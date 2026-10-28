import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/models/maintenance_record.dart';
import '../../../domain/models/telemetry.dart';

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(maintenanceRecordsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MAINTENANCE & SERVICE'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.background,
        child: const Icon(Icons.add),
        onPressed: () => _showAddRecordDialog(context, ref),
      ),
      body: recordsAsync.when(
        data: (records) {
          final totalSpent = records.fold<double>(0.0, (acc, r) => acc + r.cost);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(maintenanceRecordsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Cost & Intervals Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                AppFormatters.formatCurrency(totalSpent),
                                style: AppTypography.metricValue.copyWith(color: AppColors.primary),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text('TOTAL SERVICE COST', style: AppTypography.metricLabel),
                          ],
                        ),
                      ),
                      Container(height: 30, width: 1, color: AppColors.border),
                      Expanded(
                        child: Column(
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('${records.length}', style: AppTypography.metricValue),
                            ),
                            const SizedBox(height: 4),
                            const Text('RECORDS LOGGED', style: AppTypography.metricLabel),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // TVS Jupiter Recommended Intervals Guidance
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text('TVS JUPITER SERVICE SCHEDULE', style: AppTypography.titleSmall),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        '• 1st Service: 500-750 km (1 month)\n• Regular Service: Every 3,000 km or 90 days\n• Engine Oil: 10W-30 (750-800 ml)\n• Recommended Tyre Pressure: 25 PSI Front / 36 PSI Rear',
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Text('SERVICE HISTORY', style: AppTypography.metricLabel),
                const SizedBox(height: 8),

                if (records.isEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No maintenance records logged yet. Tap + to record a service or oil change.',
                        style: AppTypography.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ] else ...[
                  ...records.map((r) => _buildRecordCard(context, ref, r)),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildRecordCard(
    BuildContext context,
    WidgetRef ref,
    MaintenanceRecord r,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                    const Icon(Icons.build, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(r.taskType, style: AppTypography.titleMedium),
                  ],
                ),
                Text(
                  AppFormatters.formatCurrency(r.cost),
                  style: AppTypography.titleMedium.copyWith(color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Date: ${AppFormatters.formatDate(r.date)} • Odometer: ${r.odometerKm.toStringAsFixed(0)} km',
              style: AppTypography.bodySmall,
            ),
            if (r.notes != null && r.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(r.notes!, style: AppTypography.bodyMedium),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (r.nextDueKm != null)
                  Text(
                    'Next due: ${r.nextDueKm!.toStringAsFixed(0)} km',
                    style: AppTypography.badgeText.copyWith(color: AppColors.textSecondary),
                  )
                else
                  const SizedBox.shrink(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textMuted),
                  onPressed: () async {
                    final repo = ref.read(maintenanceRepositoryProvider);
                    await repo.deleteRecord(r.id);
                    ref.invalidate(maintenanceRecordsProvider);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddRecordDialog(BuildContext context, WidgetRef ref) async {
    final taskController = TextEditingController(text: 'Engine Oil Replacement');
    final costController = TextEditingController();
    final odoController = TextEditingController();
    final notesController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Add Maintenance Record'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: taskController,
                decoration: const InputDecoration(labelText: 'Task Type'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: odoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Odometer (km)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: costController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cost (₹)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes / Service Center'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('CANCEL'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: const Text('SAVE'),
            onPressed: () async {
              final odo = double.tryParse(odoController.text) ?? 0.0;
              final cost = double.tryParse(costController.text) ?? 0.0;
              final record = MaintenanceRecord(
                id: 'maint_${DateTime.now().millisecondsSinceEpoch}',
                date: DateTime.now(),
                odometerKm: odo,
                odometerSource: TelemetrySource.userManual,
                taskType: taskController.text.trim(),
                cost: cost,
                notes: notesController.text.trim(),
                nextDueKm: odo + 3000.0,
                nextDueDate: DateTime.now().add(const Duration(days: 90)),
              );

              final repo = ref.read(maintenanceRepositoryProvider);
              await repo.saveRecord(record);
              ref.invalidate(maintenanceRecordsProvider);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }
}

