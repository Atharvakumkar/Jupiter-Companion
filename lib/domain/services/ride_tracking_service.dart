import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/utils/geo_utils.dart';
import '../../data/platform/native_tracking_channel.dart';
import '../models/parking_location.dart';
import '../models/ride.dart';
import '../models/route_point.dart';
import '../models/telemetry.dart';
import '../repositories/parking_repository.dart';
import '../repositories/ride_repository.dart';

class ActiveRideState {
  final Ride ride;
  final List<RoutePoint> recentPoints;
  final TelemetryField<double> currentGpsSpeed;
  final double currentDistanceMeters;
  final int elapsedSeconds;
  final int movingSeconds;
  final bool isGpsSignalValid;

  const ActiveRideState({
    required this.ride,
    this.recentPoints = const [],
    required this.currentGpsSpeed,
    this.currentDistanceMeters = 0.0,
    this.elapsedSeconds = 0,
    this.movingSeconds = 0,
    this.isGpsSignalValid = false,
  });

  ActiveRideState copyWith({
    Ride? ride,
    List<RoutePoint>? recentPoints,
    TelemetryField<double>? currentGpsSpeed,
    double? currentDistanceMeters,
    int? elapsedSeconds,
    int? movingSeconds,
    bool? isGpsSignalValid,
  }) {
    return ActiveRideState(
      ride: ride ?? this.ride,
      recentPoints: recentPoints ?? this.recentPoints,
      currentGpsSpeed: currentGpsSpeed ?? this.currentGpsSpeed,
      currentDistanceMeters: currentDistanceMeters ?? this.currentDistanceMeters,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      movingSeconds: movingSeconds ?? this.movingSeconds,
      isGpsSignalValid: isGpsSignalValid ?? this.isGpsSignalValid,
    );
  }
}

class RideTrackingService {
  final RideRepository rideRepository;
  final ParkingRepository parkingRepository;
  final NativeTrackingChannel nativeChannel;

  RideStatus _status = RideStatus.idle;
  Ride? _currentRide;
  RoutePoint? _lastValidPoint;
  final List<RoutePoint> _inMemoryPoints = [];
  Timer? _durationTimer;
  StreamSubscription? _locationSubscription;

  int _elapsedSeconds = 0;
  int _movingSeconds = 0;
  double _accumulatedDistanceMeters = 0.0;
  double _maxSpeedKmh = 0.0;
  double _sumSpeeds = 0.0;
  int _speedReadingsCount = 0;

  final _stateController = StreamController<ActiveRideState>.broadcast();
  Stream<ActiveRideState> get stateStream => _stateController.stream;

  RideStatus get status => _status;
  Ride? get currentRide => _currentRide;
  List<RoutePoint> get currentPoints => List.unmodifiable(_inMemoryPoints);

  RideTrackingService({
    required this.rideRepository,
    required this.parkingRepository,
    required this.nativeChannel,
  });

  /// Checks for any unfinished ride session from previous runs and restores it.
  Future<void> restoreSessionIfInterrupted() async {
    try {
      final activeRide = await rideRepository.getActiveRide();
      if (activeRide != null) {
        _currentRide = activeRide;
        _status = activeRide.status;
        _elapsedSeconds = activeRide.durationSeconds;
        _movingSeconds = activeRide.movingDurationSeconds;
        _accumulatedDistanceMeters = activeRide.distanceMeters;
        _maxSpeedKmh = activeRide.maxSpeedKmh;

        final existingPoints = await rideRepository.getPointsForRide(activeRide.id);
        _inMemoryPoints.clear();
        _inMemoryPoints.addAll(existingPoints);
        if (existingPoints.isNotEmpty) {
          _lastValidPoint = existingPoints.last;
        }

        // Check if native service is still running
        final serviceStatus = await nativeChannel.getTrackingStatus();
        final isRunning = serviceStatus['isRunning'] == true;

        if (isRunning && _status == RideStatus.recording) {
          _startTimer();
          _listenToLocationUpdates();
        } else if (_status == RideStatus.recording) {
          // Restart native foreground service
          await nativeChannel.startTracking(rideId: activeRide.id);
          _startTimer();
          _listenToLocationUpdates();
        }

        _notifyState(isGpsValid: true);
      }
    } catch (e) {
      debugPrint('Error restoring interrupted ride session: $e');
    }
  }

  /// Explicit Start Ride action initiated by rider.
  Future<bool> startRide({
    RecordingSource source = RecordingSource.manual,
  }) async {
    if (_status == RideStatus.recording || _status == RideStatus.starting) {
      return false; // Already active
    }

    _status = RideStatus.starting;
    final rideId = 'ride_${DateTime.now().millisecondsSinceEpoch}';

    final initialRide = Ride(
      id: rideId,
      startTime: DateTime.now(),
      status: RideStatus.recording,
      source: source,
    );

    _currentRide = initialRide;
    _elapsedSeconds = 0;
    _movingSeconds = 0;
    _accumulatedDistanceMeters = 0.0;
    _maxSpeedKmh = 0.0;
    _sumSpeeds = 0.0;
    _speedReadingsCount = 0;
    _inMemoryPoints.clear();
    _lastValidPoint = null;

    // 1. Immediately persist initial session in SQLite
    await rideRepository.saveRide(initialRide);

    // 2. Start native Android foreground service
    final started = await nativeChannel.startTracking(rideId: rideId);
    if (!started) {
      debugPrint('Warning: Native tracking service failed to start or running on non-Android platform.');
    }

    // 3. Start state machine and listeners
    _status = RideStatus.recording;
    _startTimer();
    _listenToLocationUpdates();

    _notifyState(isGpsValid: false);
    return true;
  }

  /// Explicit Pause action
  Future<void> pauseRide() async {
    if (_status != RideStatus.recording || _currentRide == null) return;

    _status = RideStatus.paused;
    _durationTimer?.cancel();
    await nativeChannel.pauseTracking();

    final updated = _currentRide!.copyWith(
      status: RideStatus.paused,
      durationSeconds: _elapsedSeconds,
      movingDurationSeconds: _movingSeconds,
      distanceMeters: _accumulatedDistanceMeters,
      maxSpeedKmh: _maxSpeedKmh,
      avgSpeedKmh: _speedReadingsCount > 0 ? _sumSpeeds / _speedReadingsCount : 0.0,
      pointsCount: _inMemoryPoints.length,
    );
    _currentRide = updated;
    await rideRepository.updateRide(updated);

    _notifyState(isGpsValid: false);
  }

  /// Explicit Resume action
  Future<void> resumeRide() async {
    if (_status != RideStatus.paused || _currentRide == null) return;

    _status = RideStatus.recording;
    await nativeChannel.resumeTracking();
    _startTimer();

    final updated = _currentRide!.copyWith(status: RideStatus.recording);
    _currentRide = updated;
    await rideRepository.updateRide(updated);

    _notifyState(isGpsValid: true);
  }

  /// Explicit End Ride action initiated by rider.
  Future<Ride?> endRide({bool saveParking = true}) async {
    if (_currentRide == null) return null;

    _status = RideStatus.finalizing;
    _durationTimer?.cancel();
    _locationSubscription?.cancel();
    await nativeChannel.stopTracking();

    final now = DateTime.now();
    final avgSpeed = _speedReadingsCount > 0 ? _sumSpeeds / _speedReadingsCount : 0.0;

    final completedRide = _currentRide!.copyWith(
      endTime: now,
      status: RideStatus.completed,
      durationSeconds: _elapsedSeconds,
      movingDurationSeconds: _movingSeconds,
      distanceMeters: _accumulatedDistanceMeters,
      maxSpeedKmh: _maxSpeedKmh,
      avgSpeedKmh: avgSpeed,
      pointsCount: _inMemoryPoints.length,
    );

    // Save final state to SQLite
    await rideRepository.updateRide(completedRide);

    // Save parking location at ride end if coordinate available
    if (saveParking && _lastValidPoint != null) {
      await parkingRepository.saveParkingLocation(
        ParkingLocation(
          id: 'park_${now.millisecondsSinceEpoch}',
          latitude: _lastValidPoint!.latitude,
          longitude: _lastValidPoint!.longitude,
          timestamp: now,
          note: 'Parked after completed ride (${AppGeoFormat.formatDistance(_accumulatedDistanceMeters)})',
          accuracyMeters: _lastValidPoint!.accuracy,
          associatedRideId: completedRide.id,
        ),
      );
    }

    _currentRide = null;
    _status = RideStatus.idle;
    _lastValidPoint = null;

    _stateController.add(
      ActiveRideState(
        ride: completedRide,
        recentPoints: List.unmodifiable(_inMemoryPoints),
        currentGpsSpeed: TelemetryField.unavailable(
          name: 'Speed',
          unit: 'km/h',
          note: 'Ride completed',
        ),
        currentDistanceMeters: completedRide.distanceMeters,
        elapsedSeconds: completedRide.durationSeconds,
        movingSeconds: completedRide.movingDurationSeconds,
        isGpsSignalValid: false,
      ),
    );

    return completedRide;
  }

  void _startTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      if (_status == RideStatus.recording) {
        // Only increment moving seconds if moving (> 1.5 km/h)
        if (_lastValidPoint != null && _lastValidPoint!.speedKmh > 1.5) {
          _movingSeconds++;
        }
      }
      _notifyState(isGpsValid: _lastValidPoint != null);
    });
  }

  void _listenToLocationUpdates() {
    _locationSubscription?.cancel();
    _locationSubscription = nativeChannel.locationStream.listen(
      (data) {
        _processLocationPoint(data);
      },
      onError: (err) {
        debugPrint('Location stream error: $err');
      },
    );
  }

  Future<void> _processLocationPoint(Map<String, dynamic> data) async {
    if (_status != RideStatus.recording || _currentRide == null) return;

    final lat = (data['latitude'] as num).toDouble();
    final lon = (data['longitude'] as num).toDouble();
    final alt = (data['altitude'] as num?)?.toDouble() ?? 0.0;
    final acc = (data['accuracy'] as num?)?.toDouble() ?? 999.0;
    final reportedSpeedMps = (data['speed'] as num?)?.toDouble() ?? 0.0;
    final bearing = (data['bearing'] as num?)?.toDouble() ?? 0.0;
    final timestamp = (data['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
    final isPausedPoint = data['isPaused'] == true || _status == RideStatus.paused;

    final speedKmh = GeoUtils.mpsToKmh(reportedSpeedMps);

    // Validate GPS Jump and Physical Plausibility
    if (_lastValidPoint != null && !isPausedPoint) {
      final isPlausible = GeoUtils.isPointPlausible(
        prevLat: _lastValidPoint!.latitude,
        prevLon: _lastValidPoint!.longitude,
        prevTimestampMs: _lastValidPoint!.timestamp,
        newLat: lat,
        newLon: lon,
        newTimestampMs: timestamp,
        newAccuracyMeters: acc,
        reportedSpeedMps: reportedSpeedMps,
      );

      if (!isPlausible) {
        // Discard impossible jump to protect distance integrity
        return;
      }

      // Accumulate Haversine distance
      final segmentDistance = GeoUtils.haversineDistanceMeters(
        _lastValidPoint!.latitude,
        _lastValidPoint!.longitude,
        lat,
        lon,
      );
      _accumulatedDistanceMeters += segmentDistance;
    }

    final point = RoutePoint(
      rideId: _currentRide!.id,
      latitude: lat,
      longitude: lon,
      altitude: alt,
      accuracy: acc,
      speedKmh: speedKmh,
      bearing: bearing,
      timestamp: timestamp,
      isPaused: isPausedPoint,
    );

    _inMemoryPoints.add(point);
    _lastValidPoint = point;

    // Track Speed Statistics
    if (!isPausedPoint && speedKmh > 0.5) {
      if (speedKmh > _maxSpeedKmh) {
        _maxSpeedKmh = speedKmh;
      }
      _sumSpeeds += speedKmh;
      _speedReadingsCount++;
    }

    // Incremental Persistence: Save to SQLite
    await rideRepository.addRoutePoint(point);

    // Periodically update ride header in database
    if (_inMemoryPoints.length % 5 == 0) {
      final updated = _currentRide!.copyWith(
        distanceMeters: _accumulatedDistanceMeters,
        durationSeconds: _elapsedSeconds,
        movingDurationSeconds: _movingSeconds,
        maxSpeedKmh: _maxSpeedKmh,
        avgSpeedKmh: _speedReadingsCount > 0 ? _sumSpeeds / _speedReadingsCount : 0.0,
        pointsCount: _inMemoryPoints.length,
      );
      _currentRide = updated;
      await rideRepository.updateRide(updated);
    }

    _notifyState(isGpsValid: acc <= GeoUtils.defaultMaxAcceptableAccuracyMeters);
  }

  void _notifyState({required bool isGpsValid}) {
    if (_currentRide == null) return;

    final currentSpeedField = isGpsValid && _lastValidPoint != null
        ? TelemetryField<double>(
            name: 'Speed',
            value: _lastValidPoint!.speedKmh,
            unit: 'km/h',
            source: TelemetrySource.gps,
            timestamp: DateTime.fromMillisecondsSinceEpoch(_lastValidPoint!.timestamp),
            isValid: true,
            confidence: _lastValidPoint!.accuracy < 10 ? 1.0 : 0.8,
            note: 'GPS-derived measurement (±${_lastValidPoint!.accuracy.toStringAsFixed(1)}m)',
          )
        : TelemetryField<double>.unavailable(
            name: 'Speed',
            unit: 'km/h',
            note: 'GPS signal acquiring / low accuracy',
          );

    _stateController.add(
      ActiveRideState(
        ride: _currentRide!,
        recentPoints: List.unmodifiable(_inMemoryPoints),
        currentGpsSpeed: currentSpeedField,
        currentDistanceMeters: _accumulatedDistanceMeters,
        elapsedSeconds: _elapsedSeconds,
        movingSeconds: _movingSeconds,
        isGpsSignalValid: isGpsValid,
      ),
    );
  }

  void dispose() {
    _durationTimer?.cancel();
    _locationSubscription?.cancel();
    _stateController.close();
  }
}

class AppGeoFormat {
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }
}

