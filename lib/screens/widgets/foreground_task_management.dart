import 'package:asg/screens/widgets/elapsed_time_text.dart';
import 'package:asg/services/sensor_foreground_task/foreground_service.dart';
import 'package:asg/services/foreground_task_actions.dart';
import 'package:asg/data/hive.dart';
import 'package:flutter/material.dart';

class ForegroundTaskManagement extends StatefulWidget {
  const ForegroundTaskManagement({super.key});

  @override
  State<ForegroundTaskManagement> createState() =>
      _StateForegroundTaskManagement();
}

class _StateForegroundTaskManagement extends State<ForegroundTaskManagement> {
  DateTime? startTime;
  bool isRunning = false;

  @override
  void initState() {
    super.initState();
    askForegroundTaskPermissions();
    _restoreState();
  }

  Future<void> _restoreState() async {
    final state = await StateBox.instance.getState();

    if (state.startTimeMillis != null) {
      startTime = DateTime.fromMillisecondsSinceEpoch(state.startTimeMillis!);
    }
    isRunning = state.isRunning == null ? false : state.isRunning!;

    setState(() {});
  }

  Future<void> initForegroundServiceCustom() async {
    final now = DateTime.now();

    await initForegroundService();
    isRunning = true;

    await StateBox.instance.updateState(
      startTimeMillis: now.millisecondsSinceEpoch,
    );

    setState(() {
      startTime = now;
    });
  }

  Future<void> closeForegroundServiceCustom() async {
    await closeForegroundService();
    isRunning=false;

    await StateBox.instance.updateState(startTimeMillis: null);

    setState(() {
      startTime = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isRunning ? Icons.play_circle : Icons.stop_circle,
              color: isRunning ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(
              isRunning ? 'Service Running' : 'Service Stopped',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),

        const SizedBox(height: 8),

        startTime == null
            ? const Text('Elapsed: --:--:--')
            : ElapsedTimeText(startTime: startTime!),

        const SizedBox(height: 12),

        Row(
          children: [
            ElevatedButton(
              onPressed: isRunning ? null : initForegroundServiceCustom,
              child: const Text('Start'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: isRunning ? closeForegroundServiceCustom : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Stop'),
            ),
          ],
        ),
      ],
    );
  }
}
