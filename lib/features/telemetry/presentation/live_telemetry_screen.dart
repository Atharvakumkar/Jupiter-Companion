import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/battery_status_card.dart';
import '../../../app/widgets/metric_tile.dart';
import '../../../app/widgets/provenance_badge.dart';
import '../../../app/widgets/tachometer_gauge.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/models/telemetry.dart';

class LiveTelemetryScreen extends ConsumerWidget {
  const LiveTelemetryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRideState = ref.watch(activeRideStateProvider).valueOrNull;
    final vehicleConnection = ref.watch(vehicleConnectionServiceProvider);
    final liveTelemetry = ref.watch(liveClusterTelemetryProvider).valueOrNull ??
        ref.watch(liveClusterControllerProvider).currentState;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LIVE TELEMETRY CLUSTER'),
        actions: [
          IconButton(
            icon: Icon(
              liveTelemetry.isTestBenchMode ? Icons.developer_board : Icons.developer_board_outlined,
              color: liveTelemetry.isTestBenchMode ? AppColors.accentIndigo : AppColors.textMuted,
            ),
            tooltip: 'Toggle Test Bench',
            onPressed: () {
              ref.read(liveClusterControllerProvider).setTestBenchMode(!liveTelemetry.isTestBenchMode);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Provenance Explanation Callout
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    liveTelemetry.isTestBenchMode
                        ? 'TEST BENCH SIMULATION ACTIVE: Gauges demonstrate real-time revving and charging behavior for verification.'
                        : 'Strict Data Provenance: GPS measurements are cleanly separated from ECU vehicle readings. Unverified parameters are never fabricated.',
                    style: AppTypography.bodySmall.copyWith(
                      color: liveTelemetry.isTestBenchMode ? AppColors.accentIndigo : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Live Tachometer Gauge & Status
          Center(
            child: TachometerGauge(
              currentRpm: liveTelemetry.rpm,
              isConnected: vehicleConnection.isConnected || liveTelemetry.isTestBenchMode,
              sourceLabel: liveTelemetry.isTestBenchMode ? 'BENCH SIMULATION' : 'ECU STREAM',
            ),
          ),
          const SizedBox(height: 16),

          // Primary Speed & Provenance
          MetricTile(
            label: 'Instantaneous Speed',
            value: AppFormatters.formatSpeed(liveTelemetry.speedKmh),
            unit: 'km/h',
            icon: Icons.speed,
            provenance: liveTelemetry.speedSource,
            accentColor: AppColors.primary,
          ),
          const SizedBox(height: 12),

          // Battery Status Card
          BatteryStatusCard(
            voltage: liveTelemetry.batteryVoltage,
            batteryPercent: liveTelemetry.batteryPercent,
            isCharging: liveTelemetry.batteryVoltage >= 13.6,
            source: liveTelemetry.batterySource,
          ),
          const SizedBox(height: 12),

          // Engine RPM Card
          _buildTelemetryCard(
            title: 'Engine RPM',
            value: liveTelemetry.isTestBenchMode
                ? '${liveTelemetry.rpm} RPM'
                : (liveTelemetry.rpm > 0 ? '${liveTelemetry.rpm} RPM' : 'UNAVAILABLE'),
            unit: 'RPM',
            source: liveTelemetry.rpmSource,
            icon: Icons.rotate_right,
            explanation: liveTelemetry.isTestBenchMode
                ? 'Test bench dynamic simulation active (revving between 1500 and 7200 RPM).'
                : (liveTelemetry.rpm > 0
                    ? 'Verified ECU stream from SmartXonnect GATT service.'
                    : 'SmartXonnect proprietary ECU characteristic stream not connected. Values are never fabricated without connection.'),
          ),
          const SizedBox(height: 12),

          // Fuel Level (Manual & Capacity)
          _buildTelemetryCard(
            title: 'Fuel Level',
            value: '5.1 L Tank',
            unit: 'Capacity',
            source: TelemetrySource.userManual,
            icon: Icons.local_gas_station,
            explanation:
                'TVS Jupiter 110 uses a 5.1-liter fuel tank with 1.5L reserve. Log refuels in the Fuel Log screen to track consumption and mileage accurately.',
          ),
          const SizedBox(height: 12),

          // Odometer Reading
          _buildTelemetryCard(
            title: 'Odometer',
            value: '${liveTelemetry.totalOdometerKm.toStringAsFixed(1)} km',
            unit: 'Total Distance',
            source: liveTelemetry.odometerSource,
            icon: Icons.pin_drop_outlined,
            explanation:
                'Scooter odometer reading synced with GPS tracking distance. Calibrate via Settings or Maintenance.',
          ),
          const SizedBox(height: 12),

          // Trip Distance (GPS-Derived)
          MetricTile(
            label: 'Session Trip Distance',
            value: AppFormatters.formatDistance(
              liveTelemetry.isTestBenchMode
                  ? liveTelemetry.tripDistanceKm * 1000.0
                  : (activeRideState?.currentDistanceMeters ?? 0.0),
            ),
            icon: Icons.alt_route,
            provenance: liveTelemetry.isTestBenchMode ? TelemetrySource.calculated : TelemetrySource.gps,
          ),
          const SizedBox(height: 12),

          // Cluster Connection Status
          _buildTelemetryCard(
            title: 'Cluster Bluetooth State',
            value: vehicleConnection.isConnected ? 'Connected' : 'Disconnected',
            unit: '',
            source: vehicleConnection.isConnected ? TelemetrySource.verifiedEcu : TelemetrySource.unavailable,
            icon: Icons.bluetooth,
            explanation: vehicleConnection.isConnected
                ? 'BLE GATT link active. Enumerating characteristics safely.'
                : 'Cluster disconnected. Ride tracking and GPS metrics operate normally without interruption.',
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryCard({
    required String title,
    required String value,
    required String unit,
    required TelemetrySource source,
    required IconData icon,
    required String explanation,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(title.toUpperCase(), style: AppTypography.metricLabel),
                ],
              ),
              ProvenanceBadge(source: source),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: AppTypography.metricValue.copyWith(color: AppColors.textPrimary)),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(unit, style: AppTypography.clusterSpeedUnit.copyWith(fontSize: 14)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(explanation, style: AppTypography.bodySmall),
        ],
      ),
    );
  }
}
