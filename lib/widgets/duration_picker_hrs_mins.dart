import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';

/// Shows a duration picker dialog with **hours + minutes** (no AM/PM).
///
/// - Hours range: 0..maxHours
/// - Minutes must be multiples of [minuteStep] (e.g. 5)
/// Returns the selected duration in **minutes** when user taps OK, otherwise null.
Future<int?> showDurationPickerHrsMins(
  BuildContext context, {
  required int initialMinutes,
  int maxHours = 12,
  int minuteStep = 5,
  String? helpText,
}) {
  final clamped = initialMinutes.clamp(0, maxHours * 60);
  final initialHours = clamped ~/ 60;
  final initialMins = clamped % 60;

  // Snap initial minutes to nearest step within 0..59.
  final step = minuteStep <= 0 ? 1 : minuteStep;
  final snappedMins = ((initialMins / step).round() * step).clamp(0, 59);

  return showDialog<int>(
    context: context,
    builder: (_) => _DurationPickerHrsMinsDialog(
      initialHours: initialHours.clamp(0, maxHours),
      initialMinutes: snappedMins,
      maxHours: maxHours,
      minuteStep: step,
      helpText: helpText,
    ),
  );
}

class _DurationPickerHrsMinsDialog extends StatefulWidget {
  final int initialHours;
  final int initialMinutes;
  final int maxHours;
  final int minuteStep;
  final String? helpText;

  const _DurationPickerHrsMinsDialog({
    required this.initialHours,
    required this.initialMinutes,
    required this.maxHours,
    required this.minuteStep,
    this.helpText,
  });

  @override
  State<_DurationPickerHrsMinsDialog> createState() => _DurationPickerHrsMinsDialogState();
}

class _DurationPickerHrsMinsDialogState extends State<_DurationPickerHrsMinsDialog> {
  late int _hours;
  late int _minutes;


  FixedExtentScrollController _hourScrollController = FixedExtentScrollController();
  FixedExtentScrollController _minuteScrollController = FixedExtentScrollController();


  List<int> get _minuteOptions =>
      List<int>.generate((60 ~/ widget.minuteStep) + (60 % widget.minuteStep == 0 ? 0 : 1), (i) {
        final v = i * widget.minuteStep;
        return v;
      }).where((v) => v >= 0 && v <= 59).toList();

  int get _minutesIndex {
    final idx = _minuteOptions.indexOf(_minutes);
    return idx >= 0 ? idx : 0;
  }

  @override
  void initState() {
    super.initState();

    _hours = widget.initialHours.clamp(0, widget.maxHours);
    // Snap to nearest step within 0..59
    final step = widget.minuteStep <= 0 ? 5 : widget.minuteStep;
    final snapped = ((widget.initialMinutes / step).round() * step).clamp(0, 59);
    _minutes = snapped - (snapped % step);

    _hourScrollController = FixedExtentScrollController(initialItem: _hours);
    _minuteScrollController = FixedExtentScrollController(initialItem: _minutesIndex);
  }

  @override
  void dispose() {
    _hourScrollController.dispose();
    _minuteScrollController.dispose();
    super.dispose();
  }

  int get _resultMinutes => _hours * 60 + _minutes;

  @override
  Widget build(BuildContext context) {
    const double itemExtent = 54;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.helpText ?? 'Chọn thời lượng',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Hours wheel
                SizedBox(
                  width: 100,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 54,
                        child: ListWheelScrollView.useDelegate(
                          controller: _hourScrollController,
                          itemExtent: itemExtent,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (idx) {
                            setState(() => _hours = idx);
                          },
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: widget.maxHours + 1,
                            builder: (ctx, idx) {
                              final h = idx as int;
                              final isSelected = h == _hours;
                              return Center(
                                child: Text(
                                  h.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: 45,
                                    fontWeight: FontWeight.w300,
                                    color: isSelected
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary.withOpacity(0.55),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Giờ',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 22, left: 6, right: 6),
                  child: Text(
                    ':',
                    style: TextStyle(
                      fontSize: 45,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textPrimary,
                      height: 1,
                    ),
                  ),
                ),

                // Minutes wheel
                SizedBox(
                  width: 100,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 54,
                        child: ListWheelScrollView.useDelegate(
                          controller: _minuteScrollController,
                          itemExtent: itemExtent,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (idx) {
                            final newMinutes = _minuteOptions[idx];
                            setState(() => _minutes = newMinutes);
                          },
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: _minuteOptions.length,
                            builder: (ctx, idx) {
                              final i = idx as int;
                              final m = _minuteOptions[i];
                              final isSelected = m == _minutes;
                              return Center(
                                child: Text(
                                  m.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: 45,
                                    fontWeight: FontWeight.w300,
                                    color: isSelected
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary.withOpacity(0.55),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Phút',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),
              ],
            ),

   

            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Hủy',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(_resultMinutes);
                  },
                  child: Text(
                    'OK',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


