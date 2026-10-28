import 'package:flutter_test/flutter_test.dart';
import 'package:jupiter_companion/data/local/preferences_service.dart';
import 'package:jupiter_companion/domain/models/telemetry.dart';
import 'package:jupiter_companion/domain/services/live_cluster_controller.dart';
import 'package:jupiter_companion/domain/services/ride_tracking_service.dart';
import 'package:jupiter_companion/domain/services/vehicle_connection_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ride_tracking_service_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PreferencesService prefs;
  late RideTrackingService trackingService;
  late VehicleConnectionService connectionService;
  late LiveClusterController clusterController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'manual_odometer_km': 12450.0,
    });
    prefs = await PreferencesService.create();
    trackingService = RideTrackingService(
      rideRepository: MockRideRepository(),
      parkingRepository: MockParkingRepository(),
      nativeChannel: MockNativeTrackingChannel(),
    );
    connectionService = VehicleConnectionService();

    clusterController = LiveClusterController(
      prefs: prefs,
      trackingService: trackingService,
      connectionService: connectionService,
    );
  });

  tearDown(() {
    clusterController.dispose();
    trackingService.dispose();
    connectionService.dispose();
  });

  group('LiveClusterController Tests', () {
    test('Initial cluster state reflects honest provenance without fake RPM', () {
      final state = clusterController.currentState;

      expect(state.rpm, 0);
      expect(state.rpmSource, TelemetrySource.unavailable);
      expect(state.speedKmh, 0.0);
      expect(state.speedSource, TelemetrySource.gps);
      expect(state.totalOdometerKm, 12450.0);
      expect(state.odometerSource, TelemetrySource.userManual);
      expect(state.batteryVoltage, 12.6);
      expect(state.isTestBenchMode, isFalse);
    });

    test('Test bench simulation mode revs dynamically and tags calculated provenance', () async {
      clusterController.setTestBenchMode(true);
      expect(clusterController.currentState.isTestBenchMode, isTrue);
      expect(clusterController.currentState.rpmSource, TelemetrySource.calculated);
      expect(clusterController.currentState.speedSource, TelemetrySource.calculated);

      // Wait 250ms for simulation timer ticks
      await Future.delayed(const Duration(milliseconds: 250));

      final state = clusterController.currentState;
      expect(state.rpm, greaterThan(1500));
      expect(state.speedKmh, greaterThan(0.0));
      expect(state.totalOdometerKm, greaterThanOrEqualTo(12450.0));

      // Disable test bench mode
      clusterController.setTestBenchMode(false);
      final reverted = clusterController.currentState;
      expect(reverted.isTestBenchMode, isFalse);
      expect(reverted.rpm, 0);
      expect(reverted.rpmSource, TelemetrySource.unavailable);
    });

    test('updateBaseOdometer updates base reading and preserves trip offset', () async {
      await clusterController.updateBaseOdometer(15000.0);

      expect(clusterController.currentState.totalOdometerKm, 15000.0);
      expect(prefs.manualOdometerKm, 15000.0);
    });

    test('Incoming verified ECU packet updates RPM, speed, and voltage with verifiedEcu provenance', () async {
      // Feed TVS SmartXonnect binary packet: [0xAA, 0x10, speed=48, rpmHigh=0x09, rpmLow=0xC4 (2500 RPM), volt=142 (14.2V)]
      final tvsPacket = [0xAA, 0x10, 48, 0x09, 0xC4, 142];
      connectionService.processIncomingBytes(tvsPacket);

      // Allow microtask to propagate to stream listener
      await Future.delayed(const Duration(milliseconds: 50));

      final state = clusterController.currentState;
      expect(state.rpm, 2500);
      expect(state.rpmSource, TelemetrySource.verifiedEcu);
      expect(state.speedKmh, 48.0);
      expect(state.speedSource, TelemetrySource.verifiedEcu);
      expect(state.batteryVoltage, 14.2);
      expect(state.batterySource, TelemetrySource.verifiedEcu);
    });
  });
}

