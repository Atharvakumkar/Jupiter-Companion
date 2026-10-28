import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/permissions/permission_service.dart';
import '../data/local/app_database.dart';
import '../data/local/preferences_service.dart';
import '../data/platform/native_tracking_channel.dart';
import '../data/repositories/local_fuel_expense_repository.dart';
import '../data/repositories/local_maintenance_repository.dart';
import '../data/repositories/local_parking_repository.dart';
import '../data/repositories/local_ride_repository.dart';
import '../domain/models/bluetooth_device_info.dart';
import '../domain/models/fuel_log.dart';
import '../domain/models/maintenance_record.dart';
import '../domain/models/parking_location.dart';
import '../domain/models/ride.dart';
import '../domain/repositories/fuel_expense_repository.dart';
import '../domain/repositories/maintenance_repository.dart';
import '../domain/repositories/parking_repository.dart';
import '../domain/repositories/ride_repository.dart';
import '../domain/services/auto_ride_detector.dart';
import '../domain/services/cloud_sync_service.dart';
import '../domain/services/ecu_protocol_decoder.dart';
import '../domain/services/live_cluster_controller.dart';
import '../domain/services/ride_tracking_service.dart';
import '../domain/services/vehicle_connection_service.dart';

// --- Database & Local Storage Providers ---

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  throw UnimplementedError('Initialize preferencesServiceProvider in main()');
});

// --- Repository Providers ---

final rideRepositoryProvider = Provider<RideRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return LocalRideRepository(db);
});

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return LocalMaintenanceRepository(db);
});

final fuelExpenseRepositoryProvider = Provider<FuelExpenseRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return LocalFuelExpenseRepository(db);
});

final parkingRepositoryProvider = Provider<ParkingRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return LocalParkingRepository(db);
});

// --- Platform & Permissions Providers ---

final nativeTrackingChannelProvider = Provider<NativeTrackingChannel>((ref) {
  return NativeTrackingChannel();
});

final permissionServiceProvider = Provider<AppPermissionService>((ref) {
  return AppPermissionService();
});

// --- Service Providers ---

final rideTrackingServiceProvider = Provider<RideTrackingService>((ref) {
  final rideRepo = ref.watch(rideRepositoryProvider);
  final parkingRepo = ref.watch(parkingRepositoryProvider);
  final channel = ref.watch(nativeTrackingChannelProvider);

  final service = RideTrackingService(
    rideRepository: rideRepo,
    parkingRepository: parkingRepo,
    nativeChannel: channel,
  );

  // Restore session if previously interrupted by process restart
  service.restoreSessionIfInterrupted();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

final autoRideDetectorProvider = Provider<AutoRideDetector>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  final tracking = ref.watch(rideTrackingServiceProvider);

  return AutoRideDetector(
    prefs: prefs,
    trackingService: tracking,
  );
});

final vehicleConnectionServiceProvider = Provider<VehicleConnectionService>((ref) {
  final service = VehicleConnectionService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  final rideRepo = ref.watch(rideRepositoryProvider);
  final maintRepo = ref.watch(maintenanceRepositoryProvider);
  final fuelRepo = ref.watch(fuelExpenseRepositoryProvider);
  final parkingRepo = ref.watch(parkingRepositoryProvider);

  final service = CloudSyncService(
    rideRepository: rideRepo,
    maintenanceRepository: maintRepo,
    fuelRepository: fuelRepo,
    parkingRepository: parkingRepo,
  );

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

final liveClusterControllerProvider = Provider<LiveClusterController>((ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  final tracking = ref.watch(rideTrackingServiceProvider);
  final connection = ref.watch(vehicleConnectionServiceProvider);

  final controller = LiveClusterController(
    prefs: prefs,
    trackingService: tracking,
    connectionService: connection,
  );

  ref.onDispose(() {
    controller.dispose();
  });

  return controller;
});

final liveClusterTelemetryProvider = StreamProvider<LiveClusterTelemetry>((ref) {
  final controller = ref.watch(liveClusterControllerProvider);
  return controller.telemetryStream;
});

// --- State Stream Providers ---

final activeRideStateProvider = StreamProvider<ActiveRideState>((ref) {
  final service = ref.watch(rideTrackingServiceProvider);
  return service.stateStream;
});

final allRidesProvider = FutureProvider<List<Ride>>((ref) async {
  final repo = ref.watch(rideRepositoryProvider);
  return repo.getAllRides();
});

final maintenanceRecordsProvider = FutureProvider<List<MaintenanceRecord>>((ref) async {
  final repo = ref.watch(maintenanceRepositoryProvider);
  return repo.getAllRecords();
});

final fuelLogsProvider = FutureProvider<List<FuelLog>>((ref) async {
  final repo = ref.watch(fuelExpenseRepositoryProvider);
  return repo.getAllFuelLogs();
});

final latestParkingProvider = FutureProvider<ParkingLocation?>((ref) async {
  final repo = ref.watch(parkingRepositoryProvider);
  return repo.getLatestParkingLocation();
});

final bleScanResultsProvider = StreamProvider<List<BluetoothDeviceInfo>>((ref) {
  final service = ref.watch(vehicleConnectionServiceProvider);
  return service.scanResultsStream;
});

final rawPacketLogsProvider = StreamProvider<List<RawPacketLog>>((ref) {
  final service = ref.watch(vehicleConnectionServiceProvider);
  return service.rawPacketLogStream;
});

final ecuFrameStreamProvider = StreamProvider<DecodedEcuFrame>((ref) {
  final service = ref.watch(vehicleConnectionServiceProvider);
  return service.ecuFrameStream;
});
