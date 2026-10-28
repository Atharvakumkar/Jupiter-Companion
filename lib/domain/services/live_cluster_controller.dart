import 'dart:async';
import '../../data/local/preferences_service.dart';
import '../models/telemetry.dart';
import 'ride_tracking_service.dart';
import 'vehicle_connection_service.dart';

class LiveClusterTelemetry {
  final double speedKmh;
  final int rpm;
  final double batteryVoltage;
  final int batteryPercent;
  final double totalOdometerKm;
  final double tripDistanceKm;
  final TelemetrySource speedSource;
  final TelemetrySource rpmSource;
  final TelemetrySource batterySource;
  final TelemetrySource odometerSource;
  final bool isTestBenchMode;

  const LiveClusterTelemetry({
    required this.speedKmh,
    required this.rpm,
    required this.batteryVoltage,
    required this.batteryPercent,
    required this.totalOdometerKm,
    required this.tripDistanceKm,
    required this.speedSource,
    required this.rpmSource,
    required this.batterySource,
    required this.odometerSource,
    this.isTestBenchMode = false,
  });

  LiveClusterTelemetry copyWith({
    double? speedKmh,
    int? rpm,
    double? batteryVoltage,
    int? batteryPercent,
    double? totalOdometerKm,
    double? tripDistanceKm,
    TelemetrySource? speedSource,
    TelemetrySource? rpmSource,
    TelemetrySource? batterySource,
    TelemetrySource? odometerSource,
    bool? isTestBenchMode,
  }) {
    return LiveClusterTelemetry(
      speedKmh: speedKmh ?? this.speedKmh,
      rpm: rpm ?? this.rpm,
      batteryVoltage: batteryVoltage ?? this.batteryVoltage,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      totalOdometerKm: totalOdometerKm ?? this.totalOdometerKm,
      tripDistanceKm: tripDistanceKm ?? this.tripDistanceKm,
      speedSource: speedSource ?? this.speedSource,
      rpmSource: rpmSource ?? this.rpmSource,
      batterySource: batterySource ?? this.batterySource,
      odometerSource: odometerSource ?? this.odometerSource,
      isTestBenchMode: isTestBenchMode ?? this.isTestBenchMode,
    );
  }
}

/// Real-time automotive cluster telemetry controller for TVS Jupiter 110.
/// Coordinates GPS velocity, SmartXonnect BLE characteristic streams,
/// battery monitor, and live odometer.
class LiveClusterController {
  final PreferencesService _prefs;
  final RideTrackingService _trackingService;
  final VehicleConnectionService _connectionService;

  final _telemetryController = StreamController<LiveClusterTelemetry>.broadcast();
  Stream<LiveClusterTelemetry> get telemetryStream => _telemetryController.stream;

  LiveClusterTelemetry _currentState;
  LiveClusterTelemetry get currentState => _currentState;

  StreamSubscription? _rideSubscription;
  StreamSubscription? _ecuFrameSubscription;
  Timer? _simulationTimer;
  double _simulatedThrottle = 0.0;

  // ignore: prefer_initializing_formals
  LiveClusterController({
    required PreferencesService prefs,
    required RideTrackingService trackingService,
    required VehicleConnectionService connectionService,
  })  : _prefs = prefs,
        _trackingService = trackingService,
        _connectionService = connectionService,
        _currentState = LiveClusterTelemetry(
          speedKmh: 0.0,
          rpm: 0,
          batteryVoltage: 12.6,
          batteryPercent: 92,
          totalOdometerKm: prefs.manualOdometerKm,
          tripDistanceKm: 0.0,
          speedSource: TelemetrySource.gps,
          rpmSource: TelemetrySource.unavailable,
          batterySource: TelemetrySource.calculated,
          odometerSource: TelemetrySource.userManual,
        ) {
    _initListeners();
  }

  void _initListeners() {
    // 1. Listen to active ride GPS speed & distance
    _rideSubscription = _trackingService.stateStream.listen((activeState) {
      if (!_currentState.isTestBenchMode) {
        final currentSpeed = activeState.currentGpsSpeed.value ?? 0.0;
        final tripKm = activeState.currentDistanceMeters / 1000.0;
        final totalOdo = _prefs.manualOdometerKm + tripKm;

        // If verified ECU speed is not active, use GPS speed
        final isEcuSpeedActive = _currentState.speedSource == TelemetrySource.verifiedEcu;
        _currentState = _currentState.copyWith(
          speedKmh: isEcuSpeedActive ? _currentState.speedKmh : currentSpeed,
          tripDistanceKm: tripKm,
          totalOdometerKm: _currentState.odometerSource == TelemetrySource.verifiedEcu
              ? _currentState.totalOdometerKm
              : totalOdo,
          speedSource: isEcuSpeedActive ? TelemetrySource.verifiedEcu : TelemetrySource.gps,
        );
        _telemetryController.add(_currentState);
      }
    });

    // 2. Listen to verified ECU Telemetry stream (SmartXonnect / OBD-II)
    _ecuFrameSubscription = _connectionService.ecuFrameStream.listen((frame) {
      if (!_currentState.isTestBenchMode) {
        var updated = _currentState;

        if (frame.rpm != null) {
          updated = updated.copyWith(
            rpm: frame.rpm!,
            rpmSource: TelemetrySource.verifiedEcu,
          );
        }

        if (frame.speedKmh != null) {
          updated = updated.copyWith(
            speedKmh: frame.speedKmh!,
            speedSource: TelemetrySource.verifiedEcu,
          );
        }

        if (frame.batteryVoltage != null) {
          updated = updated.copyWith(
            batteryVoltage: frame.batteryVoltage!,
            batteryPercent: frame.batteryPercent ?? updated.batteryPercent,
            batterySource: TelemetrySource.verifiedEcu,
          );
        }

        if (frame.odometerKm != null) {
          updated = updated.copyWith(
            totalOdometerKm: frame.odometerKm!,
            odometerSource: TelemetrySource.verifiedEcu,
          );
        }

        _currentState = updated;
        _telemetryController.add(_currentState);
      }
    });
  }

  /// Toggle test bench simulation mode to verify cluster gauge animations on phone
  void setTestBenchMode(bool enabled) {
    _simulationTimer?.cancel();
    if (enabled) {
      _currentState = _currentState.copyWith(
        isTestBenchMode: true,
        rpmSource: TelemetrySource.calculated,
        speedSource: TelemetrySource.calculated,
      );
      _simulationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        // Smooth sine wave revving from idle 1500 RPM to 7200 RPM
        _simulatedThrottle += 0.06;
        final dynamicRpm = 1500 + ((5200 * (0.5 + 0.5 * (dynamicSine(_simulatedThrottle))))).toInt();
        final dynamicSpeed = (dynamicRpm / 110.0).clamp(0.0, 85.0);
        final dynamicVoltage = 12.8 + (dynamicRpm > 2000 ? 1.4 : 0.0);

        _currentState = _currentState.copyWith(
          rpm: dynamicRpm,
          speedKmh: dynamicSpeed,
          batteryVoltage: dynamicVoltage,
          tripDistanceKm: _currentState.tripDistanceKm + (dynamicSpeed * (0.1 / 3600.0)),
          totalOdometerKm: _currentState.totalOdometerKm + (dynamicSpeed * (0.1 / 3600.0)),
        );
        _telemetryController.add(_currentState);
      });
    } else {
      _currentState = _currentState.copyWith(
        isTestBenchMode: false,
        rpm: 0,
        speedKmh: 0.0,
        rpmSource: TelemetrySource.unavailable,
        speedSource: TelemetrySource.gps,
        totalOdometerKm: _prefs.manualOdometerKm,
      );
      _telemetryController.add(_currentState);
    }
  }

  static double dynamicSine(double x) => (x % 6.28318) < 3.14159 ? (x % 3.14159) / 3.14159 : 1.0 - ((x % 3.14159) / 3.14159);

  /// Allows rider to calibrate or update base odometer
  Future<void> updateBaseOdometer(double km) async {
    await _prefs.setManualOdometerKm(km);
    _currentState = _currentState.copyWith(
      totalOdometerKm: km + _currentState.tripDistanceKm,
    );
    _telemetryController.add(_currentState);
  }

  void dispose() {
    _simulationTimer?.cancel();
    _rideSubscription?.cancel();
    _ecuFrameSubscription?.cancel();
    _telemetryController.close();
  }
}
