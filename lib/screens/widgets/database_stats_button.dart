import 'package:flutter/material.dart';
import 'package:asg/data/db/controllers/sensor_db_controller.dart';

class DatabaseStatsButton extends StatelessWidget {
  const DatabaseStatsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _openStatsDrawer(context),
      icon: const Icon(Icons.storage),
      label: const Text('Database Stats'),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
      ),
    );
  }

  void _openStatsDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _DatabaseStatsDrawer(),
    );
  }
}

class _DatabaseStatsDrawer extends StatefulWidget {
  const _DatabaseStatsDrawer();

  @override
  State<_DatabaseStatsDrawer> createState() => _DatabaseStatsDrawerState();
}

class _DatabaseStatsDrawerState extends State<_DatabaseStatsDrawer> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = SensorDbController.getDatabaseStats();
  }

@override
Widget build(BuildContext context) {
  return DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.5,
    minChildSize: 0.3,
    maxChildSize: 0.95,
    builder: (context, scrollController) {
      return Material(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Failed to load stats:\n${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            final data = snapshot.data!;
            final pipeline = data['pipeline'] as Map<String, dynamic>;
            final timeline = data['timeline'] as Map<String, dynamic>;
            final storage = data['storage'] as Map<String, dynamic>;

            String formatBytes(int bytes) {
              const kb = 1024;
              const mb = 1024 * 1024;
              if (bytes >= mb) {
                return '${(bytes / mb).toStringAsFixed(2)} MB';
              } else if (bytes >= kb) {
                return '${(bytes / kb).toStringAsFixed(2)} KB';
              }
              return '$bytes B';
            }

            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [

                const Text(
                  'Database Health',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 16),

                const Text(
                  'Pipeline Status',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),

                ...pipeline.entries.map(
                  (e) => ListTile(
                    dense: true,
                    title: Text(e.key),
                    trailing: Text(e.value.toString()),
                  ),
                ),

                const Divider(height: 32),

                const Text(
                  'Timeline',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),

                ListTile(
                  dense: true,
                  title: const Text('Oldest archive'),
                  trailing: Text(
                    timeline['oldest_archive_created_at']?.toString() ?? '—',
                  ),
                ),

                ListTile(
                  dense: true,
                  title: const Text('Newest archive'),
                  trailing: Text(
                    timeline['newest_archive_created_at']?.toString() ?? '—',
                  ),
                ),

                const Divider(height: 32),

                const Text(
                  'Storage Usage',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),

                ListTile(
                  dense: true,
                  title: const Text('Database file size'),
                  trailing: Text(
                    formatBytes(storage['database_bytes'] as int),
                  ),
                ),

                ListTile(
                  dense: true,
                  title: const Text('Archives total size'),
                  trailing: Text(
                    formatBytes(storage['archives_total_bytes'] as int),
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

}
