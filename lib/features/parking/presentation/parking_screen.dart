import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/models/parking_location.dart';
import '../../maps/utils/map_dark_style.dart';

class ParkingScreen extends ConsumerStatefulWidget {
  const ParkingScreen({super.key});

  @override
  ConsumerState<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends ConsumerState<ParkingScreen> {
  GoogleMapController? _mapController;
  bool _isSavingLocation = false;

  @override
  Widget build(BuildContext context) {
    final parkingAsync = ref.watch(latestParkingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PARKING LOCATION'),
        actions: [
          if (_isSavingLocation)
            const Padding(
              padding: EdgeInsets.all(14.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.my_location, color: AppColors.primary),
              tooltip: 'Save Current Location as Parking',
              onPressed: _saveCurrentPhoneLocation,
            ),
        ],
      ),
      body: parkingAsync.when(
        data: (parking) {
          final target = parking != null
              ? LatLng(parking.latitude, parking.longitude)
              : const LatLng(12.9716, 77.5946);

          final markers = <Marker>{};
          if (parking != null) {
            markers.add(
              Marker(
                markerId: const MarkerId('saved_parking'),
                position: target,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                infoWindow: InfoWindow(
                  title: 'Parked Scooter',
                  snippet: AppFormatters.formatDateTime(parking.timestamp),
                ),
              ),
            );
          }

          return Column(
            children: [
              // Notice banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: AppColors.surfaceVariant,
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Phone GNSS location recorded when saved. Does not imply live remote scooter tracking.',
                        style: AppTypography.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),

              // Embedded Map
              Expanded(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(target: target, zoom: 16.5),
                  markers: markers,
                  style: darkAutomotiveMapStyle,
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  onMapCreated: (ctrl) => _mapController = ctrl,
                ),
              ),

              // Bottom Details Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (parking == null) ...[
                      const Text(
                        'No parking location recorded.',
                        style: AppTypography.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tap the button below to mark where you parked your TVS Jupiter.',
                        style: AppTypography.bodySmall,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add_location_alt),
                          label: const Text('SAVE CURRENT PARKING LOCATION'),
                          onPressed: _saveCurrentPhoneLocation,
                        ),
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  parking.note ?? 'Parked Vehicle',
                                  style: AppTypography.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Saved ${AppFormatters.formatDateTime(parking.timestamp)}',
                                  style: AppTypography.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.error),
                            onPressed: () async {
                              final repo = ref.read(parkingRepositoryProvider);
                              await repo.deleteParkingLocation(parking.id);
                              ref.invalidate(latestParkingProvider);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.my_location, color: AppColors.primary),
                              label: const Text('UPDATE SPOT'),
                              onPressed: _saveCurrentPhoneLocation,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.directions),
                              label: const Text('DIRECTIONS'),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Coordinates: ${parking.latitude.toStringAsFixed(5)}, ${parking.longitude.toStringAsFixed(5)}',
                                    ),
                                    backgroundColor: AppColors.surfaceElevated,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Future<void> _saveCurrentPhoneLocation() async {
    setState(() => _isSavingLocation = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final parking = ParkingLocation(
        id: 'park_${DateTime.now().millisecondsSinceEpoch}',
        latitude: pos.latitude,
        longitude: pos.longitude,
        timestamp: DateTime.now(),
        accuracyMeters: pos.accuracy,
        note: 'Parked Spot (${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')})',
      );

      final repo = ref.read(parkingRepositoryProvider);
      await repo.saveParkingLocation(parking);
      ref.invalidate(latestParkingProvider);

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 17.0),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parking location saved!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingLocation = false);
    }
  }
}
