import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jupiter_companion/app/widgets/tachometer_gauge.dart';

void main() {
  group('TachometerGauge Widget Tests', () {
    testWidgets('renders ECO MODE below 5000 RPM', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TachometerGauge(
              currentRpm: 3200,
              isConnected: true,
            ),
          ),
        ),
      );

      expect(find.text('3200'), findsOneWidget);
      expect(find.text('RPM'), findsOneWidget);
      expect(find.text('ECO MODE'), findsOneWidget);
    });

    testWidgets('renders POWER MODE between 5000 and 7500 RPM', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TachometerGauge(
              currentRpm: 6200,
              isConnected: true,
            ),
          ),
        ),
      );

      expect(find.text('6200'), findsOneWidget);
      expect(find.text('POWER MODE'), findsOneWidget);
    });

    testWidgets('renders REDLINE above 7500 RPM', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TachometerGauge(
              currentRpm: 8100,
              isConnected: true,
            ),
          ),
        ),
      );

      expect(find.text('8100'), findsOneWidget);
      expect(find.text('REDLINE'), findsOneWidget);
    });

    testWidgets('renders dashes --- when disconnected', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TachometerGauge(
              currentRpm: 0,
              isConnected: false,
              sourceLabel: 'UNAVAILABLE',
            ),
          ),
        ),
      );

      expect(find.text('---'), findsOneWidget);
      expect(find.text('UNAVAILABLE'), findsOneWidget);
    });
  });
}

