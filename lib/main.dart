import 'package:flutter/material.dart';
import 'my_forground_tasks.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sensor Foreground',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Sensor Foreground Notification'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Theme.of(context).colorScheme.inversePrimary, title: Text(widget.title)),
      body: Center(child: Column(mainAxisAlignment: .center,
          children: [
            ElevatedButton(onPressed: initForegroundService, child: Text('Start Sensor Foreground Service')),
            ElevatedButton(onPressed: closeForegroundService, child: Text('Stop Sensor Service')),
          ],
        ),
      ),
    );
  }
}
