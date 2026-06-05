import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'firestore_service.dart';
import 'sync_queue_service.dart';
import 'connectivity_service.dart';

class StorageService {
  static const String _tasksKey = 'tasks';
  static const String _completedTasksKey = 'completed_tasks';
  static const String _inProgressTasksKey = 'in_progress_tasks';
  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';
  static const String _userPhotoUrlKey = 'user_photo_url';
  static const String _userPhoneKey = 'user_phone';
  static const String _userBioKey = 'user_bio';
  static const String _customTasksKey = 'custom_tasks';
  static const String _customTasksUpdatedAtKey = 'custom_tasks_updatedAt';
  static const String _scheduleKey = 'generated_schedule';
  static const String _themeKey = 'theme_mode';
  static const String _filterKey = 'filter_preferences';

  // Singleton pattern
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  // Initialize shared preferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ==================== USER NAME ====================
  
  Future<void> saveUserName(String name) async {
    await _prefs?.setString(_userNameKey, name);
  }

  String getUserName() {
    return _prefs?.getString(_userNameKey) ?? '';
  }

  Future<void> saveUserEmail(String email) async {
    await _prefs?.setString(_userEmailKey, email);
  }

  String getUserEmail() {
    return _prefs?.getString(_userEmailKey) ?? '';
  }

  Future<void> saveUserPhotoUrl(String photoUrl) async {
    await _prefs?.setString(_userPhotoUrlKey, photoUrl);
  }

  String getUserPhotoUrl() {
    return _prefs?.getString(_userPhotoUrlKey) ?? '';
  }

  Future<void> saveUserPhone(String phone) async {
    await _prefs?.setString(_userPhoneKey, phone);
  }

  String getUserPhone() {
    return _prefs?.getString(_userPhoneKey) ?? '';
  }

  Future<void> saveUserBio(String bio) async {
    await _prefs?.setString(_userBioKey, bio);
  }

  String getUserBio() {
    return _prefs?.getString(_userBioKey) ?? '';
  }

  // ==================== TASK COMPLETION ====================
  
  Future<void> saveCompletedTasks(List<String> taskIds) async {
    await _prefs?.setStringList(_completedTasksKey, taskIds);
  }

  List<String> getCompletedTasks() {
    return _prefs?.getStringList(_completedTasksKey) ?? [];
  }

  Future<void> toggleTaskCompletion(String taskId) async {
    final completed = getCompletedTasks();
    if (completed.contains(taskId)) {
      completed.remove(taskId);
    } else {
      completed.add(taskId);
    }
    await saveCompletedTasks(completed);
    final newStatus = completed.contains(taskId) ? 'completed' : 'pending';
    await _syncOrQueueStatus(taskId, newStatus);
  }

  bool isTaskCompleted(String taskId) {
    return getCompletedTasks().contains(taskId);
  }

  // ==================== IN-PROGRESS TASKS ====================
  
  Future<void> saveInProgressTasks(List<String> taskIds) async {
    await _prefs?.setStringList(_inProgressTasksKey, taskIds);
  }

  List<String> getInProgressTasks() {
    return _prefs?.getStringList(_inProgressTasksKey) ?? [];
  }

  Future<void> setTaskInProgress(String taskId) async {
    final inProgress = getInProgressTasks();
    if (!inProgress.contains(taskId)) {
      inProgress.add(taskId);
      await saveInProgressTasks(inProgress);
    }
  }

  Future<void> removeTaskFromInProgress(String taskId) async {
    final inProgress = getInProgressTasks();
    inProgress.remove(taskId);
    await saveInProgressTasks(inProgress);
  }

  bool isTaskInProgress(String taskId) {
    return getInProgressTasks().contains(taskId);
  }

  String getTaskStatus(String taskId) {
    if (isTaskCompleted(taskId)) return 'completed';
    if (isTaskInProgress(taskId)) return 'inProgress';
    return 'pending';
  }

  Future<void> updateTaskStatus(String taskId, String status) async {
    // Remove from all lists first
    await removeTaskFromInProgress(taskId);
    final completed = getCompletedTasks();
    completed.remove(taskId);
    await saveCompletedTasks(completed);

    // Add to appropriate list
    if (status == 'completed') {
      completed.add(taskId);
      await saveCompletedTasks(completed);
    } else if (status == 'inProgress') {
      await setTaskInProgress(taskId);
    }
    // 'pending' means not in any list
  }

  // ==================== CUSTOM TASKS (User Created) ====================
  
  Future<void> saveCustomTasks(List<Map<String, dynamic>> tasks) async {
    final tasksJson = jsonEncode(tasks);
    await _prefs?.setString(_customTasksKey, tasksJson);
    await _prefs?.setString(_customTasksUpdatedAtKey, DateTime.now().toUtc().toIso8601String());
  }

  List<Map<String, dynamic>> getCustomTasks() {
    final tasksJson = _prefs?.getString(_customTasksKey);
    if (tasksJson == null || tasksJson.isEmpty) {
      return [];
    }
    final List<dynamic> decoded = jsonDecode(tasksJson);
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<void> addCustomTask(Map<String, dynamic> task) async {
    final tasks = getCustomTasks();
    tasks.add(task);
    await saveCustomTasks(tasks);
    // Add requires internet — push to Firestore directly (no queue needed)
    final online = await ConnectivityService().isOnline();
    if (online) {
      await FirestoreService().pushTask(task);
    }
  }

  Future<void> setTaskSessionCompleted(
    String taskId, {
    required int sessionIndex,
    required bool isCompleted,
  }) async {
    final tasks = getCustomTasks();
    final taskIndex = tasks.indexWhere((t) => (t['id'] ?? '').toString() == taskId);
    if (taskIndex == -1) return;

    final task = Map<String, dynamic>.from(tasks[taskIndex]);
    final sessionsAny = task['sessions'];
    if (sessionsAny is! List) return;
    if (sessionIndex < 0 || sessionIndex >= sessionsAny.length) return;

    final sessions = sessionsAny.map((e) => e is Map ? Map<String, dynamic>.from(e) : e).toList();
    final s = sessions[sessionIndex];
    if (s is! Map<String, dynamic>) return;
    s['isCompleted'] = isCompleted;
    sessions[sessionIndex] = s;
    task['sessions'] = sessions;

    // If a Task has sessions, consider it completed only when all sessions are completed.
    final allDone = sessions
        .whereType<Map<String, dynamic>>()
        .isNotEmpty &&
        sessions
            .whereType<Map<String, dynamic>>()
            .every((m) => m['isCompleted'] == true);
    task['isCompleted'] = allDone;

    tasks[taskIndex] = task;
    await saveCustomTasks(tasks);
    await _syncOrQueueCompleteSession(
        taskId: taskId, sessionIndex: sessionIndex, isCompleted: isCompleted);
  }

  Future<void> deleteCustomTask(String taskId) async {
    final tasks = getCustomTasks();
    tasks.removeWhere((task) => task['id'] == taskId);
    await saveCustomTasks(tasks);
    await _syncOrQueueDeleteTask(taskId);
  }

  /// Replaces a task in-place and pushes the update to Firestore when online.
  /// Use for session edits, time shifts, re-plans — not for adds/deletes.
  Future<void> updateCustomTask(Map<String, dynamic> updatedTask) async {
    final taskId = (updatedTask['id'] ?? '').toString();
    if (taskId.isEmpty) return;
    final tasks = getCustomTasks();
    final idx = tasks.indexWhere((t) => (t['id'] ?? '').toString() == taskId);
    if (idx == -1) return;
    tasks[idx] = updatedTask;
    await saveCustomTasks(tasks);
    final online = await ConnectivityService().isOnline();
    if (online) {
      await FirestoreService().pushTask(updatedTask);
    }
  }

  /// Deletes all tasks from local storage and Firestore.
  /// Uses batch delete on Firestore when online; queues each deletion otherwise.
  Future<void> deleteAllCustomTasks() async {
    final tasks = getCustomTasks();
    if (tasks.isEmpty) return;
    await saveCustomTasks([]); // clears local + updates timestamp
    final online = await ConnectivityService().isOnline();
    if (online) {
      await FirestoreService().deleteAllTasks();
    } else {
      for (final task in tasks) {
        final id = (task['id'] ?? '').toString();
        if (id.isNotEmpty) {
          await SyncQueueService().enqueueDeleteTask(id);
        }
      }
    }
  }

  /// Xóa 1 session khỏi task. Nếu không còn session nào thì xóa luôn task cha.
  Future<void> deleteTaskSession(String taskId, int sessionIndex) async {
    final tasks = getCustomTasks();
    final taskIndex = tasks.indexWhere((t) => (t['id'] ?? '').toString() == taskId);
    if (taskIndex == -1) return;

    final task = Map<String, dynamic>.from(tasks[taskIndex]);
    final sessionsAny = task['sessions'];
    if (sessionsAny is! List) return;

    final sessions = sessionsAny
        .map((e) => e is Map ? Map<String, dynamic>.from(e) : e)
        .toList();
    if (sessionIndex < 0 || sessionIndex >= sessions.length) return;

    sessions.removeAt(sessionIndex);

    if (sessions.isEmpty) {
      tasks.removeAt(taskIndex);
      await saveCustomTasks(tasks);
      await _syncOrQueueDeleteTask(taskId);
    } else {
      task['sessions'] = sessions;
      tasks[taskIndex] = task;
      await saveCustomTasks(tasks);
      await _syncOrQueueDeleteSession(taskId: taskId, sessionIndex: sessionIndex);
    }
  }

  // ==================== GENERATED SCHEDULE ====================
  
  Future<void> saveGeneratedSchedule(List<Map<String, dynamic>> schedule) async {
    final scheduleJson = jsonEncode(schedule);
    await _prefs?.setString(_scheduleKey, scheduleJson);
  }

  List<Map<String, dynamic>> getGeneratedSchedule() {
    final scheduleJson = _prefs?.getString(_scheduleKey);
    if (scheduleJson == null || scheduleJson.isEmpty) {
      return [];
    }
    final List<dynamic> decoded = jsonDecode(scheduleJson);
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<void> clearSchedule() async {
    await _prefs?.remove(_scheduleKey);
  }

  // ==================== THEME MODE ====================
  
  Future<void> saveThemeMode(String mode) async {
    // mode can be: 'light', 'dark', or 'system'
    await _prefs?.setString(_themeKey, mode);
  }

  String getThemeMode() {
    return _prefs?.getString(_themeKey) ?? 'light';
  }

  bool isDarkMode() {
    return getThemeMode() == 'dark';
  }

  Future<void> toggleTheme() async {
    final currentMode = getThemeMode();
    final newMode = currentMode == 'light' ? 'dark' : 'light';
    await saveThemeMode(newMode);
  }

  // ==================== FILTER PREFERENCES ====================
  
  Future<void> saveFilterPreferences(Map<String, dynamic> filters) async {
    final filtersJson = jsonEncode(filters);
    await _prefs?.setString(_filterKey, filtersJson);
  }

  Map<String, dynamic> getFilterPreferences() {
    final filtersJson = _prefs?.getString(_filterKey);
    if (filtersJson == null || filtersJson.isEmpty) {
      return {
        'showCompleted': true,
        'difficulty': 'all', // 'all', 'easy', 'medium', 'hard'
        'category': 'all', // 'all', 'study', 'personal'
        'sortBy': 'time', // 'time', 'difficulty', 'name'
      };
    }
    return jsonDecode(filtersJson);
  }

  Future<void> updateFilter(String key, dynamic value) async {
    final filters = getFilterPreferences();
    filters[key] = value;
    await saveFilterPreferences(filters);
  }

  // ==================== NOTIFICATION SETTINGS ====================

  static const String _notificationsEnabledKey = 'notifications_enabled';

  Future<void> saveNotificationsEnabled(bool enabled) async {
    await _prefs?.setBool(_notificationsEnabledKey, enabled);
  }

  bool getNotificationsEnabled() {
    return _prefs?.getBool(_notificationsEnabledKey) ?? true;
  }

  String getLanguageCode() {
    return _prefs?.getString('language_code') ?? 'en';
  }

  // ==================== CLEAR DATA ====================
  
  Future<void> clearAll() async {
    await _prefs?.clear();
  }

  Future<void> clearTasks() async {
    await _prefs?.remove(_customTasksKey);
    await _prefs?.remove(_completedTasksKey);
  }
  
  // ==================== PERFORMANCE TRACKING ====================
  
  static const String _performanceKey = 'task_performance';
  
  Future<void> saveTaskPerformance(Map<String, dynamic> performance) async {
    final performances = getTaskPerformances();
    performances.add(performance);
    final performanceJson = jsonEncode(performances);
    await _prefs?.setString(_performanceKey, performanceJson);
  }
  
  List<Map<String, dynamic>> getTaskPerformances() {
    final performanceJson = _prefs?.getString(_performanceKey);
    if (performanceJson == null || performanceJson.isEmpty) {
      return [];
    }
    final List<dynamic> decoded = jsonDecode(performanceJson);
    return decoded.cast<Map<String, dynamic>>();
  }
  
  // Update task with actual time when completed
  Future<void> recordTaskCompletion(String taskId, int actualMinutes) async {
    final tasks = getCustomTasks();
    final taskIndex = tasks.indexWhere((t) => t['id'] == taskId);
    
    if (taskIndex != -1) {
      final task = tasks[taskIndex];
      final estimatedMinutes = (task['estimatedTime'] ?? 1) * 60;
      
      // Save performance data
      await saveTaskPerformance({
        'taskId': taskId,
        'taskName': task['name'],
        'estimatedMinutes': estimatedMinutes,
        'actualMinutes': actualMinutes,
        'difference': actualMinutes - estimatedMinutes,
        'accuracy': ((estimatedMinutes / actualMinutes) * 100).round(),
        'difficulty': task['difficulty'],
        'category': task['category'],
        'completedAt': DateTime.now().toIso8601String(),
      });
      
      // Update task with actual time
      task['actualTime'] = actualMinutes;
      task['completedAt'] = DateTime.now().toIso8601String();
      tasks[taskIndex] = task;
      await saveCustomTasks(tasks);
    }
  }
  
  // Get average accuracy for estimates
  Map<String, dynamic> getEstimateAccuracy() {
    final performances = getTaskPerformances();
    if (performances.isEmpty) {
      return {
        'averageAccuracy': 100,
        'totalTasks': 0,
        'overestimated': 0,
        'underestimated': 0,
        'accurate': 0,
      };
    }
    
    int overestimated = 0;
    int underestimated = 0;
    int accurate = 0;
    double totalAccuracy = 0;
    
    for (var perf in performances) {
      final estimated = perf['estimatedMinutes'] ?? 0;
      final actual = perf['actualMinutes'] ?? 0;
      final diff = (actual - estimated).abs();
      
      if (diff <= 15) { // Within 15 minutes
        accurate++;
      } else if (actual > estimated) {
        underestimated++;
      } else {
        overestimated++;
      }
      
      totalAccuracy += perf['accuracy'] ?? 100;
    }
    
    return {
      'averageAccuracy': (totalAccuracy / performances.length).round(),
      'totalTasks': performances.length,
      'overestimated': overestimated,
      'underestimated': underestimated,
      'accurate': accurate,
    };
  }
  
  // ==================== BREAK REMINDERS ====================
  
  static const String _breakSettingsKey = 'break_settings';
  
  Future<void> saveBreakSettings(Map<String, dynamic> settings) async {
    final settingsJson = jsonEncode(settings);
    await _prefs?.setString(_breakSettingsKey, settingsJson);
    await _touchProfileTs();
  }
  
  Map<String, dynamic> getBreakSettings() {
    const defaults = {
      'enabled': true,
      'workDuration': 50,
      'breakDuration': 10,
      'longBreakDuration': 30,
      'longBreakAfterSessions': 4,
    };
    final settingsJson = _prefs?.getString(_breakSettingsKey);
    if (settingsJson == null || settingsJson.isEmpty) return Map.of(defaults);
    try {
      final stored = jsonDecode(settingsJson) as Map<String, dynamic>;
      // Merge: stored values override defaults; missing keys fall back to defaults
      return {...defaults, ...stored};
    } catch (_) {
      return Map.of(defaults);
    }
  }
  
  // ==================== PRODUCTIVITY HOURS ====================

  static const String _productivityHoursKey = 'productivity_hours';

  Future<void> saveProductivityHours(
      List<Map<String, dynamic>> windows) async {
    await _prefs?.setString(_productivityHoursKey, jsonEncode(windows));
    await _touchProfileTs();
  }

  List<Map<String, dynamic>> getProductivityHours() {
    final raw = _prefs?.getString(_productivityHoursKey);
    if (raw == null || raw.isEmpty) {
      // Sensible defaults: 8–11 AM and 7–10 PM
      return [
        {'startHour': 8, 'endHour': 11},
        {'startHour': 19, 'endHour': 22},
      ];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  // Returns all occupied time ranges in [from, to] from all sources.
  // Each entry: {startTime, endTime, type: 'fixed'|'deadline'|'activity'}
  List<Map<String, dynamic>> getOccupiedTimeRanges(
      DateTime from, DateTime to) {
    final results = <Map<String, dynamic>>[];
    final tasks = getCustomTasks();

    for (final task in tasks) {
      final taskType = task['taskType'] as String? ?? '';

      if (taskType == 'Schedules') {
        // Recurring fixed schedule — expand occurrences within [from, to]
        final weekdays = task['weekdays'];
        final startStr = task['startTime'] as String?;
        final endStr = task['endTime'] as String?;
        if (weekdays == null || startStr == null || endStr == null) continue;

        final scheduleWeekdays = (weekdays as List).cast<int>();
        final startParts = startStr.split(':');
        final endParts = endStr.split(':');
        if (startParts.length < 2 || endParts.length < 2) continue;

        final startH = int.tryParse(startParts[0]) ?? 0;
        final startM = int.tryParse(startParts[1]) ?? 0;
        final endH = int.tryParse(endParts[0]) ?? 0;
        final endM = int.tryParse(endParts[1]) ?? 0;

        DateTime day = DateTime(from.year, from.month, from.day);
        while (!day.isAfter(to)) {
          if (scheduleWeekdays.contains(day.weekday)) {
            final s = DateTime(day.year, day.month, day.day, startH, startM);
            final e = DateTime(day.year, day.month, day.day, endH, endM);
            if (e.isAfter(s) && s.isBefore(to) && e.isAfter(from)) {
              results.add({
                'startTime': s.toIso8601String(),
                'endTime': e.toIso8601String(),
                'type': 'fixed',
              });
            }
          }
          day = day.add(const Duration(days: 1));
        }
      } else if (taskType == 'Task') {
        // Scheduled task sessions
        final sessions = task['sessions'];
        if (sessions is List) {
          for (final s in sessions) {
            if (s is! Map) continue;
            final sStart = DateTime.tryParse(s['startTime'] as String? ?? '');
            final sEnd = DateTime.tryParse(s['endTime'] as String? ?? '');
            if (sStart == null || sEnd == null) continue;
            if (sStart.isBefore(to) && sEnd.isAfter(from)) {
              results.add({
                'startTime': sStart.toIso8601String(),
                'endTime': sEnd.toIso8601String(),
                'type': 'deadline',
              });
            }
          }
        }
      } else if (taskType == 'Activity') {
        // Scheduled activity sessions
        final sessions = task['sessions'];
        if (sessions is List) {
          for (final s in sessions) {
            if (s is! Map) continue;
            final sStart = DateTime.tryParse(s['startTime'] as String? ?? '');
            final sEnd = DateTime.tryParse(s['endTime'] as String? ?? '');
            if (sStart == null || sEnd == null) continue;
            if (sStart.isBefore(to) && sEnd.isAfter(from)) {
              results.add({
                'startTime': sStart.toIso8601String(),
                'endTime': sEnd.toIso8601String(),
                'type': 'activity',
              });
            }
          }
        }
      }
    }

    return results;
  }

  // ==================== SCHEDULE CONFLICT DETECTION ====================
  
  // Check if a time slot conflicts with existing schedule
  bool hasScheduleConflict(DateTime startTime, DateTime endTime) {
    // Check conflicts with legacy generated schedule items
    final schedule = getGeneratedSchedule();
    for (var item in schedule) {
      final itemStart = DateTime.tryParse(item['startTime'] ?? '');
      final itemEnd = DateTime.tryParse(item['endTime'] ?? '');
      if (itemStart != null && itemEnd != null) {
        if (startTime.isBefore(itemEnd) && endTime.isAfter(itemStart)) {
          return true;
        }
      }
    }

    final tasks = getCustomTasks();
    for (var task in tasks) {
      // Check recurring Schedules (fixed weekday pattern, stored as HH:MM strings)
      if (task['taskType'] == 'Schedules') {
        final weekdays = task['weekdays'];
        final startTimeStr = task['startTime'];
        final endTimeStr = task['endTime'];
        if (weekdays != null && startTimeStr != null && endTimeStr != null) {
          List<int> scheduleWeekdays = [];
          if (weekdays is List) scheduleWeekdays = weekdays.cast<int>();
          if (scheduleWeekdays.contains(startTime.weekday)) {
            final startParts = startTimeStr.toString().split(':');
            final endParts = endTimeStr.toString().split(':');
            if (startParts.length == 2 && endParts.length == 2) {
              final scheduleStart = DateTime(startTime.year, startTime.month, startTime.day,
                  int.parse(startParts[0]), int.parse(startParts[1]));
              final scheduleEnd = DateTime(startTime.year, startTime.month, startTime.day,
                  int.parse(endParts[0]), int.parse(endParts[1]));
              if (startTime.isBefore(scheduleEnd) && endTime.isAfter(scheduleStart)) {
                return true;
              }
            }
          }
        }
      }

      // Check all sessions in Task and Activity items (both store ISO8601 startTime/endTime)
      final sessions = task['sessions'];
      if (sessions is List) {
        for (final s in sessions) {
          if (s is! Map) continue;
          final sessionStart = DateTime.tryParse(s['startTime'] as String? ?? '');
          final sessionEnd = DateTime.tryParse(s['endTime'] as String? ?? '');
          if (sessionStart != null && sessionEnd != null) {
            if (startTime.isBefore(sessionEnd) && endTime.isAfter(sessionStart)) {
              return true;
            }
          }
        }
      }
    }

    return false;
  }
  
  // Find next available time slot
  DateTime? findNextAvailableSlot(int durationMinutes, DateTime afterTime) {
    final schedule = getGeneratedSchedule();
    DateTime checkTime = afterTime;
    
    // Make sure we start from current time if afterTime is in the past
    final now = DateTime.now();
    if (checkTime.isBefore(now)) {
      checkTime = now;
    }
    
    // Try next 7 days
    for (int day = 0; day < 7; day++) {
      final checkDay = DateTime(
        checkTime.year,
        checkTime.month,
        checkTime.day + day,
      );
      
      // Define available time slots (avoid regular work hours 8AM-5PM on weekdays)
      List<int> availableHours;
      final isWeekday = checkDay.weekday >= 1 && checkDay.weekday <= 5;
      
      if (isWeekday) {
        // Weekday: Early morning (6-8) or Evening (18-22)
        availableHours = [6, 7, 18, 19, 20, 21, 22];
      } else {
        // Weekend: More flexible (8-22)
        availableHours = [8, 9, 10, 11, 14, 15, 16, 17, 18, 19, 20, 21, 22];
      }
      
      // Try each available hour
      for (int hour in availableHours) {
        final slotStart = DateTime(
          checkDay.year,
          checkDay.month,
          checkDay.day,
          hour,
          0,
        );
        
        // Skip if before the requested search boundary.
        if (slotStart.isBefore(checkTime)) continue;
        
        final slotEnd = slotStart.add(Duration(minutes: durationMinutes));
        
        // Check if end time is reasonable (before 11 PM)
        if (slotEnd.hour >= 23) continue;
        
        // Check conflicts
        if (!hasScheduleConflict(slotStart, slotEnd)) {
          return slotStart;
        }
      }
    }
    
    return null; // No available slot found
  }
  
  // Get schedule for a specific day
  List<Map<String, dynamic>> getScheduleForDay(DateTime day) {
    final schedule = getGeneratedSchedule();
    return schedule.where((item) {
      final itemStart = DateTime.tryParse(item['startTime'] ?? '');
      if (itemStart == null) return false;

      return itemStart.year == day.year &&
             itemStart.month == day.month &&
             itemStart.day == day.day;
    }).toList();
  }

  // ─── Chat Planner Persistence ────────────────────────────────────────────

  static const String _chatHistoryKey = 'chat_history';
  static const String _chatContextKey = 'chat_context';
  static const int _maxChatMessages = 100;

  Future<void> saveChatHistory(List<Map<String, dynamic>> messages) async {
    final toSave = messages.length > _maxChatMessages
        ? messages.sublist(messages.length - _maxChatMessages)
        : messages;
    await _prefs?.setString(_chatHistoryKey, jsonEncode(toSave));
  }

  List<Map<String, dynamic>> loadChatHistory() {
    final raw = _prefs?.getString(_chatHistoryKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveConversationContext(Map<String, dynamic> context) async {
    await _prefs?.setString(_chatContextKey, jsonEncode(context));
  }

  Map<String, dynamic>? loadConversationContext() {
    final raw = _prefs?.getString(_chatContextKey);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearChatHistory() async {
    await _prefs?.remove(_chatHistoryKey);
    await _prefs?.remove(_chatContextKey);
  }

  // ─── Profile field saves (with timestamp) ────────────────────────────────────

  Future<void> saveUserNameWithSync(String name) async {
    await saveUserName(name);
    await _touchProfileTs();
  }

  Future<void> saveUserBioWithSync(String bio) async {
    await saveUserBio(bio);
    await _touchProfileTs();
  }

  Future<void> saveUserPhoneWithSync(String phone) async {
    await saveUserPhone(phone);
    await _touchProfileTs();
  }

  Future<void> saveUserPhotoUrlWithSync(String photoUrl) async {
    await saveUserPhotoUrl(photoUrl);
    await _touchProfileTs();
  }

  // ─── Sync helpers ─────────────────────────────────────────────────────────────

  Future<void> _touchProfileTs() async {
    await _prefs?.setString(
        'profile_updatedAt', DateTime.now().toUtc().toIso8601String());
  }

  Future<void> _syncOrQueueStatus(String taskId, String status) async {
    final online = await ConnectivityService().isOnline();
    if (online) {
      await FirestoreService().updateTaskFields(taskId, {'status': status});
    } else {
      await SyncQueueService().enqueueUpdateStatus(taskId: taskId, status: status);
    }
  }

  Future<void> _syncOrQueueCompleteSession({
    required String taskId,
    required int sessionIndex,
    required bool isCompleted,
  }) async {
    final online = await ConnectivityService().isOnline();
    if (online) {
      await FirestoreService()
          .updateSessionCompleted(taskId, sessionIndex, isCompleted);
    } else {
      await SyncQueueService().enqueueCompleteSession(
          taskId: taskId, sessionIndex: sessionIndex, isCompleted: isCompleted);
    }
  }

  Future<void> _syncOrQueueDeleteTask(String taskId) async {
    final online = await ConnectivityService().isOnline();
    if (online) {
      await FirestoreService().deleteTask(taskId);
    } else {
      await SyncQueueService().enqueueDeleteTask(taskId);
    }
  }

  Future<void> _syncOrQueueDeleteSession({
    required String taskId,
    required int sessionIndex,
  }) async {
    final online = await ConnectivityService().isOnline();
    if (online) {
      final tasks = getCustomTasks();
      final task = tasks.firstWhere(
        (t) => t['id']?.toString() == taskId,
        orElse: () => {},
      );
      if (task.isNotEmpty) await FirestoreService().pushTask(task);
    } else {
      await SyncQueueService().enqueueDeleteSession(
          taskId: taskId, sessionIndex: sessionIndex);
    }
  }

  // ─── Account identity ─────────────────────────────────────────────────────

  String? getLastUid() => _prefs?.getString('last_uid');

  Future<void> saveLastUid(String uid) async {
    await _prefs?.setString('last_uid', uid);
  }

  Future<void> clearAccountData() async {
    final keysToRemove = [
      _userNameKey,
      _userEmailKey,
      _userPhotoUrlKey,
      _userPhoneKey,
      _userBioKey,
      _customTasksKey,
      _customTasksUpdatedAtKey,
      _scheduleKey,
      _tasksKey,
      _completedTasksKey,
      _inProgressTasksKey,
      _chatHistoryKey,
      _chatContextKey,
      'last_uid',
      'profile_updatedAt',
      'productivity_hours',
      'break_settings',
      'user_profile',
    ];
    for (final key in keysToRemove) {
      await _prefs?.remove(key);
    }
  }

  Future<void> pushProfileToFirestore() async {
    final data = <String, dynamic>{
      'name': _prefs?.getString(_userNameKey) ?? '',
      'email': _prefs?.getString(_userEmailKey) ?? '',
      'photoUrl': _prefs?.getString(_userPhotoUrlKey) ?? '',
      'phone': _prefs?.getString(_userPhoneKey) ?? '',
      'bio': _prefs?.getString(_userBioKey) ?? '',
      'productivityHours': _prefs?.getString('productivity_hours') ?? '[]',
      'breakSettings': _prefs?.getString('break_settings') ?? '{}',
      'userProfile': _prefs?.getString('user_profile') ?? '{}',
    };
    await FirestoreService().pushProfile(data);
  }
}
