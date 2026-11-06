import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/app_constants.dart';
import '../providers/app_providers.dart';
import '../storage/app_storage.dart';
import 'big_int_safe_transformer.dart';
import 'chat_sync_payload.dart';
import 'chat_websocket_connect.dart';
import 'snowflake_id.dart';

/// 全局长连接服务。承担三类下行事件：
///
/// 1. AI 助手（流式增量片段 / 整包响应 / 思考过程）；
/// 2. 系统事件（被踢、token 失效、登录超时）；
/// 3. 群聊推送（新消息 / 撤回 / 公告更新）。
///
/// 行为对齐 1.0 `utils/wsClient.js`：
/// * 仅在本地存在 `token` 时连接；连接成功后发送 `{type:1000, token}`；
/// * 每 60s 上行心跳 `{type:100}`；
/// * 非主动断开时 5s 自动重连；
/// * 全部事件以广播 `Stream<ChatSocketEvent>` 暴露，业务侧按 `type` 过滤。
///
/// 与 1.0 的差异：
/// * 1.0 群聊走 HTTP `syncMsg` 轮询；2.0 增加 [ChatSocketEventType.chatNewMessage]
///   等事件，由后端在 WS 上推。客户端遇到 `chatNewMessage` 后既可以
///   直接合并 payload（若服务端带上完整消息体），也可以触发一次
///   `syncMsg` 作为兜底。
///
/// 注意：本服务在应用整个生命周期内活着，Provider 默认不会被销毁；
/// 想强制断开请显式调 [disconnect]。
final chatSocketServiceProvider = Provider<ChatSocketService>((ref) {
  final storage = ref.watch(appStorageProvider);
  final service = ChatSocketService(storage: storage);
  ref.onDispose(service.dispose);
  return service;
});

/// 事件类型。`stream`/`full`/`message` 三个值与 1.0 兼容，旧的
/// `AiChatSocketEventType` 通过 typedef 指向同一个枚举。
enum ChatSocketEventType {
  /// 任意原始下行帧 —— 不做语义判定，订阅方可自行解析。
  message,

  /// AI 助手流式增量字符片段（type=0 / 10004 / 10013 或匹配的 type=1 / 10014 增量）。
  stream,

  /// AI 助手整包响应（type=1 / 10005 / 10014 或带 `role=assistant` 的 envelope）。
  full,

  /// 群聊新消息。payload 可能直接带完整消息体；若只是个信号位，
  /// 业务侧应触发一次 `syncMsg` 兜底拉取。
  chatNewMessage,

  /// 群聊消息撤回。
  chatMessageDeleted,

  /// 群公告更新。
  chatAnnouncementUpdated,

  /// WebSocket 连接就绪（含重连成功）。业务侧应触发一次 `syncMsg` 补齐。
  connected,

  /// 被踢下线（type=10003）。
  kicked,

  /// token 失效（type=10000）。
  tokenError,

  /// 登录超时（type=10002）。
  loginTimeout,
}

/// 旧名称别名 —— `features/ai_chat` 模块沿用此名，避免大面积改 import。
typedef AiChatSocketEventType = ChatSocketEventType;

class ChatSocketEvent {
  const ChatSocketEvent({required this.type, required this.payload});

  final ChatSocketEventType type;
  final Map<String, dynamic> payload;
}

/// 旧名称别名。
typedef AiChatSocketEvent = ChatSocketEvent;

class ChatSocketService {
  ChatSocketService({required AppStorage storage}) : _storage = storage;

  final AppStorage _storage;
  final StreamController<ChatSocketEvent> _events =
      StreamController<ChatSocketEvent>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _disposed = false;
  bool _intentionallyClosed = false;
  bool _connecting = false;

  /// 全部下行事件流。订阅方按 [ChatSocketEvent.type] 过滤即可。
  Stream<ChatSocketEvent> get events => _events.stream;

  /// 当前底层 socket 是否已就绪（不是 100% 等价于"在线"，仅做粗略可视化）。
  bool get isConnected => _channel != null;

  /// 触发一次连接。若已有底层 socket 在跑，会先关掉再重连，确保用最新
  /// token 走 `{type:1000}` 握手。可在以下时机调用：
  /// * App 启动且本地存在 token；
  /// * 登录 / 重新登录成功；
  /// * 切换学校等需要换 token 的场景。
  void connect() {
    if (_disposed) {
      return;
    }
    final token = _storage.token;
    if (token.isEmpty) {
      return;
    }
    if (_connecting) {
      return;
    }
    if (_channel != null) {
      return;
    }

    _intentionallyClosed = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _closeChannel();

    _connecting = true;
    try {
      // _wsUri() 含 Uri.parse —— apiBaseUrl 异常 / 网络栈异常都不能让启动
      // 期同步抛出，全部捕获后走重连兜底。
      final uri = _wsUri();
      final channel = connectChatWebSocket(uri);
      _channel = channel;
      _subscription = channel.stream.listen(
        _handleRawMessage,
        onError: (_) => _handleClosed(),
        onDone: _handleClosed,
        cancelOnError: true,
      );
      try {
        channel.sink.add(
          jsonEncode(<String, dynamic>{'type': 1000, 'token': token}),
        );
      } catch (_) {
        // sink 在 channel 还没就绪时偶发抛同步异常；交给底层 stream 的
        // onError 关闭，不影响后续重连。
      }
      _startHeartbeat();
      // 握手帧发出后通知业务侧 syncMsg；群聊页若尚未挂载，会在进页时 reconnect。
      _emit(ChatSocketEventType.connected, const {});
    } catch (_) {
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  /// 主动断开并不再自动重连。退出登录、切换账号时调用。
  void disconnect() {
    _intentionallyClosed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _closeChannel();
  }

  /// 等价于 disconnect + connect，保证用最新 token 走一次握手。
  void reconnect() {
    disconnect();
    _intentionallyClosed = false;
    connect();
  }

  void dispose() {
    _disposed = true;
    disconnect();
    unawaited(_events.close());
  }

  Uri _wsUri() {
    final base = AppConstants.apiBaseUrl.trim();
    if (base.startsWith('https://')) {
      return Uri.parse(
        'wss://${base.substring('https://'.length).replaceFirst(RegExp(r'/$'), '')}/websocket',
      );
    }
    if (base.startsWith('http://')) {
      return Uri.parse(
        'ws://${base.substring('http://'.length).replaceFirst(RegExp(r'/$'), '')}/websocket',
      );
    }
    return Uri.parse('$base/websocket');
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      try {
        _channel?.sink.add(jsonEncode(<String, dynamic>{'type': 100}));
      } catch (_) {
        _handleClosed();
      }
    });
  }

  void _handleRawMessage(dynamic raw) {
    final text = raw?.toString() ?? '';
    if (text.isEmpty) {
      return;
    }
    try {
      final decoded = decodeBigIntSafeJson(text);
      final map = _toMap(decoded);
      if (map == null) {
        return;
      }

      // 始终先以 message 维度广播一次，方便排查 / 调试 / 自定义解析。
      _emit(ChatSocketEventType.message, map);

      final envelope = ChatSyncPayload.normalizePush(map);
      final normalizedType = _normalizeWsType(envelope);
      final rootType = _normalizeWsType(map);

      // 系统事件。
      if (rootType == 10003 || normalizedType == 10003) {
        _emit(ChatSocketEventType.kicked, map);
        return;
      }
      if (rootType == 10000 || normalizedType == 10000) {
        _emit(ChatSocketEventType.tokenError, map);
        return;
      }
      if (rootType == 10002 || normalizedType == 10002) {
        _emit(ChatSocketEventType.loginTimeout, map);
        return;
      }

      // 群聊推送 —— 必须在 AI 分支之前判定。
      //
      // 群聊消息 type 与 AI 复用 0/1 等编号（文本=1）；若先走 AI 分支，
      // chatNewMessage 永远触发不了，页面只能切会话后靠 msgList 刷新。
      //
      // 约定（推荐让后端就近选用 2001 / 2002 / 2003）：
      //   2001：新消息
      //   2002：消息撤回
      //   2003：公告变更
      final chatType = normalizedType ?? rootType;
      if (_looksLikeChatPayload(envelope, chatType) ||
          _looksLikeChatPayload(map, rootType)) {
        final payload = ChatSyncPayload.hasChatIdentity(envelope)
            ? envelope
            : ChatSyncPayload.normalizePush(map);
        if (_isChatPushType(chatType, 2002) ||
            _looksLikeChatMessageDeleted(payload, chatType)) {
          _emit(ChatSocketEventType.chatMessageDeleted, payload);
          return;
        }
        if (_isChatPushType(chatType, 2003) ||
            _looksLikeChatAnnouncementChanged(payload, chatType)) {
          _emit(ChatSocketEventType.chatAnnouncementUpdated, payload);
          return;
        }
        _emit(ChatSocketEventType.chatNewMessage, payload);
        return;
      }

      // AI 助手 —— 流式增量（type=1/10014 在协议里几乎全是 delta，整包只认 10005）。
      if (rootType == 0 ||
          rootType == 1 ||
          rootType == 10004 ||
          rootType == 10013 ||
          rootType == 10014 ||
          _isLikelyChatGptStreamChunk(map, rootType)) {
        _emit(ChatSocketEventType.stream, map);
        return;
      }

      // AI 助手 —— 整包响应（仅 10005 或无 type 的 assistant envelope）。
      if (rootType == 10005 || _isAssistantFullPayload(map, rootType)) {
        _emit(ChatSocketEventType.full, map);
        return;
      }
    } catch (_) {
      return;
    }
  }

  void _emit(ChatSocketEventType type, Map<String, dynamic> payload) {
    if (!_events.isClosed) {
      _events.add(ChatSocketEvent(type: type, payload: payload));
    }
  }

  int? _normalizeWsType(Map<String, dynamic> json) {
    final value = json['type'] ?? json['msgType'] ?? json['messageType'];
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }

  bool _isLikelyChatGptStreamChunk(Map<String, dynamic> json, int? type) {
    if (type != null) {
      return false;
    }
    return _looksLikeAssistantStreamPayload(json);
  }

  /// 无明确 type 但语义上像 AI 流式增量（delta / chunk / 短文本 content）。
  bool _looksLikeAssistantStreamPayload(Map<String, dynamic> json) {
    if (json['role'] == 'assistant' || json['role'] == 'ai') {
      return false;
    }
    if (_hasOpenAiStyleDelta(json) || _hasOpenAiStyleDelta(json['content'])) {
      return true;
    }
    if (json['delta'] != null || json['chunk'] != null) {
      return true;
    }
    final content = json['content'];
    if (content is String && content.isNotEmpty) {
      return true;
    }
    return false;
  }

  bool _hasOpenAiStyleDelta(dynamic value) {
    final map = _toMap(value);
    if (map == null) {
      return false;
    }
    if (map['delta'] != null || map['chunk'] != null) {
      return true;
    }
    final choices = map['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = _toMap(choices.first);
      return first?['delta'] != null || first?['message'] != null;
    }
    return false;
  }

  bool _isAssistantFullPayload(Map<String, dynamic> json, int? type) {
    if (type != null) {
      return false;
    }
    return (json['role'] == 'assistant' || json['role'] == 'ai') &&
        json['content'] != null &&
        (json['sessionId'] != null || json['chatSessionId'] != null);
  }

  bool _isChatPushType(int? actualType, int expectedType) =>
      actualType != null && actualType == expectedType;

  /// 群聊帧语义判定：带 classId 且具备消息字段。
  bool _looksLikeChatPayload(Map<String, dynamic> json, int? type) {
    final classId = readSnowflakeId(json['classId']) ?? readSnowflakeId(json['cId']);
    if (classId == null) return false;

    if (_isChatPushType(type, 2001) ||
        _isChatPushType(type, 2002) ||
        _isChatPushType(type, 2003)) {
      return true;
    }

    final hasChatIdentity =
        readSnowflakeId(json['fromUserId']) != null ||
        readSnowflakeId(json['msgId']) != null ||
        readSnowflakeId(json['id']) != null ||
        readSnowflakeId(json['messageId']) != null;
    final hasChatMsgType =
        type != null && ((type >= 0 && type <= 3) || type == 100);
    if (hasChatIdentity || hasChatMsgType) {
      if ((json['sessionId'] != null || json['chatSessionId'] != null) &&
          !hasChatIdentity &&
          (json['role'] == 'assistant' || json['role'] == 'ai')) {
        return false;
      }
      return true;
    }

    return _looksLikeChatNewMessage(json, type);
  }

  /// 兜底：若服务端只下发 classId + 内容字段而无明确 type，按新消息处理。
  bool _looksLikeChatNewMessage(Map<String, dynamic> json, int? type) {
    final hasClass = json['classId'] != null || json['cId'] != null;
    if (!hasClass) return false;
    final hasContent =
        json['content'] != null ||
        json['msgId'] != null ||
        json['id'] != null ||
        json['contentType'] != null;
    return hasContent;
  }

  bool _looksLikeChatMessageDeleted(Map<String, dynamic> json, int? type) {
    if (type != null && type < 2000) {
      return false;
    }
    final eventField = (json['event'] ?? json['action'] ?? '')
        .toString()
        .toLowerCase();
    return eventField.contains('delete') || eventField.contains('recall');
  }

  bool _looksLikeChatAnnouncementChanged(
    Map<String, dynamic> json,
    int? type,
  ) {
    if (type != null && type < 2000) {
      return false;
    }
    final eventField = (json['event'] ?? json['action'] ?? '')
        .toString()
        .toLowerCase();
    return eventField.contains('announcement') ||
        json['announcement'] != null && json['classId'] != null;
  }

  void _handleClosed() {
    if (_disposed || _intentionallyClosed) {
      return;
    }
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _closeChannel();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _intentionallyClosed || _reconnectTimer != null) {
      return;
    }
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _reconnectTimer = null;
      // 重连前再次校验 token，避免登出后还在静默重连。
      if (_storage.token.isEmpty) {
        return;
      }
      connect();
    });
  }

  void _closeChannel() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {
      // Ignore socket close errors.
    }
    _channel = null;
  }

  Map<String, dynamic>? _toMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, data) => MapEntry('$key', data));
    }
    return null;
  }
}
