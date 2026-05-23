import 'package:flutter/material.dart';
import 'package:ai_study_planner/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';
import '../models/scheduler_models.dart';
import '../providers/language_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final StorageService _storage = StorageService();
  final ScrollController _scrollController = ScrollController();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;

  bool _isEditing = false;
  List<ProductivityWindow> _productivityWindows = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _storage.getUserName());
    _emailController = TextEditingController(text: _storage.getUserEmail());
    _phoneController = TextEditingController(text: _storage.getUserPhone());
    _bioController = TextEditingController(text: _storage.getUserBio());
    _productivityWindows = _storage
        .getProductivityHours()
        .map((m) => ProductivityWindow.fromMap(m))
        .toList();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    await _storage.saveUserName(_nameController.text);
    await _storage.saveUserEmail(_emailController.text);
    await _storage.saveUserPhone(_phoneController.text);
    await _storage.saveUserBio(_bioController.text);

    setState(() {
      _isEditing = false;
    });

    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profileUpdated),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _cancelEdit() {
    setState(() {
      _nameController.text = _storage.getUserName();
      _emailController.text = _storage.getUserEmail();
      _phoneController.text = _storage.getUserPhone();
      _bioController.text = _storage.getUserBio();
      _isEditing = false;
    });
  }

  void _showLanguageDialog() {
    final l10n = AppLocalizations.of(context)!;
    final langProvider = context.read<LanguageProvider>();
    final current = langProvider.locale.languageCode;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.language),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(
              ctx,
              code: 'en',
              label: 'English',
              flag: '🇬🇧',
              current: current,
              langProvider: langProvider,
            ),
            const SizedBox(height: 8),
            _buildLanguageOption(
              ctx,
              code: 'vi',
              label: 'Tiếng Việt',
              flag: '🇻🇳',
              current: current,
              langProvider: langProvider,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext ctx, {
    required String code,
    required String label,
    required String flag,
    required String current,
    required LanguageProvider langProvider,
  }) {
    final isSelected = current == code;
    return InkWell(
      onTap: () {
        langProvider.setLocale(code);
        Navigator.of(ctx).pop();
      },
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.textSecondary.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.body.copyWith(
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final langProvider = context.watch<LanguageProvider>();
    final currentLang =
        langProvider.locale.languageCode == 'vi' ? 'Tiếng Việt' : 'English';

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.lg),
            // Profile Picture
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: const Icon(
                Icons.person,
                size: 50,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            Text(
              _storage.getUserName(),
              style: AppTextStyles.heading1,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.studentRole,
              style: AppTextStyles.bodySecondary,
            ),

            const SizedBox(height: AppSpacing.xl),

            // Profile Options
            _buildProfileOption(
              context: context,
              icon: Icons.person_outline,
              title: l10n.editProfile,
              onTap: () {
                setState(() {
                  _isEditing = !_isEditing;
                });
                if (_isEditing) {
                  Future.delayed(const Duration(milliseconds: 300), () {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  });
                }
              },
            ),
            _buildProfileOption(
              context: context,
              icon: Icons.notifications_outlined,
              title: l10n.notifications,
              onTap: () {},
            ),
            _buildProfileOption(
              context: context,
              icon: Icons.settings_outlined,
              title: l10n.settings,
              onTap: () {},
            ),
            _buildProfileOption(
              context: context,
              icon: Icons.language,
              title: l10n.language,
              subtitle: currentLang,
              onTap: _showLanguageDialog,
            ),
            _buildProfileOption(
              context: context,
              icon: Icons.help_outline,
              title: l10n.helpSupport,
              onTap: () {},
            ),
            _buildProfileOption(
              context: context,
              icon: Icons.info_outline,
              title: l10n.about,
              onTap: () {},
            ),

            const SizedBox(height: AppSpacing.lg),

            // Productivity Hours
            _buildProductivityHoursCard(),

            const SizedBox(height: AppSpacing.lg),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(l10n.logout),
                      content: Text(l10n.logoutConfirm),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(l10n.cancel),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.loggedOut)),
                            );
                          },
                          child: Text(
                            l10n.logout,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(
                    color: AppColors.danger,
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.md),
                ),
                child: Text(l10n.logout),
              ),
            ),

            // Edit Profile Form (appears below when Edit Profile is tapped)
            if (_isEditing) ...[
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.editProfileInfo,
                      style: AppTextStyles.heading2,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    _buildTextField(
                      controller: _nameController,
                      label: l10n.fullName,
                      icon: Icons.person_outline,
                      enabled: true,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    _buildTextField(
                      controller: _emailController,
                      label: l10n.email,
                      icon: Icons.email_outlined,
                      enabled: true,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    _buildTextField(
                      controller: _phoneController,
                      label: l10n.phone,
                      icon: Icons.phone_outlined,
                      enabled: true,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    _buildTextField(
                      controller: _bioController,
                      label: l10n.bio,
                      icon: Icons.info_outline,
                      enabled: true,
                      maxLines: 3,
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _cancelEdit,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              side: const BorderSide(
                                color: AppColors.textSecondary,
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.md),
                            ),
                            child: Text(l10n.cancel),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.md),
                            ),
                            child: Text(l10n.save),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Future<void> _addProductivityWindow() async {
    final l10n = AppLocalizations.of(context)!;
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: l10n.selectStartFocus,
    );
    if (start == null || !mounted) return;

    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: start.hour + 2, minute: 0),
      helpText: l10n.selectEndFocus,
    );
    if (end == null || !mounted) return;

    final startMin = start.hour * 60 + start.minute;
    final endMin = end.hour * 60 + end.minute;
    if (endMin <= startMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.endTimeError),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final updated = List<ProductivityWindow>.from(_productivityWindows)
      ..add(ProductivityWindow(startHour: start.hour, endHour: end.hour));
    await _storage
        .saveProductivityHours(updated.map((w) => w.toMap()).toList());
    setState(() => _productivityWindows = updated);
  }

  Future<void> _removeProductivityWindow(int index) async {
    final updated = List<ProductivityWindow>.from(_productivityWindows)
      ..removeAt(index);
    await _storage
        .saveProductivityHours(updated.map((w) => w.toMap()).toList());
    setState(() => _productivityWindows = updated);
  }

  String _formatWindow(ProductivityWindow w) {
    String fmt(int h) => '${h.toString().padLeft(2, '0')}:00';
    return '${fmt(w.startHour)} – ${fmt(w.endHour)}';
  }

  Widget _buildProductivityHoursCard() {
    final l10n = AppLocalizations.of(context)!;
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt, color: AppColors.primary, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(l10n.productivityHours, style: AppTextStyles.heading3),
                ],
              ),
              TextButton.icon(
                onPressed: _addProductivityWindow,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.add),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.productivityHoursDesc,
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_productivityWindows.isEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                l10n.noWindowsConfigured,
                style: AppTextStyles.bodySecondary
                    .copyWith(color: AppColors.textSecondary),
              ),
            )
          else
            ...List.generate(_productivityWindows.length, (i) {
              final w = _productivityWindows[i];
              return Container(
                margin:
                    const EdgeInsets.only(bottom: AppSpacing.xs),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius:
                      BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _formatWindow(w),
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.primary),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 18,
                          color: AppColors.textSecondary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () =>
                          _removeProductivityWindow(i),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color:
              enabled ? AppColors.textPrimary : AppColors.textSecondary,
        ),
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor:
            enabled ? Colors.white : Colors.grey.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.textSecondary.withOpacity(0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.textSecondary.withOpacity(0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: AppColors.textSecondary.withOpacity(0.2),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: AppTextStyles.body),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: AppTextStyles.bodySecondary
                    .copyWith(color: AppColors.textSecondary))
            : null,
        trailing:
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}
