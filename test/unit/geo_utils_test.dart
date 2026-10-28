import 'package:flutter_test/flutter_test.dart';
import 'package:jupiter_companion/core/utils/geo_utils.dart';

void main() {
  group('GeoUtils Unit Tests', () {
    test('Haversine distance between same coordinate is 0', () {
      final dist = GeoUtils.haversineDistanceMeters(12.9716, 77.5946, 12.9716, 77.5946);
      expect(dist, 0.0);
    });

    test('Haversine distance calculates known distance accurately (~10 km)', () {
      // Coordinates approx 10 km apart in Bangalore
      final dist = GeoUtils.haversineDistanceMeters(12.9716, 77.5946, 13.0616, 77.5946);
      expect(dist, greaterThan(9900));
      expect(dist, lessThan(10100));
    });

    test('Plausible point is accepted under scooter normal velocity', () {
      // Moving at ~40 km/h (11.1 m/s) over 3 seconds (~33 meters)
      final plausible = GeoUtils.isPointPlausible(
        prevLat: 12.97160,
        prevLon: 77.59460,
        prevTimestampMs: 1000,
        newLat: 12.97190,
        newLon: 77.59460,
        newTimestampMs: 4000,
        newAccuracyMeters: 5.0,
        reportedSpeedMps: 11.1,
      );
      expect(plausible, isTrue);
    });

    test('Impossible GPS jump exceeding 110 km/h is rejected', () {
      // 500 meters jump in 1 second = 500 m/s (1800 km/h) -> impossible on TVS Jupiter!
      final plausible = GeoUtils.isPointPlausible(
        prevLat: 12.9716,
        prevLon: 77.5946,
        prevTimestampMs: 1000,
        newLat: 12.9760,
        newLon: 77.5946,
        newTimestampMs: 2000,
        newAccuracyMeters: 5.0,
      );
      expect(plausible, isFalse);
    });

    test('Point with poor GPS accuracy (> 30m) is rejected from distance calculation', () {
      final plausible = GeoUtils.isPointPlausible(
        prevLat: 12.9716,
        prevLon: 77.5946,
        prevTimestampMs: 1000,
        newLat: 12.9717,
        newLon: 77.5946,
        newTimestampMs: 3000,
        newAccuracyMeters: 65.0, // Inaccurate cell-tower bounce
      );
      expect(plausible, isFalse);
    });

    test('Conversion helpers mpsToKmh and kmhToMps work correctly', () {
      expect(GeoUtils.mpsToKmh(10.0), closeTo(36.0, 0.001));
      expect(GeoUtils.kmhToMps(72.0), closeTo(20.0, 0.001));
    });
  });
}

