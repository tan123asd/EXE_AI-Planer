class ScheduleItem {
  final String id;
  final String day;
  final String time;
  final String title;
  final String subject;
  final String difficulty;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool hasBreak;
  final int? breakAfterMinutes;

  ScheduleItem({
    required this.id,
    required this.day,
    required this.time,
    required this.title,
    required this.subject,
    required this.difficulty,
    this.startTime,
    this.endTime,
    this.hasBreak = false,
    this.breakAfterMinutes,
  });
  
  // Check if this schedule item conflicts with another
  bool conflictsWith(ScheduleItem other) {
    if (startTime == null || endTime == null || 
        other.startTime == null || other.endTime == null) {
      return false;
    }
    
    // Check if time ranges overlap
    return startTime!.isBefore(other.endTime!) && 
           endTime!.isAfter(other.startTime!);
  }
  
  // Get duration in minutes
  int get durationMinutes {
    if (startTime == null || endTime == null) return 0;
    return endTime!.difference(startTime!).inMinutes;
  }
}
