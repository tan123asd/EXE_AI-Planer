import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/scheduler_models.dart';

class AiServiceException implements Exception {
  final String message;
  AiServiceException(this.message);
  @override
  String toString() => 'AiServiceException: $message';
}

const _systemPrompt = '''
You are an expert student task planner. Your job is to decompose a study or personal goal into concrete, actionable subtasks for a student\'s schedule.

## Output Format
Return ONLY a valid JSON object with this exact structure — no explanation, no markdown, no extra keys:
{
  "tasks": [
    {
      "order": <int, starts at 1>,
      "name": "<string, specific action verb + object, e.g. \'Read chapter 3-4\', \'Write introduction draft\'>",
      "duration": <float, total hours needed, one of: 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0>,
      "focus_level": "<\'high\' | \'medium\' | \'low\'>",
      "min_block": <float, minimum continuous hours per session, must satisfy: duration % min_block == 0 and min_block <= duration>,
      "preferred_time": "<\'high_focus\' | \'low_focus\' | \'flexible\'>"
    }
  ],
  "was_repaired": false,
  "constraint_violations": []
}

## Field Rules

### duration (total hours)
- Allowed values ONLY: 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0
- Represents total time needed for this subtask

### min_block (minimum session length)
- CRITICAL CONSTRAINT: duration % min_block MUST equal 0 (min_block divides duration evenly)
- Allowed values ONLY: 0.5, 1.0, 1.5, 2.0
- min_block <= duration always
- Valid pairs: (0.5,0.5), (1.0,0.5), (1.0,1.0), (1.5,0.5), (1.5,1.5), (2.0,0.5), (2.0,1.0), (2.0,2.0), (2.5,0.5), (3.0,0.5), (3.0,1.0), (3.0,1.5), (4.0,0.5), (4.0,1.0), (4.0,2.0)
- Invalid pairs (NEVER use): (1.5,1.0), (2.5,1.0), (2.5,1.5), (2.5,2.0), (3.5,1.0)

### focus_level
- "high": requires deep concentration (math, coding, writing, memorization)
- "medium": moderate attention (reading, review, light problem sets)
- "low": low cognitive load (organizing notes, formatting, simple review)

### preferred_time
- "high_focus": schedule during user\'s peak productivity hours (morning/evening)
- "low_focus": schedule during off-peak hours (afternoon)
- "flexible": no preference

## Planning Rules
1. Produce 3 to 8 subtasks (never fewer, never more)
2. Order subtasks logically: foundational tasks first, synthesis/review last
3. High-priority goals → shorter min_block (more scheduling flexibility)
4. Hard deadlines < 2 days → prefer smaller duration subtasks (0.5–1.5h) for urgency
5. Each subtask name must be a specific, actionable phrase (not generic like "Study" or "Work on it")
6. Subtask total duration should reflect the goal\'s actual complexity relative to the deadline gap
7. Never include "break" as a subtask — breaks are handled by the scheduling system

## Examples

Goal: "Complete data structures assignment", Priority: high, 3 days to deadline
Tasks: Review linked list theory (1.0h, high, 0.5), Implement Node class (1.5h, high, 0.5), Implement LinkedList methods (2.0h, high, 1.0), Write test cases (1.0h, medium, 0.5), Debug and finalize (1.0h, high, 0.5)

Goal: "Prepare for English presentation", Priority: medium, 5 days to deadline
Tasks: Research topic and gather sources (1.5h, medium, 0.5), Create outline and script (2.0h, high, 1.0), Design slides (1.5h, medium, 0.5), Practice delivery alone (1.0h, medium, 1.0), Rehearse with timer (1.0h, medium, 1.0)
''';

class AiService {
  static const _apiKey = String.fromEnvironment('OPENAI_API_KEY');
  static const _endpoint = 'https://api.openai.com/v1/chat/completions';

  static String _formatDatetime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year.toString().padLeft(4, '0')}'
        '-${local.month.toString().padLeft(2, '0')}'
        '-${local.day.toString().padLeft(2, '0')}'
        'T${local.hour.toString().padLeft(2, '0')}'
        ':${local.minute.toString().padLeft(2, '0')}'
        ':${local.second.toString().padLeft(2, '0')}';
  }

  Future<AiTaskPlan> generateTaskPlan({
    required String taskName,
    required String notes,
    required String difficulty,
    required String category,
    required DateTime deadline,
    required String priority,
    String language = 'English',
  }) async {
    if (_apiKey.isEmpty) {
      throw AiServiceException(
        'OPENAI_API_KEY is not set. Build with --dart-define=OPENAI_API_KEY=<key>.',
      );
    }

    final userMessage = 'Goal: $taskName\n'
        'Description: ${notes.isNotEmpty ? notes : taskName}\n'
        'Priority: $priority\n'
        'Current time: ${_formatDatetime(DateTime.now())}\n'
        'Deadline: ${_formatDatetime(deadline)}\n'
        'IMPORTANT: Write ALL subtask names in $language. Do not use any other language.';

    final body = jsonEncode({
      'model': 'gpt-4o-mini',
      'temperature': 0.3,
      'response_format': {'type': 'json_object'},
      'messages': [
        {'role': 'system', 'content': _systemPrompt},
        {'role': 'user', 'content': userMessage},
      ],
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
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      throw AiServiceException('Network error: $e');
    }

    if (response.statusCode != 200) {
      throw AiServiceException(
        'OpenAI API returned ${response.statusCode}: ${response.body}',
      );
    }

    final String content;
    try {
      final outer = jsonDecode(response.body) as Map<String, dynamic>;
      content = (outer['choices'] as List).first['message']['content'] as String;
    } catch (e) {
      throw AiServiceException('Failed to parse OpenAI response envelope: $e');
    }

    final Map<String, dynamic> responseMap;
    try {
      responseMap = jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      throw AiServiceException('Failed to parse task plan JSON: $e');
    }

    responseMap['created_at'] ??= DateTime.now().toIso8601String();
    responseMap['deadline'] ??= deadline.toIso8601String();
    responseMap['priority'] ??= priority;

    try {
      return AiTaskPlan.fromMap(responseMap);
    } catch (e) {
      throw AiServiceException('Invalid task plan structure from API: $e');
    }
  }
}
