import 'package:shared_preferences/shared_preferences.dart';
import 'subscription_service.dart';

class RateLimitException implements Exception {
  final int secondsUntilReset;
  const RateLimitException(this.secondsUntilReset);
}

class RateLimitService {
  static const _countKey = 'api_call_count';
  static const _dateKey = 'api_call_date';

  Future<void> checkAndRecord(UserTier tier) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    final savedDate = prefs.getString(_dateKey);

    int count;
    if (savedDate != today) {
      count = 0;
      await prefs.setString(_dateKey, today);
    } else {
      count = prefs.getInt(_countKey) ?? 0;
    }

    final limit = _limitFor(tier);
    if (count >= limit) {
      throw RateLimitException(_secondsUntilMidnight());
    }

    await prefs.setInt(_countKey, count + 1);
  }

  Future<int> getUsedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    if (prefs.getString(_dateKey) != today) return 0;
    return prefs.getInt(_countKey) ?? 0;
  }

  int _limitFor(UserTier tier) => tier == UserTier.pro ? 100 : 15;

  String _todayString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  int _secondsUntilMidnight() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return midnight.difference(now).inSeconds;
  }
}
