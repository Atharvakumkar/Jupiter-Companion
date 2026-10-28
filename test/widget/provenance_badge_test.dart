import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jupiter_companion/app/widgets/provenance_badge.dart';
import 'package:jupiter_companion/domain/models/telemetry.dart';

void main() {
  group('ProvenanceBadge Widget Tests', () {
    testWidgets('renders GPS badge correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProvenanceBadge(source: TelemetrySource.gps),
          ),
        ),
      );

      expect(find.text('GPS'), findsOneWidget);
    });

    testWidgets('renders ECU VERIFIED badge correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProvenanceBadge(source: TelemetrySource.verifiedEcu),
          ),
        ),
      );

      expect(find.text('ECU VERIFIED'), findsOneWidget);
    });

    testWidgets('renders UNAVAILABLE badge correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProvenanceBadge(source: TelemetrySource.unavailable),
          ),
        ),
      );

      expect(find.text('UNAVAILABLE'), findsOneWidget);
    });
  });
}

