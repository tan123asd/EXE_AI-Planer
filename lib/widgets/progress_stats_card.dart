import 'package:flutter/material.dart';
import '../utils/constants.dart';

class ProgressStatsCard extends StatelessWidget {
  final int completedTasks;
  final int totalTasks;
  final int dayStreak;
  final int focusHours;

  const ProgressStatsCard({
    Key? key,
    required this.completedTasks,
    required this.totalTasks,
    required this.dayStreak,
    required this.focusHours,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: AppColors.textSecondary.withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Day Streak
          Expanded(
            child: _buildStatItem(
              icon: Icons.local_fire_department,
              iconColor: AppColors.danger,
              value: '$dayStreak',
              label: 'Day Streak',
              subtitle: 'Keep it up!',
            ),
          ),
          
          // Vertical Divider
          Container(
            width: 1,
            height: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.textSecondary.withOpacity(0.15),
                  Colors.transparent,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          
          // Focus Hours
          Expanded(
            child: _buildStatItem(
              icon: Icons.access_time_rounded,
              iconColor: AppColors.primary,
              value: '${focusHours}h',
              label: 'Focus Hour',
              subtitle: 'Today',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      child: Column(
        children: [
          // Icon in circle
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 10),
          
          // Value
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          
          // Label
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          
          // Subtitle
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}
