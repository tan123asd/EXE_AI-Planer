import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/scheduler_models.dart';
import '../utils/constants.dart';

class ChatPlanPreviewCard extends StatefulWidget {
  final String goalName;
  final AiTaskPlan plan;
  final ScheduleResult schedule;
  final void Function(List<ScheduledSlot> slots) onApprove;
  final VoidCallback onReject;

  const ChatPlanPreviewCard({
    Key? key,
    required this.goalName,
    required this.plan,
    required this.schedule,
    required this.onApprove,
    required this.onReject,
  }) : super(key: key);

  @override
  State<ChatPlanPreviewCard> createState() => _ChatPlanPreviewCardState();
}

class _ChatPlanPreviewCardState extends State<ChatPlanPreviewCard> {
  late List<ScheduledSlot> _editableSlots;

  @override
  void initState() {
    super.initState();
    _editableSlots = List.from(widget.schedule.scheduledSlots);
  }

  Future<void> _editSlot(int index) async {
    final slot = _editableSlots[index];
    final duration = slot.endTime.difference(slot.startTime);

    final date = await showDatePicker(
      context: context,
      initialDate: slot.startTime.isAfter(DateTime.now())
          ? slot.startTime
          : DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(slot.startTime),
    );
    if (time == null) return;

    final newStart = DateTime(
        date.year, date.month, date.day, time.hour, time.minute);
    final newEnd = newStart.add(duration);

    setState(() {
      _editableSlots[index] = ScheduledSlot(
        taskId: slot.taskId,
        taskName: slot.taskName,
        sessionIndex: slot.sessionIndex,
        startTime: newStart,
        endTime: newEnd,
        score: slot.score,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalHours =
        (widget.plan.totalDurationMinutes / 60).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(totalHours),

          // Warning if tasks couldn't fit
          if (widget.schedule.failedTasks.isNotEmpty)
            _buildWarning(),

          // Hint
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                Text(
                  'Scheduled Sessions',
                  style: AppTextStyles.bodySecondary.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.touch_app_outlined,
                    size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 2),
                Text(
                  'Tap a slot to reschedule',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Subtask rows
          ...widget.plan.tasks.map((subtask) {
            final indexed = <_IndexedSlot>[];
            for (int i = 0; i < _editableSlots.length; i++) {
              if (_editableSlots[i].taskId == subtask.order.toString()) {
                indexed.add(_IndexedSlot(index: i, slot: _editableSlots[i]));
              }
            }
            return _SubtaskRow(
              subtask: subtask,
              indexedSlots: indexed,
              onEditSlot: _editSlot,
            );
          }),

          if (_editableSlots.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              child: Text(
                'No sessions could be scheduled. Try extending the deadline.',
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.danger),
              ),
            ),

          const SizedBox(height: 12),
          const Divider(height: 1),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side:
                          const BorderSide(color: AppColors.textSecondary),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _editableSlots.isNotEmpty
                        ? () => widget.onApprove(_editableSlots)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: const Text(
                      'Approve & Schedule',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String totalHours) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.lg),
          topRight: Radius.circular(AppRadius.lg),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.goalName,
                  style: AppTextStyles.heading3.copyWith(fontSize: 15),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$totalHours hours total · ${widget.plan.tasks.length} subtasks',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarning() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.warning, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${widget.schedule.failedTasks.length} task(s) could not fit before the deadline.',
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data helper ───────────────────────────────────────────────────────────────

class _IndexedSlot {
  final int index;
  final ScheduledSlot slot;
  const _IndexedSlot({required this.index, required this.slot});
}

// ── Subtask row ───────────────────────────────────────────────────────────────

class _SubtaskRow extends StatelessWidget {
  final AiSubtask subtask;
  final List<_IndexedSlot> indexedSlots;
  final void Function(int slotIndex) onEditSlot;

  const _SubtaskRow({
    required this.subtask,
    required this.indexedSlots,
    required this.onEditSlot,
  });

  @override
  Widget build(BuildContext context) {
    final durationStr = subtask.duration >= 1
        ? '${subtask.duration.toStringAsFixed(1)}h'
        : '${(subtask.duration * 60).round()}min';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subtask.name,
                        style: AppTextStyles.bodySecondary.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      durationStr,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                if (indexedSlots.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: indexedSlots
                        .map((s) => _SlotChip(
                              indexedSlot: s,
                              onEdit: () => onEditSlot(s.index),
                            ))
                        .toList(),
                  )
                else
                  Text(
                    'Could not schedule',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.warning),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tappable slot chip ────────────────────────────────────────────────────────

class _SlotChip extends StatelessWidget {
  final _IndexedSlot indexedSlot;
  final VoidCallback onEdit;

  const _SlotChip({required this.indexedSlot, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final start = indexedSlot.slot.startTime.toLocal();
    final end = indexedSlot.slot.endTime.toLocal();
    final label =
        '${DateFormat('EEE, MMM d').format(start)}  '
        '${DateFormat('HH:mm').format(start)}–${DateFormat('HH:mm').format(end)}';

    return GestureDetector(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border:
              Border.all(color: AppColors.primary.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule_rounded,
                size: 12, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.edit_outlined,
                size: 11, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
