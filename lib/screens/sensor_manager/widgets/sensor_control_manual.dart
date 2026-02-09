import 'package:flutter/material.dart';
import 'package:asg/screens/widgets/foreground_task_management.dart';

class SensorControlManual extends StatelessWidget {
  const SensorControlManual({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(0.0),
      child: Column(
          children: const [
            // SizedBox(height: 16),
      
            _SectionCard(
              title: 'Foreground Service',
              child: ForegroundTaskManagement(),
            ),
      
            SizedBox(height: 16),
      
          ],
        ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
