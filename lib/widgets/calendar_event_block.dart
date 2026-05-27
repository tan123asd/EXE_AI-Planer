import 'package:flutter/material.dart';
import '../utils/constants.dart';

class CalendarEventBlock extends StatelessWidget {
  final Color color;
  final String title;
  final String? subtitle;
  final String timeRange;
  final bool isCompleted;
  final VoidCallback? onTap;

  const CalendarEventBlock({
    super.key,
    required this.color,
    required this.title,
    this.subtitle,
    required this.timeRange,
    required this.isCompleted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color.withOpacity(isCompleted ? 0.35 : 0.85);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final h = constraints.maxHeight;
              // Tiered display based on available height:
              // ≤44px  → "title · subtitle" on 1 line (compact, no time)
              // 44-68px → title + subtitle on 2 separate lines (no time)
              // >68px  → title + subtitle + time range
              final showTime = h > 68;
              final showSubtitle = h > 44 && subtitle != null;
              // For tiny blocks, inline the subtitle into the title
              final effectiveTitle = (!showSubtitle && subtitle != null)
                  ? '$title · $subtitle'
                  : title;
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: DefaultTextStyle(
                  style: const TextStyle(
                    color: Colors.white,
                    height: 1.1,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        effectiveTitle,
                        maxLines: showTime ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          decoration:
                              isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (showSubtitle) ...[
                        const SizedBox(height: 1),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.80),
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ],
                      if (showTime) ...[
                        const SizedBox(height: 2),
                        Text(
                          timeRange,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.92),
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

