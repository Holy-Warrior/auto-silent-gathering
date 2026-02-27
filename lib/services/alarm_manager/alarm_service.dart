import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:asg/data/hive.dart';
import 'package:asg/services/sensor_foreground_task/foreground_service.dart';
import 'package:flutter/material.dart';
import 'package:asg/data/constants/config.dart';

@pragma('vm:entry-point')
void _alarmCallback() async {
  await Config.initilizeAllMainEntry();
  final state = await StateBox.instance.getState();
  if (state.isRunning == true) return;
  await initForegroundService();
}

class AlarmManagerService {
  /// Cancel alarms for given schedules
  /// If schedules is empty, nothing happens
  static Future<void> cancelSchedules(Map<String, Map<String, dynamic>> schedules) async {
    for (final key in schedules.keys) {
      await AndroidAlarmManager.cancel(_alarmIdFor(key));
      debugPrint('Cancelled alarm: $key');
    }
  }

  /// Activate alarms based on the schedule data
  /// Only schedules with 'enabled: true' will be scheduled
  static Future<void> activateSchedules(Map<String, Map<String, dynamic>> schedules) async {
    final now = DateTime.now();

    for (final entry in schedules.entries) {
      final key = entry.key;
      final data = entry.value;

      if (data['enabled'] != true) continue; // skip if false, null, or missing

      final timeStr = data['time'] as String?;
      if (timeStr == null) continue;

      final parts = timeStr.split(':');
      if (parts.length != 2) continue;

      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;

      // Original Nimaz time
      final originalTime = TimeOfDay(hour: hour, minute: minute);

      // Convert to execution time using Config
      final executionTime = Config.toExecutionTime(originalTime);

      // Build scheduled DateTime using execution time
      var scheduled = DateTime(now.year, now.month, now.day, executionTime.hour, executionTime.minute);

      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await AndroidAlarmManager.oneShotAt(
        scheduled,
        _alarmIdFor(key),
        _alarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );

      debugPrint('Scheduled alarm: $key at $scheduled');
    }
  }

  /// Generate a unique alarm ID based on the schedule key
  static int _alarmIdFor(String key) => key.hashCode & 0x7fffffff;
}
