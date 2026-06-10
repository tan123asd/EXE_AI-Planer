import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'storage_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelSession = AndroidNotificationChannel(
    'task_reminders',
    'Task Reminders',
    description: 'Reminds you 1 hour before each task session',
    importance: Importance.high,
  );

  static const _channelOverdue = AndroidNotificationChannel(
    'overdue_tasks',
    'Overdue Tasks',
    description: 'Alerts for tasks past their deadline',
    importance: Importance.high,
  );

  bool get enabled => StorageService().getNotificationsEnabled();

  Future<void> init() async {
    tz_data.initializeTimeZones();
    try {
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz));
    } catch (_) {
      // Falls back to UTC if timezone cannot be determined — notifications
      // will still fire, just at UTC-offset time.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(initSettings);

    // Create notification channels on Android
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channelSession);
    await androidPlugin?.createNotificationChannel(_channelOverdue);
    try {
      await androidPlugin?.requestNotificationsPermission();
    } catch (_) {
      // Permission request may fail in some environments; non-fatal.
    }
  }

  Future<void> setEnabled(bool value) async {
    await StorageService().saveNotificationsEnabled(value);
    if (value) {
      await scheduleAllNotifications();
    } else {
      await _plugin.cancelAll();
    }
  }

  /// Returns upcoming reminder times (for display in NotificationsScreen).
  List<UpcomingReminder> getUpcomingReminders() {
    final tasks = StorageService().getCustomTasks();
    final now = DateTime.now();
    final reminders = <UpcomingReminder>[];

    for (final task in tasks) {
      final taskType = task['taskType'] as String? ?? 'Task';
      if (taskType == 'Schedule') continue;

      final isCompleted = task['isCompleted'] as bool? ?? false;
      if (isCompleted) continue;

      final taskName = task['name'] as String? ?? '';
      final sessions = task['sessions'] as List<dynamic>? ?? [];

      for (final s in sessions) {
        final session = s as Map<String, dynamic>;
        final sessionCompleted = session['isCompleted'] as bool? ?? false;
        if (sessionCompleted) continue;

        final startTimeStr = session['startTime'] as String?;
        if (startTimeStr == null) continue;
        final startTime = DateTime.tryParse(startTimeStr);
        if (startTime == null) continue;

        final reminderTime = startTime.subtract(const Duration(hours: 1));
        if (reminderTime.isBefore(now)) continue;

        final sessionName = session['taskName'] as String? ?? taskName;
        reminders.add(UpcomingReminder(
          taskName: sessionName,
          reminderAt: reminderTime,
          sessionAt: startTime,
        ));
      }
    }

    reminders.sort((a, b) => a.reminderAt.compareTo(b.reminderAt));
    return reminders.take(20).toList();
  }

  Future<void> scheduleAllNotifications() async {
    if (!enabled) return;
    try {
    await _plugin.cancelAll();

    final tasks = StorageService().getCustomTasks();
    final now = DateTime.now();
    final isVi = StorageService().getLanguageCode() == 'vi';
    int notifId = 1;

    final List<String> overdueNames = [];

    for (final task in tasks) {
      final taskType = task['taskType'] as String? ?? 'Task';
      if (taskType == 'Schedule') continue;

      final isCompleted = task['isCompleted'] as bool? ?? false;
      final taskName = task['name'] as String? ?? '';
      final sessions = task['sessions'] as List<dynamic>? ?? [];

      // Check overdue (deadline passed, task not completed)
      final deadlineStr = task['deadline'] as String?;
      if (deadlineStr != null && !isCompleted) {
        final deadline = DateTime.tryParse(deadlineStr);
        if (deadline != null && deadline.isBefore(now)) {
          overdueNames.add(taskName);
        }
      }

      // Schedule 1-hour-before reminders for each upcoming session
      for (final s in sessions) {
        final session = s as Map<String, dynamic>;
        final sessionCompleted = session['isCompleted'] as bool? ?? false;
        if (sessionCompleted) continue;

        final startTimeStr = session['startTime'] as String?;
        if (startTimeStr == null) continue;
        final startTime = DateTime.tryParse(startTimeStr);
        if (startTime == null) continue;

        final reminderTime = startTime.subtract(const Duration(hours: 1));
        if (reminderTime.isBefore(now)) continue;

        final sessionName = session['taskName'] as String? ?? taskName;
        final title = isVi ? '⏰ Nhắc nhở' : '⏰ Reminder';
        final body = isVi
            ? 'Còn 1 tiếng: $sessionName'
            : '1 hour until: $sessionName';

        await _scheduleNotification(
          id: notifId++,
          title: title,
          body: body,
          scheduledDate: reminderTime,
          channelId: _channelSession.id,
          channelName: _channelSession.name,
        );

        if (notifId > 50) break;
      }
      if (notifId > 50) break;
    }

    // Show overdue notification immediately if any
    if (overdueNames.isNotEmpty) {
      final names = overdueNames.length > 3
          ? '${overdueNames.take(3).join(', ')}...'
          : overdueNames.join(', ');
      final title = isVi ? '⚠️ Task chưa hoàn thành' : '⚠️ Overdue Tasks';
      final body = isVi
          ? 'Quá hạn: $names'
          : 'Overdue: $names';

      await _plugin.show(
        99998,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelOverdue.id,
            _channelOverdue.name,
            channelDescription: _channelOverdue.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    }
    } catch (_) {
      // Notification scheduling failure must not crash the app.
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String channelId,
    required String channelName,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}

class UpcomingReminder {
  final String taskName;
  final DateTime reminderAt;
  final DateTime sessionAt;

  const UpcomingReminder({
    required this.taskName,
    required this.reminderAt,
    required this.sessionAt,
  });
}
