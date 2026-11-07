import 'dart:math' as math;

import '../demo_accounts.dart';
import '../demo_backend.dart';
import '../demo_store.dart';
import 'interaction_common.dart';
import 'interaction_quiz_bank.dart';

const _types = <String>['sequence', 'random', 'exam', 'error'];

/// 美术常识题库：每个账号、每个 schoolId 一本练习簿，
/// 含顺序 / 随机 / 高频考点 / 错题本四类练习和一份错题记录。
void registerQuizFixtures(DemoRouter r) {
  r.post('/app/user/questionPracticeSummary', (req) {
    final book = _book(req);
    _syncErrorPractice(book);
    DemoStore.save(_key(req));
    return <String, dynamic>{
      for (final type in _types) type: _summary(_practice(book, type)),
    };
  });

  r.post('/app/user/questionPracticeCreate', (req) {
    final type = req.str('practiceType');
    if (!_types.contains(type)) {
      throw const DemoApiException('未知的练习类型');
    }
    final book = _book(req);
    final practice = _create(book, type, size: req.intOf('size', 25));
    DemoStore.save(_key(req));
    return _summary(practice);
  });

  r.post('/app/user/questionPracticeItemList', (req) {
    final practice = _practiceById(_book(req), req.intOf('practiceId'));
    if (practice == null) {
      throw const DemoApiException('练习不存在，请返回刷新后重试');
    }
    return [for (final item in _items(practice)) _itemJson(item)];
  });

  r.post('/app/user/questionPracticeItemReport', (req) {
    final book = _book(req);
    final itemId = req.intOf('questionPracticeItemId');
    final practice = _practiceById(book, itemId ~/ 100);
    final item = practice == null
        ? null
        : _items(practice).where((i) => _int(i['id']) == itemId).firstOrNull;
    if (practice == null || item == null) {
      throw const DemoApiException('题目不存在，请刷新后重试');
    }
    final question = _question(_int(item['qid']));
    final answer = req.intOf('answer', -1);
    if (answer < 0 || answer >= question.options.length) {
      throw const DemoApiException('请选择一个选项');
    }
    if (_int(item['status']) == 0) {
      final correct = answer == question.answer;
      item['answer'] = answer;
      item['status'] = correct ? 1 : 2;
      final wrong = _wrong(book);
      if (practice['type'] == 'error') {
        if (correct) {
          wrong.remove(question.id);
        }
      } else if (!correct && !wrong.contains(question.id)) {
        wrong.add(question.id);
      }
      DemoStore.save(_key(req));
    }
    return <String, dynamic>{
      'status': item['status'],
      'answer': item['answer'],
      'correctAnswer': question.answer,
    };
  });
}

String _key(DemoRequest req) =>
    'quiz:${req.account.userId}:${req.str('schoolId', '0')}';

Map<String, dynamic> _book(DemoRequest req) => DemoStore.map(
  _key(req),
  () => _seedBook(req.account, req.str('schoolId', '0')),
);

/// 演示学生在公开题库里已做了 18 道顺序练习（错 4 道），其余身份从零开始。
Map<String, dynamic> _seedBook(DemoAccount account, String schoolId) {
  final book = <String, dynamic>{
    'practices': <String, dynamic>{},
    'wrong': <int>[],
  };
  if (account.role != DemoRole.student || schoolId != '0') {
    return book;
  }
  final practice = _newPractice('sequence', [
    for (final q in demoQuizBank) q.id,
  ]);
  final items = _items(practice);
  const wrongIndexes = <int>{4, 11, 13, 16};
  for (var i = 0; i < 18; i++) {
    final question = demoQuizBank[i];
    final wrong = wrongIndexes.contains(i);
    items[i]['answer'] = wrong ? (question.answer + 1) % 4 : question.answer;
    items[i]['status'] = wrong ? 2 : 1;
    if (wrong) {
      _wrong(book).add(question.id);
    }
  }
  _practices(book)['sequence'] = practice;
  return book;
}

Map<String, dynamic> _create(
  Map<String, dynamic> book,
  String type, {
  required int size,
}) {
  final existing = _practice(book, type);
  final Map<String, dynamic> practice;
  switch (type) {
    case 'sequence':
      practice =
          existing ?? _newPractice(type, [for (final q in demoQuizBank) q.id]);
    case 'exam':
      practice = existing != null && !_complete(existing)
          ? existing
          : _newPractice(type, demoQuizExamIds);
    case 'error':
      final wrong = _wrong(book);
      if (wrong.isEmpty) {
        throw const DemoApiException('错题本还是空的，做错的题会自动收进来');
      }
      practice = _newPractice(type, [...wrong]);
    default:
      final ids = [for (final q in demoQuizBank) q.id]..shuffle(math.Random());
      practice = _newPractice(
        type,
        ids.take(size.clamp(5, ids.length)).toList(),
      );
  }
  _practices(book)[type] = practice;
  return practice;
}

/// 错题本练习随错题记录更新：一轮做完后按最新错题重建，进行中只追加新错题。
void _syncErrorPractice(Map<String, dynamic> book) {
  final wrong = _wrong(book);
  final current = _practice(book, 'error');
  if (current == null || _complete(current)) {
    if (wrong.isEmpty) {
      _practices(book).remove('error');
    } else {
      _practices(book)['error'] = _newPractice('error', [...wrong]);
    }
    return;
  }
  final items = _items(current);
  final present = items.map((i) => _int(i['qid'])).toSet();
  final practiceId = _int(current['practiceId']);
  for (final qid in wrong) {
    if (!present.contains(qid)) {
      items.add(_newItem(practiceId, items.length, qid));
    }
  }
}

Map<String, dynamic> _newPractice(String type, List<int> questionIds) {
  final practiceId = int.parse(DemoStore.nextId());
  return <String, dynamic>{
    'practiceId': practiceId,
    'type': type,
    'createTime': demoTimeText(DateTime.now()),
    'items': <Map<String, dynamic>>[
      for (var i = 0; i < questionIds.length; i++)
        _newItem(practiceId, i, questionIds[i]),
    ],
  };
}

/// 题目 id = 练习 id × 100 + 序号，上报答案时可由题目 id 反查所属练习。
Map<String, dynamic> _newItem(int practiceId, int index, int questionId) =>
    <String, dynamic>{
      'id': practiceId * 100 + index + 1,
      'qid': questionId,
      'answer': null,
      'status': 0,
    };

Map<String, dynamic> _summary(Map<String, dynamic>? practice) {
  if (practice == null) {
    return <String, dynamic>{
      'practiceId': null,
      'allCount': 0,
      'doneCount': 0,
      'errorCount': 0,
      'notDoneCount': 0,
      'status': null,
    };
  }
  final items = _items(practice);
  final done = items.where((i) => _int(i['status']) != 0).length;
  final wrong = items.where((i) => _int(i['status']) == 2).length;
  return <String, dynamic>{
    'practiceId': practice['practiceId'],
    'allCount': items.length,
    'doneCount': done,
    'errorCount': wrong,
    'notDoneCount': items.length - done,
    'status': 1,
  };
}

Map<String, dynamic> _itemJson(Map<String, dynamic> item) {
  final question = _question(_int(item['qid']));
  final status = _int(item['status']);
  return <String, dynamic>{
    'id': item['id'],
    'answer': status == 0 ? null : item['answer'],
    'status': status,
    'question': <String, dynamic>{
      'id': question.id,
      'category': question.category,
      'question': question.questionHtml,
      'param1': question.options[0],
      'param2': question.options[1],
      'param3': question.options[2],
      'param4': question.options[3],
      'answer': question.answer,
      'parse': question.parseHtml,
    },
  };
}

DemoQuizQuestion _question(int id) => demoQuizBank.firstWhere(
  (q) => q.id == id,
  orElse: () => demoQuizBank.first,
);

bool _complete(Map<String, dynamic> practice) {
  final items = _items(practice);
  return items.isNotEmpty && items.every((i) => _int(i['status']) != 0);
}

Map<String, dynamic>? _practiceById(Map<String, dynamic> book, int id) {
  for (final type in _types) {
    final practice = _practice(book, type);
    if (practice != null && _int(practice['practiceId']) == id) {
      return practice;
    }
  }
  return null;
}

Map<String, dynamic> _practices(Map<String, dynamic> book) {
  final raw = book['practices'];
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  final typed = <String, dynamic>{};
  book['practices'] = typed;
  return typed;
}

Map<String, dynamic>? _practice(Map<String, dynamic> book, String type) {
  final raw = _practices(book)[type];
  return raw is Map<String, dynamic> ? raw : null;
}

List<Map<String, dynamic>> _items(Map<String, dynamic> practice) {
  final raw = practice['items'];
  if (raw is List<Map<String, dynamic>>) {
    return raw;
  }
  final typed = <Map<String, dynamic>>[
    if (raw is List)
      for (final e in raw)
        if (e is Map<String, dynamic>) e,
  ];
  practice['items'] = typed;
  return typed;
}

List<int> _wrong(Map<String, dynamic> book) {
  final raw = book['wrong'];
  if (raw is List<int>) {
    return raw;
  }
  final typed = <int>[
    if (raw is List)
      for (final e in raw) _int(e),
  ];
  book['wrong'] = typed;
  return typed;
}

int _int(Object? raw) =>
    raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}') ?? 0;
