import 'package:flutter/material.dart';
import '../models/task.dart';
import '../utils/constants.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;
  final ValueChanged<bool?>? onCheckboxChanged;

  const TaskCard({
    Key? key,
    required this.task,
    this.onTap,
    this.onCheckboxChanged,
  }) : super(key: key);

  Color _getDifficultyColor() {
    switch (task.difficulty.toLowerCase()) {
      case 'easy':
        return AppColors.easy;
      case 'medium':
        return AppColors.medium;
      case 'hard':
        return AppColors.hard;
      default:
        return AppColors.medium;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Checkbox(
                  value: task.isCompleted,
                  onChanged: onCheckboxChanged,
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.name,
                        style: AppTextStyles.heading3.copyWith(
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        task.subject,
                        style: AppTextStyles.bodySecondary,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: _getDifficultyColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        task.difficulty,
                        style: AppTextStyles.caption.copyWith(
                          color: _getDifficultyColor(),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          task.time,
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                    if (task.deadline != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: _isDeadlineClose(task.deadline!) 
                                ? AppColors.danger 
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDeadline(task.deadline!),
                            style: AppTextStyles.caption.copyWith(
                              color: _isDeadlineClose(task.deadline!) 
                                  ? AppColors.danger 
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isDeadlineClose(DateTime deadline) {
    final now = DateTime.now();
    final difference = deadline.difference(now).inDays;
    return difference <= 1 && difference >= 0;
  }

  String _formatDeadline(DateTime deadline) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDate = DateTime(deadline.year, deadline.month, deadline.day);
    final difference = deadlineDate.difference(today).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else if (difference == -1) {
      return 'Yesterday';
    } else if (difference > 1 && difference <= 7) {
      return 'in $difference days';
    } else if (difference < -1) {
      return '${-difference} days ago';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[deadline.month - 1]} ${deadline.day}';
    }
  }
}
