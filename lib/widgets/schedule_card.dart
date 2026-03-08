import 'package:flutter/material.dart';
import '../models/schedule_item.dart';
import '../utils/constants.dart';

class ScheduleCard extends StatelessWidget {
  final ScheduleItem scheduleItem;
  final VoidCallback? onTap;

  const ScheduleCard({
    Key? key,
    required this.scheduleItem,
    this.onTap,
  }) : super(key: key);

  Color _getDifficultyColor() {
    switch (scheduleItem.difficulty.toLowerCase()) {
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
        border: Border(
          left: BorderSide(
            width: 4,
            color: _getDifficultyColor(),
          ),
        ),
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
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Column(
                    children: [
                      Text(
                        scheduleItem.time.split(' - ')[0],
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('—'),
                      Text(
                        scheduleItem.time.split(' - ')[1],
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scheduleItem.title,
                        style: AppTextStyles.heading3,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        scheduleItem.subject,
                        style: AppTextStyles.bodySecondary,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getDifficultyColor(),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
