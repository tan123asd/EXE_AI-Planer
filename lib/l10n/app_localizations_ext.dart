import 'app_localizations.dart';

extension AppLocalizationsExt on AppLocalizations {
  String get enableNotifications =>
      localeName == 'vi' ? 'Bật thông báo' : 'Enable Notifications';

  String get notificationsDesc => localeName == 'vi'
      ? 'Nhận nhắc nhở thông minh để không bỏ lỡ bất kỳ task nào.'
      : 'Stay on top of your tasks with smart reminders.';

  String get upcomingReminders =>
      localeName == 'vi' ? 'Nhắc nhở sắp tới' : 'Upcoming Reminders';

  String get noUpcomingReminders => localeName == 'vi'
      ? 'Không có nhắc nhở sắp tới. Hãy thêm task để nhận thông báo.'
      : 'No upcoming reminders. Add tasks to receive notifications.';

  String get reminderRules =>
      localeName == 'vi' ? 'Cách hoạt động' : 'How Reminders Work';

  String get notifRuleSession => localeName == 'vi'
      ? '1 giờ trước mỗi buổi học bắt đầu'
      : '1 hour before each task session starts';

  String get notifRuleOverdue => localeName == 'vi'
      ? 'Cảnh báo khi task quá hạn mà chưa hoàn thành'
      : "Alert when a task deadline passes and it's still incomplete";

  String get settingsTitle => localeName == 'vi' ? 'Cài đặt' : 'Settings';

  String get appearance => localeName == 'vi' ? 'Giao diện' : 'Appearance';

  String get darkMode => localeName == 'vi' ? 'Chế độ tối' : 'Dark Mode';

  String get aboutTitle => localeName == 'vi'
      ? 'Giới thiệu AI Lập Lịch Học Tập'
      : 'About AI Study Planner';

  String get aboutDescription => localeName == 'vi'
      ? 'AI Lập Lịch Học Tập là người bạn đồng hành thông minh giúp bạn đạt thành tích học tập tốt nhất.\n\n'
          '🎯 Lịch trình thông minh — AI phân tích task, deadline và giờ tập trung cao của bạn để tạo ra kế hoạch ngày cá nhân hoá.\n\n'
          '💬 Lên kế hoạch qua chat — Chỉ cần mô tả mục tiêu bằng ngôn ngữ tự nhiên, AI sẽ tạo lịch học có cấu trúc cho bạn.\n\n'
          '📊 Theo dõi tiến độ — Theo dõi tỷ lệ hoàn thành, chuỗi ngày học và giờ tập trung để luôn có động lực.\n\n'
          '⏰ Nhắc nhở thông minh — Nhận thông báo 1 giờ trước mỗi buổi học và cảnh báo khi task quá hạn, không để sót việc.\n\n'
          '🌱 Được xây dựng cho học sinh, sinh viên muốn cân bằng học tập, cuộc sống và phát triển bản thân — tất cả trong một ứng dụng.'
      : 'AI Study Planner is your intelligent companion for academic success.\n\n'
          '🎯 Smart Scheduling — AI analyzes your tasks, deadlines, and peak-focus hours to build a personalized daily plan.\n\n'
          '💬 Chat Planning — Simply describe your goals in natural language and let the AI create a structured study schedule for you.\n\n'
          '📊 Progress Tracking — Monitor your completion rate, study streaks, and focus hours to stay motivated.\n\n'
          '⏰ Smart Reminders — Get notified 1 hour before each session and reminded of any overdue tasks so nothing slips through the cracks.\n\n'
          '🌱 Built for students who want to balance study, life, and personal growth — all in one place.';

  String get version => localeName == 'vi' ? 'Phiên bản' : 'Version';

  String get close => localeName == 'vi' ? 'Đóng' : 'Close';
}
