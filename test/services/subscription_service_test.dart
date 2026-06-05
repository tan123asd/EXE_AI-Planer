import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_study_planner/services/subscription_service.dart';

// Reset singleton state between tests bằng cách gọi downgradeToFree()
// vì SubscriptionService là singleton và giữ _tier trong bộ nhớ.
Future<void> _resetSingleton() async {
  SharedPreferences.setMockInitialValues({});
  await SubscriptionService().downgradeToFree();
}

void main() {
  setUp(_resetSingleton);

  group('SubscriptionService — Tier mặc định', () {
    test('TC-01: Khi chưa có dữ liệu, tier mặc định là Free', () async {
      await SubscriptionService().init();
      expect(SubscriptionService().currentTier, equals(UserTier.free));
      expect(SubscriptionService().isPro, isFalse);
    });

    test('TC-02: Đọc tier từ SharedPreferences khi init', () async {
      SharedPreferences.setMockInitialValues({'user_tier': 'pro'});
      await SubscriptionService().init();
      expect(SubscriptionService().currentTier, equals(UserTier.pro));
      expect(SubscriptionService().isPro, isTrue);
    });

    test('TC-03: Giá trị không hợp lệ trong prefs → fallback về Free', () async {
      SharedPreferences.setMockInitialValues({'user_tier': 'invalid_value'});
      await SubscriptionService().init();
      expect(SubscriptionService().currentTier, equals(UserTier.free));
    });
  });

  group('SubscriptionService — Nâng cấp / Hạ cấp', () {
    test('TC-04: upgradeToPro() đổi tier thành Pro ngay lập tức', () async {
      await SubscriptionService().init();
      expect(SubscriptionService().isPro, isFalse);

      await SubscriptionService().upgradeToPro();
      expect(SubscriptionService().isPro, isTrue);
      expect(SubscriptionService().currentTier, equals(UserTier.pro));
    });

    test('TC-05: upgradeToPro() lưu vào SharedPreferences', () async {
      await SubscriptionService().init();
      await SubscriptionService().upgradeToPro();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_tier'), equals('pro'));
    });

    test('TC-06: downgradeToFree() đổi tier thành Free', () async {
      SharedPreferences.setMockInitialValues({'user_tier': 'pro'});
      await SubscriptionService().init();
      expect(SubscriptionService().isPro, isTrue);

      await SubscriptionService().downgradeToFree();
      expect(SubscriptionService().isPro, isFalse);
      expect(SubscriptionService().currentTier, equals(UserTier.free));
    });

    test('TC-07: downgradeToFree() lưu "free" vào SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'user_tier': 'pro'});
      await SubscriptionService().init();
      await SubscriptionService().downgradeToFree();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_tier'), equals('free'));
    });

    test('TC-08: upgradeToPro() → downgradeToFree() hoạt động đúng', () async {
      await SubscriptionService().init();

      await SubscriptionService().upgradeToPro();
      expect(SubscriptionService().isPro, isTrue);

      await SubscriptionService().downgradeToFree();
      expect(SubscriptionService().isPro, isFalse);
    });
  });

  group('SubscriptionService — Persistence qua init()', () {
    test('TC-09: Tier được giữ sau khi gọi init() lại', () async {
      await SubscriptionService().init();
      await SubscriptionService().upgradeToPro();

      // Simulate app restart: gọi init() lại — phải đọc từ prefs
      await SubscriptionService().init();
      expect(SubscriptionService().isPro, isTrue);
    });

    test('TC-10: Free tier cũng được persist đúng', () async {
      SharedPreferences.setMockInitialValues({'user_tier': 'pro'});
      await SubscriptionService().init();
      await SubscriptionService().downgradeToFree();

      await SubscriptionService().init();
      expect(SubscriptionService().isPro, isFalse);
    });
  });

  group('ProFeatureException', () {
    test('TC-11: ProFeatureException có thể bắt bằng on clause', () {
      expect(
        () => throw const ProFeatureException(),
        throwsA(isA<ProFeatureException>()),
      );
    });

    test('TC-12: ProFeatureException implement Exception', () {
      expect(const ProFeatureException(), isA<Exception>());
    });
  });
}
