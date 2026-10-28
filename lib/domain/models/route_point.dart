/// Geographic coordinate and speed recorded incrementally during a ride session.
class RoutePoint {
  final int? id;
  final String rideId;
  final double latitude;
  final double longitude;
  final double altitude;
  final double accuracy;
  final double speedKmh;
  final double bearing;
  final int timestamp;
  final bool isPaused;

  const RoutePoint({
    this.id,
    required this.rideId,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.accuracy,
    required this.speedKmh,
    required this.bearing,
    required this.timestamp,
    required this.isPaused,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'ride_id': rideId,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'speed_kmh': speedKmh,
      'bearing': bearing,
      'timestamp': timestamp,
      'is_paused': isPaused ? 1 : 0,
    };
  }

  factory RoutePoint.fromMap(Map<String, dynamic> map) {
    return RoutePoint(
      id: map['id'] as int?,
      rideId: map['ride_id'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      altitude: (map['altitude'] as num?)?.toDouble() ?? 0.0,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 999.0,
      speedKmh: (map['speed_kmh'] as num?)?.toDouble() ?? 0.0,
      bearing: (map['bearing'] as num?)?.toDouble() ?? 0.0,
      timestamp: map['timestamp'] as int,
      isPaused: (map['is_paused'] as int?) == 1,
    );
  }
}

