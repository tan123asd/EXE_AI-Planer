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
      debugPrint('AUTH STATE: signed out (no user to delete)');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      return;
    }

    debugPrint('AUTH STATE: signed in (deletion started)');

    final uid = user.uid;

    try {
      // 1) Delete Firestore data first (Google Play expects user data removal).
      // Guard against races: if uid is missing, skip.
      if (uid.isNotEmpty) {
        debugPrint('AUTH STATE: deleting Firestore user data for $uid');
        await FirestoreService().deleteUserData(uid: uid);
      } else {
        debugPrint('AUTH STATE: uid missing; skipping Firestore delete');
      }

      // 2) Delete Firebase Auth account.
      debugPrint('AUTH STATE: deleting Firebase Auth user');
      await _deleteAuthUserWithReauth(user: user);

      // 3) Explicitly sign out to force authStateChanges(user==null) emission.
      // (Some platforms can delay token refresh; explicit signOut helps.)
      debugPrint('AUTH STATE: explicit signOut after deletion');
      try {
        await auth.signOut();
      } catch (_) {}

      // 4) Clear local cached data.
      debugPrint('AUTH STATE: clearing local account data');
      await StorageService().clearAccountData();

      // 5) Redirect to login screen safely.
      if (!context.mounted) return;
      debugPrint('AUTH STATE: navigate login');
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );


      // Intentionally do not show SnackBar after deletion.
      // Navigation can coincide with auth teardown and cause app termination on some devices.

    } catch (e) {
      debugPrint('AUTH STATE: deletion error: $e');
      rethrow;
    }
  }

  Future<void> _deleteAuthUserWithReauth({required User user}) async {
    final auth = FirebaseAuth.instance;

    try {
      await user.delete();
      return;
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') {
        rethrow;
      }

      debugPrint('AUTH STATE: requires-recent-login; reauth started');

      // Attempt re-auth depending on provider.
      final providerId = _primaryProviderId(user);
      if (providerId == 'google.com') {
        await AuthService().reauthenticateWithGoogle();
      } else {
        // For unknown providers, sign out and rethrow; user should re-login.
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


