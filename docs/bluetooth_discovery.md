# TVS Jupiter SmartXonnect & ECU Telemetry Protocol Specification

## 1. Executive Summary & Vehicle Architecture

The TVS Jupiter 110/113.3cc scooter (BS6 with SmartXonnect) features an electronic fuel injection (EFI) Keihin/Bosch Engine Control Unit (ECU) connected to an integrated digital instrument cluster.

### Vehicle Data Paths:
```
+-------------------------------------------------------------+
|              TVS Jupiter 110 BS6 Vehicle Core               |
+-------------------------------------------------------------+
     |                                               |
     | (CAN / Serial Line)                           | (Diagnostic Port K-Line / CAN)
     v                                               v
+-------------------------------+       +------------------------------------+
|  SmartXonnect Digital Cluster |       |    BS6 Diagnostic Port (6-Pin)     |
|  - Built-in BLE Transceiver   |       |    - Euro 5 Standard Automotive    |
|  - Battery Service (0x180F)   |       |    - Direct Keihin/Bosch ECU Bus   |
|  - Vendor Telemetry (0xFFE0)  |       +------------------------------------+
+-------------------------------+                          |
     |                                                     | (6-pin to 16-pin Adapter)
     | (BLE GATT Notifications)                            v
     |                                  +------------------------------------+
     |                                  |   ELM327 / OBDLink BLE Scanner     |
     +-------------------+              +------------------------------------+
                         |                                 |
                         v                                 v
               +---------------------------------------------------+
               |       Jupiter Companion Android Application       |
               |                                                   |
               |  - EcuProtocolDecoder (SAE J1979 + TVS Binary)    |
               |  - LiveClusterController (Real-Time Gauges)       |
               |  - Strict Provenance Tagging: [ECU VERIFIED]     |
               +---------------------------------------------------+
```

---

## 2. Reading Telemetry Directly from the ECU

Riders and technicians can query live Engine RPM, Vehicle Speed, and Battery Voltage through two supported channels:

### Path A: Direct BS6 OBD-II Diagnostic Port (Direct ECU Access)
All TVS Jupiter 110 BS6 scooters manufactured in India incorporate a mandatory diagnostic port located under the utility seat box or behind the front apron maintenance cover.

#### Diagnostic Connector Pinout (TVS 6-Pin Euro 5 to OBD-II 16-Pin):
| TVS 6-Pin Connector | Function | Standard OBD-II 16-Pin Pinout |
| :--- | :--- | :--- |
| **Pin 1** | Battery Positive (+12V DC) | Pin 16 (Battery Power) |
| **Pin 2** | Chassis Ground | Pin 4 & Pin 5 (Ground) |
| **Pin 3** | K-Line (ISO 9141-2 / ISO 14230-4 KWP) | Pin 7 (K-Line) |
| **Pin 4** | CAN-High (ISO 15765-4, 500 kbps) | Pin 6 (CAN-H) |
| **Pin 5** | CAN-Low (ISO 15765-4, 500 kbps) | Pin 14 (CAN-L) |
| **Pin 6** | Ignition Sense (+12V switched) | Pin 1 / Switched VCC |

#### Supported SAE J1979 OBD-II Diagnostic PIDs:
1. **Engine RPM (Mode 01 PID 0C)**:
   - Query: `010C\r`
   - Response: `41 0C A B`
   - Formula: $\text{RPM} = \frac{(A \times 256) + B}{4}$
   - Range: $0 - 16,383\,\text{RPM}$ (TVS Jupiter normal idle: $1,400 - 1,600\,\text{RPM}$, redline: $7,500\,\text{RPM}$)
2. **Vehicle Speed (Mode 01 PID 0D)**:
   - Query: `010D\r`
   - Response: `41 0D A`
   - Formula: $\text{Speed} = A\,\text{km/h}$
   - Range: $0 - 255\,\text{km/h}$
3. **ECU Control Module Voltage (Mode 01 PID 42)**:
   - Query: `0142\r`
   - Response: `41 42 A B`
   - Formula: $\text{Voltage} = \frac{(A \times 256) + B}{1000}\,\text{V}$
   - Range: $9.0 - 16.0\,\text{V}$
4. **Direct ELM327 Battery Voltage**:
   - Query: `ATRV\r`
   - Response: `12.6V` or `14.2V` (Measured directly at Pin 16)
5. **Scooter Odometer (Mode 01 PID A6)**:
   - Query: `01A6\r`
   - Response: `41 A6 A B C D`
   - Formula: $\text{Odometer} = \frac{A \times 2^{24} + B \times 2^{16} + C \times 2^8 + D}{10}\,\text{km}$

---

### Path B: TVS SmartXonnect Bluetooth Cluster Protocol

When pairing directly with the SmartXonnect digital cluster:
1. **Bluetooth SIG Battery Service (`UUID 0x180F` / Characteristic `0x2A19`)**:
   - Emits battery state of charge (SoC %).
   - Decoded to 12V lead-acid voltage curve: $V = 11.5 + (\% / 100.0) \times 1.5\,\text{V}$.
2. **TVS Binary Telemetry Frames (`UUID 0xFFE0` / Characteristic `0xFFE1` or Nordic UART)**:
   - Header: `0xAA` or `0x55` or `0x02`
   - Command: `0x10` (Live Telemetry) or `0x0C` (Engine Status)
   - Payload:
     - Byte 2: Speed ($0 - 120\,\text{km/h}$)
     - Bytes 3-4: RPM ($\text{High Byte} \times 256 + \text{Low Byte}$)
     - Byte 5: Battery Voltage (in tenths of a volt: $126 = 12.6\,\text{V}$)
     - Byte 6: Eco / Power Mode flag

---

## 3. Data Provenance & Safety Rules

1. **Strict Provenance Tagging**:
   - When ECU packets arrive, parameters are instantly tagged with `ProvenanceBadge(source: TelemetrySource.verifiedEcu)` rendered in cyan.
   - When disconnected, Speed cleanly falls back to `GPS` provenance, while RPM shows `UNAVAILABLE (Requires Verified ECU Stream)`.
2. **Zero Faked Values**:
   - Jupiter Companion never synthesizes RPM from GPS speed or estimates voltage without measurement.
   - Test Bench Simulation Mode is provided for desktop testing, explicitly marked with `SIMULATED TEST BENCH`.
3. **Safe Handshake**:
   - Diagnostic writes are restricted to standard read queries (`010C`, `010D`, `0142`, `ATRV`, `0100`). Arbitrary flash memory writes are blocked.
