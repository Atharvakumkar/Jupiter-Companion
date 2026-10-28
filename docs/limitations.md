# Jupiter Companion — Known Hardware & Platform Limitations

## 1. Operating System & Background Execution Boundaries

1. **Android Force-Stop:** If the user executes an explicit **Force Stop** from Android Settings or an aggressive OEM battery cleaner (e.g. Xiaomi MIUI Security, Oppo/Vivo Phone Master), Android halts all foreground services immediately. Neither Flutter nor native Android services can survive an explicit user force-stop.
2. **Revoked Permissions Mid-Ride:** If the rider navigates to OS settings during an active ride session and revokes Location permissions, Android destroys the location provider. Jupiter Companion catches this exception, marks the point as unavailable, and preserves all previously collected points in SQLite.
3. **Battery Optimization Whitelisting:** While Android 14+ `FOREGROUND_SERVICE_LOCATION` with a persistent notification allows recording with the screen locked, riders on aggressive battery-management ROMs should disable battery optimization in **Settings > Battery Optimization** for Jupiter Companion.

---

## 2. SmartXonnect Hardware & Protocol Boundaries

1. **Proprietary Vehicle Telemetry:** The TVS SmartXonnect cluster broadcasts proprietary BLE advertisements and GATT characteristics. To ensure engineering integrity:
   * **RPM:** Not currently exposed as a verified standard characteristic. Jupiter Companion **does not simulate RPM from GPS speed**.
   * **Cluster Odometer:** Can be entered manually in the app until an official characteristic mapping is reverse-engineered and verified on a physical Jupiter scooter.
2. **Bluetooth Connection Exclusivity:** A BLE peripheral cluster typically permits only **one** active GATT connection at a time. If the official TVS Connect application is open in the background and holds an active link, Jupiter Companion will be unable to establish a GATT connection until TVS Connect is disconnected.
3. **No Remote Vehicle Tracking:** Saving parking location records the phone's GNSS coordinates when the rider parks. It does **not** query an embedded cellular IoT modem on the scooter.

---

## 3. GNSS & Environmental Limitations

1. **Tunnels, Basements, and Urban Canyons:** GPS signals bounce or drop when entering multi-level underground parking or tunnels. Jupiter Companion's `GeoUtils.isPointPlausible` rejects inaccurate signals (>30m error) to prevent drift inflation.
2. **Static Drift:** When paused at a long traffic signal, phone GNSS can drift 5–15 meters. Moving duration stops counting when speed is <1.5 km/h to prevent inflating moving time.

