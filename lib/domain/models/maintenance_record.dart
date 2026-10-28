import 'telemetry.dart';

/// Maintenance log and service reminder record for TVS Jupiter scooter.
class MaintenanceRecord {
  final String id;
  final DateTime date;
  final double odometerKm;
  final TelemetrySource odometerSource;
  final String taskType;
  final double cost;
  final String? notes;
  final double? nextDueKm;
  final DateTime? nextDueDate;
  final bool isCompleted;

  const MaintenanceRecord({
    required this.id,
    required this.date,
    required this.odometerKm,
    this.odometerSource = TelemetrySource.userManual,
    required this.taskType,
    required this.cost,
    this.notes,
    this.nextDueKm,
    this.nextDueDate,
    this.isCompleted = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.millisecondsSinceEpoch,
      'odometer_km': odometerKm,
      'odometer_source': odometerSource.name,
      'task_type': taskType,
      'cost': cost,
      'notes': notes,
      'next_due_km': nextDueKm,
      'next_due_date': nextDueDate?.millisecondsSinceEpoch,
      'is_completed': isCompleted ? 1 : 0,
    };
  }

  factory MaintenanceRecord.fromMap(Map<String, dynamic> map) {
    return MaintenanceRecord(
      id: map['id'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      odometerKm: (map['odometer_km'] as num).toDouble(),
      odometerSource: TelemetrySource.values.byName(
        map['odometer_source'] as String? ?? 'userManual',
      ),
      taskType: map['task_type'] as String,
      cost: (map['cost'] as num).toDouble(),
      notes: map['notes'] as String?,
      nextDueKm: (map['next_due_km'] as num?)?.toDouble(),
      nextDueDate: map['next_due_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['next_due_date'] as int)
          : null,
      isCompleted: (map['is_completed'] as int?) == 1,
    );
  }
}

