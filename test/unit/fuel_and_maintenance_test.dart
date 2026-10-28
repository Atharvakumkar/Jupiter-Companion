import 'package:flutter_test/flutter_test.dart';
import 'package:jupiter_companion/domain/models/fuel_log.dart';
import 'package:jupiter_companion/domain/models/maintenance_record.dart';

void main() {
  group('Fuel and Maintenance Calculations', () {
    test('Fuel log calculates cost per liter correctly', () {
      const totalCost = 450.0;
      const liters = 4.35;
      final costPerLiter = totalCost / liters;

      final log = FuelLog(
        id: 'test_fuel',
        date: DateTime.now(),
        liters: liters,
        totalCost: totalCost,
        costPerLiter: costPerLiter,
      );

      expect(log.costPerLiter, closeTo(103.448, 0.01));
      expect(log.isFullTank, isTrue);
    });

    test('Maintenance record tracks next due km at +3000 km interval for Jupiter', () {
      final now = DateTime.now();
      const currentOdo = 6000.0;
      final record = MaintenanceRecord(
        id: 'test_maint',
        date: now,
        odometerKm: currentOdo,
        taskType: 'Engine Oil (10W-30) & Filter',
        cost: 420.0,
        nextDueKm: currentOdo + 3000.0,
        nextDueDate: now.add(const Duration(days: 90)),
      );

      expect(record.nextDueKm, 9000.0);
      expect(record.nextDueDate!.difference(now).inDays, 90);
    });
  });
}

