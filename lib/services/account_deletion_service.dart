import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../screens/login_screen.dart';
import '../utils/constants.dart';

class AccountDeletionService {
  AccountDeletionService._();
  static final AccountDeletionService instance = AccountDeletionService._();

  Future<void> deleteCurrentAccount({required BuildContext context}) async {
    final l10n = AppLocalizations.of(context)!;

    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null) {
      // Nothing to delete.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      return;
    }

    final uid = user.uid;

    // 1) Delete Firestore data first (Google Play expects user data removal).
    // We keep auth deletion for last; if re-auth is required we may need the user
    // session to still exist.
    await FirestoreService().deleteUserData(uid: uid);

    // 2) Delete Firebase Auth account.
    // Handle requires-recent-login per Google Play expectations.
    try {
      await _deleteAuthUserWithReauth(user: user, context: context);
    } catch (e) {
      // If auth deletion fails, we do NOT silently swallow. Firestore is already deleted.
      // Provide actionable feedback.
      rethrow;
    }

    // 3) Clear local cached data.
    await StorageService().clearAccountData();

    // 4) Redirect to login screen.
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.accountDeleted ?? l10n.loggedOut),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _deleteAuthUserWithReauth({
    required User user,
    required BuildContext context,
  }) async {
    final auth = FirebaseAuth.instance;

    try {
      await user.delete();
      return;
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') {
        rethrow;
      }

      // Attempt re-auth depending on provider.
      final providerId = _primaryProviderId(user);
      if (providerId == 'google.com') {
        await AuthService().reauthenticateWithGoogle();
      } else {
        // Best-effort: for unknown providers, fall back to deleting after forcing
        // a fresh auth state; the app can send the user to login if needed.
        // We still surface the error.
        try {
          await auth.signOut();
        } catch (_) {}
        throw e;
      }

      // After re-auth, try delete again.
      final freshUser = auth.currentUser;
      if (freshUser == null) {
        throw FirebaseAuthException(
          code: 'user-missing-after-reauth',
          message: 'User missing after re-authentication.',
        );
      }

      await freshUser.delete();
    }
  }

  String? _primaryProviderId(User user) {
    final providerData = user.providerData;
    if (providerData.isEmpty) return null;

    // Prefer google.com if present.
    for (final pd in providerData) {
      if (pd.providerId == 'google.com') return pd.providerId;
    }

    return providerData.first.providerId;
  }
}

