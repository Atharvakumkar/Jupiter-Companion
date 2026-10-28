# Jupiter Companion 🛵⚡

A premium, reliable Android companion application for the **TVS Jupiter 110/113.3cc scooter with SmartXonnect digital instrument cluster**.

Built with **Flutter & Dart**, **Kotlin Native Foreground Services**, **Embedded Google Maps**, **SQLite Local Persistence**, and **Riverpod**.

---

## 🚀 Key Features

1. **Rider-Controlled Manual Ride Recording:**
   - Dedicated **Start Ride**, **Pause**, **Resume**, and **End Ride** controls.
   - Screen-lock resilient tracking via native Android Kotlin Foreground Service (`FOREGROUND_SERVICE_LOCATION`).
   - Incremental atomic coordinate persistence in SQLite to protect against OS kills or process dismissal.
   - Rejects anomalous GPS jumps (>110 km/h or accuracy >30m) using physical plausibility filters.
2. **Embedded Google Maps (Replaces Mappls):**
   - High-contrast custom dark automotive map styling.
   - Live scooter marker with heading bearing and breadcrumb polyline.
   - Interactive route history replay with scrubbing slider and start/end markers.
3. **SmartXonnect Bluetooth Diagnostics & Safe GATT Inspector:**
   - BLE device discovery with automatic TVS cluster identification.
   - Safe GATT service and characteristic explorer (read/notify only; strict prohibition of arbitrary writes).
   - Live raw packet hex logger with sanitized log export for protocol reverse-engineering.
   - Automatic reconnection manager with bounded exponential backoff.
4. **Strict Telemetry Provenance (Zero Fabricated Metrics):**
   - Clear distinction between `GPS`, `ECU (Verified)`, `User Entry`, and `Calculated` sources.
   - Never fabricates fake RPM from GPS speed. Unverified parameters are labeled honestly as `UNAVAILABLE`.
5. **Maintenance Schedule & Reminders:**
   - Pre-configured with recommended TVS Jupiter service intervals (every 3,000 km or 90 days, 10W-30 oil).
   - Odometer-based reminder alerts and cost tracking.
6. **Fuel Logs & Economy Analytics:**
   - Refuel receipt logging with price per liter calculations.
   - Full-to-full consumption calculations.
7. **Saved Parking Location:**
   - Records parking coordinates upon ride completion or on-demand.
   - Visual map pin with "Get Directions" navigation launcher.
8. **Offline-First with Cloud Sync:**
   - Works 100% offline via local SQLite database.
   - Optional Firebase Firestore synchronization when authenticated and online.

---

## 🛠️ Technology Stack

* **UI Framework:** Flutter 3.47 / Dart 3.13
* **Native Android:** Kotlin (Android SDK 34/35/36, Gradle 9.3.1, Java 24)
* **Background Execution:** Android Foreground Service with `ServiceCompat.startForeground` & `PARTIAL_WAKE_LOCK`
* **Maps:** Google Maps Flutter SDK (`google_maps_flutter`)
* **Local Persistence:** SQLite (`sqflite`) with indexed coordinate tables
* **State Management:** Riverpod (`flutter_riverpod`)
* **Navigation:** `go_router` with shell navigation bar
* **Bluetooth:** `flutter_blue_plus` (GATT client & raw packet listener)

---

## 📱 Quick Start & Run Instructions

### Prerequisites
* Flutter SDK (3.47+)
* Android SDK (API 24+)
* Java Development Kit (JDK 17+)

### 1. Clone & Install Dependencies
```powershell
git clone <repo-url>
cd jupiter-companion
flutter pub get
```

### 2. Configure Google Maps API Key
Copy `.env.example` or add your key to `android/local.properties`:
```properties
MAPS_API_KEY=AIzaSyYourGoogleMapsApiKey
```

### 3. Run Automated Tests
```powershell
flutter test
```
All 23 unit and widget tests will execute and verify geo-math, state machines, and provenance badges.

### 4. Build Android Debug APK
```powershell
flutter build apk --debug
```
The compiled APK will be generated at:
`build/app/outputs/flutter-apk/app-debug.apk`

---

## 📚 Project Documentation

* [Architecture & Data Flow](docs/architecture.md)
* [Bluetooth Discovery & Telemetry Matrix](docs/bluetooth_discovery.md)
* [Google Maps SDK Setup](docs/google_maps_setup.md)
* [Firebase Setup & Security Rules](docs/firebase_setup.md)
* [Testing & Device Verification Guide](docs/testing.md)
* [Hardware & Platform Limitations](docs/limitations.md)

---

## ⚠️ Disclaimer
Jupiter Companion is an independent companion project engineered for the TVS Jupiter scooter. It is not officially affiliated with, endorsed by, or sponsored by TVS Motor Company.
