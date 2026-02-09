import 'dart:async';
import 'package:flutter/material.dart';

class ElapsedTimeText extends StatefulWidget {
  final DateTime startTime;

  const ElapsedTimeText({
    super.key,
    required this.startTime,
  });

  @override
  State<ElapsedTimeText> createState() => _ElapsedTimeTextState();
}

class _ElapsedTimeTextState extends State<ElapsedTimeText> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();

    // Rebuild once per second
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);

    return '${h.toString().padLeft(2, '0')}:'
           '${m.toString().padLeft(2, '0')}:'
           '${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.startTime);

    return Text(
      _format(elapsed),
      style: const TextStyle(fontSize: 18),
    );
  }
}
