// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AI Study Planner';

  @override
  String get tagline => 'Balance Study, Life, and Growth';

  @override
  String get getStarted => 'Get Started';

  @override
  String get haveUpdates => 'Do you have any updates for today?';

  @override
  String get yes => 'YES';

  @override
  String get no => 'NO';

  @override
  String get navHome => 'Home';

  @override
  String get navChat => 'Chat';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navProfile => 'Profile';

  @override
  String get greetingMorning => 'Good Morning';

  @override
  String get greetingAfternoon => 'Good Afternoon';

  @override
  String get greetingEvening => 'Good Evening';

  @override
  String get todayOverview => 'TODAY OVERVIEW';

  @override
  String get planCompletion => 'Plan completion';

  @override
  String get done => 'done';

  @override
  String get tasksToday => 'Tasks today';

  @override
  String get dayStreak => 'Day streak';

  @override
  String get focusHours => 'Focus hours';

  @override
  String get todaySubjectBalance => 'TODAY\'S SUBJECT BALANCE';

  @override
  String get todaySchedule => 'Today\'s Schedule';

  @override
  String get viewAll => 'View all';

  @override
  String get noTasksYet => 'No tasks yet';

  @override
  String get addFirstTask => 'Tap the + button to add your first task';

  @override
  String get recurringSchedules => 'Recurring Schedules';

  @override
  String get weeklyRoutines => 'Your weekly routines';

  @override
  String get noRecurringSchedules => 'No recurring schedules';

  @override
  String get addWeeklySchedules => 'Add schedules that repeat weekly';

  @override
  String get notSet => 'Not set';

  @override
  String get until => 'Until';

  @override
  String get coachNoTasks =>
      'No tasks yet. Add your first item to generate a smarter plan.';

  @override
  String get coachAllDone =>
      'Everything planned for today is completed. Keep the momentum going.';

  @override
  String coachItemsLeft(int count) {
    return '$count items left today. Finish the next one before switching context.';
  }

  @override
  String coachStartWith(String name) {
    return 'Start with $name. It is the highest-effort item in your plan today.';
  }

  @override
  String partOf(int part, int total) {
    return 'Part $part/$total';
  }

  @override
  String sessionOf(int part, int total) {
    return 'Session $part/$total';
  }

  @override
  String sessions(int count) {
    return '$count sessions';
  }

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get notifications => 'Notifications';

  @override
  String get settings => 'Settings';

  @override
  String get helpSupport => 'Help & Support';

  @override
  String get about => 'About';

  @override
  String get language => 'Language';

  @override
  String get studentRole => 'Student';

  @override
  String get productivityHours => 'Productivity Hours';

  @override
  String get productivityHoursDesc =>
      'High-focus tasks are scheduled within these hours.';

  @override
  String get noWindowsConfigured =>
      'No windows configured. Tap Add to set your peak focus hours.';

  @override
  String get add => 'Add';

  @override
  String get editProfileInfo => 'Edit Profile Information';

  @override
  String get fullName => 'Full Name';

  @override
  String get email => 'Email';

  @override
  String get phone => 'Phone Number';

  @override
  String get bio => 'Bio';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get logout => 'Logout';

  @override
  String get logoutConfirm => 'Are you sure you want to logout?';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountConfirm =>
      'This permanently deletes your account and all your data. This action cannot be undone.';

  @override
  String get deleteAccountError => 'Account deletion failed';

  @override
  String get accountDeleted => 'Account deleted successfully';

  @override
  String get delete => 'Delete';

  @override
  String get profileUpdated => 'Profile updated successfully!';

  @override
  String get endTimeError => 'End time must be after start time';

  @override
  String get loggedOut => 'Logged out successfully';

  @override
  String get selectStartFocus => 'Select start of focus window';

  @override
  String get selectEndFocus => 'Select end of focus window';

  @override
  String get aiScheduleTitle => 'AI Generated Schedule';

  @override
  String get aiScheduleDesc =>
      'Your personalized schedule has been generated based on your tasks and preferences.';

  @override
  String get regenerate => 'Regenerate';

  @override
  String get saveSchedule => 'Save Schedule';

  @override
  String get scheduleRefreshed => 'Schedule refreshed!';

  @override
  String get scheduleSaved => 'Schedule and task saved successfully!';

  @override
  String get chatWelcome =>
      'Hello! I am AI Planning Assistant 🤖\n\nType \"guide\" to see usage, or start right away:\n• Add task → \"add task ...\"\n• Add activity → \"add activity ...\"\n• Ask me anything about your schedule!';

  @override
  String get chatHelpText =>
      '📖 USAGE GUIDE\n\n📌 TASK (with deadline or specific time):\n  Start with: \"add task\", \"add deadline\"\n  Example: \"add task team meeting 2h at 2pm on the 26th\"\n  Example: \"add task write report for subject — AI will suggest schedule\"\n\n🏃 ACTIVITY (hobbies/habits):\n  Start with: \"add activity\"\n  Example: \"add activity football 1h at 2pm on the 23rd\"\n  Example: \"add activity reading 1h every day, AI suggests time\"\n\n✏️ MANAGE:\n  \"move task [name] to [date]\"\n  \"delete task [name]\" / \"delete subtask [name]\"\n  \"delete activity [name]\" / \"move activity [name] X days\"\n  \"complete [task name]\"\n  \"today\'s schedule\" / \"this week\'s schedule\"';

  @override
  String get chipCreatePlan => 'Create a Plan';

  @override
  String get chipModifyTask => 'Modify Task';

  @override
  String get chipMarkDone => 'Mark Done';

  @override
  String get chipReduceLoad => 'Reduce Load';

  @override
  String get taskTypeSchedules => 'Schedules';

  @override
  String get taskTypeTask => 'Task';

  @override
  String get taskTypeActivity => 'Activity';

  @override
  String get difficultyEasy => 'Easy';

  @override
  String get difficultyMedium => 'Medium';

  @override
  String get difficultyHard => 'Hard';

  @override
  String get categoryStudy => 'Study';

  @override
  String get categoryPersonal => 'Personal';

  @override
  String get categoryHealth => 'Health';

  @override
  String get categorySkill => 'Skill';

  @override
  String get categoryOther => 'Other';

  @override
  String get addTask => 'Add Task';

  @override
  String get sectionCategory => 'Category';

  @override
  String get sectionTaskTitle => 'Task Title';

  @override
  String get sectionDescription => 'Description';

  @override
  String get sectionDeadline => 'Deadline';

  @override
  String get sectionStartTime => 'Start time';

  @override
  String get sectionEndTime => 'End time';

  @override
  String get sectionEndDateOptional => 'End Date (Optional)';

  @override
  String get sectionDuration => 'Duration';

  @override
  String get sectionDailyTimeLimit => 'Daily Time Limit';

  @override
  String get sectionDates => 'Dates';

  @override
  String get sectionAiTimePlanning => 'AI Time Planning';

  @override
  String get sectionDifficulty => 'Difficulty';

  @override
  String get hintTaskTitle => 'e.g. Marketing presentation slides';

  @override
  String get hintDescription => 'What needs to be done, key steps, and phases.';

  @override
  String get hintDurationMinutes => 'Enter duration in minutes';

  @override
  String get hintSubtaskName => 'Subtask name';

  @override
  String get selectDateAndTime => 'Select date and time';

  @override
  String get selectStartTime => 'Select start time';

  @override
  String get selectEndTime => 'Select end time';

  @override
  String get noEndDate => 'No end date (runs forever)';

  @override
  String get scheduleStopRepeating =>
      'Schedule will stop repeating after this date';

  @override
  String get maxHoursPerDay => 'Max hours to schedule for this task per day';

  @override
  String get noLimit => 'No limit';

  @override
  String hoursPerDay(int h) {
    return '${h}h / day';
  }

  @override
  String get validateTaskName => 'Please enter a task name';

  @override
  String get validateDescription => 'Please enter a description';

  @override
  String get validateTaskNameAndDesc =>
      'Please fill in task name and description';

  @override
  String get validateScheduleRange =>
      'Please fill in task name, dates, and time range';

  @override
  String get validateScheduleDuration =>
      'Please fill in task name, dates, and duration';

  @override
  String get pleaseSelectDay =>
      'Please select at least one day for recurring schedule';

  @override
  String get pleaseSetStartEnd => 'Please set start and end time for schedule';

  @override
  String get pleaseSetDuration =>
      'Please set a valid duration (minutes) for activity';

  @override
  String get pleaseGenerateAI =>
      'Please generate AI schedule again after your latest changes';

  @override
  String get aiWillEstimate =>
      'AI will estimate effort automatically from task title, subject, notes, and difficulty.';

  @override
  String get aiRecommendation => 'AI recommendation';

  @override
  String get aiEstimateLabel => 'AI Estimate';

  @override
  String get estimatedEffort => 'Estimated effort: ';

  @override
  String get suggestedSchedule => 'Suggested schedule:';

  @override
  String get tapToSelect => 'Tap to select/deselect  •  Tap ';

  @override
  String get toAdjustTimes => ' to adjust times';

  @override
  String get createYourOwnSlot => 'Create your own slot';

  @override
  String get selectedTime => 'Selected Time';

  @override
  String get adjustSchedule => 'Adjust Schedule';

  @override
  String get changeDatesAndTimes =>
      'Change dates & times to fit your availability';

  @override
  String get resetBtn => 'Reset';

  @override
  String get confirmBtn => 'Confirm';

  @override
  String get editBtn => 'Edit';

  @override
  String get editEstimatedEffort => 'Edit Estimated Effort';

  @override
  String get adjustHowLong =>
      'Adjust how long this task should take. AI will regenerate schedule suggestions.';

  @override
  String get applyAndRegenerate => 'Apply & Regenerate';

  @override
  String get sessionLabel => 'Session';

  @override
  String sessionNLabel(int n) {
    return 'Session $n';
  }

  @override
  String get generating => 'Generating...';

  @override
  String get generateSmartSchedule => 'Generate Smart Schedule';

  @override
  String get addSchedule => 'Add Schedule';

  @override
  String get addToMyPlan => 'Add to My Plan';

  @override
  String get refresh => 'Refresh';

  @override
  String tasksCount(int count) {
    return '$count tasks';
  }

  @override
  String get countryVietnam => 'Vietnam';

  @override
  String get chatPlaceholder => 'Tell me your goal or ask anything...';
}
