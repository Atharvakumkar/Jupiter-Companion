import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../utils/map_dark_style.dart';
import 'vector_route_canvas.dart';

class LiveRouteMapScreen extends ConsumerStatefulWidget {
  const LiveRouteMapScreen({super.key});

  @override
  ConsumerState<LiveRouteMapScreen> createState() => _LiveRouteMapScreenState();
}

class _LiveRouteMapScreenState extends ConsumerState<LiveRouteMapScreen> {
  GoogleMapController? _mapController;
  bool _followRider = true;
  bool _useVectorCanvas = false;

  @override
  Widget build(BuildContext context) {
    final activeRideState = ref.watch(activeRideStateProvider).valueOrNull;
    final points = activeRideState?.recentPoints ?? [];

    final initialTarget = points.isNotEmpty
        ? LatLng(points.last.latitude, points.last.longitude)
        : const LatLng(12.9716, 77.5946); // Default coordinate

    final polylinePoints = points
        .where((p) => !p.isPaused)
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    final markers = <Marker>{};
    if (points.isNotEmpty) {
      final lastPoint = points.last;
      markers.add(
        Marker(
          markerId: const MarkerId('current_scooter'),
          position: LatLng(lastPoint.latitude, lastPoint.longitude),
          rotation: lastPoint.bearing,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          infoWindow: InfoWindow(
            title: 'TVS Jupiter',
            snippet: '${lastPoint.speedKmh.toStringAsFixed(1)} km/h • ±${lastPoint.accuracy.toStringAsFixed(0)}m',
          ),
        ),
      );

      // Auto-center camera if follow mode is active
      if (_followRider && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(LatLng(lastPoint.latitude, lastPoint.longitude)),
        );
      }
    }

    final polylines = <Polyline>{
      Polyline(
        polylineId: const PolylineId('active_ride_polyline'),
        points: polylinePoints,
        color: AppColors.primary,
        width: 5,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('LIVE ROUTE MAP'),
        actions: [
          // Engine Switcher: Vector Canvas vs Google Maps
          IconButton(
            icon: Icon(
              _useVectorCanvas ? Icons.layers_outlined : Icons.map_outlined,
              color: AppColors.primary,
            ),
            tooltip: _useVectorCanvas ? 'Switch to Google Maps' : 'Switch to Vector Canvas',
            onPressed: () {
              setState(() {
                _useVectorCanvas = !_useVectorCanvas;
              });
            },
          ),
          IconButton(
            icon: Icon(
              _followRider ? Icons.gps_fixed : Icons.gps_not_fixed,
              color: _followRider ? AppColors.primary : AppColors.textMuted,
            ),
            tooltip: _followRider ? 'Following Rider' : 'Free Camera',
            onPressed: () {
              setState(() {
                _followRider = !_followRider;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Primary Map View: Vector Route Canvas or Google Maps
          if (_useVectorCanvas) ...[
            VectorRouteCanvas(
              points: points,
              currentPosition: points.isNotEmpty ? points.last : null,
              onConfigureApiKey: () => _showApiKeyHelpDialog(context),
            ),
          ] else ...[
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialTarget,
                zoom: 16.0,
              ),
              markers: markers,
              polylines: polylines,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: true,
              style: darkAutomotiveMapStyle,
              onMapCreated: (controller) {
                _mapController = controller;
              },
            ),
          ],

          // Floating Telemetry Overlay HUD (Guaranteed no overflow)
          Positioned(
            top: _useVectorCanvas ? 65 : 14,
            left: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            AppFormatters.formatSpeed(
                              activeRideState?.currentGpsSpeed.value ?? 0.0,
                            ),
                            style: AppTypography.metricValue.copyWith(color: AppColors.primary),
                          ),
                        ),
                        const Text('SPEED (KM/H)', style: AppTypography.metricLabel),
                      ],
                    ),
                  ),
                  Container(height: 24, width: 1, color: AppColors.border),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            AppFormatters.formatDistance(
                              activeRideState?.currentDistanceMeters ?? 0.0,
                            ),
                            style: AppTypography.metricValue,
                          ),
                        ),
                        const Text('DISTANCE', style: AppTypography.metricLabel),
                      ],
                    ),
                  ),
                  Container(height: 24, width: 1, color: AppColors.border),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            AppFormatters.formatDurationClock(
                              activeRideState?.elapsedSeconds ?? 0,
                            ),
                            style: AppTypography.metricValue,
                          ),
                        ),
                        const Text('DURATION', style: AppTypography.metricLabel),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Zoom Controls
          if (!_useVectorCanvas)
            Positioned(
              bottom: 24,
              right: 16,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'zoom_in',
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.textPrimary,
                    child: const Icon(Icons.add),
                    onPressed: () => _mapController?.animateCamera(CameraUpdate.zoomIn()),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'zoom_out',
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.textPrimary,
                    child: const Icon(Icons.remove),
                    onPressed: () => _mapController?.animateCamera(CameraUpdate.zoomOut()),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showApiKeyHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.map, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Enable Google Maps'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'To view Google Maps road & satellite tiles:',
                style: AppTypography.titleSmall,
              ),
              SizedBox(height: 8),
              Text(
                '1. Go to Google Cloud Console > APIs & Services > Credentials.\n'
                '2. Create an API Key and enable "Maps SDK for Android".\n'
                '3. Open android/local.properties in your project and add:\n'
                '   MAPS_API_KEY=AIzaSyYourActualKeyHere\n'
                '4. Rebuild the app with "flutter build apk --debug".',
                style: AppTypography.bodySmall,
              ),
              SizedBox(height: 12),
              Text(
                'In the meantime, the Vector GPS Map tracks your exact ride coordinates with 100% precision!',
                style: TextStyle(color: AppColors.primary, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            child: const Text('GOT IT'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }
}
