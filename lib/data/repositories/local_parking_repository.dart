import '../../domain/models/parking_location.dart';
import '../../domain/repositories/parking_repository.dart';
import '../local/app_database.dart';

class LocalParkingRepository implements ParkingRepository {
  final AppDatabase _db;

  LocalParkingRepository(this._db);

  @override
  Future<void> saveParkingLocation(ParkingLocation location) =>
      _db.saveParkingLocation(location);

  @override
  Future<ParkingLocation?> getLatestParkingLocation() =>
      _db.getLatestParkingLocation();

  @override
  Future<List<ParkingLocation>> getAllParkingLocations() =>
      _db.getAllParkingLocations();

  @override
  Future<void> deleteParkingLocation(String id) =>
      _db.deleteParkingLocation(id);
}

