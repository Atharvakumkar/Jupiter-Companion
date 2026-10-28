import 'package:flutter_test/flutter_test.dart';
import 'package:jupiter_companion/data/platform/native_tracking_channel.dart';
import 'package:jupiter_companion/domain/models/parking_location.dart';
import 'package:jupiter_companion/domain/models/ride.dart';
import 'package:jupiter_companion/domain/models/route_point.dart';
import 'package:jupiter_companion/domain/repositories/parking_repository.dart';
import 'package:jupiter_companion/domain/repositories/ride_repository.dart';
import 'package:jupiter_companion/domain/services/ride_tracking_service.dart';

class MockRideRepository implements RideRepository {
  final List<Ride> rides = [];
  final List<RoutePoint> points = [];

  @override
  Future<void> saveRide(Ride ride) async => rides.add(ride);

  @override
  Future<void> updateRide(Ride ride) async {
    final idx = rides.indexWhere((r) => r.id == ride.id);
    if (idx != -1) rides[idx] = ride;
  }

  @override
  Future<Ride?> getRide(String id) async =>
      rides.where((r) => r.id == id).firstOrNull;

  @override
  Future<List<Ride>> getAllRides() async => List.unmodifiable(rides);

  @override
  Future<Ride?> getActiveRide() async =>
      rides.where((r) => r.status == RideStatus.recording || r.status == RideStatus.paused).firstOrNull;

  @override
  Future<void> deleteRide(String id) async {
    rides.removeWhere((r) => r.id == id);
    points.removeWhere((p) => p.rideId == id);
  }

  @override
  Future<void> addRoutePoint(RoutePoint point) async => points.add(point);

  @override
  Future<void> addRoutePointsBatch(List<RoutePoint> batch) async => points.addAll(batch);

  @override
  Future<List<RoutePoint>> getPointsForRide(String rideId) async =>
      points.where((p) => p.rideId == rideId).toList();
}

class MockParkingRepository implements ParkingRepository {
  ParkingLocation? lastSaved;

  @override
  Future<void> saveParkingLocation(ParkingLocation location) async => lastSaved = location;

  @override
  Future<ParkingLocation?> getLatestParkingLocation() async => lastSaved;

  @override
  Future<List<ParkingLocation>> getAllParkingLocations() async =>
      lastSaved != null ? [lastSaved!] : [];

  @override
  Future<void> deleteParkingLocation(String id) async => lastSaved = null;
}

class MockNativeTrackingChannel extends NativeTrackingChannel {
  @override
  Stream<Map<String, dynamic>> get locationStream => const Stream.empty();

  @override
  Future<bool> startTracking({required String rideId, int minTimeMs = 1000, double minDistanceM = 1.0}) async => true;

  @override
  Future<bool> pauseTracking() async => true;

  @override
  Future<bool> resumeTracking() async => true;

  @override
  Future<bool> stopTracking() async => true;

  @override
  Future<Map<String, dynamic>> getTrackingStatus() async => {'isRunning': false, 'isPaused': false, 'currentRideId': null};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RideTrackingService Unit Tests', () {
    late MockRideRepository rideRepo;
    late MockParkingRepository parkingRepo;
    late MockNativeTrackingChannel channel;
    late RideTrackingService service;

    setUp(() {
      rideRepo = MockRideRepository();
      parkingRepo = MockParkingRepository();
      channel = MockNativeTrackingChannel();
      service = RideTrackingService(
        rideRepository: rideRepo,
        parkingRepository: parkingRepo,
        nativeChannel: channel,
      );
    });

    tearDown(() {
      service.dispose();
    });

    test('Initial status is idle', () {
      expect(service.status, RideStatus.idle);
      expect(service.currentRide, isNull);
    });

    test('startRide creates session, transitions state to recording', () async {
      final started = await service.startRide();
      expect(started, isTrue);
      expect(service.status, RideStatus.recording);
      expect(service.currentRide, isNotNull);
      expect(rideRepo.rides.length, 1);
      expect(rideRepo.rides.first.status, RideStatus.recording);
    });

    test('pauseRide transitions state to paused', () async {
      await service.startRide();
      await service.pauseRide();
      expect(service.status, RideStatus.paused);
      expect(rideRepo.rides.first.status, RideStatus.paused);
    });

    test('resumeRide transitions state back to recording', () async {
      await service.startRide();
      await service.pauseRide();
      await service.resumeRide();
      expect(service.status, RideStatus.recording);
      expect(rideRepo.rides.first.status, RideStatus.recording);
    });

    test('endRide finalizes session, marks completed, and returns ride summary', () async {
      await service.startRide();
      final finishedRide = await service.endRide(saveParking: false);
      expect(service.status, RideStatus.idle);
      expect(service.currentRide, isNull);
      expect(finishedRide, isNotNull);
      expect(finishedRide!.status, RideStatus.completed);
      expect(rideRepo.rides.first.status, RideStatus.completed);
    });
  });
}

