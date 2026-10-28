enum RideStatus {
  idle,
  starting,
  recording,
  paused,
  finalizing,
  completed,
  error,
}

enum RecordingSource {
  manual,
  automatic,
}

/// Durable model representing a TVS Jupiter scooter ride session.
class Ride {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final int movingDurationSeconds;
  final double distanceMeters;
  final double maxSpeedKmh;
  final double avgSpeedKmh;
  final RideStatus status;
  final RecordingSource source;
  final int pointsCount;
  final bool isSynced;
  final DateTime? lastSyncTime;
  final String? startAddress;
  final String? endAddress;

  const Ride({
    required this.id,
    required this.startTime,
    this.endTime,
    this.durationSeconds = 0,
    this.movingDurationSeconds = 0,
    this.distanceMeters = 0.0,
    this.maxSpeedKmh = 0.0,
    this.avgSpeedKmh = 0.0,
    this.status = RideStatus.idle,
    this.source = RecordingSource.manual,
    this.pointsCount = 0,
    this.isSynced = false,
    this.lastSyncTime,
    this.startAddress,
    this.endAddress,
  });

  Ride copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    int? movingDurationSeconds,
    double? distanceMeters,
    double? maxSpeedKmh,
    double? avgSpeedKmh,
    RideStatus? status,
    RecordingSource? source,
    int? pointsCount,
    bool? isSynced,
    DateTime? lastSyncTime,
    String? startAddress,
    String? endAddress,
  }) {
    return Ride(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      movingDurationSeconds: movingDurationSeconds ?? this.movingDurationSeconds,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
      avgSpeedKmh: avgSpeedKmh ?? this.avgSpeedKmh,
      status: status ?? this.status,
      source: source ?? this.source,
      pointsCount: pointsCount ?? this.pointsCount,
      isSynced: isSynced ?? this.isSynced,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      startAddress: startAddress ?? this.startAddress,
      endAddress: endAddress ?? this.endAddress,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime?.millisecondsSinceEpoch,
      'duration_seconds': durationSeconds,
      'moving_duration_seconds': movingDurationSeconds,
      'distance_meters': distanceMeters,
      'max_speed_kmh': maxSpeedKmh,
      'avg_speed_kmh': avgSpeedKmh,
      'status': status.name,
      'source': source.name,
      'points_count': pointsCount,
      'is_synced': isSynced ? 1 : 0,
      'last_sync_time': lastSyncTime?.millisecondsSinceEpoch,
      'start_address': startAddress,
      'end_address': endAddress,
    };
  }

  factory Ride.fromMap(Map<String, dynamic> map) {
    return Ride(
      id: map['id'] as String,
      startTime: DateTime.fromMillisecondsSinceEpoch(map['start_time'] as int),
      endTime: map['end_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['end_time'] as int)
          : null,
      durationSeconds: (map['duration_seconds'] as int?) ?? 0,
      movingDurationSeconds: (map['moving_duration_seconds'] as int?) ?? 0,
      distanceMeters: (map['distance_meters'] as num?)?.toDouble() ?? 0.0,
      maxSpeedKmh: (map['max_speed_kmh'] as num?)?.toDouble() ?? 0.0,
      avgSpeedKmh: (map['avg_speed_kmh'] as num?)?.toDouble() ?? 0.0,
      status: RideStatus.values.byName(map['status'] as String? ?? 'idle'),
      source: RecordingSource.values.byName(map['source'] as String? ?? 'manual'),
      pointsCount: (map['points_count'] as int?) ?? 0,
      isSynced: (map['is_synced'] as int?) == 1,
      lastSyncTime: map['last_sync_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_sync_time'] as int)
          : null,
      startAddress: map['start_address'] as String?,
      endAddress: map['end_address'] as String?,
    );
  }
}

