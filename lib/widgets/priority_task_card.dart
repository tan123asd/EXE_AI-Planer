import 'package:flutter/material.dart';
import '../utils/constants.dart';

class PriorityTaskCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String bestSlot;
  final String priority;
  final String subject;
  final Color? accentColor;
  final VoidCallback? onTap;

  const PriorityTaskCard({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.bestSlot,
    required this.priority,
    this.subject = 'Other',
    this.accentColor,
    this.onTap,
  }) : super(key: key);

  Color _getPriorityColor() {
    if (accentColor != null) {
      return accentColor!;
    }

    switch (priority.toLowerCase()) {
      case 'high':
        return AppColors.danger;
      case 'medium':
        return AppColors.medium;
      case 'low':
        return AppColors.success;
      case 'schedule':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }
  
  IconData _getScheduleIcon() {
    // You can add more logic here based on title or category
    return Icons.calendar_month_rounded;
  }
  
  List<Color> _getGradientColors() {
    final baseColor = _getPriorityColor();
    return [
      baseColor.withOpacity(0.08),
      baseColor.withOpacity(0.03),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getGradientColors(),
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getPriorityColor().withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _getPriorityColor().withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Icon with gradient background
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _getPriorityColor().withOpacity(0.2),
                          _getPriorityColor().withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _getScheduleIcon(),
                      color: _getPriorityColor(),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Middle: Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title + Badge
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: _getPriorityColor(),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: _getPriorityColor().withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                priority,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.bookmark_rounded,
                              size: 13,
                              color: _getPriorityColor(),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              subject,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _getPriorityColor(),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        
                        // Weekdays row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 13,
                              color: AppColors.textSecondary.withOpacity(0.7),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary.withOpacity(0.8),
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        
                        // Time slot
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 13,
                                  color: _getPriorityColor().withOpacity(0.8),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  bestSlot,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _getPriorityColor(),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getPriorityColor().withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Weekly',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _getPriorityColor(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
