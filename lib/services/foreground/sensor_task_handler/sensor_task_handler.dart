// lib/services/foreground/sensor_task_handler/sensor_task_handler.dart

import 'dart:async';
import 'package:motion_test/data/models/sensor_sample.dart';
import 'package:motion_test/data/db/sensor_db_controller.dart';
import 'package:motion_test/services/alarm_manager.dart';
import 'sensor_buffer.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '_sub_functions.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(SensorTaskHandler());
}

class SensorTaskHandler extends TaskHandler {
  StreamSubscription<AccelerometerEvent>? _accSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<UserAccelerometerEvent>? _userAccSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  final SensorBuffer<SensorSample> buffer = SensorBuffer<SensorSample>();

  static const String _labelRandom = 'Random';
  static const String _labelNimaz = 'Nimaz';

  String _labelCurrent = _labelRandom;

  late final int _bundleId;
  bool _bundleIdAquired = false;

  String _currentTag = 'not_set';
  late DateTime _serviceStartTime;

  late DateTime _plannedStopTime;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    scheduleDailyForegroundRuns();

    final result = await identifyCurrentTagWithTime();
    _currentTag = result.currentTag;
    _serviceStartTime = result.startTime;

    _bundleId = await SensorDbController.getNextBundleId();
    _bundleIdAquired = true;

    // 🔹 Default: 40 minutes max runtime
    _plannedStopTime = _serviceStartTime.add(const Duration(minutes: 40));

    await FlutterForegroundTask.updateService(
      notificationText:
          'Recording [$_labelCurrent] Sensor Data for [$_currentTag]',
    );

    // Subscribe to sensors
    _accSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.fastestInterval,
    ).listen((e) {
      buffer.add(SensorSample(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        type: 'ACC', x: e.x, y: e.y, z: e.z,
      ));
    });

    _gyroSub = gyroscopeEventStream(
      samplingPeriod: SensorInterval.fastestInterval,
    ).listen((e) {
      buffer.add(SensorSample(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        type: 'GYR', x: e.x, y: e.y, z: e.z,
      ));
    });

    _userAccSub = userAccelerometerEventStream(
      samplingPeriod: SensorInterval.fastestInterval,
    ).listen((e) {
      buffer.add(SensorSample(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        type: 'UACC', x: e.x, y: e.y, z: e.z,
      ));
    });

    _magSub = magnetometerEventStream(
      samplingPeriod: SensorInterval.fastestInterval,
    ).listen((e) {
      buffer.add(SensorSample(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        type: 'MAG', x: e.x, y: e.y, z: e.z,
      ));
    });
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    final batch = await buffer.takeAll();
    if (batch.isNotEmpty) {
      await SensorDbController.insertBatch(batch, bundleId: _bundleId);
    }

    // 🔥 Absolute-time lifecycle check
    if (DateTime.now().isAfter(_plannedStopTime)) {
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationButtonPressed(String id) async {
    super.onNotificationButtonPressed(id);

    if (id != 'switch_label' || !_bundleIdAquired) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    _labelCurrent =
        (_labelCurrent == _labelRandom) ? _labelNimaz : _labelRandom;

    await FlutterForegroundTask.updateService(
      notificationText:
          'Recording [$_labelCurrent] Sensor Data for [$_currentTag]',
    );

    await SensorDbController.insertTimeLabel(
      bundleId: _bundleId,
      timestamp: timestamp,
      label: _labelCurrent,
    );

    // ───────── Nimaz lifecycle rules ─────────
    if (_labelCurrent == _labelNimaz) {
      final now = DateTime.now();

      // Rule 1: At least 20 minutes when entering Nimaz
      final minNimazStop = now.add(const Duration(minutes: 20));
      if (_plannedStopTime.isBefore(minNimazStop)) {
        _plannedStopTime = minNimazStop;
      }

      // Rule 2: Must stop 5 minutes before next Nimaz
      final minutesToNextNimaz = await minutesUntilNextNimaz();
      final hardStop =
          now.add(Duration(minutes: minutesToNextNimaz - 5));

      if (_plannedStopTime.isAfter(hardStop)) {
        _plannedStopTime = hardStop;
      }
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _accSub?.cancel();
    await _gyroSub?.cancel();
    await _userAccSub?.cancel();
    await _magSub?.cancel();

    final batch = await buffer.takeAll();
    if (batch.isNotEmpty) {
      await SensorDbController.insertBatch(batch, bundleId: _bundleId);
    }

    await SensorDbController.bundleAndClearSamples(tag: _currentTag);
  }
}
