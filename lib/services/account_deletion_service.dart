import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../screens/login_screen.dart';

class AccountDeletionService {
  AccountDeletionService._();
  static final AccountDeletionService instance = AccountDeletionService._();

  Future<void> deleteCurrentAccount({required BuildContext context}) async {
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
      // 1) Re-authenticate FIRST. If the user cancels or re-auth fails, abort
      //    here BEFORE deleting anything — avoids a half-deleted account state.
      debugPrint('AUTH STATE: re-authenticating before deletion');
      await _reauthenticate(user: user);

      // 2) Delete Firestore data (Google Play expects user data removal).
      //    Guard against races: if uid is missing, skip.
      if (uid.isNotEmpty) {
        debugPrint('AUTH STATE: deleting Firestore user data for $uid');
        await FirestoreService().deleteUserData(uid: uid);
      } else {
        debugPrint('AUTH STATE: uid missing; skipping Firestore delete');
      }

      // 3) Delete Firebase Auth account (re-auth from step 1 is still fresh).
      debugPrint('AUTH STATE: deleting Firebase Auth user');
      final freshUser = auth.currentUser ?? user;
      await freshUser.delete();

      // 4) Explicitly sign out to force authStateChanges(user==null) emission.
      // (Some platforms can delay token refresh; explicit signOut helps.)
      debugPrint('AUTH STATE: explicit signOut after deletion');
      try {
        await auth.signOut();
      } catch (_) {}

      // 5) Clear local cached data.
      debugPrint('AUTH STATE: clearing local account data');
      await StorageService().clearAccountData();

      // 6) Redirect to login screen safely.
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

  /// Re-authenticates the current user up-front so the subsequent account
  /// deletion cannot fail with `requires-recent-login`. Throws if the user
  /// cancels or the provider is unsupported — the caller then aborts before
  /// any data is deleted.
  Future<void> _reauthenticate({required User user}) async {
    final providerId = _primaryProviderId(user);
    if (providerId == 'google.com') {
      await AuthService().reauthenticateWithGoogle();
    } else {
      // Only Google sign-in is supported in this app.
      throw FirebaseAuthException(
        code: 'unsupported-provider',
        message: 'Re-authentication not supported for provider: $providerId',
      );
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


