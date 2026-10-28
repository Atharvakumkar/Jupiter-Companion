import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/battery_status_card.dart';
import '../../../app/widgets/metric_tile.dart';
import '../../../app/widgets/provenance_badge.dart';
import '../../../app/widgets/speedometer_gauge.dart';
import '../../../app/widgets/tachometer_gauge.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/models/ride.dart';
import '../../../domain/models/telemetry.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRideState = ref.watch(activeRideStateProvider).valueOrNull;
    final isRecording = activeRideState?.ride.status == RideStatus.recording ||
        activeRideState?.ride.status == RideStatus.paused;
    final latestParkingAsync = ref.watch(latestParkingProvider);
    final maintenanceAsync = ref.watch(maintenanceRecordsProvider);
    final vehicleConnection = ref.watch(vehicleConnectionServiceProvider);
    final liveTelemetry = ref.watch(liveClusterTelemetryProvider).valueOrNull ??
        ref.watch(liveClusterControllerProvider).currentState;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryGlow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.two_wheeler, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'JUPITER COMPANION',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth_searching, color: AppColors.primary),
            tooltip: 'Bluetooth Diagnostics',
            onPressed: () => context.push('/diagnostics'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(latestParkingProvider);
          ref.invalidate(maintenanceRecordsProvider);
          ref.invalidate(allRidesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Connection Status Banner (Overflow-safe)
            _buildConnectionBanner(context, vehicleConnection.isConnected),
            const SizedBox(height: 12),

            // Map & Navigation Shortcut Banner
            _buildMapStatusBanner(context),
            const SizedBox(height: 14),

            // Automotive Dual Digital Cluster (Speedometer + Tachometer + Odometer)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isRecording ? AppColors.primary.withOpacity(0.6) : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  // Dual Gauges: Speedometer (km/h) & Tachometer (RPM)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Speedometer Gauge
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SpeedometerGauge(
                            currentSpeedKmh: liveTelemetry.speedKmh,
                            isGpsValid: activeRideState?.isGpsSignalValid ?? false,
                            subtitle: liveTelemetry.isTestBenchMode
                                ? 'SIMULATED'
                                : (isRecording ? 'GPS SPEED' : 'RIDE IDLE'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Tachometer Gauge (0 - 9000 RPM)
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: TachometerGauge(
                            currentRpm: liveTelemetry.rpm,
                            isConnected: vehicleConnection.isConnected || liveTelemetry.isTestBenchMode,
                            sourceLabel: liveTelemetry.isTestBenchMode ? 'BENCH SIM' : 'ECU STREAM',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Digital Odometer & Live Trip Reading Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('ODOMETER', style: AppTypography.badgeText),
                                  const SizedBox(width: 4),
                                  ProvenanceBadge(source: liveTelemetry.odometerSource),
                                ],
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${liveTelemetry.totalOdometerKm.toStringAsFixed(1)} km',
                                  style: AppTypography.metricValue.copyWith(fontSize: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(height: 30, width: 1, color: AppColors.border),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('SESSION TRIP', style: AppTypography.badgeText),
                                  const SizedBox(width: 4),
                                  ProvenanceBadge(
                                    source: liveTelemetry.isTestBenchMode
                                        ? TelemetrySource.calculated
                                        : TelemetrySource.gps,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${liveTelemetry.tripDistanceKm.toStringAsFixed(2)} km',
                                  style: AppTypography.metricValue.copyWith(
                                    fontSize: 18,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Start / Resume / End Controls
                  Row(
                    children: [
                      if (!isRecording) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.background,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 26),
                            label: const Text('START RIDE', style: TextStyle(fontWeight: FontWeight.w800)),
                            onPressed: () async {
                              final tracking = ref.read(rideTrackingServiceProvider);
                              await tracking.startRide(source: RecordingSource.manual);
                              if (context.mounted) {
                                context.push('/recording');
                              }
                            },
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.fullscreen, color: AppColors.primary),
                            label: const Text('LIVE RIDE'),
                            onPressed: () => context.push('/recording'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.stop_rounded),
                            label: const Text('END RIDE'),
                            onPressed: () async {
                              final tracking = ref.read(rideTrackingServiceProvider);
                              final ride = await tracking.endRide(saveParking: true);
                              ref.invalidate(allRidesProvider);
                              ref.invalidate(latestParkingProvider);
                              if (context.mounted && ride != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Ride saved! ${AppFormatters.formatDistance(ride.distanceMeters)} in ${AppFormatters.formatDurationReadable(ride.durationSeconds)}'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Live Electrical & Battery Status Card
            BatteryStatusCard(
              voltage: liveTelemetry.batteryVoltage,
              batteryPercent: liveTelemetry.batteryPercent,
              isCharging: liveTelemetry.batteryVoltage >= 13.6,
              source: liveTelemetry.batterySource,
            ),
            const SizedBox(height: 14),

            // Test Bench Simulation Toggle Bar
            _buildTestBenchBar(context, ref, liveTelemetry.isTestBenchMode),
            const SizedBox(height: 14),

            // Active Ride Metrics Grid (Overflow-safe childAspectRatio 1.25)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [
                MetricTile(
                  label: 'Distance',
                  value: AppFormatters.formatDistance(activeRideState?.currentDistanceMeters ?? 0.0),
                  icon: Icons.route,
                  provenance: TelemetrySource.gps,
                ),
                MetricTile(
                  label: 'Duration',
                  value: AppFormatters.formatDurationClock(activeRideState?.elapsedSeconds ?? 0),
                  icon: Icons.timer_outlined,
                  provenance: TelemetrySource.calculated,
                ),
                MetricTile(
                  label: 'Max Speed',
                  value: AppFormatters.formatSpeed(activeRideState?.ride.maxSpeedKmh ?? 0.0),
                  unit: 'km/h',
                  icon: Icons.speed,
                  provenance: TelemetrySource.gps,
                ),
                MetricTile(
                  label: 'Moving Time',
                  value: AppFormatters.formatDurationClock(activeRideState?.movingSeconds ?? 0),
                  icon: Icons.moving,
                  provenance: TelemetrySource.calculated,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Telemetry Honest Preview Card
            _buildTelemetryHonestCard(context, liveTelemetry),
            const SizedBox(height: 16),

            // Last Parked Location Card
            latestParkingAsync.when(
              data: (parking) => _buildParkingCard(context, parking, ref),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // Next Service Reminder Card
            maintenanceAsync.when(
              data: (records) => _buildMaintenanceReminderCard(context, records),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionBanner(BuildContext context, bool isConnected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isConnected ? AppColors.successGlow : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected ? AppColors.success : AppColors.border,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            color: isConnected ? AppColors.success : AppColors.textMuted,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isConnected
                  ? 'SmartXonnect Connected'
                  : 'SmartXonnect Disconnected (GPS Only Mode)',
              style: AppTypography.titleSmall.copyWith(
                color: isConnected ? AppColors.success : AppColors.textSecondary,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(50, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => context.push('/diagnostics'),
            child: Text(
              isConnected ? 'DETAILS' : 'SCAN',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapStatusBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryGlow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.map_outlined, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Route Map & Live Tracking',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                Text(
                  'Offline Vector Engine active • Google Maps key configurable',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(50, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => context.push('/live_map'),
            child: const Text('OPEN MAP', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTestBenchBar(BuildContext context, WidgetRef ref, bool isTestBench) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isTestBench ? AppColors.accentIndigo.withOpacity(0.15) : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTestBench ? AppColors.accentIndigo : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.developer_board,
            color: isTestBench ? AppColors.accentIndigo : AppColors.textMuted,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Test Bench Simulation',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                ),
                Text(
                  isTestBench
                      ? 'Simulating RPM revs (1.5k-7.2k), speed & voltage'
                      : 'Test tachometer & cluster revving without physical scooter',
                  style: AppTypography.bodySmall.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch(
            value: isTestBench,
            activeThumbColor: AppColors.accentIndigo,
            onChanged: (val) {
              ref.read(liveClusterControllerProvider).setTestBenchMode(val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryHonestCard(BuildContext context, dynamic liveTelemetry) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('VEHICLE TELEMETRY', style: AppTypography.titleSmall),
              TextButton(
                onPressed: () => context.push('/telemetry'),
                child: const Text('VIEW ALL', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildTelemetryRow(
                  label: 'Engine RPM',
                  value: liveTelemetry.isTestBenchMode
                      ? '${liveTelemetry.rpm} RPM (Bench Simulation)'
                      : (liveTelemetry.rpm > 0 ? '${liveTelemetry.rpm} RPM' : 'UNAVAILABLE'),
                  source: liveTelemetry.rpmSource,
                  note: liveTelemetry.isTestBenchMode
                      ? 'Simulated dynamic throttle for bench testing'
                      : 'Requires verified SmartXonnect GATT characteristic stream',
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildTelemetryRow(
                  label: 'Fuel Gauge',
                  value: 'Manual Refuel Log',
                  source: TelemetrySource.userManual,
                  note: 'TVS Jupiter 5.1L capacity',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryRow({
    required String label,
    required String value,
    required TelemetrySource source,
    required String note,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTypography.bodyMedium),
            ProvenanceBadge(source: source),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary)),
        Text(note, style: AppTypography.bodySmall),
      ],
    );
  }

  Widget _buildParkingCard(
    BuildContext context,
    dynamic parking,
    WidgetRef ref,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.local_parking, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text('LAST PARKED LOCATION', style: AppTypography.titleSmall),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.add_location_alt_outlined, color: AppColors.primary),
                tooltip: 'Save Current Location as Parking',
                onPressed: () => context.push('/parking'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (parking == null) ...[
            const Text(
              'No parked location recorded yet. Parking is automatically offered when ending a ride.',
              style: AppTypography.bodyMedium,
            ),
          ] else ...[
            Text(
              parking.note ?? 'Parked Vehicle',
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Saved: ${AppFormatters.formatDateTime(parking.timestamp)}',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.directions, color: AppColors.primary),
              label: const Text('VIEW ON MAP & GET DIRECTIONS'),
              onPressed: () => context.push('/parking'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMaintenanceReminderCard(
    BuildContext context,
    List<dynamic> records,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.build_circle_outlined, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text('SERVICE & MAINTENANCE', style: AppTypography.titleSmall),
                ],
              ),
              TextButton(
                onPressed: () => context.push('/maintenance'),
                child: const Text('MANAGE', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (records.isEmpty) ...[
            const Text(
              'No service records found. Configure recommended 3000 km / 90 day engine oil intervals in Maintenance.',
              style: AppTypography.bodyMedium,
            ),
          ] else ...[
            Text(
              'Last Service: ${records.first.taskType}',
              style: AppTypography.titleMedium,
            ),
            Text(
              'Date: ${AppFormatters.formatDate(records.first.date)} • Odo: ${records.first.odometerKm.toStringAsFixed(0)} km',
              style: AppTypography.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
