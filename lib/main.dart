// lib/main.dart
import 'package:flutter/material.dart';
import 'my_alarm_manager.dart';
import 'my_foreground_tasks.dart';
import 'my_alarm_manager_timings.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'widgets/widget_github_release_checker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AndroidAlarmManager.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nimaz Data Collection',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: const MyHomePage(title: 'Nimaz Data Collection'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<String> _labels = ['Fajar', 'Zuhar', 'Asar', 'Magrib', 'Isha'];
  late Future<List<TimeOfDay>> _timingsFuture;
  List<TimeOfDay> _displayTimes = [];

  @override
  void initState() {
    super.initState();
    _timingsFuture = _loadTimings();
    askForegroundTaskPermissions().then((onValue){scheduleDailyForegroundRuns();});
  }

  Future<List<TimeOfDay>> _loadTimings() async {
    final loaded = await MyAlarmManagerData.dailyTimings();
    return loaded.map(_toDisplayTime).toList();
  }

  TimeOfDay _toDisplayTime(List<int> stored) {
    final dt = DateTime(0, 1, 1, stored[0], stored[1]).add(const Duration(minutes: 15));
    return TimeOfDay(hour: dt.hour, minute: dt.minute);
  }

  List<int> _toStoredTime(TimeOfDay picked) {
    final dt = DateTime(0, 1, 1, picked.hour, picked.minute).subtract(const Duration(minutes: 15));
    return [dt.hour, dt.minute];
  }

  void saveNewTimeFromFormAndScheduleAlarams() async {
    final storedTimes = _displayTimes.map(_toStoredTime).toList();

    await MyAlarmManagerData.dailyTimingsModify(storedTimes);

    await askForegroundTaskPermissions();
    await scheduleDailyForegroundRuns();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),

      body: FutureBuilder<List<TimeOfDay>>(
        future: _timingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading timings: ${snapshot.error}'),
            );
          }

          // Data is ready
          _displayTimes = snapshot.data!;

          return Column(
            children: [
              WidgetGitReleaseChecker(
                user: 'Holy-Warrior',
                repo: 'auto-silent-gathering',
                currentRelease: 'v1.0.0',
                filterOutPreRelease: true,
              ),
              const Text(
                'Nimaz Timings',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              NimazTimingsForm(
                labels: _labels,
                times: _displayTimes,
                onTimePicked: (index, newTime) {
                  setState(() {
                    _displayTimes[index] = newTime;
                  });
                },
              ),

              ElevatedButton(
                onPressed: saveNewTimeFromFormAndScheduleAlarams,
                child: const Text('Save Jamah Timings'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class NimazTimingsForm extends StatelessWidget {
  final List<String> labels;
  final List<TimeOfDay> times;
  final void Function(int index, TimeOfDay newTime) onTimePicked;

  const NimazTimingsForm({
    super.key,
    required this.labels,
    required this.times,
    required this.onTimePicked,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(labels.length, (i) {
        return ListTile(
          title: Text(labels[i]),
          trailing: TextButton(
            child: Text(_format12h(context, times[i])),
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: times[i],
              );

              if (picked != null) {
                onTimePicked(i, picked);
              }
            },
          ),
        );
      }),
    );
  }

  String _format12h(BuildContext context, TimeOfDay time) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatTimeOfDay(time, alwaysUse24HourFormat: false);
  }
}
