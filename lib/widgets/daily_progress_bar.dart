import 'package:flutter/material.dart';
import '../utils/constants.dart';

class DailyProgressBar extends StatelessWidget {
  final int completedTasks;
  final int totalTasks;

  const DailyProgressBar({
    Key? key,
    required this.completedTasks,
    required this.totalTasks,
  }) : super(key: key);

  double get _progress {
    if (totalTasks == 0) return 0.0;
    return completedTasks / totalTasks;
  }

  String get _progressText {
    final percentage = (_progress * 100).toInt();
    return '$percentage%';
  }

  Color get _progressColor {
    if (_progress < 0.3) return AppColors.danger;
    if (_progress < 0.7) return AppColors.medium;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Progress",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _progressColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _progressText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _progressColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Progress bar
          Stack(
            children: [
              // Background
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              // Progress
              FractionallySizedBox(
                widthFactor: _progress,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _progressColor,
                        _progressColor.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: _progressColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          // Task count
          Row(
            children: [
              Icon(
                Icons.task_alt,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                '$completedTasks of $totalTasks tasks completed',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (completedTasks == totalTasks && totalTasks > 0) ...[
                const SizedBox(width: 8),
                const Text(
                  '🎉',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
