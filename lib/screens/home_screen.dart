import 'package:flutter/material.dart';
import 'package:ai_study_planner/l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../utils/constants.dart';
import '../widgets/stats_card.dart';
import '../widgets/timeline_item.dart';
import '../providers/streak_provider.dart';
import 'package:provider/provider.dart';

import '../widgets/priority_task_card.dart';


import '../widgets/status_task_card.dart';
import '../widgets/performance_tracking_card.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../widgets/upgrade_dialog.dart';
import 'new_task_input_screen.dart';
import 'tasks_screen.dart';
import 'calendar_screen.dart';
import 'profile_screen.dart';
import 'chat_planner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _calendarVersion = 0;
  final StorageService _storage = StorageService();
  
  // Current tasks to display
  List<Map<String, dynamic>> _todayTasks = [];
  List<Map<String, dynamic>> _subjectBreakdown = [];
  String _greetingName = '';

  int _completedTasksCount = 0;
  int _plannedTaskUnitsCount = 0;

  bool _isRecurringType(Map<String, dynamic> task) {
    final type = (task['taskType'] ?? '').toString();
    return type == 'Schedules' || type == 'Activity';
  }

  @override
  void initState() {
    super.initState();
    // Auth navigation is handled by _AuthGate in main.dart.
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Load streak once the provider/context is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StreakProvider>().loadStreak(uid);
    });
  }


  void _loadData() {
    // Ensure the user's name is cached in storage for the profile screen.
    if (_storage.getUserName().isEmpty) {
      final fbUser = FirebaseAuth.instance.currentUser;
      final name = fbUser?.displayName?.trim().isNotEmpty == true
          ? fbUser!.displayName!.trim()
          : (fbUser?.email?.split('@').first ?? '');
      if (name.isNotEmpty) _storage.saveUserName(name);
    }

    setState(() {
      // Load custom tasks from storage
      final allTasks = _storage.getCustomTasks();
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      
      // 🆕 Filter tasks for today
      _todayTasks = allTasks.where((task) {
        // Schedules are shown in Calendar only
        if ((task['taskType'] ?? '') == 'Schedules') return false;

        // Activity: check if today's weekday is in the weekdays list
        if (_isRecurringType(task)) {
          final weekdays = task['weekdays'];
          if (weekdays == null || weekdays is! List) return false;
          
          // Check if today's weekday matches
          if (!weekdays.contains(today.weekday)) return false;
          
          // 🆕 Check if schedule has ended (endDate check)
          final scheduleEndDate = task['scheduleEndDate'];
          if (scheduleEndDate != null) {
            try {
              final endDate = DateTime.parse(scheduleEndDate);
              final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);
              // If today is after end date, don't show this schedule
              if (todayDate.isAfter(endDateOnly)) {
                return false;
              }
            } catch (e) {
              // If parsing fails, assume no end date
            }
          }
          
          return true;
        }
        
        // Task: check if has session today OR deadline is today
        if (task['taskType'] == 'Task') {
          // Check sessions first
          final sessions = task['sessions'];
          if (sessions != null && sessions is List) {
            // Has sessions - check if any session is today
            return sessions.any((session) {
              try {
                final sessionStart = DateTime.parse(session['startTime']);
                final sessionDate = DateTime(sessionStart.year, sessionStart.month, sessionStart.day);
                return sessionDate.isAtSameMomentAs(todayDate);
              } catch (e) {
                return false;
              }
            });
          }
          
          // No sessions - check deadline
          final deadline = task['deadline'];
          if (deadline != null) {
            try {
              final deadlineDate = DateTime.parse(deadline);
              final deadlineDateOnly = DateTime(deadlineDate.year, deadlineDate.month, deadlineDate.day);
              return deadlineDateOnly.isAtSameMomentAs(todayDate);
            } catch (e) {
              return false;
            }
          }
        }
        
        return false;
      }).toList();
      
      // Count completed tasks
      _plannedTaskUnitsCount = _todayTasks.fold<int>(0, (sum, task) {
        return sum + _getTaskPlanUnits(task);
      });

      _completedTasksCount = _todayTasks.fold<int>(0, (sum, task) {
        return sum + _getCompletedTaskUnits(task);
      });

      // Cache subject breakdown — avoids recomputing on every build()
      _subjectBreakdown = _getSubjectBreakdown();

      // Cache greeting name — avoids reading SharedPreferences on every build()
      final storedName = _storage.getUserName().trim();
      if (storedName.isNotEmpty) {
        _greetingName = storedName;
      } else {
        final fbUser = FirebaseAuth.instance.currentUser;
        final fbName = fbUser?.displayName?.trim().isNotEmpty == true
            ? fbUser!.displayName!.trim()
            : (fbUser?.email?.split('@').first ?? '');
        _greetingName = fbName.isEmpty ? 'Student' : fbName;
      }
    });
  }

  void _handleTaskStatusChange(String taskId, TaskStatus newStatus) async {
    // If this is a session item, it has composite id: "<taskId>::<sessionIndex>"
    if (taskId.contains('::')) {
      final parts = taskId.split('::');
      if (parts.length == 2) {
        final parentId = parts[0];
        final sessionIndex = int.tryParse(parts[1]);
        if (sessionIndex != null) {
          await _storage.setTaskSessionCompleted(
            parentId,
            sessionIndex: sessionIndex,
            isCompleted: newStatus == TaskStatus.completed,
          );

          // Evaluate streak right after a completion toggle.
          // Use UI units: scheduledTotal = planned units for today, completedTotal = completed units for today.
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null && newStatus == TaskStatus.completed) {
            final now = DateTime.now();
            final dayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
            final prev = now.subtract(const Duration(days: 1));
            final previousDayKey = '${prev.year}-${prev.month.toString().padLeft(2, '0')}-${prev.day.toString().padLeft(2, '0')}';

            // Recompute counts from latest storage state for accuracy.
            final allTasks = _storage.getCustomTasks();
            final today = DateTime.now();
            final todayDate = DateTime(today.year, today.month, today.day);
            final todayTasks = allTasks.where((task) {
              if ((task['taskType'] ?? '') == 'Schedules') return false;

              if (_isRecurringType(task)) {
                final weekdays = task['weekdays'];
                if (weekdays == null || weekdays is! List) return false;
                if (!weekdays.contains(today.weekday)) return false;

                final scheduleEndDate = task['scheduleEndDate'];
                if (scheduleEndDate != null) {
                  try {
                    final endDate = DateTime.parse(scheduleEndDate);
                    final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);
                    if (todayDate.isAfter(endDateOnly)) return false;
                  } catch (_) {}
                }

                return true;
              }

              if (task['taskType'] == 'Task') {
                final sessions = task['sessions'];
                if (sessions != null && sessions is List) {
                  return sessions.any((session) {
                    try {
                      final sessionStart = DateTime.parse(session['startTime']);
                      final sessionDate = DateTime(sessionStart.year, sessionStart.month, sessionStart.day);
                      return sessionDate.isAtSameMomentAs(todayDate);
                    } catch (_) {
                      return false;
                    }
                  });
                }

                final deadline = task['deadline'];
                if (deadline != null) {
                  try {
                    final deadlineDate = DateTime.parse(deadline);
                    final deadlineDateOnly = DateTime(deadlineDate.year, deadlineDate.month, deadlineDate.day);
                    return deadlineDateOnly.isAtSameMomentAs(todayDate);
                  } catch (_) {
                    return false;
                  }
                }
              }

              return false;
            }).toList();

            final plannedUnits = todayTasks.fold<int>(0, (sum, t) => sum + _getTaskPlanUnits(t));
            final completedUnits = todayTasks.fold<int>(0, (sum, t) => sum + _getCompletedTaskUnits(t));

            await context.read<StreakProvider>().evaluateDayAndUpdateStreak(
              dayKey: dayKey,
              previousDayKey: previousDayKey,
              scheduledTotal: plannedUnits,
              completedTotal: completedUnits,
            );
          }

          _loadData();
          return;
        }
      }
    }

    String statusString = 'pending';
    if (newStatus == TaskStatus.completed) {
      statusString = 'completed';
    } else if (newStatus == TaskStatus.inProgress) {
      statusString = 'inProgress';
    }

    await _storage.updateTaskStatus(taskId, statusString);
    _loadData();
  }


  TaskStatus _getTaskStatus(String taskId) {
    if (taskId.contains('::')) {
      final parts = taskId.split('::');
      if (parts.length == 2) {
        final parentId = parts[0];
        final sessionIndex = int.tryParse(parts[1]);
        if (sessionIndex != null) {
          final tasks = _storage.getCustomTasks();
          final t = tasks.firstWhere(
            (m) => (m['id'] ?? '').toString() == parentId,
            orElse: () => <String, dynamic>{},
          );
          final sessions = t['sessions'];
          if (sessions is List &&
              sessionIndex >= 0 &&
              sessionIndex < sessions.length) {
            final s = sessions[sessionIndex];
            if (s is Map && s['isCompleted'] == true) {
              return TaskStatus.completed;
            }
          }
          return TaskStatus.pending;
        }
      }
    }

    if (_storage.isTaskCompleted(taskId)) {
      return TaskStatus.completed;
    } else if (_storage.isTaskInProgress(taskId)) {
      return TaskStatus.inProgress;
    }
    return TaskStatus.pending;
  }

  void _refreshData() {
    _loadData();
  }

  String _formatTime(int estimatedHours) {
    // Simple time formatting
    final hour = 9 + (estimatedHours * 2);
    final formattedHour = hour > 12 ? hour - 12 : hour;
    return '$formattedHour:00 ${hour < 12 ? 'AM' : 'PM'}';
  }

  // 🔧 FIXED: Format time range from actual deadline or schedule times
  String _formatTimeRange(Map<String, dynamic> task) {
    // 🔧 For Schedules type - use fixed start/end time
    if (_isRecurringType(task)) {
      final type = (task['taskType'] ?? '').toString();
      if (type == 'Activity') {
        // If Activity has concrete sessions, show today's sessions time range(s)
        final sessions = task['sessions'];
        if (sessions is List && sessions.isNotEmpty) {
          final today = DateTime.now();
          final todayDate = DateTime(today.year, today.month, today.day);
          final todayRanges = <String>[];
          for (final session in sessions) {
            if (session is! Map) continue;
            try {
              final st = DateTime.parse((session['startTime'] ?? '').toString());
              final en = DateTime.parse((session['endTime'] ?? '').toString());
              final sd = DateTime(st.year, st.month, st.day);
              if (!sd.isAtSameMomentAs(todayDate)) continue;
              todayRanges.add(
                '${_formatTimeWith24H(st)} - ${_formatTimeWith24H(en, isRangeEnd: true)}',
              );
            } catch (_) {
              // ignore bad session parse
            }
          }
          if (todayRanges.isNotEmpty) {
            if (todayRanges.length == 1) return todayRanges.first;
            return '${todayRanges.length} sessions\n${todayRanges.join('\n')}';
          }
        }

        final est = task['estimatedMinutes'];
        int? minutes;
        if (est is int && est > 0) {
          minutes = est;
        } else if (est is num && est > 0) {
          minutes = est.round();
        }
        if (minutes != null) {
          final hours = minutes ~/ 60;
          final remain = minutes % 60;
          if (hours == 0) {
            return '${remain} min';
          }
          if (remain == 0) {
            return '${hours} h';
          }
          return '${hours} h ${remain} min';
        }
      }

      final startTime = task['startTime'];
      final endTime = task['endTime'];
      
      if (startTime != null && endTime != null) {
        // Parse "HH:MM" strings and format to 24h display.
        return '${_formatTimeStringTo24H(startTime)} - ${_formatTimeStringTo24H(endTime, isRangeEnd: true)}';
      }
    }
    
    // 🔧 For Task type - check sessions first, then deadline
    if (task['taskType'] == 'Task') {
      final sessions = task['sessions'];
      
      // 🆕 If task has sessions, list today's sessions (not just the first one)
      if (sessions != null && sessions is List && sessions.isNotEmpty) {
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        final todayRanges = <String>[];
        for (var session in sessions) {
          try {
            final sessionStart = DateTime.parse(session['startTime']);
            final sessionEnd = DateTime.parse(session['endTime']);
            final sessionDate = DateTime(sessionStart.year, sessionStart.month, sessionStart.day);
            
            if (sessionDate.isAtSameMomentAs(todayDate)) {
              todayRanges.add(
                '${_formatTimeWith24H(sessionStart)} - ${_formatTimeWith24H(sessionEnd, isRangeEnd: true)}',
              );
            }
          } catch (e) {
            // Continue to next session
          }
        }

        if (todayRanges.isNotEmpty) {
          if (todayRanges.length == 1) return todayRanges.first;
          return '${todayRanges.length} sessions\n${todayRanges.join('\n')}';
        }
      }
      
      // 🔧 Fallback: use deadline if no sessions
      final estimatedHours = task['estimatedTime'] as int? ?? 1;
      final durationMinutes = estimatedHours * 60;
      
      // Try to get actual deadline with time
      DateTime? taskStartTime;
      if (task['deadline'] != null) {
        try {
          taskStartTime = DateTime.parse(task['deadline']);
        } catch (e) {
          taskStartTime = null;
        }
      }
      
      // If task has specific time (not midnight), use it
      if (taskStartTime != null && (taskStartTime.hour != 0 || taskStartTime.minute != 0)) {
        final endTime = taskStartTime.add(Duration(minutes: durationMinutes));
        return '${_formatTimeWith24H(taskStartTime)} - ${_formatTimeWith24H(endTime, isRangeEnd: true)}';
      }
      
      // Otherwise, use default scheduling (9 AM start + index offset)
      final taskIndex = _todayTasks.indexOf(task);
      final startHour = 9 + (taskIndex * 2);
      final endHour = startHour + estimatedHours;
      
      final startTime = DateTime(2026, 1, 1, startHour, 0);
      final endTime = DateTime(2026, 1, 1, endHour, 0);
      
      return '${_formatTimeWith24H(startTime)} - ${_formatTimeWith24H(endTime, isRangeEnd: true)}';
    }
    
    // Default fallback
    return '09:00 - 10:00';
  }
  
  // 24h formatter. If range ends at midnight, show 24:00 for easier day planning.
  String _formatTimeWith24H(DateTime time, {bool isRangeEnd = false}) {
    if (isRangeEnd && time.hour == 0 && time.minute == 0) {
      return '24:00';
    }

    final hour = time.hour;
    final minute = time.minute;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
  
  // Parse "HH:MM" and keep 24h display. End of day can be displayed as 24:00.
  String _formatTimeStringTo24H(String timeString, {bool isRangeEnd = false}) {
    try {
      final parts = timeString.split(':');
      if (parts.length != 2) return timeString;
      
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      if (isRangeEnd && hour == 0 && minute == 0) {
        return '24:00';
      }

      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timeString; // Return original if parsing fails
    }
  }

  String? _formatDeadlineLabel(Map<String, dynamic> task) {
    if ((task['taskType'] ?? '').toString() != 'Task') {
      return null;
    }

    final rawDeadline = task['deadline'];
    if (rawDeadline == null) {
      return null;
    }

    final deadline = DateTime.tryParse(rawDeadline.toString());
    if (deadline == null) {
      return null;
    }

    if (deadline.hour == 0 && deadline.minute == 0) {
      return DateFormat('dd/MM').format(deadline);
    }

    return DateFormat('dd/MM • HH:mm').format(deadline);
  }

  Color _getTimelineColor(int index) {
    final colors = [
      AppColors.timelineBlue,
      AppColors.timelinePeach,
      AppColors.timelineGreen,
      AppColors.timelinePurple,
      AppColors.timelinePink,
    ];
    return colors[index % colors.length];
  }

  int _getGreetingTime() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 0;
    if (hour < 17) return 1;
    return 2;
  }

  String _getGreeting(AppLocalizations l10n) {
    final greetings = [l10n.greetingMorning, l10n.greetingAfternoon, l10n.greetingEvening];
    return greetings[_getGreetingTime()];
  }

  String _getGreetingName() => _greetingName.isEmpty ? 'Student' : _greetingName;

  bool _isTaskUnitTracked(Map<String, dynamic> task) {
    return (task['taskType'] ?? '').toString() == 'Task';
  }

  int _getTaskPlanUnits(Map<String, dynamic> task) {
    if (!_isTaskUnitTracked(task)) {
      return 0;
    }

    final sessions = task['sessions'];
    if (sessions is List && sessions.isNotEmpty) {
      return sessions.whereType<Map>().where((session) => _isSessionToday(session)).length;
    }

    return 1;
  }

  int _getCompletedTaskUnits(Map<String, dynamic> task) {
    if (!_isTaskUnitTracked(task)) {
      return 0;
    }

    final sessions = task['sessions'];
    if (sessions is List && sessions.isNotEmpty) {
      return sessions
          .whereType<Map>()
          .where((session) => _isSessionToday(session) && session['isCompleted'] == true)
          .length;
    }

    return _storage.isTaskCompleted(task['id'] ?? '') ? 1 : 0;
  }

  bool _isSessionToday(Map session) {
    try {
      final startTime = DateTime.parse((session['startTime'] ?? '').toString());
      final now = DateTime.now();
      return startTime.year == now.year &&
          startTime.month == now.month &&
          startTime.day == now.day;
    } catch (_) {
      return false;
    }
  }

  String _mapDifficultyToPriority(String difficulty) {
    switch (difficulty) {
      case 'Hard':
        return 'High';
      case 'Medium':
        return 'Medium';
      case 'Easy':
        return 'Low';
      default:
        return 'Medium';
    }
  }

  // 🆕 Format weekdays for display
  String _formatWeekdays(dynamic weekdays, AppLocalizations l10n) {
    if (weekdays == null) return l10n.notSet;
    
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    List<int> daysList = [];
    
    if (weekdays is List) {
      daysList = weekdays.cast<int>();
    }
    
    if (daysList.isEmpty) return l10n.notSet;
    
    daysList.sort();
    return daysList.map((d) => days[d - 1]).join(', ');
  }

  String _formatScheduleSubtitle(Map<String, dynamic> schedule, AppLocalizations l10n) {
    String weekdaysStr = _formatWeekdays(schedule['weekdays'], l10n);

    final scheduleEndDate = schedule['scheduleEndDate'];
    if (scheduleEndDate != null) {
      try {
        final endDate = DateTime.parse(scheduleEndDate);
        final formattedDate = DateFormat('MMM d, y').format(endDate);
        return '$weekdaysStr • ${l10n.until} $formattedDate';
      } catch (e) {
        return weekdaysStr;
      }
    }

    return weekdaysStr;
  }

  String _getSubjectLabel(Map<String, dynamic> task) {
    final category = task['category'];
    if (category is String && category.trim().isNotEmpty) {
      return category;
    }

    final subject = task['subject'];
    if (subject is String && subject.trim().isNotEmpty) {
      return subject;
    }

    return 'Other';
  }

  Color _getSubjectColor(Map<String, dynamic> task) {
    final category = task['category'];
    if (category is String && category.trim().isNotEmpty) {
      return AppColors.subjectAccentColor(category);
    }
    return AppColors.subjectAccentColor(_getSubjectLabel(task));
  }

  int _getTaskMinutes(Map<String, dynamic> task) {
    if (_isRecurringType(task)) {
      if ((task['taskType'] ?? '').toString() == 'Activity') {
        final est = task['estimatedMinutes'];
        if (est is int && est > 0) return est;
        if (est is num && est > 0) return est.round();
      }

      final start = task['startTime'];
      final end = task['endTime'];
      if (start is String && end is String) {
        try {
          final startParts = start.split(':');
          final endParts = end.split(':');
          if (startParts.length == 2 && endParts.length == 2) {
            final startMinutes = (int.parse(startParts[0]) * 60) + int.parse(startParts[1]);
            final endMinutes = (int.parse(endParts[0]) * 60) + int.parse(endParts[1]);
            final duration = endMinutes - startMinutes;
            if (duration > 0) {
              return duration;
            }
          }
        } catch (e) {
          // Fall through to default duration.
        }
      }
      return 60;
    }

    final estimatedHours = task['estimatedTime'];
    if (estimatedHours is int && estimatedHours > 0) {
      return estimatedHours * 60;
    }
    if (estimatedHours is num && estimatedHours > 0) {
      return estimatedHours.round() * 60;
    }

    return 60;
  }

  List<Map<String, dynamic>> _getSubjectBreakdown() {
    final Map<String, int> subjectMinutes = {};
    final Map<String, Color> subjectColors = {};

    for (final task in _todayTasks) {
      final subject = _getSubjectLabel(task);
      subjectMinutes[subject] = (subjectMinutes[subject] ?? 0) + _getTaskMinutes(task);
      subjectColors[subject] = _getSubjectColor(task);
    }

    final totalMinutes = subjectMinutes.values.fold<int>(0, (sum, value) => sum + value);
    if (totalMinutes == 0) {
      return [];
    }

    final breakdown = subjectMinutes.entries.map((entry) {
      final percent = ((entry.value / totalMinutes) * 100).round();
      return {
        'subject': entry.key,
        'minutes': entry.value,
        'percent': percent,
        'color': subjectColors[entry.key] ?? AppColors.subjectAccentColor(entry.key),
      };
    }).toList();

    breakdown.sort((a, b) => (b['minutes'] as int).compareTo(a['minutes'] as int));
    return breakdown;
  }

  String _buildCoachMessage(AppLocalizations l10n) {
    if (_todayTasks.isEmpty) {
      return l10n.coachNoTasks;
    }
    if (_todayTasks.any((task) => task['difficulty'] == 'Hard')) {
      final hardTask = _todayTasks.firstWhere((task) => task['difficulty'] == 'Hard');
      return l10n.coachStartWith(hardTask['name'] ?? '');
    }
    if (_completedTasksCount == _todayTasks.length) {
      return l10n.coachAllDone;
    }
    return l10n.coachItemsLeft(_todayTasks.length - _completedTasksCount);
  }

  Widget _buildOverviewMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color tone,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(AppLocalizations l10n) {
    final plannedUnits = _plannedTaskUnitsCount <= 0 ? 1 : _plannedTaskUnitsCount;
    final completionRatio = _todayTasks.isEmpty
        ? 0.0
      : _completedTasksCount / plannedUnits;
    final completionPercent = (completionRatio * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF8358)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.flash_on_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.todayOverview,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _buildCoachMessage(l10n),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.96),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      l10n.planCompletion,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$_completedTasksCount/${_plannedTaskUnitsCount} ${l10n.done} · $completionPercent%',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: completionRatio,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildOverviewMetric(
                icon: Icons.task_alt_rounded,
                label: l10n.tasksToday,
                value: '${_todayTasks.length}',
                tone: const Color(0xFFFFE3D7),
              ),
              const SizedBox(width: 10),
              _buildOverviewMetric(
                icon: Icons.local_fire_department_rounded,
                label: l10n.dayStreak,
                value: '${Provider.of<StreakProvider>(context).currentStreak}',

                tone: const Color(0xFFFFD5D5),
              ),

            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectAnalysisCard(AppLocalizations l10n) {
    final breakdown = _subjectBreakdown;
    if (breakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.todaySubjectBalance,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (int i = 0; i < breakdown.length; i++) ...[
                Expanded(
                  flex: (breakdown[i]['minutes'] as int).clamp(1, 10000),
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: breakdown[i]['color'] as Color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                if (i < breakdown.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: breakdown.map((item) {
              final color = item['color'] as Color;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${item['subject']} ${item['percent']}%',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent(AppLocalizations l10n) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Greeting
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(l10n),
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getGreetingName(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildOverviewCard(l10n),

            if (_todayTasks.isNotEmpty)
              const SizedBox(height: AppSpacing.md),
            if (_todayTasks.isNotEmpty)
              _buildSubjectAnalysisCard(l10n),
            
            // Performance Tracking Card - Temporarily hidden
            // const SizedBox(height: AppSpacing.lg),
            // const PerformanceTrackingCard(),
            
            const SizedBox(height: AppSpacing.xl),
            
            // Today's Schedule Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.todaySchedule,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _currentIndex = 2;
                    });
                  },
                  child: Text(
                    l10n.viewAll,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            
            // Task Cards - Dynamic from storage with status
            if (_todayTasks.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.add_task,
                      size: 48,
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.noTasksYet,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.addFirstTask,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              for (int i = 0; i < _todayTasks.length && i < 5; i++) ...[
                ...(() {
                  final task = _todayTasks[i];
                  final taskType = (task['taskType'] ?? '').toString();
                  if (taskType == 'Task') {
                    final sessions = task['sessions'];
                    if (sessions is List && sessions.isNotEmpty) {
                      final today = DateTime.now();
                      final todayDate =
                          DateTime(today.year, today.month, today.day);
                      final widgets = <Widget>[];
                      for (int si = 0; si < sessions.length; si++) {
                        final s = sessions[si];
                        if (s is! Map) continue;
                        try {
                          final st = DateTime.parse((s['startTime'] ?? '').toString());
                          final en = DateTime.parse((s['endTime'] ?? '').toString());
                          final sd = DateTime(st.year, st.month, st.day);
                          if (!sd.isAtSameMomentAs(todayDate)) continue;
                          final subject = _getSubjectLabel(task);
                          final subjectColor = _getSubjectColor(task);
                          final compositeId =
                              '${(task['id'] ?? '').toString()}::$si';
                          final durMin =
                              (s['duration'] is int ? s['duration'] as int : null) ??
                                  en.difference(st).inMinutes;
                          final durText = durMin >= 60
                              ? '${(durMin / 60).floor()}h'
                              : '${durMin}m';
                          widgets.add(
                            StatusTaskCard(
                              taskId: compositeId,
                              title: '${task['name'] ?? 'Untitled Task'} • Part ${si + 1}/${sessions.length}',
                              timeSlot:
                                  '${_formatTimeWith24H(st)} - ${_formatTimeWith24H(en, isRangeEnd: true)}',
                              deadlineText: _formatDeadlineLabel(task),
                              duration: durText,
                              difficulty: task['difficulty'] ?? 'Medium',
                              category: task['category'] ?? 'General',
                              subject: subject,
                              accentColor: subjectColor,
                              status: _getTaskStatus(compositeId),
                              onStatusChanged: _handleTaskStatusChange,
                              onDelete: () async {
                                await _storage.deleteCustomTask(
                                    (task['id'] ?? '').toString());
                                _loadData();
                              },
                            ),
                          );
                        } catch (_) {
                          // ignore bad session parse
                        }
                      }
                      if (widgets.isNotEmpty) return widgets;
                    }
                  }
                  if (taskType == 'Activity') {
                    final sessions = task['sessions'];
                    if (sessions is List && sessions.isNotEmpty) {
                      final today = DateTime.now();
                      final todayDate =
                          DateTime(today.year, today.month, today.day);
                      final widgets = <Widget>[];
                      for (int si = 0; si < sessions.length; si++) {
                        final s = sessions[si];
                        if (s is! Map) continue;
                        try {
                          final st = DateTime.parse((s['startTime'] ?? '').toString());
                          final en = DateTime.parse((s['endTime'] ?? '').toString());
                          final sd = DateTime(st.year, st.month, st.day);
                          if (!sd.isAtSameMomentAs(todayDate)) continue;
                          final subject = _getSubjectLabel(task);
                          final subjectColor = _getSubjectColor(task);
                          final compositeId =
                              '${(task['id'] ?? '').toString()}::$si';
                          final durMin =
                              (s['duration'] is int ? s['duration'] as int : null) ??
                                  en.difference(st).inMinutes;
                          final durText = durMin >= 60
                              ? '${(durMin / 60).floor()}h'
                              : '${durMin}m';
                          widgets.add(
                            StatusTaskCard(
                              taskId: compositeId,
                              title:
                                  '${task['name'] ?? 'Untitled Activity'} • Session ${si + 1}/${sessions.length}',
                              timeSlot:
                                  '${_formatTimeWith24H(st)} - ${_formatTimeWith24H(en, isRangeEnd: true)}',
                              deadlineText: _formatDeadlineLabel(task),
                              duration: durText,
                              difficulty: task['difficulty'] ?? 'Medium',
                              category: 'Activity',
                              subject: subject,
                              accentColor: subjectColor,
                              status: _getTaskStatus(compositeId),
                              onStatusChanged: _handleTaskStatusChange,
                              onDelete: () async {
                                await _storage.deleteCustomTask(
                                    (task['id'] ?? '').toString());
                                _loadData();
                              },
                            ),
                          );
                        } catch (_) {
                          // ignore bad session parse
                        }
                      }
                      if (widgets.isNotEmpty) return widgets;
                    }
                  }

                  // Default: render the task as-is.
                  final subject = _getSubjectLabel(task);
                  final subjectColor = _getSubjectColor(task);
                  return [
                    StatusTaskCard(
                      taskId: task['id'] ?? '',
                      title: task['name'] ?? 'Untitled Task',
                      timeSlot: _formatTimeRange(task),
                      deadlineText: _formatDeadlineLabel(task),
                      duration: '${task['estimatedTime'] ?? 1}h',
                      difficulty: task['difficulty'] ?? 'Medium',
                      category: task['category'] ?? 'General',
                      subject: subject,
                      accentColor: subjectColor,
                      status: _getTaskStatus(task['id'] ?? ''),
                      onStatusChanged: _handleTaskStatusChange,
                      onDelete: () async {
                        await _storage.deleteCustomTask(task['id'] ?? '');
                        _loadData();
                      },
                    ),
                  ];
                })(),
              ],
            ],
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, {VoidCallback? onTapOverride}) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTapOverride ?? () {
            setState(() {
              _currentIndex = index;
            });
          },
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 6), // Reduced space for dot
              Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 24,
              ),
              const SizedBox(height: 2), // Reduced spacing
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _getDotPosition(double screenWidth) {
    // Manual calculation for accurate positioning with spaceAround
    // Layout: [Home] [Tasks] [FAB:48px] [Calendar] [Profile]
    final fabWidth = 48.0;
    final totalItemsWidth = screenWidth - fabWidth;
    final itemWidth = totalItemsWidth / 4;
    
    // Calculate center position for each item
    if (_currentIndex == 0) {
      // Home - first quarter
      return itemWidth * 0.5;
    } else if (_currentIndex == 1) {
      // Tasks - second quarter
      return itemWidth * 1.5;
    } else if (_currentIndex == 2) {
      // Calendar - third quarter (skip FAB space)
      return (itemWidth * 2) + fabWidth + (itemWidth * 0.5);
    } else {
      // Profile - fourth quarter
      return (itemWidth * 3) + fabWidth + (itemWidth * 0.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screens = [
      _buildHomeContent(l10n),
      const ChatPlannerScreen(),
      CalendarScreen(key: ValueKey(_calendarVersion)),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: screens[_currentIndex],
      ),
      floatingActionButton: _currentIndex == 1 || MediaQuery.of(context).viewInsets.bottom > 0
          ? null
          : Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primaryDark,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    await Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const NewTaskInputScreen(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                          const begin = Offset(0.0, 1.0);
                          const end = Offset.zero;
                          const curve = Curves.easeInOut;
                          var tween = Tween(begin: begin, end: end)
                              .chain(CurveTween(curve: curve));
                          return SlideTransition(
                            position: animation.drive(tween),
                            child: child,
                          );
                        },
                        transitionDuration: const Duration(milliseconds: 400),
                      ),
                    );
                    // Refresh both home data and calendar after a task is added.
                    setState(() => _calendarVersion++);
                    _loadData();
                  },
                  customBorder: const CircleBorder(),
                  child: const Center(
                    child: Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomAppBar(
          color: AppColors.cardBackground,
          elevation: 0,
          shape: _currentIndex == 1 ? null : const CircularNotchedRectangle(),
          notchMargin: 8.0,
          child: SizedBox(
            height: 60,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    // Navigation items
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(
                          Icons.home_rounded,
                          l10n.navHome,
                          0,
                          onTapOverride: () {
                            setState(() => _currentIndex = 0);
                            _loadData();
                          },
                        ),
                        _buildNavItem(
                          Icons.chat_bubble_outline_rounded,
                          l10n.navChat,
                          1,
                          onTapOverride: () {
                            if (SubscriptionService().isPro) {
                              setState(() => _currentIndex = 1);
                            } else {
                              UpgradeDialog.show(context);
                            }
                          },
                        ),
                        const SizedBox(width: 48),
                        _buildNavItem(Icons.calendar_month, l10n.navCalendar, 2),
                        _buildNavItem(Icons.person, l10n.navProfile, 3),
                      ],
                    ),
                    // Animated dot indicator
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOut,
                      left: _getDotPosition(constraints.maxWidth) - 2.5,
                      top: 0,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
