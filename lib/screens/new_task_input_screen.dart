import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';
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
  final TextEditingController _taskNameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
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
  final List<String> _taskTypes = ['Task', 'Schedules']; // 🔧 Changed from priorities
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
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: _deadlineTime ?? TimeOfDay.now(),
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
    // 🔧 Validation based on task type
    bool isValid = false;
    String errorMessage = '';
    
    if (_taskType == 'Task') {
      // Task validation: task title is enough to generate suggestions.
      isValid = _formKey.currentState!.validate();
      errorMessage = 'Please fill in task name';
    } else {
      // Schedules validation: needs weekdays and start/end time
      isValid = _formKey.currentState!.validate() && 
                _selectedWeekdays.isNotEmpty && 
                _scheduleStartTime != null && 
                _scheduleEndTime != null;
      errorMessage = 'Please fill in task name, dates, and time range';

      if (isValid && !_isValidScheduleTimeRange(_scheduleStartTime!, _scheduleEndTime!)) {
        isValid = false;
        errorMessage = 'End time must be after start time';
      }
    }
    
    if (isValid) {
      _formKey.currentState!.save();
      
      setState(() {
        _isGenerating = true;
      });
      
      // Simulate AI processing
      await Future.delayed(const Duration(seconds: 2));
      
      // 🔧 Different logic for Task vs Schedules
      if (_taskType == 'Task') {
        // === AI ESTIMATE FOR TASK ===
        int totalMinutes;
        if (_manualEstimatedMinutesOverride != null) {
          totalMinutes = _manualEstimatedMinutesOverride!;
        } else {
          totalMinutes = _estimateTaskMinutesBySignals();

          // Adjust based on difficulty.
          if (_difficulty == 'Hard') {
            totalMinutes = (totalMinutes * 1.5).round();
          } else if (_difficulty == 'Easy') {
            totalMinutes = (totalMinutes * 0.8).round();
          }

          // 🆕 Apply historical performance data to improve estimates
          final accuracy = _storage.getEstimateAccuracy();
          if (accuracy['totalTasks'] > 5) {
            final avgAccuracy = accuracy['averageAccuracy'];
            if (avgAccuracy < 80) {
              // User tends to underestimate, increase time
              totalMinutes = (totalMinutes * 1.2).round();
            }
          }
        }

        // Round to 30-minute blocks for cleaner suggestions.
        totalMinutes = ((totalMinutes + 15) ~/ 30) * 30;
        if (totalMinutes < 30) {
          totalMinutes = 30;
        }
        if (totalMinutes > 480) {
          totalMinutes = 480;
        }

        _aiEstimatedEffort = _formatEstimatedEffort(totalMinutes);
        _aiEstimatedMinutes = totalMinutes;
      
      // 🆕 Get break settings
      final breakSettings = _storage.getBreakSettings();
      final needsBreaks = totalMinutes > 60 && breakSettings['enabled'];
      
      // Generate suggested time slots with conflict detection
      _aiSuggestedSlots = [];
      _aiSuggestedStartTimes = []; // 🔧 Clear start times array
      _aiSuggestedSessionGroups = []; // 🔧 Clear grouped sessions
      final now = DateTime.now();
      const maxSuggestions = 3;
      
      if (totalMinutes <= 120) {
        // Single-session suggestions: provide multiple alternatives.
        final durationMinutes = totalMinutes;
        final usedSlots = <Map<String, DateTime>>[];

        for (int i = 0; i < maxSuggestions; i++) {
          final searchFrom = now.add(Duration(minutes: i * 30));
          final slotStart = _findNextAvailableSlotWithTracking(
            durationMinutes,
            searchFrom,
            usedSlots,
          );

          if (slotStart == null) {
            continue;
          }

          final slotEnd = slotStart.add(Duration(minutes: durationMinutes));
          usedSlots.add({'start': slotStart, 'end': slotEnd});

          _aiSuggestedStartTimes.add(slotStart);
          _aiSuggestedSessionGroups.add([
            {
              'startTime': slotStart.toIso8601String(),
              'endTime': slotEnd.toIso8601String(),
              'duration': durationMinutes,
            }
          ]);

          String slotText = '${DateFormat('EEEE, MMM d').format(slotStart)} • '
              '${_formatTimeWith24H(slotStart)} – ${_formatTimeWith24H(slotEnd, isRangeEnd: true)}';

          if (needsBreaks) {
            final workDuration = breakSettings['workDuration'];
            slotText += '\n⏱️ Break after ${workDuration}min';
          }

          _aiSuggestedSlots.add(slotText);
        }

        if (_aiSuggestedSlots.isEmpty) {
          _aiSuggestedSlots.add('⚠️ No available slots found in next 7 days');
        }
      } else {
        // Multi-session suggestions: generate multiple full plans (e.g. 7h -> 2h+2h+2h+1h).
        int remaining = totalMinutes;
        final sessionMinutesPlan = <int>[];
        while (remaining > 0) {
          final chunk = remaining > 120 ? 120 : remaining;
          sessionMinutesPlan.add(chunk);
          remaining -= chunk;
        }

        for (int optionIndex = 0; optionIndex < maxSuggestions; optionIndex++) {
          DateTime searchFrom = now.add(Duration(hours: optionIndex));
          final optionSlots = <Map<String, DateTime>>[];
          final optionSessions = <Map<String, dynamic>>[];
          final optionLines = <String>[];
          bool validOption = true;

          for (int sessionIndex = 0; sessionIndex < sessionMinutesPlan.length; sessionIndex++) {
            final sessionMinutes = sessionMinutesPlan[sessionIndex];
            final slotStart = _findNextAvailableSlotWithTracking(
              sessionMinutes,
              searchFrom,
              optionSlots,
            );

            if (slotStart == null) {
              validOption = false;
              break;
            }

            final slotEnd = slotStart.add(Duration(minutes: sessionMinutes));
            optionSlots.add({'start': slotStart, 'end': slotEnd});
            optionSessions.add({
              'startTime': slotStart.toIso8601String(),
              'endTime': slotEnd.toIso8601String(),
              'duration': sessionMinutes,
            });

            optionLines.add(
              'S${sessionIndex + 1}: ${DateFormat('EEE d').format(slotStart)} '
              '${_formatTimeWith24H(slotStart)}-${_formatTimeWith24H(slotEnd, isRangeEnd: true)}',
            );

            searchFrom = slotStart.add(const Duration(hours: 2, minutes: 30));
          }

          if (!validOption || optionSessions.isEmpty) {
            continue;
          }

          _aiSuggestedStartTimes.add(optionSlots.first['start']!);
          _aiSuggestedSessionGroups.add(optionSessions);

          String optionText = 'Option ${optionIndex + 1} • ${optionSessions.length} sessions\n${optionLines.join('\n')}';
          if (needsBreaks) {
            final workDuration = breakSettings['workDuration'];
            final breakDuration = breakSettings['breakDuration'];
            optionText += '\n⏱️ ${workDuration}min work / ${breakDuration}min break';
          }

          _aiSuggestedSlots.add(optionText);
        }

        if (_aiSuggestedSlots.isEmpty) {
          _aiSuggestedSlots.add('⚠️ Schedule is too busy, consider rescheduling other tasks');
        }
      }

      if (_aiSuggestedStartTimes.isNotEmpty) {
        final defaultStart = _aiSuggestedStartTimes.first;
        _selectedSuggestionIndex = 0;

        // Keep manually entered deadline/time; auto-fill only when deadline is not manually set.
        if (!_isDeadlineManuallySet && (_deadline == null || _deadlineTime == null)) {
          _deadline = DateTime(defaultStart.year, defaultStart.month, defaultStart.day);
          _deadlineTime = TimeOfDay(hour: defaultStart.hour, minute: defaultStart.minute);
        }
      } else {
        _selectedSuggestionIndex = null;
      }

      // Deep-copy AI sessions so user edits don't mutate the originals
      _editedSessionGroups = _aiSuggestedSessionGroups
          .map((g) => g.map((s) => Map<String, dynamic>.from(s)).toList())
          .toList();
      _userEditedOptions = {};
      _lastGeneratedSignature = _buildPlanningSignature();
      } else {
        // === PREVIEW FOR SCHEDULES ===
        _aiEstimatedMinutes = null;
        _aiSuggestedSlots = [];
        _aiSuggestedStartTimes = [];
        _aiSuggestedSessionGroups = [];
        
        // Format weekdays
        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final weekdaysList = _selectedWeekdays.toList()..sort();
        final weekdaysText = weekdaysList.map((d) => days[d - 1]).join(', ');
        
        // Format time range in 24h display.
        final startTimeText = _formatTimeOfDay24H(_scheduleStartTime!);
        final endTimeText = _formatTimeOfDay24H(_scheduleEndTime!, isRangeEnd: true);
        
        _aiEstimatedEffort = 'Recurring schedule';
        _aiSuggestedSlots.add('📅 Every $weekdaysText\n🕐 $startTimeText – $endTimeText');
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
    final needsBreaks = (_aiEstimatedMinutes ?? 0) > 60 && breakSettings['enabled'] as bool;
    if (sessions.length == 1) {
      final start = DateTime.parse(sessions[0]['startTime'] as String);
      final end = DateTime.parse(sessions[0]['endTime'] as String);
      String text =
          '${DateFormat('EEEE, MMM d').format(start)} • '
          '${_formatTimeWith24H(start)} – ${_formatTimeWith24H(end, isRangeEnd: true)}';
      if (needsBreaks) {
        text += '\n⏱️ Break after ${breakSettings['workDuration']}min';
      }
      return text;
    }
    final lines = sessions.asMap().entries.map((e) {
      final s = e.value;
      final start = DateTime.parse(s['startTime'] as String);
      final end = DateTime.parse(s['endTime'] as String);
      return 'S${e.key + 1}: ${DateFormat('EEE d').format(start)} '
          '${_formatTimeWith24H(start)}-${_formatTimeWith24H(end, isRangeEnd: true)}';
    }).toList();
    String text =
        'Option ${optionIndex + 1} • ${sessions.length} sessions\n${lines.join('\n')}';
    if (needsBreaks) {
      text +=
          '\n⏱️ ${breakSettings['workDuration']}min work / ${breakSettings['breakDuration']}min break';
    }
    return text;
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
                            const Text(
                              'Adjust Schedule',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Change dates & times to fit your availability',
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
                        label: const Text('Reset'),
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
                    final sessionLabel = localSessions.length > 1
                        ? 'Session ${sIdx + 1}'
                        : 'Session';

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
                                final pickedTime = await showTimePicker(
                                  context: builderCtx,
                                  initialTime: TimeOfDay(
                                    hour: start.hour,
                                    minute: start.minute,
                                  ),
                                  builder: (ctx, child) => Theme(
                                    data: pickerTheme,
                                    child: child!,
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
                              label: const Text('Edit'),
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
                      child: const Text(
                        'Confirm',
                        style: TextStyle(
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
                  const Text(
                    'Edit Estimated Effort',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Adjust how long this task should take. AI will regenerate schedule suggestions.',
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
                      child: const Text(
                        'Apply & Regenerate',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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

  int _getPreferredHour() {
    final notes = _notesController.text.toLowerCase();
    final hasUrgencySignal = notes.contains('urgent') ||
        notes.contains('exam') ||
        notes.contains('deadline') ||
        notes.contains('asap');

    if (_difficulty == 'Hard' || hasUrgencySignal) {
      return 7;
    }
    if (_category == 'Health') {
      return 6;
    }
    if (_category == 'Personal') {
      return 20;
    }
    if (_category == 'Study') {
      return 19;
    }
    return 18;
  }

  List<int> _sortHoursByPreference(List<int> hours) {
    final preferredHour = _getPreferredHour();
    final sorted = List<int>.from(hours);
    sorted.sort((a, b) => (a - preferredHour).abs().compareTo((b - preferredHour).abs()));
    return sorted;
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
  
  // 🔧 Helper function to find slot that doesn't conflict with already suggested slots
  DateTime? _findNextAvailableSlotWithTracking(
    int durationMinutes,
    DateTime searchFrom,
    List<Map<String, DateTime>> alreadySuggested,
  ) {
    final now = DateTime.now();
    DateTime checkTime = searchFrom.isBefore(now) ? now : searchFrom;
    
    // Try next 7 days
    for (int day = 0; day < 7; day++) {
      final checkDay = DateTime(
        checkTime.year,
        checkTime.month,
        checkTime.day + day,
      );
      
      // Define available time slots
      final isWeekday = checkDay.weekday >= 1 && checkDay.weekday <= 5;
        List<int> availableHours = isWeekday 
          ? [6, 7, 18, 19, 20, 21, 22]
          : [8, 9, 10, 11, 14, 15, 16, 17, 18, 19, 20, 21, 22];
        availableHours = _sortHoursByPreference(availableHours);
      
      for (int hour in availableHours) {
        final slotStart = DateTime(
          checkDay.year,
          checkDay.month,
          checkDay.day,
          hour,
          0,
        );
        
        // Skip if before the search boundary (respects searchFrom for multi-session planning).
        if (slotStart.isBefore(checkTime)) continue;
        
        final slotEnd = slotStart.add(Duration(minutes: durationMinutes));
        
        // Check if end time is reasonable
        if (slotEnd.hour >= 23) continue;
        
        // 🔧 Check conflict with already suggested slots
        bool conflictsWithSuggested = false;
        for (var suggested in alreadySuggested) {
          final suggestedStart = suggested['start']!;
          final suggestedEnd = suggested['end']!;
          
          // Check overlap
          if (slotStart.isBefore(suggestedEnd) && slotEnd.isAfter(suggestedStart)) {
            conflictsWithSuggested = true;
            break;
          }
        }
        
        if (conflictsWithSuggested) continue;
        
        // Check conflict with existing schedule
        if (!_storage.hasScheduleConflict(slotStart, slotEnd)) {
          return slotStart;
        }
      }
    }
    
    return null; // No available slot found
  }

  Future<void> _addTaskToPlan() async {
    if (!_showAIPreview || _lastGeneratedSignature != _buildPlanningSignature()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.info_outline, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text('Please generate AI schedule again after your latest changes'),
              ),
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

    // 🔧 Validation for Schedules
    if (_taskType == 'Schedules') {
      if (_selectedWeekdays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.warning, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Please select at least one day for recurring schedule'),
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
      
      if (_scheduleStartTime == null || _scheduleEndTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.warning, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Please set start and end time for schedule'),
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

      if (!_isValidScheduleTimeRange(_scheduleStartTime!, _scheduleEndTime!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.warning, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text('End time must be after start time'),
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
    
    // Validation for Task
    if (_taskType == 'Task' && (!_formKey.currentState!.validate() || _deadline == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.warning, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text('Please complete all required fields'),
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
    
    _formKey.currentState!.save();
    
    // Use AI-estimated minutes (only for Task type)
    int estimatedHours = 1;
    int estimatedMinutes = 60;
    if (_taskType == 'Task') {
      estimatedMinutes = _aiEstimatedMinutes ?? _manualEstimatedMinutesOverride ?? _estimateTaskMinutesBySignals();
      estimatedHours = (estimatedMinutes / 60).ceil();
    }
    
    // 🆕 Get break settings
    final breakSettings = _storage.getBreakSettings();

    // Use user-edited sessions if available, otherwise fall back to raw AI sessions
    final sessionSource = _editedSessionGroups.isNotEmpty
        ? _editedSessionGroups
        : _aiSuggestedSessionGroups;
    final selectedGroupIndex = (_selectedSuggestionIndex != null &&
        _selectedSuggestionIndex! >= 0 &&
        _selectedSuggestionIndex! < sessionSource.length)
      ? _selectedSuggestionIndex!
      : 0;
    final selectedSessions = sessionSource.isNotEmpty
      ? sessionSource[selectedGroupIndex]
      : <Map<String, dynamic>>[];
    
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
        'subject': _category,
        'subjectColor': AppColors.subjectAccentColor(_category).toARGB32(),
        'difficulty': _difficulty,
        'deadline': finalDeadline.toIso8601String(),
        'estimatedTime': estimatedHours,
        'estimatedMinutes': estimatedMinutes,
        'category': _category,
        'taskType': 'Task',
        'notes': _notes,
        'createdAt': DateTime.now().toIso8601String(),
        // 🆕 Break reminders
        'needsBreak': estimatedHours > 1 && breakSettings['enabled'],
        'breakInterval': breakSettings['workDuration'],
        'breakDuration': breakSettings['breakDuration'],
        // 🆕 For performance tracking
        'startedAt': null,
        'completedAt': null,
        'actualTime': null,
        // AI sessions are tied to the selected suggestion option.
        'sessions': selectedSessions.isNotEmpty ? selectedSessions : null,
      };
    } else {
      // 🔧 Schedule: has fixed start/end time + recurring weekdays
      taskData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': _taskName,
        'subject': _category,
        'subjectColor': AppColors.subjectAccentColor(_category).toARGB32(),
        'difficulty': _difficulty,
        'category': _category,
        'taskType': 'Schedules',
        'weekdays': _selectedWeekdays.toList(),
        'startTime': '${_scheduleStartTime!.hour.toString().padLeft(2, '0')}:${_scheduleStartTime!.minute.toString().padLeft(2, '0')}',
        'endTime': '${_scheduleEndTime!.hour.toString().padLeft(2, '0')}:${_scheduleEndTime!.minute.toString().padLeft(2, '0')}',
        'scheduleEndDate': _scheduleEndDate?.toIso8601String(), // 🆕 Optional end date
        'notes': '',
        'createdAt': DateTime.now().toIso8601String(),
      };
    }
    
    await _storage.addCustomTask(taskData);
    
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
        title: const Text(
          'Add Task',
          style: TextStyle(
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
                  // 1. Task Title
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel('Task Title', Icons.edit_outlined),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _taskNameController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Marketing presentation slides',
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
                              return 'Please enter a task name';
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
                  
                  // 2. Category (Task Type)
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel('Category', Icons.label_outlined),
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
                                      // Reset weekdays if switching to Task
                                      if (type == 'Task') {
                                        _selectedWeekdays.clear();
                                      } else {
                                        _category = 'Other';
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
                                        type,
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
                  
                  // 2b. Weekday Selector (only for Schedules)
                  if (_taskType == 'Schedules') ...[
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel('Dates', Icons.date_range_outlined),
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
                          _buildSectionLabel('Deadline', Icons.calendar_today_outlined),
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
                                          ? '${DateFormat('d MMM yyyy').format(_deadline!)} • ${_deadlineTime!.format(context)}'
                                          : 'Select date and time',
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
                  
                  // 3b. Start/End Time (only for Schedules type)
                  if (_taskType == 'Schedules') ...[
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel('Start time', Icons.access_time),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: () async {
                              final TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: _scheduleStartTime ?? TimeOfDay.now(),
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
                                          ? _scheduleStartTime!.format(context)
                                          : 'Select start time',
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
                          _buildSectionLabel('End time', Icons.access_time_filled),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: () async {
                              final TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: _scheduleEndTime ?? TimeOfDay.now(),
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
                                          ? _scheduleEndTime!.format(context)
                                          : 'Select end time',
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
                          _buildSectionLabel('End Date (Optional)', Icons.event_busy_outlined),
                          const SizedBox(height: 8),
                          Text(
                            'Schedule will stop repeating after this date',
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
                                          : 'No end date (runs forever)',
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
                  ],
                  
                  // 4. AI Time Planning (only for Task type)
                  if (_taskType == 'Task') ...[
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel('AI Time Planning', Icons.auto_awesome_outlined),
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
                                    'AI will estimate effort automatically from task title, subject, notes, and difficulty.',
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
                        _buildSectionLabel('Difficulty', Icons.speed_outlined),
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
                                      diff,
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
                  
                  // 5. Subject
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel('Subject', Icons.bookmark_outline),
                        const SizedBox(height: 10),
                        Text(
                          'Choose subject to auto-theme your cards on Home',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _categories.map((cat) {
                            final isSelected = _category == cat;
                            final accentColor = _getCategoryColor(cat);
                            
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _category = cat;
                                  _invalidateAIPreviewState();
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? accentColor.withOpacity(0.16)
                                      : AppColors.background,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? accentColor
                                        : accentColor.withOpacity(0.28),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getCategoryIcon(cat),
                                      size: 16,
                                      color: isSelected
                                          ? accentColor
                                          : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      cat,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? accentColor
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 7. Notes (Task only)
                  if (_taskType == 'Task') ...[
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel('Notes (Optional)', Icons.note_outlined),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _notesController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: 'Extra information for the AI...',
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
                    const SizedBox(height: 24),
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
                                  const Text(
                                    'AI Estimate',
                                    style: TextStyle(
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
                                    const Text(
                                      'Estimated effort: ',
                                      style: TextStyle(
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
                              const Text(
                                'Suggested schedule:',
                                style: TextStyle(
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
                                  const Text(
                                    'Tap to select  •  Tap ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.edit_calendar_outlined,
                                    size: 12,
                                    color: AppColors.primary,
                                  ),
                                  const Text(
                                    ' to adjust times',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ..._aiSuggestedSlots.asMap().entries.map((entry) {
                                final index = entry.key;
                                final isSelected = _selectedSuggestionIndex == index;
                                final editedSet = _userEditedOptions ?? <int>{};
                                final editedGroups = _editedSessionGroups ?? <List<Map<String, dynamic>>>[];
                                final isEdited = editedSet.contains(index);
                                final canEdit = index < editedGroups.length;
                                final displayText = _buildSlotDisplayText(index);

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
                                        _selectedSuggestionIndex = index;
                                      });

                                      if (index < _aiSuggestedStartTimes.length &&
                                          !_isDeadlineManuallySet) {
                                        final suggestedTime =
                                            _aiSuggestedStartTimes[index];
                                        setState(() {
                                          _deadline = DateTime(
                                            suggestedTime.year,
                                            suggestedTime.month,
                                            suggestedTime.day,
                                          );
                                          _deadlineTime = TimeOfDay(
                                            hour: suggestedTime.hour,
                                            minute: suggestedTime.minute,
                                          );
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: const [
                                                Icon(Icons.check_circle,
                                                    color: Colors.white, size: 18),
                                                SizedBox(width: 8),
                                                Text('✨ Session plan selected, deadline set!'),
                                              ],
                                            ),
                                            backgroundColor: AppColors.success,
                                            duration: const Duration(seconds: 1),
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: const [
                                                Icon(Icons.check_circle,
                                                    color: Colors.white, size: 18),
                                                SizedBox(width: 8),
                                                Text('✨ Session plan selected. Deadline unchanged.'),
                                              ],
                                            ),
                                            backgroundColor: AppColors.success,
                                            duration: const Duration(seconds: 1),
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                        );
                                      }
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
                                                // Slot text
                                                Text(
                                                  displayText,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: isSelected
                                                        ? FontWeight.w600
                                                        : FontWeight.w500,
                                                    color: AppColors.textPrimary,
                                                    height: 1.45,
                                                  ),
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
                            ],
                          ),
                        ),
                      ),
                    ),
                  
                  // 9. Generate Button
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
                              children: const [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Generating...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.auto_awesome, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Generate Smart Schedule',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  
                  // Add to Plan button (shows after AI preview)
                  if (_showAIPreview) ...[
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
                        child: const Text(
                          'Add to My Plan',
                          style: TextStyle(
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
