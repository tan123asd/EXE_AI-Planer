import '../models/chat_models.dart';

class ToolGuardrails {
  static String? validate(AiToolCall call) {
    return switch (call) {
      ShiftTaskCall(:final daysOffset) => daysOffset.abs() > 365
          ? 'daysOffset $daysOffset quá lớn (>365 ngày). Kiểm tra lại yêu cầu.'
          : null,
      AddTaskDirectCall(
        :final specificDate,
        :final durationMinutes,
        :final specificStartHour
      ) =>
        _validateAddTask(specificDate, durationMinutes, specificStartHour),
      AdjustWorkloadCall(:final direction) =>
        !['lighter', 'heavier'].contains(direction)
            ? 'direction phải là "lighter" hoặc "heavier", nhận được: "$direction"'
            : null,
      AddActivityCall(:final durationMinutes) =>
        (durationMinutes <= 0 || durationMinutes > 480)
            ? 'durationMinutes $durationMinutes không hợp lệ (phải 1–480)'
            : null,
      CollectPlanInfoCall(:final dailyHours) =>
        (dailyHours != null && (dailyHours <= 0 || dailyHours > 24))
            ? 'dailyHours $dailyHours không hợp lệ (phải 0.5–24)'
            : null,
      ShiftActivityCall(:final daysOffset) => daysOffset.abs() > 365
          ? 'daysOffset $daysOffset quá lớn (>365 ngày). Kiểm tra lại yêu cầu.'
          : null,
      _ => null,
    };
  }

  static String? _validateAddTask(
      String date, int duration, int startHour) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) {
      return 'Định dạng ngày không hợp lệ: "$date" (cần YYYY-MM-DD)';
    }
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    if (parsed.isBefore(DateTime(yesterday.year, yesterday.month, yesterday.day))) {
      return 'Ngày "$date" đã qua, kiểm tra lại yêu cầu người dùng';
    }
    if (parsed.isAfter(DateTime.now().add(const Duration(days: 730)))) {
      return 'Ngày "$date" quá xa (>2 năm)';
    }
    if (duration <= 0 || duration > 480) {
      return 'durationMinutes $duration không hợp lệ (phải 1–480)';
    }
    if (startHour < 6 || startHour > 22) {
      return 'specificStartHour $startHour ngoài khoảng cho phép (6–22)';
    }
    return null;
  }
}
