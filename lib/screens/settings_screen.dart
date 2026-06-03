import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_ext.dart';
import '../providers/theme_provider.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';
import 'notifications_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _notifService = NotificationService();
  late bool _notifEnabled;

  @override
  void initState() {
    super.initState();
    _notifEnabled = _notifService.enabled;
  }

  Future<void> _toggleNotifications(bool value) async {
    await _notifService.setEnabled(value);
    setState(() => _notifEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.settingsTitle, style: AppTextStyles.heading2),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Appearance section
          _buildSectionHeader(l10n.appearance),
          const SizedBox(height: AppSpacing.xs),
          _buildSwitchTile(
            icon: Icons.dark_mode_outlined,
            title: l10n.darkMode,
            value: themeProvider.isDarkMode,
            onChanged: (_) => themeProvider.toggleTheme(),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Notifications section
          _buildSectionHeader(l10n.notifications),
          const SizedBox(height: AppSpacing.xs),
          _buildSwitchTile(
            icon: _notifEnabled
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            title: l10n.enableNotifications,
            value: _notifEnabled,
            onChanged: _toggleNotifications,
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildArrowTile(
            icon: Icons.tune_outlined,
            title: l10n.notifications,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const NotificationsScreen()),
              );
              // Refresh toggle in case user changed it inside
              setState(() => _notifEnabled = _notifService.enabled);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(
          left: AppSpacing.xs, bottom: AppSpacing.xs),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 0),
        secondary: Icon(icon, color: AppColors.primary),
        title: Text(title, style: AppTextStyles.body),
        value: value,
        activeColor: AppColors.primary,
        onChanged: onChanged,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  Widget _buildArrowTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: AppTextStyles.body),
        trailing: const Icon(Icons.chevron_right,
            color: AppColors.textSecondary),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}
