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
      initialChildSize: 0.4,
      minChildSize: 0.25,
      maxChildSize: 0.9,
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
              final tables = data['tables'] as Map<String, dynamic>;
              final schema = data['sensor_bundles_schema'] as List;

              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Database Statistics',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Table Row Counts',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  ...tables.entries.map(
                    (e) => ListTile(
                      dense: true,
                      title: Text(e.key),
                      trailing: Text(e.value.toString()),
                    ),
                  ),

                  const Divider(height: 32),

                  const Text(
                    'sensor_bundles Schema',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  ...schema.map(
                    (c) => ListTile(
                      dense: true,
                      title: Text(c['name']),
                      subtitle: Text(c['type']),
                      trailing: Text(
                        c['nullable'] ? 'NULL' : 'NOT NULL',
                        style: TextStyle(
                          color: c['nullable'] ? Colors.grey : Colors.green,
                        ),
                      ),
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
