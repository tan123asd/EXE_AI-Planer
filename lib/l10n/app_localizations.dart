import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Study Planner'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Balance Study, Life, and Growth'**
  String get tagline;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @haveUpdates.
  ///
  /// In en, this message translates to:
  /// **'Do you have any updates for today?'**
  String get haveUpdates;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'YES'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'NO'**
  String get no;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get navCalendar;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good Morning'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good Afternoon'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good Evening'**
  String get greetingEvening;

  /// No description provided for @todayOverview.
  ///
  /// In en, this message translates to:
  /// **'TODAY OVERVIEW'**
  String get todayOverview;

  /// No description provided for @planCompletion.
  ///
  /// In en, this message translates to:
  /// **'Plan completion'**
  String get planCompletion;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'done'**
  String get done;

  /// No description provided for @tasksToday.
  ///
  /// In en, this message translates to:
  /// **'Tasks today'**
  String get tasksToday;

  /// No description provided for @dayStreak.
  ///
  /// In en, this message translates to:
  /// **'Day streak'**
  String get dayStreak;

  /// No description provided for @focusHours.
  ///
  /// In en, this message translates to:
  /// **'Focus hours'**
  String get focusHours;

  /// No description provided for @todaySubjectBalance.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S SUBJECT BALANCE'**
  String get todaySubjectBalance;

  /// No description provided for @todaySchedule.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Schedule'**
  String get todaySchedule;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @noTasksYet.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet'**
  String get noTasksYet;

  /// No description provided for @addFirstTask.
  ///
  /// In en, this message translates to:
  /// **'Tap the + button to add your first task'**
  String get addFirstTask;

  /// No description provided for @recurringSchedules.
  ///
  /// In en, this message translates to:
  /// **'Recurring Schedules'**
  String get recurringSchedules;

  /// No description provided for @weeklyRoutines.
  ///
  /// In en, this message translates to:
  /// **'Your weekly routines'**
  String get weeklyRoutines;

  /// No description provided for @noRecurringSchedules.
  ///
  /// In en, this message translates to:
  /// **'No recurring schedules'**
  String get noRecurringSchedules;

  /// No description provided for @addWeeklySchedules.
  ///
  /// In en, this message translates to:
  /// **'Add schedules that repeat weekly'**
  String get addWeeklySchedules;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @until.
  ///
  /// In en, this message translates to:
  /// **'Until'**
  String get until;

  /// No description provided for @coachNoTasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet. Add your first item to generate a smarter plan.'**
  String get coachNoTasks;

  /// No description provided for @coachAllDone.
  ///
  /// In en, this message translates to:
  /// **'Everything planned for today is completed. Keep the momentum going.'**
  String get coachAllDone;

  /// No description provided for @coachItemsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} items left today. Finish the next one before switching context.'**
  String coachItemsLeft(int count);

  /// No description provided for @coachStartWith.
  ///
  /// In en, this message translates to:
  /// **'Start with {name}. It is the highest-effort item in your plan today.'**
  String coachStartWith(String name);

  /// No description provided for @partOf.
  ///
  /// In en, this message translates to:
  /// **'Part {part}/{total}'**
  String partOf(int part, int total);

  /// No description provided for @sessionOf.
  ///
  /// In en, this message translates to:
  /// **'Session {part}/{total}'**
  String sessionOf(int part, int total);

  /// No description provided for @sessions.
  ///
  /// In en, this message translates to:
  /// **'{count} sessions'**
  String sessions(int count);

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @helpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpSupport;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @studentRole.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get studentRole;

  /// No description provided for @productivityHours.
  ///
  /// In en, this message translates to:
  /// **'Productivity Hours'**
  String get productivityHours;

  /// No description provided for @productivityHoursDesc.
  ///
  /// In en, this message translates to:
  /// **'High-focus tasks are scheduled within these hours.'**
  String get productivityHoursDesc;

  /// No description provided for @noWindowsConfigured.
  ///
  /// In en, this message translates to:
  /// **'No windows configured. Tap Add to set your peak focus hours.'**
  String get noWindowsConfigured;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @editProfileInfo.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile Information'**
  String get editProfileInfo;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phone;

  /// No description provided for @bio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bio;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get logoutConfirm;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdated;

  /// No description provided for @endTimeError.
  ///
  /// In en, this message translates to:
  /// **'End time must be after start time'**
  String get endTimeError;

  /// No description provided for @loggedOut.
  ///
  /// In en, this message translates to:
  /// **'Logged out successfully'**
  String get loggedOut;

  /// No description provided for @selectStartFocus.
  ///
  /// In en, this message translates to:
  /// **'Select start of focus window'**
  String get selectStartFocus;

  /// No description provided for @selectEndFocus.
  ///
  /// In en, this message translates to:
  /// **'Select end of focus window'**
  String get selectEndFocus;

  /// No description provided for @aiScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Generated Schedule'**
  String get aiScheduleTitle;

  /// No description provided for @aiScheduleDesc.
  ///
  /// In en, this message translates to:
  /// **'Your personalized schedule has been generated based on your tasks and preferences.'**
  String get aiScheduleDesc;

  /// No description provided for @regenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get regenerate;

  /// No description provided for @saveSchedule.
  ///
  /// In en, this message translates to:
  /// **'Save Schedule'**
  String get saveSchedule;

  /// No description provided for @scheduleRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Schedule refreshed!'**
  String get scheduleRefreshed;

  /// No description provided for @scheduleSaved.
  ///
  /// In en, this message translates to:
  /// **'Schedule and task saved successfully!'**
  String get scheduleSaved;

  /// No description provided for @chatWelcome.
  ///
  /// In en, this message translates to:
  /// **'Hello! I am AI Planning Assistant 🤖\n\nType \"guide\" to see usage, or start right away:\n• Add task → \"add task ...\"\n• Add activity → \"add activity ...\"\n• Ask me anything about your schedule!'**
  String get chatWelcome;

  /// No description provided for @chatHelpText.
  ///
  /// In en, this message translates to:
  /// **'📖 USAGE GUIDE\n\n📌 TASK (with deadline or specific time):\n  Start with: \"add task\", \"add deadline\"\n  Example: \"add task team meeting 2h at 2pm on the 26th\"\n  Example: \"add task write report for subject — AI will suggest schedule\"\n\n🏃 ACTIVITY (hobbies/habits):\n  Start with: \"add activity\"\n  Example: \"add activity football 1h at 2pm on the 23rd\"\n  Example: \"add activity reading 1h every day, AI suggests time\"\n\n✏️ MANAGE:\n  \"move task [name] to [date]\"\n  \"delete task [name]\" / \"delete subtask [name]\"\n  \"delete activity [name]\" / \"move activity [name] X days\"\n  \"complete [task name]\"\n  \"today\'s schedule\" / \"this week\'s schedule\"'**
  String get chatHelpText;

  /// No description provided for @chipCreatePlan.
  ///
  /// In en, this message translates to:
  /// **'Create a Plan'**
  String get chipCreatePlan;

  /// No description provided for @chipModifyTask.
  ///
  /// In en, this message translates to:
  /// **'Modify Task'**
  String get chipModifyTask;

  /// No description provided for @chipMarkDone.
  ///
  /// In en, this message translates to:
  /// **'Mark Done'**
  String get chipMarkDone;

  /// No description provided for @chipReduceLoad.
  ///
  /// In en, this message translates to:
  /// **'Reduce Load'**
  String get chipReduceLoad;

  /// No description provided for @taskTypeSchedules.
  ///
  /// In en, this message translates to:
  /// **'Schedules'**
  String get taskTypeSchedules;

  /// No description provided for @taskTypeTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get taskTypeTask;

  /// No description provided for @taskTypeActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get taskTypeActivity;

  /// No description provided for @difficultyEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get difficultyEasy;

  /// No description provided for @difficultyMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get difficultyMedium;

  /// No description provided for @difficultyHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get difficultyHard;

  /// No description provided for @categoryStudy.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get categoryStudy;

  /// No description provided for @categoryPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get categoryPersonal;

  /// No description provided for @categoryHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get categoryHealth;

  /// No description provided for @categorySkill.
  ///
  /// In en, this message translates to:
  /// **'Skill'**
  String get categorySkill;

  /// No description provided for @categoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryOther;

  /// No description provided for @addTask.
  ///
  /// In en, this message translates to:
  /// **'Add Task'**
  String get addTask;

  /// No description provided for @sectionCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get sectionCategory;

  /// No description provided for @sectionTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Task Title'**
  String get sectionTaskTitle;

  /// No description provided for @sectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get sectionDescription;

  /// No description provided for @sectionDeadline.
  ///
  /// In en, this message translates to:
  /// **'Deadline'**
  String get sectionDeadline;

  /// No description provided for @sectionStartTime.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get sectionStartTime;

  /// No description provided for @sectionEndTime.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get sectionEndTime;

  /// No description provided for @sectionEndDateOptional.
  ///
  /// In en, this message translates to:
  /// **'End Date (Optional)'**
  String get sectionEndDateOptional;

  /// No description provided for @sectionDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration (minutes)'**
  String get sectionDuration;

  /// No description provided for @sectionDailyTimeLimit.
  ///
  /// In en, this message translates to:
  /// **'Daily Time Limit'**
  String get sectionDailyTimeLimit;

  /// No description provided for @sectionDates.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get sectionDates;

  /// No description provided for @sectionAiTimePlanning.
  ///
  /// In en, this message translates to:
  /// **'AI Time Planning'**
  String get sectionAiTimePlanning;

  /// No description provided for @sectionDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get sectionDifficulty;

  /// No description provided for @hintTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'e.g. Marketing presentation slides'**
  String get hintTaskTitle;

  /// No description provided for @hintDescription.
  ///
  /// In en, this message translates to:
  /// **'What needs to be done, key steps, and phases.'**
  String get hintDescription;

  /// No description provided for @hintDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'Enter duration in minutes'**
  String get hintDurationMinutes;

  /// No description provided for @hintSubtaskName.
  ///
  /// In en, this message translates to:
  /// **'Subtask name'**
  String get hintSubtaskName;

  /// No description provided for @selectDateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Select date and time'**
  String get selectDateAndTime;

  /// No description provided for @selectStartTime.
  ///
  /// In en, this message translates to:
  /// **'Select start time'**
  String get selectStartTime;

  /// No description provided for @selectEndTime.
  ///
  /// In en, this message translates to:
  /// **'Select end time'**
  String get selectEndTime;

  /// No description provided for @noEndDate.
  ///
  /// In en, this message translates to:
  /// **'No end date (runs forever)'**
  String get noEndDate;

  /// No description provided for @scheduleStopRepeating.
  ///
  /// In en, this message translates to:
  /// **'Schedule will stop repeating after this date'**
  String get scheduleStopRepeating;

  /// No description provided for @maxHoursPerDay.
  ///
  /// In en, this message translates to:
  /// **'Max hours to schedule for this task per day'**
  String get maxHoursPerDay;

  /// No description provided for @noLimit.
  ///
  /// In en, this message translates to:
  /// **'No limit'**
  String get noLimit;

  /// No description provided for @hoursPerDay.
  ///
  /// In en, this message translates to:
  /// **'{h}h / day'**
  String hoursPerDay(int h);

  /// No description provided for @validateTaskName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a task name'**
  String get validateTaskName;

  /// No description provided for @validateDescription.
  ///
  /// In en, this message translates to:
  /// **'Please enter a description'**
  String get validateDescription;

  /// No description provided for @validateTaskNameAndDesc.
  ///
  /// In en, this message translates to:
  /// **'Please fill in task name and description'**
  String get validateTaskNameAndDesc;

  /// No description provided for @validateScheduleRange.
  ///
  /// In en, this message translates to:
  /// **'Please fill in task name, dates, and time range'**
  String get validateScheduleRange;

  /// No description provided for @validateScheduleDuration.
  ///
  /// In en, this message translates to:
  /// **'Please fill in task name, dates, and duration'**
  String get validateScheduleDuration;

  /// No description provided for @pleaseSelectDay.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one day for recurring schedule'**
  String get pleaseSelectDay;

  /// No description provided for @pleaseSetStartEnd.
  ///
  /// In en, this message translates to:
  /// **'Please set start and end time for schedule'**
  String get pleaseSetStartEnd;

  /// No description provided for @pleaseSetDuration.
  ///
  /// In en, this message translates to:
  /// **'Please set a valid duration (minutes) for activity'**
  String get pleaseSetDuration;

  /// No description provided for @pleaseGenerateAI.
  ///
  /// In en, this message translates to:
  /// **'Please generate AI schedule again after your latest changes'**
  String get pleaseGenerateAI;

  /// No description provided for @aiWillEstimate.
  ///
  /// In en, this message translates to:
  /// **'AI will estimate effort automatically from task title, subject, notes, and difficulty.'**
  String get aiWillEstimate;

  /// No description provided for @aiRecommendation.
  ///
  /// In en, this message translates to:
  /// **'AI recommendation'**
  String get aiRecommendation;

  /// No description provided for @aiEstimateLabel.
  ///
  /// In en, this message translates to:
  /// **'AI Estimate'**
  String get aiEstimateLabel;

  /// No description provided for @estimatedEffort.
  ///
  /// In en, this message translates to:
  /// **'Estimated effort: '**
  String get estimatedEffort;

  /// No description provided for @suggestedSchedule.
  ///
  /// In en, this message translates to:
  /// **'Suggested schedule:'**
  String get suggestedSchedule;

  /// No description provided for @tapToSelect.
  ///
  /// In en, this message translates to:
  /// **'Tap to select/deselect  •  Tap '**
  String get tapToSelect;

  /// No description provided for @toAdjustTimes.
  ///
  /// In en, this message translates to:
  /// **' to adjust times'**
  String get toAdjustTimes;

  /// No description provided for @createYourOwnSlot.
  ///
  /// In en, this message translates to:
  /// **'Create your own slot'**
  String get createYourOwnSlot;

  /// No description provided for @selectedTime.
  ///
  /// In en, this message translates to:
  /// **'Selected Time'**
  String get selectedTime;

  /// No description provided for @adjustSchedule.
  ///
  /// In en, this message translates to:
  /// **'Adjust Schedule'**
  String get adjustSchedule;

  /// No description provided for @changeDatesAndTimes.
  ///
  /// In en, this message translates to:
  /// **'Change dates & times to fit your availability'**
  String get changeDatesAndTimes;

  /// No description provided for @resetBtn.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetBtn;

  /// No description provided for @confirmBtn.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmBtn;

  /// No description provided for @editBtn.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editBtn;

  /// No description provided for @editEstimatedEffort.
  ///
  /// In en, this message translates to:
  /// **'Edit Estimated Effort'**
  String get editEstimatedEffort;

  /// No description provided for @adjustHowLong.
  ///
  /// In en, this message translates to:
  /// **'Adjust how long this task should take. AI will regenerate schedule suggestions.'**
  String get adjustHowLong;

  /// No description provided for @applyAndRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Apply & Regenerate'**
  String get applyAndRegenerate;

  /// No description provided for @sessionLabel.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get sessionLabel;

  /// No description provided for @sessionNLabel.
  ///
  /// In en, this message translates to:
  /// **'Session {n}'**
  String sessionNLabel(int n);

  /// No description provided for @generating.
  ///
  /// In en, this message translates to:
  /// **'Generating...'**
  String get generating;

  /// No description provided for @generateSmartSchedule.
  ///
  /// In en, this message translates to:
  /// **'Generate Smart Schedule'**
  String get generateSmartSchedule;

  /// No description provided for @addSchedule.
  ///
  /// In en, this message translates to:
  /// **'Add Schedule'**
  String get addSchedule;

  /// No description provided for @addToMyPlan.
  ///
  /// In en, this message translates to:
  /// **'Add to My Plan'**
  String get addToMyPlan;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @tasksCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tasks'**
  String tasksCount(int count);

  /// No description provided for @countryVietnam.
  ///
  /// In en, this message translates to:
  /// **'Vietnam'**
  String get countryVietnam;

  /// No description provided for @chatPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Tell me your goal or ask anything...'**
  String get chatPlaceholder;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
