import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/core/network/api_response.dart';
import 'package:the_road_of_art_flutter/features/ai_chat/data/ai_chat_repository.dart';
import 'package:the_road_of_art_flutter/features/ai_chat/data/ai_chat_socket_service.dart';
import 'package:the_road_of_art_flutter/features/ai_chat/state/ai_chat_controller.dart';
import 'package:the_road_of_art_flutter/features/ai_chat/state/ai_chat_socket_dispatcher.dart';
import 'package:the_road_of_art_flutter/features/ai_chat/state/ai_chat_state.dart';

class _Repository implements AiChatRepository {
  bool fail = false;
  List<Map<String, dynamic>> history = [];
  @override
  Future<ApiResponse> noSuchMethod(Invocation i) async {
    if (i.memberName == #getSessionList) {
      return const ApiResponse(
        code: 0,
        msg: 'ok',
        data: [
          {'id': '9', 'title': 'test'},
        ],
      );
    }
    if (i.memberName == #createSession) {
      return const ApiResponse(code: 0, msg: 'ok', data: {'id': '9'});
    }
    if (i.memberName == #sendMessage && fail) {
      return ApiResponse.failure('暂未开通');
    }
    if (i.memberName == #getMessages) {
      return ApiResponse(code: 0, msg: 'ok', data: history);
    }
    return const ApiResponse(code: 0, msg: 'ok', data: []);
  }
}

void main() {
  late _Repository repository;
  late AiChatSocketDispatcher dispatcher;
  late AiChatController controller;
  setUp(() async {
    repository = _Repository();
    dispatcher = AiChatSocketDispatcher();
    controller = AiChatController(
      repository: repository,
      dispatcher: dispatcher,
    );
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() => controller.dispose());
  void frame(int type, String content) => dispatcher.dispatch(
    AiChatSocketEvent(
      type: type == 10005
          ? AiChatSocketEventType.full
          : AiChatSocketEventType.stream,
      payload: {
        'type': type,
        'sessionId': '9',
        'replyId': '91',
        'content': content,
      },
    ),
  );
  test(
    'mock plain JSON content survives stream and final, final is not duplicated',
    () async {
      await controller.sendMessage('分析');
      const text = '{"content":"keep this JSON","reasoning":"a field"}';
      frame(10004, text);
      expect(controller.state.messages.last.text, text);
      frame(10005, text);
      frame(10005, text);
      expect(
        controller.state.messages.where((m) => m.type == AiChatMessageType.ai),
        hasLength(1),
      );
      expect(controller.state.messages.last.text, text);
      expect(controller.state.waitingAssistant, isFalse);
      expect(controller.state.messages.last.streaming, isFalse);
      expect(controller.state.messages.last.reasoning, isEmpty);
    },
  );
  test(
    'off final failure ends waiting; rejected HTTP removes empty assistant',
    () async {
      await controller.sendMessage('分析');
      frame(10005, 'AI 助手暂未开通');
      expect(controller.state.waitingAssistant, isFalse);
      expect(controller.state.messages.last.text, 'AI 助手暂未开通');
      repository.fail = true;
      expect(await controller.sendMessage('再次提问'), '暂未开通');
      expect(controller.state.waitingAssistant, isFalse);
      expect(controller.state.sending, isFalse);
      expect(
        controller.state.messages.where((m) => m.type == AiChatMessageType.ai),
        hasLength(1),
      );
      expect(controller.state.messages.any((m) => m.streaming), isFalse);
      expect(controller.state.messages.last.status, AiChatMessageStatus.failed);
    },
  );
  test('persisted JSON reply remains intact on reopening', () async {
    const text = '{"content":"literal JSON"}';
    repository.history = [
      {'id': '91', 'role': 'assistant', 'content': text},
    ];
    await controller.selectSession('9');
    expect(controller.state.messages.single.text, text);
  });
}
