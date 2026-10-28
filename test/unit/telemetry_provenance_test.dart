import 'package:flutter_test/flutter_test.dart';
import 'package:jupiter_companion/domain/models/telemetry.dart';

void main() {
  group('Telemetry Provenance Unit Tests', () {
    test('Initial vehicle state strictly marks RPM as unavailable without fake values', () {
      final state = VehicleTelemetryState.initial();

      expect(state.rpm.source, TelemetrySource.unavailable);
      expect(state.rpm.value, isNull);
      expect(state.rpm.isValid, isFalse);
      expect(state.rpm.note, contains('SmartXonnect ECU'));
    });

    test('Speed measurement provenance is strictly labeled as GPS', () {
      final speedField = TelemetryField<double>(
        name: 'Speed',
        value: 42.5,
        unit: 'km/h',
        source: TelemetrySource.gps,
        timestamp: DateTime.now(),
        isValid: true,
      );

      expect(speedField.source, TelemetrySource.gps);
      expect(speedField.sourceLabel, 'GPS');
      expect(speedField.value, 42.5);
      expect(speedField.isFresh(), isTrue);
    });

    test('Stale telemetry field expires after max age', () {
      final staleField = TelemetryField<double>(
        name: 'Speed',
        value: 30.0,
        unit: 'km/h',
        source: TelemetrySource.gps,
        timestamp: DateTime.now().subtract(const Duration(seconds: 10)),
        isValid: true,
      );

      expect(staleField.isFresh(maxAge: const Duration(seconds: 3)), isFalse);
    });

    test('User manual entry is cleanly distinguished from ECU and GPS', () {
      final manualOdo = TelemetryField<double>(
        name: 'Odometer',
        value: 12500.0,
        unit: 'km',
        source: TelemetrySource.userManual,
        timestamp: DateTime.now(),
      );

      expect(manualOdo.source, TelemetrySource.userManual);
      expect(manualOdo.sourceLabel, 'User Entry');
    });
  });
}

