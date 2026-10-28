/// Diagnostic information for discovered and inspected Bluetooth/BLE devices.
class BluetoothDeviceInfo {
  final String id;
  final String name;
  final int rssi;
  final List<String> advertisedServiceUuids;
  final bool isConnected;
  final String? manufacturerDataHex;
  final String? rawBytesHex;
  final DateTime timestamp;

  const BluetoothDeviceInfo({
    required this.id,
    required this.name,
    required this.rssi,
    this.advertisedServiceUuids = const [],
    this.isConnected = false,
    this.manufacturerDataHex,
    this.rawBytesHex,
    required this.timestamp,
  });

  /// True if device advertised name suggests TVS SmartXonnect or instrument cluster
  bool get isLikelyTvsCluster {
    final lower = name.toLowerCase();
    return lower.contains('tvs') ||
        lower.contains('jupiter') ||
        lower.contains('smartxonnect') ||
        lower.contains('xonnect') ||
        lower.contains('bt_') ||
        lower.contains('cluster');
  }
}

