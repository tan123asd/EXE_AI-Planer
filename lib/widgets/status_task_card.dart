import 'package:flutter/material.dart';
import '../utils/constants.dart';

enum TaskStatus { pending, inProgress, completed }

class StatusTaskCard extends StatefulWidget {
  final String taskId;
  final String title;
  final String timeSlot;
  final String? deadlineText;
  final String duration;
  final String difficulty;
  final String category;
  final String subject;
  final Color? accentColor;
  final TaskStatus status;
  final Function(String taskId, TaskStatus newStatus) onStatusChanged;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const StatusTaskCard({
    Key? key,
    required this.taskId,
    required this.title,
    required this.timeSlot,
    this.deadlineText,
    required this.duration,
    required this.difficulty,
    required this.category,
    this.subject = 'Other',
    this.accentColor,
    this.status = TaskStatus.pending,
    required this.onStatusChanged,
    this.onDelete,
    this.onEdit,
  }) : super(key: key);

  @override
  State<StatusTaskCard> createState() => _StatusTaskCardState();
}

class _StatusTaskCardState extends State<StatusTaskCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.6).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getDifficultyColor() {
    switch (widget.difficulty.toLowerCase()) {
      case 'hard':
        return AppColors.danger;
      case 'medium':
        return AppColors.medium;
      case 'easy':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _getAccentColor() {
    return widget.accentColor ?? AppColors.subjectAccentColor(widget.category);
  }

  Color _getSurfaceColor() {
    return _getAccentColor().withOpacity(0.12);
  }

  IconData _getCategoryIcon() {
    switch (widget.category.toLowerCase()) {
      case 'study':
        return Icons.school;
      case 'personal':
        return Icons.person;
      case 'health':
        return Icons.favorite;
      case 'skill':
        return Icons.auto_awesome;
      case 'other':
        return Icons.more_horiz;
      case 'math':
        return Icons.calculate;
      case 'science':
        return Icons.science;
      case 'marketing':
        return Icons.campaign;
      case 'cs':
        return Icons.computer;
      case 'writing':
        return Icons.edit;
      default:
        return Icons.task;
    }
  }

  void _handleCheckboxTap() {
    if (widget.status == TaskStatus.completed) {
      widget.onStatusChanged(widget.taskId, TaskStatus.pending);
      _animationController.reverse();
    } else {
      widget.onStatusChanged(widget.taskId, TaskStatus.completed);
      _animationController.forward();
      _showCompletionCelebration();
    }
  }

  void _showCompletionCelebration() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text(
              '🎉 Great job! Task completed.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = widget.status == TaskStatus.completed;
    final isInProgress = widget.status == TaskStatus.inProgress;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: isCompleted ? _scaleAnimation.value : 1.0,
          child: Dismissible(
            key: Key(widget.taskId),
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                // Swipe right - Mark complete
                if (!isCompleted) {
                  _handleCheckboxTap();
                }
                return false;
              } else if (direction == DismissDirection.endToStart) {
                // Swipe left - Delete
                return await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Delete Task'),
                      content: const Text(
                          'Are you sure you want to delete this task?'),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ),
                      ],
                    );
                  },
                );
              }
              return false;
            },
            onDismissed: (direction) {
              if (direction == DismissDirection.endToStart) {
                widget.onDelete?.call();
              }
            },
            background: Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 24),
              child: const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 32,
              ),
            ),
            secondaryBackground: Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              child: const Icon(
                Icons.delete,
                color: Colors.white,
                size: 32,
              ),
            ),
            child: Opacity(
              opacity: isCompleted ? _fadeAnimation.value : 1.0,
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: _getSurfaceColor(),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: isInProgress
                        ? _getAccentColor()
                        : _getAccentColor().withOpacity(0.35),
                    width: isInProgress ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isInProgress
                          ? _getAccentColor().withOpacity(0.18)
                          : _getAccentColor().withOpacity(0.08),
                      blurRadius: isInProgress ? 12 : 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      // Tap on card to toggle between completed and pending
                      if (isCompleted) {
                        widget.onStatusChanged(
                            widget.taskId, TaskStatus.pending);
                        _animationController.reverse();
                      } else {
                        widget.onStatusChanged(
                            widget.taskId, TaskStatus.completed);
                        _animationController.forward();
                        _showCompletionCelebration();
                      }
                    },
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          // Checkbox
                          GestureDetector(
                            onTap: _handleCheckboxTap,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? AppColors.success
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isCompleted
                                      ? AppColors.success
                                      : AppColors.textSecondary
                                          .withOpacity(0.3),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: isCompleted
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 18,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          
                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: _getAccentColor(),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      widget.subject,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _getAccentColor(),
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Title with strikethrough if completed
                                Text(
                                  widget.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isCompleted
                                        ? AppColors.textSecondary
                                        : AppColors.textPrimary,
                                    decoration: isCompleted
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                
                                // Time and icons row
                                Row(
                                  children: [
                                    // Time slot
                                    Icon(
                                      Icons.access_time,
                                      size: 14,
                                      color: _getAccentColor(),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.timeSlot,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _getAccentColor(),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    
                                    // Duration
                                    Icon(
                                      Icons.schedule,
                                      size: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.duration,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    if (widget.deadlineText != null &&
                                        widget.deadlineText!.trim().isNotEmpty) ...[
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.event_available_outlined,
                                        size: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          widget.deadlineText!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ] else
                                      const SizedBox(width: 12),
                                    
                                    // Category icon
                                    Icon(
                                      _getCategoryIcon(),
                                      size: 14,
                                      color: _getAccentColor(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // Status indicator & difficulty badge
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Difficulty badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _getDifficultyColor().withOpacity(0.25),
                                  ),
                                ),
                                child: Text(
                                  widget.difficulty,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _getDifficultyColor(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              
                              // Status indicator
                              if (isCompleted)
                                Icon(
                                  Icons.check_circle,
                                  color: AppColors.success,
                                  size: 20,
                                )
                              else if (isInProgress)
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
