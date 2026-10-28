import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/models/fuel_log.dart';

class FuelExpenseScreen extends ConsumerWidget {
  const FuelExpenseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fuelLogsAsync = ref.watch(fuelLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FUEL & EXPENSES'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.background,
        child: const Icon(Icons.local_gas_station),
        onPressed: () => _showAddFuelDialog(context, ref),
      ),
      body: fuelLogsAsync.when(
        data: (logs) {
          final totalSpent = logs.fold<double>(0.0, (acc, l) => acc + l.totalCost);
          final totalLiters = logs.fold<double>(0.0, (acc, l) => acc + l.liters);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(fuelLogsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Fuel Analytics Card
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
                            const Text('TOTAL FUEL', style: AppTypography.metricLabel),
                          ],
                        ),
                      ),
                      Container(height: 30, width: 1, color: AppColors.border),
                      Expanded(
                        child: Column(
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('${totalLiters.toStringAsFixed(1)} L', style: AppTypography.metricValue),
                            ),
                            const SizedBox(height: 4),
                            const Text('TOTAL VOLUME', style: AppTypography.metricLabel),
                          ],
                        ),
                      ),
                      Container(height: 30, width: 1, color: AppColors.border),
                      Expanded(
                        child: Column(
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('${logs.length}', style: AppTypography.metricValue),
                            ),
                            const SizedBox(height: 4),
                            const Text('REFUELS', style: AppTypography.metricLabel),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Text('REFUEL HISTORY', style: AppTypography.metricLabel),
                const SizedBox(height: 8),

                if (logs.isEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No fuel refuels logged yet. Tap + to record your first petrol receipt.',
                        style: AppTypography.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ] else ...[
                  ...logs.map((log) => _buildFuelLogCard(context, ref, log)),
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

  Widget _buildFuelLogCard(
    BuildContext context,
    WidgetRef ref,
    FuelLog log,
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
                    const Icon(Icons.local_gas_station, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${log.liters.toStringAsFixed(2)} Liters',
                      style: AppTypography.titleMedium,
                    ),
                  ],
                ),
                Text(
                  AppFormatters.formatCurrency(log.totalCost),
                  style: AppTypography.titleMedium.copyWith(color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Date: ${AppFormatters.formatDate(log.date)} • Rate: ₹${log.costPerLiter.toStringAsFixed(2)}/L',
              style: AppTypography.bodySmall,
            ),
            if (log.odometerKm != null) ...[
              const SizedBox(height: 4),
              Text(
                'Odometer: ${log.odometerKm!.toStringAsFixed(0)} km',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
            ],
            if (log.fuelStation != null && log.fuelStation!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Station: ${log.fuelStation}', style: AppTypography.bodySmall),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (log.calculatedEconomyKmpl != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.successGlow,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Economy: ${log.calculatedEconomyKmpl!.toStringAsFixed(1)} km/L',
                      style: AppTypography.badgeText.copyWith(color: AppColors.success),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textMuted),
                  onPressed: () async {
                    final repo = ref.read(fuelExpenseRepositoryProvider);
                    await repo.deleteFuelLog(log.id);
                    ref.invalidate(fuelLogsProvider);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddFuelDialog(BuildContext context, WidgetRef ref) async {
    final costController = TextEditingController();
    final litersController = TextEditingController();
    final odoController = TextEditingController();
    final stationController = TextEditingController(text: 'IndianOil / HP / BPCL');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Add Fuel Receipt'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: costController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Total Cost (₹)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: litersController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Fuel Volume (Liters)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: odoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Odometer (km) - Optional'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: stationController,
                decoration: const InputDecoration(labelText: 'Fuel Station / Notes'),
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
              final totalCost = double.tryParse(costController.text) ?? 0.0;
              final liters = double.tryParse(litersController.text) ?? 0.0;
              final odo = double.tryParse(odoController.text);

              if (totalCost <= 0 || liters <= 0) return;

              final costPerL = totalCost / liters;
              final log = FuelLog(
                id: 'fuel_${DateTime.now().millisecondsSinceEpoch}',
                date: DateTime.now(),
                liters: liters,
                totalCost: totalCost,
                costPerLiter: costPerL,
                odometerKm: odo,
                fuelStation: stationController.text.trim(),
              );

              final repo = ref.read(fuelExpenseRepositoryProvider);
              await repo.saveFuelLog(log);
              ref.invalidate(fuelLogsProvider);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }
}

