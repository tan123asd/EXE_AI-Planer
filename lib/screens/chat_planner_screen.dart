import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../models/scheduler_models.dart';
import '../services/chat_ai_service.dart';
import '../services/chat_planner_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_plan_preview_card.dart';

class ChatPlannerScreen extends StatefulWidget {
  const ChatPlannerScreen({Key? key}) : super(key: key);

  @override
  State<ChatPlannerScreen> createState() => _ChatPlannerScreenState();
}

class _ChatPlannerScreenState extends State<ChatPlannerScreen> {
  final StorageService _storage = StorageService();
  final ChatAiService _aiService = ChatAiService();
  final ChatPlannerService _plannerService = ChatPlannerService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  ConversationContext _context = ConversationContext.empty();
  bool _isLoading = false;

  // Pending plan data (set when AI generates a plan, cleared after approve/reject)
  AiTaskPlan? _pendingPlan;
  ScheduleResult? _pendingSchedule;
  // When non-null, approve updates this existing task instead of creating a new one
  String? _pendingRePlanTaskName;

  // Pending activity suggestion (MODE C: AI-suggested slots awaiting user confirmation)
  List<Map<String, dynamic>>? _pendingActivitySessions;
  String? _pendingActivityName;
  String? _pendingActivityCategory;
  int _pendingActivityDurationMinutes = 0;
  List<int>? _pendingActivityWeekdays;

  static const List<_QuickChip> _quickChips = [
    _QuickChip('Create a Plan', Icons.add_task),
    _QuickChip('Modify Task', Icons.edit_calendar),
    _QuickChip('Mark Done', Icons.check_circle_outline),
    _QuickChip('Reduce Load', Icons.self_improvement),
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadHistory() {
    final rawMessages = _storage.loadChatHistory();
    final rawContext = _storage.loadConversationContext();

    setState(() {
      _messages = rawMessages.map((m) => ChatMessage.fromJson(m)).toList();

      if (rawContext != null) {
        try {
          _context = ConversationContext.fromJson(rawContext);
        } catch (_) {
          _context = ConversationContext.empty();
        }
      }

      if (_messages.isEmpty) {
        _messages.add(ChatMessage(
          role: MessageRole.assistant,
          content:
              'Xin chào! Tôi là AI Planning Assistant 🤖\n\n'
              'Gõ "hướng dẫn" để xem cách sử dụng, hoặc bắt đầu ngay:\n'
              '• Thêm task/công việc → "thêm task ..."\n'
              '• Thêm hoạt động → "thêm hoạt động ..."\n'
              '• Hỏi tôi bất cứ điều gì về lịch của bạn!',
        ));
      }
    });
  }

  // ── Send & Dispatch ───────────────────────────────────────────────────────

  static const _helpText =
      '📖 HƯỚNG DẪN SỬ DỤNG\n\n'
      '📌 TASK (có deadline hoặc giờ cụ thể):\n'
      '  Bắt đầu bằng: "thêm task", "thêm 1 task", "thêm công việc", "thêm deadline"\n'
      '  Ví dụ: "thêm task họp nhóm 2h vào 14h ngày 26"\n'
      '  Ví dụ: "thêm task làm báo cáo cho môn học — AI sẽ gợi ý lịch trình"\n\n'
      '🏃 HOẠT ĐỘNG (sở thích/thói quen):\n'
      '  Bắt đầu bằng: "thêm hoạt động", "thêm 1 hoạt động"\n'
      '  Ví dụ: "thêm hoạt động đá bóng 1h vào 14h ngày 23"\n'
      '  Ví dụ: "thêm hoạt động đọc sách 1h mỗi ngày, AI gợi ý giờ"\n\n'
      '✏️ QUẢN LÝ:\n'
      '  "dời task [tên] sang [ngày]"\n'
      '  "xóa task [tên]" / "xóa subtask [tên]"\n'
      '  "xóa hoạt động [tên]" / "dời hoạt động [tên] X ngày"\n'
      '  "hoàn thành [tên task]"\n'
      '  "lịch hôm nay" / "lịch tuần này"';

  static final _helpPattern =
      RegExp(r'^(hướng dẫn|huong dan|help|usage|hd)$', caseSensitive: false);
  static final _confirmPattern =
      RegExp(r'^(ok|có|xác nhận|yes|đồng ý|chấp nhận|thêm đi|thêm)$', caseSensitive: false);
  static final _rejectPattern =
      RegExp(r'^(không|hủy|cancel|no|thôi|bỏ qua)$', caseSensitive: false);

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isLoading) return;

    _inputController.clear();

    // Local help command — no API call needed
    if (_helpPattern.hasMatch(trimmed)) {
      final userMsg = ChatMessage(role: MessageRole.user, content: trimmed);
      setState(() {
        _messages.add(userMsg);
        _messages.add(ChatMessage(role: MessageRole.assistant, content: _helpText));
      });
      _persistState();
      _scrollToBottom();
      return;
    }

    // Pending activity confirmation/rejection (MODE C AI-suggest)
    if (_pendingActivitySessions != null) {
      if (_confirmPattern.hasMatch(trimmed)) {
        final userMsg = ChatMessage(role: MessageRole.user, content: trimmed);
        setState(() {
          _messages.add(userMsg);
          _isLoading = true;
        });
        _scrollToBottom();
        try {
          final result = await _plannerService.saveActivitySlots(
            name: _pendingActivityName!,
            category: _pendingActivityCategory ?? 'Personal',
            durationMinutes: _pendingActivityDurationMinutes,
            sessions: _pendingActivitySessions!,
            weekdays: _pendingActivityWeekdays,
          );
          _addAiMessage(result);
        } catch (e) {
          _addAiMessage('Lỗi khi lưu hoạt động. Vui lòng thử lại.');
        } finally {
          _clearPendingActivity();
          setState(() => _isLoading = false);
          _persistState();
          _scrollToBottom();
        }
        return;
      } else if (_rejectPattern.hasMatch(trimmed)) {
        final userMsg = ChatMessage(role: MessageRole.user, content: trimmed);
        setState(() => _messages.add(userMsg));
        _clearPendingActivity();
        _addAiMessage('Đã hủy. Bạn có thể chỉ định giờ cụ thể để thêm hoạt động.');
        _persistState();
        _scrollToBottom();
        return;
      }
      // Not confirm/reject → clear pending and continue to AI
      _clearPendingActivity();
    }

    final userMsg = ChatMessage(role: MessageRole.user, content: trimmed);
    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final scheduleCtx = _buildScheduleContext();
      final toolCall = await _aiService.chat(
        trimmed,
        _context,
        _messages,
        scheduleContext: scheduleCtx,
      );
      await _dispatchToolCall(toolCall);
    } catch (e) {
      _addAiMessage(_t(
        'Something went wrong. Please check your connection and try again.',
        'Đã có lỗi xảy ra. Vui lòng kiểm tra kết nối và thử lại.',
      ));
    } finally {
      setState(() => _isLoading = false);
      _persistState();
      _scrollToBottom();
    }
  }

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

      case RePlanTaskCall(:final taskName, :final userIntent):
        await _handleRePlanTask(taskName, userIntent);

      case ShiftTaskCall(:final taskName, :final daysOffset):
        final result = await _plannerService.shiftTaskByDays(taskName, daysOffset);
        _addAiMessage(result);

      case CompleteTaskCall(:final taskName):
        final result = await _plannerService.completeTask(taskName);
        _addAiMessage(result);

      case DeleteSubtaskCall(:final subtaskName):
        final match = _plannerService.findSubtaskForDelete(subtaskName);
        if (!match.found) {
          _addAiMessage(_t(
            'Could not find a subtask matching "$subtaskName".',
            'Không tìm thấy subtask nào khớp với "$subtaskName".',
          ));
        } else {
          final confirmed = await _showDeleteSubtaskConfirm(
            subtaskName: match.sessionName,
            parentTask: match.parentTaskName,
          );
          if (confirmed == true) {
            await _plannerService.confirmDeleteSubtask(match.taskIdx, match.sessionIdx);
            _addAiMessage(_t(
              'Removed subtask "${match.sessionName}" from "${match.parentTaskName}".',
              'Đã xóa subtask "${match.sessionName}" khỏi "${match.parentTaskName}".',
            ));
          } else {
            _addAiMessage(_t(
              'Cancelled. The subtask has been kept.',
              'Đã hủy. Subtask vẫn được giữ lại.',
            ));
          }
        }

      case AddTaskDirectCall(
          :final taskName,
          :final durationMinutes,
          :final specificDate,
          :final specificStartHour,
        ):
        final result = await _plannerService.addTaskDirect(
            taskName, durationMinutes, specificDate, specificStartHour);
        _addAiMessage(result);

      case AddActivityCall():
        final (message, pendingSessions) = await _plannerService.addActivity(call);
        if (pendingSessions != null && pendingSessions.isNotEmpty) {
          _pendingActivityName = call.name;
          _pendingActivityCategory = call.category;
          _pendingActivityDurationMinutes = call.durationMinutes;
          _pendingActivityWeekdays = call.preferredWeekdays;
          _pendingActivitySessions = pendingSessions;
        }
        _addAiMessage(message);

      case ShiftActivityCall(:final activityName, :final daysOffset):
        final result = await _plannerService.shiftActivity(activityName, daysOffset);
        _addAiMessage(result);

      case DeleteActivityCall(:final activityName):
        final confirmed = await _showDeleteConfirm(activityName);
        if (confirmed == true) {
          _addAiMessage(await _plannerService.deleteActivity(activityName));
        } else {
          _addAiMessage(_t(
            'Cancelled. "$activityName" has been kept.',
            'Đã hủy. "$activityName" vẫn được giữ lại.',
          ));
        }

      case DeleteTaskCall(:final taskName):
        if (taskName == '__ALL__') {
          final confirmed = await _showDeleteAllConfirm();
          if (confirmed == true) {
            _addAiMessage(await _plannerService.deleteAllTasks());
          } else {
            _addAiMessage(_t('Understood, all tasks have been kept.', 'Được rồi, tất cả task vẫn được giữ lại.'));
          }
        } else {
          final confirmed = await _showDeleteConfirm(taskName);
          if (confirmed == true) {
            _addAiMessage(await _plannerService.deleteTask(taskName));
          } else {
            _addAiMessage(_t('Got it, "$taskName" will not be deleted.', 'Được rồi, "$taskName" sẽ không bị xóa.'));
          }
        }

      case AdjustWorkloadCall(:final taskName, :final direction):
        await _handleAdjustWorkload(taskName, direction);

      case QueryScheduleCall():
        // Schedule data is already in system prompt; AI reply arrives as TextOnlyResponse
        // on the next API response. Nothing to execute on Flutter side.
        break;
    }
  }

  void _clearPendingActivity() {
    _pendingActivitySessions = null;
    _pendingActivityName = null;
    _pendingActivityCategory = null;
    _pendingActivityDurationMinutes = 0;
    _pendingActivityWeekdays = null;
  }

  // ── Language detection ────────────────────────────────────────────────────

  bool _isVi() {
    // Check any user message in the session — "3h" or "3/6" are ASCII but the
    // user is still Vietnamese if they wrote Vietnamese earlier in the chat.
    return _messages
        .where((m) => m.role == MessageRole.user)
        .any((m) => m.content.runes.any((r) => r > 127));
  }

  String _t(String en, String vi) => _isVi() ? vi : en;

  // ── Context helpers ───────────────────────────────────────────────────────

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

  DateTime? _parseDeadlineIso(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return null;
    return DateTime(dt.year, dt.month, dt.day, 23, 59, 59);
  }

  // Deterministic follow-up question — avoids a second API call
  String _buildNextQuestion() {
    final lastUser = _messages.lastWhere(
      (m) => m.role == MessageRole.user,
      orElse: () => _messages.last,
    );
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

  // ── Plan generation ───────────────────────────────────────────────────────

  Future<void> _handleGeneratePlan() async {
    _addAiMessage(_t(
      'Great, I have everything I need. Let me generate your plan... ⚙️',
      'Tuyệt vời, tôi đã có đủ thông tin. Đang tạo kế hoạch cho bạn... ⚙️',
    ));
    setState(() => _isLoading = true);

    try {
      _context.phase = ConversationPhase.awaitingApproval;
      final result = await _plannerService.generatePlan(_context);
      _pendingPlan = result.plan;
      _pendingSchedule = result.schedule;

      final previewMsg = ChatMessage(
        role: MessageRole.assistant,
        content: _t(
          'Here\'s your plan for "${_context.goalDescription}":',
          'Đây là kế hoạch cho "${_context.goalDescription}":',
        ),
        type: ChatMessageType.planPreview,
        payload: {'planReady': true},
      );
      setState(() => _messages.add(previewMsg));
    } catch (e) {
      _context.phase = ConversationPhase.idle;
      _addAiMessage(_t(
        'I couldn\'t generate a plan right now. Please try again in a moment.',
        'Không thể tạo kế hoạch lúc này. Vui lòng thử lại sau.',
      ));
    }
  }

  // ── Re-plan remaining sessions ────────────────────────────────────────────

  Future<void> _handleRePlanTask(String taskName, String userIntent) async {
    final task = _plannerService.findTask(taskName);
    if (task == null) {
      _addAiMessage(_t(
        'Could not find a task matching "$taskName".',
        'Không tìm thấy task khớp với "$taskName".',
      ));
      return;
    }

    final name = task['name'] as String? ?? taskName;
    final sessions = task['sessions'];
    final incompleteSessions = sessions is List
        ? sessions.where((s) => (s as Map)['isCompleted'] != true).toList()
        : <dynamic>[];

    if (incompleteSessions.isEmpty) {
      _addAiMessage(_t(
        'All sessions of "$name" are already completed!',
        'Tất cả buổi học của "$name" đã hoàn thành!',
      ));
      return;
    }

    _addAiMessage(_t(
      'Analyzing remaining work for "$name" (${incompleteSessions.length} sessions left)... ⚙️',
      'Đang phân tích lại công việc còn lại của "$name" (${incompleteSessions.length} buổi chưa hoàn thành)... ⚙️',
    ));
    setState(() => _isLoading = true);

    try {
      final result = await _plannerService.rePlanTask(taskName);
      if (result == null) {
        _addAiMessage(_t(
          'Could not re-plan "$name". Please try again.',
          'Không thể lập kế hoạch lại cho "$name". Vui lòng thử lại.',
        ));
        return;
      }

      _pendingPlan = result.plan;
      _pendingSchedule = result.schedule;
      _pendingRePlanTaskName = name;

      final intentNote = userIntent == 'need_more_time'
          ? _t(
              'I\'ve rescheduled the remaining sessions into available slots.',
              'Tôi đã sắp xếp lại các buổi còn lại vào các khung giờ trống.',
            )
          : _t(
              'I\'ve optimized the schedule since the task is easier than expected.',
              'Tôi đã tối ưu lại lịch vì task dễ hơn dự kiến.',
            );

      final previewMsg = ChatMessage(
        role: MessageRole.assistant,
        content: '$intentNote\n\n${_t(
              'Here\'s the updated plan for "$name":',
              'Đây là kế hoạch cập nhật cho "$name":',
            )}',
        type: ChatMessageType.planPreview,
        payload: {'planReady': true},
      );
      setState(() => _messages.add(previewMsg));
    } catch (e) {
      _addAiMessage(_t(
        'Failed to re-plan. Please try again.',
        'Không thể lập kế hoạch lại. Vui lòng thử lại.',
      ));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Workload adjustment ───────────────────────────────────────────────────

  Future<void> _handleAdjustWorkload(String taskName, String direction) async {
    final task = _plannerService.findTask(taskName);
    if (task == null) {
      _addAiMessage(_t('Could not find a task matching "$taskName".', 'Không tìm thấy task khớp với "$taskName".'));
      return;
    }
    final multiplier = direction == 'lighter' ? 0.7 : 1.4;
    final deadline = DateTime.tryParse(task['deadline'] as String? ?? '') ??
        DateTime.now().add(const Duration(days: 7));
    final result = await _plannerService.adjustWorkload(
      task['id'] as String,
      multiplier,
      deadline,
    );
    if (result == null) {
      _addAiMessage(_t('Could not adjust workload for "$taskName".', 'Không thể điều chỉnh khối lượng cho "$taskName".'));
    } else {
      _addAiMessage(_t(
        'Workload adjusted! ${result.scheduledSlots.length} sessions rescheduled.',
        'Đã điều chỉnh khối lượng! ${result.scheduledSlots.length} buổi học đã được lên lịch lại.',
      ));
    }
  }

  // ── Plan approval ─────────────────────────────────────────────────────────

  Future<void> _approvePlan(List<ScheduledSlot> slots) async {
    if (_pendingPlan == null) return;
    setState(() => _isLoading = true);

    try {
      if (_pendingRePlanTaskName != null) {
        // Re-plan: update existing task's incomplete sessions
        await _plannerService.applyRePlan(_pendingRePlanTaskName!, slots);
        _pendingRePlanTaskName = null;
        _pendingPlan = null;
        _pendingSchedule = null;
        _addAiMessage(_t(
          '✅ Schedule updated! The remaining sessions have been rescheduled. Check the Calendar tab.',
          '✅ Lịch đã được cập nhật! Các buổi còn lại đã được sắp xếp lại. Xem tab Lịch để kiểm tra.',
        ));
      } else {
        // New plan: create new task
        final id = await _plannerService.savePlan(_pendingPlan!, slots, _context);
        _context.acceptedPlanIds.add(id);
        _context.phase = ConversationPhase.idle;
        _context.reset();
        _pendingPlan = null;
        _pendingSchedule = null;
        _addAiMessage(_t(
          '✅ Plan saved! Your schedule has been updated. Check the Calendar tab to see your sessions.',
          '✅ Kế hoạch đã được lưu! Lịch của bạn đã được cập nhật. Xem tab Lịch để thấy các buổi học.',
        ));
      }
    } catch (e) {
      _addAiMessage(_t(
        'Failed to save the plan. Please try again.',
        'Không thể lưu kế hoạch. Vui lòng thử lại.',
      ));
    } finally {
      setState(() => _isLoading = false);
      _persistState();
    }
  }

  void _rejectPlan() {
    _pendingPlan = null;
    _pendingSchedule = null;
    _pendingRePlanTaskName = null;
    _context.phase = ConversationPhase.idle;
    _context.reset();
    _addAiMessage(_t(
      'No problem! The plan has been discarded. Feel free to describe a new goal whenever you\'re ready.',
      'Không sao! Kế hoạch đã bị hủy. Hãy cho tôi biết khi bạn sẵn sàng tạo mục tiêu mới.',
    ));
    _persistState();
  }

  // ── Schedule context builder ──────────────────────────────────────────────

  String _buildScheduleContext() {
    final tasks = _storage.getCustomTasks();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String pad(int n) => n.toString().padLeft(2, '0');
    final todayStr = '${now.year}-${pad(now.month)}-${pad(now.day)}';

    final sb = StringBuffer();
    sb.writeln('Today: $todayStr');
    sb.writeln();

    if (tasks.isEmpty) {
      sb.writeln('No tasks or activities scheduled.');
      return sb.toString();
    }

    // Collect all sessions with date for date-organized view
    final allSessions = <(DateTime start, DateTime end, String name)>[];
    for (final task in tasks) {
      final sessions = task['sessions'];
      if (sessions is! List) continue;
      for (final s in sessions) {
        final m = s as Map;
        final start = DateTime.tryParse(m['startTime'] as String? ?? '');
        final end = DateTime.tryParse(m['endTime'] as String? ?? '');
        final name = m['taskName'] as String? ?? (task['name'] as String? ?? '?');
        if (start != null && end != null) allSessions.add((start, end, name));
      }
    }
    allSessions.sort((a, b) => a.$1.compareTo(b.$1));

    // Date-organized view — next 14 days (so AI can answer date-specific queries)
    const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    sb.writeln('=== Schedule by date (next 14 days) ===');
    for (int d = 0; d < 14; d++) {
      final date = today.add(Duration(days: d));
      final dateStr = '${date.year}-${pad(date.month)}-${pad(date.day)}';
      final wd = weekdayNames[date.weekday - 1];
      final daySessions = allSessions
          .where((s) => s.$1.year == date.year && s.$1.month == date.month && s.$1.day == date.day)
          .toList();
      if (daySessions.isEmpty) {
        sb.writeln('$dateStr ($wd): (free)');
      } else {
        sb.write('$dateStr ($wd):');
        for (final s in daySessions) {
          sb.write(' ${s.$3} ${pad(s.$1.hour)}:${pad(s.$1.minute)}-${pad(s.$2.hour)}:${pad(s.$2.minute)} |');
        }
        sb.writeln();
      }
    }
    sb.writeln();

    // Per-task summary
    sb.writeln('=== All tasks/activities ===');
    for (final task in tasks) {
      final name = task['name'] as String? ?? 'Unnamed';
      final deadline = task['deadline'] as String? ?? 'No deadline';
      final taskType = task['taskType'] as String? ?? 'Task';
      final sessions = task['sessions'];
      sb.write('• [$taskType] $name — deadline: $deadline');
      if (sessions is List && sessions.isNotEmpty) {
        final remaining = sessions
            .where((s) => (s as Map)['isCompleted'] != true)
            .length;
        sb.write(' | $remaining/${sessions.length} sessions remaining');
      }
      sb.writeln();
    }

    return sb.toString();
  }

  // ── State helpers ─────────────────────────────────────────────────────────

  void _addAiMessage(String content) {
    setState(() {
      _messages.add(ChatMessage(role: MessageRole.assistant, content: content));
    });
  }

  Future<void> _persistState() async {
    final raw = _messages.map((m) => m.toJson()).toList();
    await _storage.saveChatHistory(raw);
    await _storage.saveConversationContext(_context.toJson());
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<bool?> _showDeleteAllConfirm() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Tasks'),
        content: const Text(
            'This will permanently delete ALL tasks and their schedules. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteConfirm(String taskName) {
    final task = _plannerService.findTask(taskName);
    final sessions = task?['sessions'];
    final subtaskCount = sessions is List ? sessions.length : 0;
    final subtaskNote = subtaskCount > 0
        ? '\n\nThis will also delete $subtaskCount subtask${subtaskCount > 1 ? 's' : ''}.'
        : '';
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "$taskName"?$subtaskNote'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteSubtaskConfirm({
    required String subtaskName,
    required String parentTask,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa subtask'),
        content: Text('Bạn có chắc muốn xóa subtask "$subtaskName" khỏi task "$parentTask"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Planner',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text('Your smart scheduling assistant', style: AppTextStyles.caption),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined,
                color: AppColors.textSecondary, size: 22),
            tooltip: 'Clear chat',
            onPressed: _confirmClearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          if (_isLoading) _buildTypingIndicator(),
          _buildQuickChips(),
          _buildInputRow(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) {
        final msg = _messages[i];
        if (msg.type == ChatMessageType.planPreview &&
            msg.role == MessageRole.assistant &&
            _pendingPlan != null &&
            _pendingSchedule != null) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ChatPlanPreviewCard(
              goalName: _context.goalDescription ?? 'Your Plan',
              plan: _pendingPlan!,
              schedule: _pendingSchedule!,
              onApprove: _approvePlan,
              onReject: _rejectPlan,
            ),
          );
        }
        return ChatMessageBubble(message: msg);
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 0, 4),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          _TypingDots(),
        ],
      ),
    );
  }

  Widget _buildQuickChips() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: _quickChips.map((chip) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _sendMessage(chip.label),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  boxShadow: AppShadows.card,
                ),
                child: Row(
                  children: [
                    Icon(chip.icon, size: 14, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Text(
                      chip.label,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInputRow() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: _sendMessage,
              decoration: InputDecoration(
                hintText: 'Tell me your goal or ask anything...',
                hintStyle: AppTextStyles.bodySecondary,
                filled: true,
                fillColor: AppColors.background,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _sendMessage(_inputController.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('This will clear all chat history and reset the context.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _storage.clearChatHistory();
      setState(() {
        _messages.clear();
        _context = ConversationContext.empty();
        _pendingPlan = null;
        _pendingSchedule = null;
        _messages.add(ChatMessage(
          role: MessageRole.assistant,
          content:
              "Chat cleared! I'm ready to help you plan your next goal. What would you like to accomplish?",
        ));
      });
    }
  }
}

// ── Quick chip data class ─────────────────────────────────────────────────

class _QuickChip {
  final String label;
  final IconData icon;
  const _QuickChip(this.label, this.icon);
}

// ── Animated typing indicator ─────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final delay = i * 0.33;
              final t = (_controller.value - delay).clamp(0.0, 1.0);
              final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.3, 1.0);
              return Container(
                width: 6,
                height: 6,
                margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(opacity),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
