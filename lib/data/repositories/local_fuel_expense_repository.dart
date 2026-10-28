import '../../domain/models/fuel_log.dart';
import '../../domain/repositories/fuel_expense_repository.dart';
import '../local/app_database.dart';

class LocalFuelExpenseRepository implements FuelExpenseRepository {
  final AppDatabase _db;

  LocalFuelExpenseRepository(this._db);

  @override
  Future<void> saveFuelLog(FuelLog log) => _db.insertFuelLog(log);

  @override
  Future<List<FuelLog>> getAllFuelLogs() => _db.getAllFuelLogs();

  @override
  Future<void> deleteFuelLog(String id) => _db.deleteFuelLog(id);
}

