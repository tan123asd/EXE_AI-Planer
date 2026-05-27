import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_models.dart';

class ContextCompressor {
  static const _endpoint = 'https://api.openai.com/v1/chat/completions';
  static const _triggerThreshold = 30;
  static const _keepRecent = 10;

  /// Returns a compressed history when length exceeds threshold.
  /// Falls back to the 10 most recent messages on API failure.
  Future<List<ChatMessage>> maybeCompress(
      List<ChatMessage> history, String apiKey) async {
    if (history.length <= _triggerThreshold || apiKey.isEmpty) return history;

    final toSummarize = history.sublist(0, history.length - _keepRecent);
    final recent = history.sublist(history.length - _keepRecent);

    final summary = await _summarize(toSummarize, apiKey);
    if (summary == null) return recent;

    return [
      ChatMessage(
        role: MessageRole.assistant,
        content: '[Tóm tắt cuộc trò chuyện trước: $summary]',
      ),
      ...recent,
    ];
  }

  Future<String?> _summarize(List<ChatMessage> messages, String apiKey) async {
    final conversationText = messages
        .map((m) => '${m.role.name.toUpperCase()}: ${m.content}')
        .join('\n');

    final body = jsonEncode({
      'model': 'gpt-4o-mini',
      'temperature': 0.2,
      'max_tokens': 150,
      'messages': [
        {
          'role': 'system',
          'content':
              'Summarize this planning conversation in 2-3 bullet points. '
              'Keep: tasks created/deleted, actions taken, user preferences stated. '
              'Skip: greetings, simple confirmations. '
              'Reply in the same language as the conversation. Be very concise.',
        },
        {'role': 'user', 'content': conversationText},
      ],
    });

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final outer = jsonDecode(response.body) as Map<String, dynamic>;
      return (outer['choices'] as List).first['message']['content'] as String?;
    } catch (_) {
      return null;
    }
  }
}
