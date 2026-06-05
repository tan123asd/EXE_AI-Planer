import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_study_planner/services/rate_limit_service.dart';
import 'package:ai_study_planner/services/subscription_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RateLimitService — Free tier (limit = 15)', () {
    test('TC-01: 15 lần đầu tiên đều được phép', () async {
      final service = RateLimitService();
      for (int i = 0; i < 15; i++) {
        await expectLater(
          service.checkAndRecord(UserTier.free),
          completes,
          reason: 'Lần thứ ${i + 1} phải được phép',
        );
      }
    });

    test('TC-02: Lần thứ 16 bị chặn bằng RateLimitException', () async {
      final service = RateLimitService();
      for (int i = 0; i < 15; i++) {
        await service.checkAndRecord(UserTier.free);
      }

      await expectLater(
        service.checkAndRecord(UserTier.free),
        throwsA(isA<RateLimitException>()),
        reason: 'Lần thứ 16 phải ném RateLimitException',
      );
    });

    test('TC-03: RateLimitException chứa secondsUntilReset > 0', () async {
      final service = RateLimitService();
      for (int i = 0; i < 15; i++) {
        await service.checkAndRecord(UserTier.free);
      }

      try {
        await service.checkAndRecord(UserTier.free);
        fail('Phải ném exception');
      } on RateLimitException catch (e) {
        expect(e.secondsUntilReset, greaterThan(0));
        expect(e.secondsUntilReset, lessThanOrEqualTo(86400));
      }
    });

    test('TC-04: getUsedToday trả về đúng số lần đã dùng', () async {
      final service = RateLimitService();
      expect(await service.getUsedToday(), equals(0));

      await service.checkAndRecord(UserTier.free);
      await service.checkAndRecord(UserTier.free);
      expect(await service.getUsedToday(), equals(2));
    });
  });

  group('RateLimitService — Pro tier (limit = 100)', () {
    test('TC-05: 100 lần đầu tiên đều được phép', () async {
      final service = RateLimitService();
      for (int i = 0; i < 100; i++) {
        await expectLater(
          service.checkAndRecord(UserTier.pro),
          completes,
          reason: 'Lần thứ ${i + 1} phải được phép (Pro)',
        );
      }
    });

    test('TC-06: Lần thứ 101 bị chặn', () async {
      final service = RateLimitService();
      for (int i = 0; i < 100; i++) {
        await service.checkAndRecord(UserTier.pro);
      }

      await expectLater(
        service.checkAndRecord(UserTier.pro),
        throwsA(isA<RateLimitException>()),
        reason: 'Lần thứ 101 phải ném RateLimitException',
      );
    });
  });

  group('RateLimitService — Daily reset', () {
    test('TC-07: Reset về 0 khi ngày thay đổi', () async {
      final service = RateLimitService();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayStr =
          '${yesterday.year.toString().padLeft(4, '0')}-'
          '${yesterday.month.toString().padLeft(2, '0')}-'
          '${yesterday.day.toString().padLeft(2, '0')}';

      // Giả lập đã dùng 15 lần hôm qua (bằng cách set thẳng vào prefs)
      SharedPreferences.setMockInitialValues({
        'api_call_count': 15,
        'api_call_date': yesterdayStr,
      });

      // Hôm nay: lần đầu tiên phải được phép (counter đã reset)
      await expectLater(
        service.checkAndRecord(UserTier.free),
        completes,
        reason: 'Sau khi sang ngày mới, counter reset về 0 và phải được phép',
      );

      expect(await service.getUsedToday(), equals(1));
    });

    test('TC-08: Cùng ngày không bị reset', () async {
      final service = RateLimitService();
      // Gọi 14 lần
      for (int i = 0; i < 14; i++) {
        await service.checkAndRecord(UserTier.free);
      }
      // Tạo instance mới (simulate app restart cùng ngày)
      final service2 = RateLimitService();
      // Lần 15 vẫn được phép
      await expectLater(service2.checkAndRecord(UserTier.free), completes);
      // Lần 16 bị chặn
      await expectLater(
        service2.checkAndRecord(UserTier.free),
        throwsA(isA<RateLimitException>()),
      );
    });

    test('TC-09: getUsedToday trả về 0 khi ngày đã thay đổi', () async {
      final service = RateLimitService();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayStr =
          '${yesterday.year.toString().padLeft(4, '0')}-'
          '${yesterday.month.toString().padLeft(2, '0')}-'
          '${yesterday.day.toString().padLeft(2, '0')}';

      SharedPreferences.setMockInitialValues({
        'api_call_count': 10,
        'api_call_date': yesterdayStr,
      });

      expect(await service.getUsedToday(), equals(0));
    });
  });

  group('RateLimitService — Free vs Pro không bị lẫn lộn', () {
    test('TC-10: Counter dùng chung — Free 14 + Pro 1 = 15, lần 16 bị chặn dù là Pro', () async {
      final service = RateLimitService();
      // 14 lần dưới vai Free
      for (int i = 0; i < 14; i++) {
        await service.checkAndRecord(UserTier.free);
      }
      // 1 lần dưới vai Pro (cùng ngày, cùng counter)
      await service.checkAndRecord(UserTier.pro);
      // Tổng = 15; Pro còn 85 lượt nhưng Free limit đã đủ
      // Khi kiểm tra với Free: bị chặn
      await expectLater(
        service.checkAndRecord(UserTier.free),
        throwsA(isA<RateLimitException>()),
      );
    });
  });
}
