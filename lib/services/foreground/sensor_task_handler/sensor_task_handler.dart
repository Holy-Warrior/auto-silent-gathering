<<<<<<< HEAD
// lib\services\foreground\sensor_task_handler\sensor_task_handler.dart
import 'dart:async';
import 'package:motion_test/data/models/sensor_sample.dart';
import 'package:motion_test/data/db/sensor_db_controller.dart';
=======
import 'dart:async';
import 'package:motion_test/data/models/sensor_sample.dart';
import 'package:motion_test/data/db/sensor_database.dart';
>>>>>>> 05df9a8784000fe5cd4c6effe305385eb36d8d54
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
  late DateTime _currentTime;
  Map<String, int> exceedingTimes = {"notify_loop":40};

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    scheduleDailyForegroundRuns();
    final result = await identifyCurrentTagWithTime();
    _currentTag = result.currentTag;
    _currentTime = result.now;
<<<<<<< HEAD
    _bundleId = await SensorDbController.getNextBundleId();
=======
    _bundleId = await SensorDatabase.getNextBundleId();
>>>>>>> 05df9a8784000fe5cd4c6effe305385eb36d8d54
    _bundleIdAquired = true;
  
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
<<<<<<< HEAD
    if (batch.isNotEmpty) await SensorDbController.insertBatch(batch, bundleId: _bundleId);
=======
    if (batch.isNotEmpty) await SensorDatabase.insertBatch(batch, bundleId: _bundleId);
>>>>>>> 05df9a8784000fe5cd4c6effe305385eb36d8d54

    if (minutesLeft(exceedingTimes['notify_loop']!, _currentTime) <=0 ) {
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

      await FlutterForegroundTask.updateService(notificationText: 'Recording [$_labelCurrent] Sensor Data');
<<<<<<< HEAD
      await SensorDbController.insertTimeLabel
=======
      await SensorDatabase.insertTimeLabel
>>>>>>> 05df9a8784000fe5cd4c6effe305385eb36d8d54
      (bundleId: _bundleId, timestamp: timestamp, label: _labelCurrent,);

      if (_labelCurrent== _labelNimaz && minutesLeft(exceedingTimes['notify_loop']!, _currentTime) <= 20){
        exceedingTimes['notify_loop']= 20;
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
<<<<<<< HEAD
      await SensorDbController.insertBatch(batch, bundleId: _bundleId);
    }

    await SensorDbController.bundleAndClearSamples(tag: _currentTag);
=======
      await SensorDatabase.insertBatch(batch, bundleId: _bundleId);
    }

    await SensorDatabase.bundleAndClearSamples(tag: _currentTag);
>>>>>>> 05df9a8784000fe5cd4c6effe305385eb36d8d54
  }

}

