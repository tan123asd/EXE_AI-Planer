import 'package:flutter/material.dart';
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

  String _formatTimeRange(int estimatedHours) {
    final startHour = 9;
    final endHour = startHour + estimatedHours;
    
    // Format start time with AM/PM
    String startFormatted;
    if (startHour == 0) {
      startFormatted = '12:00 AM';
    } else if (startHour < 12) {
      startFormatted = '$startHour:00 AM';
    } else if (startHour == 12) {
      startFormatted = '12:00 PM';
    } else {
      startFormatted = '${startHour - 12}:00 PM';
    }
    
    // Format end time with AM/PM
    String endFormatted;
    if (endHour == 0) {
      endFormatted = '12:00 AM';
    } else if (endHour < 12) {
      endFormatted = '$endHour:00 AM';
    } else if (endHour == 12) {
      endFormatted = '12:00 PM';
    } else {
      endFormatted = '${endHour - 12}:00 PM';
    }
    
    return '$startFormatted - $endFormatted';
  }

  @override
  Widget build(BuildContext context) {
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
                    '${_allTasks.length} task${_allTasks.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: _allTasks.isEmpty
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
                          'No tasks yet',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Tap the + button to add your first task',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _allTasks.length,
                    itemBuilder: (context, index) {
                      final task = _allTasks[index];
                      
                      return StatusTaskCard(
                        taskId: task['id'] ?? '',
                        title: task['name'] ?? 'Untitled Task',
                        timeSlot: _formatTimeRange(task['estimatedTime'] as int? ?? 1),
                        duration: '${task['estimatedTime'] ?? 1}h',
                        difficulty: task['difficulty'] ?? 'Medium',
                        category: task['category'] ?? 'General',
                        status: _getTaskStatus(task['id'] ?? ''),
                        onStatusChanged: _handleTaskStatusChange,
                        onDelete: () async {
                          await _storage.deleteCustomTask(task['id'] ?? '');
                          _loadTasks();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
