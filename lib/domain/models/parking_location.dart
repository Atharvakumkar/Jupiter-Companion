/// Saved vehicle parking coordinate (phone GNSS location at time of save).
class ParkingLocation {
  final String id;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String? note;
  final double? accuracyMeters;
  final String? addressPreview;
  final String? associatedRideId;

  const ParkingLocation({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.note,
    this.accuracyMeters,
    this.addressPreview,
    this.associatedRideId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'note': note,
      'accuracy_meters': accuracyMeters,
      'address_preview': addressPreview,
      'associated_ride_id': associatedRideId,
    };
  }

  factory ParkingLocation.fromMap(Map<String, dynamic> map) {
    return ParkingLocation(
      id: map['id'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      note: map['note'] as String?,
      accuracyMeters: (map['accuracy_meters'] as num?)?.toDouble(),
      addressPreview: map['address_preview'] as String?,
      associatedRideId: map['associated_ride_id'] as String?,
    );
  }
}

