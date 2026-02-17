import 'package:flutter/material.dart';
import 'package:asg/screens/widgets/export_share_as_json.dart';
import 'package:asg/screens/widgets/database_stats_button.dart';

class DataManger extends StatelessWidget {

  const DataManger({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
            _SectionCard(title: 'Data Export', child: ExportShareZipButton()),
      
            const SizedBox(height: 16),
      
            _SectionCard(title: 'Database', child: DatabaseStatsButton()),
      ]
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
