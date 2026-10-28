/// Fuel refuel log and expense record.
class FuelLog {
  final String id;
  final DateTime date;
  final double liters;
  final double totalCost;
  final double costPerLiter;
  final double? odometerKm;
  final bool isFullTank;
  final String? fuelStation;
  final String? notes;
  final double? calculatedEconomyKmpl;

  const FuelLog({
    required this.id,
    required this.date,
    required this.liters,
    required this.totalCost,
    required this.costPerLiter,
    this.odometerKm,
    this.isFullTank = true,
    this.fuelStation,
    this.notes,
    this.calculatedEconomyKmpl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.millisecondsSinceEpoch,
      'liters': liters,
      'total_cost': totalCost,
      'cost_per_liter': costPerLiter,
      'odometer_km': odometerKm,
      'is_full_tank': isFullTank ? 1 : 0,
      'fuel_station': fuelStation,
      'notes': notes,
      'calculated_economy_kmpl': calculatedEconomyKmpl,
    };
  }

  factory FuelLog.fromMap(Map<String, dynamic> map) {
    return FuelLog(
      id: map['id'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      liters: (map['liters'] as num).toDouble(),
      totalCost: (map['total_cost'] as num).toDouble(),
      costPerLiter: (map['cost_per_liter'] as num).toDouble(),
      odometerKm: (map['odometer_km'] as num?)?.toDouble(),
      isFullTank: (map['is_full_tank'] as int?) == 1,
      fuelStation: map['fuel_station'] as String?,
      notes: map['notes'] as String?,
      calculatedEconomyKmpl: (map['calculated_economy_kmpl'] as num?)?.toDouble(),
    );
  }
}

