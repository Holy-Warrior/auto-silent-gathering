import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:asg/data/db/controllers/sensor_db_controller.dart';

class ExportShareZipButton extends StatefulWidget {
  const ExportShareZipButton({super.key});

  @override
  State<ExportShareZipButton> createState() => _ExportShareZipButtonState();
}

class _ExportShareZipButtonState extends State<ExportShareZipButton> {
  String status = '';
  bool isExporting = false;

  Future<void> _onExportPressed() async {
    setState(() {
      status = 'Preparing export...';
      isExporting = true;
    });

    try {
      final zipFile = await SensorDbController.bundleAndExportZip();

      if (zipFile == null || !await zipFile.exists()) {
        setState(() => status = 'Nothing to export');
        return;
      }

      await Share.shareXFiles([XFile(zipFile.path)]);
      setState(() => status = 'Export complete');
    } catch (_) {
      setState(() => status = 'Export failed');
    } finally {
      setState(() => isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: isExporting ? null : _onExportPressed,
          icon: const Icon(Icons.archive),
          label: isExporting
              ? const Text('Exporting...')
              : const Text('Export & Share ZIP'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),

        if (status.isNotEmpty)
          Padding(padding: const EdgeInsets.all(8.0), child: Text(status)),
      ],
    );
  }
}
