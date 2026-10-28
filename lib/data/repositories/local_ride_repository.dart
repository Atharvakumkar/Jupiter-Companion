import '../../domain/models/ride.dart';
import '../../domain/models/route_point.dart';
import '../../domain/repositories/ride_repository.dart';
import '../local/app_database.dart';

class LocalRideRepository implements RideRepository {
  final AppDatabase _db;

  LocalRideRepository(this._db);

  @override
  Future<void> saveRide(Ride ride) => _db.insertRide(ride);

  @override
  Future<void> updateRide(Ride ride) => _db.updateRide(ride);

  @override
  Future<Ride?> getRide(String id) => _db.getRide(id);

  @override
  Future<List<Ride>> getAllRides() => _db.getAllRides();

  @override
  Future<Ride?> getActiveRide() => _db.getActiveRide();

  @override
  Future<void> deleteRide(String id) => _db.deleteRide(id);

  @override
  Future<void> addRoutePoint(RoutePoint point) => _db.insertRoutePoint(point);

  @override
  Future<void> addRoutePointsBatch(List<RoutePoint> points) =>
      _db.insertRoutePointsBatch(points);

  @override
  Future<List<RoutePoint>> getPointsForRide(String rideId) =>
      _db.getPointsForRide(rideId);
}

