import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Digital Tachometer gauge displaying live engine RPM for TVS Jupiter 110.
/// Visualizes Eco zone (0-5k), Power zone (5k-7.5k), and Redline zone (7.5k-9k).
class TachometerGauge extends StatelessWidget {
  final int currentRpm;
  final int maxRpm;
  final bool isConnected;
  final String? sourceLabel;

  const TachometerGauge({
    super.key,
    required this.currentRpm,
    this.maxRpm = 9000,
    required this.isConnected,
    this.sourceLabel,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (currentRpm / maxRpm).clamp(0.0, 1.0);

    // Color logic based on TVS Econometer
    Color zoneColor;
    String zoneName;
    if (currentRpm < 5000) {
      zoneColor = AppColors.success;
      zoneName = 'ECO MODE';
    } else if (currentRpm < 7500) {
      zoneColor = AppColors.warning;
      zoneName = 'POWER MODE';
    } else {
      zoneColor = AppColors.error;
      zoneName = 'REDLINE';
    }

    return SizedBox(
      height: 200,
      width: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(200, 200),
            painter: _TachometerArcPainter(
              progress: isConnected ? progress : 0.0,
              activeColor: isConnected ? zoneColor : AppColors.provenanceUnavailable,
              trackColor: AppColors.surfaceElevated,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isConnected ? currentRpm.toString() : '---',
                style: AppTypography.clusterSpeed.copyWith(
                  fontSize: 38,
                  color: isConnected ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
              Text(
                'RPM',
                style: AppTypography.clusterSpeedUnit.copyWith(
                  color: isConnected ? zoneColor : AppColors.textMuted,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (isConnected ? zoneColor : AppColors.provenanceUnavailable).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isConnected ? zoneName : (sourceLabel ?? 'NO STREAM'),
                  style: AppTypography.badgeText.copyWith(
                    color: isConnected ? zoneColor : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TachometerArcPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color trackColor;

  _TachometerArcPainter({
    required this.progress,
    required this.activeColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 16;
    const strokeWidth = 12.0;

    const startAngle = 135 * (math.pi / 180.0);
    const totalSweep = 270 * (math.pi / 180.0);

    // Background Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      trackPaint,
    );

    // Active RPM Sweep
    if (progress > 0) {
      final activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final glowPaint = Paint()
        ..color = activeColor.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        totalSweep * progress,
        false,
        glowPaint,
      );

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        totalSweep * progress,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TachometerArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.trackColor != trackColor;
  }
}

