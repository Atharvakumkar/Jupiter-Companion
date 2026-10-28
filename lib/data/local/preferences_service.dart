import 'package:shared_preferences/shared_preferences.dart';

/// Local preferences management for user settings and TVS Jupiter vehicle profile.
class PreferencesService {
  static const _keyAutoRecordEnabled = 'auto_record_enabled';
  static const _keyAutoRecordMinSpeedKmh = 'auto_record_min_speed_kmh';
  static const _keyAutoRecordMinDurationSec = 'auto_record_min_duration_sec';
  static const _keyGpsAccuracyThreshold = 'gps_accuracy_threshold';
  static const _keyVehicleModel = 'vehicle_model';
  static const _keyFuelTankCapacityLiters = 'fuel_tank_capacity_liters';
  static const _keyManualOdometerKm = 'manual_odometer_km';
  static const _keyLastParkedId = 'last_parked_id';
  static const _keyIsOnboardingComplete = 'is_onboarding_complete';

  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  static Future<PreferencesService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService(prefs);
  }

  // --- Auto Recording Settings ---
  // Mandatory: Disabled by default until explicitly enabled by user
  bool get isAutoRecordEnabled => _prefs.getBool(_keyAutoRecordEnabled) ?? false;
  Future<void> setAutoRecordEnabled(bool enabled) =>
      _prefs.setBool(_keyAutoRecordEnabled, enabled);

  double get autoRecordMinSpeedKmh =>
      _prefs.getDouble(_keyAutoRecordMinSpeedKmh) ?? 15.0;
  Future<void> setAutoRecordMinSpeedKmh(double speed) =>
      _prefs.setDouble(_keyAutoRecordMinSpeedKmh, speed);

  int get autoRecordMinDurationSec =>
      _prefs.getInt(_keyAutoRecordMinDurationSec) ?? 15;
  Future<void> setAutoRecordMinDurationSec(int seconds) =>
      _prefs.setInt(_keyAutoRecordMinDurationSec, seconds);

  double get gpsAccuracyThreshold =>
      _prefs.getDouble(_keyGpsAccuracyThreshold) ?? 30.0;
  Future<void> setGpsAccuracyThreshold(double meters) =>
      _prefs.setDouble(_keyGpsAccuracyThreshold, meters);

  // --- Vehicle Profile (TVS Jupiter 110 / 113.3cc) ---
  String get vehicleModel =>
      _prefs.getString(_keyVehicleModel) ?? 'TVS Jupiter 110 (113.3cc SmartXonnect)';
  Future<void> setVehicleModel(String model) =>
      _prefs.setString(_keyVehicleModel, model);

  double get fuelTankCapacityLiters =>
      _prefs.getDouble(_keyFuelTankCapacityLiters) ?? 5.1; // Jupiter 110 official tank capacity

  double get manualOdometerKm => _prefs.getDouble(_keyManualOdometerKm) ?? 0.0;
  Future<void> setManualOdometerKm(double km) =>
      _prefs.setDouble(_keyManualOdometerKm, km);

  String? get lastParkedId => _prefs.getString(_keyLastParkedId);
  Future<void> setLastParkedId(String? id) => id != null
      ? _prefs.setString(_keyLastParkedId, id)
      : _prefs.remove(_keyLastParkedId);

  bool get isOnboardingComplete =>
      _prefs.getBool(_keyIsOnboardingComplete) ?? false;
  Future<void> setOnboardingComplete(bool complete) =>
      _prefs.setBool(_keyIsOnboardingComplete, complete);
}

