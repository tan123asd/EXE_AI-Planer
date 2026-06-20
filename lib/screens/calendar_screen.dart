import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ai_study_planner/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';
import '../widgets/day_timeline.dart';
import '../widgets/task_detail_sheet.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final StorageService _storage = StorageService();
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _allCustomTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    _allCustomTasks = _storage.getCustomTasks();
    setState(() => _isLoading = false);
  }

  List<dynamic>? _extractSessions(dynamic raw) {
    if (raw is List) return raw;
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  List<DayTimelineEvent> _getFixedScheduleEventsForDate(DateTime date) {
    final events = <DayTimelineEvent>[];
    for (final task in _allCustomTasks) {
      if (task['taskType'] != 'Schedules') continue;

      final weekdays = task['weekdays'];
      if (weekdays is! List) continue;
      if (!weekdays.contains(date.weekday)) continue;

      final startTimeStr = task['startTime'] as String?;
      final endTimeStr = task['endTime'] as String?;
      if (startTimeStr == null || endTimeStr == null) continue;

      final startParts = startTimeStr.split(':');
      final endParts = endTimeStr.split(':');
      if (startParts.length != 2 || endParts.length != 2) continue;

      final startHour = int.tryParse(startParts[0]) ?? 0;
      final startMin = int.tryParse(startParts[1]) ?? 0;
      final endHour = int.tryParse(endParts[0]) ?? 0;
      final endMin = int.tryParse(endParts[1]) ?? 0;

      final start = DateTime(date.year, date.month, date.day, startHour, startMin);
      final end = DateTime(date.year, date.month, date.day, endHour, endMin);
      if (!end.isAfter(start)) continue;

      final endDateStr = task['endDate'] as String?;
      if (endDateStr != null) {
        final endDate = DateTime.tryParse(endDateStr);
        if (endDate != null && date.isAfter(endDate)) continue;
      }

      events.add(DayTimelineEvent(
        id: '${task['id'] ?? 'fixed'}_${date.millisecondsSinceEpoch}',
        taskId: (task['id'] ?? '').toString(),
        sessionIndex: -1,
        title: (task['name'] ?? 'Schedule').toString(),
        subtitle: null,
        subject: 'Schedules',
        start: start,
        end: end,
        isCompleted: false,
      ));
    }
    return events;
  }

  List<DayTimelineEvent> _getSessionEventsForDate(DateTime date) {
    final events = <DayTimelineEvent>[];
    for (final task in _allCustomTasks) {
      final sessions = _extractSessions(task['sessions']);
      if (sessions == null || sessions.isEmpty) continue;
      final taskId = (task['id'] ?? '').toString();
      final taskName = (task['name'] ?? 'Untitled').toString();
      final subject = (task['subject'] ?? task['taskType'] ?? 'Task').toString();

      for (int i = 0; i < sessions.length; i++) {
        final s = sessions[i];
        if (s is! Map) continue;
        final start = DateTime.tryParse((s['startTime'] ?? '').toString());
        final end = DateTime.tryParse((s['endTime'] ?? '').toString());
        if (start == null || end == null) continue;
        final sessionCompleted = s['isCompleted'] == true;

        // Use subtask name as title; fall back to parent task name if absent.
        final subtaskName = (s['taskName'] as String?)?.trim() ?? '';
        final title = subtaskName.isNotEmpty ? subtaskName : taskName;
        // Show parent task as subtitle only when it differs from the title.
        final subtitle = (subtaskName.isNotEmpty && subtaskName != taskName)
            ? taskName
            : null;

        if (start.year == date.year &&
            start.month == date.month &&
            start.day == date.day) {
          events.add(
            DayTimelineEvent(
              id: '${taskId}_$i',
              taskId: taskId,
              sessionIndex: i,
              title: title,
              subtitle: subtitle,
              subject: subject,
              start: start,
              end: end,
              isCompleted: sessionCompleted,
            ),
          );
        }
      }
    }
    return events;
  }

  Map<String, dynamic>? _findTaskById(String taskId) {
    for (final t in _allCustomTasks) {
      if ((t['id'] ?? '').toString() == taskId) return t;
    }
    return null;
  }

  /// Returns Activity tasks that recur on the given date's weekday but have no
  /// sessions (i.e. they are timeless recurring activities, not on the timeline).
  List<Map<String, dynamic>> _getRecurringActivitiesForDate(DateTime date) {
    final result = <Map<String, dynamic>>[];
    for (final task in _allCustomTasks) {
      if (task['taskType'] != 'Activity') continue;
      final sessions = task['sessions'];
      // Only show here if there are no session-based time slots already on timeline
      if (sessions != null && sessions is List && sessions.isNotEmpty) continue;
      final weekdays = task['weekdays'];
      if (weekdays == null || weekdays is! List) continue;
      if (!weekdays.contains(date.weekday)) continue;
      final endDateStr = task['scheduleEndDate'] as String?;
      if (endDateStr != null) {
        final endDate = DateTime.tryParse(endDateStr);
        if (endDate != null) {
          final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);
          final dateOnly = DateTime(date.year, date.month, date.day);
          if (dateOnly.isAfter(endDateOnly)) continue;
        }
      }
      result.add(task);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final day1 = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final day2 = day1.add(const Duration(days: 1));
    final eventsDay1 = [
      ..._getSessionEventsForDate(day1),
      ..._getFixedScheduleEventsForDate(day1),
    ];
    final eventsDay2 = [
      ..._getSessionEventsForDate(day2),
      ..._getFixedScheduleEventsForDate(day2),
    ];
    final viewDay1 = _computeHourViewport(eventsDay1);
    final viewDay2 = _computeHourViewport(eventsDay2);
    final totalCount = eventsDay1.length + eventsDay2.length;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('MMMM', locale).format(DateTime(_selectedDate.year, _selectedDate.month)),
                    style: AppTextStyles.heading1.copyWith(fontSize: 26),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_selectedDate.year}, ${l10n.countryVietnam}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _isLoading
                        ? null
                        : () => setState(() {
                              _selectedDate =
                                  _selectedDate.subtract(const Duration(days: 1));
                            }),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    onPressed: _isLoading
                        ? null
                        : () => setState(() {
                              _selectedDate = _selectedDate.add(const Duration(days: 1));
                            }),
                    icon: const Icon(Icons.chevron_right),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _loadData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      l10n.refresh,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${DateFormat('EEE', locale).format(day1)} ${day1.day}',
                        style: AppTextStyles.heading3,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${DateFormat('EEE', locale).format(day2)} ${day2.day}',
                        style: AppTextStyles.heading3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppShadows.card,
                ),
                child: Text(
                  l10n.tasksCount(totalCount),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Recurring activities row (timeless — no sessions on timeline)
          Builder(builder: (ctx) {
            final acts1 = _getRecurringActivitiesForDate(day1);
            final acts2 = _getRecurringActivitiesForDate(day2);
            if (acts1.isEmpty && acts2.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildActivityChips(acts1)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildActivityChips(acts2)),
                ],
              ),
            );
          }),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DayTimeline(
                          selectedDate: day1,
                          events: eventsDay1,
                          startHour: viewDay1.startHour,
                          endHour: viewDay1.endHour,
                          pxPerMinute: 0.75,
                          hideEmptyTime: true,
                          onEventTap: _onEventTap,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DayTimeline(
                          selectedDate: day2,
                          events: eventsDay2,
                          startHour: viewDay2.startHour,
                          endHour: viewDay2.endHour,
                          pxPerMinute: 0.75,
                          hideEmptyTime: true,
                          onEventTap: _onEventTap,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _onEventTap(DayTimelineEvent event) async {
    final task = _findTaskById(event.taskId);
    if (task == null) return;
    final navigator = Navigator.of(context);
    final isSchedule = event.sessionIndex < 0;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return TaskDetailSheet(
          task: task,
          sessionStart: event.start,
          sessionEnd: event.end,
          isCompleted: isSchedule ? true : event.isCompleted,
          onMarkCompleted: isSchedule
              ? () async {}
              : () async {
                  await _storage.setTaskSessionCompleted(
                    event.taskId,
                    sessionIndex: event.sessionIndex,
                    isCompleted: true,
                  );
                  if (!mounted) return;
                  navigator.pop();
                  await _loadData();
                },
          onDeleteSession: !isSchedule
              ? () async {
                  await _storage.deleteTaskSession(
                    event.taskId,
                    event.sessionIndex,
                  );
                  if (!mounted) return;
                  navigator.pop();
                  await _loadData();
                }
              : null,
          onDelete: () async {
            await _storage.deleteCustomTask(event.taskId);
            if (!mounted) return;
            navigator.pop();
            await _loadData();
          },
        );
      },
    );
  }

  Widget _buildActivityChips(List<Map<String, dynamic>> activities) {
    if (activities.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: activities.map((task) {
        final name = (task['name'] ?? '').toString();
        final est = task['estimatedMinutes'];
        String durLabel = '';
        if (est is num && est > 0) {
          final mins = est.round();
          durLabel = mins < 60 ? ' · ${mins}m' : ' · ${mins ~/ 60}h${mins % 60 > 0 ? '${mins % 60}m' : ''}';
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
          ),
          child: Text(
            '$name$durLabel',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }

  /// Returns (startHour, endHour) focusing on hours that contain events.
  /// Adds 1-hour padding on each side; clamps to 0..24.
  _HourViewport _computeHourViewport(List<DayTimelineEvent> events) {
    if (events.isEmpty) return const _HourViewport(startHour: 6, endHour: 22);
    int minM = 24 * 60;
    int maxM = 0;
    for (final e in events) {
      if (e.startMinutes < minM) minM = e.startMinutes;
      if (e.endMinutes > maxM) maxM = e.endMinutes;
    }
    final startHour = ((minM ~/ 60) - 1).clamp(0, 23);
    final endHour = (((maxM + 59) ~/ 60) + 1).clamp(startHour + 1, 24);
    return _HourViewport(startHour: startHour, endHour: endHour);
  }
}

class _HourViewport {
  final int startHour;
  final int endHour;

  const _HourViewport({required this.startHour, required this.endHour});
}
