import 'package:flutter/material.dart';
import 'dart:async' show unawaited;
import 'package:ai_study_planner/l10n/app_localizations.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';
import '../services/ai_service.dart';
import '../services/scheduler_service.dart';
import '../services/notification_service.dart';
import '../models/scheduler_models.dart';
import '../widgets/time_picker_12h.dart';
import 'package:intl/intl.dart';

class NewTaskInputScreen extends StatefulWidget {
  const NewTaskInputScreen({Key? key}) : super(key: key);

  @override
  State<NewTaskInputScreen> createState() => _NewTaskInputScreenState();
}

class _NewTaskInputScreenState extends State<NewTaskInputScreen> 
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final StorageService _storage = StorageService();
  final AiService _aiService = AiService();
  final SchedulerService _schedulerService = SchedulerService();
  final TextEditingController _taskNameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _activityDurationController = TextEditingController();
  final TextEditingController _customSubtaskNameController = TextEditingController();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  String _taskName = '';
  String _difficulty = 'Medium';
  String _taskType = 'Task'; // 🔧 Task (with deadline) or Schedules (recurring with fixed time)
  DateTime? _deadline;
  TimeOfDay? _deadlineTime;
  TimeOfDay? _scheduleStartTime; // 🆕 For Schedules only
  TimeOfDay? _scheduleEndTime; // 🆕 For Schedules only
  DateTime? _scheduleEndDate; // 🆕 End date for recurring schedules
  Set<int> _selectedWeekdays = {}; // 🆕 For recurring schedules (1=Monday, 7=Sunday)
  String _category = 'Study'; // 🔧 Single category instead of set
  String _notes = '';
  bool _showAIPreview = false;
  bool _isGenerating = false;
  bool _isDeadlineManuallySet = false;
  int? _selectedSuggestionIndex;
  String _lastGeneratedSignature = '';
  int? _activityDurationMinutes;
  int? _dailyHoursLimit; // null = no cap
  // Task: multi-select AI slots + custom slots
  final Set<int> _selectedSuggestionIndices = {};
  final Map<int, Set<int>> _selectedSessionsPerOption = {};
  final List<Map<String, dynamic>> _customSlots = [];
  DateTime? _customSlotDate;
  TimeOfDay? _customSlotStart;
  TimeOfDay? _customSlotEnd;
  
  // AI Preview data
  String _aiEstimatedEffort = '';
  int? _aiEstimatedMinutes;
  int? _manualEstimatedMinutesOverride;
  List<String> _aiSuggestedSlots = [];
  List<DateTime> _aiSuggestedStartTimes = [];
  List<List<Map<String, dynamic>>> _aiSuggestedSessionGroups = [];
  List<List<Map<String, dynamic>>> _editedSessionGroups = [];
  Set<int> _userEditedOptions = <int>{};

  final List<String> _difficulties = ['Easy', 'Medium', 'Hard'];
  final List<String> _taskTypes = ['Schedules', 'Task', 'Activity'];
  final List<String> _categories = ['Study', 'Personal', 'Health', 'Skill', 'Other'];

  @override
  void initState() {
    super.initState();
    // Hot-reload safety: ensure collection fields are never null in existing State objects
    _aiSuggestedSlots = _aiSuggestedSlots;
    _aiSuggestedStartTimes = _aiSuggestedStartTimes;
    _aiSuggestedSessionGroups = _aiSuggestedSessionGroups;
    _editedSessionGroups = _editedSessionGroups ?? [];
    _userEditedOptions = _userEditedOptions ?? <int>{};
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _taskNameController.dispose();
    _notesController.dispose();
    _activityDurationController.dispose();
    _customSubtaskNameController.dispose();
    super.dispose();
  }

  Future<void> _selectDeadline(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker12h(
        context,
        initialTime: _deadlineTime ?? TimeOfDay.now(),
      );
      
      if (pickedTime != null) {
        setState(() {
          _deadline = pickedDate;
          _deadlineTime = pickedTime;
          _isDeadlineManuallySet = true;
          _selectedSuggestionIndex = null; // 🔧 Reset selection since user manually picked time
          _invalidateAIPreviewState();
        });
      }
    }
  }

  void _generateAIEstimate() async {
    final l10n = AppLocalizations.of(context)!;
    // 🔧 Validation based on task type
    bool isValid = false;
    String errorMessage = '';

    if (_taskType == 'Task') {
      // Task validation: task title and description required.
      isValid = _formKey.currentState!.validate();
      errorMessage = l10n.validateTaskNameAndDesc;
    } else if (_taskType == 'Schedules') {
      // Schedules validation: needs weekdays and start/end time
      isValid = _formKey.currentState!.validate() &&
                _selectedWeekdays.isNotEmpty &&
                _scheduleStartTime != null &&
                _scheduleEndTime != null;
      errorMessage = l10n.validateScheduleRange;

      if (isValid && !_isValidScheduleTimeRange(_scheduleStartTime!, _scheduleEndTime!)) {
        isValid = false;
        errorMessage = l10n.endTimeError;
      }
    } else {
      // Activity validation: needs weekdays + duration minutes
      isValid = _formKey.currentState!.validate() &&
          _selectedWeekdays.isNotEmpty &&
          _activityDurationMinutes != null &&
          _activityDurationMinutes! > 0;
      errorMessage = l10n.validateScheduleDuration;
    }
    
    if (isValid) {
      _formKey.currentState!.save();
      
      setState(() {
        _isGenerating = true;
      });
      
      // === TASK TYPE: call AI API then run scheduler ===
      if (_taskType == 'Task') {
        _aiSuggestedSlots = [];
        _aiSuggestedStartTimes = [];
        _aiSuggestedSessionGroups = [];

        final now = DateTime.now();
        final effectiveDeadline = _deadline ?? now.add(const Duration(days: 7));
        final priorityStr = _difficulty == 'Hard'
            ? 'high'
            : _difficulty == 'Easy'
                ? 'low'
                : 'medium';

        AiTaskPlan? plan;
        String? apiWarning;

        try {
          final taskText = _taskNameController.text.trim();
          final notesText = _notesController.text.trim();
          final isVi = taskText.runes.any((r) => r > 127) ||
              notesText.runes.any((r) => r > 127);
          final dailyConstraint = _dailyHoursLimit != null
              ? 'HARD CONSTRAINT: User can only work $_dailyHoursLimit hour${_dailyHoursLimit == 1 ? '' : 's'} per day on this task. '
                'Each subtask duration MUST be ≤ ${_dailyHoursLimit}h. '
                'Do NOT generate any subtask longer than ${_dailyHoursLimit}h.'
              : '';
          final combinedNotes = [notesText, dailyConstraint]
              .where((s) => s.isNotEmpty)
              .join(' ');
          plan = await _aiService.generateTaskPlan(
            taskName: taskText,
            notes: combinedNotes.isNotEmpty ? combinedNotes : taskText,
            difficulty: _difficulty,
            category: _category,
            deadline: effectiveDeadline,
            priority: priorityStr,
            language: isVi ? 'Vietnamese' : 'English',
          );
        } on AiServiceException catch (e) {
          apiWarning = e.message;
        } catch (e) {
          apiWarning = 'AI API error: $e';
        }

        if (plan == null) {
          // Fallback: build a single-subtask plan from local heuristics
          int totalMinutes = _manualEstimatedMinutesOverride ?? _estimateTaskMinutesBySignals();
          if (_difficulty == 'Hard') totalMinutes = (totalMinutes * 1.5).round();
          if (_difficulty == 'Easy') totalMinutes = (totalMinutes * 0.8).round();
          final accuracy = _storage.getEstimateAccuracy();
          if ((accuracy['totalTasks'] as int) > 5 &&
              (accuracy['averageAccuracy'] as int) < 80) {
            totalMinutes = (totalMinutes * 1.2).round();
          }
          totalMinutes = ((totalMinutes + 15) ~/ 30) * 30;
          totalMinutes = totalMinutes.clamp(30, 480);

          plan = AiTaskPlan(
            createdAt: now,
            deadline: effectiveDeadline,
            priority: priorityStr,
            tasks: [
              AiSubtask(
                order: 1,
                name: _taskNameController.text.trim(),
                duration: (totalMinutes / 60).ceilToDouble(),
                focusLevel: _difficulty == 'Hard' ? 'high' : 'medium',
                minBlock: totalMinutes <= 120 ? 1.0 : 2.0,
                preferredTime:
                    _difficulty == 'Hard' ? 'high_focus' : 'flexible',
              ),
            ],
          );
        }

        _aiEstimatedMinutes = plan.totalDurationMinutes;
        _aiEstimatedEffort = _formatEstimatedEffort(plan.totalDurationMinutes);

        // Build SchedulerConfig from stored productivity hours
        final productivityWindows = _storage
            .getProductivityHours()
            .map((m) => ProductivityWindow.fromMap(m))
            .toList();
        final config = SchedulerConfig(
          productivityWindows: productivityWindows,
          searchFrom: now,
          deadline: effectiveDeadline,
          maxMinutesPerDay:
              _dailyHoursLimit != null ? _dailyHoursLimit! * 60 : null,
        );

        final occupiedRanges =
            _storage.getOccupiedTimeRanges(now, effectiveDeadline);

        final result = _schedulerService.scheduleDeadlinePlan(
            plan, config, occupiedRanges);

        // Group scheduled slots by taskId (each subtask becomes one card)
        final grouped = <String, List<ScheduledSlot>>{};
        for (final slot in result.scheduledSlots) {
          grouped.putIfAbsent(slot.taskId, () => []).add(slot);
        }

        final breakSettings = _storage.getBreakSettings();
        final needsBreaks = plan.totalDurationMinutes > 60 &&
            (breakSettings['enabled'] as bool? ?? true);

        for (final entry in grouped.entries) {
          final slots = entry.value;
          final subtask = plan.tasks.firstWhere(
            (t) => t.order.toString() == entry.key,
            orElse: () => plan!.tasks.first,
          );

          _aiSuggestedStartTimes.add(slots.first.startTime);

          final sessions = slots
              .map((s) => {
                    'startTime': s.startTime.toIso8601String(),
                    'endTime': s.endTime.toIso8601String(),
                    'duration': s.durationMinutes,
                    'taskName': subtask.name,
                  })
              .toList();
          _aiSuggestedSessionGroups.add(sessions);

          final lines = slots.asMap().entries.map((e) {
            final idx = e.key;
            final s = e.value;
            final datePart = DateFormat('EEE, MMM d').format(s.startTime);
            final timePart =
                '${_formatTimeWith24H(s.startTime)} – ${_formatTimeWith24H(s.endTime, isRangeEnd: true)}';
            if (slots.length == 1) return '$datePart • $timePart';
            return 'S${idx + 1}: $datePart • $timePart';
          }).join('\n');

          String cardText = subtask.name;
          if (slots.length > 1) cardText += ' • ${slots.length} sessions';
          cardText += '\n$lines';
          if (needsBreaks && subtask.duration * 60 > 60) {
            cardText +=
                '\n⏱️ ${breakSettings['workDuration'] ?? 50}min work / ${breakSettings['breakDuration'] ?? 10}min break';
          }
          _aiSuggestedSlots.add(cardText);
        }

        if (result.failedTasks.isNotEmpty) {
          final names =
              result.failedTasks.map((t) => t.name).join(', ');
          _aiSuggestedSlots.add(
            '⚠️ Cannot fit before deadline: $names. '
            'Consider extending deadline or reducing scope.',
          );
        }

        if (_aiSuggestedSlots.isEmpty) {
          _aiSuggestedSlots
              .add('⚠️ No available slots found before the deadline.');
        }

        if (apiWarning != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('AI API unavailable — used local estimate. ($apiWarning)'),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 4),
            ),
          );
        }

        _selectedSuggestionIndex = null;
        _selectedSuggestionIndices.clear();
        _selectedSessionsPerOption.clear();
        if (_aiSuggestedStartTimes.isNotEmpty && !_isDeadlineManuallySet) {
          final first = _aiSuggestedStartTimes.first;
          _deadline =
              DateTime(first.year, first.month, first.day);
          _deadlineTime =
              TimeOfDay(hour: first.hour, minute: first.minute);
        }

        _editedSessionGroups = _aiSuggestedSessionGroups
            .map((g) => g.map((s) => Map<String, dynamic>.from(s)).toList())
            .toList();
        _userEditedOptions = {};
        _lastGeneratedSignature = _buildPlanningSignature();
      } else {
        // === PREVIEW FOR SCHEDULES / ACTIVITY ===
        _aiEstimatedMinutes = null;
        _aiSuggestedSlots = [];
        _aiSuggestedStartTimes = [];
        _aiSuggestedSessionGroups = [];

        // Format weekdays
        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final weekdaysList = _selectedWeekdays.toList()..sort();
        final weekdaysText = weekdaysList.map((d) => days[d - 1]).join(', ');

        if (_taskType == 'Schedules') {
          // Format time range in 24h display.
          final startTimeText = _formatTimeOfDay24H(_scheduleStartTime!);
          final endTimeText = _formatTimeOfDay24H(_scheduleEndTime!, isRangeEnd: true);

          _aiEstimatedEffort = 'Recurring schedule';
          _aiSuggestedSlots.add('📅 Every $weekdaysText\n🕐 $startTimeText – $endTimeText');
        } else {
          // Activity: use SchedulerService to find conflict-free slots on preferred weekdays
          final mins = (_activityDurationMinutes ?? 0).clamp(1, 24 * 60);
          _aiEstimatedEffort = 'Recurring activity';
          _aiEstimatedMinutes = mins;

          final now = DateTime.now();
          final searchEnd = now.add(
              const Duration(days: SchedulerService.activityLookAheadDays));
          final productivityWindows = _storage
              .getProductivityHours()
              .map((m) => ProductivityWindow.fromMap(m))
              .toList();
          final actConfig = SchedulerConfig(
            productivityWindows: productivityWindows,
            searchFrom: now,
            deadline: searchEnd,
          );
          final actOccupied = _storage.getOccupiedTimeRanges(now, searchEnd);
          final actReq = ActivityRequest(
            name: _taskNameController.text.trim(),
            durationMinutes: mins,
            preferredWeekdays: _selectedWeekdays.toList(),
            category: _category,
          );
          final actSlots =
              _schedulerService.scheduleActivity(actReq, actConfig, actOccupied);

          for (final slot in actSlots) {
            _aiSuggestedStartTimes.add(slot.startTime);
            _aiSuggestedSessionGroups.add([
              {
                'startTime': slot.startTime.toIso8601String(),
                'endTime': slot.endTime.toIso8601String(),
                'duration': slot.durationMinutes,
              }
            ]);
            _aiSuggestedSlots.add(
              '${DateFormat('EEEE, MMM d').format(slot.startTime)} • '
              '${_formatTimeWith24H(slot.startTime)} – '
              '${_formatTimeWith24H(slot.endTime, isRangeEnd: true)}',
            );
          }

          if (_aiSuggestedSlots.isEmpty) {
            _aiSuggestedSlots.add(
              '📅 Every $weekdaysText\n⏱️ ${_formatEstimatedEffort(mins)}\n'
              '⚠️ No free slot on selected days in next 14 days',
            );
            _editedSessionGroups = [];
          } else {
            _editedSessionGroups = _aiSuggestedSessionGroups
                .map((g) => g.map((s) => Map<String, dynamic>.from(s)).toList())
                .toList();
          }
          _selectedSuggestionIndices.clear();
          _selectedSessionsPerOption.clear();
        }

        _lastGeneratedSignature = _buildPlanningSignature();
      }
      
      setState(() {
        _isGenerating = false;
        _showAIPreview = true;
      });
      
      _animationController.forward();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(errorMessage),
              ),
            ],
          ),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  int _estimateTaskMinutesBySignals() {
    final title = _taskNameController.text.trim().toLowerCase();
    final notes = _notesController.text.trim().toLowerCase();
    final combinedText = '$title $notes';

    int minutes;
    switch (_category) {
      case 'Study':
        minutes = 90;
        break;
      case 'Skill':
        minutes = 90;
        break;
      case 'Health':
        minutes = 60;
        break;
      case 'Personal':
        minutes = 45;
        break;
      default:
        minutes = 60;
    }

    final complexKeywords = RegExp(
      r'project|assignment|report|presentation|exam|revision|research|plan|strategy|build|implement|feature|debug|refactor|module',
    );
    final quickKeywords = RegExp(
      r'read|review|check|email|message|note|summary|flashcard|walk|stretch|cleanup',
    );

    if (complexKeywords.hasMatch(combinedText)) {
      minutes += 45;
    }
    if (quickKeywords.hasMatch(combinedText)) {
      minutes -= 20;
    }

    final wordCount = combinedText
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    if (wordCount >= 10) {
      minutes += 20;
    }
    if (wordCount >= 18) {
      minutes += 20;
    }

    if (RegExp(r'chapter\s*\d+|part\s*\d+|unit\s*\d+').hasMatch(combinedText)) {
      minutes += 20;
    }

    if (_difficulty == 'Easy') {
      minutes -= 10;
    } else if (_difficulty == 'Medium') {
      minutes += 15;
    } else {
      minutes += 35;
    }

    if (_deadline != null) {
      final totalHoursToDeadline = _deadline!.difference(DateTime.now()).inHours;
      if (totalHoursToDeadline > 0 && totalHoursToDeadline <= 24) {
        minutes += 15;
      }
    }

    minutes = minutes.clamp(30, 480);
    return ((minutes + 15) ~/ 30) * 30;
  }

  void _invalidateAIPreviewState() {
    _showAIPreview = false;
    _selectedSuggestionIndex = null;
    _selectedSuggestionIndices.clear();
    _selectedSessionsPerOption.clear();
    _customSlots.clear();
    _customSubtaskNameController.clear();
    _customSlotDate = null;
    _customSlotStart = null;
    _customSlotEnd = null;
    _aiEstimatedEffort = '';
    _aiEstimatedMinutes = null;
    _manualEstimatedMinutesOverride = null;
    _aiSuggestedSlots = <String>[];
    _aiSuggestedStartTimes = <DateTime>[];
    _aiSuggestedSessionGroups = <List<Map<String, dynamic>>>[];
    _editedSessionGroups = <List<Map<String, dynamic>>>[];
    _userEditedOptions = <int>{};
    _lastGeneratedSignature = '';
  }

  String _buildPlanningSignature() {
    final sortedWeekdays = _selectedWeekdays.toList()..sort();
    final startTime = _scheduleStartTime == null
        ? ''
        : '${_scheduleStartTime!.hour.toString().padLeft(2, '0')}:${_scheduleStartTime!.minute.toString().padLeft(2, '0')}';
    final endTime = _scheduleEndTime == null
        ? ''
        : '${_scheduleEndTime!.hour.toString().padLeft(2, '0')}:${_scheduleEndTime!.minute.toString().padLeft(2, '0')}';

    return [
      _taskType,
      _taskNameController.text.trim().toLowerCase(),
      _notesController.text.trim().toLowerCase(),
      _difficulty,
      _category,
      _deadline?.toIso8601String() ?? '',
      _deadlineTime == null
          ? ''
          : '${_deadlineTime!.hour.toString().padLeft(2, '0')}:${_deadlineTime!.minute.toString().padLeft(2, '0')}',
      sortedWeekdays.join(','),
      startTime,
      endTime,
      _scheduleEndDate?.toIso8601String() ?? '',
      _activityDurationMinutes?.toString() ?? '',
      _dailyHoursLimit?.toString() ?? '',
    ].join('|');
  }

  // Build display text for a suggestion card, reflecting any user edits
  String _buildSlotDisplayText(int optionIndex) {
    final editedSet = _userEditedOptions ?? <int>{};
    final editedGroups = _editedSessionGroups ?? <List<Map<String, dynamic>>>[];
    if (!editedSet.contains(optionIndex) ||
        optionIndex >= editedGroups.length) {
      return optionIndex < _aiSuggestedSlots.length
          ? _aiSuggestedSlots[optionIndex]
          : '';
    }
    final sessions = editedGroups[optionIndex];
    if (sessions.isEmpty) {
      return optionIndex < _aiSuggestedSlots.length
          ? _aiSuggestedSlots[optionIndex]
          : '';
    }
    final breakSettings = _storage.getBreakSettings();
    final totalMinutes = sessions.fold<int>(0, (sum, s) {
      final start = DateTime.parse(s['startTime'] as String);
      final end = DateTime.parse(s['endTime'] as String);
      return sum + end.difference(start).inMinutes;
    });
    final needsBreaks = totalMinutes > 60 && breakSettings['enabled'] as bool;

    final lines = sessions.asMap().entries.map((e) {
      final s = e.value;
      final start = DateTime.parse(s['startTime'] as String);
      final end = DateTime.parse(s['endTime'] as String);
      final datePart = DateFormat('EEE, MMM d').format(start);
      final timePart =
          '${_formatTimeWith24H(start)} – ${_formatTimeWith24H(end, isRangeEnd: true)}';
      if (sessions.length == 1) return '$datePart • $timePart';
      return 'S${e.key + 1}: $datePart • $timePart';
    }).join('\n');

    final originalFirstLine = optionIndex < _aiSuggestedSlots.length
        ? _aiSuggestedSlots[optionIndex].split('\n').first
        : '';
    final taskName =
        originalFirstLine.replaceAll(RegExp(r' • \d+ sessions$'), '');
    String header = taskName;
    if (sessions.length > 1) header += ' • ${sessions.length} sessions';

    String text = '$header\n$lines';
    if (needsBreaks) {
      text +=
          '\n⏱️ ${breakSettings['workDuration'] ?? 50}min work / ${breakSettings['breakDuration'] ?? 10}min break';
    }
    return text;
  }

  Widget _buildSessionCardContent(
    int index,
    bool isSelected,
    List<List<Map<String, dynamic>>> editedGroups,
  ) {
    final sessions =
        index < editedGroups.length ? editedGroups[index] : <Map<String, dynamic>>[];

    if (sessions.length <= 1) {
      return Text(
        _buildSlotDisplayText(index),
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: AppColors.textPrimary,
          height: 1.45,
        ),
      );
    }

    final breakSettings = _storage.getBreakSettings();
    final totalMinutes = sessions.fold<int>(0, (sum, s) {
      final start = DateTime.parse(s['startTime'] as String);
      final end = DateTime.parse(s['endTime'] as String);
      return sum + end.difference(start).inMinutes;
    });
    final needsBreaks = totalMinutes > 60 && breakSettings['enabled'] as bool;

    final firstLine = index < _aiSuggestedSlots.length
        ? _aiSuggestedSlots[index].split('\n').first
        : '';
    final taskName = firstLine.replaceAll(RegExp(r' • \d+ sessions$'), '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$taskName • ${sessions.length} sessions',
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        ...sessions.asMap().entries.map((e) {
          final sIdx = e.key;
          final s = e.value;
          final start = DateTime.parse(s['startTime'] as String);
          final end = DateTime.parse(s['endTime'] as String);
          final datePart = DateFormat('EEE, MMM d').format(start);
          final timePart =
              '${_formatTimeWith24H(start)} – ${_formatTimeWith24H(end, isRangeEnd: true)}';
          final isSessionSel =
              _selectedSessionsPerOption[index]?.contains(sIdx) ?? false;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                final set = _selectedSessionsPerOption.putIfAbsent(index, () => {});
                if (isSessionSel) {
                  set.remove(sIdx);
                  if (set.isEmpty) {
                    _selectedSuggestionIndices.remove(index);
                    _selectedSessionsPerOption.remove(index);
                  }
                } else {
                  set.add(sIdx);
                  _selectedSuggestionIndices.add(index);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(
                children: [
                  Icon(
                    isSessionSel
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 15,
                    color: isSessionSel
                        ? AppColors.primary
                        : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$datePart • $timePart',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSessionSel
                            ? FontWeight.w500
                            : FontWeight.w400,
                        color: isSessionSel
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        if (needsBreaks) ...[
          const SizedBox(height: 6),
          Text(
            '⏱️ ${breakSettings['workDuration'] ?? 50}min work / ${breakSettings['breakDuration'] ?? 10}min break',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  // Bottom sheet for user to manually adjust AI-suggested session times
  Future<void> _showEditSessionSheet(int optionIndex) async {
    final editedGroups = _editedSessionGroups ?? <List<Map<String, dynamic>>>[];
    if (optionIndex >= editedGroups.length) return;

    // Local mutable copy – applied to state only when user taps "Confirm"
    final localSessions = editedGroups[optionIndex]
        .map((s) => Map<String, dynamic>.from(s))
        .toList();
    bool changed = false;
    bool didReset = false;

    final ThemeData pickerTheme = Theme.of(context).copyWith(
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (builderCtx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 12,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(builderCtx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Header row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.edit_calendar,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.adjustSchedule,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              AppLocalizations.of(context)!.changeDatesAndTimes,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Reset to AI button
                      TextButton.icon(
                        onPressed: () {
                          final aiGroups = _aiSuggestedSessionGroups ?? <List<Map<String, dynamic>>>[];
                          if (optionIndex < aiGroups.length) {
                            final original = aiGroups[optionIndex]
                                .map((s) => Map<String, dynamic>.from(s))
                                .toList();
                            for (int i = 0; i < localSessions.length && i < original.length; i++) {
                              localSessions[i] = original[i];
                            }
                            changed = true;
                            didReset = true;
                          }
                          setSheetState(() {});
                        },
                        icon: const Icon(Icons.restart_alt, size: 15),
                        label: Text(AppLocalizations.of(context)!.resetBtn),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  // Session rows
                  ...localSessions.asMap().entries.map((entry) {
                    final sIdx = entry.key;
                    final session = localSessions[sIdx];
                    final start = DateTime.parse(session['startTime'] as String);
                    final end = DateTime.parse(session['endTime'] as String);
                    final duration = session['duration'] as int;
                    final durationLabel = duration >= 60
                        ? '${duration ~/ 60}h${duration % 60 > 0 ? ' ${duration % 60}m' : ''}'
                        : '${duration}min';
                    final sl10n = AppLocalizations.of(context)!;
                    final sessionLabel = localSessions.length > 1
                        ? sl10n.sessionNLabel(sIdx + 1)
                        : sl10n.sessionLabel;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.15),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        sessionLabel,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          durationLabel,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    DateFormat('EEE, d MMM yyyy').format(start),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_formatTimeWith24H(start)} – ${_formatTimeWith24H(end, isRangeEnd: true)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final pickedDate = await showDatePicker(
                                  context: builderCtx,
                                  initialDate: start,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 180)),
                                  builder: (ctx, child) => Theme(
                                    data: pickerTheme,
                                    child: child!,
                                  ),
                                );
                                if (pickedDate == null) return;
                                final pickedTime = await showTimePicker12h(
                                  builderCtx,
                                  initialTime: TimeOfDay(
                                    hour: start.hour,
                                    minute: start.minute,
                                  ),
                                );
                                if (pickedTime == null) return;
                                final newStart = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                  pickedTime.hour,
                                  pickedTime.minute,
                                );
                                final newEnd =
                                    newStart.add(Duration(minutes: duration));
                                localSessions[sIdx] = {
                                  'startTime': newStart.toIso8601String(),
                                  'endTime': newEnd.toIso8601String(),
                                  'duration': duration,
                                };
                                changed = true;
                                didReset = false;
                                setSheetState(() {});
                              },
                              icon: const Icon(Icons.schedule, size: 15),
                              label: Text(AppLocalizations.of(context)!.editBtn),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 4),
                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.confirmBtn,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!changed || !mounted) return;
    setState(() {
      (_editedSessionGroups ?? <List<Map<String, dynamic>>>[]).length > optionIndex
          ? _editedSessionGroups![optionIndex] = localSessions
          : null;
      // Safer: ensure list is big enough
      while ((_editedSessionGroups ?? []).length <= optionIndex) {
        (_editedSessionGroups ??= []).add([]);
      }
      _editedSessionGroups![optionIndex] = localSessions;
      if (didReset) {
        (_userEditedOptions ?? <int>{}).remove(optionIndex);
      } else {
        (_userEditedOptions ??= <int>{}).add(optionIndex);
      }
      // Keep aiSuggestedStartTimes in sync with edited first session
      if (localSessions.isNotEmpty &&
          optionIndex < _aiSuggestedStartTimes.length) {
        _aiSuggestedStartTimes[optionIndex] =
            DateTime.parse(localSessions[0]['startTime'] as String);
      }
      // If this option is selected + deadline not manually set, sync deadline
      if (_selectedSuggestionIndex == optionIndex &&
          !_isDeadlineManuallySet &&
          localSessions.isNotEmpty) {
        final ns = DateTime.parse(localSessions[0]['startTime'] as String);
        _deadline = DateTime(ns.year, ns.month, ns.day);
        _deadlineTime = TimeOfDay(hour: ns.hour, minute: ns.minute);
      }
      // Re-capture signature so stale-check still passes after editing
      _lastGeneratedSignature = _buildPlanningSignature();
    });
  }

  String _formatEstimatedEffort(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) {
      return '$minutes min';
    }
    if (minutes == 0) {
      return '$hours hour${hours > 1 ? 's' : ''}';
    }
    return '${hours}h ${minutes}m';
  }

  Future<void> _showEditEstimatedEffortSheet() async {
    if (_taskType != 'Task' || _isGenerating) return;

    int selectedMinutes = _aiEstimatedMinutes ?? _manualEstimatedMinutesOverride ?? 60;
    selectedMinutes = selectedMinutes.clamp(30, 480);
    final quickOptions = <int>[30, 60, 90, 120, 150, 180, 240, 300, 360, 420, 480];

    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (builderCtx, setSheetState) {
            String formatLabel(int mins) => _formatEstimatedEffort(mins);

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: MediaQuery.of(builderCtx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.editEstimatedEffort,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppLocalizations.of(context)!.adjustHowLong,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          formatLabel(selectedMinutes),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: quickOptions.map((mins) {
                      final isSelected = selectedMinutes == mins;
                      return ChoiceChip(
                        label: Text(formatLabel(mins)),
                        selected: isSelected,
                        onSelected: (_) {
                          setSheetState(() {
                            selectedMinutes = mins;
                          });
                        },
                        selectedColor: AppColors.primary.withOpacity(0.18),
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : Colors.grey.shade300,
                        ),
                        backgroundColor: Colors.white,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: selectedMinutes.toDouble(),
                    min: 30,
                    max: 480,
                    divisions: 15,
                    label: formatLabel(selectedMinutes),
                    activeColor: AppColors.primary,
                    onChanged: (value) {
                      setSheetState(() {
                        selectedMinutes = ((value.round() + 15) ~/ 30) * 30;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(sheetCtx).pop(selectedMinutes),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.applyAndRegenerate,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;

    setState(() {
      _manualEstimatedMinutesOverride = result;
    });

    _generateAIEstimate();
  }

  // 24h formatter. If range ends at midnight, show 24:00.
  String _formatTimeWith24H(DateTime time, {bool isRangeEnd = false}) {
    if (isRangeEnd && time.hour == 0 && time.minute == 0) {
      return '24:00';
    }

    final hour = time.hour;
    final minute = time.minute;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  /// Builds the unified "Selected Time" list: AI sessions from checked options + custom slots.
  /// Each map has startTime, endTime, duration, and optionally _optionIndex/_sessionIndexInOption (AI) or _customIndex (custom).
  List<Map<String, dynamic>> _getSelectedTimeSlots() {
    final list = <Map<String, dynamic>>[];
    final editedGroups = _editedSessionGroups.isNotEmpty ? _editedSessionGroups : _aiSuggestedSessionGroups;
    for (final idx in _selectedSuggestionIndices) {
      if (idx >= editedGroups.length) continue;
      final sessions = editedGroups[idx];
      final selectedInOption = _selectedSessionsPerOption[idx];
      for (int s = 0; s < sessions.length; s++) {
        if (sessions.length > 1 &&
            selectedInOption != null &&
            !selectedInOption.contains(s)) continue;
        list.add({
          ...Map<String, dynamic>.from(sessions[s]),
          '_optionIndex': idx,
          '_sessionIndexInOption': s,
          '_customIndex': null,
        });
      }
    }
    for (int c = 0; c < _customSlots.length; c++) {
      list.add({
        ...Map<String, dynamic>.from(_customSlots[c]),
        '_optionIndex': null,
        '_sessionIndexInOption': null,
        '_customIndex': c,
      });
    }
    return list;
  }

  List<String> _findCustomSlotOverlaps(DateTime newStart, DateTime newEnd) {
    final conflicts = <String>[];
    for (final slot in _getSelectedTimeSlots()) {
      final sStr = slot['startTime'];
      final eStr = slot['endTime'];
      DateTime s, e;
      try {
        s = sStr is DateTime ? sStr : DateTime.parse(sStr as String);
        e = eStr is DateTime ? eStr : DateTime.parse(eStr as String);
      } catch (_) {
        continue;
      }
      if (!newStart.isBefore(e) || !s.isBefore(newEnd)) continue;
      final customIdx = slot['_customIndex'] as int?;
      if (customIdx != null && customIdx < _customSlots.length) {
        conflicts.add(
            _customSlots[customIdx]['taskName'] as String? ?? 'Custom slot');
      } else {
        final optIdx = slot['_optionIndex'] as int?;
        if (optIdx != null && optIdx < _aiSuggestedSlots.length) {
          final firstLine = _aiSuggestedSlots[optIdx].split('\n').first;
          conflicts
              .add(firstLine.replaceAll(RegExp(r' • \d+ sessions$'), ''));
        } else {
          conflicts.add('Scheduled slot');
        }
      }
    }
    // Also check against already-saved tasks/schedules/activities in storage
    if (_storage.hasScheduleConflict(newStart, newEnd)) {
      conflicts.add('Existing scheduled block');
    }
    return conflicts.toSet().toList(); // deduplicate
  }

  String _formatTimeOfDay24H(TimeOfDay time, {bool isRangeEnd = false}) {
    if (isRangeEnd && time.hour == 0 && time.minute == 0) {
      return '24:00';
    }
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  bool _isValidScheduleTimeRange(TimeOfDay start, TimeOfDay end) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    return endMinutes > startMinutes;
  }
  
  Future<void> _addTaskToPlan() async {
    final l10n = AppLocalizations.of(context)!;
    // For Task type, require a fresh AI preview before adding.
    if (_taskType == 'Task' &&
        (!_showAIPreview || _lastGeneratedSignature != _buildPlanningSignature())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.pleaseGenerateAI)),
            ],
          ),
          backgroundColor: AppColors.textPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    // 🔧 Validation for Schedules & Activities (recurring)
    if (_taskType == 'Schedules' || _taskType == 'Activity') {
      if (_selectedWeekdays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n.pleaseSelectDay)),
              ],
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }

      if (_taskType == 'Schedules') {
        if (_scheduleStartTime == null || _scheduleEndTime == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l10n.pleaseSetStartEnd)),
                ],
              ),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          return;
        }

        if (!_isValidScheduleTimeRange(_scheduleStartTime!, _scheduleEndTime!)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l10n.endTimeError)),
                ],
              ),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          return;
        }
      } else if (_taskType == 'Activity') {
        if (_activityDurationMinutes == null || _activityDurationMinutes! <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l10n.pleaseSetDuration)),
                ],
              ),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          return;
        }
        if (_showAIPreview && _aiSuggestedSessionGroups.isNotEmpty && _getSelectedTimeSlots().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.warning, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Please select at least one time slot or add your own'),
                  ),
                ],
              ),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          return;
        }
      }
    }
    
    // Validation for Task
    if (_taskType == 'Task' && (!_formKey.currentState!.validate() || _deadline == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.validateTaskNameAndDesc)),
            ],
          ),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    _formKey.currentState?.save();

    // Use AI-estimated minutes (only for Task type)
    int estimatedHours = 1;
    int estimatedMinutes = 60;
    if (_taskType == 'Task') {
      estimatedMinutes = _aiEstimatedMinutes ?? _manualEstimatedMinutesOverride ?? _estimateTaskMinutesBySignals();
      estimatedHours = (estimatedMinutes / 60).ceil();
    }
    
    // 🆕 Get break settings
    final breakSettings = _storage.getBreakSettings();

    // Task: use unified selected time (AI checked options + custom slots)
    final selectedTimeSlots = _getSelectedTimeSlots();
    final selectedSessions = selectedTimeSlots.map((m) {
      final copy = Map<String, dynamic>.from(m);
      copy.remove('_optionIndex');
      copy.remove('_sessionIndexInOption');
      copy.remove('_customIndex');
      if (copy['startTime'] is DateTime) copy['startTime'] = (copy['startTime'] as DateTime).toIso8601String();
      if (copy['endTime'] is DateTime) copy['endTime'] = (copy['endTime'] as DateTime).toIso8601String();
      return copy;
    }).toList();
    
    Map<String, dynamic> taskData;
    
    if (_taskType == 'Task') {
      // 🔧 Task: has deadline
      DateTime finalDeadline = _deadline!;
      if (_deadlineTime != null) {
        finalDeadline = DateTime(
          _deadline!.year,
          _deadline!.month,
          _deadline!.day,
          _deadlineTime!.hour,
          _deadlineTime!.minute,
        );
      }
      
      taskData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': _taskName,
        'subject': _taskType,
        'subjectColor': AppColors.subjectAccentColor(_taskType).toARGB32(),
        'difficulty': _difficulty,
        'deadline': finalDeadline.toIso8601String(),
        'estimatedTime': estimatedHours,
        'estimatedMinutes': estimatedMinutes,
        'category': _taskType,
        'taskType': 'Task',
        'notes': _notes,
        'createdAt': DateTime.now().toIso8601String(),
        // 🆕 Break reminders
        'needsBreak': estimatedHours > 1 && (breakSettings['enabled'] as bool? ?? true),
        'breakInterval': breakSettings['workDuration'] ?? 50,
        'breakDuration': breakSettings['breakDuration'] ?? 10,
        // 🆕 For performance tracking
        'startedAt': null,
        'completedAt': null,
        'actualTime': null,
        // AI sessions are tied to the selected suggestion option.
        'sessions': selectedSessions.isNotEmpty ? selectedSessions : null,
      };
    } else if (_taskType == 'Schedules') {
      // 🔧 Schedule: has fixed start/end time + recurring weekdays
      taskData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': _taskName,
        'subject': _taskType,
        'subjectColor': AppColors.subjectAccentColor(_taskType).toARGB32(),
        'difficulty': _difficulty,
        'category': _taskType,
        'taskType': _taskType,
        'weekdays': _selectedWeekdays.toList(),
        'startTime': '${_scheduleStartTime!.hour.toString().padLeft(2, '0')}:${_scheduleStartTime!.minute.toString().padLeft(2, '0')}',
        'endTime': '${_scheduleEndTime!.hour.toString().padLeft(2, '0')}:${_scheduleEndTime!.minute.toString().padLeft(2, '0')}',
        'scheduleEndDate': _scheduleEndDate?.toIso8601String(), // 🆕 Optional end date
        'notes': '',
        'createdAt': DateTime.now().toIso8601String(),
      };
    } else {
      // 🔧 Activity: recurring with duration; optional sessions when user selected AI/custom slots
      final activityMinutes = (_activityDurationMinutes ?? 60).clamp(1, 24 * 60);
      taskData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': _taskName,
        'subject': _taskType,
        'subjectColor': AppColors.subjectAccentColor(_taskType).toARGB32(),
        'difficulty': _difficulty,
        'category': _taskType,
        'taskType': 'Activity',
        'weekdays': _selectedWeekdays.toList(),
        'scheduleEndDate': _scheduleEndDate?.toIso8601String(),
        'estimatedMinutes': activityMinutes,
        'sessions': selectedSessions.isNotEmpty ? selectedSessions : null,
        'notes': '',
        'createdAt': DateTime.now().toIso8601String(),
      };
    }
    
    await _storage.addCustomTask(taskData);
    unawaited(NotificationService().scheduleAllNotifications());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('✨ Task added to your smart schedule!'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Easy':
        return AppColors.success;
      case 'Medium':
        return AppColors.medium;
      case 'Hard':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }

  // 🔧 Removed _getPriorityColor - no longer needed

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Study':
        return Icons.school;
      case 'Personal':
        return Icons.person;
      case 'Health':
        return Icons.favorite;
      case 'Skill':
        return Icons.auto_awesome;
      case 'Other':
        return Icons.more_horiz;
      default:
        return Icons.task;
    }
  }

  Color _getCategoryColor(String category) {
    return AppColors.subjectAccentColor(category);
  }

  String _getTaskTypeLabel(String type, AppLocalizations l10n) {
    switch (type) {
      case 'Task': return l10n.taskTypeTask;
      case 'Schedules': return l10n.taskTypeSchedules;
      case 'Activity': return l10n.taskTypeActivity;
      default: return type;
    }
  }

  String _getDifficultyLabel(String diff, AppLocalizations l10n) {
    switch (diff) {
      case 'Easy': return l10n.difficultyEasy;
      case 'Medium': return l10n.difficultyMedium;
      case 'Hard': return l10n.difficultyHard;
      default: return diff;
    }
  }

  Widget _buildSectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  // 🆕 Build weekday button for recurring schedules
  Widget _buildWeekdayButton(String label, int weekday) {
    final isSelected = _selectedWeekdays.contains(weekday);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedWeekdays.remove(weekday);
          } else {
            _selectedWeekdays.add(weekday);
          }
          _invalidateAIPreviewState();
        });
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primary 
              : AppColors.background,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected 
                ? AppColors.primary 
                : AppColors.textSecondary.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected 
                  ? Colors.white 
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
                          color: AppColors.textPrimary,
                          size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.addTask,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Category (Task / Schedules / Activity)
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel(l10n.sectionCategory, Icons.label_outlined),
                        const SizedBox(height: 16),
                        Row(
                          children: _taskTypes.map((type) {
                            final isSelected = _taskType == type;
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: type != _taskTypes.last ? 8.0 : 0,
                                ),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _taskType = type;
                                      if (type == 'Task') {
                                        _selectedWeekdays.clear();
                                      } else {
                                        _notesController.clear();
                                        _notes = '';
                                      }
                                      _invalidateAIPreviewState();
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.textSecondary.withOpacity(0.15)
                                          : AppColors.background,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.textPrimary
                                            : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _getTaskTypeLabel(type, l10n),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? AppColors.textPrimary
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 2. Task Title
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel(l10n.sectionTaskTitle, Icons.edit_outlined),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _taskNameController,
                          decoration: InputDecoration(
                            hintText: l10n.hintTaskTitle,
                            hintStyle: TextStyle(
                              color: Color(0xFFCCCCCC),
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.validateTaskName;
                            }
                            return null;
                          },
                          onChanged: (_) {
                            setState(() {
                              _invalidateAIPreviewState();
                            });
                          },
                          onSaved: (value) => _taskName = value ?? '',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 1b. Description (Task only, required)
                  if (_taskType == 'Task') ...[
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel(l10n.sectionDescription, Icons.description_outlined),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _notesController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: l10n.hintDescription,
                              hintStyle: const TextStyle(
                                color: Color(0xFFCCCCCC),
                                fontSize: 14,
                              ),
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            validator: (value) {
                              if (_taskType == 'Task' && (value == null || value.trim().isEmpty)) {
                                return l10n.validateDescription;
                              }
                              return null;
                            },
                            onChanged: (_) {
                              setState(() {
                                _invalidateAIPreviewState();
                              });
                            },
                            onSaved: (value) => _notes = value ?? '',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // 2b. Weekday Selector (for recurring types: Schedules/Activity)
                  if (_taskType == 'Schedules' || _taskType == 'Activity') ...[
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel(l10n.sectionDates, Icons.date_range_outlined),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildWeekdayButton('M', 1),
                              _buildWeekdayButton('T', 2),
                              _buildWeekdayButton('W', 3),
                              _buildWeekdayButton('T', 4),
                              _buildWeekdayButton('F', 5),
                              _buildWeekdayButton('S', 6),
                              _buildWeekdayButton('S', 7),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // 3. Deadline (only for Task type)
                  if (_taskType == 'Task') ...[
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel(l10n.sectionDeadline, Icons.calendar_today_outlined),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: () => _selectDeadline(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _deadline != null
                                      ? AppColors.primary.withOpacity(0.3)
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.event,
                                    color: _deadline != null
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _deadline != null && _deadlineTime != null
                                          ? '${DateFormat('d MMM yyyy').format(_deadline!)} • ${fmt12h(_deadlineTime!)}'
                                          : l10n.selectDateAndTime,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: _deadline != null
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: AppColors.textSecondary,
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // 3b. Time/Duration for recurring types
                  if (_taskType == 'Schedules') ...[
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel(l10n.sectionStartTime, Icons.access_time),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: () async {
                              final TimeOfDay? picked = await showTimePicker12h(
                                context,
                                initialTime: _scheduleStartTime ?? TimeOfDay.now(),
                              );
                              if (picked != null) {
                                setState(() {
                                  _scheduleStartTime = picked;
                                  _invalidateAIPreviewState();
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _scheduleStartTime != null 
                                      ? AppColors.primary.withOpacity(0.3)
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    color: _scheduleStartTime != null 
                                        ? AppColors.primary 
                                        : AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _scheduleStartTime != null
                                          ? fmt12h(_scheduleStartTime!)
                                          : l10n.selectStartTime,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: _scheduleStartTime != null
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: AppColors.textSecondary,
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel(l10n.sectionEndTime, Icons.access_time_filled),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: () async {
                              final TimeOfDay? picked = await showTimePicker12h(
                                context,
                                initialTime: _scheduleEndTime ?? TimeOfDay.now(),
                              );
                              if (picked != null) {
                                setState(() {
                                  _scheduleEndTime = picked;
                                  _invalidateAIPreviewState();
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _scheduleEndTime != null 
                                      ? AppColors.primary.withOpacity(0.3)
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    color: _scheduleEndTime != null 
                                        ? AppColors.primary 
                                        : AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _scheduleEndTime != null
                                          ? fmt12h(_scheduleEndTime!)
                                          : l10n.selectEndTime,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: _scheduleEndTime != null
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: AppColors.textSecondary,
                                    size: 14,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 🆕 End Date for Schedule
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel(l10n.sectionEndDateOptional, Icons.event_busy_outlined),
                          const SizedBox(height: 8),
                          Text(
                            l10n.scheduleStopRepeating,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: _scheduleEndDate ?? DateTime.now().add(const Duration(days: 30)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: ColorScheme.light(
                                        primary: AppColors.primary,
                                        onPrimary: Colors.white,
                                        surface: Colors.white,
                                        onSurface: AppColors.textPrimary,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() {
                                  _scheduleEndDate = picked;
                                  _invalidateAIPreviewState();
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _scheduleEndDate != null
                                      ? AppColors.primary.withOpacity(0.3)
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.event,
                                    color: _scheduleEndDate != null
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _scheduleEndDate != null
                                          ? DateFormat('d MMM yyyy').format(_scheduleEndDate!)
                                          : l10n.noEndDate,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: _scheduleEndDate != null
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  if (_scheduleEndDate != null)
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      color: AppColors.textSecondary,
                                      onPressed: () {
                                        setState(() {
                                          _scheduleEndDate = null;
                                          _invalidateAIPreviewState();
                                        });
                                      },
                                    )
                                  else
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      color: AppColors.textSecondary,
                                      size: 14,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else if (_taskType == 'Activity') ...[
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel(l10n.sectionDuration, Icons.timelapse),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _activityDurationController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: l10n.hintDurationMinutes,
                              prefixIcon: const Icon(Icons.timer_outlined),
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (value) {
                              final parsed = int.tryParse(value);
                              setState(() {
                                _activityDurationMinutes = parsed;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // 3c. Daily hours limit (Task only)
                  if (_taskType == 'Task') ...[
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel(l10n.sectionDailyTimeLimit, Icons.schedule_outlined),
                          const SizedBox(height: 6),
                          Text(
                            l10n.maxHoursPerDay,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [null, 1, 2, 3, 4, 5].map<Widget>((h) {
                              final isSelected = _dailyHoursLimit == h;
                              final label = h == null ? l10n.noLimit : l10n.hoursPerDay(h);
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _dailyHoursLimit = h;
                                    _invalidateAIPreviewState();
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.background,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.grey.shade300,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 4. AI Time Planning (only for Task type)
                  if (_taskType == 'Task') ...[
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel(l10n.sectionAiTimePlanning, Icons.auto_awesome_outlined),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.psychology_alt_outlined,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l10n.aiWillEstimate,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary.withOpacity(0.95),
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  
                  // 6. Difficulty
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel(l10n.sectionDifficulty, Icons.speed_outlined),
                        const SizedBox(height: 16),
                        Row(
                          children: _difficulties.map((diff) {
                            final isSelected = _difficulty == diff;
                            final color = _getDifficultyColor(diff);
                            
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: diff != _difficulties.last ? 8.0 : 0,
                                ),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _difficulty = diff;
                                      _invalidateAIPreviewState();
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: isSelected 
                                          ? color 
                                          : AppColors.background,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected 
                                            ? color 
                                            : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      _getDifficultyLabel(diff, l10n),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                  
                  // 8. AI Preview Section
                  if (_showAIPreview)
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.1),
                                Colors.blue.withOpacity(0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.smart_toy,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _taskType == 'Task' ? l10n.aiRecommendation : l10n.aiEstimateLabel,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.timer_outlined,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      l10n.estimatedEffort,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      _aiEstimatedEffort,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_taskType == 'Task')
                                      InkWell(
                                        onTap: _showEditEstimatedEffortSheet,
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.edit_outlined,
                                            size: 16,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                l10n.suggestedSchedule,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.touch_app_outlined,
                                    size: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    l10n.tapToSelect,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.edit_calendar_outlined,
                                    size: 12,
                                    color: AppColors.primary,
                                  ),
                                  Text(
                                    l10n.toAdjustTimes,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ..._aiSuggestedSlots.asMap().entries.map((entry) {
                                final index = entry.key;
                                final isSelected = _selectedSuggestionIndices.contains(index);
                                final editedSet = _userEditedOptions ?? <int>{};
                                final editedGroups = _editedSessionGroups ?? <List<Map<String, dynamic>>>[];
                                final isEdited = editedSet.contains(index);
                                final canEdit = index < editedGroups.length;
                                final sessionCount = canEdit ? editedGroups[index].length : 1;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary.withOpacity(0.07)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : isEdited
                                              ? const Color(0xFFD4A20A)
                                              : Colors.grey.shade200,
                                      width: isSelected ? 2 : 1.5,
                                    ),
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedSuggestionIndices.remove(index);
                                          _selectedSessionsPerOption.remove(index);
                                        } else {
                                          _selectedSuggestionIndices.add(index);
                                          _selectedSessionsPerOption[index] =
                                              Set.from(List.generate(sessionCount, (i) => i));
                                          if (index < _aiSuggestedStartTimes.length && !_isDeadlineManuallySet && _deadline == null) {
                                            final suggestedTime = _aiSuggestedStartTimes[index];
                                            _deadline = DateTime(suggestedTime.year, suggestedTime.month, suggestedTime.day);
                                            _deadlineTime = TimeOfDay(hour: suggestedTime.hour, minute: suggestedTime.minute);
                                          }
                                        }
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Select indicator
                                          Padding(
                                            padding: const EdgeInsets.only(top: 3),
                                            child: Icon(
                                              isSelected
                                                  ? Icons.check_circle
                                                  : Icons.radio_button_unchecked,
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : Colors.grey.shade400,
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          // Content column
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // "Manually adjusted" badge
                                                if (isEdited)
                                                  Container(
                                                    margin: const EdgeInsets.only(
                                                        bottom: 6),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          const Color(0xFFFFF3CD),
                                                      borderRadius:
                                                          BorderRadius.circular(6),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: const [
                                                        Icon(Icons.edit,
                                                            size: 11,
                                                            color: Color(
                                                                0xFF8B6914)),
                                                        SizedBox(width: 4),
                                                        Text(
                                                          'Manually adjusted',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Color(
                                                                0xFF8B6914),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                // Slot content
                                                _buildSessionCardContent(
                                                  index,
                                                  isSelected,
                                                  editedGroups,
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Edit calendar button
                                          if (canEdit) ...[
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              behavior:
                                                  HitTestBehavior.opaque,
                                              onTap: () =>
                                                  _showEditSessionSheet(index),
                                              child: Tooltip(
                                                message: 'Adjust times',
                                                child: Container(
                                                  padding: const EdgeInsets.all(7),
                                                  decoration: BoxDecoration(
                                                    color: isEdited
                                                        ? const Color(0xFFFFF3CD)
                                                        : AppColors.primary
                                                            .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(9),
                                                  ),
                                                  child: Icon(
                                                    Icons.edit_calendar_outlined,
                                                    color: isEdited
                                                        ? const Color(0xFF8B6914)
                                                        : AppColors.primary,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                              // Create your own slot (Task & Activity)
                              if (_taskType == 'Task' || _taskType == 'Activity') ...[
                                const SizedBox(height: 20),
                                Text(
                                  l10n.createYourOwnSlot,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: TextField(
                                    controller: _customSubtaskNameController,
                                    decoration: InputDecoration(
                                      hintText: l10n.hintSubtaskName,
                                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                      isDense: true,
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate: _customSlotDate ?? DateTime.now(),
                                            firstDate: DateTime.now(),
                                            lastDate: DateTime.now().add(const Duration(days: 365)),
                                            builder: (c, child) => Theme(
                                              data: Theme.of(context).copyWith(
                                                colorScheme: ColorScheme.light(
                                                  primary: AppColors.primary,
                                                  onPrimary: Colors.white,
                                                  surface: Colors.white,
                                                  onSurface: AppColors.textPrimary,
                                                ),
                                              ),
                                              child: child!,
                                            ),
                                          );
                                          if (picked != null) setState(() => _customSlotDate = picked);
                                        },
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.grey.shade300),
                                          ),
                                          child: Text(
                                            _customSlotDate != null
                                                ? DateFormat('dd/MM/yyyy').format(_customSlotDate!)
                                                : 'dd/mm/yyyy',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: _customSlotDate != null ? AppColors.textPrimary : AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final picked = await showTimePicker12h(
                                            context,
                                            initialTime: _customSlotStart ?? TimeOfDay.now(),
                                          );
                                          if (picked != null) setState(() => _customSlotStart = picked);
                                        },
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.grey.shade300),
                                          ),
                                          child: Text(
                                            _customSlotStart != null
                                                ? fmt12h(_customSlotStart!)
                                                : 'Bắt đầu',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: _customSlotStart != null ? AppColors.textPrimary : AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final picked = await showTimePicker12h(
                                            context,
                                            initialTime: _customSlotEnd ?? const TimeOfDay(hour: 10, minute: 0),
                                          );
                                          if (picked != null) setState(() => _customSlotEnd = picked);
                                        },
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.grey.shade300),
                                          ),
                                          child: Text(
                                            _customSlotEnd != null
                                                ? fmt12h(_customSlotEnd!)
                                                : 'Kết thúc',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: _customSlotEnd != null ? AppColors.textPrimary : AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          final subtaskName = _customSubtaskNameController.text.trim();
                                          if (subtaskName.isEmpty || _customSlotDate == null || _customSlotStart == null || _customSlotEnd == null) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Please set subtask name, date, start and end time'),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                            return;
                                          }
                                          final startMin = _customSlotStart!.hour * 60 + _customSlotStart!.minute;
                                          final endMin = _customSlotEnd!.hour * 60 + _customSlotEnd!.minute;
                                          if (endMin <= startMin) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('End time must be after start time'),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                            return;
                                          }
                                          final sh = _customSlotStart!.hour.clamp(0, 23);
                                          final sm = _customSlotStart!.minute.clamp(0, 59);
                                          final eh = _customSlotEnd!.hour.clamp(0, 23);
                                          final em = _customSlotEnd!.minute.clamp(0, 59);
                                          final start = DateTime(
                                            _customSlotDate!.year,
                                            _customSlotDate!.month,
                                            _customSlotDate!.day,
                                            sh,
                                            sm,
                                          );
                                          final end = DateTime(
                                            _customSlotDate!.year,
                                            _customSlotDate!.month,
                                            _customSlotDate!.day,
                                            eh,
                                            em,
                                          );
                                          final duration = end.difference(start).inMinutes;

                                          final conflicts = _findCustomSlotOverlaps(start, end);
                                          if (conflicts.isNotEmpty && mounted) {
                                            final proceed = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(16)),
                                                title: const Row(
                                                  children: [
                                                    Icon(Icons.warning_amber_rounded,
                                                        color: AppColors.warning),
                                                    SizedBox(width: 8),
                                                    Text('Time Conflict'),
                                                  ],
                                                ),
                                                content: Text(
                                                  'This slot overlaps with:\n'
                                                  '${conflicts.map((c) => '• $c').join('\n')}\n\n'
                                                  'Do you want to add it anyway?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.of(ctx).pop(false),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () => Navigator.of(ctx).pop(true),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: AppColors.warning,
                                                      foregroundColor: Colors.white,
                                                    ),
                                                    child: const Text('Add Anyway'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (proceed != true || !mounted) return;
                                          }

                                          setState(() {
                                            _customSlots.add({
                                              'taskName': subtaskName,
                                              'startTime': start.toIso8601String(),
                                              'endTime': end.toIso8601String(),
                                              'duration': duration,
                                            });
                                            _customSubtaskNameController.clear();
                                            _customSlotDate = null;
                                            _customSlotStart = null;
                                            _customSlotEnd = null;
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        child: const Text('Add'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              // Selected Time (Task & Activity)
                              if ((_taskType == 'Task' || _taskType == 'Activity') && _getSelectedTimeSlots().isNotEmpty) ...[
                                const SizedBox(height: 20),
                                Text(
                                  l10n.selectedTime,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ..._getSelectedTimeSlots().asMap().entries.map((entry) {
                                  final i = entry.key;
                                  final m = entry.value;
                                  final startStr = m['startTime'];
                                  final endStr = m['endTime'];
                                  DateTime start;
                                  DateTime end;
                                  try {
                                    start = startStr is DateTime ? startStr : DateTime.parse(startStr as String);
                                    end = endStr is DateTime ? endStr : DateTime.parse(endStr as String);
                                  } catch (_) {
                                    start = DateTime.now();
                                    end = start.add(const Duration(hours: 1));
                                  }
                                  final optionIndex = m['_optionIndex'] as int?;
                                  final sessionIndexInOption = m['_sessionIndexInOption'] as int?;
                                  final customIndex = m['_customIndex'] as int?;
                                  final customTaskName = customIndex != null
                                      ? _customSlots[customIndex]['taskName'] as String?
                                      : null;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (customTaskName != null && customTaskName.isNotEmpty)
                                                Text(
                                                  customTaskName,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                              Text(
                                                '${DateFormat('d/M/yyyy').format(start)}  ${_formatTimeWith24H(start)} – ${_formatTimeWith24H(end, isRangeEnd: true)}',
                                                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              if (customIndex != null) {
                                                _customSlots.removeAt(customIndex);
                                              } else if (optionIndex != null && sessionIndexInOption != null) {
                                                if (_editedSessionGroups.length > optionIndex) {
                                                  _editedSessionGroups[optionIndex].removeAt(sessionIndexInOption);
                                                  _selectedSessionsPerOption[optionIndex]?.remove(sessionIndexInOption);
                                                  if (_editedSessionGroups[optionIndex].isEmpty) {
                                                    _selectedSuggestionIndices.remove(optionIndex);
                                                    _selectedSessionsPerOption.remove(optionIndex);
                                                  }
                                                }
                                              }
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            child: Icon(
                                              Icons.cancel_outlined,
                                              size: 20,
                                              color: const Color(0xFFD4A20A),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  
                  // 9. Generate Button
                  if (_taskType != 'Schedules')
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isGenerating ? null : _generateAIEstimate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          disabledBackgroundColor: AppColors.textSecondary.withOpacity(0.3),
                        ),
                        child: _isGenerating
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    l10n.generating,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.auto_awesome, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.generateSmartSchedule,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                  // Add Schedule button (Schedules only)
                  if (_taskType == 'Schedules') ...[
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _addTaskToPlan,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_task, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              l10n.addSchedule,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  
                  // Add to Plan button (shows after AI preview)
                  if (_showAIPreview && _taskType != 'Schedules') ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _addTaskToPlan,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          l10n.addToMyPlan,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
