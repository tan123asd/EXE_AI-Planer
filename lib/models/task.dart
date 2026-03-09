class Task {
  final String id;
  final String name;
  final String subject;
  final String time;
  final String difficulty;
  final bool isCompleted;
  final String category;
  final DateTime? deadline;
  final int? estimatedTime;
  
  // Performance tracking
  final int? actualTime; // Actual time spent in minutes
  final DateTime? startedAt; // When task was started
  final DateTime? completedAt; // When task was completed
  
  // Break reminders
  final bool needsBreak; // Whether this task needs break reminders
  final int breakInterval; // Break interval in minutes (default 50)
  final int breakDuration; // Break duration in minutes (default 10)
  
  // Schedule conflict avoidance
  final DateTime? scheduledStartTime;
  final DateTime? scheduledEndTime;

  Task({
    required this.id,
    required this.name,
    required this.subject,
    required this.time,
    required this.difficulty,
    this.isCompleted = false,
    this.category = 'Study',
    this.deadline,
    this.estimatedTime,
    this.actualTime,
    this.startedAt,
    this.completedAt,
    this.needsBreak = true,
    this.breakInterval = 50,
    this.breakDuration = 10,
    this.scheduledStartTime,
    this.scheduledEndTime,
  });

  Task copyWith({
    String? id,
    String? name,
    String? subject,
    String? time,
    String? difficulty,
    bool? isCompleted,
    String? category,
    DateTime? deadline,
    int? estimatedTime,
    int? actualTime,
    DateTime? startedAt,
    DateTime? completedAt,
    bool? needsBreak,
    int? breakInterval,
    int? breakDuration,
    DateTime? scheduledStartTime,
    DateTime? scheduledEndTime,
  }) {
    return Task(
      id: id ?? this.id,
      name: name ?? this.name,
      subject: subject ?? this.subject,
      time: time ?? this.time,
      difficulty: difficulty ?? this.difficulty,
      isCompleted: isCompleted ?? this.isCompleted,
      category: category ?? this.category,
      deadline: deadline ?? this.deadline,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      actualTime: actualTime ?? this.actualTime,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      needsBreak: needsBreak ?? this.needsBreak,
      breakInterval: breakInterval ?? this.breakInterval,
      breakDuration: breakDuration ?? this.breakDuration,
      scheduledStartTime: scheduledStartTime ?? this.scheduledStartTime,
      scheduledEndTime: scheduledEndTime ?? this.scheduledEndTime,
    );
  }
  
  // Helper methods
  int get performanceRatio {
    if (actualTime == null || estimatedTime == null || estimatedTime == 0) {
      return 100;
    }
    return ((actualTime! / (estimatedTime! * 60)) * 100).round();
  }
  
  bool get isOverEstimate => actualTime != null && 
      estimatedTime != null && 
      actualTime! > (estimatedTime! * 60);
  
  bool get isUnderEstimate => actualTime != null && 
      estimatedTime != null && 
      actualTime! < (estimatedTime! * 60);
}
