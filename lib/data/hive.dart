import 'package:asg/data/constants/config.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:asg/screens/sensor_manager/widgets/mode_toggle.dart';

class StateBox {
  StateBox._();
  static final StateBox instance = StateBox._();

  late Box _box;
  final Map<String, dynamic> _pendingUpdates = {};
  bool stateBoxInitialized = false;

  Future<void> _init() async {
    await Hive.initFlutter(); // Initialize Hive (once)
    _box = await Hive.openBox('service_state'); // Open your box (once)
    stateBoxInitialized = true;
  }

  // Update state safely
  Future<void> updateState({int? bundleId, bool? isNimaz, bool? isRunning, int? startTimeMillis}) async {
    if (!stateBoxInitialized) await _init();

    if (bundleId != null) _pendingUpdates['bundleId'] = bundleId;
    if (isNimaz != null) _pendingUpdates['isNimaz'] = isNimaz;
    if (startTimeMillis != null) _pendingUpdates['startTimeMillis'] = startTimeMillis;
    if (isRunning != null) _pendingUpdates['isRunning'] = isRunning;

    await _box.putAll(_pendingUpdates); // write all pending updates
    await _box.flush(); // ensure they're persisted to disk
    _pendingUpdates.clear(); // clear pending updates
  }

  // Read current state safely
  Future<ServiceState> getState() async {
    if (!stateBoxInitialized) await _init();

    return ServiceState(
      bundleId: _box.get('bundleId', defaultValue: null),
      isNimaz: _box.get('isNimaz', defaultValue: null),
      startTimeMillis: _box.get('startTimeMillis'),
      isRunning: _box.get('isRunning', defaultValue: null),
    );
  }

  // ==================== [ Schedules] ====================

  Future<void> overwriteSchedules(Map<String, Map<String, dynamic>> schedules) async {
    if (!stateBoxInitialized) await _init();

    await _box.put('schedules', schedules);
    await _box.flush();
  }

  Future<Map<String, Map<String, dynamic>>> getSchedules() async {
    if (!stateBoxInitialized) await _init();
    final raw = _box.get('schedules');
    if (raw == null) return {};
    return Map<String, Map<String, dynamic>>.from(
      (raw as Map).map((key, value) => MapEntry(key as String, Map<String, dynamic>.from(value as Map))),
    );
  }

  // ==================== [ Sensor mode] ====================
  Future<void> setSensorMode(Mode mode) async {
    if (!stateBoxInitialized) await _init();

    await _box.put('sensorMode', mode == Mode.manual ? 'manual' : 'schedule');
    await _box.flush();
  }

  Future<Mode> getSensorMode() async {
    if (!stateBoxInitialized) await _init();

    final value = _box.get('sensorMode', defaultValue: 'manual');

    return value == 'schedule' ? Mode.schedule : Mode.manual;
  }

  // ==================== [ Data Upload Quene] ====================
  Future<void> addToUploadQueue(int epochTime, int archiveId) async {
    if (!stateBoxInitialized) await _init();
    final raw = _box.get('uploadQueue');
    final Map<int, int> queue = raw != null ? Map<int, int>.from(raw as Map) : <int, int>{};
    queue[archiveId] = epochTime;
    await _box.put('uploadQueue', queue);
    await _box.flush();
  }

  /// Removes the given archive ID from the upload queue.
  Future<void> removeFromUploadQueue(int archiveId) async {
    if (!stateBoxInitialized) await _init();
    final raw = _box.get('uploadQueue');
    final Map<int, int> queue = raw != null ? Map<int, int>.from(raw as Map) : <int, int>{};
    queue.remove(archiveId);
    await _box.put('uploadQueue', queue);
    await _box.flush();
  }

  /// Retrieves the current upload queue as a map of archive IDs to their corresponding epoch times.
  Future<List<({int archiveId, int epochTime})>> getUploadQueue() async {
    if (!stateBoxInitialized) await _init();
    final raw = _box.get('uploadQueue');
    if (raw == null) return [];
    final Map<int, int> queue = Map<int, int>.from(raw as Map);
    return queue.entries.map((e) => (archiveId: e.key, epochTime: e.value)).toList();
  }

  Future<int?> currentUploadArchiveId(int? setArchiveId) async {
    if (!stateBoxInitialized) await _init();
    if (setArchiveId == null) {
      setArchiveId = _box.get('currentUploadArchiveId', defaultValue: null) as int?;
      await _box.put('currentUploadArchiveId', null);
      return setArchiveId;
    }
    await _box.put('currentUploadArchiveId', setArchiveId);
    return setArchiveId;
  }

  // ==================== [ Device Codename ] ====================
  Future<String> getDeviceCodename() async {
    if (!stateBoxInitialized) await _init();
    final codename = _box.get('deviceCodename');
    if (codename == null) {
      final newCodename = Config().generateCodename();
      await _box.put('deviceCodename', newCodename);
      await _box.flush();
      return newCodename;
    }
    return codename;
  }
}

class ServiceState {
  final int? startTimeMillis;
  final bool? isRunning;
  final int? bundleId;
  final bool? isNimaz;

  ServiceState({this.bundleId, this.isNimaz, this.startTimeMillis, this.isRunning});
}
