import '../models/maintenance_record.dart';

abstract class MaintenanceRepository {
  Future<void> saveRecord(MaintenanceRecord record);
  Future<List<MaintenanceRecord>> getAllRecords();
  Future<void> deleteRecord(String id);
}

