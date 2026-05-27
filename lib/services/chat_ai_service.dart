import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_models.dart';
import 'context_compressor.dart';
import 'user_profile_service.dart';

class ChatAiService {
  static const _apiKey = String.fromEnvironment('OPENAI_API_KEY');
  static const _endpoint = 'https://api.openai.com/v1/chat/completions';

  final _compressor = ContextCompressor();

  static String _buildSystemPrompt(
    ConversationPhase phase, {
    String scheduleData = '',
    String profileHint = '',
  }) {
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final tomorrow = today.add(const Duration(days: 1));
    final tomorrowStr =
        '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';

    final schedulePart = scheduleData.isNotEmpty
        ? '\n\n## User\'s Tasks & Schedule\n$scheduleData'
        : '';
    final profilePart =
        profileHint.isNotEmpty ? '\n\n$profileHint' : '';

    final phaseBody = switch (phase) {
      ConversationPhase.collectingContext =>
        _promptCollecting + profilePart,
      ConversationPhase.awaitingApproval => _promptApproval,
      // idle and executing both need full tool routing + schedule context
      _ => _promptToolRouting + profilePart + schedulePart,
    };

    return (_promptBase + phaseBody)
        .replaceAll('{{TODAY}}', todayStr)
        .replaceAll('{{TOMORROW}}', tomorrowStr);
  }

  // ── Prompt sections ───────────────────────────────────────────────────────

  static const _promptBase = '''
You are an AI Planning Assistant in a smart scheduling app.
Today is {{TODAY}}. Tomorrow is {{TOMORROW}}.

## Vietnamese weekday mapping (CRITICAL — always apply exactly):
Thứ 2 (T2) = Monday    = weekday 1
Thứ 3 (T3) = Tuesday   = weekday 2
Thứ 4 (T4) = Wednesday = weekday 3
Thứ 5 (T5) = Thursday  = weekday 4
Thứ 6 (T6) = Friday    = weekday 5
Thứ 7 (T7) = Saturday  = weekday 6
Chủ nhật (CN) = Sunday = weekday 7
ALWAYS convert Vietnamese weekday names using this table when filling preferred_weekdays.
Example: "thứ 2, 4" → [1, 3]  |  "thứ 3, 5" → [2, 4]  |  "mỗi ngày" → [1,2,3,4,5,6,7]

## Rules
- Convert relative dates to ISO 8601 ONLY when the user explicitly states a date.
- "ngày mai" / "tomorrow" → {{TOMORROW}}
- "2 tuần" / "2 weeks" → add 14 days to {{TODAY}}
- "tháng sau" / "next month" → add 30 days to {{TODAY}}
- NEVER infer or guess a deadline from words like "deadline", "task", or "goal" alone.
- Reply in Vietnamese if the user writes Vietnamese, English otherwise.
- Keep replies concise and action-oriented.
- NEVER say "I don't have access to your schedule" — the data is in the system prompt.
''';

  // Used in idle + executing phases (full tool routing)
  static const _promptToolRouting = '''
## When to call tools vs reply text

### TASK tools (deadline-based work):
- User starts with "thêm task", "thêm 1 task", "tạo task", "tạo 1 task", "thêm công việc", "tạo công việc", "thêm 1 công việc", "thêm deadline", "thêm 1 deadline", "add task", "add a task", "create task" → decide between collect_plan_info or add_task_direct
  - Call add_task_direct ONLY when user provides ALL of: task name + SPECIFIC CALENDAR DATE (like "ngày 26", "30/5", "2026-05-26") + specific start hour + duration in ONE message.
  - Day-of-week expressions like "thứ 3", "thứ 4 hàng tuần", "mỗi thứ 2" are NOT specific calendar dates → use collect_plan_info.
  - Otherwise (missing info, or multi-session goal) → call collect_plan_info.
  - "tạo task X" or "tạo 1 task X" WITHOUT full date+time+duration → call collect_plan_info (same as "thêm task").
- User says they need more time / "không kịp deadline" / "task này khó" → call re_plan_task with userIntent="need_more_time"
- User says a task is easy / needs less time → call re_plan_task with userIntent="task_is_easier"
- User wants to move/reschedule a task ("dời sang ngày mai", "shift to next week") → call shift_task
- User says a task is done/finished → call complete_task
- User wants to delete something → look at ## User's Tasks & Schedule to decide:
  - If the name matches a TOP-LEVEL task (listed with its deadline) → call delete_task
  - If the name matches a SUBTASK/SESSION inside a task → call delete_subtask
  - When in doubt, PREFER delete_subtask (safer: only removes one session, not the whole task)
- User wants to delete all tasks → call delete_task with "__ALL__"
- User says "too much work" / "quá nặng" / "nhẹ hơn" → call adjust_workload

### ACTIVITY tools (personal habits/hobbies):
- User starts with "thêm hoạt động", "thêm 1 hoạt động", "add activity", "add an activity" → call add_activity with one of three modes:
  MODE A — Specific date + specific time (e.g. "đá bóng 1h vào 14h ngày 23/5"):
    → set specific_date (ISO8601 YYYY-MM-DD) + specific_start_hour. System adds one session.
  MODE B — Specific time, recurring weekdays (e.g. "đá bóng 1h vào 14h mỗi ngày", "đọc sách 1h lúc 9h thứ 2 4"):
    → set specific_start_hour + preferred_weekdays. Leave specific_date null. System adds recurring sessions at that exact hour.
  MODE C — No specific time, AI suggests (e.g. "đọc sách 1h mỗi thứ 2 4", "AI gợi ý giờ"):
    → set preferred_weekdays only. Leave both specific_date and specific_start_hour null. System will show suggestions for user confirmation before saving.
- User wants to move an activity ("dời hoạt động", "shift activity") → call shift_activity
- User wants to delete an activity ("xóa hoạt động", "delete activity") → call delete_activity

### SCHEDULE queries:
- User asks about schedule, today's tasks, tomorrow's tasks, tasks on a specific date, or upcoming deadlines → reply DIRECTLY as text. Do NOT call any tool.
- The schedule is organized by date in "=== Schedule by date ===" in ## User's Tasks & Schedule.
- For schedule queries, always read ## User's Tasks & Schedule and give a clear human-readable answer.

### CLARIFICATION RULES — confidence field (shift_task, add_task_direct, adjust_workload, re_plan_task):
Set confidence='high' ONLY when the user EXPLICITLY stated the info:
- shift_task: 'high' only if user explicitly stated the exact number of days (e.g. "3 ngày", "1 tuần"). If no number given, set confidence='low' and clarification_needed="Bạn muốn dời task bao nhiêu ngày?".
- add_task_direct: 'high' only if all 4 fields (name+date+hour+duration) are explicit. If start hour is missing, set confidence='low' and clarification_needed="Bạn muốn bắt đầu lúc mấy giờ?".
- adjust_workload: 'high' only if task name AND direction are both clear. If task name is missing or vague, set confidence='low' and clarification_needed="Bạn muốn điều chỉnh task nào?".
- re_plan_task: 'high' only if the task name is clearly stated. If not, set confidence='low' and clarification_needed="Bạn muốn lập kế hoạch lại cho task nào?".

### FUZZY MATCH CONFIRMATION — when task name is abbreviated:
If the user refers to a task by a SHORT or PARTIAL name (e.g. user says "toán" but the full task name is "Ôn thi Toán"), set confidence='medium' and clarification_needed="Tôi tìm thấy task '[tên đầy đủ]'. Đây có phải task bạn muốn không?" so the user can confirm before any action is taken.

### Default:
- Greetings, clarifications, or anything else → reply with text only (NO tool call)
''';

  // Used only in collectingContext phase
  static const _promptCollecting = '''
## Collecting plan information
You are gathering information to create a study plan. Use collect_plan_info to record each piece of info the user provides.
- Required fields IN ORDER: goal → task_details → deadline → daily_hours.
- task_details is ALWAYS required (not only for vague goals). After the user states their goal, ALWAYS ask "What specific steps/topics does this involve?" before asking for the deadline.
- Ask ONE question at a time. Do NOT ask for multiple fields in the same message.
- When ALL FOUR (goal, task_details, deadline, daily_hours) are present in ## Current Context → say "Tuyệt vời, tôi đã có đủ thông tin. Đang tạo kế hoạch..." and stop calling collect_plan_info.
''';

  // Used only in awaitingApproval phase
  static const _promptApproval = '''
## Plan approval
A study plan has been generated and displayed to the user. Your role:
- If user approves ("yes", "ok", "lưu", "được", "đồng ý") → confirm it will be saved.
- If user rejects or asks for changes → acknowledge and ask what they would like to change.
- Do NOT call any tool in this phase. Reply with text only.
''';

  static const _tools = [
    {
      'type': 'function',
      'function': {
        'name': 'collect_plan_info',
        'description': 'Collect information to create a new study plan. '
            'Call when the user mentions a goal, deadline, or daily hours. '
            'Pass null for fields not yet known.',
        'parameters': {
          'type': 'object',
          'properties': {
            'goal': {'type': 'string', 'description': 'What the user wants to achieve'},
            'task_details': {
              'type': 'string',
              'description': 'Specific topics, chapters, steps, or content the user needs to work on. '
                  'Ask for this when the goal is vague (e.g. "ôn thi toán" → ask which chapters/topics). '
                  'Set once the user provides specifics.',
            },
            'deadline': {
              'type': 'string',
              'description':
                  'ISO 8601 YYYY-MM-DD — set ONLY when the user explicitly states a specific date or relative date '
                  '("tomorrow", "next week", "May 30", "in 2 weeks"). '
                  'Leave null if the user has NOT mentioned a specific deadline date. '
                  'Do NOT infer a date from the word "deadline" alone.',
            },
            'daily_hours': {'type': 'number', 'description': 'Hours per day the user can work'},
            'project_type': {
              'type': 'string',
              'enum': ['research', 'production', 'personal'],
            },
          },
          'required': <String>[],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'shift_task',
        'description': 'Move all sessions of a task forward or backward by N days.',
        'parameters': {
          'type': 'object',
          'properties': {
            'task_name': {'type': 'string', 'description': 'Name of the task to shift (fuzzy matched)'},
            'days_offset': {
              'type': 'integer',
              'description': 'Positive = forward, negative = backward',
            },
            'confidence': {
              'type': 'string',
              'enum': ['high', 'medium', 'low'],
              'description': 'high: user stated the exact days explicitly. medium: inferred. low: ambiguous.',
            },
            'clarification_needed': {
              'type': 'string',
              'description': 'Fill when confidence is medium or low. Describe what is unclear (e.g. "How many days forward?").',
            },
          },
          'required': ['task_name', 'days_offset'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'complete_task',
        'description': 'Mark all sessions of a task as completed.',
        'parameters': {
          'type': 'object',
          'properties': {
            'task_name': {'type': 'string', 'description': 'Name of the task to mark complete'},
          },
          'required': ['task_name'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 're_plan_task',
        'description': 'Re-analyze and reschedule a task when the user says they need more time, '
            'cannot finish on time, or a task is easier than expected. '
            'Checks completed vs incomplete sessions and re-plans only the remaining work. '
            'Do NOT use shift_task for this — shift_task only moves sessions, this re-plans them.',
        'parameters': {
          'type': 'object',
          'properties': {
            'task_name': {
              'type': 'string',
              'description': 'Name of the task to re-plan (fuzzy matched)',
            },
            'user_intent': {
              'type': 'string',
              'enum': ['need_more_time', 'task_is_easier'],
              'description': 'need_more_time: user cannot finish on time; task_is_easier: task needs less time',
            },
            'confidence': {
              'type': 'string',
              'enum': ['high', 'medium', 'low'],
              'description': 'high: intent is clear. medium: inferred. low: ambiguous.',
            },
            'clarification_needed': {
              'type': 'string',
              'description': 'Fill when confidence is medium or low. Describe what is unclear.',
            },
          },
          'required': ['task_name', 'user_intent'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'delete_task',
        'description': 'Delete an ENTIRE task including ALL its subtasks/sessions. '
            'Use "__ALL__" to delete everything. '
            'If user only wants to delete one subtask/session, use delete_subtask instead.',
        'parameters': {
          'type': 'object',
          'properties': {
            'task_name': {
              'type': 'string',
              'description': 'Task name or "__ALL__" to delete all tasks',
            },
          },
          'required': ['task_name'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'delete_subtask',
        'description': 'Delete a specific subtask/session within a task, keeping the rest of the task intact. '
            'Use this when the user says they want to remove one specific subtask or session, '
            'NOT the whole task.',
        'parameters': {
          'type': 'object',
          'properties': {
            'subtask_name': {
              'type': 'string',
              'description': 'Name of the subtask/session to delete (fuzzy matched against session names)',
            },
          },
          'required': ['subtask_name'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'adjust_workload',
        'description': 'Reschedule a task with a lighter or heavier daily load.',
        'parameters': {
          'type': 'object',
          'properties': {
            'task_name': {'type': 'string'},
            'direction': {
              'type': 'string',
              'enum': ['lighter', 'heavier'],
            },
            'confidence': {
              'type': 'string',
              'enum': ['high', 'medium', 'low'],
              'description': 'high: user clearly said lighter/heavier. medium: inferred. low: ambiguous.',
            },
            'clarification_needed': {
              'type': 'string',
              'description': 'Fill when confidence is medium or low. Describe what is unclear.',
            },
          },
          'required': ['task_name', 'direction'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'add_task_direct',
        'description':
            'Add a single standalone task session when the user provides ALL info in ONE message: '
            'task name + specific date + specific start time + duration. '
            'Triggered by: "thêm task", "thêm 1 task", "thêm công việc", "thêm deadline". '
            'Use ONLY when all four fields are clearly present. '
            'If any field is missing or the user needs a multi-session AI plan, use collect_plan_info instead.',
        'parameters': {
          'type': 'object',
          'properties': {
            'task_name': {'type': 'string', 'description': 'Name of the task'},
            'duration_minutes': {'type': 'integer', 'description': 'Duration in minutes'},
            'specific_date': {
              'type': 'string',
              'description': 'ISO 8601 YYYY-MM-DD of the specific day',
            },
            'specific_start_hour': {
              'type': 'integer',
              'description': 'Start hour 0-23 (e.g. 14 for 14:00)',
            },
            'confidence': {
              'type': 'string',
              'enum': ['high', 'medium', 'low'],
              'description': 'high: all fields explicitly stated. medium: date/time inferred. low: ambiguous.',
            },
            'clarification_needed': {
              'type': 'string',
              'description': 'Fill when confidence is medium or low. Describe what is unclear (e.g. "What date exactly?").',
            },
          },
          'required': ['task_name', 'duration_minutes', 'specific_date', 'specific_start_hour'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'add_activity',
        'description':
            'Add a personal activity or hobby (NOT a deadline task). '
            'Triggered by: "thêm hoạt động", "thêm 1 hoạt động", "add activity". '
            'If the user gives an exact time and date (e.g. "vào 14h ngày 23"), set specific_date + specific_start_hour. '
            'If the user wants recurring or AI-suggested slots, set preferred_weekdays and leave specific_date null.',
        'parameters': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'description': 'Activity name'},
            'duration_minutes': {'type': 'integer', 'description': 'Duration in minutes'},
            'preferred_weekdays': {
              'type': 'array',
              'items': {'type': 'integer'},
              'description': '1=Mon, 2=Tue, ..., 7=Sun. Null if user specified an exact date instead.',
            },
            'specific_date': {
              'type': 'string',
              'description': 'ISO 8601 YYYY-MM-DD if user specified a concrete date. Null for recurring.',
            },
            'specific_start_hour': {
              'type': 'integer',
              'description': 'Start hour 0-23 if user specified a concrete time. Null for AI-suggested.',
            },
            'category': {
              'type': 'string',
              'description': 'Category label, default "Personal"',
            },
          },
          'required': ['name', 'duration_minutes'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'shift_activity',
        'description': 'Move all sessions of an activity forward or backward by N days.',
        'parameters': {
          'type': 'object',
          'properties': {
            'activity_name': {'type': 'string', 'description': 'Activity name (fuzzy matched)'},
            'days_offset': {
              'type': 'integer',
              'description': 'Positive = forward, negative = backward',
            },
          },
          'required': ['activity_name', 'days_offset'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'delete_activity',
        'description': 'Delete an activity and all its sessions.',
        'parameters': {
          'type': 'object',
          'properties': {
            'activity_name': {'type': 'string', 'description': 'Activity name (fuzzy matched)'},
          },
          'required': ['activity_name'],
        },
      },
    },
  ];

  Future<AiToolCall> chat(
    String userMessage,
    ConversationContext ctx,
    List<ChatMessage> history, {
    String? scheduleContext,
  }) async {
    if (_apiKey.isEmpty) {
      return TextOnlyResponse(
        content: 'OpenAI API key not configured. Please run the app with --dart-define=OPENAI_API_KEY=sk-...',
      );
    }

    final ctxSummary = _buildContextSummary(ctx);
    final profileHint = UserProfileService().toPromptString();

    final effectiveHistory = await _compressor.maybeCompress(history, _apiKey);
    final recent = effectiveHistory.length > 20
        ? effectiveHistory.sublist(effectiveHistory.length - 20)
        : effectiveHistory;
    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content':
            '${_buildSystemPrompt(ctx.phase, scheduleData: scheduleContext ?? '', profileHint: profileHint)}\n\n## Current Context\n$ctxSummary',
      },
      for (final msg in recent)
        {'role': msg.role.name, 'content': msg.content},
      {'role': 'user', 'content': userMessage},
    ];

    final body = jsonEncode({
      'model': 'gpt-4o-mini',
      'temperature': 0.4,
      'tools': _tools,
      'tool_choice': 'auto',
      'messages': messages,
    });

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      return TextOnlyResponse(content: 'Network error. Please check your connection and try again.');
    }

    if (response.statusCode != 200) {
      return TextOnlyResponse(content: 'API error (${response.statusCode}). Please try again.');
    }

    try {
      final outer = jsonDecode(response.body) as Map<String, dynamic>;
      final message = (outer['choices'] as List).first['message'] as Map<String, dynamic>;
      final toolCalls = message['tool_calls'] as List<dynamic>?;

      if (toolCalls == null || toolCalls.isEmpty) {
        final content = message['content'] as String? ?? '';
        return TextOnlyResponse(content: content);
      }

      final fn = (toolCalls.first as Map<String, dynamic>)['function'] as Map<String, dynamic>;
      final name = fn['name'] as String;
      final args = jsonDecode(fn['arguments'] as String) as Map<String, dynamic>;
      return _parseToolCall(name, args);
    } catch (e) {
      return TextOnlyResponse(content: 'Failed to parse AI response. Please try again.');
    }
  }

  AiToolCall _parseToolCall(String name, Map<String, dynamic> args) {
    try {
      switch (name) {
        case 'collect_plan_info':
          return CollectPlanInfoCall(
            goal: args['goal'] as String?,
            deadline: args['deadline'] as String?,
            dailyHours: (args['daily_hours'] as num?)?.toDouble(),
            taskDetails: args['task_details'] as String?,
            projectType: args['project_type'] as String?,
          );
        case 'shift_task':
          return ShiftTaskCall(
            taskName: args['task_name'] as String,
            daysOffset: (args['days_offset'] as num).toInt(),
            confidence: args['confidence'] as String? ?? 'high',
            clarificationNeeded: args['clarification_needed'] as String?,
          );
        case 'complete_task':
          return CompleteTaskCall(taskName: args['task_name'] as String);
        case 're_plan_task':
          return RePlanTaskCall(
            taskName: args['task_name'] as String,
            userIntent: args['user_intent'] as String? ?? 'need_more_time',
            confidence: args['confidence'] as String? ?? 'high',
            clarificationNeeded: args['clarification_needed'] as String?,
          );
        case 'delete_task':
          return DeleteTaskCall(taskName: args['task_name'] as String);
        case 'delete_subtask':
          return DeleteSubtaskCall(subtaskName: args['subtask_name'] as String);
        case 'adjust_workload':
          return AdjustWorkloadCall(
            taskName: args['task_name'] as String,
            direction: args['direction'] as String,
            confidence: args['confidence'] as String? ?? 'high',
            clarificationNeeded: args['clarification_needed'] as String?,
          );
        case 'query_schedule':
          return QueryScheduleCall(timeRange: args['time_range'] as String);
        case 'add_task_direct':
          return AddTaskDirectCall(
            taskName: args['task_name'] as String,
            durationMinutes: (args['duration_minutes'] as num).toInt(),
            specificDate: args['specific_date'] as String,
            specificStartHour: (args['specific_start_hour'] as num).toInt(),
            confidence: args['confidence'] as String? ?? 'high',
            clarificationNeeded: args['clarification_needed'] as String?,
          );
        case 'add_activity':
          final weekdaysRaw = args['preferred_weekdays'] as List<dynamic>?;
          return AddActivityCall(
            name: args['name'] as String,
            durationMinutes: (args['duration_minutes'] as num).toInt(),
            preferredWeekdays: weekdaysRaw?.map((e) => (e as num).toInt()).toList(),
            specificDate: args['specific_date'] as String?,
            specificStartHour: (args['specific_start_hour'] as num?)?.toInt(),
            category: args['category'] as String? ?? 'Personal',
          );
        case 'shift_activity':
          return ShiftActivityCall(
            activityName: args['activity_name'] as String,
            daysOffset: (args['days_offset'] as num).toInt(),
          );
        case 'delete_activity':
          return DeleteActivityCall(activityName: args['activity_name'] as String);
        default:
          return TextOnlyResponse(content: 'Unknown action: $name');
      }
    } catch (e) {
      return TextOnlyResponse(content: 'Could not parse action. Please try again.');
    }
  }

  String _buildContextSummary(ConversationContext ctx) {
    if (ctx.goalDescription == null) return 'No active planning session.';
    final lines = <String>[
      'Goal: ${ctx.goalDescription}',
      if (ctx.taskDetails != null) 'Task details: ${ctx.taskDetails}',
      if (ctx.parsedDeadline != null) 'Deadline: ${ctx.parsedDeadline!.toIso8601String()}',
      if (ctx.dailyAvailableHours != null) 'Daily hours available: ${ctx.dailyAvailableHours}',
      if (ctx.projectType != null) 'Project type: ${ctx.projectType}',
      if (ctx.additionalNotes != null) 'Notes: ${ctx.additionalNotes}',
      'Phase: ${ctx.phase.name}',
    ];
    return lines.join('\n');
  }
}
