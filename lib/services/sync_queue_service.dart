import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'firestore_service.dart';

/// Operation types that can be queued while offline.
enum SyncOp { completeSession, updateStatus, deleteTask, deleteSession, addTask }

class SyncQueueService {
  static final SyncQueueService _instance = SyncQueueService._internal();
  factory SyncQueueService() => _instance;
  SyncQueueService._internal();

  static const String _queueKey = 'sync_queue';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ─── Queue management ────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _loadQueue() {
    final raw = _prefs?.getString(_queueKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveQueue(List<Map<String, dynamic>> queue) async {
    await _prefs?.setString(_queueKey, jsonEncode(queue));
  }

  Future<void> enqueue(Map<String, dynamic> entry) async {
    final queue = _loadQueue();
    queue.add({
      ...entry,
      'ts': DateTime.now().toUtc().toIso8601String(),
    });
    await _saveQueue(queue);
  }

  bool get hasPending => _loadQueue().isNotEmpty;

  // ─── Convenience enqueue methods ─────────────────────────────────────────────

  Future<void> enqueueCompleteSession({
    required String taskId,
    required int sessionIndex,
    required bool isCompleted,
  }) =>
      enqueue({
        'op': 'completeSession',
        'taskId': taskId,
        'sessionIndex': sessionIndex,
        'isCompleted': isCompleted,
      });

  Future<void> enqueueUpdateStatus({
    required String taskId,
    required String status,
  }) =>
      enqueue({'op': 'updateStatus', 'taskId': taskId, 'status': status});

  Future<void> enqueueDeleteTask(String taskId) =>
      enqueue({'op': 'deleteTask', 'taskId': taskId});

  Future<void> enqueueDeleteSession({
    required String taskId,
    required int sessionIndex,
  }) =>
      enqueue({
        'op': 'deleteSession',
        'taskId': taskId,
        'sessionIndex': sessionIndex,
      });

  Future<void> enqueueAddTask(Map<String, dynamic> task) =>
      enqueue({'op': 'addTask', 'task': task});

  // ─── Flush ───────────────────────────────────────────────────────────────────

  /// Processes all pending operations against Firestore in timestamp order.
  /// Safe to call multiple times — already-processed ops are removed from queue.
  Future<void> flushToFirestore() async {
    final queue = _loadQueue();
    if (queue.isEmpty) return;

    // Sort by timestamp ascending so ordering is preserved
    queue.sort((a, b) => (a['ts'] as String).compareTo(b['ts'] as String));

    final firestore = FirestoreService();
    final failed = <Map<String, dynamic>>[];

    for (final entry in queue) {
      try {
        await _processEntry(entry, firestore);
      } catch (_) {
        // Network failed mid-flush — keep this entry and stop
        failed.add(entry);
        break;
      }
    }

    // Remove successfully processed entries
    final processed = queue.length - failed.length;
    final remaining = queue.sublist(processed);
    await _saveQueue(remaining);
  }

  Future<void> _processEntry(
    Map<String, dynamic> entry,
    FirestoreService firestore,
  ) async {
    final op = entry['op'] as String;
    final taskId = (entry['taskId'] as String?) ?? '';

    switch (op) {
      case 'completeSession':
        // Skip if task no longer exists on Firestore (deleted from another device)
        if (!await firestore.taskExists(taskId)) return;
        final sessionIndex = entry['sessionIndex'] as int;
        final isCompleted = entry['isCompleted'] as bool;
        await firestore.updateSessionCompleted(taskId, sessionIndex, isCompleted);

      case 'updateStatus':
        if (!await firestore.taskExists(taskId)) return;
        final status = entry['status'] as String;
        await firestore.updateTaskFields(taskId, {'status': status});

      case 'deleteTask':
        // Idempotent — no existence check needed
        await firestore.deleteTask(taskId);

      case 'deleteSession':
        if (!await firestore.taskExists(taskId)) return;
        // Re-fetch the task and remove the session, then push the whole doc back
        final tasks = await firestore.fetchAllTasks();
        final task = tasks.firstWhere(
          (t) => t['id']?.toString() == taskId,
          orElse: () => {},
        );
        if (task.isEmpty) return;
        final sessions = task['sessions'];
        if (sessions is! List) return;
        final sessionIndex = entry['sessionIndex'] as int;
        if (sessionIndex < 0 || sessionIndex >= sessions.length) return;
        sessions.removeAt(sessionIndex);
        if (sessions.isEmpty) {
          await firestore.deleteTask(taskId);
        } else {
          task['sessions'] = sessions;
          await firestore.pushTask(task);
        }

      case 'addTask':
        final taskData = entry['task'] as Map<String, dynamic>?;
        if (taskData == null) return;
        await firestore.pushTask(taskData);
    }
  }
}
