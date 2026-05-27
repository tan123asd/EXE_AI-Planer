import '../models/scheduler_models.dart';

class SchedulerService {
  static const int _scanStepMinutes = 10;

  // Activity scheduling constants (public so callers fetch the matching occupied window)
  static const int activityLookAheadDays    = 14;
  static const int _activityScanStepMinutes = 15;
  static const int _maxActivityCandidates   = 7;
  static const int _maxPerBucket            = 3; // morning / afternoon / evening

  // ─── Part 1: Deadline Plan ─────────────────────────────────────────────────

  ScheduleResult scheduleDeadlinePlan(
    AiTaskPlan plan,
    SchedulerConfig config,
    List<Map<String, dynamic>> rawOccupied,
  ) {
    final hardOccupied = _parseOccupied(rawOccupied);
    _addLateNightBlocks(hardOccupied, config.searchFrom, config.deadline);

    final softRest = _inferSoftRest(config.searchFrom, config.deadline);
    final sortedTasks = _sortTasks(plan.tasks, plan.priority);
    final scheduledSlots = <ScheduledSlot>[];
    final failedTasks = <AiSubtask>[];

    // Tracks minutes allocated per calendar day for the daily-cap constraint.
    final Map<String, int> allocatedPerDay = {};

    // Sequential cursor: subtask N+1 starts after subtask N's last session ends.
    // This preserves chapter ordering (ch1 → ch2 → ch3).
    // The old pile-up bug was caused by the urgency bonus, not this constraint.
    DateTime subtaskSearchFrom = config.searchFrom;

    for (final task in sortedTasks) {
      int durationLeft = (task.duration * 60).round();
      final int minBlockMin = (task.minBlock * 60).round();
      DateTime sessionSearchFrom = subtaskSearchFrom;

      int sessionIdx = 0;
      while (durationLeft > 0) {
        final blocks = _findFreeBlocks(
          sessionSearchFrom,
          config.deadline,
          minBlockMin,
          hardOccupied,
          softRest,
          config,
        );

        if (blocks.isEmpty) break;

        _scoreAndSort(blocks, task, hardOccupied, config);

        final best = blocks.first;

        // ── Daily cap check ──────────────────────────────────────────────────
        if (config.maxMinutesPerDay != null) {
          final dk = _dayKey(best.start);
          final usedToday = allocatedPerDay[dk] ?? 0;
          if (usedToday >= config.maxMinutesPerDay!) {
            // This day is full — jump to 06:00 the next day.
            sessionSearchFrom = _startOfNextDay(best.start);
            continue;
          }
        }

        final allocate = durationLeft.clamp(minBlockMin, best.durationMinutes);

        // Snap allocation to minBlock granularity (round up to next minBlock multiple)
        final sessions = (allocate / minBlockMin).ceil();
        int actualAlloc = (sessions * minBlockMin).clamp(minBlockMin, best.durationMinutes);

        // Cap to remaining daily budget.
        if (config.maxMinutesPerDay != null) {
          final dk = _dayKey(best.start);
          final remaining = config.maxMinutesPerDay! - (allocatedPerDay[dk] ?? 0);
          final cappedSessions = (remaining / minBlockMin).floor();
          if (cappedSessions <= 0) {
            sessionSearchFrom = _startOfNextDay(best.start);
            continue;
          }
          actualAlloc = actualAlloc.clamp(minBlockMin, cappedSessions * minBlockMin);
        }

        final slotStart = best.start;
        final slotEnd = slotStart.add(Duration(minutes: actualAlloc));

        scheduledSlots.add(ScheduledSlot(
          taskId: task.order.toString(),
          taskName: task.name,
          sessionIndex: sessionIdx,
          startTime: slotStart,
          endTime: slotEnd,
        ));
        hardOccupied.add(_Range(slotStart, slotEnd));
        // Insert a mandatory break so the next session doesn't start immediately.
        final breakMin = _breakAfterSession(actualAlloc, task.focusLevel);
        if (breakMin > 0) {
          hardOccupied.add(_Range(slotEnd, slotEnd.add(Duration(minutes: breakMin))));
        }
        // Advance within-subtask cursor past this session and its break.
        sessionSearchFrom = slotEnd.add(Duration(minutes: breakMin));
        durationLeft -= actualAlloc;
        sessionIdx++;

        // Update per-day tally.
        if (config.maxMinutesPerDay != null) {
          final dk = _dayKey(slotStart);
          allocatedPerDay[dk] = (allocatedPerDay[dk] ?? 0) + actualAlloc;
        }
      }

      // Advance the cross-subtask cursor so the next subtask starts after this one.
      subtaskSearchFrom = sessionSearchFrom;

      if (durationLeft > 0) {
        failedTasks.add(task);
      }
    }

    final failureReason = failedTasks.isNotEmpty
        ? 'Cannot fit ${failedTasks.length} task(s) before the deadline: '
            '${failedTasks.map((t) => t.name).join(', ')}.'
        : null;

    return ScheduleResult(
      allTasksScheduled: failedTasks.isEmpty,
      scheduledSlots: scheduledSlots,
      failedTasks: failedTasks,
      failureReason: failureReason,
    );
  }

  // ─── Part 2: Activity Scheduling ──────────────────────────────────────────

  List<ScheduledSlot> scheduleActivity(
    ActivityRequest req,
    SchedulerConfig config,
    List<Map<String, dynamic>> rawOccupied,
  ) {
    final now = DateTime.now();
    final searchEnd = now.add(const Duration(days: activityLookAheadDays));

    final hardOccupied = _parseOccupied(rawOccupied);
    _addLateNightBlocks(hardOccupied, now, searchEnd);

    final candidates = <_ScoredSlot>[];

    // Phase 1: Scan each preferred weekday; collect best slot per time bucket
    DateTime day = DateTime(now.year, now.month, now.day);
    while (day.isBefore(searchEnd)) {
      if (!req.preferredWeekdays.contains(day.weekday)) {
        day = day.add(const Duration(days: 1));
        continue;
      }

      // Buckets: 0=morning (07–12), 1=afternoon (12–17), 2=evening (17–22:30)
      final bucketBest = <int, _ScoredSlot>{};

      final dayLimit = DateTime(day.year, day.month, day.day, 22, 30);
      var t = DateTime(day.year, day.month, day.day, 7, 0);

      while (t.isBefore(dayLimit)) {
        if (t.isBefore(now)) {
          t = t.add(const Duration(minutes: _activityScanStepMinutes));
          continue;
        }

        final slotEnd = t.add(Duration(minutes: req.durationMinutes));
        if (!slotEnd.isBefore(dayLimit)) break; // reject slots ending at or after 22:30

        if (!_overlapsAny(t, slotEnd, hardOccupied)) {
          final sc = _scoreActivitySlot(t, config, hardOccupied);
          final bucket = _bucketOf(t);
          if (!bucketBest.containsKey(bucket) ||
              sc > bucketBest[bucket]!.score) {
            bucketBest[bucket] = _ScoredSlot(start: t, end: slotEnd, score: sc);
          }
        }

        t = t.add(const Duration(minutes: _activityScanStepMinutes));
      }

      candidates.addAll(bucketBest.values);
      day = day.add(const Duration(days: 1));
    }

    // Phase 2: Reward the most-common start hour (consistent weekly rhythm)
    _applyConsistencyBonus(candidates);

    // Phase 3: Sort by score descending, then enforce time-diversity cap
    // (at most _maxPerBucket results per morning/afternoon/evening bucket)
    // so no single time-of-day dominates the output.
    candidates.sort((a, b) => b.score.compareTo(a.score));

    final bucketCount = <int, int>{};
    final curated = <_ScoredSlot>[];
    for (final c in candidates) {
      final b = _bucketOf(c.start);
      final used = bucketCount[b] ?? 0;
      if (used < _maxPerBucket) {
        curated.add(c);
        bucketCount[b] = used + 1;
      }
      if (curated.length >= _maxActivityCandidates) break;
    }

    int sessionIdx = 0;
    return curated.map((c) {
      return ScheduledSlot(
        taskId: 'activity',
        taskName: req.name,
        sessionIndex: sessionIdx++,
        startTime: c.start,
        endTime: c.end,
        score: c.score,
      );
    }).toList();
  }

  // ─── Private helpers ───────────────────────────────────────────────────────

  // Round a datetime UP to the nearest intervalMinutes boundary (drops seconds).
  static DateTime _ceilToInterval(DateTime dt, int intervalMinutes) {
    final noSec = DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);
    final rem = noSec.minute % intervalMinutes;
    if (rem == 0) return noSec;
    return noSec.add(Duration(minutes: intervalMinutes - rem));
  }

  List<_Range> _parseOccupied(List<Map<String, dynamic>> raw) {
    final ranges = <_Range>[];
    for (final item in raw) {
      final s = DateTime.tryParse(item['startTime'] as String? ?? '');
      final e = DateTime.tryParse(item['endTime'] as String? ?? '');
      if (s != null && e != null && e.isAfter(s)) {
        ranges.add(_Range(s, e));
      }
    }
    return ranges;
  }

  // Late-night 22:30–06:00 treated as hard exclusions.
  void _addLateNightBlocks(
      List<_Range> occupied, DateTime from, DateTime to) {
    DateTime day = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day).add(const Duration(days: 1));
    while (day.isBefore(end)) {
      // 22:30 this day → 06:00 next day
      final nightStart = DateTime(day.year, day.month, day.day, 22, 30);
      final nightEnd = DateTime(day.year, day.month, day.day + 1, 6, 0);
      occupied.add(_Range(nightStart, nightEnd));
      day = day.add(const Duration(days: 1));
    }
  }

  List<_Range> _inferSoftRest(DateTime from, DateTime deadline) {
    final soft = <_Range>[];
    DateTime day = DateTime(from.year, from.month, from.day);
    final end = DateTime(deadline.year, deadline.month, deadline.day)
        .add(const Duration(days: 1));
    while (day.isBefore(end)) {
      // Lunch 12:00–13:00
      soft.add(_Range(
        DateTime(day.year, day.month, day.day, 12, 0),
        DateTime(day.year, day.month, day.day, 13, 0),
      ));
      // Dinner 18:00–19:00
      soft.add(_Range(
        DateTime(day.year, day.month, day.day, 18, 0),
        DateTime(day.year, day.month, day.day, 19, 0),
      ));
      day = day.add(const Duration(days: 1));
    }
    return soft;
  }

  List<AiSubtask> _sortTasks(List<AiSubtask> tasks, String planPriority) {
    // Preserve the API's task order. The scoring/block-selection logic will
    // still place high-focus tasks into their best matching windows.
    final sorted = List<AiSubtask>.from(tasks);
    sorted.sort((a, b) => a.order.compareTo(b.order));
    return sorted;
  }

  // Break duration (minutes) to insert after a work session.
  // Rules: ≥90 min session → 30 min (high focus) / 20 min; ≥60 min → 20/15 min; ≥30 min → 10 min.
  int _breakAfterSession(int sessionMinutes, String focusLevel) {
    if (sessionMinutes >= 90) return focusLevel == 'high' ? 30 : 20;
    if (sessionMinutes >= 60) return focusLevel == 'high' ? 20 : 15;
    if (sessionMinutes >= 30) return 10;
    return 0;
  }

  List<TimeBlock> _findFreeBlocks(
    DateTime from,
    DateTime deadline,
    int minBlockMin,
    List<_Range> hardOccupied,
    List<_Range> softRest,
    SchedulerConfig config,
  ) {
    final now = DateTime.now();
    final searchStart = from.isBefore(now) ? now : from;
    final blocks = <TimeBlock>[];

    // We scan in _scanStepMinutes steps and merge consecutive free chunks.
    DateTime? blockStart;
    bool? blockHighProductivity;
    bool blockHasSoftRest = false;

    void finalizeBlock(DateTime blockEnd) {
      if (blockStart != null && blockEnd.difference(blockStart!).inMinutes >= minBlockMin) {
        blocks.add(TimeBlock(
          start: blockStart!,
          end: blockEnd,
          isHighProductivity: blockHighProductivity ?? false,
          isSoftRest: blockHasSoftRest,
        ));
      }
      blockStart = null;
      blockHighProductivity = null;
      blockHasSoftRest = false;
    }

    DateTime cursor = _ceilToInterval(searchStart, _scanStepMinutes);
    while (cursor.isBefore(deadline)) {
      final chunkEnd = cursor.add(const Duration(minutes: _scanStepMinutes));
      if (chunkEnd.isAfter(deadline)) break;

      final isHard = _overlapsAny(cursor, chunkEnd, hardOccupied);
      if (isHard) {
        finalizeBlock(cursor);
        cursor = chunkEnd;
        continue;
      }

      final isSoft = _overlapsAny(cursor, chunkEnd, softRest);
      final isHigh = config.productivityWindows
          .any((w) => w.containsHour(cursor.hour));

      if (blockStart == null) {
        blockStart = cursor;
        blockHighProductivity = isHigh;
        blockHasSoftRest = isSoft;
      } else {
        // If productivity or soft-rest character changes, split the block.
        if (isHigh != blockHighProductivity || (isSoft && !blockHasSoftRest)) {
          finalizeBlock(cursor);
          blockStart = cursor;
          blockHighProductivity = isHigh;
          blockHasSoftRest = isSoft;
        } else {
          if (isSoft) blockHasSoftRest = true;
        }
      }

      cursor = chunkEnd;
    }
    if (blockStart != null) finalizeBlock(cursor);

    return blocks;
  }

  void _scoreAndSort(
    List<TimeBlock> blocks,
    AiSubtask task,
    List<_Range> hardOccupied,
    SchedulerConfig config,
  ) {
    blocks.sort((a, b) {
      final sa = _score(a, task, hardOccupied, config);
      final sb = _score(b, task, hardOccupied, config);
      return sb.compareTo(sa); // descending
    });
  }

  double _score(
    TimeBlock block,
    AiSubtask task,
    List<_Range> hardOccupied,
    SchedulerConfig config,
  ) {
    double s = 0;

    // Focus-level match
    if (task.focusLevel == 'high' && block.isHighProductivity) s += 50;
    if (task.focusLevel == 'low' && !block.isHighProductivity) s += 20;
    if (task.focusLevel == 'medium') s += 10;

    // Preferred-time match
    if (task.preferredTime == 'high_focus' && block.isHighProductivity) s += 30;
    if (task.preferredTime == 'low_focus' &&
        !block.isHighProductivity &&
        !block.isSoftRest) {
      s += 20;
    }

    // Soft-rest penalty
    if (block.isSoftRest) s -= 30;

    // Day overload penalty — tiered so the scheduler spreads work across days.
    final dayMinutes = _scheduledMinutesOnDay(block.start, hardOccupied);
    if (dayMinutes > 360) {
      s -= 150; // >6 h: strongly avoid this day
    } else if (dayMinutes > 240) {
      s -= 60;  // >4 h: prefer a fresh day
    }

    // Prefer earlier slots so work is spread from today, not piled at the deadline.
    final daysFromNow = block.start.difference(config.searchFrom).inDays;
    s -= daysFromNow;

    return s;
  }

  int _scheduledMinutesOnDay(DateTime day, List<_Range> occupied) {
    int total = 0;
    for (final r in occupied) {
      if (r.start.year == day.year &&
          r.start.month == day.month &&
          r.start.day == day.day) {
        total += r.end.difference(r.start).inMinutes;
      }
    }
    return total;
  }

  bool _overlapsAny(DateTime start, DateTime end, List<_Range> ranges) {
    for (final r in ranges) {
      if (start.isBefore(r.end) && end.isAfter(r.start)) return true;
    }
    return false;
  }

  // Score a candidate activity slot. Higher = more desirable.
  int _scoreActivitySlot(
    DateTime start,
    SchedulerConfig config,
    List<_Range> occupied,
  ) {
    int s = 0;
    final h = start.hour;
    final inProductivity =
        config.productivityWindows.any((w) => w.containsHour(h));

    // Prime leisure window: 14:00–22:00 outside productivity
    if (h >= 14 && h < 22 && !inProductivity) s += 50;

    // General non-focus time bonus
    if (!inProductivity) s += 30;

    // Time-of-day preferences
    if (h >= 14 && h < 17) s += 20; // early afternoon
    if (h >= 17 && h < 20) s += 15; // evening
    if (h >= 20 && h < 22) s += 5;  // late evening

    // Penalise displacing productive focus time
    if (inProductivity) s -= 20;

    // Soft-rest overlap (lunch 12–13, dinner 18–19)
    if (h == 12 || h == 18) s -= 25;

    // Day overload penalty
    if (_scheduledMinutesOnDay(start, occupied) > 240) s -= 20;

    // Weekend bonus (more natural free time)
    final wd = start.weekday;
    if (wd == DateTime.saturday || wd == DateTime.sunday) s += 10;

    return s;
  }

  // Classify a time into morning (0), afternoon (1), or evening (2) bucket.
  int _bucketOf(DateTime t) {
    if (t.hour < 12) return 0;
    if (t.hour < 17) return 1;
    return 2;
  }

  // Add +15 to every candidate whose start hour matches the most-common hour
  // across all candidates, nudging the ranking toward a consistent weekly time.
  void _applyConsistencyBonus(List<_ScoredSlot> candidates) {
    if (candidates.isEmpty) return;
    final freq = <int, int>{};
    for (final c in candidates) {
      freq[c.start.hour] = (freq[c.start.hour] ?? 0) + 1;
    }
    final topHour =
        freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    for (final c in candidates) {
      if (c.start.hour == topHour) c.score += 15;
    }
  }

  // ── Daily-cap helpers ─────────────────────────────────────────────────────

  static String _dayKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static DateTime _startOfNextDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day + 1, 6, 0);

}

class _Range {
  final DateTime start;
  final DateTime end;
  _Range(this.start, this.end);
}

class _ScoredSlot {
  final DateTime start;
  final DateTime end;
  int score;
  _ScoredSlot({required this.start, required this.end, required this.score});
}
