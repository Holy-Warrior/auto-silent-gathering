<<<<<<< HEAD
// lib\screens\widgets\nimaz_timngs_form.dart
import 'package:flutter/material.dart';

=======
import 'package:flutter/material.dart';


>>>>>>> 05df9a8784000fe5cd4c6effe305385eb36d8d54
class NimazTimingsForm extends StatelessWidget {
  final List<String> labels;
  final List<TimeOfDay> times;
  final void Function(int index, TimeOfDay newTime) onTimePicked;

  const NimazTimingsForm({
    super.key,
    required this.labels,
    required this.times,
    required this.onTimePicked,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(labels.length, (i) {
        return ListTile(
          title: Text(labels[i]),
          trailing: TextButton(
            child: Text(_format12h(context, times[i])),
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: times[i],
              );

              if (picked != null) {
                onTimePicked(i, picked);
              }
            },
          ),
        );
      }),
    );
  }

  String _format12h(BuildContext context, TimeOfDay time) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatTimeOfDay(time, alwaysUse24HourFormat: false);
  }
}
