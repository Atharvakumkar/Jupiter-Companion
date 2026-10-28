# Jupiter Companion — Architecture Documentation

## 1. High-Level Architectural Vision

Jupiter Companion is an independent motorcycle and scooter companion application engineered specifically for the **TVS Jupiter 110/113.3cc with SmartXonnect digital cluster**.

The system addresses the five core real-world pain points of connected scooter experiences:
1. **Background Service Termination:** Android aggressively kills background tasks when the phone locks. Jupiter Companion implements a native Kotlin Foreground Service (`FOREGROUND_SERVICE_LOCATION`) with a persistent status notification and partial wake lock.
2. **Unreliable Automatic Trip Detection:** Many rider apps attempt to guess when a ride starts, leading to lost segments or false recordings. Jupiter Companion prioritizes rider-controlled, explicit **Start Ride** and **End Ride** sessions with durable SQLite storage.
3. **Laggy Mappls Integration:** Replaced with a hardware-accelerated **Google Maps SDK** integration styled in high-contrast dark automotive mode.
4. **Unreliable or Fabricated Telemetry:** Strict data provenance. GPS-derived speed is never conflated with ECU engine speed. RPM is never simulated from GPS. Unverified fields are honestly reported as unavailable.
5. **Unified Dashboard:** Ride history, route replay, scheduled maintenance intervals, refuel expense logs, and saved parking locations unified in one dark automotive cluster interface.

---

## 2. Layered Feature-First Architecture

```
jupiter_companion/
├── android/app/src/main/
│   ├── kotlin/com/antigravity/jupitercompanion/jupiter_companion/
│   │   ├── MainActivity.kt                       # Method & EventChannel bridges
│   │   └── services/RideTrackingForegroundService.kt # Persistent native location service
│   └── AndroidManifest.xml                       # Foreground service & permissions
├── lib/
│   ├── app/                                      # Application lifecycle, theme, routing, DI
│   │   ├── app.dart                              # Root MaterialApp.router
│   │   ├── router.dart                           # GoRouter configuration & shell navigation
│   │   ├── providers.dart                        # Riverpod dependency injection graph
│   │   ├── theme/                                # Dark automotive palette & typography
│   │   └── widgets/                              # SpeedometerGauge, MetricTile, ProvenanceBadge
│   ├── core/                                     # Core cross-cutting utilities
│   │   ├── errors/                               # Domain failure definitions
│   │   ├── permissions/                          # Runtime permission handling
│   │   └── utils/                                # Haversine math, GPS plausibility filters
│   ├── data/                                     # Persistent storage & platform integrations
│   │   ├── local/                                # SQLite database (AppDatabase) & SharedPreferences
│   │   ├── platform/                             # Native Android channel bridges
│   │   └── repositories/                         # Local implementations of repositories
│   ├── domain/                                   # Pure business models, contracts, and services
│   │   ├── models/                               # Ride, RoutePoint, Telemetry, Maintenance, FuelLog, Parking
│   │   ├── repositories/                         # Abstract repository interfaces
│   │   └── services/                             # RideTrackingService, AutoRideDetector, VehicleConnection
│   └── features/                                 # Feature presentation & UI
│       ├── dashboard/                            # Cluster overview, quick metrics, status
│       ├── rides/                                # Ride recording, history, route replay
│       ├── maps/                                 # Live route map, dark Google Maps styling
│       ├── vehicle_connection/                   # BLE scanner, GATT inspector, raw packet dump
│       ├── telemetry/                            # Live telemetry with provenance verification
│       ├── maintenance/                          # Service schedule & reminders
│       ├── fuel_expenses/                        # Fuel refuels, costs, mileage calculation
│       ├── parking/                              # Saved parking pin & directions
│       ├── settings/                             # Preferences, permissions, vehicle profile
│       └── onboarding/                           # Splash screen, initialization, guest mode
├── test/                                         # Automated unit & widget tests
└── docs/                                         # Operational & protocol specifications
```

---

## 3. Data Flow & Provenance Architecture

```
[Phone GNSS Receiver]
        │
        ▼ (Every 1s / 1m)
[Android RideTrackingForegroundService] (Native Kotlin)
        │
        ├─► [Persistent Notification] (Updated with current speed & point count)
        ▼ (EventChannel stream)
[NativeTrackingChannel] (Dart Platform Channel)
        ▼
[RideTrackingService]
        ├─► [GeoUtils.isPointPlausible] (Rejects GPS jumps >110 km/h or accuracy >30m)
        ├─► [Haversine Distance Accumulator]
        ├─► [Incremental SQLite Point Insert] (`route_points` table)
        └─► [Periodic Ride Header Update] (`rides` table)
        ▼
[ActiveRideState StreamProvider]
        ▼
[Presentation Layer] (Dashboard, Live Map, Gauge)
```

---

## 4. Ride State Machine

```
              ┌─────────┐
              │  IDLE   │
              └────┬────┘
                   │ startRide()
                   ▼
              ┌───────────┐
              │ STARTING  │
              └────┬──────┘
                   │ Foreground service started
                   ▼
        ┌──────►┌───────────┐◄──────┐
        │       │ RECORDING │       │
        │       └────┬──────┘       │
resume()│            │ pause()      │
        │            ▼              │
        │       ┌─────────┐         │
        └───────┤ PAUSED  ├─────────┘
                └────┬────┘
                     │ endRide()
                     ▼
              ┌────────────┐
              │ FINALIZING │
              └────┬───────┘
                   │ Summary calculated, parking offered
                   ▼
              ┌───────────┐
              │ COMPLETED │
              └───────────┘
```

---

## 5. Resilient Recovery Mechanics

* **Atomic Session Persistence:** The ride record is written to SQLite *before* the first location point is recorded.
* **Incremental Points:** Coordinates are appended to SQLite immediately upon passing plausibility checks. If the process is recreated or the user clears the app from the recent apps list, points already flushed to disk are safe.
* **Process Recreation Recovery:** On startup, `RideTrackingService.restoreSessionIfInterrupted()` queries SQLite for any ride in `RECORDING` or `PAUSED` state. If found, it recovers elapsed duration, distance, and points, checks if the Android foreground service is still active, and resumes streaming without creating duplicate rides.

