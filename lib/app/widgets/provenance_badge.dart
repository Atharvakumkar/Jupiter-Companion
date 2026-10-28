import 'package:flutter/material.dart';
import '../../domain/models/telemetry.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class ProvenanceBadge extends StatelessWidget {
  final TelemetrySource source;
  final String? customLabel;

  const ProvenanceBadge({
    super.key,
    required this.source,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    Color textColor;
    String label;

    switch (source) {
      case TelemetrySource.gps:
        badgeColor = AppColors.provenanceGps.withOpacity(0.15);
        textColor = AppColors.provenanceGps;
        label = customLabel ?? 'GPS';
        break;
      case TelemetrySource.verifiedEcu:
        badgeColor = AppColors.provenanceEcu.withOpacity(0.15);
        textColor = AppColors.provenanceEcu;
        label = customLabel ?? 'ECU VERIFIED';
        break;
      case TelemetrySource.calculated:
        badgeColor = AppColors.provenanceCalculated.withOpacity(0.15);
        textColor = AppColors.provenanceCalculated;
        label = customLabel ?? 'CALCULATED';
        break;
      case TelemetrySource.userManual:
        badgeColor = AppColors.provenanceManual.withOpacity(0.15);
        textColor = AppColors.provenanceManual;
        label = customLabel ?? 'USER ENTRY';
        break;
      case TelemetrySource.unavailable:
        badgeColor = AppColors.provenanceUnavailable.withOpacity(0.15);
        textColor = AppColors.provenanceUnavailable;
        label = customLabel ?? 'UNAVAILABLE';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withOpacity(0.4), width: 1),
      ),
      child: Text(
        label,
        style: AppTypography.badgeText.copyWith(color: textColor),
      ),
    );
  }
}

