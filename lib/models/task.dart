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
    );
  }
}
