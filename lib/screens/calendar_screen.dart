import 'dart:convert';
import 'package:flutter/material.dart';
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

  List<DayTimelineEvent> _getSessionEventsForDate(DateTime date) {
    final events = <DayTimelineEvent>[];
    for (final task in _allCustomTasks) {
      final sessions = _extractSessions(task['sessions']);
      if (sessions == null || sessions.isEmpty) continue;
      final taskId = (task['id'] ?? '').toString();
      final title = (task['name'] ?? 'Untitled').toString();
      final subject = (task['subject'] ?? task['taskType'] ?? 'Task').toString();

      for (int i = 0; i < sessions.length; i++) {
        final s = sessions[i];
        if (s is! Map) continue;
        final start = DateTime.tryParse((s['startTime'] ?? '').toString());
        final end = DateTime.tryParse((s['endTime'] ?? '').toString());
        if (start == null || end == null) continue;
        final sessionCompleted = s['isCompleted'] == true;

        if (start.year == date.year &&
            start.month == date.month &&
            start.day == date.day) {
          events.add(
            DayTimelineEvent(
              id: '${taskId}_$i',
              taskId: taskId,
              sessionIndex: i,
              title: title,
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

  @override
  Widget build(BuildContext context) {
    final day1 = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final day2 = day1.add(const Duration(days: 1));
    final eventsDay1 = _getSessionEventsForDate(day1);
    final eventsDay2 = _getSessionEventsForDate(day2);
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
                    _getMonthName(_selectedDate.month),
                    style: AppTextStyles.heading1.copyWith(fontSize: 26),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_selectedDate.year}, Vietnam',
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
                    child: const Text(
                      'Refresh',
                      style: TextStyle(fontWeight: FontWeight.w700),
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
                        '${_weekdayShort(day1.weekday)} ${day1.day}',
                        style: AppTextStyles.heading3,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_weekdayShort(day2.weekday)} ${day2.day}',
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
                  '$totalCount tasks',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return TaskDetailSheet(
          task: task,
          sessionStart: event.start,
          sessionEnd: event.end,
          isCompleted: event.isCompleted,
          onMarkCompleted: () async {
            await _storage.setTaskSessionCompleted(
              event.taskId,
              sessionIndex: event.sessionIndex,
              isCompleted: true,
            );
            if (!mounted) return;
            navigator.pop(); // close sheet
            await _loadData();
          },
        );
      },
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  String _weekdayShort(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(weekday - 1).clamp(0, 6)];
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
