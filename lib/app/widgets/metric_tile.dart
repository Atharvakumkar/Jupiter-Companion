import 'package:flutter/material.dart';
import '../../domain/models/telemetry.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'provenance_badge.dart';

class MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData? icon;
  final TelemetrySource? provenance;
  final Color? accentColor;

  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.provenance,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 15, color: accentColor ?? AppColors.primary),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: Text(
                        label.toUpperCase(),
                        style: AppTypography.metricLabel,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (provenance != null) ...[
                const SizedBox(width: 4),
                ProvenanceBadge(source: provenance!),
              ],
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: AppTypography.metricValue.copyWith(
                    color: accentColor ?? AppColors.textPrimary,
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    unit!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
