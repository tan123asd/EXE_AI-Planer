import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../models/task.dart';
import '../models/schedule_item.dart';
import '../services/storage_service.dart';
import '../widgets/task_card.dart';
import '../widgets/schedule_card.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final StorageService _storage = StorageService();
  DateTime _selectedDate = DateTime.now();
  List<Task> _allTasks = [];
  List<ScheduleItem> _allSchedule = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Load tasks
    final customTasks = await _storage.getCustomTasks();
    _allTasks = customTasks.map((item) {
      DateTime? deadline;
      if (item['deadline'] != null) {
        try {
          deadline = DateTime.parse(item['deadline']);
        } catch (e) {
          deadline = null;
        }
      }
      
      return Task(
        id: item['id'] ?? DateTime.now().toString(),
        name: item['name'] ?? 'Untitled',
        subject: item['subject'] ?? 'General',
        time: _formatTaskTime(item),
        difficulty: item['difficulty'] ?? 'Medium',
        isCompleted: item['isCompleted'] ?? false,
        deadline: deadline,
        category: item['category'] ?? 'Study',
        estimatedTime: item['estimatedTime'],
      );
    }).toList();

    // Load schedule
    final savedSchedule = await _storage.getGeneratedSchedule();
    _allSchedule = savedSchedule.map((item) {
      return ScheduleItem(
        id: item['id'] ?? DateTime.now().toString(),
        day: item['day'] ?? 'Monday',
        time: item['time'] ?? '00:00',
        title: item['title'] ?? 'Untitled',
        subject: item['subject'] ?? 'General',
        difficulty: item['difficulty'] ?? 'Medium',
      );
    }).toList();

    setState(() => _isLoading = false);
  }

  String _formatTaskTime(Map<String, dynamic> item) {
    if (item['deadline'] != null) {
      try {
        final deadline = DateTime.parse(item['deadline']);
        final hour = deadline.hour;
        final minute = deadline.minute.toString().padLeft(2, '0');
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '$displayHour:$minute $period';
      } catch (e) {
        return '08:00 AM';
      }
    }
    return '08:00 AM';
  }

  String _getDayName(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }

  List<ScheduleItem> _getScheduleForDay(String dayName) {
    return _allSchedule.where((item) => item.day == dayName).toList();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDayName = _getDayName(_selectedDate);
    final scheduleForDay = _getScheduleForDay(selectedDayName);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Calendar',
            style: AppTextStyles.heading1,
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Month Navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _selectedDate = DateTime(
                      _selectedDate.year,
                      _selectedDate.month - 1,
                      _selectedDate.day,
                    );
                  });
                },
              ),
              Text(
                '${_getMonthName(_selectedDate.month)} ${_selectedDate.year}',
                style: AppTextStyles.heading2,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _selectedDate = DateTime(
                      _selectedDate.year,
                      _selectedDate.month + 1,
                      _selectedDate.day,
                    );
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Week Days
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (index) {
                final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                final today = DateTime.now();
                final dayDate = today.subtract(Duration(days: today.weekday - 1 - index));
                final isSelected = dayDate.day == _selectedDate.day &&
                    dayDate.month == _selectedDate.month;
                final isToday = dayDate.day == today.day && dayDate.month == today.month;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = dayDate;
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          days[index],
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${dayDate.day}',
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          
          // Selected Day Info
          Text(
            '$selectedDayName, ${_selectedDate.day} ${_getMonthName(_selectedDate.month)}',
            style: AppTextStyles.heading2,
          ),
          const SizedBox(height: AppSpacing.md),
          
          // Tasks and Schedule
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : scheduleForDay.isEmpty && _allTasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_available,
                              size: 64,
                              color: AppColors.textSecondary.withOpacity(0.5),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'No tasks for this day',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        children: [
                          if (scheduleForDay.isNotEmpty) ...[
                            const Text(
                              'Schedule',
                              style: AppTextStyles.heading3,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            ...scheduleForDay.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: ScheduleCard(scheduleItem: item),
                            )),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          if (_allTasks.isNotEmpty) ...[
                            const Text(
                              'All Tasks',
                              style: AppTextStyles.heading3,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            ..._allTasks.asMap().entries.map((entry) {
                              final index = entry.key;
                              final task = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: TaskCard(
                                  task: task,
                                  onCheckboxChanged: (value) async {
                                    final updatedTask = task.copyWith(isCompleted: value ?? false);
                                    setState(() {
                                      _allTasks[index] = updatedTask;
                                    });
                                    
                                    final customTasks = await _storage.getCustomTasks();
                                    final taskIndex = customTasks.indexWhere((t) => t['id'] == task.id);
                                    if (taskIndex != -1) {
                                      customTasks[taskIndex]['isCompleted'] = updatedTask.isCompleted;
                                      await _storage.saveCustomTasks(customTasks);
                                    }
                                  },
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}
