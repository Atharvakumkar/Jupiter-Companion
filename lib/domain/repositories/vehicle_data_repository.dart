import '../models/bluetooth_device_info.dart';
import '../models/telemetry.dart';

abstract class VehicleDataRepository {
  Stream<VehicleTelemetryState> get telemetryStream;
  Stream<bool> get connectionStatusStream;
  bool get isConnected;

  Future<void> startScan();
  Future<void> stopScan();
  Stream<List<BluetoothDeviceInfo>> get scanResultsStream;

  Future<bool> connect(String deviceId);
  Future<void> disconnect();

  Future<List<String>> discoverServices();
}

