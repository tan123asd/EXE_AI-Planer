import '../models/chat_models.dart';
import '../models/scheduler_models.dart';
import '../utils/constants.dart';
import 'ai_service.dart';
import 'scheduler_service.dart';
import 'storage_service.dart';

typedef SubtaskMatch = ({
  bool found,
  String sessionName,
  String parentTaskName,
  int taskIdx,
  int sessionIdx
});

class ChatPlannerResult {
  final AiTaskPlan plan;
  final ScheduleResult schedule;
  const ChatPlannerResult({required this.plan, required this.schedule});
}

class ChatPlannerService {
  final StorageService _storage = StorageService();
  final AiService _aiService = AiService();
  final SchedulerService _schedulerService = SchedulerService();

  // ── Plan generation ──────────────────────────────────────────────────────

  Future<ChatPlannerResult> generatePlan(ConversationContext ctx) async {
    // Ensure the deadline is at least 24 hours from now so the scheduler always
    // has a real window to work with.  Catches cases where the AI returned a
    // date-only string that was parsed as midnight-already-past.
    final rawDeadline =
        ctx.parsedDeadline ?? DateTime.now().add(const Duration(days: 7));
    final minDeadline = DateTime.now().add(const Duration(days: 1));
    final deadline =
        rawDeadline.isBefore(minDeadline) ? DateTime.now().add(const Duration(days: 7)) : rawDeadline;
    final goal = ctx.goalDescription ?? 'Unnamed goal';
    final notes = [
      if (ctx.taskDetails != null) ctx.taskDetails!,
      if (ctx.additionalNotes != null) ctx.additionalNotes!,
      if (ctx.dailyAvailableHours != null)
        'Available ${ctx.dailyAvailableHours} hours per day.',
      if (ctx.projectType != null) 'Project type: ${ctx.projectType}.',
    ].join(' ');

    final isVi = goal.runes.any((r) => r > 127) ||
        (ctx.taskDetails?.runes.any((r) => r > 127) ?? false);
    final language = isVi ? 'Vietnamese' : 'English';

    final plan = await _aiService.generateTaskPlan(
      taskName: goal,
      notes: notes.isNotEmpty ? notes : goal,
      difficulty: 'Medium',
      category: 'Study',
      deadline: deadline,
      priority: 'high',
      language: language,
    );

    final config = _buildSchedulerConfig(deadline);
    final occupied = _storage.getOccupiedTimeRanges(DateTime.now(), deadline);
    final schedule = _schedulerService.scheduleDeadlinePlan(plan, config, occupied);

    return ChatPlannerResult(plan: plan, schedule: schedule);
  }

  // ── Save approved plan ────────────────────────────────────────────────────

  Future<String> savePlan(
    AiTaskPlan plan,
    List<ScheduledSlot> slots,
    ConversationContext ctx,
  ) async {
    final goal = ctx.goalDescription ?? 'AI Plan';
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    // Flatten all scheduled slots into a sessions array
    final sessions = slots.map((slot) => {
          'startTime': slot.startTime.toIso8601String(),
          'endTime': slot.endTime.toIso8601String(),
          'duration': slot.durationMinutes,
          'taskId': slot.taskId,
          'taskName': slot.taskName,
          'isCompleted': false,
        }).toList();

    final breakSettings = _storage.getBreakSettings();
    final estimatedMinutes = plan.totalDurationMinutes;

    final taskData = {
      'id': id,
      'name': goal,
      'subject': 'Study',
      'subjectColor': AppColors.subjectAccentColor('Study').toARGB32(),
      'difficulty': 'Medium',
      'deadline': plan.deadline.toIso8601String(),
      'estimatedTime': (estimatedMinutes / 60).round(),
      'estimatedMinutes': estimatedMinutes,
      'category': 'Study',
      'taskType': 'Task',
      'notes': ctx.additionalNotes ?? '',
      'createdAt': DateTime.now().toIso8601String(),
      'needsBreak': estimatedMinutes > 60 && (breakSettings['enabled'] as bool? ?? true),
      'breakInterval': breakSettings['workDuration'] ?? 50,
      'breakDuration': breakSettings['breakDuration'] ?? 10,
      'startedAt': null,
      'completedAt': null,
      'actualTime': null,
      'sessions': sessions.isNotEmpty ? sessions : null,
      // Store subtask names for dependency reference
      'subtaskNames': plan.tasks.map((t) => t.name).toList(),
    };

    await _storage.addCustomTask(taskData);
    return id;
  }

  // ── Complete a task ────────────────────────────────────────────────────────

  Future<String> completeTask(String taskName) async {
    final task = _fuzzyFindTask(taskName);
    if (task == null) return 'Could not find a task matching "$taskName".';

    final taskId = task['id'] as String? ?? '';
    final sessions = task['sessions'];
    if (sessions is List) {
      for (int i = 0; i < sessions.length; i++) {
        await _storage.setTaskSessionCompleted(taskId, sessionIndex: i, isCompleted: true);
      }
    } else {
      await _storage.updateTaskStatus(taskId, 'completed');
    }

    // Find next priority task
    final nextTask = _findNextPriorityTask(taskId);
    if (nextTask != null) {
      final name = nextTask['name'] as String? ?? 'next task';
      final sessions = nextTask['sessions'];
      if (sessions is List && sessions.isNotEmpty) {
        final first = sessions.first as Map<String, dynamic>?;
        final start = first != null ? DateTime.tryParse(first['startTime'] as String? ?? '') : null;
        if (start != null) {
          final timeStr = _formatTime(start);
          return 'Marked complete! Next up: "$name" — scheduled for $timeStr.';
        }
      }
      return 'Marked complete! Next up: "$name".';
    }

    return 'Task "${task['name']}" marked as complete!';
  }

  // ── Re-plan remaining sessions of a task ──────────────────────────────────

  Future<ChatPlannerResult?> rePlanTask(String taskName) async {
    final task = _fuzzyFindTask(taskName);
    if (task == null) return null;

    final sessions = task['sessions'];
    if (sessions is! List || sessions.isEmpty) return null;

    final incompleteSessions = sessions
        .where((s) => (s as Map)['isCompleted'] != true)
        .toList();
    if (incompleteSessions.isEmpty) return null;

    final remainingMinutes = incompleteSessions.fold<int>(0, (sum, s) {
      return sum + ((s as Map)['duration'] as int? ?? 60);
    });

    final deadline = DateTime.tryParse(task['deadline'] as String? ?? '') ??
        DateTime.now().add(const Duration(days: 7));
    final goal = task['name'] as String? ?? 'Task';

    final isVi = goal.runes.any((r) => r > 127);
    final language = isVi ? 'Vietnamese' : 'English';

    final plan = await _aiService.generateTaskPlan(
      taskName: goal,
      notes: 'Re-planning remaining work. Remaining time: $remainingMinutes minutes.',
      difficulty: task['difficulty'] as String? ?? 'Medium',
      category: task['category'] as String? ?? 'Study',
      deadline: deadline.isBefore(DateTime.now().add(const Duration(days: 1)))
          ? DateTime.now().add(const Duration(days: 3))
          : deadline,
      priority: 'high',
      language: language,
    );

    final config = _buildSchedulerConfig(deadline);
    final occupied = _storage.getOccupiedTimeRanges(DateTime.now(), deadline);
    final schedule = _schedulerService.scheduleDeadlinePlan(plan, config, occupied);

    return ChatPlannerResult(plan: plan, schedule: schedule);
  }

  /// Update the incomplete sessions of an existing task with new scheduled slots.
  Future<void> applyRePlan(
    String taskName,
    List<ScheduledSlot> newSlots,
  ) async {
    final tasks = _storage.getCustomTasks();
    final idx = _fuzzyFindIndex(taskName, tasks);
    if (idx == -1) return;

    final task = Map<String, dynamic>.from(tasks[idx]);
    final existingSessions = task['sessions'];
    final completedSessions = existingSessions is List
        ? existingSessions.where((s) => (s as Map)['isCompleted'] == true).toList()
        : <dynamic>[];

    final newSessions = newSlots.map((slot) => {
          'startTime': slot.startTime.toIso8601String(),
          'endTime': slot.endTime.toIso8601String(),
          'duration': slot.durationMinutes,
          'taskId': slot.taskId,
          'taskName': slot.taskName,
          'isCompleted': false,
        }).toList();

    task['sessions'] = [...completedSessions, ...newSessions];
    tasks[idx] = task;
    await _storage.saveCustomTasks(tasks);
  }

  // ── Delete a task ──────────────────────────────────────────────────────────

  Future<String> deleteTask(String taskName, {bool force = false}) async {
    final task = _fuzzyFindTask(taskName);
    if (task == null) return 'Could not find a task matching "$taskName".';

    final name = task['name'] as String? ?? taskName;
    await _storage.deleteCustomTask(task['id'] as String);
    return 'Task "$name" has been deleted.';
  }

  // ── Delete a single subtask/session ───────────────────────────────────────

  /// Find a subtask for deletion (returns match info without deleting).
  /// UI should show a confirm dialog with [sessionName] + [parentTaskName],
  /// then call [confirmDeleteSubtask] if the user agrees.
  SubtaskMatch findSubtaskForDelete(String subtaskName) {
    final tasks = _storage.getCustomTasks();
    final notFound = (
      found: false,
      sessionName: '',
      parentTaskName: '',
      taskIdx: -1,
      sessionIdx: -1,
    );

    for (int ti = 0; ti < tasks.length; ti++) {
      final task = tasks[ti];
      final sessions = task['sessions'];
      if (sessions is! List) continue;

      final matchIdx = _findSessionIndex(sessions, subtaskName);
      if (matchIdx == -1) continue;

      final sessionName =
          (sessions[matchIdx] as Map)['taskName'] as String? ?? subtaskName;
      return (
        found: true,
        sessionName: sessionName,
        parentTaskName: task['name'] as String? ?? '',
        taskIdx: ti,
        sessionIdx: matchIdx,
      );
    }
    return notFound;
  }

  /// Actually removes the session after user confirmed.
  Future<void> confirmDeleteSubtask(int taskIdx, int sessionIdx) async {
    final tasks = _storage.getCustomTasks();
    if (taskIdx >= tasks.length) return;
    final task = Map<String, dynamic>.from(tasks[taskIdx]);
    final sessions = task['sessions'];
    if (sessions is! List) return;
    final updated = List<dynamic>.from(sessions)..removeAt(sessionIdx);
    task['sessions'] = updated;
    tasks[taskIdx] = task;
    await _storage.saveCustomTasks(tasks);
  }

  int _findSessionIndex(List<dynamic> sessions, String query) {
    final nq = _normalize(query);

    // 1. Exact normalized match
    var idx = sessions.indexWhere(
        (s) => _normalize((s as Map)['taskName']?.toString() ?? '') == nq);
    if (idx != -1) return idx;

    // 2. Session name contains query (normalized)
    idx = sessions.indexWhere((s) {
      final name = _normalize((s as Map)['taskName']?.toString() ?? '');
      return name.isNotEmpty && name.contains(nq);
    });
    if (idx != -1) return idx;

    // 3. Query contains session name (normalized)
    idx = sessions.indexWhere((s) {
      final name = _normalize((s as Map)['taskName']?.toString() ?? '');
      return name.isNotEmpty && nq.contains(name);
    });
    if (idx != -1) return idx;

    // 4. Word overlap ≥ 50%
    final queryWords = nq.split(RegExp(r'\s+')).where((w) => w.length > 1).toList();
    if (queryWords.isNotEmpty) {
      int bestIdx = -1;
      double bestScore = 0;
      for (int i = 0; i < sessions.length; i++) {
        final name = _normalize((sessions[i] as Map)['taskName']?.toString() ?? '');
        final matches = queryWords.where((w) => name.contains(w)).length;
        final score = matches / queryWords.length;
        if (score >= 0.5 && score > bestScore) {
          bestScore = score;
          bestIdx = i;
        }
      }
      if (bestIdx != -1) return bestIdx;
    }

    return -1;
  }

  String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[àáảãạăắặẳẵậâầấậẩẫ]'), 'a')
        .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
        .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
        .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
        .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
        .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y')
        .replaceAll('đ', 'd')
        .trim();
  }

  // ── Delete all tasks ───────────────────────────────────────────────────────

  Future<String> deleteAllTasks() async {
    final tasks = _storage.getCustomTasks();
    if (tasks.isEmpty) return 'There are no tasks to delete.';
    final count = tasks.length;
    await _storage.saveCustomTasks([]);
    return 'Deleted $count task(s). Your schedule is now empty.';
  }

  // ── Activity management ────────────────────────────────────────────────────

  /// Returns (message, pendingSessions).
  /// pendingSessions != null means AI-suggested slots awaiting user confirmation — do NOT save yet.
  /// pendingSessions == null means the action is already saved (or an error occurred).
  Future<(String, List<Map<String, dynamic>>?)> addActivity(AddActivityCall call) async {
    // MODE A: specific calendar date + specific time → single one-off session
    if (call.specificDate != null && call.specificStartHour != null) {
      final date = DateTime.tryParse(call.specificDate!);
      if (date == null) return ('Ngày không hợp lệ.', null);
      final start = DateTime(date.year, date.month, date.day, call.specificStartHour!);
      final end = start.add(Duration(minutes: call.durationMinutes));

      if (_storage.hasScheduleConflict(start, end)) {
        final alt = _storage.findNextAvailableSlot(call.durationMinutes, start);
        final msg = 'Khung giờ ${call.specificStartHour}h-${end.hour}h ngày ${date.day}/${date.month} đã bị chiếm.';
        return (alt != null ? '$msg Slot trống gần nhất: ${_formatTime(alt)}.' : msg, null);
      }

      final id = DateTime.now().millisecondsSinceEpoch.toString();
      await _storage.addCustomTask({
        'id': id,
        'name': call.name,
        'subject': call.category,
        'taskType': 'Activity',
        'estimatedMinutes': call.durationMinutes,
        'estimatedTime': (call.durationMinutes / 60).round(),
        'category': call.category,
        'createdAt': DateTime.now().toIso8601String(),
        'sessions': [{
          'startTime': start.toIso8601String(),
          'endTime': end.toIso8601String(),
          'duration': call.durationMinutes,
          'taskName': call.name,
          'isCompleted': false,
        }],
      });
      return ('Đã thêm hoạt động "${call.name}" vào ${call.specificStartHour}h-${end.hour}h ngày ${date.day}/${date.month}.', null);
    }

    // MODE B: specific time, no specific date → recurring at that exact hour on weekdays
    if (call.specificStartHour != null) {
      return _addRecurringActivity(call);
    }

    // MODE C: no specific time → AI suggests slots, returns pending for user confirmation
    return _suggestActivitySlots(call);
  }

  Future<(String, List<Map<String, dynamic>>?)> _addRecurringActivity(AddActivityCall call) async {
    final weekdays = call.preferredWeekdays ?? [1, 2, 3, 4, 5, 6, 7];
    final sessions = <Map<String, dynamic>>[];
    final conflicts = <String>[];

    for (final wd in weekdays) {
      // Find first occurrence of this weekday starting from tomorrow
      var cursor = DateTime.now().add(const Duration(days: 1));
      while (cursor.weekday != wd) {
        cursor = cursor.add(const Duration(days: 1));
      }
      // Add next 4 weekly occurrences
      for (int i = 0; i < 4; i++) {
        final start = DateTime(cursor.year, cursor.month, cursor.day, call.specificStartHour!);
        final end = start.add(Duration(minutes: call.durationMinutes));
        if (_storage.hasScheduleConflict(start, end)) {
          conflicts.add('${_weekdayShort(wd)} ${start.day}/${start.month}');
        } else {
          sessions.add({
            'startTime': start.toIso8601String(),
            'endTime': end.toIso8601String(),
            'duration': call.durationMinutes,
            'taskName': call.name,
            'isCompleted': false,
          });
        }
        cursor = cursor.add(const Duration(days: 7));
      }
    }

    if (sessions.isEmpty) {
      return ('Không thêm được "${call.name}" — tất cả slot ${call.specificStartHour}h trên các ngày đã chọn đều bị chiếm.', null);
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await _storage.addCustomTask({
      'id': id,
      'name': call.name,
      'subject': call.category,
      'taskType': 'Activity',
      'estimatedMinutes': call.durationMinutes,
      'estimatedTime': (call.durationMinutes / 60).round(),
      'category': call.category,
      'weekdays': weekdays,
      'createdAt': DateTime.now().toIso8601String(),
      'sessions': sessions,
    });

    final conflictNote = conflicts.isNotEmpty ? '\nBỏ qua do xung đột: ${conflicts.join(', ')}' : '';
    return ('Đã thêm hoạt động "${call.name}" vào ${call.specificStartHour}h — ${sessions.length} buổi.$conflictNote', null);
  }

  Future<(String, List<Map<String, dynamic>>?)> _suggestActivitySlots(AddActivityCall call) async {
    final weekdays = call.preferredWeekdays ?? [1, 2, 3, 4, 5, 6, 7];
    final request = ActivityRequest(
      name: call.name,
      durationMinutes: call.durationMinutes,
      preferredWeekdays: weekdays,
      category: call.category,
    );
    final config = _buildSchedulerConfig(DateTime.now().add(const Duration(days: 28)));
    final occupied = _storage.getOccupiedTimeRanges(
        DateTime.now(), DateTime.now().add(const Duration(days: 28)));
    final candidates = _schedulerService.scheduleActivity(request, config, occupied);

    if (candidates.isEmpty) {
      return ('Không tìm được slot phù hợp cho "${call.name}". Vui lòng chỉ định giờ cụ thể.', null);
    }

    final top = candidates.take(3).toList();
    final sessions = top.map((s) => {
      'startTime': s.startTime.toIso8601String(),
      'endTime': s.endTime.toIso8601String(),
      'duration': s.durationMinutes,
      'taskName': call.name,
      'isCompleted': false,
    }).toList();

    final slotList = top.map((s) => '  • ${_formatTime(s.startTime)}').join('\n');
    final msg = 'Tôi gợi ý thêm "${call.name}" vào:\n$slotList\n\nGõ "ok" để xác nhận hoặc "hủy" để từ chối.';
    return (msg, sessions);
  }

  Future<String> saveActivitySlots({
    required String name,
    required String category,
    required int durationMinutes,
    required List<Map<String, dynamic>> sessions,
    List<int>? weekdays,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await _storage.addCustomTask({
      'id': id,
      'name': name,
      'subject': category,
      'taskType': 'Activity',
      'estimatedMinutes': durationMinutes,
      'estimatedTime': (durationMinutes / 60).round(),
      'category': category,
      'weekdays': weekdays,
      'createdAt': DateTime.now().toIso8601String(),
      'sessions': sessions,
    });
    return 'Đã lưu hoạt động "$name" — ${sessions.length} buổi.';
  }

  String _weekdayShort(int wd) {
    const names = {1: 'T2', 2: 'T3', 3: 'T4', 4: 'T5', 5: 'T6', 6: 'T7', 7: 'CN'};
    return names[wd] ?? 'T?';
  }

  Future<String> shiftActivity(String name, int daysOffset) async {
    final tasks = _storage.getCustomTasks();
    final idx = _fuzzyFindActivityIndex(name, tasks);
    if (idx == -1) return 'Không tìm thấy hoạt động khớp với "$name".';

    final task = Map<String, dynamic>.from(tasks[idx]);
    final sessions = task['sessions'];
    if (sessions is! List) return 'Hoạt động "${task['name']}" không có buổi nào để dời.';

    final shifted = sessions.map((s) {
      final m = Map<String, dynamic>.from(s as Map);
      final start = DateTime.tryParse(m['startTime'] as String? ?? '');
      final end = DateTime.tryParse(m['endTime'] as String? ?? '');
      if (start != null) m['startTime'] = start.add(Duration(days: daysOffset)).toIso8601String();
      if (end != null) m['endTime'] = end.add(Duration(days: daysOffset)).toIso8601String();
      return m;
    }).toList();

    task['sessions'] = shifted;
    tasks[idx] = task;
    await _storage.saveCustomTasks(tasks);

    final actName = task['name'] as String? ?? name;
    final dir = daysOffset > 0 ? 'tới $daysOffset ngày' : 'lùi ${-daysOffset} ngày';
    return 'Đã dời hoạt động "$actName" $dir.';
  }

  Future<String> deleteActivity(String name) async {
    final tasks = _storage.getCustomTasks();
    final idx = _fuzzyFindActivityIndex(name, tasks);
    if (idx == -1) return 'Không tìm thấy hoạt động khớp với "$name".';

    final actName = tasks[idx]['name'] as String? ?? name;
    await _storage.deleteCustomTask(tasks[idx]['id'] as String);
    return 'Đã xóa hoạt động "$actName".';
  }

  int _fuzzyFindActivityIndex(String name, List<Map<String, dynamic>> tasks) {
    final activities = tasks
        .asMap()
        .entries
        .where((e) => e.value['taskType'] == 'Activity')
        .toList();

    final query = name.toLowerCase().trim();

    // Exact match
    var entry = activities.firstWhere(
        (e) => (e.value['name'] as String? ?? '').toLowerCase() == query,
        orElse: () => const MapEntry(-1, {}));
    if (entry.key != -1) return entry.key;

    // Contains match
    entry = activities.firstWhere(
        (e) => (e.value['name'] as String? ?? '').toLowerCase().contains(query),
        orElse: () => const MapEntry(-1, {}));
    if (entry.key != -1) return entry.key;

    // Query contains activity name
    entry = activities.firstWhere(
        (e) => query.contains((e.value['name'] as String? ?? '').toLowerCase()),
        orElse: () => const MapEntry(-1, {}));
    return entry.key;
  }

  // ── Add task directly (single session, full info provided) ────────────────

  Future<String> addTaskDirect(
    String taskName,
    int durationMinutes,
    String specificDate,
    int startHour,
  ) async {
    final date = DateTime.tryParse(specificDate);
    if (date == null) return 'Ngày không hợp lệ.';

    final start = DateTime(date.year, date.month, date.day, startHour);
    final end = start.add(Duration(minutes: durationMinutes));

    if (_storage.hasScheduleConflict(start, end)) {
      final alt = _storage.findNextAvailableSlot(durationMinutes, start);
      final msg =
          'Khung giờ ${startHour}h-${end.hour}h ngày ${date.day}/${date.month} đã bị chiếm.';
      if (alt != null) return '$msg Slot trống gần nhất: ${_formatTime(alt)}.';
      return msg;
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await _storage.addCustomTask({
      'id': id,
      'name': taskName,
      'subject': 'Personal',
      'subjectColor': AppColors.subjectAccentColor('Personal').toARGB32(),
      'taskType': 'Task',
      'deadline': end.toIso8601String(),
      'estimatedMinutes': durationMinutes,
      'estimatedTime': (durationMinutes / 60).round(),
      'category': 'Personal',
      'createdAt': DateTime.now().toIso8601String(),
      'sessions': [
        {
          'startTime': start.toIso8601String(),
          'endTime': end.toIso8601String(),
          'duration': durationMinutes,
          'taskName': taskName,
          'isCompleted': false,
        }
      ],
    });
    return 'Đã thêm task "$taskName" vào ${startHour}h-${end.hour}h ngày ${date.day}/${date.month}.';
  }

  // ── Modify task schedule ───────────────────────────────────────────────────

  /// Shifts all sessions of a task by [daysOffset] days.
  Future<String> shiftTaskByDays(String taskName, int daysOffset) async {
    final tasks = _storage.getCustomTasks();
    final idx = _fuzzyFindIndex(taskName, tasks);
    if (idx == -1) return 'Could not find a task matching "$taskName".';

    final task = Map<String, dynamic>.from(tasks[idx]);
    final sessions = task['sessions'];
    if (sessions is! List) return 'Task "${task['name']}" has no sessions to shift.';

    final shifted = sessions.map((s) {
      final m = Map<String, dynamic>.from(s as Map);
      final start = DateTime.tryParse(m['startTime'] as String? ?? '');
      final end = DateTime.tryParse(m['endTime'] as String? ?? '');
      if (start != null) m['startTime'] = start.add(Duration(days: daysOffset)).toIso8601String();
      if (end != null) m['endTime'] = end.add(Duration(days: daysOffset)).toIso8601String();
      return m;
    }).toList();

    task['sessions'] = shifted;
    tasks[idx] = task;
    await _storage.saveCustomTasks(tasks);

    final name = task['name'] as String? ?? taskName;
    final dir = daysOffset > 0 ? 'forward $daysOffset day(s)' : 'back ${-daysOffset} day(s)';
    return 'Shifted "$name" $dir.';
  }

  // ── Dependency validation (deterministic) ─────────────────────────────────

  /// Returns true if taskA can be scheduled before taskB given the dependency graph.
  /// Returns false if taskB is an ancestor of taskA (meaning taskA requires taskB first).
  bool canScheduleBefore(
    String taskA,
    String taskB,
    Map<String, List<String>> graph,
  ) {
    // If taskA depends (directly or transitively) on taskB, taskA cannot go before taskB.
    return !_isAncestor(graph, taskB, taskA);
  }

  bool _isAncestor(Map<String, List<String>> graph, String ancestor, String node) {
    final visited = <String>{};
    return _dfs(graph, ancestor, node, visited);
  }

  bool _dfs(Map<String, List<String>> graph, String target, String current, Set<String> visited) {
    if (current == target) return true;
    if (visited.contains(current)) return false;
    visited.add(current);
    final prerequisites = graph[current] ?? [];
    for (final dep in prerequisites) {
      if (_dfs(graph, target, dep, visited)) return true;
    }
    return false;
  }

  // ── Adjust workload ────────────────────────────────────────────────────────

  /// Regenerates the schedule for [taskId] with session durations scaled by [multiplier].
  /// multiplier < 1.0 = lighter plan, > 1.0 = more intensive.
  Future<ScheduleResult?> adjustWorkload(
    String taskId,
    double multiplier,
    DateTime deadline,
  ) async {
    final tasks = _storage.getCustomTasks();
    final task = tasks.firstWhere(
      (t) => (t['id'] ?? '').toString() == taskId,
      orElse: () => <String, dynamic>{},
    );
    if (task.isEmpty) return null;

    // Build a simple single-subtask plan with adjusted duration
    final estimatedMins = (task['estimatedMinutes'] as int? ?? 120) * multiplier;
    final clamped = estimatedMins.clamp(30, 480).round();
    final subtask = AiSubtask(
      order: 1,
      name: task['name'] as String? ?? 'Task',
      duration: clamped / 60,
      focusLevel: 'medium',
      minBlock: 0.5,
      preferredTime: 'flexible',
    );
    final plan = AiTaskPlan(
      createdAt: DateTime.now(),
      deadline: deadline,
      priority: 'medium',
      tasks: [subtask],
    );

    final config = _buildSchedulerConfig(deadline);
    final occupied = _storage.getOccupiedTimeRanges(DateTime.now(), deadline);
    return _schedulerService.scheduleDeadlinePlan(plan, config, occupied);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  SchedulerConfig _buildSchedulerConfig(DateTime deadline) {
    final hours = _storage.getProductivityHours();
    final windows = hours
        .map((h) => ProductivityWindow(
              startHour: h['startHour'] as int,
              endHour: h['endHour'] as int,
            ))
        .toList();
    return SchedulerConfig(
      productivityWindows: windows,
      searchFrom: DateTime.now(),
      deadline: deadline,
    );
  }

  Map<String, dynamic>? findTask(String name) => _fuzzyFindTask(name);

  Map<String, dynamic>? _fuzzyFindTask(String name) {
    final tasks = _storage.getCustomTasks();
    final idx = _fuzzyFindIndex(name, tasks);
    return idx == -1 ? null : tasks[idx];
  }

  int _fuzzyFindIndex(String name, List<Map<String, dynamic>> tasks) {
    final query = name.toLowerCase().trim();

    // Exact match first
    var idx = tasks.indexWhere(
        (t) => (t['name'] as String? ?? '').toLowerCase() == query);
    if (idx != -1) return idx;

    // Contains match (task name contains full query)
    idx = tasks.indexWhere(
        (t) => (t['name'] as String? ?? '').toLowerCase().contains(query));
    if (idx != -1) return idx;

    // Reverse contains (query contains task name)
    idx = tasks.indexWhere(
        (t) => query.contains((t['name'] as String? ?? '').toLowerCase()));
    if (idx != -1) return idx;

    // Word-overlap: at least 50% of meaningful query words match task name
    final queryWords =
        query.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
    if (queryWords.isNotEmpty) {
      int bestIdx = -1;
      double bestScore = 0;
      for (int i = 0; i < tasks.length; i++) {
        final taskName = (tasks[i]['name'] as String? ?? '').toLowerCase();
        final matches =
            queryWords.where((w) => taskName.contains(w)).length;
        final score = matches / queryWords.length;
        if (score >= 0.5 && score > bestScore) {
          bestScore = score;
          bestIdx = i;
        }
      }
      if (bestIdx != -1) return bestIdx;
    }

    return -1;
  }

  Map<String, dynamic>? _findNextPriorityTask(String excludeId) {
    final tasks = _storage.getCustomTasks();
    final incomplete = tasks.where((t) {
      if ((t['id'] ?? '') == excludeId) return false;
      if (t['taskType'] != 'Task') return false;
      final sessions = t['sessions'];
      if (sessions is! List || sessions.isEmpty) return false;
      return sessions.any((s) => (s as Map)['isCompleted'] != true);
    }).toList();

    if (incomplete.isEmpty) return null;

    // Sort by nearest deadline
    incomplete.sort((a, b) {
      final da = DateTime.tryParse(a['deadline'] as String? ?? '');
      final db = DateTime.tryParse(b['deadline'] as String? ?? '');
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });

    return incomplete.first;
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][local.weekday - 1];
    return '$weekday $h:$minute $period';
  }
}
