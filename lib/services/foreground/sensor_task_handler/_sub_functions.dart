// lib\services\foreground\sensor_task_handler\_sub_functions.dart
import 'package:motion_test/data/prefs.dart';

Future<({String currentTag, DateTime startTime})> identifyCurrentTagWithTime() async {
  final List<String> tags = ['Fajar', 'Zuhar', 'Asar', 'Magrib', 'Isha'];
  final List<List<int>> timings = await Prefs.Alarms.getTimings();

  final DateTime startTime = DateTime.now();
  final int nowMinutes = startTime.hour * 60 + startTime.minute;
  final timingMinutes = timings.map((t) => t[0] * 60 + t[1]).toList();

  int selectedIndex = -1;
  for (int i = 0; i < timingMinutes.length; i++) {
    if (timingMinutes[i] <= nowMinutes) {
      selectedIndex = i;
    } else { break; }
  }

  if (selectedIndex == -1) { selectedIndex = timingMinutes.length - 1; }

  return (
    currentTag: tags[selectedIndex],
    startTime: startTime,
  );
}

Future<int> minutesUntilNextNimaz() async {
  final timings = await Prefs.Alarms.getTimings();
  final now = DateTime.now();
  final nowMinutes = now.hour * 60 + now.minute;

  for (final t in timings) {
    final m = t[0] * 60 + t[1];
    if (m > nowMinutes) return m - nowMinutes;
  }

  // wrap to tomorrow
  final first = timings.first;
  return (24 * 60 - nowMinutes) + (first[0] * 60 + first[1]);
}




int minutesLeft(int finishLineMinutes, DateTime startTime) {
  final DateTime finishLineTime = startTime.add(Duration(minutes: finishLineMinutes));

  final Duration remaining = finishLineTime.difference(DateTime.now());

  if (remaining.isNegative) return 0;

  return remaining.inMinutes;
}


