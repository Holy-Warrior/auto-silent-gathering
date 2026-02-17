| #   | execute                           | data                                                        |
| --- | --------------------------------- | ----------------------------------------------------------- |
| 1   | sensor_manager: onScheduleUpdated | Map<String, Map<String, dynamic [timeString, enabledBool]>> |





{hob: {time: 20:33, enabled: true}, dhr: {time: 17:38, enabled: true}}



this is how my data comes
```
| #   | execute                           | data                                                        |
| --- | --------------------------------- | ----------------------------------------------------------- |
| 1   | sensor_manager: onScheduleUpdated | Map<String, Map<String, dynamic [timeString, enabledBool]>> |





sample data: {hob: {time: 20:33, enabled: true}, dhr: {time: 17:38, enabled: true}}
```
the execution function
```

Future<void> onSchedulesUpdated(Map<String, Map<String, dynamic>> data) async {
  StateBox.instance.overwriteSchedules(data);
  debugPrint(ColorCode.green('Updated schedules: $data', true));
}
```
and this is the file that i want to use
```
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'schedule_alarm.dart';

class ScheduleAlarmService {
  static Future<void> syncSchedules(
    Map<String, Map<String, dynamic>> schedules,
  ) async {
    // Cancel all existing alarms first
    for (final key in schedules.keys) {
      await AndroidAlarmManager.cancel(
        alarmIdFor(key),
      );
    }

    for (final entry in schedules.entries) {
      final title = entry.key;
      final data = entry.value;

      if (data['enabled'] != true) continue;

      final time = data['time'] as String;
      final parts = time.split(':');

      final now = DateTime.now();
      var scheduled = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );

      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await AndroidAlarmManager.oneShotAt(
        scheduled,
        alarmIdFor(title),
        scheduleAlarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );
    }
  }

  static int alarmIdFor(String title) =>
      title.hashCode & 0x7fffffff;
}
Future<void> onSchedulesUpdated(
  Map<String, Map<String, dynamic>> data,
) async {
  await StateBox.instance.overwriteSchedules(data);
  await ScheduleAlarmService.syncSchedules(data);
}
Future<void> onModeChanged(Mode mode) async {
  if (_mode == mode) return;

  setState(() => _mode = mode);
  await StateBox.instance.setSensorMode(mode);

  if (mode == Mode.manual) {
    await AndroidAlarmManager.cancelAll();
  } else {
    final schedules =
        await StateBox.instance.getSchedules();
    await ScheduleAlarmService.syncSchedules(schedules);
  }
}

```
and maybe this too, i don't know but these are two code files i made some time ago
```
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'schedule_alarm.dart';

class ScheduleAlarmService {
  static Future<void> syncSchedules(
    Map<String, Map<String, dynamic>> schedules,
  ) async {
    // Cancel all existing alarms first
    for (final key in schedules.keys) {
      await AndroidAlarmManager.cancel(
        alarmIdFor(key),
      );
    }

    for (final entry in schedules.entries) {
      final title = entry.key;
      final data = entry.value;

      if (data['enabled'] != true) continue;

      final time = data['time'] as String;
      final parts = time.split(':');

      final now = DateTime.now();
      var scheduled = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );

      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await AndroidAlarmManager.oneShotAt(
        scheduled,
        alarmIdFor(title),
        scheduleAlarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );
    }
  }

  static int alarmIdFor(String title) =>
      title.hashCode & 0x7fffffff;
}
Future<void> onSchedulesUpdated(
  Map<String, Map<String, dynamic>> data,
) async {
  await StateBox.instance.overwriteSchedules(data);
  await ScheduleAlarmService.syncSchedules(data);
}
Future<void> onModeChanged(Mode mode) async {
  if (_mode == mode) return;

  setState(() => _mode = mode);
  await StateBox.instance.setSensorMode(mode);

  if (mode == Mode.manual) {
    await AndroidAlarmManager.cancelAll();
  } else {
    final schedules =
        await StateBox.instance.getSchedules();
    await ScheduleAlarmService.syncSchedules(schedules);
  }
}

```
the data that is passed to the files are in two forms, here is the edited execution function
```
Future<void> onSchedulesUpdated(Map<String, Map<String, dynamic>> data) async {
  Map<String, Map<String, dynamic>> schedules_to_remove = StateBox.instance.getSchedules();
  StateBox.instance.overwriteSchedules(data);
  debugPrint(ColorCode.green('Updated schedules: $data', true));
}
```
`schedules_to_remove` is the same format data as the one in `data`, beware that either of them may be an empty Map but if they are not empty then they will have at least one of these whole data parts -> `hob: {time: 20:33, enabled: true}`

so what is your analysis, can i use the code files as is or do you see problems?