import 'package:asg/screens/sensor_manager/widgets/mode_toggle.dart';
import 'package:flutter/material.dart';
import 'package:asg/data/hive.dart';
import 'package:asg/services/alarm_manager/alarm_service.dart';
import 'package:asg/services/sensor_foreground_task/foreground_service.dart';
import 'package:asg/data/constants/config.dart';

Future<bool> handleModeSwitch({
  required BuildContext context,
  required Mode newMode,
}) async {
  final isSchedule = newMode == Mode.schedule;

  final confirmed = await showConfirmationDialog(
    context: context,
    title: isSchedule
        ? 'Switch to Schedule mode?'
        : 'Switch to Manual mode?',
    message: isSchedule
        ? 'Switching to schedule mode will stop the currently running sensor service. Continue?'
        : 'Switching to Manual mode will stop all scheduled sensor gathering sessions. Continue?',
    confirmText: 'Switch',
  );

  if (!confirmed) return false;

  final schedules = await StateBox.instance.getSchedules();

  await closeForegroundService();

  if (isSchedule) {
    await AlarmManagerService.activateSchedules(schedules);
  } else {
    await AlarmManagerService.cancelSchedules(schedules);
  }

  await StateBox.instance.setSensorMode(newMode);

  return true;
}

Future<Map<String, Map<String, dynamic>>> onLoadSchedules() async {
  return StateBox.instance.getSchedules();
}

Future<void> onSchedulesUpdated(Map<String, Map<String, dynamic>> newSchedules) async {
  final mode = await StateBox.instance.getSensorMode();

  if (mode == Mode.schedule){
    final oldSchedules = await StateBox.instance.getSchedules();
    await AlarmManagerService.cancelSchedules(oldSchedules);
    await AlarmManagerService.activateSchedules(newSchedules);
  }

  await StateBox.instance.overwriteSchedules(newSchedules);
  debugPrint(ColorCode.green('Updated schedules: $newSchedules', true));
}


Future<bool> showConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
}) async {
  final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(cancelText),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmText),
            ),
          ],
        ),
      ) ??
      false;

  return result;
}
