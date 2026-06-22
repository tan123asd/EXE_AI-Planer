import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';


/// Streak logic:
/// - +1 streak only when user completes 100% of tasks/sessions scheduled for that day.
/// - Day has no tasks -> ignored (no streak change).
/// - Day has tasks but missing at least one task -> reset streak to 0.
///
/// Notes:
/// - This provider stores computed streak in Firestore under users/{uid}/performance.
/// - It also keeps a local in-memory copy for UI.
class StreakProvider extends ChangeNotifier {
  StreakProvider({FirestoreService? firestore}) : _firestore = firestore ?? FirestoreService();

  final FirestoreService _firestore;

  String? _uid;

  int currentStreak = 0;
  int bestStreak = 0;
  String? lastCompletedDayKey;
  String? lastEvaluatedDayKey;

  bool _loading = false;
  bool get isLoading => _loading;

  /// Load streak state from Firestore for [uid].
  /// Reads: users/{uid}/streak/main
  Future<void> loadStreak(String uid) async {
    _uid = uid;

    _loading = true;
    notifyListeners();

    try {
      final data = await _firestore.fetchStreak(uid);
      if (data == null) {
        currentStreak = 0;
        bestStreak = 0;
        lastCompletedDayKey = null;
        lastEvaluatedDayKey = null;
      } else {
        currentStreak = (data['currentStreak'] as num?)?.toInt() ?? 0;
        bestStreak = (data['bestStreak'] as num?)?.toInt() ?? 0;
        lastCompletedDayKey = data['lastCompletedDayKey'] as String?;
        lastEvaluatedDayKey = data['lastEvaluatedDayKey'] as String?;
      }

      notifyListeners();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Must be called after sessions/task completion updates.
  ///
  /// [dayKey] should be an *effective* day key (e.g. local date after cutoff), format: yyyy-MM-dd.
  /// [previousDayKey] is dayKey - 1 day, same format.
  ///
  /// [scheduledTotal] = number of scheduled sessions/tasks for that day.
  /// [completedTotal] = number of completed sessions/tasks for that day.
  Future<void> evaluateDayAndUpdateStreak({
    required String dayKey,
    required String previousDayKey,
    required int scheduledTotal,
    required int completedTotal,
  }) async {
    if (scheduledTotal < 0 || completedTotal < 0) return;
    if (_uid == null) return; // must call loadStreak(uid) after login

    // Prevent double evaluation for same day.
    if (lastEvaluatedDayKey == dayKey) return;

    _loading = true;
    notifyListeners();

    try {
      // If another evaluation already set lastEvaluatedDayKey concurrently, re-check.
      if (lastEvaluatedDayKey == dayKey) return;

      if (scheduledTotal == 0) {
        // Ignore day with no tasks.
        lastEvaluatedDayKey = dayKey;
        await _persistStreak();
        return;
      }

      final isAllDone = completedTotal == scheduledTotal;

      if (isAllDone) {
        if (lastCompletedDayKey == previousDayKey) {
          currentStreak += 1;
        } else {
          currentStreak = 1;
        }

        if (currentStreak > bestStreak) bestStreak = currentStreak;
        lastCompletedDayKey = dayKey;
        lastEvaluatedDayKey = dayKey;
      } else {
        // Has tasks but missed at least one.
        currentStreak = 0;
        lastEvaluatedDayKey = dayKey;
      }

      await _persistStreak();

      notifyListeners();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Clears local state (doesn't delete Firestore data).
  void resetLocal() {
    currentStreak = 0;
    bestStreak = 0;
    lastCompletedDayKey = null;
    lastEvaluatedDayKey = null;
    notifyListeners();
  }

  Future<void> _persistStreak() async {
    if (_uid == null) return;

    await _firestore.saveStreak(_uid!, {
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'lastCompletedDayKey': lastCompletedDayKey,
      'lastEvaluatedDayKey': lastEvaluatedDayKey,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}


