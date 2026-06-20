import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_ext.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _notifService = NotificationService();
  late bool _enabled;
  List<UpcomingReminder> _reminders = [];

  @override
  void initState() {
    super.initState();
    _enabled = _notifService.enabled;
    _reminders = _notifService.getUpcomingReminders();
  }

  Future<void> _toggleEnabled(bool value) async {
    await _notifService.setEnabled(value);
    setState(() {
      _enabled = value;
      if (value) _reminders = _notifService.getUpcomingReminders();
    });
  }

  String _formatDate(DateTime dt) {
    return DateFormat('EEE, d MMM • HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.notifications, style: AppTextStyles.heading2),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Master toggle card
          _buildToggleCard(l10n),

          const SizedBox(height: AppSpacing.lg),

          // How reminders work
          _buildRulesCard(l10n),

          const SizedBox(height: AppSpacing.lg),

          // Upcoming reminders list
          _buildUpcomingCard(l10n),
        ],
      ),
    );
  }

  Widget _buildToggleCard(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        secondary: Icon(
          _enabled ? Icons.notifications_active : Icons.notifications_off,
          color: _enabled ? AppColors.primary : AppColors.textSecondary,
        ),
        title: Text(l10n.enableNotifications, style: AppTextStyles.body),
        subtitle: Text(
          l10n.notificationsDesc,
          style: AppTextStyles.bodySecondary
              .copyWith(color: AppColors.textSecondary),
        ),
        value: _enabled,
        activeColor: AppColors.primary,
        onChanged: _toggleEnabled,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  Widget _buildRulesCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(l10n.reminderRules, style: AppTextStyles.heading3),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildRuleRow(Icons.access_time, l10n.notifRuleSession),
          const SizedBox(height: AppSpacing.xs),
          _buildRuleRow(Icons.warning_amber_outlined, l10n.notifRuleOverdue),
        ],
      ),
    );
  }

  Widget _buildRuleRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySecondary
                .copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, color: AppColors.primary, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(l10n.upcomingReminders, style: AppTextStyles.heading3),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!_enabled || _reminders.isEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                l10n.noUpcomingReminders,
                style: AppTextStyles.bodySecondary
                    .copyWith(color: AppColors.textSecondary),
              ),
            )
          else
            ...List.generate(_reminders.length, (i) {
              final r = _reminders[i];
              return _buildReminderRow(r, i < _reminders.length - 1);
            }),
        ],
      ),
    );
  }

  Widget _buildReminderRow(UpcomingReminder r, bool showDivider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.taskName,
                        style: AppTextStyles.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(
                      _formatDate(r.reminderAt),
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
              height: 1,
              color: AppColors.textSecondary.withValues(alpha: 0.15)),
      ],
    );
  }
}
