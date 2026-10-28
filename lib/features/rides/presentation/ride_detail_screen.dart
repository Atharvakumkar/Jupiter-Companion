import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/metric_tile.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/models/ride.dart';
import '../../../domain/models/route_point.dart';
import '../../../domain/models/telemetry.dart';
import '../../maps/presentation/vector_route_canvas.dart';
import '../../maps/utils/map_dark_style.dart';

class RideDetailScreen extends ConsumerStatefulWidget {
  final String rideId;

  const RideDetailScreen({super.key, required this.rideId});

  @override
  ConsumerState<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends ConsumerState<RideDetailScreen> {
  GoogleMapController? _mapController;
  int _replayIndex = 0;
  bool _useVectorEngine = true;

  @override
  Widget build(BuildContext context) {
    final rideRepo = ref.watch(rideRepositoryProvider);

    return FutureBuilder<Map<String, dynamic>>(
      future: _loadRideData(rideRepo),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('RIDE DETAILS')),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        final ride = snapshot.data!['ride'] as Ride?;
        final points = snapshot.data!['points'] as List<RoutePoint>;

        if (ride == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('RIDE DETAILS')),
            body: const Center(child: Text('Ride not found')),
          );
        }

        final polylineCoordinates = points
            .where((p) => !p.isPaused)
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();

        final markers = <Marker>{};
        if (polylineCoordinates.isNotEmpty) {
          // Start Marker
          markers.add(
            Marker(
              markerId: const MarkerId('start'),
              position: polylineCoordinates.first,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              infoWindow: const InfoWindow(title: 'Start Location'),
            ),
          );

          // End Marker
          markers.add(
            Marker(
              markerId: const MarkerId('end'),
              position: polylineCoordinates.last,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: const InfoWindow(title: 'End Location'),
            ),
          );

          // Replay Position Marker
          if (polylineCoordinates.length > _replayIndex) {
            final activePoint = points[_replayIndex];
            markers.add(
              Marker(
                markerId: const MarkerId('replay'),
                position: LatLng(activePoint.latitude, activePoint.longitude),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
                infoWindow: InfoWindow(
                  title: 'Replay Position',
                  snippet: '${activePoint.speedKmh.toStringAsFixed(1)} km/h',
                ),
              ),
            );
          }
        }

        final polylines = <Polyline>{
          Polyline(
            polylineId: const PolylineId('detail_polyline'),
            points: polylineCoordinates,
            color: AppColors.primary,
            width: 4,
            jointType: JointType.round,
          ),
        };

        final initialTarget = polylineCoordinates.isNotEmpty
            ? polylineCoordinates.first
            : const LatLng(12.9716, 77.5946);

        return Scaffold(
          appBar: AppBar(
            title: Text(AppFormatters.formatDateTime(ride.startTime)),
            actions: [
              IconButton(
                icon: Icon(
                  _useVectorEngine ? Icons.map_outlined : Icons.polyline_outlined,
                  color: AppColors.primary,
                ),
                tooltip: _useVectorEngine ? 'Switch to Google Maps' : 'Switch to Vector Canvas',
                onPressed: () => setState(() => _useVectorEngine = !_useVectorEngine),
              ),
              IconButton(
                icon: const Icon(Icons.help_outline, color: AppColors.textSecondary),
                tooltip: 'Maps Setup Guide',
                onPressed: () => _showApiKeyHelpDialog(context),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                tooltip: 'Delete Ride',
                onPressed: () => _confirmDelete(context, ride),
              ),
            ],
          ),
          body: ListView(
            children: [
              // Map Route Overview (Dual-Engine: Vector Route Canvas or Google Maps)
              SizedBox(
                height: 290,
                child: _useVectorEngine
                    ? VectorRouteCanvas(
                        points: points,
                        replayIndex: points.isNotEmpty ? _replayIndex : null,
                        statusNote:
                            'Vector Route Canvas • ${_useVectorEngine ? "Tap top Map icon to view Google Maps" : ""}',
                        onConfigureApiKey: () => _showApiKeyHelpDialog(context),
                      )
                    : GoogleMap(
                        initialCameraPosition: CameraPosition(target: initialTarget, zoom: 14.5),
                        markers: markers,
                        polylines: polylines,
                        zoomControlsEnabled: false,
                        myLocationButtonEnabled: false,
                        style: darkAutomotiveMapStyle,
                        onMapCreated: (ctrl) {
                          _mapController = ctrl;
                          if (polylineCoordinates.length >= 2) {
                            _fitBounds(polylineCoordinates);
                          }
                        },
                      ),
              ),

              // Route Replay Slider (when points exist)
              if (points.length > 1) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppColors.surfaceVariant,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('ROUTE REPLAY', style: AppTypography.badgeText),
                          Text(
                            'Point ${_replayIndex + 1}/${points.length} • Speed: ${points[_replayIndex].speedKmh.toStringAsFixed(1)} km/h',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.primary),
                          ),
                        ],
                      ),
                      Slider(
                        value: _replayIndex.toDouble(),
                        min: 0,
                        max: (points.length - 1).toDouble(),
                        activeColor: AppColors.primary,
                        inactiveColor: AppColors.border,
                        onChanged: (val) {
                          setState(() {
                            _replayIndex = val.toInt();
                          });
                          final p = points[_replayIndex];
                          if (!_useVectorEngine) {
                            _mapController?.animateCamera(
                              CameraUpdate.newLatLng(LatLng(p.latitude, p.longitude)),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],

              // Detailed Metrics Section (Overflow-safe childAspectRatio: 1.25)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('RIDE SUMMARY', style: AppTypography.titleSmall),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.25,
                      children: [
                        MetricTile(
                          label: 'Distance',
                          value: AppFormatters.formatDistance(ride.distanceMeters),
                          icon: Icons.route,
                          provenance: TelemetrySource.gps,
                        ),
                        MetricTile(
                          label: 'Total Duration',
                          value: AppFormatters.formatDurationClock(ride.durationSeconds),
                          icon: Icons.timer_outlined,
                          provenance: TelemetrySource.calculated,
                        ),
                        MetricTile(
                          label: 'Average Speed',
                          value: AppFormatters.formatSpeed(ride.avgSpeedKmh),
                          unit: 'km/h',
                          icon: Icons.speed,
                          provenance: TelemetrySource.gps,
                        ),
                        MetricTile(
                          label: 'Top Speed',
                          value: AppFormatters.formatSpeed(ride.maxSpeedKmh),
                          unit: 'km/h',
                          icon: Icons.bolt,
                          provenance: TelemetrySource.gps,
                        ),
                        MetricTile(
                          label: 'Moving Time',
                          value: AppFormatters.formatDurationClock(ride.movingDurationSeconds),
                          icon: Icons.moving,
                          provenance: TelemetrySource.calculated,
                        ),
                        MetricTile(
                          label: 'Points Tracked',
                          value: '${ride.pointsCount}',
                          icon: Icons.scatter_plot,
                          provenance: TelemetrySource.calculated,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _loadRideData(dynamic rideRepo) async {
    final ride = await rideRepo.getRideById(widget.rideId);
    final points = await rideRepo.getRoutePoints(widget.rideId);
    return {'ride': ride, 'points': points};
  }

  void _fitBounds(List<LatLng> coords) {
    if (coords.isEmpty || _mapController == null) return;
    double minLat = coords.first.latitude;
    double maxLat = coords.first.latitude;
    double minLng = coords.first.longitude;
    double maxLng = coords.first.longitude;

    for (final c in coords) {
      if (c.latitude < minLat) minLat = c.latitude;
      if (c.latitude > maxLat) maxLat = c.latitude;
      if (c.longitude < minLng) minLng = c.longitude;
      if (c.longitude > maxLng) maxLng = c.longitude;
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50.0,
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
            Text('Google Maps Setup'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'To view Google Maps satellite and road layers:',
                style: AppTypography.titleSmall,
              ),
              SizedBox(height: 8),
              Text(
                '1. Go to Google Cloud Console > Credentials.\n'
                '2. Create an Android API Key (enable "Maps SDK for Android").\n'
                '3. Open android/local.properties and add:\n'
                '   MAPS_API_KEY=AIzaSyYourActualKeyHere\n'
                '4. Rebuild the app with "flutter build apk --debug".',
                style: AppTypography.bodySmall,
              ),
              SizedBox(height: 12),
              Text(
                'Notice: Vector Route Canvas works 100% offline without any API keys!',
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

  Future<void> _confirmDelete(BuildContext context, Ride ride) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Ride Record?'),
        content: const Text(
          'Are you sure you want to permanently delete this ride and all associated GPS route points? This cannot be undone.',
        ),
        actions: [
          TextButton(
            child: const Text('CANCEL'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('DELETE'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (shouldDelete == true && context.mounted) {
      final rideRepo = ref.read(rideRepositoryProvider);
      await rideRepo.deleteRide(ride.id);
      ref.invalidate(allRidesProvider);
      if (context.mounted) {
        context.pop();
      }
    }
  }
}
