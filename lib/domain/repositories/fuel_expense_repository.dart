import '../models/fuel_log.dart';

abstract class FuelExpenseRepository {
  Future<void> saveFuelLog(FuelLog log);
  Future<List<FuelLog>> getAllFuelLogs();
  Future<void> deleteFuelLog(String id);
}

