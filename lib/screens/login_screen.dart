import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ai_study_planner/services/auth_service.dart';
import 'package:ai_study_planner/services/storage_service.dart';
import 'package:ai_study_planner/services/firestore_service.dart';
import 'package:ai_study_planner/services/connectivity_service.dart';
import 'package:ai_study_planner/services/subscription_service.dart';
import 'package:ai_study_planner/services/user_profile_service.dart';
import 'package:ai_study_planner/utils/constants.dart' as app_constants;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              app_constants.AppColors.primary.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top section with logo/title
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: app_constants.AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.school,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      'AI Study Planner',
                      style: app_constants.AppTextStyles.heading1.copyWith(
                        fontSize: 32,
                        color: app_constants.AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your AI-Powered Scheduling Assistant',
                      style: app_constants.AppTextStyles.body.copyWith(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              // Middle section with features
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _FeatureItem(
                      icon: Icons.schedule,
                      title: 'Smart Scheduling',
                      subtitle: 'AI-powered scheduling with conflict detection',
                    ),
                    const SizedBox(height: 20),
                    _FeatureItem(
                      icon: Icons.analytics,
                      title: 'Performance Tracking',
                      subtitle: 'Monitor your productivity and progress',
                    ),
                    const SizedBox(height: 20),
                    _FeatureItem(
                      icon: Icons.chat,
                      title: 'Chat Planning',
                      subtitle: 'Plan naturally with conversational AI',
                    ),
                  ],
                ),
              ),

              // Bottom section with login button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  children: [
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: app_constants.AppColors.danger.withOpacity(0.1),
                          border: Border.all(color: app_constants.AppColors.danger),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: app_constants.AppTextStyles.body.copyWith(color: app_constants.AppColors.danger),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    _GoogleSignInButton(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      isLoading: _isLoading,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userCredential = await _authService.signInWithGoogle();
      final user = userCredential?.user;
      if (user != null) {
        final displayName = user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : (user.email?.split('@').first ?? 'Student');
        final email = user.email ?? '';
        final photoUrl = user.photoURL ?? '';

        // If a different account is logging in, clear the previous user's data
        // so bio/phone/tasks don't leak across accounts.
        final lastUid = _storageService.getLastUid();
        if (lastUid != null && lastUid != user.uid) {
          await _storageService.clearAccountData();
        }
        await _storageService.saveLastUid(user.uid);

        await _storageService.saveUserName(displayName);
        await _storageService.saveUserEmail(email);
        await _storageService.saveUserPhotoUrl(photoUrl);

        // Initial sync: Firestore ↔ local (pull remote or push local if new account).
        // 10-second timeout prevents hanging when Firestore is slow or offline.
        try {
          final prefs = await SharedPreferences.getInstance();
          await FirestoreService().initialSync(prefs)
              .timeout(const Duration(seconds: 10));
          await ConnectivityService().syncNow()
              .timeout(const Duration(seconds: 5));
        } catch (_) {
          // Sync failed or timed out — proceed to home. ConnectivityService will retry on reconnect.
        }
        // Refresh subscription tier AFTER login so Firestore is queried
        // with the correct UID. This ensures Pro users on a new device get
        // the correct tier before HomeScreen renders.
        try {
          await SubscriptionService().init()
              .timeout(const Duration(seconds: 5));
        } catch (_) {
          // Offline or timeout — fall back to cached tier.
        }
        // Re-init UserProfileService to reset its in-memory AI chat stats
        // (avgDailyHours, planCount) that were cleared from SharedPreferences.
        await UserProfileService().init();
      }

      if (userCredential != null && mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } on PlatformException catch (e) {
      setState(() {
        if (e.code == 'sign_in_failed' || e.message?.contains('ApiException: 10') == true) {
          _errorMessage = 'Google Sign-In is not configured correctly. Add the app SHA-1 to Firebase Console, then download google-services.json again.';
        } else {
          _errorMessage = 'An error occurred. Please try again.';
        }
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e.code);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'account-exists-with-different-credential':
        return 'This email is already registered with another provider.';
      case 'invalid-credential':
        return 'Invalid credentials. Please try again.';
      case 'operation-not-allowed':
        return 'Google sign-in is not enabled.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'user-not-found':
        return 'User not found.';
      case 'wrong-password':
        return 'Wrong password.';
      default:
        return 'An error occurred: $code';
    }
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const _GoogleSignInButton({
    required this.onPressed,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F2937),
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 2,
          disabledBackgroundColor: Colors.grey[300],
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    app_constants.AppColors.primary.withOpacity(0.7),
                  ),
                  strokeWidth: 2,
                ),
              )
            : Image.asset(
                'assets/google_logo.png',
                width: 24,
                height: 24,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.login, size: 24);
                },
              ),
        label: Text(
          isLoading ? 'Signing in...' : 'Sign in with Google',
          style: app_constants.AppTextStyles.body.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: app_constants.AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: app_constants.AppColors.primary, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: app_constants.AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: app_constants.AppTextStyles.caption.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
