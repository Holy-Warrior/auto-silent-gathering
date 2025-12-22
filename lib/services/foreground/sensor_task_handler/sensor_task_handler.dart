// lib/services/foreground/sensor_task_handler/sensor_task_handler.dart

import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:motion_test/data/db/sensor_db_controller.dart';
import 'package:motion_test/data/models/sensor_sample.dart';
import 'package:motion_test/data/models/sensor_task_state.dart';
import 'package:motion_test/data/prefs.dart';
import 'package:motion_test/services/alarm_manager.dart';

import 'sensor_buffer.dart';
import '_sub_functions.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(SensorTaskHandler());
}

class SensorTaskHandler extends TaskHandler {
  // ───────── Sensors ─────────
  late Map<String, Map<String, StreamSubscription>> _sensorSubs;
  final SensorBuffer<SensorSample> buffer = SensorBuffer<SensorSample>();

  // ───────── Labels ─────────
  static const String _labelRandom = 'Random';
  static const String _labelNimaz = 'Nimaz';

  String _labelCurrent = _labelRandom;
  String get _labelEmoji => _labelCurrent == _labelNimaz ? '🕌' : '';

  // ───────── Bundle ─────────
  late int _bundleId;
  bool _bundleIdAquired = false;

  // ───────── Lifecycle ─────────
  String _currentTag = 'not_set';
  // late DateTime _serviceStartTime;
  late DateTime _plannedStopTime;
  bool _intentionalStop = false;


  // ─────────────────────────────
  // START
  // ─────────────────────────────
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    scheduleDailyForegroundRuns();

    // ── Tag & time context
    final result = await identifyCurrentTagWithTime();
    _currentTag = result.currentTag;
    // _serviceStartTime = result.startTime;

    // ── Restore previous task state (consume-once)
    final SensorTaskState restored =
        await Prefs.SensorTask.getStateOrDefaults();

    _labelCurrent = restored.label;
    _plannedStopTime = restored.plannedStopTime;

    if (restored.bundleId != null) {
      // Resume same logical session
      _bundleId = restored.bundleId!;
      _bundleIdAquired = true;
    } else {
      // Fresh session
      _bundleId = await SensorDbController.getNextBundleId();
      _bundleIdAquired = true;
    }

    // ── Notification
    await FlutterForegroundTask.updateService(
      notificationText:
          '${_labelEmoji}Recording [$_labelCurrent] Sensor Data for [$_currentTag]',
    );

    // ── Sensors
    _sensorSubs = await subscribeToAllSensors(buffer);
  }

  // ─────────────────────────────
  // PERIODIC FLUSH
  // ─────────────────────────────
  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    final batch = await buffer.takeAll();
    if (batch.isNotEmpty) {
      await SensorDbController.insertBatch(batch, bundleId: _bundleId);
    }

    // Absolute-time stop
    if (DateTime.now().isAfter(_plannedStopTime)) {
      _intentionalStop = true;
      FlutterForegroundTask.stopService();
    }
  }

  // ─────────────────────────────
  // NOTIFICATION ACTION
  // ─────────────────────────────
  @override
  void onNotificationButtonPressed(String id) async {
    super.onNotificationButtonPressed(id);

    if (id != 'switch_label' || !_bundleIdAquired) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Toggle label
    _labelCurrent =
        (_labelCurrent == _labelRandom) ? _labelNimaz : _labelRandom;

    await FlutterForegroundTask.updateService(
      notificationText:
          '${_labelEmoji}Recording [$_labelCurrent] Sensor Data for [$_currentTag]',
    );

    await SensorDbController.insertTimeLabel(
      bundleId: _bundleId,
      timestamp: timestamp,
      label: _labelCurrent,
    );

    // ───────── Nimaz lifecycle rules ─────────
    if (_labelCurrent == _labelNimaz) {
      final now = DateTime.now();

      // Rule 1: minimum 20 minutes
      final minStop = now.add(const Duration(minutes: 20));
      if (_plannedStopTime.isBefore(minStop)) {
        _plannedStopTime = minStop;
      }

      // Rule 2: stop 5 minutes before next Nimaz
      final minutesToNext = await minutesUntilNextNimaz();
      final hardStop = now.add(Duration(minutes: minutesToNext - 5));

      if (_plannedStopTime.isAfter(hardStop)) {
        _plannedStopTime = hardStop;
      }
    }
  }

  // ─────────────────────────────
  // DESTROY
  // ─────────────────────────────
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Save ONLY if unintentional
    if (!_intentionalStop) {
      await Prefs.SensorTask.saveState(
        label: _labelCurrent,
        plannedStopTime: _plannedStopTime,
        bundleId: _bundleIdAquired ? _bundleId : null,
      );
    }

    await cancelAllSubscriptions(_sensorSubs);

    final batch = await buffer.takeAll();
    if (batch.isNotEmpty) {
      await SensorDbController.insertBatch(batch, bundleId: _bundleId);
    }

    await SensorDbController.bundleAndClearSamples(tag: _currentTag);
  }
}
