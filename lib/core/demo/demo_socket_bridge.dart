import 'dart:async';
import 'dart:math' as math;

import '../network/chat_socket_service.dart';

/// 演示模式下的 WebSocket 替身：把模拟下行帧注入 [ChatSocketService]
/// 的统一解析链路（AI 流式回复、群聊新消息等），协议与线上一致。
class DemoSocketBridge {
  DemoSocketBridge._();

  static final DemoSocketBridge instance = DemoSocketBridge._();

  ChatSocketService? _service;
  final math.Random _random = math.Random();

  void attach(ChatSocketService service) {
    _service = service;
  }

  void push(Map<String, dynamic> frame) {
    _service?.injectDemoFrame(frame);
  }

  /// AI 回复：若干 `type=10004` 增量帧 + 一条 `type=10005` 整包收尾。
  Future<void> streamAiReply({
    required String sessionId,
    required String text,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    var index = 0;
    while (index < text.length) {
      final step = 2 + _random.nextInt(5);
      final end = math.min(text.length, index + step);
      push(<String, dynamic>{
        'type': 10004,
        'sessionId': sessionId,
        'content': text.substring(index, end),
      });
      index = end;
      await Future<void>.delayed(Duration(milliseconds: 30 + _random.nextInt(40)));
    }
    push(<String, dynamic>{
      'type': 10005,
      'sessionId': sessionId,
      'content': text,
    });
  }

  /// 群聊推送：延迟后下发一条新消息信号（payload 为完整消息体）。
  void pushChatMessage(Map<String, dynamic> message, {Duration? delay}) {
    unawaited(
      Future<void>.delayed(delay ?? const Duration(seconds: 2), () {
        push(<String, dynamic>{'type': 2001, ...message});
      }),
    );
  }
}
