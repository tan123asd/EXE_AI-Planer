import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';

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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _storage.getUserName());
    _emailController = TextEditingController(text: _storage.getUserEmail());
    _phoneController = TextEditingController(text: _storage.getUserPhone());
    _bioController = TextEditingController(text: _storage.getUserBio());
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
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

  @override
  Widget build(BuildContext context) {
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
              'Student',
              style: AppTextStyles.bodySecondary,
            ),
            
            const SizedBox(height: AppSpacing.xl),
            
            // Profile Options
            _buildProfileOption(
              context: context,
              icon: Icons.person_outline,
              title: 'Edit Profile',
              onTap: () {
                setState(() {
                  _isEditing = !_isEditing;
                });
                if (_isEditing) {
                  // Auto scroll to bottom after UI updates
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
              title: 'Notifications',
              onTap: () {},
            ),
            _buildProfileOption(
              context: context,
              icon: Icons.settings_outlined,
              title: 'Settings',
              onTap: () {},
            ),
            _buildProfileOption(
              context: context,
              icon: Icons.help_outline,
              title: 'Help & Support',
              onTap: () {},
            ),
            _buildProfileOption(
              context: context,
              icon: Icons.info_outline,
              title: 'About',
              onTap: () {},
            ),
            
            const SizedBox(height: AppSpacing.lg),
            
            // Logout Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Logged out successfully')),
                            );
                          },
                          child: const Text('Logout', style: TextStyle(color: AppColors.danger)),
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
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                ),
                child: const Text('Logout'),
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
                  const Text(
                    'Edit Profile Information',
                    style: AppTextStyles.heading2,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  // Name Field
                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person_outline,
                    enabled: true,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  // Email Field
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    enabled: true,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  // Phone Field
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone_outlined,
                    enabled: true,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  // Bio Field
                  _buildTextField(
                    controller: _bioController,
                    label: 'Bio',
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
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                          ),
                          child: const Text('Cancel'),
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
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                          ),
                          child: const Text('Save'),
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
          color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
        ),
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.withOpacity(0.1),
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
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}
