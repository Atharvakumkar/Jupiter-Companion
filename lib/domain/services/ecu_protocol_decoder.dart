import 'dart:convert';
import '../models/telemetry.dart';

enum EcuProtocolType {
  obd2Ascii,
  tvsBinary,
  bleStandardBattery,
  unknown,
}

/// Strongly-typed verified ECU frame parsed from physical vehicle hardware.
class DecodedEcuFrame {
  final DateTime timestamp;
  final int? rpm;
  final double? speedKmh;
  final double? batteryVoltage;
  final int? batteryPercent;
  final double? odometerKm;
  final TelemetrySource source;
  final EcuProtocolType protocol;
  final String rawHex;
  final String? diagnosticNote;

  const DecodedEcuFrame({
    required this.timestamp,
    this.rpm,
    this.speedKmh,
    this.batteryVoltage,
    this.batteryPercent,
    this.odometerKm,
    this.source = TelemetrySource.verifiedEcu,
    required this.protocol,
    required this.rawHex,
    this.diagnosticNote,
  });

  bool get hasAnyMetric =>
      rpm != null || speedKmh != null || batteryVoltage != null || odometerKm != null;

  @override
  String toString() {
    return 'DecodedEcuFrame(protocol: $protocol, rpm: $rpm, speed: $speedKmh km/h, volt: ${batteryVoltage}V, odo: $odometerKm km)';
  }
}

/// Comprehensive ECU Telemetry Protocol Decoder for TVS Jupiter 110 & BS6 OBD-II.
class EcuProtocolDecoder {
  /// Primary dispatch method: takes incoming raw bytes from Bluetooth peripheral
  /// and detects whether it is an SAE J1979 OBD-II ASCII response, a TVS SmartXonnect
  /// binary frame, or a standard BLE Battery characteristic.
  static DecodedEcuFrame? decode(
    List<int> bytes, {
    String characteristicUuid = '',
  }) {
    if (bytes.isEmpty) return null;

    final charUuidLower = characteristicUuid.toLowerCase();

    // 1. Check standard Bluetooth SIG Battery Service UUID (0x2A19)
    if (charUuidLower.contains('2a19') || charUuidLower.contains('180f')) {
      return decodeBleBattery(bytes);
    }

    // 2. Try parsing as ASCII text (standard ELM327 / OBD-II responses)
    final asciiString = _tryExtractAscii(bytes);
    if (asciiString != null) {
      final obdFrame = decodeObdAscii(asciiString, rawBytes: bytes);
      if (obdFrame != null) return obdFrame;
    }

    // 3. Try parsing as TVS SmartXonnect Binary Telemetry Frame
    final binaryFrame = decodeTvsBinary(bytes);
    if (binaryFrame != null) return binaryFrame;

    return null;
  }

  /// Decode standard SAE J1979 OBD-II response string
  /// Examples:
  /// - RPM: "41 0C 1F A0" -> 2024 RPM
  /// - Speed: "41 0D 2A" -> 42 km/h
  /// - Voltage: "41 42 31 38" -> 12.6V
  /// - ATRV: "12.6V" -> 12.6V
  /// - Odometer (PID A6): "41 A6 00 01 E2 40" -> 12345.6 km
  static DecodedEcuFrame? decodeObdAscii(String text, {List<int>? rawBytes}) {
    final cleaned = text.replaceAll('\r', ' ').replaceAll('\n', ' ').trim();
    final hexRaw = rawBytes != null
        ? rawBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')
        : cleaned;

    // Check ELM327 ATRV Voltage command response: e.g. "12.6V" or "13.8V"
    final atrvMatch = RegExp(r'(\d{1,2}\.\d)\s*V', caseSensitive: false).firstMatch(cleaned);
    if (atrvMatch != null) {
      final v = double.tryParse(atrvMatch.group(1)!);
      if (v != null && v >= 9.0 && v <= 16.0) {
        final percent = (((v - 11.5) / 1.5) * 100).clamp(0, 100).toInt();
        return DecodedEcuFrame(
          timestamp: DateTime.now(),
          batteryVoltage: v,
          batteryPercent: percent,
          protocol: EcuProtocolType.obd2Ascii,
          rawHex: hexRaw,
          diagnosticNote: 'ELM327 direct battery voltage read (ATRV)',
        );
      }
    }

    // Standard OBD-II hex stream: remove spaces and normalize
    final compact = cleaned.replaceAll(' ', '').toUpperCase();

    // Mode 01 PID 0C: Engine RPM ("410Cxxxx")
    final rpmMatch = RegExp(r'410C([0-9A-F]{4})').firstMatch(compact);
    if (rpmMatch != null) {
      final hexVal = rpmMatch.group(1)!;
      final a = int.parse(hexVal.substring(0, 2), radix: 16);
      final b = int.parse(hexVal.substring(2, 4), radix: 16);
      final rpm = ((a * 256) + b) ~/ 4;
      return DecodedEcuFrame(
        timestamp: DateTime.now(),
        rpm: rpm,
        protocol: EcuProtocolType.obd2Ascii,
        rawHex: hexRaw,
        diagnosticNote: 'SAE J1979 Mode 01 PID 0C (Engine RPM)',
      );
    }

    // Mode 01 PID 0D: Vehicle Speed ("410Dxx")
    final speedMatch = RegExp(r'410D([0-9A-F]{2})').firstMatch(compact);
    if (speedMatch != null) {
      final hexVal = speedMatch.group(1)!;
      final speed = int.parse(hexVal, radix: 16).toDouble();
      return DecodedEcuFrame(
        timestamp: DateTime.now(),
        speedKmh: speed,
        protocol: EcuProtocolType.obd2Ascii,
        rawHex: hexRaw,
        diagnosticNote: 'SAE J1979 Mode 01 PID 0D (Vehicle Speed)',
      );
    }

    // Mode 01 PID 42: Control Module Voltage ("4142xxxx")
    final voltMatch = RegExp(r'4142([0-9A-F]{4})').firstMatch(compact);
    if (voltMatch != null) {
      final hexVal = voltMatch.group(1)!;
      final a = int.parse(hexVal.substring(0, 2), radix: 16);
      final b = int.parse(hexVal.substring(2, 4), radix: 16);
      final millivolts = (a * 256) + b;
      final volts = millivolts / 1000.0;
      final percent = (((volts - 11.5) / 1.5) * 100).clamp(0, 100).toInt();
      return DecodedEcuFrame(
        timestamp: DateTime.now(),
        batteryVoltage: volts,
        batteryPercent: percent,
        protocol: EcuProtocolType.obd2Ascii,
        rawHex: hexRaw,
        diagnosticNote: 'SAE J1979 Mode 01 PID 42 (ECU Module Voltage)',
      );
    }

    // Mode 01 PID A6: Odometer ("41A6xxxxxxxx")
    final odoMatch = RegExp(r'41A6([0-9A-F]{8})').firstMatch(compact);
    if (odoMatch != null) {
      final hexVal = odoMatch.group(1)!;
      final odoRaw = int.parse(hexVal, radix: 16);
      final odoKm = odoRaw / 10.0;
      return DecodedEcuFrame(
        timestamp: DateTime.now(),
        odometerKm: odoKm,
        protocol: EcuProtocolType.obd2Ascii,
        rawHex: hexRaw,
        diagnosticNote: 'SAE J1979 Mode 01 PID A6 (Odometer)',
      );
    }

    return null;
  }

  /// Decode TVS SmartXonnect Binary Telemetry Frame
  /// TVS digital clusters emit framed telemetry when active notifications are enabled.
  /// Frame structure:
  /// - Header: [0xAA] or [0x55] or [0x02]
  /// - Packet Type: [0x10] (Live Telemetry) or [0x0C] (Engine Status)
  /// - Length: 1 byte
  /// - Speed: 1 byte (km/h)
  /// - RPM: 2 bytes (High, Low)
  /// - Voltage: 1 byte (tenths of volt: 126 = 12.6V)
  static DecodedEcuFrame? decodeTvsBinary(List<int> bytes) {
    if (bytes.length < 6) return null;

    final hexRaw = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

    // TVS Frame Type 1: Header 0xAA or 0x55
    if (bytes[0] == 0xAA || bytes[0] == 0x55) {
      final cmd = bytes[1];
      if (cmd == 0x10 || cmd == 0x0C) {
        final speed = bytes[2].toDouble();
        final rpmHigh = bytes[3];
        final rpmLow = bytes[4];
        final rpm = (rpmHigh * 256) + rpmLow;
        double? voltage;
        int? batteryPct;

        if (bytes.length >= 6) {
          final voltByte = bytes[5];
          if (voltByte >= 90 && voltByte <= 160) {
            voltage = voltByte / 10.0;
            batteryPct = (((voltage - 11.5) / 1.5) * 100).clamp(0, 100).toInt();
          }
        }

        if (rpm >= 0 && rpm <= 10000 && speed >= 0.0 && speed <= 125.0) {
          return DecodedEcuFrame(
            timestamp: DateTime.now(),
            rpm: rpm,
            speedKmh: speed,
            batteryVoltage: voltage,
            batteryPercent: batteryPct,
            protocol: EcuProtocolType.tvsBinary,
            rawHex: hexRaw,
            diagnosticNote: 'TVS SmartXonnect Binary Cluster Frame (Cmd 0x${cmd.toRadixString(16)})',
          );
        }
      }
    }

    // TVS Frame Type 2: STX (0x02) framed message
    if (bytes[0] == 0x02 && bytes.length >= 7) {
      final speed = bytes[1].toDouble();
      final rpm = ((bytes[2] * 256) + bytes[3]) ~/ (bytes.length > 8 ? 4 : 1);
      final voltRaw = bytes[4];
      final voltage = voltRaw > 50 ? voltRaw / 10.0 : 12.0 + (voltRaw / 50.0);

      if (rpm >= 0 && rpm <= 10000 && speed >= 0.0 && speed <= 125.0) {
        return DecodedEcuFrame(
          timestamp: DateTime.now(),
          rpm: rpm,
          speedKmh: speed,
          batteryVoltage: voltage,
          batteryPercent: (((voltage - 11.5) / 1.5) * 100).clamp(0, 100).toInt(),
          protocol: EcuProtocolType.tvsBinary,
          rawHex: hexRaw,
          diagnosticNote: 'TVS SmartXonnect STX Framed Telemetry',
        );
      }
    }

    return null;
  }

  /// Decode standard Bluetooth SIG Battery Service (UUID 0x2A19)
  static DecodedEcuFrame? decodeBleBattery(List<int> bytes) {
    if (bytes.isEmpty) return null;

    final hexRaw = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

    if (bytes.length == 1) {
      final level = bytes[0].clamp(0, 100);
      // Lead-Acid 12V voltage curve: 0% = 11.5V, 100% = 13.0V
      final voltage = 11.5 + (level / 100.0) * 1.5;
      return DecodedEcuFrame(
        timestamp: DateTime.now(),
        batteryPercent: level,
        batteryVoltage: voltage,
        protocol: EcuProtocolType.bleStandardBattery,
        rawHex: hexRaw,
        diagnosticNote: 'Bluetooth SIG Battery Service (UUID 0x2A19)',
      );
    } else if (bytes.length >= 2) {
      // 2-byte millivolts e.g. 12600 mV = 12.6V
      final mv = (bytes[0] * 256) + bytes[1];
      if (mv >= 9000 && mv <= 16000) {
        final v = mv / 1000.0;
        final pct = (((v - 11.5) / 1.5) * 100).clamp(0, 100).toInt();
        return DecodedEcuFrame(
          timestamp: DateTime.now(),
          batteryVoltage: v,
          batteryPercent: pct,
          protocol: EcuProtocolType.bleStandardBattery,
          rawHex: hexRaw,
          diagnosticNote: 'Bluetooth SIG Battery Millivolts (UUID 0x2A19)',
        );
      }
    }

    return null;
  }

  static String? _tryExtractAscii(List<int> bytes) {
    try {
      // Must contain printable ASCII characters and either '41' (OBD response), 'V', or 'OK'
      final s = ascii.decode(bytes);
      if (s.contains('41') || s.contains('AT') || s.contains('V') || s.contains('>')) {
        return s;
      }
    } catch (_) {}
    return null;
  }
}

extension IntRangeCheck on int {
  bool inRange(int min, int max) => this >= min && this <= max;
}

extension DoubleRangeCheck on double {
  bool inRange(double min, double max) => this >= min && this <= max;
}
