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
              // final summary =
              //     data['session_summary'] as Map<String, dynamic>? ?? {};
              // final recentArchives =
              //     data['recent_archives'] as List<dynamic>? ?? const [];
              // final sessionSource =
              //     (summary['source'] as String? ?? 'none').toUpperCase();

              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Database Statistics',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 16),

                  // const Text(
                  //   'Session Status',
                  //   style: TextStyle(fontWeight: FontWeight.w600),
                  // ),
                  // ListTile(
                  //   dense: true,
                  //   title: const Text('Stored data source'),
                  //   trailing: Text(sessionSource),
                  // ),
                  // ListTile(
                  //   dense: true,
                  //   title: const Text('Current session samples'),
                  //   trailing: Text(
                  //     '${summary['current_samples'] ?? 0}',
                  //   ),
                  // ),
                  // ListTile(
                  //   dense: true,
                  //   title: const Text('Previous session bundles'),
                  //   trailing: Text(
                  //     '${summary['pending_previous_session_bundles'] ?? 0}',
                  //   ),
                  // ),

                  // const Divider(height: 32),

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

                  // const Divider(height: 32),

                  // const Text(
                  //   'Recent Session Archives',
                  //   style: TextStyle(fontWeight: FontWeight.w600),
                  // ),
                  // if (recentArchives.isEmpty)
                  //   const ListTile(
                  //     dense: true,
                  //     title: Text('No archived sessions recorded'),
                  //   )
                  // else
                  //   ...recentArchives.map((entry) {
                  //     final archive = entry as Map<String, dynamic>;
                  //     final sampleCount = archive['sample_count'] ?? 0;
                  //     final durationMs = archive['duration_ms'] ?? 0;
                  //     final jsonName = archive['json_name'] ?? '-';
                  //     final syncStatus = archive['sync_status'] ?? 'pending';
                  //     final localAvailable =
                  //         (archive['local_available'] ?? 0) == 1;
                  //     final createdAt = archive['created_at'] as int?;
                  //     final createdAtText = createdAt == null
                  //         ? '-'
                  //         : DateTime.fromMillisecondsSinceEpoch(createdAt)
                  //               .toLocal()
                  //               .toString();

                  //     return ListTile(
                  //       dense: true,
                  //       title: Text(archive['title']?.toString() ?? 'Session'),
                  //       subtitle: Text(
                  //         'samples: $sampleCount | duration: ${_formatDuration(durationMs)}\njson: $jsonName\nsync: $syncStatus | local: ${localAvailable ? 'yes' : 'no'}\ncreated: $createdAtText',
                  //       ),
                  //       isThreeLine: true,
                  //     );
                  //   }),

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

  // String _formatDuration(Object? value) {
  //   final ms = value is num ? value.toInt() : 0;
  //   final totalSeconds = ms ~/ 1000;
  //   final hours = totalSeconds ~/ 3600;
  //   final minutes = (totalSeconds % 3600) ~/ 60;
  //   final seconds = totalSeconds % 60;
  //   return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  // }
}
