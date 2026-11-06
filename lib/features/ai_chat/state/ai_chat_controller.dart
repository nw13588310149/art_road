import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_chat_repository.dart';
import '../data/ai_chat_socket_service.dart';
import 'ai_chat_socket_dispatcher.dart';
import 'ai_chat_state.dart';

final aiChatControllerProvider =
    StateNotifierProvider<AiChatController, AiChatState>((ref) {
      final repository = ref.watch(aiChatRepositoryProvider);
      final dispatcher = ref.watch(aiChatSocketDispatcherProvider);
      final controller = AiChatController(
        repository: repository,
        dispatcher: dispatcher,
      );
      ref.onDispose(controller.detachSocketHandler);
      return controller;
    });

class AiChatController extends StateNotifier<AiChatState> {
  AiChatController({
    required AiChatRepository repository,
    required AiChatSocketDispatcher dispatcher,
  }) : _dispatcher = dispatcher,
       _repository = repository,
       super(const AiChatState()) {
    _dispatcher.setHandler(_handleSocketEvent);
    unawaited(_loadInitial());
  }

  final AiChatSocketDispatcher _dispatcher;
  final AiChatRepository _repository;
  Timer? _streamFallbackTimer;
  String? _streamingMessageId;
  String? _streamTargetSessionId;
  String? _streamCorrelationReplyId;
  bool _streamUsesReasoningUi = false;
  String? _sessionsOwnerUserId;

  @override
  void dispose() {
    detachSocketHandler();
    _clearStreamTimers();
    super.dispose();
  }

  void detachSocketHandler() {
    _dispatcher.clearHandler(_handleSocketEvent);
  }

  Future<void> _loadInitial() async {
    await loadSessions(autoSelectFirst: false);
  }

  /// 账号切换后强制清空本地缓存并重新拉取会话列表。
  Future<void> refreshSessionsForAccountChange() async {
    _cancelAiStream(removeStreamingMessage: true);
    state = state.copyWith(
      clearActiveSessionId: true,
      sessions: const [],
      messages: const [],
      pendingAttachments: const [],
      isNewConversation: true,
      waitingAssistant: false,
      sending: false,
      messagesLoading: false,
      sessionsLoading: true,
    );
    await loadSessions(autoSelectFirst: false);
  }

  /// 当前登录用户与会话缓存归属不一致时触发强制刷新。
  void syncSessionsWithCurrentUser(String userId) {
    if (userId.isEmpty) {
      return;
    }
    if (_sessionsOwnerUserId == userId) {
      return;
    }
    final previousOwner = _sessionsOwnerUserId;
    _sessionsOwnerUserId = userId;
    if (previousOwner != null && previousOwner != userId) {
      unawaited(refreshSessionsForAccountChange());
    }
  }

  void toggleSidebar() {
    state = state.copyWith(sidebarCollapsed: !state.sidebarCollapsed);
  }

  void toggleDeepThinking() {
    if (!state.selectedModel.supportsDeepThinking) {
      return;
    }
    state = state.copyWith(isDeepThinking: !state.isDeepThinking);
  }

  void toggleWebSearching() {
    if (!state.selectedModel.supportsWebSearch) {
      return;
    }
    state = state.copyWith(isWebSearching: !state.isWebSearching);
  }

  Future<String?> selectModel(AiChatModel model) async {
    if (model == state.selectedModel || state.sending) {
      return null;
    }
    _cancelAiStream(removeStreamingMessage: true);
    state = state.copyWith(
      selectedModel: model,
      isDeepThinking: model.supportsDeepThinking && state.isDeepThinking,
      isWebSearching: model.supportsWebSearch && state.isWebSearching,
      clearActiveSessionId: true,
      sessions: const [],
      messages: const [],
      pendingAttachments: const [],
      isNewConversation: true,
      waitingAssistant: false,
      sending: false,
      messagesLoading: false,
    );
    return loadSessions(autoSelectFirst: false);
  }

  void toggleReasoningExpanded(String messageId) {
    final next = state.messages.map((message) {
      if (message.id != messageId) {
        return message;
      }
      return message.copyWith(reasoningExpanded: !message.reasoningExpanded);
    }).toList();
    state = state.copyWith(messages: next);
  }

  Future<String?> loadSessions({bool autoSelectFirst = false}) async {
    state = state.copyWith(sessionsLoading: true);
    try {
      final response = await _repository.getSessionList();
      if (!response.isSuccess) {
        state = state.copyWith(sessionsLoading: false);
        return response.displayMsg;
      }

      final sessions = _normalizeSessionList(response.data);
      final sorted = _sortSessions(sessions);
      final activeExists = sorted.any(
        (item) => item.id == state.activeSessionId,
      );
      state = state.copyWith(
        sessionsLoading: false,
        sessions: sorted,
        activeSessionId: activeExists ? state.activeSessionId : null,
        clearActiveSessionId: !activeExists && state.activeSessionId != null,
      );

      if (autoSelectFirst &&
          state.activeSessionId == null &&
          sorted.isNotEmpty) {
        return selectSession(sorted.first.id);
      }
      return null;
    } catch (_) {
      state = state.copyWith(sessionsLoading: false);
      return '加载会话列表失败';
    }
  }

  Future<String?> selectSession(String sessionId) async {
    _cancelAiStream(removeStreamingMessage: true);
    state = state.copyWith(
      activeSessionId: sessionId,
      waitingAssistant: false,
      pendingAttachments: const [],
    );
    return _fetchMessages(sessionId, showLoading: true);
  }

  void startNewChat() {
    _cancelAiStream(removeStreamingMessage: true);
    state = state.copyWith(
      clearActiveSessionId: true,
      messages: const [],
      pendingAttachments: const [],
      isNewConversation: true,
      waitingAssistant: false,
      sending: false,
      messagesLoading: false,
    );
  }

  Future<String?> uploadAttachment({
    required List<int> bytes,
    required String filename,
    required int size,
  }) async {
    if (state.uploadingAttachment) {
      return null;
    }
    if (state.pendingAttachments.length >= 3) {
      return '最多添加 3 个附件';
    }
    const maxBytes = 30 * 1024 * 1024;
    if (size > maxBytes) {
      return '附件不能超过 30MB';
    }

    state = state.copyWith(uploadingAttachment: true);
    try {
      final response = await _repository.uploadAttachment(
        bytes: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
        filename: filename,
      );
      if (!response.isSuccess) {
        state = state.copyWith(uploadingAttachment: false);
        return response.displayMsg;
      }
      final url = _extractAttachmentUrl(response.data);
      if (url.isEmpty) {
        state = state.copyWith(uploadingAttachment: false);
        return '附件上传结果异常';
      }
      final attachment = AiChatAttachment(name: filename, url: url, size: size);
      state = state.copyWith(
        uploadingAttachment: false,
        pendingAttachments: [...state.pendingAttachments, attachment],
      );
      return null;
    } catch (_) {
      state = state.copyWith(uploadingAttachment: false);
      return '';
    }
  }

  void removePendingAttachment(AiChatAttachment attachment) {
    state = state.copyWith(
      pendingAttachments: state.pendingAttachments
          .where((item) => item.url != attachment.url)
          .toList(),
    );
  }

  Future<String?> deleteSession(AiChatSession session) async {
    try {
      final response = await _repository.deleteSession(session.id);
      if (!response.isSuccess) {
        return response.displayMsg;
      }

      final nextSessions = state.sessions
          .where((item) => item.id != session.id)
          .toList();

      if (state.activeSessionId == session.id) {
        state = state.copyWith(
          sessions: nextSessions,
          clearActiveSessionId: true,
          messages: const [],
          pendingAttachments: const [],
          isNewConversation: true,
          waitingAssistant: false,
          sending: false,
        );
        return null;
      }

      state = state.copyWith(sessions: nextSessions);
      return null;
    } catch (_) {
      return '删除会话失败';
    }
  }

  Future<String?> sendMessage(String rawText) async {
    final text = rawText.trim();
    final attachments = List<AiChatAttachment>.from(state.pendingAttachments);
    if ((text.isEmpty && attachments.isEmpty) || state.sending) {
      return null;
    }
    final visibleText = text.isEmpty ? '请根据附件内容进行分析。' : text;
    final requestContent = _buildContentWithAttachments(
      visibleText,
      attachments,
    );

    final pendingId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final pendingMessage = AiChatMessage(
      id: pendingId,
      type: AiChatMessageType.user,
      text: visibleText,
      status: AiChatMessageStatus.sending,
      attachments: attachments,
      sortTime: DateTime.now(),
    );
    state = state.copyWith(
      isNewConversation: false,
      waitingAssistant: true,
      sending: true,
      pendingAttachments: const [],
      messages: [...state.messages, pendingMessage],
    );

    try {
      var sessionId = state.activeSessionId;
      if (sessionId == null) {
        final title = _titleFromFirstUserMessage(visibleText);
        final createResponse = await _repository.createSession(
          title: title,
          robot: state.selectedModel.robot,
        );
        if (!createResponse.isSuccess) {
          _setPendingMessageStatus(pendingId, AiChatMessageStatus.failed);
          state = state.copyWith(waitingAssistant: false, sending: false);
          return createResponse.displayMsg;
        }

        final createdSessionId = _extractSessionId(createResponse.data);
        if (createdSessionId == null) {
          _setPendingMessageStatus(pendingId, AiChatMessageStatus.failed);
          state = state.copyWith(waitingAssistant: false, sending: false);
          return '创建会话失败，未返回会话 ID';
        }

        sessionId = createdSessionId;
        final createdSession = AiChatSession(
          id: sessionId,
          title: title,
          sortTime: DateTime.now(),
        );
        final nextSessions = _sortSessions([
          createdSession,
          ...state.sessions.where((item) => item.id != sessionId),
        ]);

        state = state.copyWith(
          activeSessionId: sessionId,
          sessions: nextSessions,
        );
      }

      _beginAiStream(
        sessionId: sessionId,
        useReasoningUi: state.isDeepThinking,
      );
      final sendResponse = await _repository.sendMessage(
        sessionId: sessionId,
        content: requestContent,
        isDeep: state.isDeepThinking,
        isNet: state.isWebSearching,
        model: state.selectedModel.requestModel,
        systemPrompt: _assistantSystemRule(),
        attachments: attachments.map((item) => item.toJson()).toList(),
      );

      if (!sendResponse.isSuccess) {
        _setPendingMessageStatus(pendingId, AiChatMessageStatus.failed);
        _cancelAiStream(removeStreamingMessage: true);
        state = state.copyWith(waitingAssistant: false, sending: false);
        return sendResponse.displayMsg;
      }

      _setPendingMessageStatus(pendingId, AiChatMessageStatus.sent);
      state = state.copyWith(sending: false);
      return null;
    } catch (_) {
      _setPendingMessageStatus(pendingId, AiChatMessageStatus.failed);
      _cancelAiStream(removeStreamingMessage: true);
      state = state.copyWith(waitingAssistant: false, sending: false);
      return '发送失败，请检查网络连接';
    }
  }

  Future<String?> resendMessage(AiChatMessage message) async {
    if (message.type != AiChatMessageType.user) {
      return null;
    }
    if (state.sending || state.activeSessionId == null) {
      return null;
    }

    final text = message.text.trim();
    final attachments = message.attachments;
    if (text.isEmpty && attachments.isEmpty) {
      return null;
    }
    final requestContent = _buildContentWithAttachments(
      text.isEmpty ? '请根据附件内容进行分析。' : text,
      attachments,
    );

    _setPendingMessageStatus(message.id, AiChatMessageStatus.sending);
    state = state.copyWith(
      waitingAssistant: true,
      sending: true,
      isNewConversation: false,
    );

    try {
      _beginAiStream(
        sessionId: state.activeSessionId!,
        useReasoningUi: state.isDeepThinking,
      );
      final sendResponse = await _repository.sendMessage(
        sessionId: state.activeSessionId!,
        content: requestContent,
        isDeep: state.isDeepThinking,
        isNet: state.isWebSearching,
        model: state.selectedModel.requestModel,
        systemPrompt: _assistantSystemRule(),
        attachments: attachments.map((item) => item.toJson()).toList(),
      );
      if (!sendResponse.isSuccess) {
        _setPendingMessageStatus(message.id, AiChatMessageStatus.failed);
        _cancelAiStream(removeStreamingMessage: true);
        state = state.copyWith(waitingAssistant: false, sending: false);
        return sendResponse.displayMsg;
      }

      _setPendingMessageStatus(message.id, AiChatMessageStatus.sent);
      state = state.copyWith(sending: false);
      return null;
    } catch (_) {
      _setPendingMessageStatus(message.id, AiChatMessageStatus.failed);
      _cancelAiStream(removeStreamingMessage: true);
      state = state.copyWith(waitingAssistant: false, sending: false);
      return '重新发送失败';
    }
  }

  void _beginAiStream({
    required String sessionId,
    required bool useReasoningUi,
  }) {
    _cancelAiStream(removeStreamingMessage: true);
    final streamId = 'ai-stream-${DateTime.now().microsecondsSinceEpoch}';
    _streamingMessageId = streamId;
    _streamTargetSessionId = sessionId;
    _streamCorrelationReplyId = null;
    _streamUsesReasoningUi = useReasoningUi;
    final streamMessage = AiChatMessage(
      id: streamId,
      type: AiChatMessageType.ai,
      text: '',
      reasoning: '',
      reasoningExpanded: true,
      streaming: true,
      reasoningStreaming: useReasoningUi,
      sortTime: DateTime.now(),
    );
    state = state.copyWith(
      waitingAssistant: true,
      messages: [...state.messages, streamMessage],
    );
    _resetStreamFallbackTimer();
  }

  void _handleSocketEvent(AiChatSocketEvent event) {
    if (!mounted) {
      return;
    }
    _reopenStreamIfNeeded(event.payload);
    if (_streamingMessageId == null) {
      return;
    }
    if (event.type == AiChatSocketEventType.stream) {
      _onWsChatGptStream(event.payload);
    } else if (event.type == AiChatSocketEventType.full) {
      if (_shouldTreatFullPayloadAsStreamChunk(event.payload)) {
        _onWsChatGptStream(event.payload);
        return;
      }
      _onWsChatGptFull(event.payload);
    }
  }

  /// 流式被误结束后，若同一轮回复仍有 WS 分片到达，则恢复 streaming 上下文。
  void _reopenStreamIfNeeded(Map<String, dynamic> json) {
    if (_streamingMessageId != null) {
      return;
    }
    if (!state.waitingAssistant) {
      return;
    }
    if (!_payloadBelongsToActiveStream(json)) {
      return;
    }
    final streamMsg = state.messages
        .where(
          (item) =>
              item.type == AiChatMessageType.ai &&
              item.id.startsWith('ai-stream-'),
        )
        .lastOrNull;
    if (streamMsg == null) {
      return;
    }
    _streamingMessageId = streamMsg.id;
    _streamTargetSessionId ??= state.activeSessionId;
    _updateMessageById(
      streamMsg.id,
      (current) => current.copyWith(
        streaming: true,
        reasoningStreaming: _streamUsesReasoningUi && current.text.isEmpty,
      ),
    );
    _resetStreamFallbackTimer();
  }

  /// 全局 WS 偶发把 type=1/10014 流式分片归到 full 分支时的兜底。
  bool _shouldTreatFullPayloadAsStreamChunk(Map<String, dynamic> json) {
    if (_streamingMessageId == null) {
      return false;
    }
    final type = _wsNumericType(json);
    if (type == 10005) {
      return false;
    }
    if (type == 1 ||
        type == 0 ||
        type == 10004 ||
        type == 10013 ||
        type == 10014) {
      return true;
    }
    final delta = _extractStreamDelta(json);
    final reasoningDelta = _extractReasoningStreamDelta(json);
    return delta.isNotEmpty || reasoningDelta.isNotEmpty;
  }

  void _onWsChatGptStream(Map<String, dynamic> json) {
    if (!_matchesStreamSession(json)) {
      return;
    }
    final replyId = _readString(json['replyId']);
    if (replyId.isNotEmpty && _streamCorrelationReplyId == null) {
      _streamCorrelationReplyId = replyId;
    }

    var delta = _extractStreamDelta(json);
    var reasoningDelta = _extractReasoningStreamDelta(json);
    final type = _wsNumericType(json);
    if (_streamUsesReasoningUi &&
        (type == 1 || type == 10014) &&
        delta.isNotEmpty &&
        reasoningDelta.isEmpty) {
      reasoningDelta = delta;
      delta = '';
    }
    if (delta.isEmpty && reasoningDelta.isEmpty) {
      return;
    }
    _applyStreamChunk(delta, reasoningDelta);
    _resetStreamFallbackTimer();
  }

  void _onWsChatGptFull(Map<String, dynamic> json) {
    if (!_matchesStreamSession(json)) {
      return;
    }
    final type = _wsNumericType(json);
    // 流式进行中：除 10005 外一律走增量，避免 JSON 分片被当成整包后立刻 finish。
    if (_streamingMessageId != null && type != 10005) {
      _onWsChatGptStream(json);
      return;
    }

    final envelope = _parseAssistantEnvelopeFromWs(json);
    final fullReply = envelope?.text.trim().isNotEmpty == true
        ? envelope!.text.trim()
        : _extractFullReply(json);
    final fullReasoning = envelope?.reasoning.trim().isNotEmpty == true
        ? envelope!.reasoning.trim()
        : _extractFullReasoning(json);

    final streamId = _streamingMessageId;
    if (streamId == null) {
      return;
    }
    final index = state.messages.indexWhere((item) => item.id == streamId);
    if (index == -1) {
      _finishAiStream();
      return;
    }

    final current = state.messages[index];
    final text = _normalizeAssistantDisplayText(
      fullReply.trim().isEmpty ? current.text : fullReply,
    );
    final reasoning = _normalizeAssistantDisplayText(
      fullReasoning.trim().isEmpty ? current.reasoning : fullReasoning,
    );
    _replaceMessage(
      current.copyWith(
        text: text,
        reasoning: reasoning,
        reasoningExpanded: reasoning.isNotEmpty || current.reasoningExpanded,
        streaming: false,
        reasoningStreaming: false,
      ),
    );
    _finishAiStream();
  }

  void _applyStreamChunk(String piece, String reasoningPiece) {
    final streamId = _streamingMessageId;
    if (streamId == null) {
      return;
    }
    final rawText = _normalizeAssistantDisplayText(
      _unwrapJsonStringContent(piece),
    );
    final rawReasoning = _normalizeAssistantDisplayText(reasoningPiece);
    _updateMessageById(streamId, (current) {
      var nextText = current.text;
      if (rawText.isNotEmpty) {
        nextText = nextText.isNotEmpty && rawText.startsWith(nextText)
            ? rawText
            : nextText + rawText;
      }
      final nextReasoning = current.reasoning + rawReasoning;
      return current.copyWith(
        text: nextText,
        reasoning: nextReasoning,
        reasoningExpanded:
            current.reasoningExpanded ||
            nextReasoning.isNotEmpty ||
            _streamUsesReasoningUi,
        streaming: true,
        reasoningStreaming: _streamUsesReasoningUi && nextText.isEmpty,
      );
    });
  }

  void _finishAiStream() {
    _clearStreamTimers();
    final streamId = _streamingMessageId;
    _streamingMessageId = null;
    _streamTargetSessionId = null;
    _streamCorrelationReplyId = null;
    _streamUsesReasoningUi = false;
    if (streamId != null) {
      _updateMessageById(
        streamId,
        (current) =>
            current.copyWith(streaming: false, reasoningStreaming: false),
      );
    }
    state = state.copyWith(waitingAssistant: false, sending: false);
    unawaited(loadSessions(autoSelectFirst: false));
  }

  void _cancelAiStream({required bool removeStreamingMessage}) {
    _clearStreamTimers();
    final streamId = _streamingMessageId;
    _streamingMessageId = null;
    _streamTargetSessionId = null;
    _streamCorrelationReplyId = null;
    _streamUsesReasoningUi = false;
    if (removeStreamingMessage && streamId != null) {
      state = state.copyWith(
        messages: state.messages.where((item) => item.id != streamId).toList(),
      );
    }
  }

  void _resetStreamFallbackTimer() {
    _streamFallbackTimer?.cancel();
    // 深度思考 / 长回答中间可能有数秒静默，不能用短 idle 误判结束。
    _streamFallbackTimer = Timer(const Duration(minutes: 3), () async {
      final sessionId = _streamTargetSessionId ?? state.activeSessionId;
      _finishAiStream();
      if (sessionId != null && mounted) {
        await _fetchMessages(sessionId, showLoading: false);
      }
    });
  }

  void _clearStreamTimers() {
    _streamFallbackTimer?.cancel();
    _streamFallbackTimer = null;
  }

  bool _matchesStreamSession(Map<String, dynamic> json) {
    if (_streamingMessageId == null) {
      return false;
    }
    return _payloadBelongsToActiveStream(json);
  }

  bool _payloadBelongsToActiveStream(Map<String, dynamic> json) {
    final sid = _extractWsSessionId(json);
    if (sid == null) {
      return true;
    }
    return _streamIdsEqual(sid, state.activeSessionId) ||
        _streamIdsEqual(sid, _streamTargetSessionId);
  }

  Object? _extractWsSessionId(Map<String, dynamic> json) {
    final data = _toMap(json['data']);
    return json['sessionId'] ??
        json['chatSessionId'] ??
        data?['sessionId'] ??
        data?['chatSessionId'];
  }

  bool _streamIdsEqual(Object? a, Object? b) {
    if (a == null && b == null) {
      return true;
    }
    if (a == null || b == null) {
      return false;
    }
    return '$a' == '$b';
  }

  Future<String?> _fetchMessages(
    String sessionId, {
    required bool showLoading,
  }) async {
    if (showLoading) {
      state = state.copyWith(messagesLoading: true);
    }
    try {
      final response = await _repository.getMessages(sessionId);
      if (!response.isSuccess) {
        state = state.copyWith(messagesLoading: false);
        return response.displayMsg;
      }

      final messages = _normalizeMessageList(response.data);
      state = state.copyWith(
        messagesLoading: false,
        messages: messages,
        isNewConversation: messages.isEmpty,
      );
      return null;
    } catch (_) {
      state = state.copyWith(messagesLoading: false);
      return '加载消息失败';
    }
  }

  void _setPendingMessageStatus(String messageId, AiChatMessageStatus status) {
    final next = state.messages.map((message) {
      if (message.id != messageId) {
        return message;
      }
      return message.copyWith(status: status);
    }).toList();
    state = state.copyWith(messages: next);
  }

  void _replaceMessage(AiChatMessage nextMessage) {
    _updateMessageById(nextMessage.id, (_) => nextMessage);
  }

  void _updateMessageById(
    String messageId,
    AiChatMessage Function(AiChatMessage current) update,
  ) {
    final next = state.messages.map((message) {
      if (message.id != messageId) {
        return message;
      }
      return update(message);
    }).toList();
    state = state.copyWith(messages: next);
  }

  List<AiChatSession> _normalizeSessionList(dynamic data) {
    final payload = _extractListPayload(data);
    final result = <AiChatSession>[];
    for (final item in payload) {
      final session = _mapSession(item);
      if (session != null) {
        result.add(session);
      }
    }
    return result;
  }

  List<AiChatMessage> _normalizeMessageList(dynamic data) {
    final payload = _extractListPayload(data);
    final result = <AiChatMessage>[];
    for (final item in payload) {
      final message = _mapMessage(item);
      if (message != null) {
        result.add(message);
      }
    }

    result.sort((a, b) {
      final at = a.sortTime?.millisecondsSinceEpoch ?? 0;
      final bt = b.sortTime?.millisecondsSinceEpoch ?? 0;
      if (at != bt) {
        return at.compareTo(bt);
      }
      return a.id.compareTo(b.id);
    });
    return result;
  }

  List<AiChatSession> _sortSessions(List<AiChatSession> sessions) {
    final next = [...sessions];
    next.sort((a, b) {
      final at = a.sortTime?.millisecondsSinceEpoch ?? 0;
      final bt = b.sortTime?.millisecondsSinceEpoch ?? 0;
      if (at != bt) {
        return bt.compareTo(at);
      }
      return b.id.compareTo(a.id);
    });
    return next;
  }

  List<dynamic> _extractListPayload(dynamic data) {
    if (data is List) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      final records = data['records'];
      if (records is List) {
        return records;
      }
      final list = data['list'];
      if (list is List) {
        return list;
      }
      final rows = data['rows'];
      if (rows is List) {
        return rows;
      }
      final messages = data['messages'];
      if (messages is List) {
        return messages;
      }
    }
    return const [];
  }

  AiChatSession? _mapSession(dynamic raw) {
    final map = _toMap(raw);
    if (map == null) {
      return null;
    }

    final idValue = _readString(
      map['id'] ?? map['sessionId'] ?? map['chatSessionId'],
    );
    if (idValue.isEmpty) {
      return null;
    }

    final title = _readString(
      map['title'] ?? map['name'] ?? map['sessionTitle'],
    );
    final sortTime = _parseDateTime(
      map['updateTime'] ??
          map['updateDate'] ??
          map['createTime'] ??
          map['createDate'] ??
          map['lastMessageTime'] ??
          map['modifyTime'] ??
          map['timestamp'],
    );
    return AiChatSession(
      id: idValue,
      title: title.isEmpty ? '未命名会话' : title,
      sortTime: sortTime,
    );
  }

  AiChatMessage? _mapMessage(dynamic raw) {
    final map = _toMap(raw);
    if (map == null) {
      return null;
    }

    final idValue = _readString(
      map['id'] ??
          map['msgId'] ??
          'msg-${DateTime.now().microsecondsSinceEpoch}-${map.hashCode}',
    );
    final type = _deduceMessageType(map);
    final attachmentParts = _splitAttachmentsFromText(
      _normalizeMessageText(map),
    );
    final rawText = attachmentParts.text;
    final rawReasoning = _readString(
      map['reasoning_content'] ??
          map['reasoningContent'] ??
          map['reasoning'] ??
          map['thinking'] ??
          map['think'] ??
          map['thought'] ??
          map['thinkContent'] ??
          map['deepThink'] ??
          map['deepThinking'],
    );
    final parts = type == AiChatMessageType.ai
        ? _splitReasoningFromText(text: rawText, reasoning: rawReasoning)
        : _MessageParts(text: rawText.trim(), reasoning: '');
    final text = _normalizeAssistantDisplayText(parts.text);
    final reasoning = _normalizeAssistantDisplayText(parts.reasoning);

    final messageAttachments = <AiChatAttachment>[];
    if (type == AiChatMessageType.user) {
      for (final attachment in <AiChatAttachment>[
        ...attachmentParts.attachments,
        ..._attachmentsFromMessageMap(map),
      ]) {
        if (!messageAttachments.any((item) => item.url == attachment.url)) {
          messageAttachments.add(attachment);
        }
      }
    }

    return AiChatMessage(
      id: idValue,
      type: type,
      text: text,
      status: AiChatMessageStatus.sent,
      reasoning: reasoning,
      reasoningExpanded: type == AiChatMessageType.ai && reasoning.isNotEmpty,
      attachments: messageAttachments,
      sortTime: _parseDateTime(map['createTime'] ?? map['timestamp']),
    );
  }

  String _buildContentWithAttachments(
    String text,
    List<AiChatAttachment> attachments,
  ) {
    final normalizedText = text.trim();
    if (attachments.isEmpty) {
      return normalizedText;
    }
    final buffer = StringBuffer(normalizedText);
    buffer.writeln();
    buffer.writeln();
    buffer.writeln('[附件]');
    for (var index = 0; index < attachments.length; index++) {
      final attachment = attachments[index];
      buffer.writeln('${index + 1}. ${attachment.name}: ${attachment.url}');
    }
    buffer.write('请结合以上附件内容回答。');
    return buffer.toString();
  }

  String _extractAttachmentUrl(dynamic data) {
    if (data == null) {
      return '';
    }
    if (data is String || data is num) {
      return data.toString();
    }
    final map = _toMap(data);
    if (map != null) {
      final direct = _readString(
        map['url'] ?? map['fileUrl'] ?? map['path'] ?? map['src'],
      );
      if (direct.isNotEmpty) {
        return direct;
      }
      return _extractAttachmentUrl(map['data']);
    }
    return '';
  }

  _AttachmentTextParts _splitAttachmentsFromText(String source) {
    const marker = '[附件]';
    final markerIndex = source.indexOf(marker);
    if (markerIndex < 0) {
      return _AttachmentTextParts(text: source.trim(), attachments: const []);
    }

    final visibleText = source.substring(0, markerIndex).trim();
    final rawAttachmentText = source.substring(markerIndex + marker.length);
    final attachments = <AiChatAttachment>[];
    final lineRegExp = RegExp(
      r'^\s*(?:[-*]|\d+[.)])?\s*(.*?):\s*(https?:\/\/\S+)\s*$',
    );
    for (final line in rawAttachmentText.split('\n')) {
      final match = lineRegExp.firstMatch(line.trim());
      if (match == null) {
        continue;
      }
      final name = (match.group(1) ?? '').trim();
      final url = (match.group(2) ?? '').trim();
      if (url.isEmpty) {
        continue;
      }
      attachments.add(
        AiChatAttachment(name: name.isEmpty ? '附件' : name, url: url),
      );
    }
    return _AttachmentTextParts(text: visibleText, attachments: attachments);
  }

  List<AiChatAttachment> _attachmentsFromMessageMap(Map<String, dynamic> map) {
    final raw =
        map['attachments'] ??
        map['fileList'] ??
        map['files'] ??
        map['attachmentList'];
    final result = <AiChatAttachment>[];
    if (raw is List) {
      for (final item in raw) {
        final parsed = _attachmentFromRaw(item);
        if (parsed != null &&
            !result.any((attachment) => attachment.url == parsed.url)) {
          result.add(parsed);
        }
      }
    }

    final singleUrl = _readString(map['fileUrl'] ?? map['url']);
    if (singleUrl.isNotEmpty &&
        !result.any((attachment) => attachment.url == singleUrl)) {
      final name = _readString(map['fileName'] ?? map['name']);
      result.add(
        AiChatAttachment(name: name.isEmpty ? '附件' : name, url: singleUrl),
      );
    }
    return result;
  }

  AiChatAttachment? _attachmentFromRaw(dynamic raw) {
    if (raw is String) {
      final value = raw.trim();
      if (value.isEmpty) {
        return null;
      }
      return AiChatAttachment(name: _filenameFromUrl(value), url: value);
    }
    final map = _toMap(raw);
    if (map == null) {
      return null;
    }
    final url = _readString(map['url'] ?? map['fileUrl'] ?? map['path']);
    if (url.isEmpty) {
      return null;
    }
    final name = _readString(map['name'] ?? map['fileName'] ?? map['title']);
    final size = int.tryParse(_readString(map['size'])) ?? 0;
    return AiChatAttachment(
      name: name.isEmpty ? _filenameFromUrl(url) : name,
      url: url,
      size: size,
    );
  }

  String _filenameFromUrl(String url) {
    final path = Uri.tryParse(url)?.path ?? url;
    final segments = path.split('/');
    final last = segments.isEmpty ? '' : segments.last;
    return last.isEmpty ? '附件' : Uri.decodeComponent(last);
  }

  _MessageParts _splitReasoningFromText({
    required String text,
    required String reasoning,
  }) {
    var visibleText = text.trim();
    var visibleReasoning = reasoning.trim();
    final thinkRegExp = RegExp(
      r'<think>([\s\S]*?)<\/think>',
      caseSensitive: false,
    );
    final matches = thinkRegExp.allMatches(visibleText).toList();
    if (matches.isNotEmpty) {
      final extracted = matches
          .map((match) => (match.group(1) ?? '').trim())
          .where((item) => item.isNotEmpty)
          .join('\n\n');
      visibleText = visibleText.replaceAll(thinkRegExp, '').trim();
      if (extracted.isNotEmpty) {
        visibleReasoning = visibleReasoning.isEmpty
            ? extracted
            : '$visibleReasoning\n\n$extracted';
      }
    }
    return _MessageParts(text: visibleText, reasoning: visibleReasoning);
  }

  int? _wsNumericType(Map<String, dynamic> json) {
    final value = json['type'] ?? json['msgType'] ?? json['messageType'];
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }

  _MessageParts _openAiStyleDeltasFromObject(dynamic value) {
    final object = _toMap(value);
    if (object == null) {
      return const _MessageParts(text: '', reasoning: '');
    }
    var text = '';
    var reasoning = '';
    final choices = object['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = _toMap(choices.first);
      final delta = _toMap(first?['delta'] ?? first?['message']);
      if (delta != null) {
        text += _readString(delta['content']);
        reasoning += _readString(
          delta['reasoning_content'] ??
              delta['reasoningContent'] ??
              delta['reasoning'] ??
              delta['thinking'],
        );
      }
    }

    final delta = _toMap(object['delta']);
    if (delta != null) {
      text += _readString(delta['content']);
      reasoning += _readString(
        delta['reasoning_content'] ??
            delta['reasoningContent'] ??
            delta['reasoning'] ??
            delta['thinking'],
      );
    }

    reasoning += _readString(
      object['reasoning_content'] ??
          object['reasoningContent'] ??
          object['reasoning'] ??
          object['thinking'],
    );
    if (object['content'] is String && choices is! List) {
      text += object['content'] as String;
    }
    return _MessageParts(text: text, reasoning: reasoning);
  }

  String _extractStreamDelta(Map<String, dynamic> json) {
    final type = _wsNumericType(json);
    if (_toMap(json['delta']) != null) {
      final parts = _openAiStyleDeltasFromObject(json);
      if (parts.text.isNotEmpty) {
        return parts.text;
      }
    }

    final content = json['content'];
    if ((type == 0 || type == 1 || type == 10014) && content is String) {
      final trimmed = content.trim();
      if (trimmed.startsWith('{')) {
        final parts = _openAiStyleDeltasFromObject(_toMapFromJson(trimmed));
        if (parts.text.isNotEmpty || parts.reasoning.isNotEmpty) {
          return parts.text;
        }
      }
      return _unwrapJsonStringContent(content);
    }
    if ((type == 0 || type == 1 || type == 10014) && content is Map) {
      final parts = _openAiStyleDeltasFromObject(content);
      if (parts.text.isNotEmpty) {
        return parts.text;
      }
    }
    if ((type == 10004 || type == 10013) && content is String) {
      return content;
    }
    if ((type == 10004 || type == 10013) && content is Map) {
      final map = _toMap(content);
      final nested =
          map?['delta'] ??
          map?['text'] ??
          map?['message'] ??
          map?['content'] ??
          map?['chunk'];
      if (nested != null) {
        return '$nested';
      }
    }

    final data = _parseJsonIfNeeded(json['data']);
    if (data is String) {
      return data;
    }
    final dataMap = _toMap(data);
    if (dataMap != null) {
      final parts = _openAiStyleDeltasFromObject(dataMap);
      if (parts.text.isNotEmpty) {
        return parts.text;
      }
      final nested =
          dataMap['delta'] ??
          dataMap['chunk'] ??
          dataMap['text'] ??
          dataMap['content'] ??
          dataMap['message'] ??
          dataMap['answer'];
      if (nested is String) {
        return nested;
      }
      final nestedParts = _openAiStyleDeltasFromObject(nested);
      if (nestedParts.text.isNotEmpty) {
        return nestedParts.text;
      }
    }

    final pick =
        json['delta'] ??
        json['chunk'] ??
        json['text'] ??
        json['message'] ??
        json['result'] ??
        json['output'];
    if (pick is String) {
      return pick;
    }
    final parts = _openAiStyleDeltasFromObject(pick);
    return parts.text;
  }

  String _extractReasoningStreamDelta(Map<String, dynamic> json) {
    final type = _wsNumericType(json);
    final top = _readString(
      json['reasoning_content'] ??
          json['reasoningContent'] ??
          json['reasoning'] ??
          json['thinking'],
    );
    if (top.isNotEmpty) {
      return top;
    }
    if (_toMap(json['delta']) != null) {
      final parts = _openAiStyleDeltasFromObject(json);
      if (parts.reasoning.isNotEmpty) {
        return parts.reasoning;
      }
    }
    final content = json['content'];
    if (content is Map) {
      final parts = _openAiStyleDeltasFromObject(content);
      if (parts.reasoning.isNotEmpty) {
        return parts.reasoning;
      }
    }
    final data = _parseJsonIfNeeded(json['data']);
    final dataParts = _openAiStyleDeltasFromObject(data);
    if (dataParts.reasoning.isNotEmpty) {
      return dataParts.reasoning;
    }
    if ((type == 0 || type == 1 || type == 10014) && content is String) {
      final trimmed = content.trim();
      if (trimmed.startsWith('{')) {
        final parts = _openAiStyleDeltasFromObject(_toMapFromJson(trimmed));
        if (parts.reasoning.isNotEmpty) {
          return parts.reasoning;
        }
      }
    }
    return '';
  }

  _MessageParts? _parseAssistantEnvelopeFromWs(Map<String, dynamic> json) {
    final type = _wsNumericType(json);
    if (type != 10005 && type != 10014) {
      return null;
    }
    final content = json['content'];
    final object = content is String
        ? _toMapFromJson(content.trim())
        : _toMap(content);
    if (object == null) {
      return null;
    }
    final reasoning = _readString(
      object['reasoningContent'] ??
          object['reasoning_content'] ??
          object['reasoning'] ??
          object['thinking'],
    ).trim();
    final reply = _readString(
      object['content'] ??
          object['answer'] ??
          object['text'] ??
          object['message'],
    ).trim();
    if (reply.isEmpty && reasoning.isEmpty) {
      return null;
    }
    return _MessageParts(text: reply, reasoning: reasoning);
  }

  String _extractFullReply(Map<String, dynamic> json) {
    final type = _wsNumericType(json);
    final content = json['content'];
    if ((json['role'] == 'assistant' || json['role'] == 'ai') &&
        content is Map) {
      final map = _toMap(content);
      return _readString(
        map?['content'] ?? map?['answer'] ?? map?['text'] ?? map?['message'],
      );
    }
    if ((json['role'] == 'assistant' || json['role'] == 'ai') &&
        content is String) {
      return _unwrapJsonStringContent(content);
    }
    if ((type == 10005 || type == 10014) && content is Map) {
      final map = _toMap(content);
      return _readString(
        map?['content'] ?? map?['answer'] ?? map?['text'] ?? map?['message'],
      );
    }
    if ((type == 10005 || type == 10014) && content is String) {
      final trimmed = content.trim();
      if (trimmed.startsWith('{')) {
        final map = _toMapFromJson(trimmed);
        final main = _readString(
          map?['content'] ?? map?['answer'] ?? map?['text'] ?? map?['message'],
        );
        if (main.isNotEmpty) {
          return main;
        }
      }
      return trimmed;
    }
    final data = _parseJsonIfNeeded(json['data']);
    if (data is String) {
      return data;
    }
    final dataMap = _toMap(data);
    return _readString(
      json['answer'] ??
          json['full'] ??
          json['text'] ??
          json['message'] ??
          dataMap?['content'] ??
          dataMap?['answer'] ??
          dataMap?['message'] ??
          dataMap?['full'] ??
          dataMap?['text'],
    );
  }

  String _extractFullReasoning(Map<String, dynamic> json) {
    final type = _wsNumericType(json);
    final top = _readString(
      json['reasoning_content'] ??
          json['reasoningContent'] ??
          json['reasoning'] ??
          json['thinking'],
    );
    if (top.isNotEmpty) {
      return top;
    }
    final content = json['content'];
    if (content is Map) {
      final map = _toMap(content);
      final inner = _readString(
        map?['reasoning_content'] ??
            map?['reasoningContent'] ??
            map?['reasoning'] ??
            map?['thinking'],
      );
      if (inner.isNotEmpty) {
        return inner;
      }
    }
    if ((type == 10005 || type == 10014) && content is String) {
      final map = _toMapFromJson(content.trim());
      final inner = _readString(
        map?['reasoning_content'] ??
            map?['reasoningContent'] ??
            map?['reasoning'] ??
            map?['thinking'],
      );
      if (inner.isNotEmpty) {
        return inner;
      }
    }
    final data = _parseJsonIfNeeded(json['data']);
    final parts = _openAiStyleDeltasFromObject(data);
    if (parts.reasoning.isNotEmpty) {
      return parts.reasoning;
    }
    final dataMap = _toMap(data);
    return _readString(
      dataMap?['reasoning_content'] ??
          dataMap?['reasoningContent'] ??
          dataMap?['reasoning'] ??
          dataMap?['thinking'],
    );
  }

  dynamic _parseJsonIfNeeded(dynamic value) {
    if (value is! String) {
      return value;
    }
    final trimmed = value.trim();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
      return value;
    }
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return value;
    }
  }

  AiChatMessageType _deduceMessageType(Map<String, dynamic> map) {
    final role = _readString(map['role']).toLowerCase();
    if (role == 'user') {
      return AiChatMessageType.user;
    }
    if (role == 'assistant' || role == 'ai') {
      return AiChatMessageType.ai;
    }

    final type = map['type'];
    final messageType = map['messageType'];
    final senderType = map['senderType'];
    final fromUser = map['fromUser'];
    final isSelf = map['isSelf'];

    final looksUser =
        type == 'user' ||
        type == 1 ||
        messageType == 0 ||
        messageType == 'USER' ||
        senderType == 1 ||
        fromUser == true ||
        isSelf == true;
    if (looksUser) {
      return AiChatMessageType.user;
    }
    return AiChatMessageType.ai;
  }

  String _normalizeMessageText(Map<String, dynamic> raw) {
    dynamic value =
        raw['content'] ??
        raw['message'] ??
        raw['text'] ??
        raw['answer'] ??
        raw['body'];

    if (value is Map<String, dynamic>) {
      value = value['content'] ?? value['text'] ?? value['message'];
    }

    final text = _readString(value);
    return _unwrapJsonStringContent(text).trim();
  }

  String _unwrapJsonStringContent(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('{')) {
      return text;
    }

    try {
      final map = _toMap(trimmed);
      if (map == null) {
        return trimmed;
      }
      final role = _readString(map['role']).toLowerCase();
      if (role == 'assistant') {
        final content = _readString(map['content']);
        if (content.isNotEmpty) {
          return content;
        }
      }
      final candidate = _readString(
        map['content'] ?? map['text'] ?? map['message'],
      );
      return candidate.isNotEmpty ? candidate : trimmed;
    } catch (_) {
      return trimmed;
    }
  }

  String? _extractSessionId(dynamic data) {
    if (data == null) {
      return null;
    }
    if (data is num || data is String) {
      final id = data.toString();
      return id.isEmpty ? null : id;
    }
    if (data is Map<String, dynamic>) {
      final id = _readString(data['id'] ?? data['sessionId']);
      return id.isEmpty ? null : id;
    }
    return null;
  }

  String _titleFromFirstUserMessage(String text) {
    final raw = text.trim();
    if (raw.isEmpty) {
      return '新对话';
    }
    final firstLine = raw.split('\n').first.trim();
    if (firstLine.length <= 50) {
      return firstLine;
    }
    return '${firstLine.substring(0, 50)}...';
  }

  String _assistantSystemRule() {
    return '''
你必须全程扮演“小艺同学”，定位是面向音乐艺考生的备考与学习辅助助手。
只围绕音乐艺考相关内容回答，比如乐理、视唱练耳、听辨、曲目练习、院校方向和备考计划。
如果用户的话题与音乐艺考无关，请先用一句话说明你的定位，再把对话自然引导回音乐学习场景。
不要自称 DeepSeek，不要提及第三方模型公司名称。
回答风格要清晰、友好、专业，优先给出可执行的学习建议和分步骤说明。
如果用户提出的是抽象问题，请尽量结合音乐艺考训练场景举例说明。
''';
  }

  Map<String, dynamic>? _toMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, data) => MapEntry('$key', data));
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        return _toMapFromJson(trimmed);
      }
    }
    return null;
  }

  Map<String, dynamic>? _toMapFromJson(String text) {
    try {
      final decoded = jsonDecode(text);
      return _toMap(decoded);
    } catch (_) {
      return null;
    }
  }

  String _readString(dynamic value) {
    if (value == null) {
      return '';
    }
    return '$value';
  }

  DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is DateTime) {
      return raw;
    }
    if (raw is num) {
      var millis = raw.toInt();
      if (millis <= 0) {
        return null;
      }
      if (millis < 10000000000) {
        millis *= 1000;
      }
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }
    final str = raw.toString().trim();
    if (str.isEmpty) {
      return null;
    }
    final asNum = int.tryParse(str);
    if (asNum != null) {
      return _parseDateTime(asNum);
    }
    return DateTime.tryParse(str);
  }

  String _normalizeAssistantDisplayText(String source) {
    if (source.isEmpty) {
      return source;
    }

    var text = source;
    text = text.replaceAll(
      RegExp(r'\bDeepSeek\b', caseSensitive: false),
      '小艺同学',
    );
    text = text.replaceAll(RegExp(r'deepseek', caseSensitive: false), '小艺同学');
    text = text.replaceAll('深度求索公司', '小艺同学');
    text = text.replaceAll('深度求索', '小艺同学');
    return text;
  }
}

class _MessageParts {
  const _MessageParts({required this.text, required this.reasoning});

  final String text;
  final String reasoning;
}

class _AttachmentTextParts {
  const _AttachmentTextParts({required this.text, required this.attachments});

  final String text;
  final List<AiChatAttachment> attachments;
}
