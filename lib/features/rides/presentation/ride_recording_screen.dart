import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/battery_status_card.dart';
import '../../../app/widgets/metric_tile.dart';
import '../../../app/widgets/speedometer_gauge.dart';
import '../../../app/widgets/tachometer_gauge.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/models/ride.dart';
import '../../../domain/models/telemetry.dart';
import '../../../domain/services/ride_tracking_service.dart';

class RideRecordingScreen extends ConsumerWidget {
  const RideRecordingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRideState = ref.watch(activeRideStateProvider).valueOrNull;
    final trackingService = ref.read(rideTrackingServiceProvider);
    final vehicleConnection = ref.watch(vehicleConnectionServiceProvider);
    final liveTelemetry = ref.watch(liveClusterTelemetryProvider).valueOrNull ??
        ref.watch(liveClusterControllerProvider).currentState;

    final isPaused = activeRideState?.ride.status == RideStatus.paused;
    final isRecording = activeRideState?.ride.status == RideStatus.recording;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        appBar: AppBar(
          title: Text(isPaused ? 'RIDE PAUSED' : 'RECORDING ACTIVE'),
          actions: [
            IconButton(
              icon: const Icon(Icons.map_outlined, color: AppColors.primary),
              tooltip: 'View Live Route Map',
              onPressed: () => context.push('/live_map'),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Screen-Lock Protection Notice Pill
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: AppColors.surfaceElevated,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_clock,
                      size: 16,
                      color: isRecording ? AppColors.success : AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isRecording
                          ? 'Lock screen protected • Continuous GPS service'
                          : 'Recording Paused • Tap Resume to continue',
                      style: AppTypography.bodySmall.copyWith(
                        color: isRecording ? AppColors.textPrimary : AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Dual Digital Cluster (Speedometer & Live Tachometer)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: SpeedometerGauge(
                                    currentSpeedKmh: liveTelemetry.speedKmh,
                                    isGpsValid: activeRideState?.isGpsSignalValid ?? false,
                                    subtitle: isPaused
                                        ? 'PAUSED'
                                        : (activeRideState?.isGpsSignalValid == true
                                            ? 'GPS SPEED'
                                            : 'SEARCHING GPS'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
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
                          const SizedBox(height: 12),
                          // Live Odometer & Trip bar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('ODOMETER', style: AppTypography.badgeText),
                                      const SizedBox(height: 2),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '${liveTelemetry.totalOdometerKm.toStringAsFixed(1)} km',
                                          style: AppTypography.metricValue.copyWith(fontSize: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(height: 24, width: 1, color: AppColors.border),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('TRIP DISTANCE', style: AppTypography.badgeText),
                                      const SizedBox(height: 2),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '${liveTelemetry.tripDistanceKm.toStringAsFixed(2)} km',
                                          style: AppTypography.metricValue.copyWith(fontSize: 16, color: AppColors.primary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Battery & Electrical Status
                    BatteryStatusCard(
                      voltage: liveTelemetry.batteryVoltage,
                      batteryPercent: liveTelemetry.batteryPercent,
                      isCharging: liveTelemetry.batteryVoltage >= 13.6,
                      source: liveTelemetry.batterySource,
                    ),
                    const SizedBox(height: 14),

                    // Metrics Grid (Overflow-safe childAspectRatio 1.25)
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
                          value: AppFormatters.formatDistance(
                            activeRideState?.currentDistanceMeters ?? 0.0,
                          ),
                          icon: Icons.route,
                          provenance: TelemetrySource.gps,
                        ),
                        MetricTile(
                          label: 'Elapsed Time',
                          value: AppFormatters.formatDurationClock(
                            activeRideState?.elapsedSeconds ?? 0,
                          ),
                          icon: Icons.timer_outlined,
                          provenance: TelemetrySource.calculated,
                        ),
                        MetricTile(
                          label: 'Max Speed',
                          value: AppFormatters.formatSpeed(
                            activeRideState?.ride.maxSpeedKmh ?? 0.0,
                          ),
                          unit: 'km/h',
                          icon: Icons.speed,
                          provenance: TelemetrySource.gps,
                        ),
                        MetricTile(
                          label: 'Points Recorded',
                          value: '${activeRideState?.recentPoints.length ?? 0}',
                          icon: Icons.scatter_plot,
                          provenance: TelemetrySource.calculated,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Map Shortcut Card
                    InkWell(
                      onTap: () => context.push('/live_map'),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGlow,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.navigation, color: AppColors.primary),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Live Route Map', style: AppTypography.titleMedium),
                                  Text(
                                    '${activeRideState?.recentPoints.length ?? 0} route coordinates mapped',
                                    style: AppTypography.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textMuted),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Action Controls
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    // Pause / Resume
                    Expanded(
                      flex: 1,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: isPaused ? AppColors.success : AppColors.warning,
                            width: 1.5,
                          ),
                        ),
                        icon: Icon(
                          isPaused ? Icons.play_arrow : Icons.pause,
                          color: isPaused ? AppColors.success : AppColors.warning,
                        ),
                        label: Text(
                          isPaused ? 'RESUME' : 'PAUSE',
                          style: TextStyle(
                            color: isPaused ? AppColors.success : AppColors.warning,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          if (isPaused) {
                            trackingService.resumeRide();
                          } else {
                            trackingService.pauseRide();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    // End Ride
                    Expanded(
                      flex: 1,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.stop_rounded, size: 24),
                        label: const Text('END RIDE', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => _confirmEndRide(context, ref, trackingService),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmEndRide(
    BuildContext context,
    WidgetRef ref,
    RideTrackingService trackingService,
  ) async {
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('End Current Ride?'),
        content: const Text(
          'This will finalize the ride session, calculate statistics, save the route polyline, and offer to save your parked location.',
        ),
        actions: [
          TextButton(
            child: const Text('CANCEL'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('END RIDE'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (shouldEnd == true && context.mounted) {
      final ride = await trackingService.endRide(saveParking: true);
      ref.invalidate(allRidesProvider);
      ref.invalidate(latestParkingProvider);
      if (context.mounted) {
        context.pop(); // Return to dashboard
        if (ride != null) {
          context.push('/ride_detail/${ride.id}');
        }
      }
    }
  }
}
