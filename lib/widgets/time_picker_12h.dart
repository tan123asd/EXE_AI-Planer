import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';

/// Formats a [TimeOfDay] as a 12-hour string: "2:30 SA" or "5:45 CH".
String fmt12h(TimeOfDay t) {
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final m = t.minute.toString().padLeft(2, '0');
  final suffix = t.period == DayPeriod.am ? 'AM' : 'PM';
  return '$h:$m $suffix';
}

/// Shows a 12-hour time picker dialog with AM/PM (SA/CH) toggle.
/// Returns [TimeOfDay] in Flutter's 24-hour internal format, or null if cancelled.
Future<TimeOfDay?> showTimePicker12h(
  BuildContext context, {
  required TimeOfDay initialTime,
  String? helpText,
}) {
  return showDialog<TimeOfDay>(
    context: context,
    builder: (_) => _TimePicker12hDialog(
      initialTime: initialTime,
      helpText: helpText,
    ),
  );
}

// ─── Dialog ──────────────────────────────────────────────────────────────────

class _TimePicker12hDialog extends StatefulWidget {
  final TimeOfDay initialTime;
  final String? helpText;
  const _TimePicker12hDialog({required this.initialTime, this.helpText});

  @override
  State<_TimePicker12hDialog> createState() => _TimePicker12hDialogState();
}

class _TimePicker12hDialogState extends State<_TimePicker12hDialog> {
  late final TextEditingController _hourCtrl;
  late final TextEditingController _minuteCtrl;
  final _hourFocus = FocusNode();
  final _minuteFocus = FocusNode();
  bool _hourSelected = true;
  late DayPeriod _period;

  @override
  void initState() {
    super.initState();
    _period = widget.initialTime.period;
    final h = widget.initialTime.hourOfPeriod == 0 ? 12 : widget.initialTime.hourOfPeriod;
    _hourCtrl = TextEditingController(text: h.toString().padLeft(2, '0'));
    _minuteCtrl = TextEditingController(
      text: widget.initialTime.minute.toString().padLeft(2, '0'),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hourFocus.requestFocus();
      _hourCtrl.selection =
          TextSelection(baseOffset: 0, extentOffset: _hourCtrl.text.length);
    });
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    _hourFocus.dispose();
    _minuteFocus.dispose();
    super.dispose();
  }

  TimeOfDay? get _result {
    final h = int.tryParse(_hourCtrl.text);
    final m = int.tryParse(_minuteCtrl.text);
    if (h == null || m == null || h < 1 || h > 12 || m < 0 || m > 59) return null;
    final hour24 =
        _period == DayPeriod.am ? (h == 12 ? 0 : h) : (h == 12 ? 12 : h + 12);
    return TimeOfDay(hour: hour24, minute: m);
  }

  void _onHourChanged(String v) {
    if (v.length == 2) {
      final n = int.tryParse(v);
      if (n != null && n > 12) {
        _hourCtrl.text = '12';
        _hourCtrl.selection = const TextSelection.collapsed(offset: 2);
      } else if (n != null && n < 1) {
        _hourCtrl.text = '01';
        _hourCtrl.selection = const TextSelection.collapsed(offset: 2);
      }
      setState(() => _hourSelected = false);
      _minuteFocus.requestFocus();
      _minuteCtrl.selection =
          TextSelection(baseOffset: 0, extentOffset: _minuteCtrl.text.length);
    }
  }

  void _onMinuteChanged(String v) {
    if (v.length == 2) {
      final n = int.tryParse(v);
      if (n != null && n > 59) {
        _minuteCtrl.text = '59';
        _minuteCtrl.selection = const TextSelection.collapsed(offset: 2);
      }
      setState(() {});
    }
  }

  Widget _field({
    required TextEditingController ctrl,
    required FocusNode focus,
    required bool isActive,
    required String label,
    required VoidCallback onTap,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            onTap();
            focus.requestFocus();
            ctrl.selection =
                TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
          },
          child: Container(
            width: 80,
            height: 72,
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary.withOpacity(0.12)
                  : const Color(0xFFEEF0F2),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: TextField(
              controller: ctrl,
              focusNode: focus,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              style: TextStyle(
                fontSize: 45,
                fontWeight: FontWeight.w300,
                color: AppColors.textPrimary,
                height: 1,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              onTap: () {
                onTap();
                ctrl.selection =
                    TextSelection(baseOffset: 0, extentOffset: ctrl.text.length);
              },
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
              widget.helpText ?? 'Nhập thời gian',
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
                _field(
                  ctrl: _hourCtrl,
                  focus: _hourFocus,
                  isActive: _hourSelected,
                  label: 'Giờ',
                  onTap: () => setState(() => _hourSelected = true),
                  onChanged: _onHourChanged,
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
                _field(
                  ctrl: _minuteCtrl,
                  focus: _minuteFocus,
                  isActive: !_hourSelected,
                  label: 'Phút',
                  onTap: () => setState(() => _hourSelected = false),
                  onChanged: _onMinuteChanged,
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Column(
                    children: [
                      _PeriodBtn(
                        label: 'AM',
                        selected: _period == DayPeriod.am,
                        onTap: () => setState(() => _period = DayPeriod.am),
                      ),
                      const SizedBox(height: 6),
                      _PeriodBtn(
                        label: 'PM',
                        selected: _period == DayPeriod.pm,
                        onTap: () => setState(() => _period = DayPeriod.pm),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
                  onPressed: () => Navigator.of(context).pop(_result),
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

// ─── AM/PM toggle button ──────────────────────────────────────────────────────

class _PeriodBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 52,
        height: 36,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
          border: Border.all(
            color: selected ? AppColors.primary : Colors.grey.shade400,
            width: selected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
