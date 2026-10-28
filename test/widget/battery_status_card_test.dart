import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jupiter_companion/app/widgets/battery_status_card.dart';
import 'package:jupiter_companion/domain/models/telemetry.dart';

void main() {
  group('BatteryStatusCard Widget Tests', () {
    testWidgets('renders healthy lead-acid state for normal 12.6V', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BatteryStatusCard(
              voltage: 12.6,
              batteryPercent: 90,
              isCharging: false,
              source: TelemetrySource.calculated,
            ),
          ),
        ),
      );

      expect(find.text('12.6 V'), findsOneWidget);
      expect(find.text('90%'), findsOneWidget);
      expect(find.text('HEALTHY (12V LEAD-ACID)'), findsOneWidget);
    });

    testWidgets('renders alternator charging state for >= 13.8V', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BatteryStatusCard(
              voltage: 14.2,
              batteryPercent: 100,
              isCharging: true,
              source: TelemetrySource.verifiedEcu,
            ),
          ),
        ),
      );

      expect(find.text('14.2 V'), findsOneWidget);
      expect(find.text('CHARGING (ALTERNATOR)'), findsOneWidget);
    });
  });
}

