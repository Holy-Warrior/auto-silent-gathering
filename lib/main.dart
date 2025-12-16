import 'package:flutter/material.dart';
import 'my_alarm_manager.dart';
import 'my_foreground_tasks.dart';
import 'my_alarm_manager_timings.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

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
      title: 'Sensor Foreground',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Sensor Foreground Notification'),
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
  List<List<int>>? timings;
  
  @override
  void initState() {
    super.initState();
    _loadTimings();
  }

  Future<void> _loadTimings() async {
    final loadedTimings = await MyAlarmManagerData.dailyTimings();
    setState(() {
      timings = loadedTimings;
    });
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      title: Text(widget.title),
    ),
    body: Center(
      child: timings == null
          ? const CircularProgressIndicator()
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await askForegroundTaskPermissions();
                    await scheduleDailyForegroundRuns();
                  },
                  child: const Text('Schedule Foreground service'),
                ),
                const Text('Alarm Manager Timings:'),
                for (final t in timings!)
                  Text(
                    '${t[0].toString().padLeft(2, '0')}:${t[1].toString().padLeft(2, '0')}',
                  ),
              ],
            ),
      ),
    );
  }
}
