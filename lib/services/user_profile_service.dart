import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfileService {
  static const _key = 'user_profile';
  static final UserProfileService _instance = UserProfileService._();
  factory UserProfileService() => _instance;
  UserProfileService._();

  SharedPreferences? _prefs;
  double _avgDailyHours = 0;
  int _planCount = 0;
  String _projectType = '';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _load();
  }

  void _load() {
    final raw = _prefs?.getString(_key);
    if (raw == null) return;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _avgDailyHours = (map['avgDailyHours'] as num?)?.toDouble() ?? 0;
    _planCount = map['planCount'] as int? ?? 0;
    _projectType = map['projectType'] as String? ?? '';
  }

  Future<void> updateFromApprovedPlan({
    required double dailyHours,
    required String projectType,
  }) async {
    _planCount++;
    // Rolling average: avoids early outliers dominating
    _avgDailyHours = (_avgDailyHours * (_planCount - 1) + dailyHours) / _planCount;
    if (projectType.isNotEmpty) _projectType = projectType;
    await _prefs?.setString(_key, jsonEncode({
      'avgDailyHours': _avgDailyHours,
      'planCount': _planCount,
      'projectType': _projectType,
    }));
  }

  /// Returns empty string when no data yet → nothing injected into prompt
  String toPromptString() {
    if (_planCount == 0) return '';
    final hoursStr = _avgDailyHours.toStringAsFixed(1);
    final typeStr = _projectType.isNotEmpty ? ', loại dự án: $_projectType' : '';
    return '## Thông tin người dùng (từ lịch sử)\n'
        '- Số kế hoạch đã tạo: $_planCount\n'
        '- Giờ học trung bình/ngày: ${hoursStr}h$typeStr\n';
  }
}
