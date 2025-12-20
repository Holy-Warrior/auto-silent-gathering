import 'package:motion_test/data/prefs.dart';

Future<({String currentTag, DateTime now})> identifyCurrentTagWithTime() async {
  final List<String> tags = ['Fajar', 'Zuhar', 'Asar', 'Magrib', 'Isha'];
  final List<List<int>> timings = await Prefs.Alarms.getTimings();

  final DateTime now = DateTime.now();
  final int nowMinutes = now.hour * 60 + now.minute;
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
    now: now,
  );
}


int minutesLeft(int finishLineMinutes, DateTime currentTime) {
  final DateTime finishLineTime = currentTime.add(Duration(minutes: finishLineMinutes));

  final Duration remaining = finishLineTime.difference(DateTime.now());

  if (remaining.isNegative) return 0;

  return remaining.inMinutes;
}


