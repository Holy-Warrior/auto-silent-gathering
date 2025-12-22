# Auto Silent Gathering

A Flutter-based Android foreground service for **continuous, time-aware motion sensor data collection**, designed around **Nimaz (prayer) schedules** with strict lifecycle guarantees.

The system prioritizes **correct execution windows**, **predictable shutdown**, and **data integrity**, even under dynamic label changes and alarm overlaps.

---

## 🧠 Core Idea

- Sensors run **only when allowed**
- Nimaz periods receive **focused, bounded data**
- Services **never overrun** into the next scheduled alarm
- All lifecycle decisions are **time-based, not counter-based**

---

## Architecture on FigJam
[Open Figma Figjam board](https://www.figma.com/board/PoB8R81aaIFJuOnStNscp4/Auto-Silent-Gathering?node-id=0-1&t=phJCG8GcxQGWFB8s-1)

---

## 🧩 Architecture (v1.4.0)

### UI Layer

- `main.dart`
  - App bootstrap
  - Alarm manager initialization
  - Foreground task permission setup

- `HomeScreen`
  - Loads & persists Nimaz timings via `Prefs`
  - Schedules daily alarms and foreground services
  - Displays GitHub release checker
  - Uses `FutureBuilder` correctly for async preferences

- `NimazTimingsForm`
  - Stateless widget
  - Localized 12-hour formatting using `MaterialLocalizations`

---

### Persistence Layer

#### SharedPreferences

- `Prefs.Alarms`
- Stores **5 Nimaz timings** in 24-hour `[hour, minute]` format

#### SQLite (sqflite)

Tables:

- `sensor_samples`
- `time_label`
- `sensor_bundles`

Controlled via:

- `DBInit`
- `DBTables`
- `SensorDbController`

All writes are **batched** and finalized during service teardown.

---

### Scheduling Layer

- `android_alarm_manager_plus`
  - 5 daily **exact** alarms
  - Each alarm triggers `alarmCallback`
  - Callback starts the foreground service

---

### Foreground Execution

- `flutter_foreground_task`

#### `SensorTaskHandler`

Responsibilities:

- Starts accelerometer, gyroscope, user-accelerometer, and magnetometer
- Buffers sensor samples in memory
- Periodically flushes to SQLite
- Supports notification button-based label switching
- Enforces **strict lifecycle guarantees**
- Performs final bundling on service destruction

---

### 🕒 Lifecycle & Timing Rules (Critical)

The foreground service lifecycle is governed by **absolute timestamps**, not counters.

#### Default Rules

- **Maximum runtime:** 40 minutes
- Lifecycle is controlled by a single variable:
  ```dart
  DateTime _plannedStopTime
