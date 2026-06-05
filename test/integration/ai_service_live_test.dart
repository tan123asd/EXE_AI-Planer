/// Integration test — gọi OpenAI API thật.
/// Chạy: flutter test test/integration/ai_service_live_test.dart
///         --dart-define=OPENAI_API_KEY=sk-...
///
/// Mỗi lần chạy tốn ~1 API call (TC-01).
/// TC-02 kiểm tra rate-limit block TRƯỚC khi gọi API → không tốn thêm.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_study_planner/services/ai_service.dart';
import 'package:ai_study_planner/services/rate_limit_service.dart';
import 'package:ai_study_planner/services/subscription_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SubscriptionService().init();
  });

  test('TC-LIVE-01: Gọi OpenAI thật — nhận về AiTaskPlan hợp lệ', () async {
    final plan = await AiService().generateTaskPlan(
      taskName: 'Ôn tập môn Giải tích',
      notes: 'Thi cuối kỳ tuần sau',
      difficulty: 'medium',
      category: 'Study',
      deadline: DateTime.now().add(const Duration(days: 7)),
      priority: 'high',
      language: 'Vietnamese',
    );

    expect(plan.tasks, isNotEmpty, reason: 'Phải có ít nhất 1 subtask');
    expect(plan.tasks.first.name, isNotEmpty);
    expect(plan.tasks.first.duration, greaterThan(0));

    print('\n✅ Nhận được ${plan.tasks.length} subtasks từ OpenAI:');
    for (final t in plan.tasks) {
      print('  - ${t.name} (${t.duration}h, ${t.focusLevel})');
    }
  });

  test('TC-LIVE-02: Rate limit block xảy ra TRƯỚC khi gọi API', () async {
    // Giả lập đã dùng đủ 15 lần (Free limit)
    SharedPreferences.setMockInitialValues({'api_call_count': 15, 'api_call_date': _today()});

    expect(
      () => AiService().generateTaskPlan(
        taskName: 'Test block',
        notes: '',
        difficulty: 'low',
        category: 'Study',
        deadline: DateTime.now().add(const Duration(days: 1)),
        priority: 'low',
      ),
      throwsA(isA<RateLimitException>()),
      reason: 'Phải bị chặn bằng RateLimitException, không gọi đến OpenAI',
    );
  });
}

String _today() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}'
      '-${now.month.toString().padLeft(2, '0')}'
      '-${now.day.toString().padLeft(2, '0')}';
}
