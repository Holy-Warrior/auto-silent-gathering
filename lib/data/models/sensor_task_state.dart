// lib\data\models\sensor_task_state.dart
class SensorTaskState {
  final String label;
  final DateTime plannedStopTime;
  final int? bundleId;

  const SensorTaskState({
    required this.label,
    required this.plannedStopTime,
    this.bundleId,
  });

  factory SensorTaskState.defaults() {
    final now = DateTime.now();
    return SensorTaskState(
      label: 'Random',
      plannedStopTime: now.add(const Duration(minutes: 40)),
      bundleId: null,
    );
  }
}
