import '../data/demo_artwork_data.dart';
import '../data/demo_artwork_store.dart';
import '../data/demo_exam_critique_store.dart';
import '../data/demo_marking_data.dart';
import '../demo_accounts.dart';
import '../demo_backend.dart';
import '../demo_clock.dart';
import '../media/demo_media.dart';

/// 月考原卷讲评（阅卷系统 exam-api）：老师按「考试 + 科目」挑代表卷、在卷面上标几处
/// 讲评，发布后学生在成绩报告里听。
///
/// - 教职端 `/school/teacher/exams/{examId}/subjects/{subjectId}/critique*`：
///   读取、保存一张卷子、移出、发布 / 撤回。能不能改由 `access.canEdit` 给出：任教这一科
///   的老师和这一科的教学组长可以改，其他教职只读，学生 403。
/// - 学生端 `/app/study/exams/{examId}/subjects/{subjectId}/critique*`：只给本人看已发布的
///   讲评（代表卷 + 自己的个人点评），教职 403。
void registerMarkingCritiqueFixtures(DemoRouter marking) {
  const staff = '/school/teacher/exams/{examId}/subjects/{subjectId}/critique';
  const student = '/app/study/exams/{examId}/subjects/{subjectId}/critique';

  marking.get(staff, (req) => _staffPayload(_StaffScope.of(req)));

  marking.post('$staff/papers', (req) {
    final scope = _StaffScope.of(req)..requireEdit();
    final archiveId = req.str('archiveId');
    final shared = req.boolOf('shared', true);
    final candidate = scope.candidate(archiveId);
    final critique = DemoExamCritiqueStore.ensure(
      scope.exam.examId,
      scope.def.subjectId,
    );
    final papers = DemoExamCritiqueStore.rawPapers(critique);
    final existing = _paperOf(critique, archiveId, shared);
    if (existing == null &&
        shared &&
        DemoExamCritiqueStore.papersOf(
              critique,
            ).where((p) => p['shared'] == true).length >=
            _sharedLimit) {
      throw const DemoApiException('每科最多选 10 张代表卷', code: 400);
    }
    final body = req.bodyMap;
    final summary = body.containsKey('summary')
        ? _text(body['summary'])
        : _text(existing?['summary']);
    if (summary.runes.length > _summaryLimit) {
      throw const DemoApiException('讲评总结最多 500 个字', code: 400);
    }
    final voiceRef = body.containsKey('voiceUrl')
        ? _text(body['voiceUrl'])
        : _text(existing?['voiceRef']);
    final voiceSeconds = voiceRef.isEmpty
        ? 0
        : (body.containsKey('voiceSeconds')
                  ? _int(body['voiceSeconds'])
                  : _int(existing?['voiceSeconds']))
              .clamp(0, _voiceLimit);
    final marks = _parseMarks(body['marks'], existing?['marks']);
    final now = DemoExamCritiqueStore.fmt(DemoClock.now());
    final account = req.account;
    final paper =
        existing ??
        <String, dynamic>{
          'id': 'cp-${scope.exam.examId}-${scope.def.subjectId}-'
              '${shared ? 's' : 'p'}$archiveId',
          'archiveId': candidate.person.archiveId,
          'shared': shared,
          'notified': false,
        };
    paper
      ..['summary'] = summary
      ..['voiceRef'] = voiceRef
      ..['voiceSeconds'] = voiceSeconds
      ..['marks'] = marks
      ..['updatedTime'] = now
      ..['teacherId'] = account.teacherId ?? ''
      ..['teacherName'] = account.name;
    if (existing == null) {
      papers.add(paper);
    }
    critique
      ..['updatedTime'] = now
      ..['teacherId'] = account.teacherId ?? ''
      ..['teacherName'] = account.name;
    // 已发布的讲评里新录了个人点评：只通知那一位学生，同一张只通知一次。
    if (critique['published'] == true &&
        !shared &&
        paper['notified'] != true &&
        DemoExamCritiqueStore.hasContent(paper)) {
      paper['notified'] = true;
      _notify(
        candidate.person.index,
        scope,
        '【学情】${account.name}老师给你的${_shortExamName(scope.exam.examName)}'
        '${scope.def.subjectName}原卷录了讲评，可以在「学情」查看。',
      );
    }
    DemoExamCritiqueStore.save();
    return _staffPayload(scope);
  });

  marking.post('$staff/papers/delete', (req) {
    final scope = _StaffScope.of(req)..requireEdit();
    final critique = DemoExamCritiqueStore.critique(
      scope.exam.examId,
      scope.def.subjectId,
    );
    final paper = critique == null
        ? null
        : _paperOf(critique, req.str('archiveId'), req.boolOf('shared', true));
    if (critique == null || paper == null) {
      throw const DemoApiException('这张卷子已经不在讲评里了，请刷新后重试', code: 404);
    }
    DemoExamCritiqueStore.rawPapers(critique).remove(paper);
    critique['updatedTime'] = DemoExamCritiqueStore.fmt(DemoClock.now());
    DemoExamCritiqueStore.save();
    return _staffPayload(scope);
  });

  marking.post('$staff/publish', (req) {
    final scope = _StaffScope.of(req)..requireEdit();
    final publish = req.boolOf('published', true);
    final critique = DemoExamCritiqueStore.ensure(
      scope.exam.examId,
      scope.def.subjectId,
    );
    if (!publish) {
      critique['published'] = false;
      DemoExamCritiqueStore.save();
      return _staffPayload(scope);
    }
    final ready = DemoExamCritiqueStore.papersOf(
      critique,
    ).where(DemoExamCritiqueStore.hasContent).toList();
    if (ready.isEmpty) {
      throw const DemoApiException('先给至少一张卷子录上讲评，再发布', code: 400);
    }
    final wasPublished = critique['published'] == true;
    final now = DemoExamCritiqueStore.fmt(DemoClock.now());
    critique
      ..['published'] = true
      ..['showNames'] = req.boolOf('showNames')
      ..['updatedTime'] = now;
    if (!wasPublished) {
      final account = req.account;
      critique
        ..['publishTime'] = now
        ..['teacherId'] = account.teacherId ?? ''
        ..['teacherName'] = account.name;
      final title =
          '${_shortExamName(scope.exam.examName)}${scope.def.subjectName}讲评';
      for (final entry in DemoMarkingData.instance.entriesOfExam(
        scope.exam.examId,
      )) {
        if (!entry.scored) continue;
        final mine = ready.any(
          (p) => p['shared'] != true && p['archiveId'] == entry.person.archiveId,
        );
        _notify(
          entry.person.index,
          scope,
          mine
              ? '【学情】$title已发布，${account.name}老师还看了你的原卷，可以在「学情」查看。'
              : '【学情】$title已发布，可以在「学情」对照代表卷查看。',
        );
      }
      for (final paper in ready) {
        if (paper['shared'] != true) paper['notified'] = true;
      }
    }
    DemoExamCritiqueStore.save();
    return _staffPayload(scope);
  });

  marking.get(student, (req) {
    final scope = _StudentScope.of(req);
    final critique = DemoExamCritiqueStore.critique(
      scope.exam.examId,
      scope.def.subjectId,
    );
    final papers = critique == null || critique['published'] != true
        ? const <Map<String, dynamic>>[]
        : DemoExamCritiqueStore.visiblePapers(critique, scope.person.index);
    final showNames = critique?['showNames'] == true;
    final readBy = critique?['readBy'];
    final candidates = {
      for (final c in DemoExamCritiqueStore.candidates(
        scope.exam.examId,
        scope.def.subjectId,
      ))
        c.person.archiveId: c,
    };
    return <String, dynamic>{
      'exam': _examJson(scope.exam),
      'subject': _subjectJson(scope.def),
      'published': papers.isNotEmpty,
      'showNames': showNames,
      'publishTime': _text(critique?['publishTime']),
      'teacherName': _text(critique?['teacherName']),
      'watermarkText':
          '${scope.person.name} ${scope.entry.admissionNo} · 仅供本人学习',
      'myGrade': scope.score.grade,
      'myScore': scope.score.score,
      'read': readBy is List && readBy.contains('${scope.person.index}'),
      'bands': [
        for (final band in DemoMarkingData.bandsFor(scope.def))
          <String, dynamic>{
            'grade': band.grade,
            'min': band.min,
            'max': band.max,
          },
      ],
      'papers': [
        for (final paper in papers)
          if (candidates[_text(paper['archiveId'])] case final candidate?)
            _studentPaperJson(
              paper,
              candidate,
              own: candidate.person.index == scope.person.index,
              showNames: showNames,
            ),
      ],
    };
  });

  marking.post('$student/read', (req) {
    final scope = _StudentScope.of(req);
    final critique = DemoExamCritiqueStore.critique(
      scope.exam.examId,
      scope.def.subjectId,
    );
    if (critique == null ||
        critique['published'] != true ||
        DemoExamCritiqueStore.visiblePapers(
          critique,
          scope.person.index,
        ).isEmpty) {
      throw const DemoApiException('这一科还没有发布讲评', code: 404);
    }
    DemoExamCritiqueStore.markRead(critique, scope.person.index);
    return <String, dynamic>{'read': true};
  });
}

const _sharedLimit = 10;
const _summaryLimit = 500;
const _marksPerPaper = 20;
const _markTextLimit = 200;
const _voiceLimit = 120;

String _text(Object? raw) {
  if (raw == null) return '';
  final text = raw.toString().trim();
  return text == 'null' ? '' : text;
}

int _int(Object? raw) =>
    raw is num ? raw.toInt() : int.tryParse(_text(raw)) ?? 0;

/// 「2026 年 9 月月考」在消息和今日清单里说成「9 月月考」。
String _shortExamName(String name) =>
    name.replaceFirst(RegExp(r'^\d{4}\s*年\s*'), '');

DemoExamDef _examOf(String examId) {
  final exam = DemoMarkingData.instance.exam(examId);
  if (exam == null) {
    throw const DemoApiException('考试不存在或已撤销', code: 404);
  }
  if (!exam.reviewed) {
    throw const DemoApiException('这场考试还在阅卷中，出分后才能讲评', code: 409);
  }
  return exam;
}

DemoSubjectDef _subjectOf(DemoExamDef exam, String subjectId) {
  for (final subject in exam.subjects) {
    if (subject.subjectId == subjectId) return subject;
  }
  throw const DemoApiException('这场考试没有该科目', code: 404);
}

/// 任教这一科的老师（作品点评老师名册里同一科目）和这一科的教学组长可以改讲评。
bool critiqueEditableBy(DemoAccount account, String subjectName) {
  if (!account.role.teaches) return false;
  if (account.groupLeaderSubjects.contains(subjectName)) return true;
  final teacherId = account.teacherId;
  return teacherId != null &&
      DemoMarkingData.reviewTeachers.any(
        (t) => t.id == teacherId && t.subject == subjectName,
      );
}

class _StaffScope {
  _StaffScope(this.account, this.exam, this.def);

  factory _StaffScope.of(DemoRequest req) {
    final account = req.account;
    if (!account.role.isStaff) {
      throw const DemoApiException('讲评由老师录入，学生请在「学情」查看', code: 403);
    }
    final exam = _examOf(req.param('examId'));
    return _StaffScope(account, exam, _subjectOf(exam, req.param('subjectId')));
  }

  final DemoAccount account;
  final DemoExamDef exam;
  final DemoSubjectDef def;

  bool get canEdit => critiqueEditableBy(account, def.subjectName);

  void requireEdit() {
    if (!canEdit) {
      throw DemoApiException('只有任教${def.subjectName}的老师和组长可以修改讲评', code: 403);
    }
  }

  late final List<DemoCritiqueCandidate> candidates =
      DemoExamCritiqueStore.candidates(exam.examId, def.subjectId);

  DemoCritiqueCandidate candidate(String archiveId) {
    for (final c in candidates) {
      if (c.person.archiveId == archiveId) return c;
    }
    throw const DemoApiException('这位学生这一科没有可讲评的原卷', code: 400);
  }
}

class _StudentScope {
  _StudentScope(this.person, this.exam, this.def, this.entry, this.score);

  factory _StudentScope.of(DemoRequest req) {
    final account = req.account;
    final index = account.personIndex;
    if (account.role != DemoRole.student || index == null) {
      throw const DemoApiException('讲评的学生视图只给学生本人查看', code: 403);
    }
    final exam = _examOf(req.param('examId'));
    final def = _subjectOf(exam, req.param('subjectId'));
    final entry = DemoMarkingData.instance.entryOf(index, exam.examId);
    final score = entry?.subject(def.subjectId);
    if (entry == null || score == null) {
      throw const DemoApiException('这场考试暂无该科成绩', code: 404);
    }
    return _StudentScope(entry.person, exam, def, entry, score);
  }

  final DemoPerson person;
  final DemoExamDef exam;
  final DemoSubjectDef def;
  final DemoExamEntry entry;
  final DemoSubjectScore score;
}

Map<String, dynamic>? _paperOf(
  Map<String, dynamic> critique,
  String archiveId,
  bool shared,
) {
  for (final paper in DemoExamCritiqueStore.papersOf(critique)) {
    if (_text(paper['archiveId']) == archiveId &&
        (paper['shared'] == true) == shared) {
      return paper;
    }
  }
  return null;
}

/// 学情消息（targetType 1）点开是这场考试的成绩报告。只有带演示账号的学生收得到。
void _notify(int personIndex, _StaffScope scope, String content) {
  final userId = DemoArtworkData.userIdOfStudent(personIndex);
  if (userId == null) return;
  DemoArtworkStore.appendNotice(
    userId: userId,
    content: content,
    targetType: 1,
    targetId: scope.exam.examId,
  );
}

Map<String, dynamic> _examJson(DemoExamDef exam) => <String, dynamic>{
  'examId': exam.examId,
  'examName': exam.examName,
  'examTime': '${exam.examDate} 08:30:00',
};

Map<String, dynamic> _subjectJson(DemoSubjectDef def) => <String, dynamic>{
  'subjectId': def.subjectId,
  'subjectName': def.subjectName,
  'fullScore': def.fullScore,
};

List<Map<String, dynamic>> _marksJson(Object? raw) => [
  if (raw is List)
    for (final item in raw)
      if (item is Map)
        <String, dynamic>{
          'id': _text(item['id']),
          'imageIndex': 0,
          'x': item['x'],
          'y': item['y'],
          'text': _text(item['text']),
          'voiceUrl': _text(item['voiceRef']),
          'voiceSeconds': _int(item['voiceSeconds']),
        },
];

Map<String, dynamic> _paperJson(
  Map<String, dynamic> paper,
  DemoCritiqueCandidate candidate,
) => <String, dynamic>{
  'id': _text(paper['id']),
  'shared': paper['shared'] == true,
  'summary': _text(paper['summary']),
  'voiceUrl': _text(paper['voiceRef']),
  'voiceSeconds': _int(paper['voiceSeconds']),
  'marks': _marksJson(paper['marks']),
  'updatedTime': _text(paper['updatedTime']),
  'teacherName': _text(paper['teacherName']),
  'score': candidate.score,
  'grade': candidate.grade,
  'imageUrl': DemoMedia.url(candidate.imageRef),
};

Map<String, dynamic> _studentPaperJson(
  Map<String, dynamic> paper,
  DemoCritiqueCandidate candidate, {
  required bool own,
  required bool showNames,
}) {
  final mine = own && paper['shared'] != true;
  return <String, dynamic>{
    ..._paperJson(paper, candidate),
    if (own) 'archiveId': candidate.person.archiveId,
    'mine': mine,
    'studentName': own || showNames ? candidate.person.name : '',
  };
}

Map<String, dynamic> _staffPayload(_StaffScope scope) {
  final bands = DemoMarkingData.bandsFor(scope.def);
  final candidates = scope.candidates;
  final suggested = DemoExamCritiqueStore.suggestedArchiveIds(
    candidates,
    bands,
  ).values.toSet();
  final byArchive = {for (final c in candidates) c.person.archiveId: c};
  final critique = DemoExamCritiqueStore.critique(
    scope.exam.examId,
    scope.def.subjectId,
  );
  return <String, dynamic>{
    'exam': _examJson(scope.exam),
    'subject': _subjectJson(scope.def),
    'bands': [
      for (final band in bands)
        <String, dynamic>{
          'grade': band.grade,
          'min': band.min,
          'max': band.max,
          'count': candidates.where((c) => c.grade == band.grade).length,
        },
    ],
    'papers': [
      for (final c in candidates)
        <String, dynamic>{
          'archiveId': c.person.archiveId,
          'studentName': c.person.name,
          'organizationName': c.person.organizationName,
          'score': c.score,
          'grade': c.grade,
          'imageUrl': DemoMedia.url(c.imageRef),
          'suggested': suggested.contains(c.person.archiveId),
        },
    ],
    'critique': critique == null
        ? null
        : <String, dynamic>{
            'published': critique['published'] == true,
            'showNames': critique['showNames'] == true,
            'publishTime': _text(critique['publishTime']),
            'teacherName': _text(critique['teacherName']),
            'updatedTime': _text(critique['updatedTime']),
            'papers': [
              for (final paper in DemoExamCritiqueStore.papersOf(critique))
                if (byArchive[_text(paper['archiveId'])] case final c?)
                  <String, dynamic>{
                    ..._paperJson(paper, c),
                    'archiveId': c.person.archiveId,
                    'studentName': c.person.name,
                    'organizationName': c.person.organizationName,
                  },
            ],
          },
    'access': <String, dynamic>{'canEdit': scope.canEdit},
  };
}

/// 卷面上的几处讲评整组替换，规则与作品定点点评一致：不传沿用上次，空列表清除；
/// 每张最多 20 处，每处文字最多 200 字，文字和语音至少一样；卷子只有一张图，序号只能是 0。
List<Map<String, dynamic>> _parseMarks(Object? raw, Object? previous) {
  if (raw == null) {
    return [
      if (previous is List)
        for (final item in previous)
          if (item is Map<String, dynamic>) item,
    ];
  }
  if (raw is! List) {
    throw const DemoApiException('讲评标记格式无效', code: 400);
  }
  if (raw.length > _marksPerPaper) {
    throw const DemoApiException('每张卷子最多标 20 处', code: 400);
  }
  final ids = <String>{};
  final marks = <Map<String, dynamic>>[];
  for (final item in raw) {
    if (item is! Map) {
      throw const DemoApiException('讲评标记格式无效', code: 400);
    }
    final imageIndex = item['imageIndex'] == null ? 0 : _int(item['imageIndex']);
    if (imageIndex != 0) {
      throw const DemoApiException('讲评标记的图片序号无效，请刷新后重试', code: 400);
    }
    double? coordinate(Object? value) {
      final number = value is num ? value.toDouble() : double.tryParse('$value');
      return number == null || !number.isFinite ? null : number.clamp(0.0, 1.0);
    }

    final x = coordinate(item['x']);
    final y = coordinate(item['y']);
    if (x == null || y == null) {
      throw const DemoApiException('讲评标记的位置无效', code: 400);
    }
    final text = _text(item['text']);
    if (text.runes.length > _markTextLimit) {
      throw const DemoApiException('每处讲评最多 200 个字', code: 400);
    }
    final voiceRef = _text(item['voiceUrl'] ?? item['voiceRef']);
    if (text.isEmpty && voiceRef.isEmpty) {
      throw const DemoApiException('每处讲评要写一句话或录一段语音', code: 400);
    }
    var id = _text(item['id']);
    if (id.isEmpty || id.length > 40 || ids.contains(id)) {
      var n = marks.length + 1;
      while (ids.contains('mk-$n')) {
        n++;
      }
      id = 'mk-$n';
    }
    ids.add(id);
    marks.add(<String, dynamic>{
      'id': id,
      'imageIndex': 0,
      'x': (x * 10000).round() / 10000,
      'y': (y * 10000).round() / 10000,
      'text': text,
      'voiceRef': voiceRef,
      'voiceSeconds': voiceRef.isEmpty
          ? 0
          : _int(item['voiceSeconds']).clamp(0, _voiceLimit),
    });
  }
  return marks;
}
