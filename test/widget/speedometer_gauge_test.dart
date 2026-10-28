import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jupiter_companion/app/widgets/speedometer_gauge.dart';

void main() {
  group('SpeedometerGauge Widget Tests', () {
    testWidgets('renders valid speed and KM/H unit when GPS is valid', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpeedometerGauge(
              currentSpeedKmh: 48.0,
              isGpsValid: true,
              subtitle: 'GPS LIVE',
            ),
          ),
        ),
      );

      expect(find.text('48'), findsOneWidget);
      expect(find.text('KM/H'), findsOneWidget);
      expect(find.text('GPS LIVE'), findsOneWidget);
    });

    testWidgets('renders dashes -- and ACQUIRING GPS when GPS signal is invalid', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpeedometerGauge(
              currentSpeedKmh: 0.0,
              isGpsValid: false,
              subtitle: 'ACQUIRING GPS',
            ),
          ),
        ),
      );

      expect(find.text('--'), findsOneWidget);
      expect(find.text('KM/H'), findsOneWidget);
      expect(find.text('ACQUIRING GPS'), findsOneWidget);
    });
  });
}

