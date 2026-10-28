import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class SpeedometerGauge extends StatelessWidget {
  final double currentSpeedKmh;
  final double maxGaugeSpeedKmh;
  final bool isGpsValid;
  final String? subtitle;

  const SpeedometerGauge({
    super.key,
    required this.currentSpeedKmh,
    this.maxGaugeSpeedKmh = 100.0,
    required this.isGpsValid,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (currentSpeedKmh / maxGaugeSpeedKmh).clamp(0.0, 1.0);

    return SizedBox(
      height: 220,
      width: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(220, 220),
            painter: _SpeedometerArcPainter(
              progress: progress,
              arcColor: isGpsValid ? AppColors.primary : AppColors.provenanceUnavailable,
              trackColor: AppColors.surfaceElevated,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isGpsValid ? currentSpeedKmh.toStringAsFixed(0) : '--',
                style: AppTypography.clusterSpeed.copyWith(
                  color: isGpsValid ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
              const Text('KM/H', style: AppTypography.clusterSpeedUnit),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (isGpsValid ? AppColors.provenanceGps : AppColors.warning)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  subtitle ?? (isGpsValid ? 'GPS LIVE' : 'ACQUIRING GPS'),
                  style: AppTypography.badgeText.copyWith(
                    color: isGpsValid ? AppColors.provenanceGps : AppColors.warning,
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

class _SpeedometerArcPainter extends CustomPainter {
  final double progress;
  final Color arcColor;
  final Color trackColor;

  _SpeedometerArcPainter({
    required this.progress,
    required this.arcColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 16;
    const strokeWidth = 14.0;

    // Start angle: 135 deg (3*pi/4), Sweep: 270 deg (3*pi/2)
    const startAngle = 135 * (math.pi / 180.0);
    const totalSweep = 270 * (math.pi / 180.0);

    // Track Paint
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

    // Active Arc Paint
    if (progress > 0) {
      final activePaint = Paint()
        ..color = arcColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      // Glow effect
      final glowPaint = Paint()
        ..color = arcColor.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

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
  bool shouldRepaint(covariant _SpeedometerArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.arcColor != arcColor ||
        oldDelegate.trackColor != trackColor;
  }
}

