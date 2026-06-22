# TODO - Streak Firestore + Provider integration

- [ ] Step 1: Update `lib/services/firestore_service.dart`
  - [ ] Add `Future<Map<String, dynamic>?> fetchStreak(String uid)` reading `users/{uid}/streak/main`
  - [ ] Add `Future<void> saveStreak(String uid, Map<String, dynamic> data)` writing to same doc
  - [ ] Ensure `updatedAt: FieldValue.serverTimestamp()` is used by streak provider (or supported)

- [ ] Step 2: Update `lib/providers/streak_provider.dart`
  - [ ] Add `loadStreak(String uid)`
  - [ ] Modify `evaluateDayAndUpdateStreak()` to stop using pushPerformance and call `saveStreak()`
  - [ ] Persist fields exactly: `currentStreak, bestStreak, lastCompletedDayKey, lastEvaluatedDayKey, updatedAt: FieldValue.serverTimestamp()`

- [ ] Step 3: Update Provider wiring in `lib/main.dart`
  - [ ] Add `StreakProvider` to `MultiProvider`

- [ ] Step 4: Update `lib/screens/home_screen.dart`
  - [ ] Read `currentStreak` from `StreakProvider`
  - [ ] Trigger `loadStreak(uid)` in `didChangeDependencies()` or post-frame callback (not initState)

- [ ] Step 5: Run `flutter analyze`
  - [ ] Fix any compile/analyze errors

- [ ] Step 6: Report changes + data flow
  - [ ] List modified files
  - [ ] Provide flow: Task completion → evaluateDayAndUpdateStreak() → saveStreak() → loadStreak() → UI displays

