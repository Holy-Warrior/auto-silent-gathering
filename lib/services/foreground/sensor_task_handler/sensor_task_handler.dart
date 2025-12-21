// lib\services\foreground\sensor_task_handler\sensor_task_handler.dart
import 'dart:async';
import 'package:motion_test/data/models/sensor_sample.dart';
import 'package:motion_test/data/db/sensor_db_controller.dart';
import 'package:motion_test/services/alarm_manager.dart';
import 'sensor_buffer.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '_sub_functions.dart';

@pragma('vm:entry-point')
void startCallback(){
    FlutterForegroundTask.setTaskHandler(SensorTaskHandler());
}

class SensorTaskHandler extends TaskHandler {
  StreamSubscription<AccelerometerEvent>? _accSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<UserAccelerometerEvent>? _userAccSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  
  SensorBuffer<SensorSample> buffer = SensorBuffer<SensorSample>();
  final _labelRandom = 'Random', _labelNimaz = 'Nimaz';
  String _labelCurrent = 'Random';
  late final int _bundleId;
  bool _bundleIdAquired = false;
  String _currentTag = "not_set";
  late DateTime _serviceStartTime;
  int notifyLoop= 40;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    scheduleDailyForegroundRuns();
    final result = await identifyCurrentTagWithTime();
    _currentTag = result.currentTag;
    _serviceStartTime = result.startTime;
    _bundleId = await SensorDbController.getNextBundleId();
    _bundleIdAquired = true;

    await FlutterForegroundTask.updateService(notificationText: 'Recording [$_labelCurrent] Sensor Data for [$_currentTag]');
  
    // Subscribe to sensors
    _accSub = accelerometerEventStream(samplingPeriod: SensorInterval.fastestInterval)
            .listen((e) { buffer.add(SensorSample(timestamp: DateTime.now()
            .millisecondsSinceEpoch, type: 'ACC', x: e.x, y: e.y, z: e.z, ));});
    _gyroSub = gyroscopeEventStream(samplingPeriod: SensorInterval.fastestInterval)
            .listen((e) { buffer.add(SensorSample(timestamp: DateTime.now()
            .millisecondsSinceEpoch, type: 'GYR', x: e.x, y: e.y, z: e.z));});
    _userAccSub = userAccelerometerEventStream(samplingPeriod: SensorInterval.fastestInterval)
            .listen((e) { buffer.add(SensorSample(timestamp: DateTime.now()
            .millisecondsSinceEpoch, type: 'UACC', x: e.x, y: e.y, z: e.z));});
    _magSub = magnetometerEventStream(samplingPeriod: SensorInterval.fastestInterval)
            .listen((e) { buffer.add(SensorSample(timestamp: DateTime.now()
            .millisecondsSinceEpoch, type: 'MAG', x: e.x, y: e.y, z: e.z));});
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    final batch = await buffer.takeAll();
    if (batch.isNotEmpty) await SensorDbController.insertBatch(batch, bundleId: _bundleId);

    if (minutesLeft(notifyLoop, _serviceStartTime) <=0 ) {
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationButtonPressed(String id) async {
    super.onNotificationButtonPressed(id);

    if (id == 'switch_label'){
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      if(!_bundleIdAquired) return;
      if (_labelCurrent == _labelRandom) {_labelCurrent = _labelNimaz;}
      else {_labelCurrent = _labelRandom;}

      await FlutterForegroundTask.updateService(notificationText: 'Recording [$_labelCurrent] Sensor Data for [$_currentTag]');
      await SensorDbController.insertTimeLabel
      (bundleId: _bundleId, timestamp: timestamp, label: _labelCurrent,);

      final remainingMinutesLeft = minutesLeft(notifyLoop, _serviceStartTime);
      if (_labelCurrent== _labelNimaz){
        if (remainingMinutesLeft <= 20) notifyLoop= 20;

        final minutesToNextNimaz = await minutesUntilNextNimaz();
        final remaining =
            minutesLeft(notifyLoop, _serviceStartTime); // remaining time of current service
        final requiredMinutes = minutesToNextNimaz + 5; // we must survive until next Nimaz (+ 5 min buffer)
        if (remaining < requiredMinutes) {
          notifyLoop += (requiredMinutes - remaining);
        }

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

