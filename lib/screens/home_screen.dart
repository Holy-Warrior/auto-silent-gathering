import 'package:asg/screens/data_manager/data_manger.dart';
import 'package:asg/screens/widgets/tab_manager.dart';
import 'package:flutter/material.dart';
import 'package:asg/data/constants/config.dart';
import 'package:asg/screens/widgets/github_release_checker.dart';
import 'package:asg/screens/sensor_manager/sensor_manager.dart';

class HomeScreen extends StatelessWidget {
  final String title;
  const HomeScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            WidgetGitReleaseChecker(
              user: Config.gitUser,
              repo: Config.gitRepo,
              currentRelease: Config.gitCurentRelease,
              filterOutPreRelease: Config.gitFilterOutPrerelease,
              showLoading: false,
            ),
            TabManager(
              tabs: const [
                ManagedTab(title: 'Sensor Data Gathering', child: SensorManager()),
                ManagedTab(title: 'Data Management', child: DataManger())
              ],
            ),
          ],
        ),
      ),
    );
  }
}
