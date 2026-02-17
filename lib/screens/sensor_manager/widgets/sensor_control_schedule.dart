import 'package:flutter/material.dart';
import 'package:asg/data/constants/config.dart';

class ScheduleItem {
  String name;
  bool enabled;
  TimeOfDay time;

  ScheduleItem({required this.name, this.enabled = true, required this.time});
}

class ScheduleRow extends StatelessWidget {
  final ScheduleItem item;
  final bool showDelete;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickTime;
  final TimeOfDay displayTime;

  const ScheduleRow({
    super.key,
    required this.item,
    required this.showDelete,
    required this.onDelete,
    required this.onToggle,
    required this.onPickTime,
    required this.displayTime,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(item.name, style: const TextStyle(fontSize: 16))),

        Switch(value: item.enabled, onChanged: onToggle),

        TextButton(
          onPressed: onPickTime,
          child: Text(
            MaterialLocalizations.of(
              context,
            ).formatTimeOfDay(displayTime, alwaysUse24HourFormat: false),
          ),
        ),

        if (showDelete)
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: onDelete,
          ),
      ],
    );
  }
}

class SensorControlSchedule extends StatefulWidget {
  const SensorControlSchedule({
    super.key,
    required this.onLoadSchedules,
    required this.onSchedulesUpdated,
  });

  final Future<Map<String, Map<String, dynamic>>> Function() onLoadSchedules;

  final Future<void> Function(Map<String, Map<String, dynamic>> schedules)
  onSchedulesUpdated;

  @override
  State<SensorControlSchedule> createState() => _SensorControlScheduleState();
}

class _SensorControlScheduleState extends State<SensorControlSchedule> {
  bool editMode = false;
  List<ScheduleItem> items = [];
  bool showExecutionTime = false; // toggle state

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    final data = await widget.onLoadSchedules();

    setState(() {
      items = data.entries.map((e) {
        final timeParts = (e.value['time'] as String).split(':');

        return ScheduleItem(
          name: e.key,
          enabled: e.value['enabled'] as bool? ?? true,
          time: TimeOfDay(
            hour: int.parse(timeParts[0]),
            minute: int.parse(timeParts[1]),
          ),
        );
      }).toList();
    });
  }

  Future<void> addItem() async {
    final titleController = TextEditingController();
    TimeOfDay? selectedTime;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final canAdd =
                titleController.text.trim().isNotEmpty && selectedTime != null;

            return AlertDialog(
              title: const Text('Add schedule'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedTime == null
                              ? 'Select time'
                              : MaterialLocalizations.of(
                                  context,
                                ).formatTimeOfDay(selectedTime!),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime ?? TimeOfDay.now(),
                          );
                          if (time != null) {
                            setState(() => selectedTime = time);
                          }
                        },
                        child: const Text('Pick'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: canAdd ? () => Navigator.pop(context, true) : null,
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      setState(() {
        items.add(
          ScheduleItem(name: titleController.text.trim(), time: selectedTime!),
        );
      });
      _notifyUpdate();
    }
  }

  Future<void> pickTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: items[index].time, // always original
    );

    if (picked != null) {
      setState(() => items[index].time = picked);
      _notifyUpdate();
    }
  }

  Future<void> _notifyUpdate() async {
    final map = {
      for (final item in items)
        item.name: {
          'time':
              '${item.time.hour.toString().padLeft(2, '0')}:'
              '${item.time.minute.toString().padLeft(2, '0')}',
          'enabled': item.enabled,
        },
    };

    await widget.onSchedulesUpdated(map);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header controls
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Text(
                "Edit mode",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              Switch(
                value: editMode,
                onChanged: (v) => setState(() => editMode = v),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Text(
              showExecutionTime?"Execution Time (view only)":"Original Nimaz Time",
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 8),
            Switch(
              value: showExecutionTime,
              onChanged: (v) {
                setState(() => showExecutionTime = v);
              },
            ),
          ],
        ),

        const Divider(),

        // Repeating list
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ScheduleRow(
                item: items[index],
                displayTime: showExecutionTime
                    ? Config.convertTime(items[index].time, Config.executionOffsetMinutes)
                    : items[index].time,
                showDelete: editMode,
                onToggle: (v) {
                  setState(() => items[index].enabled = v);
                  _notifyUpdate();
                },
                onPickTime: () => pickTime(index),
                onDelete: () {
                  setState(() => items.removeAt(index));
                  _notifyUpdate();
                },
              ),
            );
          },
        ),

        // Add more
        Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            onPressed: addItem,
            icon: const Icon(Icons.add),
            label: const Text("Add more"),
          ),
        ),
      ],
    );
  }
}

