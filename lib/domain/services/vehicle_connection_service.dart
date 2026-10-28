import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/bluetooth_device_info.dart';
import '../models/telemetry.dart';
import 'ecu_protocol_decoder.dart';

class RawPacketLog {
  final DateTime timestamp;
  final String serviceUuid;
  final String characteristicUuid;
  final List<int> rawBytes;
  final String hexString;

  const RawPacketLog({
    required this.timestamp,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.rawBytes,
    required this.hexString,
  });

  String toSanitizedExportLine() {
    return '${timestamp.toIso8601String()} | Svc:$serviceUuid | Char:$characteristicUuid | Hex:$hexString | Len:${rawBytes.length}';
  }
}

class DiscoveredCharacteristicInfo {
  final String uuid;
  final bool canRead;
  final bool canWrite;
  final bool canNotify;
  final bool canIndicate;
  final List<int>? lastValue;

  const DiscoveredCharacteristicInfo({
    required this.uuid,
    required this.canRead,
    required this.canWrite,
    required this.canNotify,
    required this.canIndicate,
    this.lastValue,
  });
}

class DiscoveredServiceInfo {
  final String uuid;
  final List<DiscoveredCharacteristicInfo> characteristics;

  const DiscoveredServiceInfo({
    required this.uuid,
    required this.characteristics,
  });
}

class VehicleConnectionService {
  BluetoothDevice? _connectedDevice;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  final _scanResultsController = StreamController<List<BluetoothDeviceInfo>>.broadcast();
  final _connectionStateController = StreamController<BluetoothConnectionState>.broadcast();
  final _rawPacketLogController = StreamController<List<RawPacketLog>>.broadcast();
  final _telemetryStateController = StreamController<VehicleTelemetryState>.broadcast();
  final _ecuFrameController = StreamController<DecodedEcuFrame>.broadcast();

  final List<RawPacketLog> _packetLogs = [];
  final List<DiscoveredServiceInfo> _discoveredServices = [];
  BluetoothCharacteristic? _writeCharacteristic;
  DecodedEcuFrame? _latestEcuFrame;
  Timer? _ecuPollingTimer;
  int _pollStep = 0;

  Stream<List<BluetoothDeviceInfo>> get scanResultsStream => _scanResultsController.stream;
  Stream<BluetoothConnectionState> get connectionStateStream => _connectionStateController.stream;
  Stream<List<RawPacketLog>> get rawPacketLogStream => _rawPacketLogController.stream;
  Stream<VehicleTelemetryState> get telemetryStateStream => _telemetryStateController.stream;
  Stream<DecodedEcuFrame> get ecuFrameStream => _ecuFrameController.stream;

  List<DiscoveredServiceInfo> get discoveredServices => List.unmodifiable(_discoveredServices);
  BluetoothDevice? get connectedDevice => _connectedDevice;
  BluetoothCharacteristic? get writeCharacteristic => _writeCharacteristic;
  DecodedEcuFrame? get latestEcuFrame => _latestEcuFrame;
  bool get isConnected => _connectedDevice != null;
  bool get isEcuPollingActive => _ecuPollingTimer != null;

  VehicleConnectionService() {
    _initBluetoothListeners();
  }

  void _initBluetoothListeners() {
    FlutterBluePlus.scanResults.listen((results) {
      final devices = results.map((r) {
        final rawBytes = r.advertisementData.advName.codeUnits;
        final mfgData = r.advertisementData.manufacturerData.values.isNotEmpty
            ? r.advertisementData.manufacturerData.values.first
                .map((b) => b.toRadixString(16).padLeft(2, '0'))
                .join()
            : null;

        return BluetoothDeviceInfo(
          id: r.device.remoteId.str,
          name: r.advertisementData.advName.isNotEmpty
              ? r.advertisementData.advName
              : (r.device.platformName.isNotEmpty ? r.device.platformName : 'Unknown Peripheral'),
          rssi: r.rssi,
          advertisedServiceUuids:
              r.advertisementData.serviceUuids.map((u) => u.str128).toList(),
          isConnected: _connectedDevice?.remoteId == r.device.remoteId,
          manufacturerDataHex: mfgData,
          rawBytesHex: rawBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
          timestamp: r.timeStamp,
        );
      }).toList();

      // Sort with likely TVS clusters and strongest RSSI first
      devices.sort((a, b) {
        if (a.isLikelyTvsCluster && !b.isLikelyTvsCluster) return -1;
        if (!a.isLikelyTvsCluster && b.isLikelyTvsCluster) return 1;
        return b.rssi.compareTo(a.rssi);
      });

      _scanResultsController.add(devices);
    });
  }

  /// Start BLE scan for SmartXonnect cluster or surrounding devices
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) async {
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        debugPrint('BLE is not supported on this device.');
        return;
      }
      await FlutterBluePlus.startScan(timeout: timeout);
    } catch (e) {
      debugPrint('Error starting BLE scan: $e');
    }
  }

  /// Stop BLE scan
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint('Error stopping BLE scan: $e');
    }
  }

  /// Safely connects to device and enumerates services without arbitrary writes
  Future<bool> connect(String deviceId) async {
    if (_isConnecting) return false;
    _isConnecting = true;

    try {
      await stopScan();
      final device = BluetoothDevice.fromId(deviceId);

      // Listen to connection state
      device.connectionState.listen((state) {
        _connectionStateController.add(state);
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnection(device);
        }
      });

      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      _connectedDevice = device;
      _reconnectAttempts = 0;
      _isConnecting = false;

      // Discover GATT services
      await discoverGattServices(device);
      return true;
    } catch (e) {
      _isConnecting = false;
      debugPrint('Connection to BLE device failed: $e');
      return false;
    }
  }

  /// Discover and catalog all GATT services and characteristics
  Future<void> discoverGattServices(BluetoothDevice device) async {
    _discoveredServices.clear();
    try {
      final services = await device.discoverServices();
      for (final s in services) {
        final charList = <DiscoveredCharacteristicInfo>[];
        for (final c in s.characteristics) {
          charList.add(
            DiscoveredCharacteristicInfo(
              uuid: c.uuid.str128,
              canRead: c.properties.read,
              canWrite: c.properties.write || c.properties.writeWithoutResponse,
              canNotify: c.properties.notify,
              canIndicate: c.properties.indicate,
            ),
          );

          // If characteristic supports notify, subscribe safely to log raw bytes
          if (c.properties.notify) {
            _subscribeSafelyToCharacteristic(s.uuid.str128, c);
          }

          // Detect writable characteristic for OBD-II / UART requests
          if (c.properties.write || c.properties.writeWithoutResponse) {
            final uuidLower = c.uuid.str128.toLowerCase();
            if (uuidLower.contains('ffe1') ||
                uuidLower.contains('fff1') ||
                uuidLower.contains('6e400002') ||
                _writeCharacteristic == null) {
              _writeCharacteristic = c;
            }
          }
        }
        _discoveredServices.add(
          DiscoveredServiceInfo(
            uuid: s.uuid.str128,
            characteristics: charList,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error discovering GATT services: $e');
    }
  }

  /// Safely listens to incoming notifications to log packet bytes for protocol reverse-engineering
  void _subscribeSafelyToCharacteristic(
    String serviceUuid,
    BluetoothCharacteristic characteristic,
  ) {
    try {
      characteristic.setNotifyValue(true).then((_) {
        characteristic.onValueReceived.listen((bytes) {
          processIncomingBytes(
            bytes,
            serviceUuid: serviceUuid,
            characteristicUuid: characteristic.uuid.str128,
          );
        });
      }).catchError((err) {
        debugPrint('Failed to set notification on ${characteristic.uuid.str128}: $err');
      });
    } catch (e) {
      debugPrint('Error subscribing to characteristic: $e');
    }
  }

  /// Process incoming byte packets, log raw bytes, and decode verified ECU parameters
  void processIncomingBytes(
    List<int> bytes, {
    String serviceUuid = '',
    String characteristicUuid = '',
  }) {
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    final log = RawPacketLog(
      timestamp: DateTime.now(),
      serviceUuid: serviceUuid,
      characteristicUuid: characteristicUuid,
      rawBytes: bytes,
      hexString: hex,
    );

    _packetLogs.add(log);
    if (_packetLogs.length > 200) {
      _packetLogs.removeAt(0); // Bounded memory buffer
    }
    _rawPacketLogController.add(List.unmodifiable(_packetLogs));

    // Feed into verified ECU protocol decoder
    final decoded = EcuProtocolDecoder.decode(
      bytes,
      characteristicUuid: characteristicUuid,
    );
    if (decoded != null && decoded.hasAnyMetric) {
      _latestEcuFrame = decoded;
      _ecuFrameController.add(decoded);
    }
  }

  /// Safely send a diagnostic command to the peripheral (e.g. "010C" for RPM or "ATRV")
  Future<bool> sendDiagnosticCommand(String command) async {
    final char = _writeCharacteristic;
    if (char == null) {
      debugPrint('Cannot send diagnostic command: No writable characteristic discovered.');
      return false;
    }

    try {
      final payload = command.endsWith('\r') ? command : '$command\r';
      final bytes = utf8.encode(payload);
      final withoutResponse = char.properties.writeWithoutResponse && !char.properties.write;
      await char.write(bytes, withoutResponse: withoutResponse);
      return true;
    } catch (e) {
      debugPrint('Failed to send diagnostic command "$command": $e');
      return false;
    }
  }

  /// Start automated round-robin ECU diagnostic polling loop (5 Hz default)
  void startEcuPolling({Duration interval = const Duration(milliseconds: 200)}) {
    stopEcuPolling();
    _pollStep = 0;
    // Standard ELM327 initialization if writable
    sendDiagnosticCommand('ATE0'); // Echo off

    _ecuPollingTimer = Timer.periodic(interval, (timer) {
      if (!isConnected || _writeCharacteristic == null) {
        stopEcuPolling();
        return;
      }

      switch (_pollStep % 3) {
        case 0:
          sendDiagnosticCommand('010C'); // Mode 01 PID 0C: Engine RPM
          break;
        case 1:
          sendDiagnosticCommand('010D'); // Mode 01 PID 0D: Vehicle Speed
          break;
        case 2:
          sendDiagnosticCommand('0142'); // Mode 01 PID 42: Control Module Voltage
          break;
      }
      _pollStep++;
    });
  }

  /// Stop automated ECU diagnostic polling loop
  void stopEcuPolling() {
    _ecuPollingTimer?.cancel();
    _ecuPollingTimer = null;
  }

  /// Handles disconnection with bounded exponential backoff
  void _handleDisconnection(BluetoothDevice device) {
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      final delaySeconds = (1 << _reconnectAttempts).clamp(2, 30);
      debugPrint('Disconnected. Attempting reconnect #$_reconnectAttempts in ${delaySeconds}s...');

      Timer(Duration(seconds: delaySeconds), () async {
        if (_connectedDevice != null) {
          try {
            await device.connect(timeout: const Duration(seconds: 10));
            await discoverGattServices(device);
          } catch (e) {
            debugPrint('Reconnect attempt failed: $e');
          }
        }
      });
    } else {
      debugPrint('Max reconnect attempts reached. Releasing connection.');
      disconnect();
    }
  }

  /// Cleanly disconnects and releases Bluetooth resources
  Future<void> disconnect() async {
    try {
      stopEcuPolling();
      final device = _connectedDevice;
      _connectedDevice = null;
      _writeCharacteristic = null;
      _latestEcuFrame = null;
      _reconnectAttempts = _maxReconnectAttempts;
      if (device != null) {
        await device.disconnect();
      }
      _discoveredServices.clear();
      _connectionStateController.add(BluetoothConnectionState.disconnected);
    } catch (e) {
      debugPrint('Error disconnecting device: $e');
    }
  }

  /// Export sanitized logs for offline analysis
  String exportSanitizedLogs() {
    final buffer = StringBuffer();
    buffer.writeln('# TVS Jupiter SmartXonnect BLE Diagnostic Packet Dump');
    buffer.writeln('# Generated at: ${DateTime.now().toIso8601String()}');
    buffer.writeln('# Total packets logged: ${_packetLogs.length}');
    buffer.writeln('--------------------------------------------------');
    for (final log in _packetLogs) {
      buffer.writeln(log.toSanitizedExportLine());
    }
    return buffer.toString();
  }

  void dispose() {
    stopEcuPolling();
    stopScan();
    disconnect();
    _scanResultsController.close();
    _connectionStateController.close();
    _rawPacketLogController.close();
    _telemetryStateController.close();
    _ecuFrameController.close();
  }
}

