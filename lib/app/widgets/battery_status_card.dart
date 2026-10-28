import 'package:flutter/material.dart';
import '../../domain/models/telemetry.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'provenance_badge.dart';

class BatteryStatusCard extends StatelessWidget {
  final double voltage;
  final int batteryPercent;
  final bool isCharging;
  final TelemetrySource source;

  const BatteryStatusCard({
    super.key,
    required this.voltage,
    required this.batteryPercent,
    this.isCharging = false,
    this.source = TelemetrySource.calculated,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;

    if (voltage >= 13.8) {
      statusColor = AppColors.success;
      statusText = 'CHARGING (ALTERNATOR)';
    } else if (voltage >= 12.4) {
      statusColor = AppColors.primary;
      statusText = 'HEALTHY (12V LEAD-ACID)';
    } else if (voltage >= 11.8) {
      statusColor = AppColors.warning;
      statusText = 'LOW CHARGE';
    } else {
      statusColor = AppColors.error;
      statusText = 'CRITICAL VOLTAGE';
    }

    return Container(
      padding: const EdgeInsets.all(14),
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
              Row(
                children: [
                  Icon(Icons.battery_charging_full, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  const Text('ELECTRICAL & BATTERY', style: AppTypography.titleSmall),
                ],
              ),
              ProvenanceBadge(source: source),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Voltage Meter
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${voltage.toStringAsFixed(1)} V',
                      style: AppTypography.metricValue.copyWith(color: statusColor),
                    ),
                    const SizedBox(height: 2),
                    Text(statusText, style: AppTypography.badgeText.copyWith(color: statusColor)),
                  ],
                ),
              ),
              Container(height: 36, width: 1, color: AppColors.border),
              const SizedBox(width: 14),

              // Battery Percent Meter
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('$batteryPercent%', style: AppTypography.metricValue),
                        if (isCharging) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.bolt, size: 16, color: AppColors.success),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text('STATE OF CHARGE', style: AppTypography.metricLabel),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (batteryPercent / 100.0).clamp(0.0, 1.0),
              backgroundColor: AppColors.surfaceElevated,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

