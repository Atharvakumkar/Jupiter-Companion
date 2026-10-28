import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionStatusReport {
  final bool hasLocationPermission;
  final bool isLocationServiceEnabled;
  final bool hasNotificationPermission;
  final bool hasBluetoothPermission;

  const PermissionStatusReport({
    required this.hasLocationPermission,
    required this.isLocationServiceEnabled,
    required this.hasNotificationPermission,
    required this.hasBluetoothPermission,
  });

  bool get canStartRide => hasLocationPermission && isLocationServiceEnabled;
}

class AppPermissionService {
  /// Checks current state of all critical automotive permissions
  Future<PermissionStatusReport> checkPermissions() async {
    final locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    final locationStatus = await Permission.location.status;
    final notificationStatus = await Permission.notification.status;
    final bluetoothScanStatus = await Permission.bluetoothScan.status;
    final bluetoothConnectStatus = await Permission.bluetoothConnect.status;

    return PermissionStatusReport(
      hasLocationPermission: locationStatus.isGranted,
      isLocationServiceEnabled: locationServiceEnabled,
      hasNotificationPermission: notificationStatus.isGranted,
      hasBluetoothPermission:
          bluetoothScanStatus.isGranted && bluetoothConnectStatus.isGranted,
    );
  }

  /// Requests location permissions needed for ride tracking
  Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// Requests notification permission (Android 13+)
  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Requests Bluetooth Scan and Connect permissions (Android 12+)
  Future<bool> requestBluetoothPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    return statuses[Permission.bluetoothScan]?.isGranted == true &&
        statuses[Permission.bluetoothConnect]?.isGranted == true;
  }

  /// Requests background location permission with appropriate disclosure
  Future<bool> requestBackgroundLocation() async {
    final status = await Permission.locationAlways.request();
    return status.isGranted;
  }

  /// Opens system application settings
  Future<bool> openAppSettings() => openAppSettings();
}

