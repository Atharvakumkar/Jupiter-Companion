import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/provenance_badge.dart';
import '../../../domain/models/bluetooth_device_info.dart';
import '../../../domain/models/telemetry.dart';
import '../../../domain/services/vehicle_connection_service.dart';

class BluetoothDiagnosticScreen extends ConsumerStatefulWidget {
  const BluetoothDiagnosticScreen({super.key});

  @override
  ConsumerState<BluetoothDiagnosticScreen> createState() => _BluetoothDiagnosticScreenState();
}

class _BluetoothDiagnosticScreenState extends ConsumerState<BluetoothDiagnosticScreen> {
  bool _isScanning = false;
  final TextEditingController _customCmdController = TextEditingController();
  final List<String> _consoleLines = [];

  @override
  void dispose() {
    _customCmdController.dispose();
    super.dispose();
  }

  void _logConsole(String line) {
    setState(() {
      _consoleLines.insert(0, line);
      if (_consoleLines.length > 50) _consoleLines.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    final connectionService = ref.watch(vehicleConnectionServiceProvider);
    final scanResults = ref.watch(bleScanResultsProvider).valueOrNull ?? [];
    final packetLogs = ref.watch(rawPacketLogsProvider).valueOrNull ?? [];
    final liveTelemetry = ref.watch(liveClusterTelemetryProvider).valueOrNull ??
        ref.watch(liveClusterControllerProvider).currentState;

    // Listen to incoming decoded ECU frames for the console
    ref.listen(ecuFrameStreamProvider, (prev, next) {
      final frame = next.valueOrNull;
      if (frame != null) {
        _logConsole('<< [ECU RX] ${frame.diagnosticNote ?? frame.protocol.name}: '
            '${frame.rpm != null ? "RPM:${frame.rpm} " : ""}'
            '${frame.speedKmh != null ? "Speed:${frame.speedKmh}km/h " : ""}'
            '${frame.batteryVoltage != null ? "Volt:${frame.batteryVoltage}V " : ""}');
      }
    });

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('BLUETOOTH & ECU DIAGNOSTICS'),
          actions: [
            IconButton(
              icon: const Icon(Icons.file_download_outlined, color: AppColors.primary),
              tooltip: 'Export Sanitized Logs',
              onPressed: () {
                final logs = connectionService.exportSanitizedLogs();
                Clipboard.setData(ClipboardData(text: logs));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sanitized diagnostic logs copied to clipboard!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
            ),
          ],
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            isScrollable: false,
            tabs: [
              Tab(icon: Icon(Icons.devices_other), text: 'SCAN'),
              Tab(icon: Icon(Icons.speed), text: 'ECU READER'),
              Tab(icon: Icon(Icons.code), text: 'RAW BYTES'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: Device Discovery & GATT Exploration
            _buildScanTab(context, connectionService, scanResults),

            // TAB 2: Real-Time ECU Live Telemetry & OBD-II Poller
            _buildEcuReaderTab(context, connectionService, liveTelemetry),

            // TAB 3: Raw Packet Inspector
            _buildRawPacketsTab(context, packetLogs),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: Device Scan ---

  Widget _buildScanTab(
    BuildContext context,
    VehicleConnectionService connectionService,
    List<BluetoothDeviceInfo> scanResults,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Scan Control Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('BLE PERIPHERAL SCANNER', style: AppTypography.titleSmall),
                        Text(
                          _isScanning ? 'Scanning for TVS SmartXonnect & BLE OBD-II...' : 'Scanner Idle',
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isScanning ? AppColors.error : AppColors.primary,
                    ),
                    icon: Icon(_isScanning ? Icons.stop : Icons.search),
                    label: Text(_isScanning ? 'STOP' : 'SCAN'),
                    onPressed: () async {
                      if (_isScanning) {
                        await connectionService.stopScan();
                        setState(() => _isScanning = false);
                      } else {
                        setState(() => _isScanning = true);
                        await connectionService.startScan();
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Connected Device Banner
        if (connectionService.isConnected && connectionService.connectedDevice != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.successGlow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.success),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: AppColors.success, size: 20),
                        SizedBox(width: 8),
                        Text('CONNECTED HARDWARE', style: AppTypography.titleSmall),
                      ],
                    ),
                    TextButton(
                      child: const Text('DISCONNECT', style: TextStyle(color: AppColors.error)),
                      onPressed: () => connectionService.disconnect(),
                    ),
                  ],
                ),
                Text(
                  connectionService.connectedDevice!.platformName.isNotEmpty
                      ? connectionService.connectedDevice!.platformName
                      : 'Connected Peripheral',
                  style: AppTypography.titleMedium,
                ),
                Text('ID: ${connectionService.connectedDevice!.remoteId.str}', style: AppTypography.bodySmall),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'GATT Services: ${connectionService.discoveredServices.length}',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.primary),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      connectionService.writeCharacteristic != null ? '• Write Active' : '• Read Only',
                      style: TextStyle(
                        fontSize: 12,
                        color: connectionService.writeCharacteristic != null
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Discovered Devices Header
        Text('DISCOVERED PERIPHERALS (${scanResults.length})', style: AppTypography.metricLabel),
        const SizedBox(height: 8),

        if (scanResults.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.bluetooth_searching, size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  const Text('No devices found yet.', style: AppTypography.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Ensure scooter ignition is ON and cluster/OBD-II adapter is advertising.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          ...scanResults.map((dev) => _buildDeviceTile(context, dev, connectionService)),
        ],
      ],
    );
  }

  // --- TAB 2: ECU Live Reader & Diagnostic Poller ---

  Widget _buildEcuReaderTab(
    BuildContext context,
    VehicleConnectionService connectionService,
    dynamic liveTelemetry,
  ) {
    final isConnected = connectionService.isConnected;
    final isPolling = connectionService.isEcuPollingActive;
    final hasEcuData = liveTelemetry.rpmSource == TelemetrySource.verifiedEcu ||
        liveTelemetry.speedSource == TelemetrySource.verifiedEcu;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status & Connection Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hasEcuData
                ? AppColors.primaryGlow
                : (isConnected ? AppColors.surfaceElevated : AppColors.surfaceVariant),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasEcuData ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasEcuData
                    ? Icons.offline_bolt
                    : (isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled),
                color: hasEcuData ? AppColors.primary : AppColors.textMuted,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasEcuData
                          ? 'ECU TELEMETRY STREAM ACTIVE'
                          : (isConnected ? 'PERIPHERAL CONNECTED' : 'ECU DISCONNECTED'),
                      style: AppTypography.titleSmall.copyWith(
                        color: hasEcuData ? AppColors.primary : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      hasEcuData
                          ? 'Streaming live RPM, Speed, and Voltage from vehicle ECU'
                          : (isConnected
                              ? 'Tap "START AUTO-POLL" below to query SAE J1979 PIDs'
                              : 'Connect your SmartXonnect cluster or OBD-II adapter in the Scan tab'),
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Live ECU Metric Cards
        Row(
          children: [
            // ECU RPM Card
            Expanded(
              child: _buildEcuMetricBox(
                label: 'ECU RPM',
                value: liveTelemetry.rpm > 0 ? '${liveTelemetry.rpm}' : '---',
                unit: 'RPM',
                source: liveTelemetry.rpmSource,
                accentColor: AppColors.primary,
                icon: Icons.rotate_right,
              ),
            ),
            const SizedBox(width: 12),

            // ECU Speed Card
            Expanded(
              child: _buildEcuMetricBox(
                label: 'ECU SPEED',
                value: liveTelemetry.speedKmh > 0 ? liveTelemetry.speedKmh.toStringAsFixed(1) : '0.0',
                unit: 'km/h',
                source: liveTelemetry.speedSource,
                accentColor: AppColors.success,
                icon: Icons.speed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            // ECU Battery Voltage Card
            Expanded(
              child: _buildEcuMetricBox(
                label: 'ECU VOLTAGE',
                value: '${liveTelemetry.batteryVoltage.toStringAsFixed(1)} V',
                unit: '${liveTelemetry.batteryPercent}% SoC',
                source: liveTelemetry.batterySource,
                accentColor: liveTelemetry.batteryVoltage >= 13.8 ? AppColors.success : AppColors.warning,
                icon: Icons.battery_charging_full,
              ),
            ),
            const SizedBox(width: 12),

            // ECU Odometer Card
            Expanded(
              child: _buildEcuMetricBox(
                label: 'ECU ODOMETER',
                value: '${liveTelemetry.totalOdometerKm.toStringAsFixed(1)}',
                unit: 'km',
                source: liveTelemetry.odometerSource,
                accentColor: AppColors.accentIndigo,
                icon: Icons.pin_drop_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Diagnostic Poller Controls
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DIAGNOSTIC POLLING CONTROLS', style: AppTypography.titleSmall),
              const SizedBox(height: 6),
              const Text(
                'Sends standard SAE J1979 PIDs (010C=RPM, 010D=Speed, 0142=Voltage) over Bluetooth.',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPolling ? AppColors.error : AppColors.primary,
                        foregroundColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: Icon(isPolling ? Icons.stop : Icons.play_arrow),
                      label: Text(isPolling ? 'STOP POLLING' : 'START AUTO-POLL (5 Hz)'),
                      onPressed: isConnected
                          ? () {
                              if (isPolling) {
                                connectionService.stopEcuPolling();
                                _logConsole('>> [CMD] Stopped ECU diagnostic polling loop');
                              } else {
                                connectionService.startEcuPolling();
                                _logConsole('>> [CMD] Started ECU auto-polling (010C, 010D, 0142 at 5 Hz)');
                              }
                              setState(() {});
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: isConnected
                        ? () async {
                            _logConsole('>> [QUERY] Polling 010C (RPM), 010D (Speed), ATRV');
                            await connectionService.sendDiagnosticCommand('010C');
                            await Future.delayed(const Duration(milliseconds: 60));
                            await connectionService.sendDiagnosticCommand('010D');
                            await Future.delayed(const Duration(milliseconds: 60));
                            await connectionService.sendDiagnosticCommand('ATRV');
                          }
                        : null,
                    child: const Text('POLL ONCE'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Quick PID Shortcut Chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    label: const Text('010C (RPM)'),
                    onPressed: isConnected
                        ? () {
                            connectionService.sendDiagnosticCommand('010C');
                            _logConsole('>> [CMD] 010C (Request Engine RPM)');
                          }
                        : null,
                  ),
                  ActionChip(
                    label: const Text('010D (Speed)'),
                    onPressed: isConnected
                        ? () {
                            connectionService.sendDiagnosticCommand('010D');
                            _logConsole('>> [CMD] 010D (Request Vehicle Speed)');
                          }
                        : null,
                  ),
                  ActionChip(
                    label: const Text('ATRV (Voltage)'),
                    onPressed: isConnected
                        ? () {
                            connectionService.sendDiagnosticCommand('ATRV');
                            _logConsole('>> [CMD] ATRV (Read Battery Voltage)');
                          }
                        : null,
                  ),
                  ActionChip(
                    label: const Text('0100 (Supported PIDs)'),
                    onPressed: isConnected
                        ? () {
                            connectionService.sendDiagnosticCommand('0100');
                            _logConsole('>> [CMD] 0100 (Request Supported PIDs 01-20)');
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Custom Command Input Box
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customCmdController,
                decoration: const InputDecoration(
                  hintText: 'Enter OBD PID or AT command (e.g. 010C, ATRV)...',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (cmd) {
                  if (cmd.isNotEmpty && isConnected) {
                    connectionService.sendDiagnosticCommand(cmd);
                    _logConsole('>> [USER] $cmd');
                    _customCmdController.clear();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: isConnected
                  ? () {
                      final cmd = _customCmdController.text.trim();
                      if (cmd.isNotEmpty) {
                        connectionService.sendDiagnosticCommand(cmd);
                        _logConsole('>> [USER] $cmd');
                        _customCmdController.clear();
                      }
                    }
                  : null,
              child: const Text('SEND'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Terminal Output Console
        Container(
          height: 150,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: _consoleLines.isEmpty
              ? const Center(
                  child: Text(
                    'Terminal console ready. Outgoing OBD queries and decoded ECU packets will appear here.',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: _consoleLines.length,
                  itemBuilder: (_, idx) => Text(
                    _consoleLines[idx],
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: AppColors.primary,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 16),

        // Hardware Connection Instructions Card
        _buildHardwareGuideCard(),
      ],
    );
  }

  Widget _buildEcuMetricBox({
    required String label,
    required String value,
    required String unit,
    required TelemetrySource source,
    required Color accentColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: accentColor),
                  const SizedBox(width: 6),
                  Text(label, style: AppTypography.badgeText),
                ],
              ),
              ProvenanceBadge(source: source),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTypography.metricValue.copyWith(color: accentColor, fontSize: 24),
            ),
          ),
          const SizedBox(height: 2),
          Text(unit, style: AppTypography.bodySmall),
        ],
      ),
    );
  }

  Widget _buildHardwareGuideCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.two_wheeler, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text('TVS JUPITER 110 HARDWARE SETUP GUIDE', style: AppTypography.titleSmall),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'How to read RPM, Speed & Voltage directly from vehicle ECU:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            '1. SmartXonnect Digital Cluster:\n'
            '   Turn scooter ignition ON. In Tab 1, scan and connect to your TVS cluster. '
            '   Battery service (0x2A19) and TVS binary telemetry streams are parsed automatically.\n\n'
            '2. BS6 OBD-II Diagnostic Port (Direct ECU Access):\n'
            '   All TVS Jupiter 110 BS6 models have a standard Euro 5 diagnostic port under the seat. '
            '   Plug in a standard 6-pin to 16-pin adapter cable with any BLE OBD-II scanner (e.g. V-Gate iCar, ELM327 BLE). '
            '   Connect in Tab 1 and tap "START AUTO-POLL" to read ECU parameters at 5-10 Hz with 100% precision!',
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }

  // --- TAB 3: Raw Packets ---

  Widget _buildRawPacketsTab(BuildContext context, List<RawPacketLog> packetLogs) {
    if (packetLogs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No characteristic notifications captured yet.\nConnect to a peripheral to record incoming byte streams for safe protocol reverse-engineering.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: packetLogs.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, idx) {
        final log = packetLogs[idx];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    log.characteristicUuid.substring(0, 8),
                    style: AppTypography.badgeText.copyWith(color: AppColors.primary),
                  ),
                  Text(
                    '${log.timestamp.second}:${log.timestamp.millisecond}',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                log.hexString,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeviceTile(
    BuildContext context,
    BluetoothDeviceInfo dev,
    VehicleConnectionService service,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          dev.isLikelyTvsCluster ? Icons.two_wheeler : Icons.bluetooth,
          color: dev.isLikelyTvsCluster ? AppColors.primary : AppColors.textMuted,
        ),
        title: Text(
          dev.name,
          style: AppTypography.titleSmall.copyWith(
            color: dev.isLikelyTvsCluster ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          'ID: ${dev.id} • RSSI: ${dev.rssi} dBm',
          style: AppTypography.bodySmall,
        ),
        trailing: dev.isConnected
            ? const Text('CONNECTED', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold))
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceElevated,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('CONNECT'),
                onPressed: () async {
                  final success = await service.connect(dev.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Connected to ${dev.name}. GATT services enumerated.'
                              : 'Failed to connect. Ensure official TVS app is not holding exclusive connection.',
                        ),
                        backgroundColor: success ? AppColors.success : AppColors.error,
                      ),
                    );
                  }
                },
              ),
      ),
    );
  }
}
