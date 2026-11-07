import 'dart:async';
import 'dart:math' as math;

import '../demo_accounts.dart';
import '../demo_backend.dart';
import '../demo_clock.dart';
import '../demo_socket_bridge.dart';
import '../demo_store.dart';
import '../media/demo_media.dart';
import 'interaction_ai_tutor.dart';
import 'interaction_common.dart';

/// 小美同学（美术答疑助手）：会话 / 消息存 [DemoStore]，回复经演示 WebSocket
/// 以 10004 增量帧 + 10005 整包帧推送。
void registerAiChatFixtures(DemoRouter r) {
  r.post('/app/user/chat-gpt/sessionList', (req) {
    final sessions = [..._sessions(req.account)]
      ..sort((a, b) => '${b['updateTime']}'.compareTo('${a['updateTime']}'));
    return demoPage(sessions, req);
  });

  r.post('/app/user/chat-gpt/sessionCreate', (req) {
    final account = req.account;
    final now = demoTimeText(DateTime.now());
    final session = <String, dynamic>{
      'id': DemoStore.nextId(),
      'title': _clip(req.str('title', '新对话'), 50),
      'robot': req.str('robot', 'DeepSeek'),
      'createTime': now,
      'updateTime': now,
    };
    _sessions(account).add(session);
    _persist(account);
    return session;
  });

  r.post('/app/user/chat-gpt/sessionDelete', (req) {
    final account = req.account;
    final id = req.str('id');
    _sessions(account).removeWhere((s) => s['id'] == id);
    _messages(account).removeWhere((m) => m['sessionId'] == id);
    _persist(account);
    return true;
  });

  r.post('/app/user/chat-gpt/msgList', (req) {
    final sessionId = req.str('sessionId');
    final list = _messages(
      req.account,
    ).where((m) => m['sessionId'] == sessionId).toList();
    final size = req.intOf('size', 100);
    final page = list.length > size ? list.sublist(list.length - size) : list;
    return [for (final m in page) _messageJson(m)];
  });

  r.post('/app/user/chat-gpt/send', (req) {
    final account = req.account;
    final sessionId = req.str('sessionId');
    final session = _sessions(
      account,
    ).where((s) => s['id'] == sessionId).firstOrNull;
    if (session == null) {
      throw const DemoApiException('会话不存在或已被删除，请新建对话');
    }
    final attachments = _attachmentsOf(req);
    final question = _visibleText(req.str('content'));
    if (question.isEmpty && attachments.isEmpty) {
      throw const DemoApiException('请输入问题');
    }
    final answer = DemoAiTutor.answer(
      account: account,
      question: question,
      attachments: [
        for (final a in attachments)
          DemoAiAttachment(
            name: a['name']?.toString() ?? '',
            url: DemoMedia.url(a['ref']?.toString() ?? ''),
          ),
      ],
      webSearch: req.boolOf('isNet'),
    );
    final deep = req.boolOf('isDeep');
    final askedAt = _nextMessageTime(account, sessionId);
    final userMessage = <String, dynamic>{
      'id': DemoStore.nextId(),
      'sessionId': sessionId,
      'role': 'user',
      'content': question.isEmpty ? '请根据附件内容进行分析。' : question,
      'attachments': attachments,
      'createTime': demoTimeText(askedAt),
    };
    final replyMessage = <String, dynamic>{
      'id': DemoStore.nextId(),
      'sessionId': sessionId,
      'role': 'assistant',
      'content': answer.text,
      if (deep) 'reasoningContent': answer.reasoning,
      'createTime': demoTimeText(askedAt.add(const Duration(seconds: 1))),
    };
    _messages(account).addAll([userMessage, replyMessage]);
    session['updateTime'] = replyMessage['createTime'];
    _persist(account);

    unawaited(
      _streamReply(
        sessionId: sessionId,
        reasoning: deep ? answer.reasoning : '',
        text: answer.text,
      ),
    );
    return <String, dynamic>{
      'sessionId': sessionId,
      'msgId': userMessage['id'],
      'replyId': replyMessage['id'],
    };
  });
}

String _sessionsKey(DemoAccount account) =>
    'ai_chat:sessions:${account.userId}';

String _messagesKey(DemoAccount account) =>
    'ai_chat:messages:${account.userId}';

List<Map<String, dynamic>> _sessions(DemoAccount account) => DemoStore.list(
  _sessionsKey(account),
  () => demoCloneSeed([for (final seed in _seedsFor(account)) seed.session]),
);

List<Map<String, dynamic>> _messages(DemoAccount account) => DemoStore.list(
  _messagesKey(account),
  () =>
      demoCloneSeed([for (final seed in _seedsFor(account)) ...seed.messages]),
);

/// 会话与消息来自同一份种子，任何一边改动都一起落盘，避免重启后两边对不上。
void _persist(DemoAccount account) {
  _sessions(account);
  _messages(account);
  DemoStore.save(_sessionsKey(account));
  DemoStore.save(_messagesKey(account));
}

Future<void> _streamReply({
  required String sessionId,
  required String reasoning,
  required String text,
}) async {
  final bridge = DemoSocketBridge.instance;
  if (reasoning.isNotEmpty) {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    for (var i = 0; i < reasoning.length; i += 6) {
      bridge.push(<String, dynamic>{
        'type': 10004,
        'sessionId': sessionId,
        'reasoning_content': reasoning.substring(
          i,
          math.min(i + 6, reasoning.length),
        ),
      });
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
  }
  await bridge.streamAiReply(sessionId: sessionId, text: text);
}

/// 客户端按 createTime（秒级）排序消息，同一会话内的时间必须严格递增，
/// 否则一秒内连发两条时问答会错位。
DateTime _nextMessageTime(DemoAccount account, String sessionId) {
  final now = DateTime.now();
  var next = DateTime(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute,
    now.second,
  );
  for (final m in _messages(account)) {
    if (m['sessionId'] != sessionId) {
      continue;
    }
    final time = DateTime.tryParse('${m['createTime']}');
    if (time != null && !next.isAfter(time)) {
      next = time.add(const Duration(seconds: 1));
    }
  }
  return next;
}

/// 客户端会把附件清单拼进 content（`[附件]` 段），历史消息只保留用户输入的正文。
String _visibleText(String content) {
  final index = content.indexOf('[附件]');
  return (index < 0 ? content : content.substring(0, index)).trim();
}

List<Map<String, dynamic>> _attachmentsOf(DemoRequest req) {
  final raw = req.listOf('attachments').isNotEmpty
      ? req.listOf('attachments')
      : req.listOf('fileList');
  final result = <Map<String, dynamic>>[];
  for (final item in raw) {
    if (item is! Map) {
      continue;
    }
    final url = (item['url'] ?? item['fileUrl'] ?? '').toString().trim();
    if (url.isEmpty) {
      continue;
    }
    result.add(<String, dynamic>{
      'name': (item['name'] ?? item['fileName'] ?? '附件').toString(),
      'ref': demoMediaRefOf(url),
      'size': int.tryParse('${item['size']}') ?? 0,
    });
  }
  return result;
}

Map<String, dynamic> _messageJson(Map<String, dynamic> m) {
  final attachments = m['attachments'];
  return <String, dynamic>{
    'id': m['id'],
    'sessionId': m['sessionId'],
    'role': m['role'],
    'content': m['content'],
    if ((m['reasoningContent']?.toString() ?? '').isNotEmpty)
      'reasoningContent': m['reasoningContent'],
    if (attachments is List && attachments.isNotEmpty)
      'attachments': [
        for (final a in attachments.whereType<Map>())
          <String, dynamic>{
            'name': a['name'],
            'fileName': a['name'],
            'url': DemoMedia.url(a['ref']?.toString() ?? ''),
            'size': a['size'] ?? 0,
          },
      ],
    'createTime': m['createTime'],
  };
}

String _clip(String text, int max) =>
    text.length <= max ? text : '${text.substring(0, max)}...';

class _SeedChat {
  _SeedChat({
    required this.id,
    required this.question,
    required this.reply,
    required DateTime time,
  }) : session = <String, dynamic>{
         'id': id,
         'title': question,
         'robot': 'DeepSeek',
         'createTime': demoTimeText(time),
         'updateTime': demoTimeText(time.add(const Duration(seconds: 1))),
       },
       messages = <Map<String, dynamic>>[
         <String, dynamic>{
           'id': '${id}01',
           'sessionId': id,
           'role': 'user',
           'content': question,
           'attachments': const <Map<String, dynamic>>[],
           'createTime': demoTimeText(time),
         },
         <String, dynamic>{
           'id': '${id}02',
           'sessionId': id,
           'role': 'assistant',
           'content': reply,
           'createTime': demoTimeText(time.add(const Duration(seconds: 1))),
         },
       ];

  final String id;
  final String question;
  final String reply;
  final Map<String, dynamic> session;
  final List<Map<String, dynamic>> messages;
}

final Map<String, List<_SeedChat>> _seedCache = <String, List<_SeedChat>>{};

List<_SeedChat> _seedsFor(DemoAccount account) {
  return _seedCache.putIfAbsent(account.userId, () {
    final questions = account.role == DemoRole.student
        ? const <(String, Duration)>[
            ('素描起形总是不准怎么办？', Duration(hours: 2, minutes: 13)),
            ('色彩画面发灰怎么调整？', Duration(days: 3, hours: 5, minutes: 41)),
            ('联考评分 A–E 档怎么划分？', Duration(days: 12, hours: 3, minutes: 7)),
          ]
        : const <(String, Duration)>[
            ('怎样给学生讲清楚明暗五大调子？', Duration(hours: 5, minutes: 22)),
            ('联考评分 A–E 档怎么划分？', Duration(days: 6, hours: 2, minutes: 48)),
          ];
    return [
      for (var i = 0; i < questions.length; i++)
        _SeedChat(
          id: '900100${i + 1}',
          question: questions[i].$1,
          reply: DemoAiTutor.answer(
            account: account,
            question: questions[i].$1,
          ).text,
          time: DemoClock.ago(questions[i].$2),
        ),
    ];
  });
}
