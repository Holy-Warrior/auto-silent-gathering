// lib\services\alarm_manager.dart
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'foreground/foreground_service.dart';
import '../data/prefs.dart';

@pragma('vm:entry-point')
void alarmCallback() async {
  await initForegroundService();
}

Future<void> scheduleDailyForegroundRuns() async {
  /* Provide Permissions before running */
  final now = DateTime.now();
  final dailyTimings = await Prefs.Alarms.getTimings();

  for (int i = 0; i<5; i++) {
    final clockHM = dailyTimings[i];
    DateTime scheduled = DateTime(now.year, now.month, now.day, clockHM[0], clockHM[1]);

    // if time already passed -> shedule tomorrow
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await AndroidAlarmManager.oneShotAt
      (scheduled, Prefs.Alarms.alarmBaseId +i, alarmCallback,
      exact: true, wakeup: true, rescheduleOnReboot: true);
  }
}