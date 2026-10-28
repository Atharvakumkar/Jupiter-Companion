/// Data provenance source for vehicle telemetry.
/// Crucial rule: Never merge GPS speed with ECU speed without tracking provenance.
/// Never invent ECU capabilities or fake RPM readings.
enum TelemetrySource {
  /// Derived from phone GNSS/GPS location provider
  gps,

  /// Streamed directly from verified scooter ECU / SmartXonnect BLE characteristic
  verifiedEcu,

  /// Computed from known mathematical/sensor formulas (e.g. Haversine distance, average velocity)
  calculated,

  /// Entered manually by rider
  userManual,

  /// Sensor or characteristic is unverified or currently unavailable
  unavailable,
}

/// A strongly typed telemetry measurement carrying full provenance, units, and validity.
class TelemetryField<T> {
  final String name;
  final T? value;
  final String unit;
  final TelemetrySource source;
  final DateTime timestamp;
  final bool isValid;
  final double confidence; // 0.0 to 1.0
  final String? note;

  const TelemetryField({
    required this.name,
    required this.value,
    required this.unit,
    required this.source,
    required this.timestamp,
    this.isValid = true,
    this.confidence = 1.0,
    this.note,
  });

  /// Factory for unavailable or unverified field
  factory TelemetryField.unavailable({
    required String name,
    required String unit,
    String? note,
  }) {
    return TelemetryField(
      name: name,
      value: null,
      unit: unit,
      source: TelemetrySource.unavailable,
      timestamp: DateTime.now(),
      isValid: false,
      confidence: 0.0,
      note: note ?? 'Requires verified vehicle telemetry stream',
    );
  }

  /// Whether reading has not timed out (e.g. within last 3 seconds)
  bool isFresh({Duration maxAge = const Duration(seconds: 3)}) {
    if (!isValid || value == null) return false;
    return DateTime.now().difference(timestamp) <= maxAge;
  }

  String get sourceLabel {
    switch (source) {
      case TelemetrySource.gps:
        return 'GPS';
      case TelemetrySource.verifiedEcu:
        return 'ECU (Verified)';
      case TelemetrySource.calculated:
        return 'Calculated';
      case TelemetrySource.userManual:
        return 'User Entry';
      case TelemetrySource.unavailable:
        return 'Unavailable';
    }
  }

  TelemetryField<T> copyWith({
    String? name,
    T? value,
    String? unit,
    TelemetrySource? source,
    DateTime? timestamp,
    bool? isValid,
    double? confidence,
    String? note,
  }) {
    return TelemetryField<T>(
      name: name ?? this.name,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      source: source ?? this.source,
      timestamp: timestamp ?? this.timestamp,
      isValid: isValid ?? this.isValid,
      confidence: confidence ?? this.confidence,
      note: note ?? this.note,
    );
  }
}

/// Comprehensive vehicle state container
class VehicleTelemetryState {
  final TelemetryField<double> speedKmh;
  final TelemetryField<int> rpm;
  final TelemetryField<double> fuelLevelPercent;
  final TelemetryField<double> odometerKm;
  final TelemetryField<double> tripDistanceKm;
  final TelemetryField<double> batteryVoltage;
  final TelemetryField<String> engineStatus;

  const VehicleTelemetryState({
    required this.speedKmh,
    required this.rpm,
    required this.fuelLevelPercent,
    required this.odometerKm,
    required this.tripDistanceKm,
    required this.batteryVoltage,
    required this.engineStatus,
  });

  factory VehicleTelemetryState.initial() {
    return VehicleTelemetryState(
      speedKmh: TelemetryField.unavailable(
        name: 'Speed',
        unit: 'km/h',
        note: 'GPS signal acquiring...',
      ),
      rpm: TelemetryField.unavailable(
        name: 'Engine RPM',
        unit: 'RPM',
        note: 'Requires verified SmartXonnect ECU characteristic stream',
      ),
      fuelLevelPercent: TelemetryField.unavailable(
        name: 'Fuel Level',
        unit: '%',
        note: 'No verified fuel gauge telemetry; enter manually in Fuel Log',
      ),
      odometerKm: TelemetryField.unavailable(
        name: 'Odometer',
        unit: 'km',
        note: 'Enter manual odometer or configure in settings',
      ),
      tripDistanceKm: TelemetryField(
        name: 'Trip Distance',
        value: 0.0,
        unit: 'km',
        source: TelemetrySource.calculated,
        timestamp: DateTime.now(),
        isValid: true,
      ),
      batteryVoltage: TelemetryField.unavailable(
        name: 'Battery',
        unit: 'V',
        note: 'Requires verified cluster characteristic',
      ),
      engineStatus: TelemetryField.unavailable(
        name: 'Engine',
        unit: '',
        note: 'Cluster disconnected',
      ),
    );
  }
}

