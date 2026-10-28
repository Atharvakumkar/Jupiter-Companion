import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/models/ride.dart';

class RideHistoryScreen extends ConsumerStatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  ConsumerState<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends ConsumerState<RideHistoryScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final ridesAsync = ref.watch(allRidesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('RIDE HISTORY & ANALYTICS'),
      ),
      body: ridesAsync.when(
        data: (rides) {
          final completedRides = rides
              .where((r) => r.status == RideStatus.completed)
              .where((r) {
                if (_searchQuery.isEmpty) return true;
                final dateStr = AppFormatters.formatDate(r.startTime).toLowerCase();
                return dateStr.contains(_searchQuery.toLowerCase());
              })
              .toList();

          final totalDistanceMeters = rides.fold<double>(
            0.0,
            (acc, r) => acc + (r.status == RideStatus.completed ? r.distanceMeters : 0.0),
          );
          final totalDurationSec = rides.fold<int>(
            0,
            (acc, r) => acc + (r.status == RideStatus.completed ? r.durationSeconds : 0),
          );
          final completedCount = rides.where((r) => r.status == RideStatus.completed).length;

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(allRidesProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Analytics Summary Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ALL-TIME SCOOTER STATISTICS', style: AppTypography.titleSmall),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatColumn(
                            'TOTAL DISTANCE',
                            AppFormatters.formatDistance(totalDistanceMeters),
                            AppColors.primary,
                          ),
                          Container(height: 30, width: 1, color: AppColors.border),
                          _buildStatColumn(
                            'RIDES',
                            '$completedCount',
                            AppColors.textPrimary,
                          ),
                          Container(height: 30, width: 1, color: AppColors.border),
                          _buildStatColumn(
                            'HOURS',
                            '${(totalDurationSec / 3600).toStringAsFixed(1)} h',
                            AppColors.textPrimary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Search Bar
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search rides by date (e.g. Oct, 2026)...',
                    prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 16),

                // Completed Rides List
                if (completedRides.isEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No recorded rides found. Start your first ride from Dashboard!',
                        style: AppTypography.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ] else ...[
                  ...completedRides.map((ride) => _buildRideCard(context, ride)),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading history: $err')),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: AppTypography.metricValue.copyWith(color: color)),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.badgeText.copyWith(color: AppColors.textMuted)),
      ],
    );
  }

  Widget _buildRideCard(BuildContext context, Ride ride) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/ride_detail/${ride.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.two_wheeler, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        AppFormatters.formatDateTime(ride.startTime),
                        style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: ride.source == RecordingSource.manual
                          ? AppColors.primaryGlow
                          : AppColors.accentIndigo.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ride.source == RecordingSource.manual ? 'MANUAL' : 'AUTO',
                      style: AppTypography.badgeText.copyWith(
                        color: ride.source == RecordingSource.manual
                            ? AppColors.primary
                            : AppColors.accentIndigo,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            AppFormatters.formatDistance(ride.distanceMeters),
                            style: AppTypography.metricValue,
                          ),
                        ),
                        const Text('DISTANCE', style: AppTypography.metricLabel),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            AppFormatters.formatDurationClock(ride.durationSeconds),
                            style: AppTypography.metricValue,
                          ),
                        ),
                        const Text('DURATION', style: AppTypography.metricLabel),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${ride.maxSpeedKmh.toStringAsFixed(0)} km/h',
                            style: AppTypography.metricValue,
                          ),
                        ),
                        const Text('MAX SPEED', style: AppTypography.metricLabel),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

