import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/permissions/permission_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  PermissionStatusReport? _permissionReport;

  @override
  void initState() {
    super.initState();
    _refreshPermissions();
  }

  Future<void> _refreshPermissions() async {
    final report = await ref.read(permissionServiceProvider).checkPermissions();
    if (mounted) {
      setState(() => _permissionReport = report);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesServiceProvider);
    final cloudSync = ref.watch(cloudSyncServiceProvider);
    final nativeChannel = ref.watch(nativeTrackingChannelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SETTINGS & SYSTEM'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Vehicle Profile Section
          _buildSectionHeader('SCOOTER PROFILE'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.two_wheeler, color: AppColors.primary),
                  title: const Text('Vehicle Model', style: AppTypography.titleSmall),
                  subtitle: Text(prefs.vehicleModel, style: AppTypography.bodySmall),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.local_gas_station, color: AppColors.primary),
                  title: const Text('Fuel Tank Capacity', style: AppTypography.titleSmall),
                  subtitle: Text('${prefs.fuelTankCapacityLiters} Liters (1.5L Reserve)', style: AppTypography.bodySmall),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.pin_drop_outlined, color: AppColors.primary),
                  title: const Text('Current Odometer', style: AppTypography.titleSmall),
                  subtitle: Text('${prefs.manualOdometerKm.toStringAsFixed(0)} km (Manual Entry)', style: AppTypography.bodySmall),
                  trailing: TextButton(
                    child: const Text('EDIT', style: TextStyle(color: AppColors.primary)),
                    onPressed: () => _showEditOdometerDialog(context, prefs),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Automatic Ride Recording (Disabled by default per Section 7)
          _buildSectionHeader('AUTOMATIC RIDE RECORDING'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  activeThumbColor: AppColors.primary,
                  title: const Text('Auto-Detect Rides', style: AppTypography.titleSmall),
                  subtitle: const Text(
                    'Starts recording automatically when sustained scooter motion is detected. Manual Start/End is always available.',
                    style: AppTypography.bodySmall,
                  ),
                  value: prefs.isAutoRecordEnabled,
                  onChanged: (val) async {
                    await prefs.setAutoRecordEnabled(val);
                    setState(() {});
                  },
                ),
                if (prefs.isAutoRecordEnabled) ...[
                  const Divider(),
                  ListTile(
                    title: const Text('Minimum Speed Threshold', style: AppTypography.titleSmall),
                    subtitle: Text('${prefs.autoRecordMinSpeedKmh.toStringAsFixed(0)} km/h', style: AppTypography.bodySmall),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Sustained Movement Duration', style: AppTypography.titleSmall),
                    subtitle: Text('${prefs.autoRecordMinDurationSec} seconds', style: AppTypography.bodySmall),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Android Permissions & Foreground Service Reliability
          _buildSectionHeader('ANDROID PERMISSIONS & BACKGROUND RELIABILITY'),
          Card(
            child: Column(
              children: [
                _buildPermissionTile(
                  icon: Icons.location_on,
                  title: 'Precise Location (GPS)',
                  isGranted: _permissionReport?.hasLocationPermission ?? false,
                  onTap: () async {
                    await ref.read(permissionServiceProvider).requestLocationPermission();
                    _refreshPermissions();
                  },
                ),
                const Divider(),
                _buildPermissionTile(
                  icon: Icons.notifications,
                  title: 'Foreground Notifications',
                  isGranted: _permissionReport?.hasNotificationPermission ?? false,
                  onTap: () async {
                    await ref.read(permissionServiceProvider).requestNotificationPermission();
                    _refreshPermissions();
                  },
                ),
                const Divider(),
                _buildPermissionTile(
                  icon: Icons.bluetooth,
                  title: 'Bluetooth Scan & Connect',
                  isGranted: _permissionReport?.hasBluetoothPermission ?? false,
                  onTap: () async {
                    await ref.read(permissionServiceProvider).requestBluetoothPermissions();
                    _refreshPermissions();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.battery_charging_full, color: AppColors.primary),
                  title: const Text('Battery Optimization', style: AppTypography.titleSmall),
                  subtitle: const Text('Prevent Android from killing tracking when screen is locked', style: AppTypography.bodySmall),
                  trailing: TextButton(
                    child: const Text('CHECK', style: TextStyle(color: AppColors.primary)),
                    onPressed: () => nativeChannel.requestIgnoreBatteryOptimizations(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Cloud Sync & Storage
          _buildSectionHeader('FIREBASE CLOUD BACKUP & SYNC'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.cloud_sync_outlined, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Local-First Architecture', style: AppTypography.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'All rides, maintenance logs, and parking locations are persisted durably in local SQLite. Cloud synchronization triggers automatically when signed in.',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.sync, color: AppColors.primary),
                      label: const Text('TRIGGER CLOUD SYNC'),
                      onPressed: () async {
                        await cloudSync.performSync();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Local records synchronized!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title, style: AppTypography.metricLabel),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: isGranted ? AppColors.success : AppColors.warning),
      title: Text(title, style: AppTypography.titleSmall),
      trailing: isGranted
          ? const Icon(Icons.check_circle, color: AppColors.success, size: 20)
          : TextButton(
              onPressed: onTap,
              child: const Text('GRANT', style: TextStyle(color: AppColors.warning)),
            ),
    );
  }

  Future<void> _showEditOdometerDialog(
    BuildContext context,
    dynamic prefs,
  ) async {
    final controller = TextEditingController(text: prefs.manualOdometerKm.toStringAsFixed(0));
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Update Scooter Odometer'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Odometer (km)'),
        ),
        actions: [
          TextButton(
            child: const Text('CANCEL'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: const Text('SAVE'),
            onPressed: () async {
              final km = double.tryParse(controller.text) ?? 0.0;
              await prefs.setManualOdometerKm(km);
              setState(() {});
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }
}
