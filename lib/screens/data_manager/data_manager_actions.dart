import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:asg/data/db/controllers/sensor_db_controller.dart';
import 'package:asg/data/constants/config.dart';

class ExportShareZipButton extends StatefulWidget {
  final bool isEnabled;
  final int id;
  final Function(String, int) updateStatus;
  const ExportShareZipButton({super.key, required this.isEnabled, required this.id, required this.updateStatus});

  @override
  State<ExportShareZipButton> createState() => _ExportShareZipButtonState();
}

class _ExportShareZipButtonState extends State<ExportShareZipButton> {
  bool isExporting = false;

  Future<void> _onExportPressed() async {
    debugPrint(ColorCode.green('[_onExportPressed] Exporting archive #${widget.id}', true));
    if (!mounted) return;

    setState(() {
      debugPrint(ColorCode.yellow('[_onExportPressed] Preparing export...', true));
      widget.updateStatus('Preparing export...', widget.id);
      isExporting = true;
    });

    try {
      final zipFile = await SensorDbController.getZipFile(widget.id);

      if (!mounted) return;

      if (zipFile == null || !await zipFile.exists()) {
        debugPrint(ColorCode.yellow('[_onExportPressed] Nothing to export', true));
        widget.updateStatus('Nothing to export', widget.id);
        return;
      }

      debugPrint(ColorCode.magenta('[_onExportPressed::shareXFiles] Exporting archive #${widget.id}]',true));
      await Share.shareXFiles([XFile(zipFile.path)]);

      if (!mounted) return;

      debugPrint(ColorCode.yellow('[_onExportPressed] Export complete', true));
      widget.updateStatus('Export complete', widget.id);
    } catch (e) {
      if (!mounted) return;
      debugPrint(ColorCode.red('[_onExportPressed] Export failed: $e', true));
      widget.updateStatus('Export failed', widget.id);
    }
    if (!mounted) return;
    setState(() => isExporting = false);
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: widget.isEnabled && !isExporting ? _onExportPressed : null,
      icon: const Icon(Icons.archive),
      label: isExporting ? const Text('Exporting...') : const Text('Export'),
    );
  }
}
