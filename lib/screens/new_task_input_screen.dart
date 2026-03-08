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
  String _priority = 'Medium';
  DateTime? _deadline;
  TimeOfDay? _deadlineTime;
  Set<String> _selectedCategories = {'Study'};
  String _notes = '';
  String _estimatedTime = '1 hour';
  bool _showCustomTime = false;
  bool _showAIPreview = false;
  bool _isGenerating = false;
  
  // AI Preview data
  String _aiEstimatedEffort = '';
  List<String> _aiSuggestedSlots = [];

  final List<String> _difficulties = ['Easy', 'Medium', 'Hard'];
  final List<String> _priorities = ['Low', 'Medium', 'High'];
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
        });
      }
    }
  }

  void _generateAIEstimate() async {
    if (_formKey.currentState!.validate() && _deadline != null) {
      _formKey.currentState!.save();
      
      setState(() {
        _isGenerating = true;
      });
      
      // Simulate AI processing
      await Future.delayed(const Duration(seconds: 2));
      
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
      
      _aiEstimatedEffort = '$totalHours hour${totalHours > 1 ? 's' : ''}';
      
      // Generate suggested time slots
      _aiSuggestedSlots = [];
      final now = DateTime.now();
      
      if (totalHours <= 2) {
        // Single session
        final suggestedDay = _difficulty == 'Hard' ? now : now.add(const Duration(days: 1));
        final timeSlot = _difficulty == 'Hard' ? 9 : 20;
        _aiSuggestedSlots.add(
          '${DateFormat('EEEE').format(suggestedDay)} ${timeSlot.toString().padLeft(2, '0')}:00 – ${(timeSlot + totalHours).toString().padLeft(2, '0')}:00'
        );
      } else {
        // Split into multiple sessions
        int remainingHours = totalHours;
        int dayOffset = 0;
        
        while (remainingHours > 0) {
          final sessionHours = remainingHours > 2 ? 2 : remainingHours;
          final suggestedDay = now.add(Duration(days: dayOffset));
          final timeSlot = 20;
          
          _aiSuggestedSlots.add(
            '${DateFormat('EEEE').format(suggestedDay)} ${timeSlot.toString().padLeft(2, '0')}:00 – ${(timeSlot + sessionHours).toString().padLeft(2, '0')}:00'
          );
          
          remainingHours -= sessionHours;
          dayOffset++;
          
          if (_aiSuggestedSlots.length >= 3) break;
        }
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
            children: const [
              Icon(Icons.warning, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text('Please fill in task name and deadline'),
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

  Future<void> _addTaskToPlan() async {
    if (!_formKey.currentState!.validate() || _deadline == null) {
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
    
    int estimatedHours = 1;
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
    
    final taskData = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': _taskName,
      'subject': _selectedCategories.first,
      'difficulty': _difficulty,
      'deadline': _deadline?.toIso8601String(),
      'estimatedTime': estimatedHours,
      'category': _selectedCategories.first,
      'priority': _priority,
      'notes': _notes,
      'createdAt': DateTime.now().toIso8601String(),
    };
    
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

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'Low':
        return AppColors.success;
      case 'Medium':
        return AppColors.medium;
      case 'High':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }

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
                  
                  // 2. Deadline
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
                  
                  // 3. Estimated Time
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
                  
                  // 4. Difficulty
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
                  
                  // 5. Priority
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel('Priority', Icons.flag_outlined),
                        const SizedBox(height: 16),
                        Row(
                          children: _priorities.map((prior) {
                            final isSelected = _priority == prior;
                            final color = _getPriorityColor(prior);
                            
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: prior != _priorities.last ? 8.0 : 0,
                                ),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _priority = prior;
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
                                      prior,
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
                  
                  // 6. Category
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel('Category', Icons.label_outlined),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _categories.map((category) {
                            final isSelected = _selectedCategories.contains(category);
                            
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    if (_selectedCategories.length > 1) {
                                      _selectedCategories.remove(category);
                                    }
                                  } else {
                                    _selectedCategories.add(category);
                                  }
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
                                      _getCategoryIcon(category),
                                      size: 16,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      category,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.textPrimary,
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
                              const SizedBox(height: 8),
                              ..._aiSuggestedSlots.map((slot) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.event_available,
                                      color: AppColors.success,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        slot,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )).toList(),
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
