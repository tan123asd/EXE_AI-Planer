// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'AI Lập Lịch Học Tập';

  @override
  String get tagline => 'Cân bằng Học tập, Cuộc sống và Phát triển';

  @override
  String get getStarted => 'Bắt đầu';

  @override
  String get haveUpdates => 'Hôm nay bạn có gì cần cập nhật không?';

  @override
  String get yes => 'CÓ';

  @override
  String get no => 'KHÔNG';

  @override
  String get navHome => 'Trang chủ';

  @override
  String get navChat => 'Trò chuyện';

  @override
  String get navCalendar => 'Lịch';

  @override
  String get navProfile => 'Hồ sơ';

  @override
  String get greetingMorning => 'Chào buổi sáng';

  @override
  String get greetingAfternoon => 'Chào buổi chiều';

  @override
  String get greetingEvening => 'Chào buổi tối';

  @override
  String get todayOverview => 'TỔNG QUAN HÔM NAY';

  @override
  String get planCompletion => 'Hoàn thành kế hoạch';

  @override
  String get done => 'xong';

  @override
  String get tasksToday => 'Task hôm nay';

  @override
  String get dayStreak => 'Chuỗi ngày';

  @override
  String get focusHours => 'Giờ tập trung';

  @override
  String get todaySubjectBalance => 'CÂN BẰNG MÔN HỌC HÔM NAY';

  @override
  String get todaySchedule => 'Lịch hôm nay';

  @override
  String get viewAll => 'Xem tất cả';

  @override
  String get noTasksYet => 'Chưa có task';

  @override
  String get addFirstTask => 'Nhấn nút + để thêm task đầu tiên';

  @override
  String get recurringSchedules => 'Lịch cố định';

  @override
  String get weeklyRoutines => 'Lịch lặp hàng tuần';

  @override
  String get noRecurringSchedules => 'Không có lịch cố định';

  @override
  String get addWeeklySchedules => 'Thêm lịch lặp theo tuần';

  @override
  String get notSet => 'Chưa đặt';

  @override
  String get until => 'Đến';

  @override
  String get coachNoTasks =>
      'Chưa có task. Thêm mục đầu tiên để tạo kế hoạch thông minh hơn.';

  @override
  String get coachAllDone =>
      'Đã hoàn thành tất cả kế hoạch hôm nay. Tiếp tục phát huy nhé!';

  @override
  String coachItemsLeft(int count) {
    return 'Còn $count mục hôm nay. Hoàn thành mục tiếp theo trước khi chuyển sang việc khác.';
  }

  @override
  String coachStartWith(String name) {
    return 'Bắt đầu với $name. Đây là mục tốn công sức nhất trong kế hoạch hôm nay.';
  }

  @override
  String partOf(int part, int total) {
    return 'Phần $part/$total';
  }

  @override
  String sessionOf(int part, int total) {
    return 'Buổi $part/$total';
  }

  @override
  String sessions(int count) {
    return '$count buổi';
  }

  @override
  String get editProfile => 'Chỉnh sửa hồ sơ';

  @override
  String get notifications => 'Thông báo';

  @override
  String get settings => 'Cài đặt';

  @override
  String get helpSupport => 'Hỗ trợ';

  @override
  String get about => 'Giới thiệu';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get studentRole => 'Học sinh / Sinh viên';

  @override
  String get productivityHours => 'Giờ làm việc hiệu quả';

  @override
  String get productivityHoursDesc =>
      'Các task cần tập trung cao sẽ được xếp lịch trong khoảng giờ này.';

  @override
  String get noWindowsConfigured =>
      'Chưa cấu hình. Nhấn Thêm để đặt giờ tập trung cao nhất.';

  @override
  String get add => 'Thêm';

  @override
  String get editProfileInfo => 'Chỉnh sửa thông tin cá nhân';

  @override
  String get fullName => 'Họ và tên';

  @override
  String get email => 'Email';

  @override
  String get phone => 'Số điện thoại';

  @override
  String get bio => 'Giới thiệu bản thân';

  @override
  String get cancel => 'Hủy';

  @override
  String get save => 'Lưu';

  @override
  String get logout => 'Đăng xuất';

  @override
  String get logoutConfirm => 'Bạn có chắc muốn đăng xuất không?';

  @override
  String get profileUpdated => 'Cập nhật hồ sơ thành công!';

  @override
  String get endTimeError => 'Giờ kết thúc phải sau giờ bắt đầu';

  @override
  String get loggedOut => 'Đăng xuất thành công';

  @override
  String get selectStartFocus => 'Chọn giờ bắt đầu tập trung';

  @override
  String get selectEndFocus => 'Chọn giờ kết thúc tập trung';

  @override
  String get aiScheduleTitle => 'Lịch trình do AI tạo';

  @override
  String get aiScheduleDesc =>
      'Lịch trình cá nhân hoá đã được tạo dựa trên task và sở thích của bạn.';

  @override
  String get regenerate => 'Tạo lại';

  @override
  String get saveSchedule => 'Lưu lịch trình';

  @override
  String get scheduleRefreshed => 'Lịch đã được làm mới!';

  @override
  String get scheduleSaved => 'Lịch trình và task đã lưu thành công!';

  @override
  String get chatWelcome =>
      'Xin chào! Tôi là AI Planning Assistant 🤖\n\nGõ \"hướng dẫn\" để xem cách sử dụng, hoặc bắt đầu ngay:\n• Thêm task/công việc → \"thêm task ...\"\n• Thêm hoạt động → \"thêm hoạt động ...\"\n• Hỏi tôi bất cứ điều gì về lịch của bạn!';

  @override
  String get chatHelpText =>
      '📖 HƯỚNG DẪN SỬ DỤNG\n\n📌 TASK (có deadline hoặc giờ cụ thể):\n  Bắt đầu bằng: \"thêm task\", \"thêm 1 task\", \"thêm công việc\", \"thêm deadline\"\n  Ví dụ: \"thêm task họp nhóm 2h vào 14h ngày 26\"\n  Ví dụ: \"thêm task làm báo cáo cho môn học — AI sẽ gợi ý lịch trình\"\n\n🏃 HOẠT ĐỘNG (sở thích/thói quen):\n  Bắt đầu bằng: \"thêm hoạt động\", \"thêm 1 hoạt động\"\n  Ví dụ: \"thêm hoạt động đá bóng 1h vào 14h ngày 23\"\n  Ví dụ: \"thêm hoạt động đọc sách 1h mỗi ngày, AI gợi ý giờ\"\n\n✏️ QUẢN LÝ:\n  \"dời task [tên] sang [ngày]\"\n  \"xóa task [tên]\" / \"xóa subtask [tên]\"\n  \"xóa hoạt động [tên]\" / \"dời hoạt động [tên] X ngày\"\n  \"hoàn thành [tên task]\"\n  \"lịch hôm nay\" / \"lịch tuần này\"';

  @override
  String get chipCreatePlan => 'Lên kế hoạch';

  @override
  String get chipModifyTask => 'Chỉnh sửa task';

  @override
  String get chipMarkDone => 'Đánh dấu xong';

  @override
  String get chipReduceLoad => 'Giảm tải';

  @override
  String get taskTypeSchedules => 'Lịch cố định';

  @override
  String get taskTypeTask => 'Task';

  @override
  String get taskTypeActivity => 'Hoạt động';

  @override
  String get difficultyEasy => 'Dễ';

  @override
  String get difficultyMedium => 'Vừa';

  @override
  String get difficultyHard => 'Khó';

  @override
  String get categoryStudy => 'Học tập';

  @override
  String get categoryPersonal => 'Cá nhân';

  @override
  String get categoryHealth => 'Sức khoẻ';

  @override
  String get categorySkill => 'Kỹ năng';

  @override
  String get categoryOther => 'Khác';

  @override
  String get addTask => 'Thêm nhiệm vụ';

  @override
  String get sectionCategory => 'Loại';

  @override
  String get sectionTaskTitle => 'Tên nhiệm vụ';

  @override
  String get sectionDescription => 'Mô tả';

  @override
  String get sectionDeadline => 'Thời hạn';

  @override
  String get sectionStartTime => 'Giờ bắt đầu';

  @override
  String get sectionEndTime => 'Giờ kết thúc';

  @override
  String get sectionEndDateOptional => 'Ngày kết thúc (Tùy chọn)';

  @override
  String get sectionDuration => 'Thời lượng';

  @override
  String get sectionDailyTimeLimit => 'Giới hạn giờ mỗi ngày';

  @override
  String get sectionDates => 'Ngày trong tuần';

  @override
  String get sectionAiTimePlanning => 'AI Lập kế hoạch';

  @override
  String get sectionDifficulty => 'Độ khó';

  @override
  String get hintTaskTitle => 'Ví dụ: Thuyết trình marketing';

  @override
  String get hintDescription =>
      'Những việc cần làm, các bước và giai đoạn chính.';

  @override
  String get hintDurationMinutes => 'Nhập thời lượng';

  @override
  String get hintSubtaskName => 'Tên nhiệm vụ phụ';

  @override
  String get selectDateAndTime => 'Chọn ngày và giờ';

  @override
  String get selectStartTime => 'Chọn giờ bắt đầu';

  @override
  String get selectEndTime => 'Chọn giờ kết thúc';

  @override
  String get noEndDate => 'Không có ngày kết thúc (lặp mãi)';

  @override
  String get scheduleStopRepeating => 'Lịch sẽ dừng lặp sau ngày này';

  @override
  String get maxHoursPerDay => 'Số giờ tối đa cho nhiệm vụ này mỗi ngày';

  @override
  String get noLimit => 'Không giới hạn';

  @override
  String hoursPerDay(int h) {
    return '${h}h / ngày';
  }

  @override
  String get validateTaskName => 'Vui lòng nhập tên nhiệm vụ';

  @override
  String get validateDescription => 'Vui lòng nhập mô tả';

  @override
  String get validateTaskNameAndDesc => 'Vui lòng điền tên và mô tả nhiệm vụ';

  @override
  String get validateScheduleRange =>
      'Vui lòng điền tên, ngày và khoảng thời gian';

  @override
  String get validateScheduleDuration =>
      'Vui lòng điền tên, ngày và thời lượng';

  @override
  String get pleaseSelectDay => 'Vui lòng chọn ít nhất một ngày cho lịch lặp';

  @override
  String get pleaseSetStartEnd => 'Vui lòng đặt giờ bắt đầu và kết thúc';

  @override
  String get pleaseSetDuration => 'Vui lòng đặt thời lượng hợp lệ (phút)';

  @override
  String get pleaseGenerateAI => 'Vui lòng tạo lại lịch AI sau khi thay đổi';

  @override
  String get aiWillEstimate =>
      'AI sẽ tự động ước tính công sức từ tiêu đề, môn học, ghi chú và độ khó.';

  @override
  String get aiRecommendation => 'Đề xuất AI';

  @override
  String get aiEstimateLabel => 'Ước tính AI';

  @override
  String get estimatedEffort => 'Ước tính công sức: ';

  @override
  String get suggestedSchedule => 'Lịch đề xuất:';

  @override
  String get tapToSelect => 'Nhấn để chọn/bỏ chọn  •  Nhấn ';

  @override
  String get toAdjustTimes => ' để điều chỉnh giờ';

  @override
  String get createYourOwnSlot => 'Tạo khung giờ của bạn';

  @override
  String get selectedTime => 'Thời gian đã chọn';

  @override
  String get adjustSchedule => 'Điều chỉnh lịch';

  @override
  String get changeDatesAndTimes =>
      'Thay đổi ngày và giờ phù hợp với lịch của bạn';

  @override
  String get resetBtn => 'Đặt lại';

  @override
  String get confirmBtn => 'Xác nhận';

  @override
  String get editBtn => 'Sửa';

  @override
  String get editEstimatedEffort => 'Chỉnh sửa ước tính công sức';

  @override
  String get adjustHowLong =>
      'Điều chỉnh thời gian cần thiết. AI sẽ tạo lại đề xuất lịch.';

  @override
  String get applyAndRegenerate => 'Áp dụng & Tạo lại';

  @override
  String get sessionLabel => 'Buổi';

  @override
  String sessionNLabel(int n) {
    return 'Buổi $n';
  }

  @override
  String get generating => 'Đang tạo...';

  @override
  String get generateSmartSchedule => 'Tạo lịch thông minh';

  @override
  String get addSchedule => 'Thêm lịch';

  @override
  String get addToMyPlan => 'Thêm vào kế hoạch';

  @override
  String get refresh => 'Làm mới';

  @override
  String tasksCount(int count) {
    return '$count nhiệm vụ';
  }

  @override
  String get countryVietnam => 'Việt Nam';

  @override
  String get chatPlaceholder => 'Hãy nói mục tiêu hoặc hỏi bất cứ điều gì...';
}
