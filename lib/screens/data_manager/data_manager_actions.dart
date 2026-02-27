import 'package:asg/data/supabase/controller.dart';
import 'package:flutter/material.dart';
// import 'package:share_plus/share_plus.dart';
// import 'package:asg/data/db/controllers/sensor_db_controller.dart';
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

  // Future<void> _onUploadPressed() async {
  //   debugPrint(ColorCode.green('[_onUploadPressed] Exporting archive #${widget.id}', true));
  //   if (!mounted) return;
  // 
  //   setState(() {
  //     debugPrint(ColorCode.yellow('[_onUploadPressed] Preparing export...', true));
  //     widget.updateStatus('Preparing export...', widget.id);
  //     isExporting = true;
  //   });
  //
  //   try {
  //     final zipFile = await SensorDbController.getZipFile(widget.id);
  //
  //     if (!mounted) return;
  //
  //     if (zipFile == null || !await zipFile.exists()) {
  //       debugPrint(ColorCode.yellow('[_onUploadPressed] Nothing to export', true));
  //       widget.updateStatus('Nothing to export', widget.id);
  //       return;
  //     }
  //
  //     debugPrint(ColorCode.magenta('[_onUploadPressed::shareXFiles] Exporting archive #${widget.id}]',true));
  //     await Share.shareXFiles([XFile(zipFile.path)]);
  //
  //     if (!mounted) return;
  //
  //     debugPrint(ColorCode.yellow('[_onUploadPressed] Export complete', true));
  //     widget.updateStatus('Export complete', widget.id);
  //   } catch (e) {
  //     if (!mounted) return;
  //     debugPrint(ColorCode.red('[_onUploadPressed] Export failed: $e', true));
  //     widget.updateStatus('Export failed', widget.id);
  //   }
  //   if (!mounted) return;
  //   setState(() => isExporting = false);
  // }

  Future<void> _onUploadPressed() async {
    debugPrint(ColorCode.green('[_onUploadPressed] Uploading archive #${widget.id}', true));
    if (!mounted) return;

    setState(() {
      debugPrint(ColorCode.yellow('[_onUploadPressed] Preparing upload...', true));
      widget.updateStatus('Preparing upload...', widget.id);
      isExporting = true;
    });

    try {
      await SupabaseController.uploadArchive(widget.id);

      if (!mounted) return;

      debugPrint(ColorCode.yellow('[_onUploadPressed] Upload complete', true));
      widget.updateStatus('Upload complete', widget.id);
    } catch (e) {
      if (!mounted) return;
      debugPrint(ColorCode.red('[_onUploadPressed] Upload failed: $e', true));
      widget.updateStatus('Upload failed', widget.id);
    }
    if (!mounted) return;
    setState(() => isExporting = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) return const Text('Uploaded 👌');
    return ElevatedButton.icon(
      onPressed: widget.isEnabled && !isExporting ? _onUploadPressed : null,
      icon: const Icon(Icons.upload_file),
      label: isExporting ? const Text('Uploading...') : const Text('Upload'),
    );
  }
}
