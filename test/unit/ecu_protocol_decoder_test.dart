import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:jupiter_companion/domain/models/telemetry.dart';
import 'package:jupiter_companion/domain/services/ecu_protocol_decoder.dart';

void main() {
  group('EcuProtocolDecoder Tests', () {
    test('Decodes OBD-II Engine RPM (Mode 01 PID 0C)', () {
      // "41 0C 1F A0" -> A=0x1F(31), B=0xA0(160) -> ((31*256)+160)/4 = 8096/4 = 2024 RPM
      final asciiBytes = ascii.encode('41 0C 1F A0\r');
      final frame = EcuProtocolDecoder.decode(asciiBytes);

      expect(frame, isNotNull);
      expect(frame!.rpm, 2024);
      expect(frame.protocol, EcuProtocolType.obd2Ascii);
      expect(frame.source, TelemetrySource.verifiedEcu);
    });

    test('Decodes OBD-II Vehicle Speed (Mode 01 PID 0D)', () {
      // "41 0D 32" -> 0x32 = 50 km/h
      final asciiBytes = ascii.encode('41 0D 32\r');
      final frame = EcuProtocolDecoder.decode(asciiBytes);

      expect(frame, isNotNull);
      expect(frame!.speedKmh, 50.0);
      expect(frame.protocol, EcuProtocolType.obd2Ascii);
    });

    test('Decodes OBD-II ECU Control Module Voltage (Mode 01 PID 42)', () {
      // "41 42 31 38" -> A=0x31(49), B=0x38(56) -> ((49*256)+56) = 12600 mV = 12.6V
      final asciiBytes = ascii.encode('41 42 31 38\r');
      final frame = EcuProtocolDecoder.decode(asciiBytes);

      expect(frame, isNotNull);
      expect(frame!.batteryVoltage, 12.6);
      expect(frame.batteryPercent, 73);
      expect(frame.protocol, EcuProtocolType.obd2Ascii);
    });

    test('Decodes ELM327 Direct Battery Voltage (ATRV)', () {
      final asciiBytes = ascii.encode('14.2V\r');
      final frame = EcuProtocolDecoder.decode(asciiBytes);

      expect(frame, isNotNull);
      expect(frame!.batteryVoltage, 14.2);
      expect(frame.batteryPercent, 100);
      expect(frame.protocol, EcuProtocolType.obd2Ascii);
    });

    test('Decodes TVS SmartXonnect Binary Telemetry Frame (Header 0xAA)', () {
      // [0xAA, 0x10, speed=45, rpmHigh=0x09, rpmLow=0xC4 (2500 RPM), volt=128 (12.8V)]
      final binaryBytes = [0xAA, 0x10, 45, 0x09, 0xC4, 128];
      final frame = EcuProtocolDecoder.decode(binaryBytes);

      expect(frame, isNotNull);
      expect(frame!.speedKmh, 45.0);
      expect(frame.rpm, 2500);
      expect(frame.batteryVoltage, 12.8);
      expect(frame.protocol, EcuProtocolType.tvsBinary);
      expect(frame.source, TelemetrySource.verifiedEcu);
    });

    test('Decodes Standard BLE Battery Service (UUID 0x2A19)', () {
      final batteryBytes = [85]; // 85%
      final frame = EcuProtocolDecoder.decode(
        batteryBytes,
        characteristicUuid: '00002a19-0000-1000-8000-00805f9b34fb',
      );

      expect(frame, isNotNull);
      expect(frame!.batteryPercent, 85);
      expect(frame.batteryVoltage, closeTo(12.775, 0.01));
      expect(frame.protocol, EcuProtocolType.bleStandardBattery);
    });

    test('Ignores random invalid noise bytes safely', () {
      final noiseBytes = [0x00, 0x01, 0x02];
      final frame = EcuProtocolDecoder.decode(noiseBytes);

      expect(frame, isNull);
    });
  });
}

