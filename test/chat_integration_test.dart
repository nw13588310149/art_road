import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_socket_bridge.dart';
import 'package:the_road_of_art_flutter/core/network/api_response.dart';
import 'package:the_road_of_art_flutter/core/network/chat_socket_service.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/data/chat_repository.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/ui/group_chat_view.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _Storage extends Fake implements AppStorage {
  @override
  String token = 'test-session';
}

class _Sink extends Fake implements WebSocketSink {
  final sent = <dynamic>[];
  @override
  void add(dynamic data) => sent.add(jsonDecode(data as String));
  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}
}

class _Wire extends Fake implements WebSocketChannel {
  final inbound = StreamController<dynamic>();
  @override
  final _Sink sink = _Sink();
  @override
  Stream<dynamic> get stream => inbound.stream;
  @override
  int? closeCode;
}

class _Socket extends Fake implements ChatSocketService {
  final frames = StreamController<ChatSocketEvent>.broadcast();
  @override
  bool isConnected = true;
  @override
  Stream<ChatSocketEvent> get events => frames.stream;
  @override
  void connect() {}
}

Map<String, dynamic> _message(String id, String group, String text) => {
  'id': id,
  'classId': group,
  'fromUserId': '8',
  'type': 1,
  'content': text,
  'createTime': '2026-11-20 09:00:00',
};

class _Groups extends Fake implements ChatRepository {
  final offsets = <String>[];
  bool wasRecalled = false;
  Map<String, dynamic> get firstMessage => {
    ..._message('10', '1', '上节课的安排'),
    if (wasRecalled) 'type': 100,
  };
  @override
  Future<ApiResponse> classList() async => ApiResponse(
    code: 0,
    msg: 'ok',
    data: [
      {'id': '1', 'name': '置顶班', 'isPinned': 1, 'latestMsg': firstMessage},
      {
        'id': '2',
        'name': '活跃班',
        'latestMsg': _message('9000000000000000033', '2', '今日安排'),
      },
    ],
  );
  @override
  Future<ApiResponse> classDetail({required String classId}) async =>
      const ApiResponse(code: 0, msg: 'ok', data: {});
  @override
  Future<ApiResponse> msgList({
    required String classId,
    String offsetMsgId = '0',
    int size = 20,
  }) async => ApiResponse(
    code: 0,
    msg: 'ok',
    data: {
      'msgList': [firstMessage],
    },
  );
  @override
  Future<ApiResponse> syncMsg({String offsetMsgId = '0', int size = 20}) async {
    offsets.add(offsetMsgId);
    return const ApiResponse(code: 0, msg: 'ok', data: {'msgList': []});
  }
}

void main() {
  testWidgets('正式连接在握手后可用，网络中断后重试，被替换或令牌失效后停止重连', (tester) async {
    final wires = <_Wire>[];
    final service = ChatSocketService(
      storage: _Storage(),
      baseUrl: 'http://127.0.0.1:8787/',
      openChannel: (_) {
        final wire = _Wire();
        wires.add(wire);
        return wire;
      },
    );
    final events = <ChatSocketEventType>[];
    final sub = service.events.listen((event) => events.add(event.type));
    service.connect();
    expect(wires.single.sink.sent.single['type'], 1000);
    expect(service.isConnected, isFalse);
    wires.single.inbound.add('{"type":1001}');
    await tester.pump();
    expect(service.isConnected, isTrue);
    expect(events, contains(ChatSocketEventType.connected));
    unawaited(wires.single.inbound.close());
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(wires, hasLength(2));
    expect(service.isConnected, isFalse);
    wires.last.inbound.add('{"type":10000}');
    await tester.pump();
    expect(events, contains(ChatSocketEventType.tokenError));
    await tester.pump(const Duration(seconds: 6));
    expect(wires, hasLength(2));
    service.connect();
    wires.last.closeCode = 4009;
    unawaited(wires.last.inbound.close());
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    expect(wires, hasLength(3));
    service.connect();
    wires.last.inbound.add('{"type":10003}');
    await tester.pump();
    expect(events, contains(ChatSocketEventType.kicked));
    await tester.pump(const Duration(seconds: 6));
    expect(wires, hasLength(4));
    service.dispose();
    unawaited(sub.cancel());
    for (final wire in wires) {
      unawaited(wire.inbound.close());
    }
    await tester.pump();
  });

  testWidgets('切换体验身份后忽略延迟的演示消息，正式账号只向指定服务握手', (tester) async {
    final storage = _Storage()..token = DemoAccounts.teacher.token;
    final wire = _Wire();
    final addresses = <Uri>[];
    final events = <ChatSocketEventType>[];
    final service = ChatSocketService(
      storage: storage,
      baseUrl: 'https://example.test/',
      openChannel: (uri) {
        addresses.add(uri);
        return wire;
      },
    );
    final sub = service.events.listen((event) => events.add(event.type));
    service.connect();
    DemoSocketBridge.instance.pushChatMessage({'classId': '1', 'msgId': '5'});
    storage.token = DemoAccounts.student.token;
    service.connect();
    await tester.pump(const Duration(seconds: 3));
    expect(events, isNot(contains(ChatSocketEventType.chatNewMessage)));
    expect(addresses, isEmpty);
    for (final token in ['youke', 'demo.student.13900001111', '']) {
      storage.token = token;
      service.connect();
      expect(service.isConnected, isFalse);
      expect(addresses, isEmpty);
    }
    storage.token = 'formal-test-session';
    service.connect();
    expect(addresses.single.toString(), 'wss://example.test/websocket');
    expect(wire.sink.sent.single, {'type': 1000, 'token': storage.token});
    service.dispose();
    unawaited(sub.cancel());
    unawaited(wire.inbound.close());
    await tester.pump();
  });

  testWidgets('跨群同步从活跃群快照开始，在线撤回就地生效，断线期间才轮询', (tester) async {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final socket = _Socket();
    final groups = _Groups();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRepositoryProvider.overrideWithValue(groups),
          chatSocketServiceProvider.overrideWithValue(socket),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: GroupChatView(
              onBack: () {},
              currentUserId: '8',
              currentUserName: '任课老师',
              currentUserAvatarUrl: '',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(groups.offsets, ['9000000000000000033']);
    socket.frames.add(
      const ChatSocketEvent(
        type: ChatSocketEventType.chatMessageDeleted,
        payload: {'classId': '1', 'msgId': '10'},
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('一条消息已撤回'), findsOneWidget);
    expect(find.text('上节课的安排'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    expect(groups.offsets, hasLength(1));
    socket.isConnected = false;
    await tester.pump(const Duration(seconds: 5));
    expect(groups.offsets, hasLength(2));
    groups.wasRecalled = true;
    socket.isConnected = true;
    socket.frames.add(
      const ChatSocketEvent(type: ChatSocketEventType.connected, payload: {}),
    );
    await tester.pumpAndSettle();
    expect(find.text('对方 撤回了一条消息'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await socket.frames.close();
  });
}
