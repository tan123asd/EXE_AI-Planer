# Kế hoạch Refactor: Chat AI → OpenAI Function Calling

## Mục tiêu
Thay thế cơ chế JSON schema cứng nhắc + hardcode string matching bằng OpenAI Function Calling,
cho phép AI tự chọn hành động và điền tham số một cách linh hoạt.

## Tổng quan thay đổi

```
TRƯỚC                                SAU
─────────────────────────────────    ─────────────────────────────────
AI trả JSON cố định (intent +        AI gọi tool với tham số đúng
extractedData schema)                ngôn ngữ tự nhiên

Flutter hardcode string matching     Flutter chỉ đọc tool call và
(_parseDayOffset, _extractLastWord)  thực thi deterministic action

8 intent enum + switch/case          Sealed class AiToolCall, mỗi
                                     tool là 1 type riêng
```

---

## Các file bị ảnh hưởng

| File | Loại thay đổi |
|------|--------------|
| `lib/models/chat_models.dart` | Thêm sealed classes `AiToolCall` |
| `lib/services/chat_ai_service.dart` | Viết lại hoàn toàn `chat()` |
| `lib/screens/chat_planner_screen.dart` | Viết lại `_sendMessage()` + dispatch |
| `lib/services/chat_planner_service.dart` | Expose `findTask()` public |

**Không thay đổi:** UI build methods, `ChatPlanPreviewCard`, `ChatPlannerService` (logic thực thi),
`StorageService`, `SchedulerService`, `AiService`, `ConversationContext`, `ChatMessage`.

---

## Bước 1 — `chat_models.dart`: Thêm Sealed Classes

**Thời gian ước tính:** 30 phút  
**Độ phức tạp:** Thấp

Thêm vào cuối file (không xóa gì):

```dart
sealed class AiToolCall {}

class CollectPlanInfoCall extends AiToolCall {
  final String? goal;
  final String? deadline;       // ISO 8601 YYYY-MM-DD
  final double? dailyHours;
  final String? taskDetails;
  final String? projectType;
  CollectPlanInfoCall({this.goal, this.deadline, this.dailyHours, this.taskDetails, this.projectType});
}

class ShiftTaskCall extends AiToolCall {
  final String taskName;
  final int daysOffset;         // âm = lui, dương = tiến
  ShiftTaskCall({required this.taskName, required this.daysOffset});
}

class CompleteTaskCall extends AiToolCall {
  final String taskName;
  CompleteTaskCall({required this.taskName});
}

class DeleteTaskCall extends AiToolCall {
  final String taskName;        // "__ALL__" = xóa tất cả
  DeleteTaskCall({required this.taskName});
}

class AdjustWorkloadCall extends AiToolCall {
  final String taskName;
  final String direction;       // "lighter" | "heavier"
  AdjustWorkloadCall({required this.taskName, required this.direction});
}

class QueryScheduleCall extends AiToolCall {
  final String timeRange;       // "today" | "this_week" | "all"
  QueryScheduleCall({required this.timeRange});
}

class TextOnlyResponse extends AiToolCall {
  final String content;
  TextOnlyResponse({required this.content});
}
```

**Verify:** `flutter analyze` không báo lỗi mới.

---

## Bước 2 — `chat_ai_service.dart`: Tool Definitions

**Thời gian ước tính:** 20 phút  
**Độ phức tạp:** Thấp

Thêm constant `_tools` vào class `ChatAiService`:

```dart
static const _tools = [
  {
    'type': 'function',
    'function': {
      'name': 'collect_plan_info',
      'description': 'Collect information to create a new study plan. '
          'Call when user mentions a goal, deadline, or daily hours. '
          'Pass null for unknown fields.',
      'parameters': {
        'type': 'object',
        'properties': {
          'goal':         {'type': 'string', 'description': 'What the user wants to achieve'},
          'task_details': {'type': 'string', 'description': 'Scope, expected output, complexity'},
          'deadline':     {'type': 'string', 'description': 'ISO 8601 YYYY-MM-DD. Today={{TODAY}}'},
          'daily_hours':  {'type': 'number', 'description': 'Hours per day available'},
          'project_type': {'type': 'string', 'enum': ['research', 'production', 'personal']},
        },
        'required': [],
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
          'task_name':   {'type': 'string'},
          'days_offset': {'type': 'integer', 'description': 'Positive=forward, negative=backward'},
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
          'task_name': {'type': 'string'},
        },
        'required': ['task_name'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'delete_task',
      'description': 'Delete a specific task or all tasks. Use "__ALL__" to delete everything.',
      'parameters': {
        'type': 'object',
        'properties': {
          'task_name': {'type': 'string', 'description': 'Task name or "__ALL__"'},
        },
        'required': ['task_name'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'adjust_workload',
      'description': 'Reschedule a task with lighter or heavier daily load.',
      'parameters': {
        'type': 'object',
        'properties': {
          'task_name': {'type': 'string'},
          'direction': {'type': 'string', 'enum': ['lighter', 'heavier']},
        },
        'required': ['task_name', 'direction'],
      },
    },
  },
  {
    'type': 'function',
    'function': {
      'name': 'query_schedule',
      'description': 'Signal intent to summarize the user schedule. '
          'The data is already in the system prompt — call this then reply with a summary.',
      'parameters': {
        'type': 'object',
        'properties': {
          'time_range': {'type': 'string', 'enum': ['today', 'this_week', 'all']},
        },
        'required': ['time_range'],
      },
    },
  },
];
```

**Verify:** Không có gì để test ở bước này (chỉ là constant).

---

## Bước 3 — `chat_ai_service.dart`: Viết lại `chat()`

**Thời gian ước tính:** 90 phút  
**Độ phức tạp:** Cao — trung tâm của refactor

### 3a. System prompt mới (ngắn hơn, không có phần "Response Format JSON")

```dart
static const _systemPromptTemplate = '''
You are an AI Planning Assistant in a smart scheduling app.
The ## User's Tasks & Schedule section contains REAL-TIME data from the app.

## When to call tools vs reply text
- User mentions a new goal, deadline, or daily hours → call collect_plan_info
- User wants to move/reschedule a task → call shift_task
- User says a task is done/finished → call complete_task
- User wants to delete a task or all tasks → call delete_task
- User says "too much work" / "reduce" / "heavier" / "lighter" → call adjust_workload
- User asks about their schedule / today's tasks → call query_schedule THEN reply with summary
- Greetings, clarifications, anything else → reply with text only (NO tool call)

## Multi-turn context collection
The ## Current Context section shows what has been collected for the active plan.
- If goal/deadline/daily_hours is still missing, call collect_plan_info with new values
- When ALL THREE (goal + deadline + daily_hours) are in context → say
  "Great, I have everything I need. Let me generate your plan..." and do NOT call collect_plan_info

## Rules
- Today is {{TODAY}}. Always convert relative dates to YYYY-MM-DD in tool args.
- "ngày mai" → {{TOMORROW}}. "2 tuần" → add 14 days to {{TODAY}}.
- Reply in Vietnamese if the user writes Vietnamese, English otherwise.
- Keep replies concise. NEVER say "I don't have access to your schedule."
''';
```

### 3b. Signature mới — trả `AiToolCall` thay vì `ChatResponse`

```dart
Future<AiToolCall> chat(
  String userMessage,
  ConversationContext ctx,
  List<ChatMessage> history, {
  String? scheduleContext,
}) async {
  if (_apiKey.isEmpty) {
    return TextOnlyResponse(content: 'OpenAI API key not configured.');
  }

  final ctxSummary = _buildContextSummary(ctx);
  final schedulePart = scheduleContext != null
      ? '\n\n## User\'s Tasks & Schedule\n$scheduleContext'
      : '';

  final recent = history.length > 20 ? history.sublist(history.length - 20) : history;
  final messages = <Map<String, dynamic>>[
    {'role': 'system', 'content': '${_buildSystemPrompt()}\n\n## Current Context\n$ctxSummary$schedulePart'},
    for (final msg in recent)
      {'role': msg.role.name, 'content': msg.content},
    {'role': 'user', 'content': userMessage},
  ];

  final body = jsonEncode({
    'model': 'gpt-4o-mini',
    'temperature': 0.4,
    'tools': _tools,
    'tool_choice': 'auto',
    // KHÔNG còn response_format: json_object
    'messages': messages,
  });

  http.Response response;
  try {
    response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: body,
    ).timeout(const Duration(seconds: 30));
  } catch (e) {
    return TextOnlyResponse(content: 'Network error. Please check your connection.');
  }

  if (response.statusCode != 200) {
    return TextOnlyResponse(content: 'API error (${response.statusCode}). Please try again.');
  }

  try {
    final outer = jsonDecode(response.body) as Map<String, dynamic>;
    final message = (outer['choices'] as List).first['message'] as Map<String, dynamic>;
    final toolCalls = message['tool_calls'] as List<dynamic>?;

    if (toolCalls == null || toolCalls.isEmpty) {
      // AI reply thuần text (general, hỏi câu tiếp theo, v.v.)
      final content = message['content'] as String? ?? '';
      return TextOnlyResponse(content: content);
    }

    // AI gọi tool
    final fn = (toolCalls.first as Map<String, dynamic>)['function'] as Map<String, dynamic>;
    final name = fn['name'] as String;
    final args = jsonDecode(fn['arguments'] as String) as Map<String, dynamic>;
    return _parseToolCall(name, args);
  } catch (e) {
    return TextOnlyResponse(content: 'Failed to parse AI response. Please try again.');
  }
}
```

### 3c. `_parseToolCall()` method

```dart
AiToolCall _parseToolCall(String name, Map<String, dynamic> args) {
  try {
    switch (name) {
      case 'collect_plan_info':
        return CollectPlanInfoCall(
          goal:        args['goal'] as String?,
          deadline:    args['deadline'] as String?,
          dailyHours:  (args['daily_hours'] as num?)?.toDouble(),
          taskDetails: args['task_details'] as String?,
          projectType: args['project_type'] as String?,
        );
      case 'shift_task':
        return ShiftTaskCall(
          taskName:   args['task_name'] as String,
          daysOffset: (args['days_offset'] as num).toInt(),
        );
      case 'complete_task':
        return CompleteTaskCall(taskName: args['task_name'] as String);
      case 'delete_task':
        return DeleteTaskCall(taskName: args['task_name'] as String);
      case 'adjust_workload':
        return AdjustWorkloadCall(
          taskName:  args['task_name'] as String,
          direction: args['direction'] as String,
        );
      case 'query_schedule':
        return QueryScheduleCall(timeRange: args['time_range'] as String);
      default:
        return TextOnlyResponse(content: 'Unknown action: $name');
    }
  } catch (e) {
    return TextOnlyResponse(content: 'Could not parse action. Please try again.');
  }
}
```

**Verify (test thủ công với print log):**
- "Hello" → `TextOnlyResponse`
- "Tôi muốn học Flutter" → `CollectPlanInfoCall(goal: "học Flutter")`
- "Dời task Math sang 3 ngày sau" → `ShiftTaskCall(taskName: "Math", daysOffset: 3)`
- "Xong task Assignment rồi" → `CompleteTaskCall(taskName: "Assignment")`
- "Xóa tất cả task" → `DeleteTaskCall(taskName: "__ALL__")`
- "Lịch hôm nay của tôi" → `QueryScheduleCall(timeRange: "today")`

---

## Bước 4 — `chat_planner_screen.dart`: Dispatch Logic

**Thời gian ước tính:** 90 phút  
**Độ phức tạp:** Cao

### 4a. Cập nhật `_sendMessage()`

```dart
Future<void> _sendMessage(String text) async {
  final trimmed = text.trim();
  if (trimmed.isEmpty || _isLoading) return;

  _inputController.clear();
  final userMsg = ChatMessage(role: MessageRole.user, content: trimmed);
  setState(() {
    _messages.add(userMsg);
    _isLoading = true;
  });
  _scrollToBottom();

  try {
    final scheduleCtx = _buildScheduleContext();
    final toolCall = await _aiService.chat(trimmed, _context, _messages, scheduleContext: scheduleCtx);
    await _dispatchToolCall(toolCall);
  } catch (e) {
    _addAiMessage('Something went wrong. Please check your connection and try again.');
  } finally {
    setState(() => _isLoading = false);
    _persistState();
    _scrollToBottom();
  }
}
```

### 4b. `_dispatchToolCall()` — thay cho toàn bộ if-else intent cũ

```dart
Future<void> _dispatchToolCall(AiToolCall call) async {
  switch (call) {
    case TextOnlyResponse(:final content):
      _addAiMessage(content);

    case CollectPlanInfoCall():
      _applyCollectPlanInfo(call);
      if (_isReadyToPlan()) {
        await _handleGeneratePlan();
      } else {
        _addAiMessage(_buildNextQuestion());
      }

    case ShiftTaskCall(:final taskName, :final daysOffset):
      final result = await _plannerService.shiftTaskByDays(taskName, daysOffset);
      _addAiMessage(result);

    case CompleteTaskCall(:final taskName):
      final result = await _plannerService.completeTask(taskName);
      _addAiMessage(result);

    case DeleteTaskCall(:final taskName):
      if (taskName == '__ALL__') {
        final confirmed = await _showDeleteAllConfirm();
        if (confirmed == true) {
          _addAiMessage(await _plannerService.deleteAllTasks());
        } else {
          _addAiMessage('Understood, all tasks have been kept.');
        }
      } else {
        final confirmed = await _showDeleteConfirm(taskName);
        if (confirmed == true) {
          _addAiMessage(await _plannerService.deleteTask(taskName));
        } else {
          _addAiMessage('Got it, "$taskName" will not be deleted.');
        }
      }

    case AdjustWorkloadCall(:final taskName, :final direction):
      await _handleAdjustWorkload(taskName, direction);

    case QueryScheduleCall():
      // AI đã có schedule data trong system prompt — reply sẽ đến qua TextOnlyResponse
      // Không cần action phía Flutter
      break;
  }
}
```

### 4c. Các method mới/cập nhật

```dart
void _applyCollectPlanInfo(CollectPlanInfoCall call) {
  if (call.goal != null && _context.goalDescription == null) {
    _context.goalDescription = call.goal;
    _context.phase = ConversationPhase.collectingContext;
  }
  if (call.deadline != null && _context.parsedDeadline == null) {
    _context.parsedDeadline = _parseDeadlineIso(call.deadline!);
  }
  if (call.dailyHours != null && _context.dailyAvailableHours == null) {
    _context.dailyAvailableHours = call.dailyHours!.round();
  }
  if (call.taskDetails != null && _context.taskDetails == null) {
    _context.taskDetails = call.taskDetails;
  }
  if (call.projectType != null) {
    _context.projectType = call.projectType;
  }
}

bool _isReadyToPlan() =>
    _context.goalDescription != null &&
    _context.parsedDeadline != null &&
    _context.dailyAvailableHours != null;

// Đơn giản hóa — AI đã convert sang ISO, không cần parse phức tạp
DateTime? _parseDeadlineIso(String raw) {
  final dt = DateTime.tryParse(raw);
  if (dt == null) return null;
  return DateTime(dt.year, dt.month, dt.day, 23, 59, 59);
}

// Câu hỏi tiếp theo (deterministic — không tốn API call thêm)
String _buildNextQuestion() {
  final lastUser = _messages.lastWhere(
    (m) => m.role == MessageRole.user, orElse: () => _messages.last);
  final isVi = lastUser.content.runes.any((r) => r > 127);

  if (_context.goalDescription == null) {
    return isVi
        ? 'Bạn muốn đạt được điều gì? Hãy mô tả mục tiêu của bạn.'
        : 'What would you like to accomplish? Please describe your goal.';
  }
  if (_context.parsedDeadline == null) {
    return isVi
        ? 'Deadline cho "${_context.goalDescription}" là khi nào?'
        : 'What is your deadline for "${_context.goalDescription}"?';
  }
  return isVi
      ? 'Mỗi ngày bạn có thể dành bao nhiêu giờ cho việc này?'
      : 'How many hours per day can you work on this?';
}

Future<void> _handleAdjustWorkload(String taskName, String direction) async {
  final task = _plannerService.findTask(taskName);
  if (task == null) {
    _addAiMessage('Could not find a task matching "$taskName".');
    return;
  }
  final multiplier = direction == 'lighter' ? 0.7 : 1.4;
  final deadline = DateTime.tryParse(task['deadline'] as String? ?? '')
      ?? DateTime.now().add(const Duration(days: 7));
  final result = await _plannerService.adjustWorkload(
      task['id'] as String, multiplier, deadline);
  if (result == null) {
    _addAiMessage('Could not adjust workload for "$taskName".');
  } else {
    _addAiMessage(
        'Workload adjusted! ${result.scheduledSlots.length} sessions rescheduled.');
  }
}
```

### 4d. Xóa các method không còn dùng

```
_parseDayOffset()       ← XÓA
_extractLastWord()      ← XÓA
_parseDeadline()        ← XÓA (thay bằng _parseDeadlineIso)
_applyExtractedData()   ← XÓA (thay bằng _applyCollectPlanInfo)
_handleCompleteTask()   ← XÓA
_handleDeleteTask()     ← XÓA
_handleModifyTask()     ← XÓA
```

**Verify:**
- Multi-turn tạo plan hoạt động (3 lượt hội thoại)
- Shift task bằng câu tiếng Việt tự nhiên
- Delete với confirm dialog
- AdjustWorkload trigger đúng

---

## Bước 5 — Xử lý "Second-Turn" (Risk chính)

**Thời gian ước tính:** 45 phút  
**Độ phức tạp:** Trung bình

**Vấn đề:** Khi AI gọi `collect_plan_info`, OpenAI trả về `tool_calls` message không có `content` text.
AI không tự hỏi câu tiếp theo.

**Giải pháp đã chọn:** `_buildNextQuestion()` — deterministic, không tốn API call thêm (xem Bước 4c).

**Vì sao không dùng second API call:**
- Tốn thêm latency (~1s)
- Tốn thêm token
- `_buildNextQuestion()` đã cover đủ 3 trạng thái cần thiết

**Verify:** Thử flow đầy đủ:
```
User: "Tôi muốn ôn thi IELTS"
AI: CollectPlanInfoCall(goal="ôn thi IELTS") → screen hỏi "Deadline là khi nào?"
User: "Ngày 30 tháng 6"
AI: CollectPlanInfoCall(deadline="2026-06-30") → screen hỏi "Mỗi ngày bao nhiêu giờ?"
User: "2 tiếng"
AI: CollectPlanInfoCall(dailyHours=2.0) → _isReadyToPlan()=true → _handleGeneratePlan()
```

---

## Bước 6 — `chat_planner_service.dart`: Expose `findTask()`

**Thời gian ước tính:** 5 phút  
**Độ phức tạp:** Thấp

```dart
// Đổi _fuzzyFindTask thành public
Map<String, dynamic>? findTask(String name) => _fuzzyFindTask(name);
```

**Verify:** `flutter analyze` sạch.

---

## Bước 7 — Cleanup Dead Code

**Thời gian ước tính:** 30 phút  
**Độ phức tạp:** Thấp

1. Xóa `ChatResponse` class khỏi `chat_models.dart` (nếu không còn reference)
2. Xóa `ChatIntent` enum
3. Kiểm tra `ConversationPhase.executing` — xóa nếu unused
4. Chạy `flutter analyze` → fix mọi warning
5. Chạy `flutter format lib/`

---

## Bảng tổng hợp

| Bước | File | Thay đổi | Độ phức tạp | Thời gian |
|------|------|----------|-------------|-----------|
| 1 | `chat_models.dart` | Thêm `sealed class AiToolCall` | Thấp | 30 phút |
| 2 | `chat_ai_service.dart` | Thêm `_tools` constant | Thấp | 20 phút |
| 3 | `chat_ai_service.dart` | Viết lại `chat()` + parser | Cao | 90 phút |
| 4 | `chat_planner_screen.dart` | Viết lại dispatch logic | Cao | 90 phút |
| 5 | `chat_planner_screen.dart` | Second-turn handling | Trung bình | 45 phút |
| 6 | `chat_planner_service.dart` | Expose `findTask()` | Thấp | 5 phút |
| 7 | Nhiều file | Cleanup dead code | Thấp | 30 phút |
| **Total** | | | | **~5 giờ** |

---

## Risk và Cách Xử lý

| Risk | Khả năng xảy ra | Xử lý |
|------|----------------|-------|
| AI không gọi tool khi cần (false negative) | Trung bình | Fallback `TextOnlyResponse` — không crash, user thấy AI reply text |
| AI gọi sai args (type mismatch) | Thấp | `_parseToolCall()` trong try-catch → `TextOnlyResponse` |
| `collect_plan_info` gọi lại khi context đã đủ | Thấp | Flutter check `_isReadyToPlan()` → kích hoạt plan ngay |
| OpenAI thay đổi `tool_calls` format | Thấp | Wrap parse trong try-catch |

---

## Thứ tự thực hiện khuyến nghị

```
Bước 1 → Bước 2 → Bước 6   (setup, không risk)
                ↓
           Bước 3            (core AI layer)
                ↓
        Test với print log
                ↓
           Bước 4            (Flutter dispatch)
                ↓
           Bước 5            (second-turn edge case)
                ↓
           Bước 7            (cleanup)
```
