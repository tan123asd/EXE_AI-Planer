# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**EXE AI-Planer** is a cross-platform Flutter app for AI-powered student scheduling. It helps students manage study deadlines and personal development with smart conflict detection, break reminders, and performance tracking.

## Common Commands

All commands run from `d:\Workspace\Nguyen_new_banch\EXE_AI-Planer\`.

```bash
flutter pub get              # Install/update dependencies
flutter run                  # Run on default connected device
flutter run -d chrome        # Run on web
flutter run -d windows       # Run on Windows desktop
flutter analyze              # Lint check
flutter format lib/          # Format all Dart source files
flutter clean                # Clean build artifacts
flutter build apk --release  # Build Android APK
```

## Architecture

**Pattern**: Feature-grouped screens with a shared service layer. No BLoC or Riverpod — state is managed with `provider` (v6.1.1) for theme only; screens hold local `StatefulWidget` state directly.

**Data flow**: All persistence goes through `StorageService` (`lib/services/storage_service.dart`), which wraps `shared_preferences`. There is no remote backend wired up yet (Firebase config exists but is unused for data).

**Key layers**:
- `lib/models/` — Plain Dart data classes (`Task`, `ScheduleItem`). `Task` carries performance-tracking fields (estimated vs. actual duration).
- `lib/services/storage_service.dart` — Single service that handles CRUD for tasks/schedules **and** contains all AI scheduling algorithms (conflict detection, break reminders, smart time-slot selection, performance learning).
- `lib/screens/` — Full-screen widgets. `home_screen.dart` is the main dashboard; `ai_schedule_screen.dart` renders AI-generated schedules; `new_task_input_screen.dart` is the primary task creation flow.
- `lib/widgets/` — Reusable components. AI-specific widgets: `performance_tracking_card.dart`, `break_reminder_widget.dart`.
- `lib/utils/constants.dart` — Single source of truth for all colors, text styles, spacing, and subject/status color mappings.
- `lib/providers/theme_provider.dart` — Light/dark theme toggle via `ChangeNotifier`.

## AI Scheduling Features (in `StorageService`)

1. **Conflict detection** — Checks new tasks against existing schedule for time overlaps; suggests alternative slots.
2. **Break reminders** — Pomodoro-style (50 min work / 10 min break); tracked via widget state.
3. **Performance tracking** — Compares estimated vs. actual task duration; updates accuracy stats shown on the home screen.
4. **Smart slot selection** — Avoids 8 AM–5 PM on weekdays, prefers mornings on weekends, only suggests future slots, uses explicit AM/PM formatting.

## Design System

Defined entirely in `lib/utils/constants.dart`. Do not use hardcoded colors or text styles elsewhere.

| Token | Value |
|---|---|
| Primary | `#FF6B35` (orange) |
| Background | `#F8F9FA` |
| Success | `#10B981` |
| Warning | `#F59E0B` |
| Danger | `#EF4444` |

Subject color map: Study → orange, Personal → purple (`#7B61FF`), Health → green (`#2FBF71`), Skill → blue (`#3B82F6`), Other → amber.

## Flutter SDK & Dependencies

- Flutter SDK constraint: `>=2.19.0 <3.0.0`
- Linting: `package:flutter_lints/flutter.yaml` (no custom overrides)
- Key packages: `provider`, `shared_preferences`, `intl`, `http`

---

## Scheduler Redesign (added 2026-05-09)

### New files

| File | Role |
|---|---|
| `lib/models/scheduler_models.dart` | All scheduler data classes (see schema below) |
| `lib/services/scheduler_service.dart` | Pure scheduling algorithm — no I/O, no UI |
| `lib/services/ai_service.dart` | OpenAI gpt-4o-mini API call that returns `AiTaskPlan` |

### Updated Architecture

The scheduling pipeline is now split across three layers:

```
AiService          → calls Gemini API, returns AiTaskPlan
SchedulerService   → pure function: (AiTaskPlan, SchedulerConfig, occupiedRanges) → ScheduleResult
StorageService     → supplies occupiedRanges + productivity hours; still owns conflict detection for legacy paths
```

`new_task_input_screen.dart` orchestrates the three: calls `AiService`, builds `SchedulerConfig` from `StorageService.getProductivityHours()`, calls `SchedulerService`, then renders results. Falls back to local heuristic (`_estimateTaskMinutesBySignals`) if the API call fails.

### AI Task Plan Schema

The Gemini prompt asks for this exact JSON. `AiTaskPlan.fromJson()` / `AiTaskPlan.fromMap()` parse it:

```json
{
  "created_at": "<ISO8601>",
  "deadline":   "<ISO8601>",
  "priority":   "high|medium|low",
  "tasks": [
    {
      "order":          1,
      "name":           "subtask name",
      "duration":       2,
      "focus_level":    "high|medium|low",
      "min_block":      1,
      "preferred_time": "high_focus|low_focus|flexible"
    }
  ]
}
```

- `duration` and `min_block` are in **hours as floats** (e.g. `0.5`, `1`, `2`). `AiSubtask` stores them as `double`.
- `min_block` ≤ `duration`: minimum continuous block that must not be interrupted.
- A task with `duration=4, min_block=2` may be split into 2×2 h sessions but never into chunks smaller than 2 h.

### Scheduler Algorithm (Part 1 — Deadline Tasks)

1. **Build occupancy** — `StorageService.getOccupiedTimeRanges(from, to)` expands all `Schedules` (recurring fixed), `Task` sessions, and `Activity` sessions into concrete `DateTimeRange`s.
2. **Hard exclusions** — Late night 22:30–06:00 is added to hard-occupied on every calendar day in the window.
3. **Soft rest inference** — Lunch 12:00–13:00 and dinner 18:00–19:00 are marked as soft-rest (−30 score) daily. If a day already has >4 h scheduled, adjacent gaps get −20.
4. **Task sort key**: `(priority_rank, focus_level_rank, task.order)` — high-focus tasks are scheduled first so they compete for the best blocks.
5. **Free block scan** — 30-minute step through `[now, deadline]`; consecutive free chunks merged into `TimeBlock`s; filtered by `minBlock`.
6. **Scoring** (higher is better):
   - `focus_level=high` in a productivity window → +50
   - `preferred_time=high_focus` in a productivity window → +30
   - `focus_level=low` outside productivity window → +20
   - `preferred_time=low_focus` outside productivity + not soft-rest → +20
   - Soft-rest block → −30
   - Day overload (>4 h) → −20
   - Deadline within 2 days → +15
7. **Greedy allocation** — picks the highest-scored block, allocates in `min_block` multiples, marks as occupied, repeats until task is fully scheduled or blocks run out.
8. **Failure reporting** — tasks that cannot fit before the deadline are returned in `ScheduleResult.failedTasks`; the UI shows a banner instead of silently dropping them.

### Scheduler Algorithm (Part 2 — Activity Tasks)

Redesigned 2026-05-10. **Do not revert to the old first-valid-slot approach.**

**Goal:** Return up to 14 scored candidate slots so the user can choose; multiple time options (morning / afternoon / evening) are surfaced per preferred weekday.

**Algorithm steps:**

1. **Build occupancy** — same `_parseOccupied()` + `_addLateNightBlocks()` used by Part 1.
2. **Scan preferred weekdays** — 15-minute steps from 07:00 to 22:30, over a 28-day window.
3. **Bucket per day** — slots are grouped into three buckets per day-occurrence: morning (07–12), afternoon (12–17), evening (17–22:30). Only the highest-scored slot from each bucket is kept → at most 3 candidates per day-occurrence.
4. **Slot scoring** (`_scoreActivitySlot`):
   - +50 if 14:00–22:00 AND outside productivity window (prime leisure)
   - +30 if outside productivity window (general non-focus time)
   - +20 if 14:00–17:00, +15 if 17:00–20:00, +5 if 20:00–22:00
   - −20 if inside a productivity window (avoid displacing focus time)
   - −25 if start hour is 12 or 18 (lunch / dinner overlap)
   - −20 if day already has >4 h scheduled
   - +10 on Saturday or Sunday
5. **Consistency bonus** (`_applyConsistencyBonus`) — after all candidates are collected, the most-common start hour across all candidates gets +15, nudging the ranking toward a consistent weekly rhythm.
6. **Sort and return** — sort descending by score, return top 14 as `List<ScheduledSlot>` (each carries a `score` field for future UI use).

**Key constants** (in `SchedulerService`):
```
_activityScanStepMinutes = 15
_activityLookAheadDays   = 28
_maxActivityCandidates   = 14
```

**Private helpers added:**
- `_scoreActivitySlot(DateTime, SchedulerConfig, List<_Range>) → int`
- `_bucketOf(DateTime) → int`  (0=morning, 1=afternoon, 2=evening)
- `_applyConsistencyBonus(List<_ScoredSlot>)`
- `_ScoredSlot` — private mutable value class (start, end, score)

**Removed:** `_leisureHours()`, `_startOfNextDay()`, `_maxActivityDays`, `_maxActivitySlots` constants.

**`ScheduledSlot`** now has an optional `score` field (default 0, not persisted in `toMap()`). The deadline path always passes `score: 0`; only the activity path fills it.

### Productivity Windows

Users configure peak-focus time ranges in the **Profile** screen (Productivity Hours card). Stored as JSON list under SharedPreferences key `productivity_hours`.

Default: `[{startHour: 8, endHour: 11}, {startHour: 19, endHour: 22}]`

`StorageService.getProductivityHours()` always returns a non-empty default if nothing is saved. `ProductivityWindow.containsHour(h)` is `h >= startHour && h < endHour` (end is exclusive).

### Occupancy Data Source

`StorageService.getOccupiedTimeRanges(DateTime from, DateTime to)` is the single source of truth for what is occupied. It returns entries with type `'fixed' | 'deadline' | 'activity'`. Always call this (not `hasScheduleConflict`) when constructing a `SchedulerConfig`.

### AI API Activation

The OpenAI API key is injected at build time:

```
flutter run --dart-define=OPENAI_API_KEY=sk-...
flutter build apk --dart-define=OPENAI_API_KEY=sk-...
```

If `OPENAI_API_KEY` is empty, `AiService.generateTaskPlan()` throws `AiServiceException`. The caller catches this, creates a single-subtask fallback plan from the local heuristic, and shows a snackbar. The scheduler still runs on the fallback plan — no code path skips the scheduler.

**Request body** sent to `POST /plan`:
```json
{
  "goal":        "<taskName>",
  "description": "<notes or taskName if empty>",
  "priority":    "high|medium|low",
  "created_at":  "<ISO8601 now>",
  "deadline":    "<ISO8601 full datetime>"
}
```

**Response** from the fine-tuned API is direct JSON (no unwrapping needed):
```json
{ "tasks": [...], "was_repaired": bool, "constraint_violations": [] }
```
`tasks` is passed directly to `AiTaskPlan.fromMap()`. `duration` and `min_block` in each task are **floats** (e.g. `0.5`, `1`, `2`), so `AiSubtask.duration` and `AiSubtask.minBlock` are `double`.

### Removed from `new_task_input_screen.dart`

`_findNextAvailableSlotWithTracking`, `_sortHoursByPreference`, and `_getPreferredHour` were deleted — their logic is now fully inside `SchedulerService`.
