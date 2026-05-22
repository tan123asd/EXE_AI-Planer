import 'dart:convert';

class AiSubtask {
  final int order;
  final String name;
  final double duration; // hours
  final String focusLevel; // 'high' | 'medium' | 'low'
  final double minBlock; // hours, minimum continuous block required
  final String preferredTime; // 'high_focus' | 'low_focus' | 'flexible'

  const AiSubtask({
    required this.order,
    required this.name,
    required this.duration,
    required this.focusLevel,
    required this.minBlock,
    required this.preferredTime,
  });

  factory AiSubtask.fromMap(Map<String, dynamic> map) {
    return AiSubtask(
      order: (map['order'] as num).toInt(),
      name: map['name'] as String,
      duration: (map['duration'] as num).toDouble(),
      focusLevel: map['focus_level'] as String? ?? 'medium',
      minBlock: (map['min_block'] as num?)?.toDouble() ?? 1.0,
      preferredTime: map['preferred_time'] as String? ?? 'flexible',
    );
  }
}

class AiTaskPlan {
  final DateTime createdAt;
  final DateTime deadline;
  final String priority; // 'high' | 'medium' | 'low'
  final List<AiSubtask> tasks;

  const AiTaskPlan({
    required this.createdAt,
    required this.deadline,
    required this.priority,
    required this.tasks,
  });

  factory AiTaskPlan.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return AiTaskPlan.fromMap(map);
  }

  factory AiTaskPlan.fromMap(Map<String, dynamic> map) {
    final tasksList = (map['tasks'] as List<dynamic>)
        .map((t) => AiSubtask.fromMap(t as Map<String, dynamic>))
        .toList();
    return AiTaskPlan(
      createdAt: DateTime.parse(map['created_at'] as String),
      deadline: DateTime.parse(map['deadline'] as String),
      priority: map['priority'] as String? ?? 'medium',
      tasks: tasksList,
    );
  }

  int get totalDurationMinutes =>
      tasks.fold(0.0, (sum, t) => sum + t.duration * 60).round();
}

class ProductivityWindow {
  final int startHour; // inclusive, 0–23
  final int endHour; // exclusive, 1–24

  const ProductivityWindow({required this.startHour, required this.endHour});

  factory ProductivityWindow.fromMap(Map<String, dynamic> map) {
    return ProductivityWindow(
      startHour: (map['startHour'] as num).toInt(),
      endHour: (map['endHour'] as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() => {'startHour': startHour, 'endHour': endHour};

  bool containsHour(int hour) => hour >= startHour && hour < endHour;
}

class SchedulerConfig {
  final List<ProductivityWindow> productivityWindows;
  final DateTime searchFrom;
  final DateTime deadline;
  // Max minutes to allocate for this task on any single calendar day.
  // Null means no cap.
  final int? maxMinutesPerDay;

  const SchedulerConfig({
    required this.productivityWindows,
    required this.searchFrom,
    required this.deadline,
    this.maxMinutesPerDay,
  });
}

class TimeBlock {
  final DateTime start;
  final DateTime end;
  final bool isHighProductivity;
  final bool isSoftRest;

  const TimeBlock({
    required this.start,
    required this.end,
    required this.isHighProductivity,
    required this.isSoftRest,
  });

  int get durationMinutes => end.difference(start).inMinutes;
}

class ScheduledSlot {
  final String taskId;
  final String taskName;
  final int sessionIndex;
  final DateTime startTime;
  final DateTime endTime;
  final int score;

  const ScheduledSlot({
    required this.taskId,
    required this.taskName,
    required this.sessionIndex,
    required this.startTime,
    required this.endTime,
    this.score = 0,
  });

  int get durationMinutes => endTime.difference(startTime).inMinutes;

  Map<String, dynamic> toMap() => {
        'taskId': taskId,
        'taskName': taskName,
        'sessionIndex': sessionIndex,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'duration': durationMinutes,
      };
}

class ScheduleResult {
  final bool allTasksScheduled;
  final List<ScheduledSlot> scheduledSlots;
  final List<AiSubtask> failedTasks;
  final String? failureReason;

  const ScheduleResult({
    required this.allTasksScheduled,
    required this.scheduledSlots,
    required this.failedTasks,
    this.failureReason,
  });
}

class ActivityRequest {
  final String name;
  final int durationMinutes;
  final List<int> preferredWeekdays; // 1=Mon … 7=Sun
  final String category;

  const ActivityRequest({
    required this.name,
    required this.durationMinutes,
    required this.preferredWeekdays,
    required this.category,
  });
}
