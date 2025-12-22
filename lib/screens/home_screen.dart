// lib\screens\home_screen.dart
import 'package:flutter/material.dart';
import '../services/foreground/foreground_service.dart';
import '../services/alarm_manager.dart';
import 'widgets/github_release_checker.dart';
import 'widgets/nimaz_timngs_form.dart';
import '../data/prefs.dart';
import 'package:motion_test/data/config.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.title});
  final String title;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    final loaded = await Prefs.Alarms.getTimings();
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

    await Prefs.Alarms.updateTimings(storedTimes);

    await askForegroundTaskPermissions();
    await scheduleDailyForegroundRuns();

    // Show Snackbar confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jamah timings saved successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
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
                currentRelease: Config.currentGitReleaseVersion,
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
