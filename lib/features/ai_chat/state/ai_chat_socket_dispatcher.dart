import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_chat_socket_service.dart';

typedef AiChatSocketHandler = void Function(AiChatSocketEvent event);

/// 应用级 AI WebSocket 事件分发器。
///
/// 订阅全局 [ChatSocketService] 的长连接广播，再把 AI 相关帧转发给当前
/// 活跃的 [AiChatController]。避免 autoDispose / 页面重建导致流式订阅丢失。
class AiChatSocketDispatcher {
  AiChatSocketHandler? _handler;

  void setHandler(AiChatSocketHandler? handler) {
    _handler = handler;
  }

  void clearHandler(AiChatSocketHandler handler) {
    if (identical(_handler, handler)) {
      _handler = null;
    }
  }

  void dispatch(AiChatSocketEvent event) {
    if (_handler == null) {
      return;
    }
    if (event.type != AiChatSocketEventType.stream &&
        event.type != AiChatSocketEventType.full) {
      return;
    }
    _handler!(event);
  }
}

final aiChatSocketDispatcherProvider = Provider<AiChatSocketDispatcher>((ref) {
  final socket = ref.watch(aiChatSocketServiceProvider);
  final dispatcher = AiChatSocketDispatcher();
  final subscription = socket.events.listen(dispatcher.dispatch);
  ref.onDispose(subscription.cancel);
  return dispatcher;
});
