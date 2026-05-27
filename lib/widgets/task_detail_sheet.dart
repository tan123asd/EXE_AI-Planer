import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';

class TaskDetailSheet extends StatelessWidget {
  final Map<String, dynamic> task;
  final DateTime sessionStart;
  final DateTime sessionEnd;
  final bool isCompleted;
  final Future<void> Function() onMarkCompleted;
  final Future<void> Function()? onDelete;
  final Future<void> Function()? onDeleteSession;

  const TaskDetailSheet({
    super.key,
    required this.task,
    required this.sessionStart,
    required this.sessionEnd,
    required this.isCompleted,
    required this.onMarkCompleted,
    this.onDelete,
    this.onDeleteSession,
  });

  @override
  Widget build(BuildContext context) {
    final title = (task['name'] ?? 'Untitled').toString();
    final subject = (task['subject'] ?? task['taskType'] ?? 'Task').toString();
    final color = AppColors.subjectAccentColor(subject);

    final notes = (task['notes'] ?? '').toString().trim();
    final lines = notes.isEmpty
        ? const <String>[]
        : notes
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();

    final dateText = DateFormat('EEEE, MMMM d yyyy').format(sessionStart);
    final timeText =
        '${_hhmm(sessionStart)}-${_hhmm(sessionEnd)}';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
        ),
        child: Material(
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
                decoration: BoxDecoration(
                  color: color,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$dateText  $timeText',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.92),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    )
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (lines.isNotEmpty) ...[
                      ...lines.map(
                        (l) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 3),
                                child: Icon(
                                  Icons.check_box_outline_blank,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  l,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'No description',
                        style: AppTextStyles.bodySecondary,
                      ),
                    ],

                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.flag_outlined,
                            size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          (task['difficulty'] ?? 'Medium').toString(),
                          style: AppTextStyles.bodySecondary,
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.lock_outline,
                            size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          (task['privacy'] ?? 'Private').toString(),
                          style: AppTextStyles.bodySecondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isCompleted ? null : () => onMarkCompleted(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.textSecondary.withOpacity(0.25),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          isCompleted ? 'Completed' : 'Mark completed',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    if (onDeleteSession != null) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => _confirmDeleteSession(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Xóa buổi này',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (onDelete != null) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => _confirmDelete(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: BorderSide(
                              color: AppColors.danger.withValues(alpha: 0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Xóa toàn bộ task',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteSession(BuildContext context) async {
    final timeText = '${_hhmm(sessionStart)}–${_hhmm(sessionEnd)}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa buổi này'),
        content: Text('Xóa buổi $timeText khỏi task này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onDeleteSession!();
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final title = (task['name'] ?? 'task').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa task'),
        content: Text('Bạn có chắc muốn xóa "$title" và tất cả các buổi học của nó?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onDelete!();
  }

  String _hhmm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

