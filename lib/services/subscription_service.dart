import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_service.dart';

enum UserTier { free, pro }

class ProFeatureException implements Exception {
  const ProFeatureException();
}

class SubscriptionService {
  UserTier _tier = UserTier.free;

  static final SubscriptionService _instance = SubscriptionService._();
  factory SubscriptionService() => _instance;
  SubscriptionService._();

  String get _localCacheKey {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      return uid != null ? 'user_tier_$uid' : 'user_tier';
    } catch (_) {
      return 'user_tier'; // Firebase not initialized (test environment).
    }
  }

  /// Initialises tier. Firestore is the source of truth; local cache is offline fallback only.
  Future<void> init() async {
    // 1. Try Firestore first — server is authoritative.
    try {
      final remote = await FirestoreService()
          .fetchSubscriptionTier()
          .timeout(const Duration(seconds: 5));
      if (remote != null) {
        _tier = remote == 'pro' ? UserTier.pro : UserTier.free;
        await _persistCache(_tier);
        return;
      }
      // Field missing in Firestore (free user who hasn't had it set yet).
      // Write 'free' so the field exists for future reads and security rules.
      _tier = UserTier.free;
      await _persistCache(_tier);
      await FirestoreService()
          .setSubscriptionTier('free')
          .timeout(const Duration(seconds: 5));
      return;
    } catch (_) {
      // Firestore unavailable (offline or test environment) — fall through to cache.
    }

    // 2. Offline fallback: read from local cache.
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localCacheKey);
    _tier = raw == 'pro' ? UserTier.pro : UserTier.free;
  }

  UserTier get currentTier => _tier;
  bool get isPro => _tier == UserTier.pro;

  /// Sets tier. Writes to Firestore first so the server is always authoritative.
  /// Only call this from a verified payment callback — NOT directly from UI.
  Future<void> _setTier(UserTier tier) async {
    // Write to Firestore first. If offline, update cache only (server catches up on reconnect).
    try {
      await FirestoreService()
          .setSubscriptionTier(tier == UserTier.pro ? 'pro' : 'free')
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Offline — cache updated below; Firestore sync will happen on reconnect via syncSettingsIfNeeded.
    }
    _tier = tier;
    await _persistCache(tier);
  }

  Future<void> _persistCache(UserTier tier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localCacheKey, tier == UserTier.pro ? 'pro' : 'free');
  }

  /// Call this only after verifying payment with the server.
  Future<void> upgradeToPro() => _setTier(UserTier.pro);

  /// Internal use / admin only.
  Future<void> downgradeToFree() => _setTier(UserTier.free);
}
