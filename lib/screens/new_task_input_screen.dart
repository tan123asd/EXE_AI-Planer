import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';
import 'dart:math';
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
  final TextEditingController _customTimeController = TextEditingController();
  
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
  Set<int> _selectedWeekdays = {}; // 🆕 For recurring schedules (1=Monday, 7=Sunday)
  String _category = 'Study'; // 🔧 Single category instead of set
  String _notes = '';
  String _estimatedTime = '1 hour';
  bool _showCustomTime = false;
  bool _showAIPreview = false;
  bool _isGenerating = false;
  int? _selectedSuggestionIndex;
  
  // AI Preview data
  String _aiEstimatedEffort = '';
  List<String> _aiSuggestedSlots = [];
  List<DateTime> _aiSuggestedStartTimes = [];
  List<Map<String, dynamic>> _aiSuggestedSessions = []; // 🆕 Full session data

  final List<String> _difficulties = ['Easy', 'Medium', 'Hard'];
  final List<String> _taskTypes = ['Task', 'Schedules']; // 🔧 Changed from priorities
  final List<String> _timeOptions = ['30 min', '1 hour', '2 hours', '3 hours', 'Custom'];
  final List<String> _categories = ['Study', 'Personal', 'Health', 'Skill', 'Other'];

  @override
  void initState() {
    super.initState();
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
    _customTimeController.dispose();
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
          _selectedSuggestionIndex = null; // 🔧 Reset selection since user manually picked time
        });
      }
    }
  }

  void _generateAIEstimate() async {
    // 🔧 Validation based on task type
    bool isValid = false;
    String errorMessage = '';
    
    if (_taskType == 'Task') {
      // Task validation: needs deadline
      isValid = _formKey.currentState!.validate() && _deadline != null;
      errorMessage = 'Please fill in task name and deadline';
    } else {
      // Schedules validation: needs weekdays and start/end time
      isValid = _formKey.currentState!.validate() && 
                _selectedWeekdays.isNotEmpty && 
                _scheduleStartTime != null && 
                _scheduleEndTime != null;
      errorMessage = 'Please fill in task name, dates, and time range';
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
        // Generate AI estimate
        final random = Random();
        int totalHours = 1;
      
      if (_estimatedTime.contains('30 min')) {
        totalHours = 1;
      } else if (_estimatedTime.contains('1 hour')) {
        totalHours = 1;
      } else if (_estimatedTime.contains('2 hours')) {
        totalHours = 2;
      } else if (_estimatedTime.contains('3 hours')) {
        totalHours = 3;
      } else if (_showCustomTime && _customTimeController.text.isNotEmpty) {
        totalHours = int.tryParse(_customTimeController.text) ?? 2;
      }
      
      // Adjust based on difficulty
      if (_difficulty == 'Hard') {
        totalHours = (totalHours * 1.5).ceil();
      } else if (_difficulty == 'Easy') {
        totalHours = (totalHours * 0.8).ceil();
      }
      
      // 🆕 Apply historical performance data to improve estimates
      final accuracy = _storage.getEstimateAccuracy();
      if (accuracy['totalTasks'] > 5) {
        final avgAccuracy = accuracy['averageAccuracy'];
        if (avgAccuracy < 80) {
          // User tends to underestimate, increase time
          totalHours = (totalHours * 1.2).ceil();
        }
      }
      
      _aiEstimatedEffort = '$totalHours hour${totalHours > 1 ? 's' : ''}';
      
      // 🆕 Get break settings
      final breakSettings = _storage.getBreakSettings();
      final needsBreaks = totalHours > 1 && breakSettings['enabled'];
      
      // Generate suggested time slots with conflict detection
      _aiSuggestedSlots = [];
      _aiSuggestedStartTimes = []; // 🔧 Clear start times array
      _aiSuggestedSessions = []; // 🔧 Clear sessions array
      final now = DateTime.now();
      
      if (totalHours <= 2) {
        // Single session
        final durationMinutes = totalHours * 60;
        DateTime? slotStart;
        
        // 🆕 IMPROVED: Find available slot starting from now
        slotStart = _storage.findNextAvailableSlot(durationMinutes, now);
        
        if (slotStart != null) {
          final slotEnd = slotStart.add(Duration(minutes: durationMinutes));
          
          // 🔧 Save start time for later use
          _aiSuggestedStartTimes.add(slotStart);
          
          // 🆕 Save full session data
          _aiSuggestedSessions.add({
            'startTime': slotStart.toIso8601String(),
            'endTime': slotEnd.toIso8601String(),
            'duration': durationMinutes,
          });
          
          // 🆕 Format with AM/PM
          String slotText = '${DateFormat('EEEE, MMM d').format(slotStart)} • '
              '${_formatTimeWithAMPM(slotStart)} – ${_formatTimeWithAMPM(slotEnd)}';
          
          // 🆕 Add break reminder if needed
          if (needsBreaks) {
            final workDuration = breakSettings['workDuration'];
            slotText += '\n⏱️ Break after ${workDuration}min';
          }
          
          _aiSuggestedSlots.add(slotText);
        } else {
          _aiSuggestedSlots.add('⚠️ No available slots found in next 7 days');
        }
      } else {
        // Split into multiple sessions
        int remainingHours = totalHours;
        int sessionCount = 0;
        DateTime searchFrom = now;
        
        // 🔧 FIX: Track suggested slots to avoid duplicates
        List<Map<String, DateTime>> suggestedSlots = [];
        
        while (remainingHours > 0 && sessionCount < 5) {
          final sessionHours = remainingHours > 2 ? 2 : remainingHours;
          final sessionMinutes = sessionHours * 60;
          
          // 🔧 FIX: Find available slot that doesn't conflict with already suggested slots
          DateTime? slotStart = _findNextAvailableSlotWithTracking(
            sessionMinutes,
            searchFrom,
            suggestedSlots,
          );
          
          if (slotStart != null) {
            final slotEnd = slotStart.add(Duration(minutes: sessionMinutes));
            
            // 🔧 FIX: Add to tracking list
            suggestedSlots.add({'start': slotStart, 'end': slotEnd});
            
            // 🔧 Save start time for later use
            _aiSuggestedStartTimes.add(slotStart);
            
            // 🆕 Save full session data
            _aiSuggestedSessions.add({
              'startTime': slotStart.toIso8601String(),
              'endTime': slotEnd.toIso8601String(),
              'duration': sessionMinutes,
            });
            
            // 🆕 Format with AM/PM
            String slotText = '${DateFormat('EEEE, MMM d').format(slotStart)} • '
                '${_formatTimeWithAMPM(slotStart)} – ${_formatTimeWithAMPM(slotEnd)} '
                '(Session ${sessionCount + 1})';
            
            // 🆕 Add break reminder
            if (needsBreaks) {
              final workDuration = breakSettings['workDuration'];
              final breakDuration = breakSettings['breakDuration'];
              slotText += '\n⏱️ ${workDuration}min work / ${breakDuration}min break';
            }
            
            _aiSuggestedSlots.add(slotText);
            
            // 🔧 FIX: Search for next session at least 2 hours after this one starts
            // This ensures sessions are spread out, not overlapping
            searchFrom = slotStart.add(Duration(hours: 2, minutes: 30));
          } else {
            break; // No more slots available
          }
          
          remainingHours -= sessionHours;
          sessionCount++;
        }
        
        if (_aiSuggestedSlots.isEmpty) {
          _aiSuggestedSlots.add('⚠️ Schedule is too busy, consider rescheduling other tasks');
        }
      }
      } else {
        // === PREVIEW FOR SCHEDULES ===
        _aiSuggestedSlots = [];
        _aiSuggestedStartTimes = [];
        _aiSuggestedSessions = [];
        
        // Format weekdays
        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final weekdaysList = _selectedWeekdays.toList()..sort();
        final weekdaysText = weekdaysList.map((d) => days[d - 1]).join(', ');
        
        // Format time range
        final startTimeText = _scheduleStartTime!.format(context);
        final endTimeText = _scheduleEndTime!.format(context);
        
        _aiEstimatedEffort = 'Recurring schedule';
        _aiSuggestedSlots.add('📅 Every $weekdaysText\n🕐 $startTimeText – $endTimeText');
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
  
  // 🆕 Helper function to format time with AM/PM
  String _formatTimeWithAMPM(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;
    
    if (hour == 0) {
      return '12:${minute.toString().padLeft(2, '0')} AM';
    } else if (hour < 12) {
      return '$hour:${minute.toString().padLeft(2, '0')} AM';
    } else if (hour == 12) {
      return '12:${minute.toString().padLeft(2, '0')} PM';
    } else {
      return '${hour - 12}:${minute.toString().padLeft(2, '0')} PM';
    }
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
      
      for (int hour in availableHours) {
        final slotStart = DateTime(
          checkDay.year,
          checkDay.month,
          checkDay.day,
          hour,
          0,
        );
        
        // Skip if in the past
        if (slotStart.isBefore(now)) continue;
        
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
    
    // Parse estimated time (only for Task type)
    int estimatedHours = 1;
    if (_taskType == 'Task') {
      if (_estimatedTime.contains('30 min')) {
        estimatedHours = 1;
      } else if (_estimatedTime.contains('1 hour')) {
        estimatedHours = 1;
      } else if (_estimatedTime.contains('2 hours')) {
        estimatedHours = 2;
      } else if (_estimatedTime.contains('3 hours')) {
        estimatedHours = 3;
      } else if (_showCustomTime && _customTimeController.text.isNotEmpty) {
        estimatedHours = int.tryParse(_customTimeController.text) ?? 2;
      }
    }
    
    // 🆕 Get break settings
    final breakSettings = _storage.getBreakSettings();
    
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
        'difficulty': _difficulty,
        'deadline': finalDeadline.toIso8601String(),
        'estimatedTime': estimatedHours,
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
        // 🆕 AI suggested sessions (for multi-session tasks)
        'sessions': _aiSuggestedSessions.isNotEmpty ? _aiSuggestedSessions : null,
      };
    } else {
      // 🔧 Schedule: has fixed start/end time + recurring weekdays
      taskData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': _taskName,
        'subject': _category,
        'difficulty': _difficulty,
        'category': _category,
        'taskType': 'Schedules',
        'weekdays': _selectedWeekdays.toList(),
        'startTime': '${_scheduleStartTime!.hour.toString().padLeft(2, '0')}:${_scheduleStartTime!.minute.toString().padLeft(2, '0')}',
        'endTime': '${_scheduleEndTime!.hour.toString().padLeft(2, '0')}:${_scheduleEndTime!.minute.toString().padLeft(2, '0')}',
        'notes': _notes,
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
                                      }
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
                  ],
                  
                  // 4. Estimated Time (only for Task type)
                  if (_taskType == 'Task') ...[
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionLabel('Estimated Time', Icons.access_time_outlined),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _timeOptions.map((time) {
                            final isSelected = _estimatedTime == time;
                            final isCustom = time == 'Custom' && _showCustomTime;
                            
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _estimatedTime = time;
                                  _showCustomTime = time == 'Custom';
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected || isCustom
                                      ? AppColors.primary
                                      : AppColors.background,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isSelected || isCustom
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  time,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected || isCustom
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        if (_showCustomTime) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _customTimeController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'Enter hours (e.g., 4)',
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
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
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
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _categories.map((cat) {
                            final isSelected = _category == cat;
                            
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _category = cat;
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
                                      ? AppColors.primary.withOpacity(0.1)
                                      : AppColors.background,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.transparent,
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
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      cat,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? AppColors.primary
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
                  
                  // 7. Notes
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
                          onSaved: (value) => _notes = value ?? '',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
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
                              const Text(
                                'Tap a suggestion to set it as deadline',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._aiSuggestedSlots.asMap().entries.map((entry) {
                                final index = entry.key;
                                final slot = entry.value;
                                final isSelected = _selectedSuggestionIndex == index;
                                
                                return GestureDetector(
                                  onTap: () {
                                    // 🔧 Set deadline from suggestion
                                    if (index < _aiSuggestedStartTimes.length) {
                                      final suggestedTime = _aiSuggestedStartTimes[index];
                                      setState(() {
                                        _selectedSuggestionIndex = index;
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
                                              Icon(Icons.check_circle, color: Colors.white, size: 18),
                                              SizedBox(width: 8),
                                              Text('✨ Deadline set!'),
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
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSelected 
                                          ? AppColors.primary.withOpacity(0.1)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: isSelected
                                          ? Border.all(color: AppColors.primary, width: 2)
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelected ? Icons.check_circle : Icons.event_available,
                                          color: isSelected ? AppColors.primary : AppColors.success,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            slot,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
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
