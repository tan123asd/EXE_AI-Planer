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
}
