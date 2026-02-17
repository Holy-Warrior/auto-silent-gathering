import 'package:asg/screens/sensor_manager/widgets/mode_toggle.dart';
import 'package:asg/screens/sensor_manager/widgets/sensor_control_manual.dart';
import 'package:asg/screens/sensor_manager/widgets/sensor_control_schedule.dart';
import 'package:flutter/material.dart';
import 'package:asg/data/hive.dart';
import 'sensor_manager_actions.dart';

class SensorManager extends StatefulWidget {
  const SensorManager({super.key});

  @override
  State<SensorManager> createState() => _SensorManagerState();
}

class _SensorManagerState extends State<SensorManager> {
  Mode _mode = Mode.manual;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMode();
  }

  Future<void> _loadMode() async {
    final savedMode = await StateBox.instance.getSensorMode();

    setState(() {
      _mode = savedMode;
      _loading = false;
    });
  }

  Future<void> onModeChanged(Mode mode) async {
    if (_mode == mode) return;

    final switched = await handleModeSwitch(
      context: context,
      newMode: mode,
    );

    if (!switched) return;

    setState(() => _mode = mode);

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            mode == Mode.manual
                ? 'Manual mode selected'
                : 'Schedule mode selected',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        ModeToggle(activeMode: _mode, onChanged: onModeChanged),
        if (_mode == Mode.manual)
          const SensorControlManual()
        else
          const SensorControlSchedule(
            onLoadSchedules: onLoadSchedules,
            onSchedulesUpdated: onSchedulesUpdated,
          ),
      ],
    );
  }
}
