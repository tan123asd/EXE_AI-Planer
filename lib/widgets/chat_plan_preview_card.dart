import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/scheduler_models.dart';
import '../utils/constants.dart';
import 'time_picker_12h.dart';

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
  late Set<int> _selectedIndices;
  final Set<int> _editedIndices = {};
  final List<Map<String, dynamic>> _customSlots = [];
  DateTime? _customSlotDate;
  TimeOfDay? _customSlotStart;
  TimeOfDay? _customSlotEnd;
  final TextEditingController _customSubtaskNameController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _editableSlots = List.from(widget.schedule.scheduledSlots);
    _selectedIndices = Set.from(List.generate(_editableSlots.length, (i) => i));
  }

  @override
  void dispose() {
    _customSubtaskNameController.dispose();
    super.dispose();
  }

  List<String> _findOverlaps(DateTime newStart, DateTime newEnd) {
    final conflicts = <String>[];
    for (int i = 0; i < _editableSlots.length; i++) {
      if (!_selectedIndices.contains(i)) continue;
      final slot = _editableSlots[i];
      if (newStart.isBefore(slot.endTime) && slot.startTime.isBefore(newEnd)) {
        conflicts.add(slot.taskName);
      }
    }
    for (final c in _customSlots) {
      final s = DateTime.parse(c['startTime'] as String);
      final e = DateTime.parse(c['endTime'] as String);
      if (newStart.isBefore(e) && s.isBefore(newEnd)) {
        conflicts.add(c['subtaskName'] as String? ?? 'Custom slot');
      }
    }
    return conflicts;
  }

  Map<String, List<int>> _groupBySubtask() {
    final groups = <String, List<int>>{};
    for (int i = 0; i < _editableSlots.length; i++) {
      groups.putIfAbsent(_editableSlots[i].taskId, () => []).add(i);
    }
    return groups;
  }

  Future<void> _editSlot(int index) async {
    final slot = _editableSlots[index];
    final duration = slot.endTime.difference(slot.startTime);

    final pickerTheme = Theme.of(context).copyWith(
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
    );

    final date = await showDatePicker(
      context: context,
      initialDate: slot.startTime.isAfter(DateTime.now())
          ? slot.startTime
          : DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(data: pickerTheme, child: child!),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker12h(
      context,
      initialTime: TimeOfDay.fromDateTime(slot.startTime),
    );
    if (time == null || !mounted) return;

    final newStart =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
      _editedIndices.add(index);
    });
  }

  Future<void> _addCustomSlot() async {
    final subtaskName = _customSubtaskNameController.text.trim();
    if (subtaskName.isEmpty ||
        _customSlotDate == null ||
        _customSlotStart == null ||
        _customSlotEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please set subtask name, date, start and end time'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final startMin =
        _customSlotStart!.hour * 60 + _customSlotStart!.minute;
    final endMin = _customSlotEnd!.hour * 60 + _customSlotEnd!.minute;
    if (endMin <= startMin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('End time must be after start time'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final start = DateTime(
      _customSlotDate!.year,
      _customSlotDate!.month,
      _customSlotDate!.day,
      _customSlotStart!.hour,
      _customSlotStart!.minute,
    );
    final end = DateTime(
      _customSlotDate!.year,
      _customSlotDate!.month,
      _customSlotDate!.day,
      _customSlotEnd!.hour,
      _customSlotEnd!.minute,
    );

    final conflicts = _findOverlaps(start, end);
    if (conflicts.isNotEmpty && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: AppColors.warning),
              SizedBox(width: 8),
              Text('Time Conflict'),
            ],
          ),
          content: Text(
            'This slot overlaps with:\n'
            '${conflicts.map((c) => '• $c').join('\n')}\n\n'
            'Do you want to add it anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Anyway'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    setState(() {
      _customSlots.add({
        'subtaskName': subtaskName,
        'startTime': start.toIso8601String(),
        'endTime': end.toIso8601String(),
        'duration': end.difference(start).inMinutes,
      });
      _customSubtaskNameController.clear();
      _customSlotDate = null;
      _customSlotStart = null;
      _customSlotEnd = null;
    });
  }

  void _onApprove() {
    final selected = <ScheduledSlot>[];
    for (int i = 0; i < _editableSlots.length; i++) {
      if (_selectedIndices.contains(i)) selected.add(_editableSlots[i]);
    }
    for (final c in _customSlots) {
      final start = DateTime.parse(c['startTime'] as String);
      final end = DateTime.parse(c['endTime'] as String);
      final subtaskName = c['subtaskName'] as String? ?? widget.goalName;
      final matchingTask = widget.plan.tasks
          .where((t) => t.name == subtaskName)
          .firstOrNull;
      final taskId = matchingTask?.order.toString() ??
          'custom_${selected.length}';
      selected.add(ScheduledSlot(
        taskId: taskId,
        taskName: subtaskName,
        sessionIndex: selected.length,
        startTime: start,
        endTime: end,
      ));
    }
    widget.onApprove(selected);
  }

  String _fmt24(DateTime dt, {bool isEnd = false}) {
    if (isEnd && dt.hour == 0 && dt.minute == 0) return '24:00';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final totalHours =
        (widget.plan.totalDurationMinutes / 60).toStringAsFixed(1);
    final groups = _groupBySubtask();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            Colors.blue.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.smart_toy,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'AI recommendation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Estimated effort ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                const Text(
                  'Estimated effort: ',
                  style: TextStyle(
                      fontSize: 14, color: AppColors.textSecondary),
                ),
                Text(
                  '$totalHours hours',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── "Suggested schedule" label + hint ────────────────────────────
          const Text(
            'Suggested schedule:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: const [
              Icon(Icons.touch_app_outlined,
                  size: 12, color: AppColors.textSecondary),
              SizedBox(width: 4),
              Text(
                'Tap to select/deselect  •  Tap ',
                style:
                    TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              Icon(Icons.edit_calendar_outlined,
                  size: 12, color: AppColors.primary),
              Text(
                ' to adjust times',
                style:
                    TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Warning for unscheduled tasks ────────────────────────────────
          if (widget.schedule.failedTasks.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.warning, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚠️ Cannot fit before deadline: '
                      '${widget.schedule.failedTasks.map((t) => t.name).join(', ')}. '
                      'Consider extending deadline or reducing scope.',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Slot cards grouped by subtask ────────────────────────────────
          ...widget.plan.tasks.map((subtask) {
            final indices = groups[subtask.order.toString()] ?? [];
            if (indices.isEmpty) {
              return _buildUnscheduledRow(subtask.name);
            }
            if (indices.length == 1) {
              return _buildSingleSlotCard(indices.first, subtask.name);
            }
            return _buildMultiSlotCard(subtask.name, indices);
          }),

          // ── Create your own slot ─────────────────────────────────────────
          const SizedBox(height: 20),
          const Text(
            'Create your own slot',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: _customSubtaskNameController,
              decoration: const InputDecoration(
                hintText: 'Subtask name',
                hintStyle: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildDateField()),
              const SizedBox(width: 8),
              Expanded(child: _buildTimeField(isStart: true)),
              const SizedBox(width: 8),
              Expanded(child: _buildTimeField(isStart: false)),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addCustomSlot,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Add'),
              ),
            ],
          ),

          // Added custom slots
          if (_customSlots.isNotEmpty) ...[
            const SizedBox(height: 10),
            ..._customSlots.asMap().entries.map((entry) {
              final idx = entry.key;
              final c = entry.value;
              final start = DateTime.parse(c['startTime'] as String);
              final end = DateTime.parse(c['endTime'] as String);
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((c['subtaskName'] as String?)?.isNotEmpty == true)
                            Text(
                              c['subtaskName'] as String,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          Text(
                            '${DateFormat('d/M/yyyy').format(start)}  '
                            '${_fmt24(start)} – ${_fmt24(end, isEnd: true)}',
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _customSlots.removeAt(idx)),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.cancel_outlined,
                            size: 20, color: Color(0xFFD4A20A)),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          // ── Action buttons ───────────────────────────────────────────────
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
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
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: (_selectedIndices.isNotEmpty ||
                          _customSlots.isNotEmpty)
                      ? _onApprove
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  child: const Text(
                    'Approve & Schedule',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Slot card builders ───────────────────────────────────────────────────

  Widget _buildUnscheduledRow(String subtaskName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.warning.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.warning, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$subtaskName — could not schedule',
              style: AppTextStyles.caption.copyWith(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleSlotCard(int slotIndex, String subtaskName) {
    final slot = _editableSlots[slotIndex];
    final isSelected = _selectedIndices.contains(slotIndex);
    final isEdited = _editedIndices.contains(slotIndex);
    final durationMins =
        slot.endTime.difference(slot.startTime).inMinutes;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withOpacity(0.07) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppColors.primary
              : isEdited
                  ? const Color(0xFFD4A20A)
                  : Colors.grey.shade200,
          width: isSelected ? 2 : 1.5,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() {
          isSelected
              ? _selectedIndices.remove(slotIndex)
              : _selectedIndices.add(slotIndex);
        }),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isSelected ? AppColors.primary : Colors.grey.shade400,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isEdited) _buildEditedBadge(),
                    Text(
                      subtaskName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${DateFormat('EEE, MMM d').format(slot.startTime)} • '
                      '${_fmt24(slot.startTime)} – ${_fmt24(slot.endTime, isEnd: true)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    if (durationMins > 60) ...[
                      const SizedBox(height: 4),
                      const Text(
                        '⏱️ 50min work / 10min break',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildEditButton(slotIndex, isEdited),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMultiSlotCard(String subtaskName, List<int> indices) {
    final allSelected = indices.every((i) => _selectedIndices.contains(i));
    final anySelected = indices.any((i) => _selectedIndices.contains(i));
    final anyEdited = indices.any((i) => _editedIndices.contains(i));
    final totalDurationMins = indices.fold<int>(0, (sum, i) {
      final s = _editableSlots[i];
      return sum + s.endTime.difference(s.startTime).inMinutes;
    });

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: anySelected
            ? AppColors.primary.withOpacity(0.07)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: allSelected
              ? AppColors.primary
              : anyEdited
                  ? const Color(0xFFD4A20A)
                  : Colors.grey.shade200,
          width: allSelected ? 2 : 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subtask header row (tap to toggle all)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() {
                if (allSelected) {
                  _selectedIndices.removeAll(indices);
                } else {
                  _selectedIndices.addAll(indices);
                }
              }),
              child: Row(
                children: [
                  Icon(
                    allSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: allSelected
                        ? AppColors.primary
                        : Colors.grey.shade400,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$subtaskName • ${indices.length} sessions',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: allSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Individual session rows
            ...indices.map((idx) {
              final slot = _editableSlots[idx];
              final isSel = _selectedIndices.contains(idx);
              final isEdited = _editedIndices.contains(idx);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() {
                  isSel
                      ? _selectedIndices.remove(idx)
                      : _selectedIndices.add(idx);
                }),
                child: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Row(
                    children: [
                      Icon(
                        isSel
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 15,
                        color: isSel
                            ? AppColors.primary
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${DateFormat('EEE, MMM d').format(slot.startTime)} • '
                          '${_fmt24(slot.startTime)} – ${_fmt24(slot.endTime, isEnd: true)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSel
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: isSel
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildEditButton(idx, isEdited, size: 14, padding: 5),
                    ],
                  ),
                ),
              );
            }),
            if (totalDurationMins > 60) ...[
              const SizedBox(height: 6),
              const Text(
                '⏱️ 50min work / 10min break',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEditButton(int slotIndex, bool isEdited,
      {double size = 16, double padding = 7}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _editSlot(slotIndex),
      child: Tooltip(
        message: 'Adjust time',
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: isEdited
                ? const Color(0xFFFFF3CD)
                : AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            Icons.edit_calendar_outlined,
            color: isEdited ? const Color(0xFF8B6914) : AppColors.primary,
            size: size,
          ),
        ),
      ),
    );
  }

  Widget _buildEditedBadge() {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit, size: 11, color: Color(0xFF8B6914)),
          SizedBox(width: 4),
          Text(
            'Manually adjusted',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8B6914),
            ),
          ),
        ],
      ),
    );
  }

  // ── Custom slot input widgets ────────────────────────────────────────────

  Widget _buildDateField() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _customSlotDate ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (c, child) => Theme(
            data: Theme.of(c).copyWith(
              colorScheme: ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: AppColors.textPrimary,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) setState(() => _customSlotDate = picked);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          _customSlotDate != null
              ? DateFormat('dd/MM/yyyy').format(_customSlotDate!)
              : 'dd/mm/yyyy',
          style: TextStyle(
            fontSize: 13,
            color: _customSlotDate != null
                ? AppColors.textPrimary
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeField({required bool isStart}) {
    final current = isStart ? _customSlotStart : _customSlotEnd;
    final label = isStart ? 'Bắt đầu' : 'Kết thúc';
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker12h(
          context,
          initialTime: current ??
              (isStart ? TimeOfDay.now() : const TimeOfDay(hour: 10, minute: 0)),
        );
        if (picked != null) {
          setState(() {
            if (isStart) {
              _customSlotStart = picked;
            } else {
              _customSlotEnd = picked;
            }
          });
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          current != null ? fmt12h(current) : label,
          style: TextStyle(
            fontSize: 13,
            color: current != null
                ? AppColors.textPrimary
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
