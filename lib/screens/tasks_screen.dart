import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';
import '../widgets/status_task_card.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({Key? key}) : super(key: key);

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final StorageService _storage = StorageService();
  List<Map<String, dynamic>> _allTasks = [];
  String _activeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  void _loadTasks() {
    setState(() {
      _allTasks = _storage.getCustomTasks();
    });
  }

  TaskStatus _getTaskStatus(String taskId) {
    if (_storage.isTaskCompleted(taskId)) {
      return TaskStatus.completed;
    } else if (_storage.isTaskInProgress(taskId)) {
      return TaskStatus.inProgress;
    }
    return TaskStatus.pending;
  }

  void _handleTaskStatusChange(String taskId, TaskStatus newStatus) async {
    String statusString = 'pending';
    if (newStatus == TaskStatus.completed) {
      statusString = 'completed';
    } else if (newStatus == TaskStatus.inProgress) {
      statusString = 'inProgress';
    }
    
    await _storage.updateTaskStatus(taskId, statusString);
    _loadTasks();
  }

  bool _isSchedule(Map<String, dynamic> task) {
    final type = (task['taskType'] ?? '').toString();
    return type == 'Schedules' || type == 'Activity';
  }

  String _formatDurationMinutes(int minutes) {
    if (minutes <= 0) {
      return '0m';
    }

    final hours = minutes ~/ 60;
    final remain = minutes % 60;
    if (hours == 0) {
      return '${remain}m';
    }
    if (remain == 0) {
      return '${hours}h';
    }
    return '${hours}h ${remain}m';
  }

  int _resolveEstimatedMinutes(Map<String, dynamic> task) {
    final estimatedMinutes = task['estimatedMinutes'];
    if (estimatedMinutes is int && estimatedMinutes > 0) {
      return estimatedMinutes;
    }
    if (estimatedMinutes is num && estimatedMinutes > 0) {
      return estimatedMinutes.round();
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

  String _formatDateTimeRange(DateTime start, DateTime end) {
    final sameDate = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    final dayPrefix = DateFormat('dd/MM').format(start);
    final startTime = DateFormat('HH:mm').format(start);
    final endTime = (end.hour == 0 && end.minute == 0)
        ? '24:00'
        : DateFormat('HH:mm').format(end);

    if (sameDate) {
      return '$dayPrefix $startTime - $endTime';
    }

    final endPrefix = DateFormat('dd/MM').format(end);
    return '$dayPrefix $startTime - $endPrefix $endTime';
  }

  String _formatScheduleTimeRange(Map<String, dynamic> schedule) {
    final start = (schedule['startTime'] ?? '').toString();
    final end = (schedule['endTime'] ?? '').toString();
    if (start.isEmpty || end.isEmpty) {
      return 'Not set';
    }

    if (end == '00:00') {
      return '$start - 24:00';
    }
    return '$start - $end';
  }

  int _resolveScheduleMinutes(Map<String, dynamic> schedule) {
    final start = (schedule['startTime'] ?? '').toString().split(':');
    final end = (schedule['endTime'] ?? '').toString().split(':');
    if (start.length != 2 || end.length != 2) {
      return 60;
    }

    try {
      final startMin = int.parse(start[0]) * 60 + int.parse(start[1]);
      final endMin = int.parse(end[0]) * 60 + int.parse(end[1]);
      final diff = endMin - startMin;
      return diff > 0 ? diff : 60;
    } catch (_) {
      return 60;
    }
  }

  String _resolveTaskTimeSlot(Map<String, dynamic> task) {
    final sessions = task['sessions'];
    if (sessions is List && sessions.isNotEmpty) {
      final parsed = <Map<String, DateTime>>[];
      for (final session in sessions) {
        if (session is! Map<String, dynamic>) continue;
        final start = DateTime.tryParse((session['startTime'] ?? '').toString());
        final end = DateTime.tryParse((session['endTime'] ?? '').toString());
        if (start != null && end != null) {
          parsed.add({'start': start, 'end': end});
        }
      }

      if (parsed.isNotEmpty) {
        parsed.sort((a, b) => a['start']!.compareTo(b['start']!));
        return _formatDateTimeRange(parsed.first['start']!, parsed.first['end']!);
      }
    }

    final deadline = DateTime.tryParse((task['deadline'] ?? '').toString());
    if (deadline != null && (deadline.hour != 0 || deadline.minute != 0)) {
      final end = deadline.add(Duration(minutes: _resolveEstimatedMinutes(task)));
      return _formatDateTimeRange(deadline, end);
    }

    return 'No specific time';
  }

  String? _resolveDeadlineLabel(Map<String, dynamic> task) {
    if ((task['taskType'] ?? '').toString() != 'Task') {
      return null;
    }

    final deadline = DateTime.tryParse((task['deadline'] ?? '').toString());
    if (deadline == null) {
      return null;
    }

    if (deadline.hour == 0 && deadline.minute == 0) {
      return DateFormat('dd/MM').format(deadline);
    }

    return DateFormat('dd/MM • HH:mm').format(deadline);
  }

  String _formatWeekdays(dynamic weekdays) {
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (weekdays is! List || weekdays.isEmpty) {
      return 'No days set';
    }

    final items = weekdays
        .map((e) => e is int && e >= 1 && e <= 7 ? dayNames[e - 1] : null)
        .whereType<String>()
        .toList();
    if (items.isEmpty) {
      return 'No days set';
    }
    return items.join(', ');
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    final title = (schedule['name'] ?? 'Untitled Schedule').toString();
    final category = (schedule['category'] ?? schedule['subject'] ?? 'Other').toString();
    final subject = category;
    final accentColor = AppColors.subjectAccentColor(category);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: accentColor.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$subject • ${_formatWeekdays(schedule['weekdays'])}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatScheduleTimeRange(schedule)} • ${_formatDurationMinutes(_resolveScheduleMinutes(schedule))}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              await _storage.deleteCustomTask((schedule['id'] ?? '').toString());
              _loadTasks();
            },
            icon: const Icon(Icons.delete_outline),
            color: AppColors.danger,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String keyName,
    required String label,
    required int count,
  }) {
    final isActive = _activeFilter == keyName;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeFilter = keyName;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.textSecondary.withOpacity(0.25),
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _allTasks.where((task) => !_isSchedule(task)).toList();
    final schedules = _allTasks.where(_isSchedule).toList();
    final activities = schedules
      .where((task) => (task['taskType'] ?? '').toString() == 'Activity')
      .toList();
    final showTasks = _activeFilter == 'all' || _activeFilter == 'tasks';
    final showSchedules = _activeFilter == 'all' || _activeFilter == 'schedules';
    final showActivities = _activeFilter == 'all' || _activeFilter == 'activities';
    final schedulesOnly = schedules
      .where((task) => (task['taskType'] ?? '').toString() == 'Schedules')
      .toList();
    final hasVisibleItems =
      (showTasks && tasks.isNotEmpty) ||
      (showSchedules && schedulesOnly.isNotEmpty) ||
      (showActivities && activities.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'All Tasks',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (_allTasks.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_allTasks.length} item${_allTasks.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _buildFilterChip(
                keyName: 'all',
                label: 'All',
                count: _allTasks.length,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                keyName: 'tasks',
                label: 'Tasks',
                count: tasks.length,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                keyName: 'schedules',
                label: 'Schedules',
                count: schedulesOnly.length,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                keyName: 'activities',
                label: 'Activity',
                count: activities.length,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: !hasVisibleItems
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.task_alt,
                          size: 80,
                          color: AppColors.textSecondary.withOpacity(0.3),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          _allTasks.isEmpty ? 'No tasks yet' : 'No items in this filter',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _allTasks.isEmpty
                              ? 'Tap the + button to add your first task'
                              : 'Try switching filter to see other items',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    children: [
                      if (showTasks && tasks.isNotEmpty) ...[
                        const Text(
                          'Tasks',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ...tasks.map((task) {
                          final category = (task['category'] ?? task['subject'] ?? 'Other').toString();
                          final subject = category;
                          final accentColor = AppColors.subjectAccentColor(category);

                          return StatusTaskCard(
                            taskId: (task['id'] ?? '').toString(),
                            title: (task['name'] ?? 'Untitled Task').toString(),
                            timeSlot: _resolveTaskTimeSlot(task),
                            deadlineText: _resolveDeadlineLabel(task),
                            duration: _formatDurationMinutes(_resolveEstimatedMinutes(task)),
                            difficulty: (task['difficulty'] ?? 'Medium').toString(),
                            category: (task['category'] ?? 'General').toString(),
                            subject: subject,
                            accentColor: accentColor,
                            status: _getTaskStatus((task['id'] ?? '').toString()),
                            onStatusChanged: _handleTaskStatusChange,
                            onDelete: () async {
                              await _storage.deleteCustomTask((task['id'] ?? '').toString());
                              _loadTasks();
                            },
                          );
                        }),
                      ],
                      if (showTasks && tasks.isNotEmpty && showSchedules && schedulesOnly.isNotEmpty)
                        const SizedBox(height: AppSpacing.md),
                      if (showSchedules && schedulesOnly.isNotEmpty) ...[
                        const Text(
                          'Recurring Schedules',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ...schedulesOnly.map(_buildScheduleCard),
                      ],
                      if ((showTasks && tasks.isNotEmpty || showSchedules && schedulesOnly.isNotEmpty) &&
                          showActivities && activities.isNotEmpty)
                        const SizedBox(height: AppSpacing.md),
                      if (showActivities && activities.isNotEmpty) ...[
                        const Text(
                          'Activities',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ...activities.map(_buildScheduleCard),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
