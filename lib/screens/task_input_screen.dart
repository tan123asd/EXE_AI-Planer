import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';
import 'dart:math';
import 'package:intl/intl.dart';

class TaskInputScreen extends StatefulWidget {
  const TaskInputScreen({Key? key}) : super(key: key);

  @override
  State<TaskInputScreen> createState() => _TaskInputScreenState();
}

class _TaskInputScreenState extends State<TaskInputScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final StorageService _storage = StorageService();
  final TextEditingController _taskNameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _customTimeController = TextEditingController();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
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
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _deadline = picked;
      });
    }
  }

  void _generateAIEstimate() {
    if (_formKey.currentState!.validate() && _deadline != null) {
      _formKey.currentState!.save();
      
      // Simple AI estimation logic
      final random = Random();
      final hours = _difficulty == 'Easy' ? random.nextInt(2) + 1 : 
                    _difficulty == 'Medium' ? random.nextInt(3) + 2 : 
                    random.nextInt(4) + 3;
      final minutes = random.nextInt(6) * 10;
      _estimatedTime = '${hours}h ${minutes}m';
      
      // Calculate best slot (simplified)
      final now = DateTime.now();
      final suggestedHour = _difficulty == 'Hard' ? 9 : 
                           _difficulty == 'Medium' ? 14 : 19;
      _bestSlot = 'Today ${suggestedHour}:00 ${suggestedHour < 12 ? 'AM' : 'PM'}';
      
      // Set priority based on deadline and difficulty
      final daysUntilDeadline = _deadline!.difference(now).inDays;
      if (_difficulty == 'Hard' || daysUntilDeadline <= 2) {
        _priority = 'High';
      } else if (_difficulty == 'Medium' || daysUntilDeadline <= 5) {
        _priority = 'Medium';
      } else {
        _priority = 'Low';
      }
      
      setState(() {
        _showAIPreview = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _addTaskToPlan() async {
    final taskData = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': _taskName,
      'subject': _category,
      'difficulty': _difficulty,
      'deadline': _deadline?.toIso8601String(),
      'estimatedTime': int.parse(_estimatedTime.split('h')[0]),
      'category': _category,
      'createdAt': DateTime.now().toIso8601String(),
    };
    
    await _storage.addCustomTask(taskData);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task added to your plan!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Task Title
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.description_outlined, 
                                 size: 18, 
                                 color: AppColors.textSecondary),
                            SizedBox(width: 8),
                            Text(
                              'TASK TITLE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _taskNameController,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Marketing presentation slides',
                            hintStyle: TextStyle(
                              color: Color(0xFFCCCCCC),
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(
                            fontSize: 15,
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
                  const SizedBox(height: AppSpacing.md),
                  
                  // Deadline
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.calendar_today_outlined, 
                                 size: 18, 
                                 color: AppColors.textSecondary),
                            SizedBox(width: 8),
                            Text(
                              'DEADLINE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () => _selectDate(context),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _deadline != null
                                    ? '${_deadline!.day.toString().padLeft(2, '0')}/${_deadline!.month.toString().padLeft(2, '0')}/${_deadline!.year}'
                                    : 'dd/mm/yyyy',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: _deadline != null
                                      ? AppColors.textPrimary
                                      : const Color(0xFFCCCCCC),
                                ),
                              ),
                              const Icon(Icons.calendar_month, 
                                         color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  // Difficulty
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.label_outline, 
                                 size: 18, 
                                 color: AppColors.textSecondary),
                            SizedBox(width: 8),
                            Text(
                              'DIFFICULTY',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: _difficulties.map((difficulty) {
                            final isSelected = _difficulty == difficulty;
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: difficulty != _difficulties.last ? 8 : 0,
                                ),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _difficulty = difficulty;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                          : const Color(0xFFF5F5F5),
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                    ),
                                    child: Text(
                                      difficulty,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isSelected 
                                            ? Colors.white 
                                            : AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
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
                  const SizedBox(height: AppSpacing.md),
                  
                  // Category
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.label_outline, 
                                 size: 18, 
                                 color: AppColors.textSecondary),
                            SizedBox(width: 8),
                            Text(
                              'CATEGORY',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _categories.map((category) {
                            final isSelected = _category == category;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _category = category;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    color: isSelected 
                                        ? Colors.white 
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  // Notes (Optional)
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.description_outlined, 
                                 size: 18, 
                                 color: AppColors.textSecondary),
                            SizedBox(width: 8),
                            Text(
                              'NOTES (OPTIONAL)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Any additional info for the AI...',
                            hintStyle: TextStyle(
                              color: Color(0xFFCCCCCC),
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                          onSaved: (value) => _notes = value ?? '',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  
                  // Get AI Estimate Button (or AI Preview)
                  if (!_showAIPreview) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _generateAIEstimate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.auto_awesome, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Get AI Estimate',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // AI Smart Preview Card
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFFFF8C5A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.auto_awesome, 
                                   color: Colors.white, 
                                   size: 18),
                              SizedBox(width: 8),
                              Text(
                                'AI SMART PREVIEW',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildPreviewRow(
                            Icons.access_time,
                            'Estimated time:',
                            _estimatedTime,
                          ),
                          const SizedBox(height: 12),
                          _buildPreviewRow(
                            Icons.calendar_today,
                            'Best slot:',
                            _bestSlot,
                          ),
                          const SizedBox(height: 12),
                          _buildPreviewRow(
                            Icons.label,
                            'Priority:',
                            _priority,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _addTaskToPlan,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.3),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                ),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text(
                                    'Add to My Plan',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.check_circle, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildPreviewRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
