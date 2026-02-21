import 'package:asg/data/constants/config.dart';
import 'package:asg/screens/data_manager/data_manager_actions.dart';
import 'package:asg/screens/widgets/database_stats_button.dart';
import 'package:flutter/material.dart';
import 'package:asg/data/db/controllers/sensor_db_controller.dart';

class DataManager extends StatefulWidget {
  const DataManager({super.key});
  @override
  State<DataManager> createState() => _StateDataManager();
}

class _StateDataManager extends State<DataManager> {
  Map<int, String> status = {};
  late Future<List<({int id, String startedAt, String path, bool localAvailable, int sampleCount, int durationMs})>>
  _archivesFuture;
  @override
  void initState() {
    super.initState();
    _archivesFuture = SensorDbController.getZipMetaData();
  }

  void _refreshArchives() {
    setState(() {
      _archivesFuture = SensorDbController.getZipMetaData();
    });
  }

  void updateStatus(String newStatus, int id) {
    setState(() {
      status[id] = "\n$newStatus";
    });
  }

  void ensureStatusKey(int id) {
    if (!status.containsKey(id)) {
      status[id] = "";
    }
  }

  void delteArchive(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      debugPrint('Delete $id');
      await SensorDbController.delteArchive(id);
      setState(() {
        status.remove(id);
      });
      _refreshArchives();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Flexible(child: DatabaseStatsButton()),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _refreshArchives),
              ),
            ),
          ],
        ),
        SizedBox(
          width: double.infinity,
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child:
                  FutureBuilder<
                    List<
                      ({int id, String startedAt, String path, bool localAvailable, int sampleCount, int durationMs})
                    >
                  >(
                    future: _archivesFuture,

                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        debugPrint(ColorCode.red('Failed to load archives:\n${snapshot.error}', true));
                        return Padding(
                          padding: const EdgeInsets.all(4),
                          child: Text(
                            'Failed to load archives:\n${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      final items = snapshot.data;

                      if (items == null || items.isEmpty) {
                        debugPrint(ColorCode.yellow('No archives found.', true));
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: Text('No archives found.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                          ),
                        );
                      }

                      debugPrint(ColorCode.green('Archives found$items', true));
                      return SizedBox(
                        height: 300, // limit height if inside Column
                        child: ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            ensureStatusKey(item.id);
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Archive #${item.id}',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6),

                                    Text(
                                      'Samples: ${item.sampleCount}  | Duration: ${item.durationMs} ms\n'
                                      'Created: ${item.startedAt}${status[item.id]}',
                                    ),

                                    const SizedBox(height: 12),

                                    // Buttons Row
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ExportShareZipButton(
                                            isEnabled: item.localAvailable,
                                            id: item.id,
                                            updateStatus: updateStatus,
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Placeholder for your delete button
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () => delteArchive(item.id),
                                            icon: const Icon(Icons.delete),
                                            label: const Text('Delete'),
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
            ),
          ),
        ),
      ],
    );
  }
}
