import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  static const String _tasksKey = 'tasks';
  static const String _completedTasksKey = 'completed_tasks';
  static const String _inProgressTasksKey = 'in_progress_tasks';
  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';
  static const String _userPhoneKey = 'user_phone';
  static const String _userBioKey = 'user_bio';
  static const String _customTasksKey = 'custom_tasks';
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
    return _prefs?.getString(_userNameKey) ?? 'Tan';
  }

  Future<void> saveUserEmail(String email) async {
    await _prefs?.setString(_userEmailKey, email);
  }

  String getUserEmail() {
    return _prefs?.getString(_userEmailKey) ?? '';
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
  }

  Future<void> deleteCustomTask(String taskId) async {
    final tasks = getCustomTasks();
    tasks.removeWhere((task) => task['id'] == taskId);
    await saveCustomTasks(tasks);
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
  }
  
  Map<String, dynamic> getBreakSettings() {
    final settingsJson = _prefs?.getString(_breakSettingsKey);
    if (settingsJson == null || settingsJson.isEmpty) {
      return {
        'enabled': true,
        'workDuration': 50, // minutes
        'breakDuration': 10, // minutes
        'longBreakDuration': 30, // minutes
        'longBreakAfterSessions': 4, // number of sessions
      };
    }
    return jsonDecode(settingsJson);
  }
  
  // ==================== SCHEDULE CONFLICT DETECTION ====================
  
  // Check if a time slot conflicts with existing schedule
  bool hasScheduleConflict(DateTime startTime, DateTime endTime) {
    // Check conflicts with existing schedule items
    final schedule = getGeneratedSchedule();
    
    for (var item in schedule) {
      final itemStart = DateTime.tryParse(item['startTime'] ?? '');
      final itemEnd = DateTime.tryParse(item['endTime'] ?? '');
      
      if (itemStart != null && itemEnd != null) {
        // Check overlap
        if (startTime.isBefore(itemEnd) && endTime.isAfter(itemStart)) {
          return true;
        }
      }
    }
    
    // 🔧 Check conflicts with recurring Schedules (fixed time slots)
    final tasks = getCustomTasks();
    
    for (var task in tasks) {
      // 🔧 NEW: Check recurring schedules (fixed time slots only)
      if (task['taskType'] == 'Schedules') {
        final weekdays = task['weekdays'];
        final startTimeStr = task['startTime'];
        final endTimeStr = task['endTime'];
        
        if (weekdays != null && startTimeStr != null && endTimeStr != null) {
          List<int> scheduleWeekdays = [];
          if (weekdays is List) {
            scheduleWeekdays = weekdays.cast<int>();
          }
          
          // Check if proposed time falls on one of the recurring days
          if (scheduleWeekdays.contains(startTime.weekday)) {
            // Parse schedule time (format: "HH:MM")
            final startParts = startTimeStr.toString().split(':');
            final endParts = endTimeStr.toString().split(':');
            
            if (startParts.length == 2 && endParts.length == 2) {
              final scheduleStart = DateTime(
                startTime.year,
                startTime.month,
                startTime.day,
                int.parse(startParts[0]),
                int.parse(startParts[1]),
              );
              
              final scheduleEnd = DateTime(
                startTime.year,
                startTime.month,
                startTime.day,
                int.parse(endParts[0]),
                int.parse(endParts[1]),
              );
              
              // Check time overlap on that day
              if (startTime.isBefore(scheduleEnd) && endTime.isAfter(scheduleStart)) {
                return true; // Conflicts with recurring schedule
              }
            }
          }
        }
      }
      
      // 🔧 Check conflicts with Task type (with deadline)
      if (task['taskType'] == 'Task' && task['deadline'] != null) {
        final taskDeadline = DateTime.tryParse(task['deadline']);
        
        if (taskDeadline != null) {
          // Get estimated time (stored as int hours or as string)
          int durationMinutes = 60; // Default 1 hour
          
          if (task['estimatedTime'] != null) {
            if (task['estimatedTime'] is int) {
              durationMinutes = (task['estimatedTime'] as int) * 60;
            } else if (task['estimatedTime'] is String) {
              final estimatedTime = task['estimatedTime'] as String;
              if (estimatedTime.contains('30 min')) {
                durationMinutes = 60;
              } else if (estimatedTime.contains('1 hour')) {
                durationMinutes = 60;
              } else if (estimatedTime.contains('2 hours')) {
                durationMinutes = 120;
              } else if (estimatedTime.contains('3 hours')) {
                durationMinutes = 180;
              } else if (estimatedTime.contains('4 hours')) {
                durationMinutes = 240;
              } else if (estimatedTime.contains('5+ hours')) {
                durationMinutes = 300;
              }
            }
          }
          
          // 🔧 Check if task has specific time or just date
          if (taskDeadline.hour != 0 || taskDeadline.minute != 0) {
            // Task has specific time - deadline is the START time
            final taskStart = taskDeadline;
            final taskEnd = taskDeadline.add(Duration(minutes: durationMinutes));
            
            // Check overlap
            if (startTime.isBefore(taskEnd) && endTime.isAfter(taskStart)) {
              return true;
            }
          }
          // If task only has date (00:00), we don't know exact time, skip conflict check
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
}
