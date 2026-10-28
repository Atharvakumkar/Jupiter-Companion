import '../../domain/models/maintenance_record.dart';
import '../../domain/repositories/maintenance_repository.dart';
import '../local/app_database.dart';

class LocalMaintenanceRepository implements MaintenanceRepository {
  final AppDatabase _db;

  LocalMaintenanceRepository(this._db);

  @override
  Future<void> saveRecord(MaintenanceRecord record) => _db.insertMaintenanceRecord(record);

  @override
  Future<List<MaintenanceRecord>> getAllRecords() => _db.getAllMaintenanceRecords();

  @override
  Future<void> deleteRecord(String id) => _db.deleteMaintenanceRecord(id);
}

