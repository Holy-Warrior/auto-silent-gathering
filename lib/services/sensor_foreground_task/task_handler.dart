import 'package:asg/data/db/models/sensor_sample.dart';
import 'package:asg/data/hive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:asg/services/sensor_foreground_task/sensor_buffer.dart';
import 'package:asg/services/sensor_foreground_task/sensor_manager.dart';
import 'package:asg/data/constants/config.dart';
import 'package:asg/data/db/controllers/sensor_db_controller.dart';

@pragma('vm:entry-point')
void startSensorTaskCallback() {
  FlutterForegroundTask.setTaskHandler(SensorTaskHandler());
}

class SensorTaskHandler extends TaskHandler{
  final buffer = SensorBuffer();
  final sensorManager = SensorManager();
  final state = StateBox.instance;

  late final int bundleId;
  bool isNimaz = false;
  bool startupCompleted = false;
  bool startedByDev = true;
  bool isLoopEventDisabled = false; 
  bool stopInExecution = false;
  bool changeLabelInExecution = false;

  final String masgidEmoji = '🕌';

  String debugLogReference(String functionName){
    return "[ForegroundTaskHandler::$functionName]: ";
  }


  @override // START TASK
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    final drStart = debugLogReference('onStart');
    debugPrint(ColorCode.green('${drStart}Execution Started', true));
    if (starter == TaskStarter.developer) await archiveCompression(taskText: 'Cleaning previos session data'); 

    sensorManager.subscribeAll(
      samplingPeriod: Config.samplingPeriod,
      buffer: buffer
    );
    debugPrint(ColorCode.yellow('${drStart}Subscribed to Sensors', true));

    final millisecondsSinceEpoch = DateTime.now().millisecondsSinceEpoch;

    if (starter == TaskStarter.developer){
      bundleId = await SensorDbController.getNextBundleId();
      await state.updateState(bundleId: bundleId, isNimaz: isNimaz);
    } 
    else {
      startedByDev = false;
      final bstate = await state.getState();

      if (bstate.isNimaz != null){
        isNimaz = bstate.isNimaz!;
      } else {
        debugPrint('$drStart${ColorCode.raw_red}[Hive Storage Error]: TaskStarter is (system) but hive did not have isNimaz, this variable cannot be recovered ${ColorCode.reset}');
        await state.updateState(isNimaz: isNimaz);
      }

      if (bstate.bundleId != null)
        { bundleId = bstate.bundleId!;}
      else {
        debugPrint('$drStart${ColorCode.raw_red}[Hive Storage Error]: TaskStarter is (system) but hive did not have bundleId ${ColorCode.reset}');
        bundleId = await SensorDbController.getNextBundleId(recoverPreviouslyUsedId: true);
        await state.updateState(bundleId: bundleId);
      }
    }
    debugPrint(ColorCode.yellow('${drStart}Variables Initialized', true));

    await FlutterForegroundTask.updateService(
      notificationText:
          '${isNimaz? masgidEmoji:""}Recording [${isNimaz? "Nimaz":"Random"}] Sensor Data${startedByDev? "" : "\nTask restarted by system"}',
      notificationButtons: [
        NotificationButton(id: 'switch_label', text: 'Change Label'),
        NotificationButton(id: 'stop', text: 'End Session')
      ],
    );
    debugPrint(ColorCode.yellow('${drStart}Notification Service Updated', true));

    SensorDbController.insertTimeLabel(bundleId: bundleId, timestamp: millisecondsSinceEpoch, isNimaz: isNimaz).then((onValue){
      debugPrint(ColorCode.magenta('${drStart}Initial Timelabel Inserted in Async', true));
    });

    if (starter == TaskStarter.system) {
      SensorDbController.insertCrashRecoveryRecord(bundleId: bundleId, timestamp: millisecondsSinceEpoch);
    }

    startupCompleted = true;
    await StateBox.instance.updateState(isRunning: true, startTimeMillis: millisecondsSinceEpoch);
    debugPrint(ColorCode.red('${drStart}Execution Ended', true));
  }




  @override // TASK LOOP EVENT
  Future<void> onRepeatEvent(DateTime timestamp) async {
    if (isLoopEventDisabled){
    debugPrint(ColorCode.cyan('${debugLogReference('onRepeatEvent')}[$timestamp]loop event disabled, returning', true));
      return;}
    debugPrint(ColorCode.green('${debugLogReference('onRepeatEvent')}[$timestamp]started', true));
    final List<SensorSample> samples = await buffer.takeAll();
    await SensorDbController.insertBatch(samples, bundleId: bundleId);
    debugPrint(ColorCode.magenta('${debugLogReference('onRepeatEvent')}[$timestamp]Batch Insertion Complete', true));
  }




  @override // NOTIFICATION BUTTON EVENTS
  void onNotificationButtonPressed(String id) async {
    super.onNotificationButtonPressed(id);
    final millisecondsSinceEpoch = DateTime.now().millisecondsSinceEpoch;
    debugPrint(ColorCode.green('${debugLogReference('onNotificationButtonPressed')}[$millisecondsSinceEpoch][$id]started', true));

    if (!startupCompleted) {
        debugPrint(ColorCode.red('${debugLogReference('onNotificationButtonPressed')}startup incomplete:Execution Ended', true));
        return;
      }
    
    debugPrint(ColorCode.yellow('${debugLogReference('onNotificationButtonPressed')}id: $id', true));

    if (id == 'switch_label' && !changeLabelInExecution) 
      { await _switchLabelCallback(millisecondsSinceEpoch); }
    else if (id == 'stop' && !stopInExecution) 
      {await _stopCallback();}

    debugPrint(ColorCode.red('${debugLogReference('onNotificationButtonPressed')}Execution Ended', true));
  }




  // Notification button: switch_label
  Future<void> _switchLabelCallback(int millisecondsSinceEpoch)async{
    changeLabelInExecution=true;
    isNimaz = !isNimaz;
    await FlutterForegroundTask.updateService(
      notificationText:
          '${isNimaz? masgidEmoji:""}Recording [${isNimaz? "Nimaz":"Random"}] Sensor Data${startedByDev? "" : "\nTask restarted by system"}',
    );

    await SensorDbController.insertTimeLabel(bundleId: bundleId, timestamp: millisecondsSinceEpoch, isNimaz: isNimaz);
    await state.updateState(isNimaz:isNimaz);
    changeLabelInExecution=false;
  }


  // Notification button: stop
  Future<void> _stopCallback()async{
    stopInExecution=true;
    isLoopEventDisabled = true;
    await FlutterForegroundTask.stopService();
  }


  @override // END TASK
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    stopInExecution = true;
    isLoopEventDisabled = true;
    await sensorTaskEnder();
    await archiveCompression();
  }


  Future<void> sensorTaskEnder()async{
    await FlutterForegroundTask.updateService(
      notificationButtons: [],
      notificationText: 'Cleaning up',
    );
    await sensorManager.unsubscribeAll();
    await StateBox.instance.updateState(isRunning: false, startTimeMillis: null);
    final List<SensorSample> samples = await buffer.takeAll();
    await SensorDbController.insertBatch(samples, bundleId: bundleId);
  }


  Future<void>archiveCompression({String taskText = 'Compressing Sensors Data'})async{
    await FlutterForegroundTask.updateService(notificationText: taskText);
    await SensorDbController.bundleAndExportZip();
    await FlutterForegroundTask.updateService(notificationText: 'Done');
  }

}
