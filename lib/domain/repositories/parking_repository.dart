import '../models/parking_location.dart';

abstract class ParkingRepository {
  Future<void> saveParkingLocation(ParkingLocation location);
  Future<ParkingLocation?> getLatestParkingLocation();
  Future<List<ParkingLocation>> getAllParkingLocations();
  Future<void> deleteParkingLocation(String id);
}

