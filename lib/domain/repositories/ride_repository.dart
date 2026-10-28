import '../models/ride.dart';
import '../models/route_point.dart';

abstract class RideRepository {
  Future<void> saveRide(Ride ride);
  Future<void> updateRide(Ride ride);
  Future<Ride?> getRide(String id);
  Future<List<Ride>> getAllRides();
  Future<Ride?> getActiveRide();
  Future<void> deleteRide(String id);

  Future<void> addRoutePoint(RoutePoint point);
  Future<void> addRoutePointsBatch(List<RoutePoint> points);
  Future<List<RoutePoint>> getPointsForRide(String rideId);
}

