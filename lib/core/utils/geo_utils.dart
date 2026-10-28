import 'dart:math' as math;

/// Physical and geographic utilities for automotive ride recording.
class GeoUtils {
  // Earth radius in meters
  static const double earthRadiusMeters = 6371000.0;

  // TVS Jupiter 110/113.3cc real-world physical limits:
  // Top speed: ~85-90 km/h (25 m/s)
  // Max realistic speed threshold: 110 km/h (30.5 m/s)
  // Max plausible acceleration: 5.5 m/s²
  static const double maxRealisticSpeedKmh = 110.0;
  static const double maxRealisticSpeedMps = maxRealisticSpeedKmh / 3.6;
  static const double maxPlausibleAccelerationMps2 = 5.5;

  // Maximum acceptable GPS horizontal accuracy for distance accumulation (in meters)
  static const double defaultMaxAcceptableAccuracyMeters = 30.0;

  /// Calculates Haversine great-circle distance between two coordinates in meters.
  static double haversineDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    if (lat1 == lat2 && lon1 == lon2) return 0.0;

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  /// Evaluates whether a new location point is physically plausible
  /// compared to the previous recorded point. Rejects anomalous GPS jumps.
  static bool isPointPlausible({
    required double prevLat,
    required double prevLon,
    required int prevTimestampMs,
    required double newLat,
    required double newLon,
    required int newTimestampMs,
    required double newAccuracyMeters,
    double? reportedSpeedMps,
    double maxAccuracyThreshold = defaultMaxAcceptableAccuracyMeters,
  }) {
    // 1. Accuracy check: ignore poor signals
    if (newAccuracyMeters > maxAccuracyThreshold) {
      return false;
    }

    final timeDeltaSec = (newTimestampMs - prevTimestampMs) / 1000.0;
    if (timeDeltaSec <= 0.0) {
      return false; // Duplicate or out-of-order timestamp
    }

    // 2. Reported GPS speed check
    if (reportedSpeedMps != null && reportedSpeedMps > maxRealisticSpeedMps) {
      return false; // Impossible speed reported by GNSS
    }

    // 3. Distance & derived velocity check
    final distance = haversineDistanceMeters(prevLat, prevLon, newLat, newLon);
    final derivedSpeedMps = distance / timeDeltaSec;

    // Reject if derived speed exceeds vehicle capabilities + margin
    if (derivedSpeedMps > maxRealisticSpeedMps) {
      return false;
    }

    return true;
  }

  /// Converts speed from m/s to km/h
  static double mpsToKmh(double mps) => mps * 3.6;

  /// Converts speed from km/h to m/s
  static double kmhToMps(double kmh) => kmh / 3.6;

  static double _toRadians(double degrees) => degrees * (math.pi / 180.0);
}

