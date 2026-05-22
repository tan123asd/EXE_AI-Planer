import 'dart:math';
import 'scheduler_models.dart';

String _generateId() {
  final rand = Random().nextInt(999999).toString().padLeft(6, '0');
  return '${DateTime.now().millisecondsSinceEpoch}_$rand';
}

enum MessageRole { user, assistant }

enum ChatIntent {
  createPlan,
  modifyTask,
  completeTask,
  deleteTask,
  adjustWorkload,
  expandTask,
  querySchedule,
  general,
}

enum ConversationPhase {
  idle,
  collectingContext,
  awaitingApproval,
  executing,
}

enum ChatMessageType {
  text,
  planPreview,
  actionResult,
}

class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final ChatMessageType type;
  final Map<String, dynamic>? payload;

  ChatMessage({
    String? id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.type = ChatMessageType.text,
    this.payload,
  })  : id = id ?? _generateId(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'type': type.name,
        'payload': payload,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        role: MessageRole.values.firstWhere(
          (r) => r.name == json['role'],
          orElse: () => MessageRole.assistant,
        ),
        content: json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        type: ChatMessageType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => ChatMessageType.text,
        ),
        payload: json['payload'] != null
            ? Map<String, dynamic>.from(json['payload'] as Map)
            : null,
      );
}

class ConversationContext {
  String? goalDescription;
  String? taskDetails;
  DateTime? parsedDeadline;
  int? dailyAvailableHours;
  String? projectType;
  String? additionalNotes;
  ConversationPhase phase;
  List<Map<String, dynamic>>? pendingSubtasks;
  ScheduleResult? pendingScheduleResult;
  AiTaskPlan? pendingAiTaskPlan;
  String? pendingModificationRequest;
  List<String> acceptedPlanIds;
  Map<String, List<String>> dependencyGraph;

  ConversationContext({
    this.goalDescription,
    this.taskDetails,
    this.parsedDeadline,
    this.dailyAvailableHours,
    this.projectType,
    this.additionalNotes,
    this.phase = ConversationPhase.idle,
    this.pendingSubtasks,
    this.pendingScheduleResult,
    this.pendingAiTaskPlan,
    this.pendingModificationRequest,
    List<String>? acceptedPlanIds,
    Map<String, List<String>>? dependencyGraph,
  })  : acceptedPlanIds = acceptedPlanIds ?? [],
        dependencyGraph = dependencyGraph ?? {};

  void reset() {
    goalDescription = null;
    taskDetails = null;
    parsedDeadline = null;
    dailyAvailableHours = null;
    projectType = null;
    additionalNotes = null;
    phase = ConversationPhase.idle;
    pendingSubtasks = null;
    pendingScheduleResult = null;
    pendingAiTaskPlan = null;
    pendingModificationRequest = null;
  }

  Map<String, dynamic> toJson() => {
        'goalDescription': goalDescription,
        'taskDetails': taskDetails,
        'parsedDeadline': parsedDeadline?.toIso8601String(),
        'dailyAvailableHours': dailyAvailableHours,
        'projectType': projectType,
        'additionalNotes': additionalNotes,
        'phase': phase.name,
        'acceptedPlanIds': acceptedPlanIds,
        'dependencyGraph': dependencyGraph.map(
          (k, v) => MapEntry(k, v),
        ),
      };

  factory ConversationContext.fromJson(Map<String, dynamic> json) {
    final graphRaw = json['dependencyGraph'] as Map<String, dynamic>?;
    final graph = <String, List<String>>{};
    if (graphRaw != null) {
      for (final entry in graphRaw.entries) {
        graph[entry.key] = List<String>.from(entry.value as List);
      }
    }
    return ConversationContext(
      goalDescription: json['goalDescription'] as String?,
      taskDetails: json['taskDetails'] as String?,
      parsedDeadline: json['parsedDeadline'] != null
          ? DateTime.parse(json['parsedDeadline'] as String)
          : null,
      dailyAvailableHours: json['dailyAvailableHours'] as int?,
      projectType: json['projectType'] as String?,
      additionalNotes: json['additionalNotes'] as String?,
      phase: ConversationPhase.values.firstWhere(
        (p) => p.name == json['phase'],
        orElse: () => ConversationPhase.idle,
      ),
      acceptedPlanIds: List<String>.from(
          (json['acceptedPlanIds'] as List<dynamic>?) ?? []),
      dependencyGraph: graph,
    );
  }

  factory ConversationContext.empty() => ConversationContext();
}

class ChatResponse {
  final ChatIntent intent;
  final String content;
  final List<String> missingFields;
  final bool readyToPlan;
  final Map<String, dynamic> extractedData;

  const ChatResponse({
    required this.intent,
    required this.content,
    required this.missingFields,
    required this.readyToPlan,
    required this.extractedData,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    final intentStr = json['intent'] as String? ?? 'general';
    ChatIntent intent;
    switch (intentStr) {
      case 'createPlan':
        intent = ChatIntent.createPlan;
        break;
      case 'modifyTask':
        intent = ChatIntent.modifyTask;
        break;
      case 'completeTask':
        intent = ChatIntent.completeTask;
        break;
      case 'deleteTask':
        intent = ChatIntent.deleteTask;
        break;
      case 'adjustWorkload':
        intent = ChatIntent.adjustWorkload;
        break;
      case 'expandTask':
        intent = ChatIntent.expandTask;
        break;
      case 'querySchedule':
        intent = ChatIntent.querySchedule;
        break;
      default:
        intent = ChatIntent.general;
    }
    return ChatResponse(
      intent: intent,
      content: json['content'] as String? ?? '',
      missingFields: List<String>.from(
          (json['missingFields'] as List<dynamic>?) ?? []),
      readyToPlan: json['readyToPlan'] as bool? ?? false,
      extractedData: Map<String, dynamic>.from(
          (json['extractedData'] as Map<dynamic, dynamic>?) ?? {}),
    );
  }

  factory ChatResponse.error(String message) => ChatResponse(
        intent: ChatIntent.general,
        content: message,
        missingFields: [],
        readyToPlan: false,
        extractedData: {},
      );
}

// ── Tool Call sealed classes (Function Calling) ───────────────────────────

sealed class AiToolCall {}

class CollectPlanInfoCall extends AiToolCall {
  final String? goal;
  final String? deadline;
  final double? dailyHours;
  final String? taskDetails;
  final String? projectType;
  CollectPlanInfoCall({this.goal, this.deadline, this.dailyHours, this.taskDetails, this.projectType});
}

class ShiftTaskCall extends AiToolCall {
  final String taskName;
  final int daysOffset;
  final String confidence; // 'high' | 'medium' | 'low'
  final String? clarificationNeeded;
  ShiftTaskCall({
    required this.taskName,
    required this.daysOffset,
    this.confidence = 'high',
    this.clarificationNeeded,
  });
}

class CompleteTaskCall extends AiToolCall {
  final String taskName;
  CompleteTaskCall({required this.taskName});
}

class DeleteTaskCall extends AiToolCall {
  final String taskName;
  DeleteTaskCall({required this.taskName});
}

class AdjustWorkloadCall extends AiToolCall {
  final String taskName;
  final String direction;
  final String confidence; // 'high' | 'medium' | 'low'
  final String? clarificationNeeded;
  AdjustWorkloadCall({
    required this.taskName,
    required this.direction,
    this.confidence = 'high',
    this.clarificationNeeded,
  });
}

class QueryScheduleCall extends AiToolCall {
  final String timeRange;
  QueryScheduleCall({required this.timeRange});
}

class RePlanTaskCall extends AiToolCall {
  final String taskName;
  final String userIntent; // 'need_more_time' | 'task_is_easier'
  final String confidence; // 'high' | 'medium' | 'low'
  final String? clarificationNeeded;
  RePlanTaskCall({
    required this.taskName,
    required this.userIntent,
    this.confidence = 'high',
    this.clarificationNeeded,
  });
}

class DeleteSubtaskCall extends AiToolCall {
  final String subtaskName;
  DeleteSubtaskCall({required this.subtaskName});
}

class AddActivityCall extends AiToolCall {
  final String name;
  final int durationMinutes;
  final List<int>? preferredWeekdays;
  final String? specificDate;
  final int? specificStartHour;
  final String category;
  AddActivityCall({
    required this.name,
    required this.durationMinutes,
    this.preferredWeekdays,
    this.specificDate,
    this.specificStartHour,
    this.category = 'Personal',
  });
}

class ShiftActivityCall extends AiToolCall {
  final String activityName;
  final int daysOffset;
  ShiftActivityCall({required this.activityName, required this.daysOffset});
}

class DeleteActivityCall extends AiToolCall {
  final String activityName;
  DeleteActivityCall({required this.activityName});
}

class AddTaskDirectCall extends AiToolCall {
  final String taskName;
  final int durationMinutes;
  final String specificDate;
  final int specificStartHour;
  final String confidence; // 'high' | 'medium' | 'low'
  final String? clarificationNeeded;
  AddTaskDirectCall({
    required this.taskName,
    required this.durationMinutes,
    required this.specificDate,
    required this.specificStartHour,
    this.confidence = 'high',
    this.clarificationNeeded,
  });
}

class TextOnlyResponse extends AiToolCall {
  final String content;
  TextOnlyResponse({required this.content});
}
