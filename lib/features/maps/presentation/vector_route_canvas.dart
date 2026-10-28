import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/models/route_point.dart';

/// High-fidelity dark automotive vector route canvas.
/// Renders route polylines, start/end markers, and live vehicle heading
/// reliably even when Google Maps API key is unconfigured or phone is offline.
class VectorRouteCanvas extends StatelessWidget {
  final List<RoutePoint> points;
  final RoutePoint? currentPosition;
  final int? replayIndex;
  final String? statusNote;
  final VoidCallback? onConfigureApiKey;

  const VectorRouteCanvas({
    super.key,
    required this.points,
    this.currentPosition,
    this.replayIndex,
    this.statusNote,
    this.onConfigureApiKey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Stack(
        children: [
          // Custom Vector Grid & Route Painter
          CustomPaint(
            size: Size.infinite,
            painter: _VectorRoutePainter(
              points: points,
              replayIndex: replayIndex,
              currentPosition: currentPosition,
            ),
          ),

          // API Key Notice Banner
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.92),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      statusNote ??
                          'Vector GPS Map Active. To enable Google Maps road tiles, add your free API key in android/local.properties.',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                  if (onConfigureApiKey != null) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: onConfigureApiKey,
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: const Text('SETUP KEY', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Coordinate Stats Chip (Bottom Left)
          if (points.isNotEmpty)
            Positioned(
              bottom: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '${points.length} GPS Coordinates • Lat: ${points.last.latitude.toStringAsFixed(4)}, Lon: ${points.last.longitude.toStringAsFixed(4)}',
                  style: AppTypography.badgeText.copyWith(color: AppColors.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VectorRoutePainter extends CustomPainter {
  final List<RoutePoint> points;
  final int? replayIndex;
  final RoutePoint? currentPosition;

  _VectorRoutePainter({
    required this.points,
    this.replayIndex,
    this.currentPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw subtle radar/grid lines
    final gridPaint = Paint()
      ..color = AppColors.surfaceElevated.withOpacity(0.5)
      ..strokeWidth = 1.0;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (points.isEmpty && currentPosition == null) {
      _drawCenteredScooter(canvas, size);
      return;
    }

    // 2. Project Lat/Lng to Canvas Coordinates with bounding box normalization
    final allPoints = List<RoutePoint>.from(points);
    if (currentPosition != null && !allPoints.contains(currentPosition)) {
      allPoints.add(currentPosition!);
    }

    if (allPoints.isEmpty) return;

    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLon = allPoints.first.longitude;
    double maxLon = allPoints.first.longitude;

    for (final p in allPoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }

    final latRange = (maxLat - minLat).abs();
    final lonRange = (maxLon - minLon).abs();
    final effectiveLatRange = latRange < 0.001 ? 0.001 : latRange;
    final effectiveLonRange = lonRange < 0.001 ? 0.001 : lonRange;

    const padding = 48.0;
    final drawWidth = size.width - (padding * 2);
    final drawHeight = size.height - (padding * 2);

    Offset project(double lat, double lon) {
      final x = padding + ((lon - minLon) / effectiveLonRange) * drawWidth;
      // Invert Y so north is top
      final y = size.height - padding - (((lat - minLat) / effectiveLatRange) * drawHeight);
      return Offset(x, y);
    }

    // 3. Draw Route Polyline
    if (points.length >= 2) {
      final polyPaint = Paint()
        ..color = AppColors.primary
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final polyGlow = Paint()
        ..color = AppColors.primary.withOpacity(0.35)
        ..strokeWidth = 10.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

      final path = Path();
      bool first = true;
      for (final p in points) {
        if (p.isPaused) continue;
        final offset = project(p.latitude, p.longitude);
        if (first) {
          path.moveTo(offset.dx, offset.dy);
          first = false;
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }

      canvas.drawPath(path, polyGlow);
      canvas.drawPath(path, polyPaint);

      // Start Marker (Green Circle)
      final startOffset = project(points.first.latitude, points.first.longitude);
      canvas.drawCircle(startOffset, 8, Paint()..color = AppColors.success);
      canvas.drawCircle(startOffset, 12, Paint()..color = AppColors.success.withOpacity(0.3));

      // End Marker (Red Circle)
      final endOffset = project(points.last.latitude, points.last.longitude);
      canvas.drawCircle(endOffset, 8, Paint()..color = AppColors.error);
      canvas.drawCircle(endOffset, 12, Paint()..color = AppColors.error.withOpacity(0.3));
    }

    // 4. Draw Replay or Current Scooter Marker
    final activePt = (replayIndex != null && replayIndex! < points.length)
        ? points[replayIndex!]
        : (currentPosition ?? points.last);

    final scooterOffset = project(activePt.latitude, activePt.longitude);

    // Glowing Pulse
    canvas.drawCircle(
      scooterOffset,
      16,
      Paint()..color = AppColors.primary.withOpacity(0.35),
    );
    canvas.drawCircle(
      scooterOffset,
      9,
      Paint()..color = AppColors.primary,
    );
    canvas.drawCircle(
      scooterOffset,
      4,
      Paint()..color = Colors.white,
    );
  }

  void _drawCenteredScooter(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 24, Paint()..color = AppColors.primary.withOpacity(0.2));
    canvas.drawCircle(center, 12, Paint()..color = AppColors.primary);
    canvas.drawCircle(center, 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _VectorRoutePainter oldDelegate) {
    return oldDelegate.points.length != points.length ||
        oldDelegate.replayIndex != replayIndex ||
        oldDelegate.currentPosition != currentPosition;
  }
}

