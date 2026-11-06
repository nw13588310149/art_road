import 'dart:math' as math;

import '../data/demo_marking_data.dart';
import '../demo_backend.dart';
import '../media/demo_media.dart';

/// 学情中心演示接口（阅卷系统 exam-api）：学生「我的学情」与教职「班级学情」。
void registerMarkingStudyFixtures(DemoRouter marking) {
  // ── 学生端（app-token）──────────────────────────────────────────────

  marking.get('/app/study/overview', (req) {
    final index = _studentIndex(req);
    final person = _data.person(index);
    final newestFirst = _data.entriesOf(index).reversed.toList();
    DemoExamEntry? recent;
    for (final entry in newestFirst) {
      if (entry.scored) {
        recent = entry;
        break;
      }
    }
    final published = newestFirst.where((e) => e.exam.reviewed).length;
    final recentChanges = recent == null ? null : _changesOf(recent);
    return <String, dynamic>{
      'profile': <String, dynamic>{
        'archiveId': person.archiveId,
        'name': person.name,
        'gender': person.gender,
        'idCardMasked': person.idCardMasked,
        'avatarUrl': DemoMedia.url(person.avatarRef),
        'organizationName': person.organizationName,
        'schoolName': DemoMarkingData.schoolName,
      },
      'statistics': <String, dynamic>{
        'total': newestFirst.length,
        'published': published,
        'pending': newestFirst.length - published,
      },
      'recentStage': recent == null
          ? null
          : <String, dynamic>{
              'exam': _examRecord(recent),
              'scoreChange': recentChanges?.score,
              'rankingChange': recentChanges?.ranking,
            },
      'exams': [for (final entry in newestFirst.take(6)) _examRecord(entry)],
    };
  });

  marking.get('/app/study/exams', (req) {
    final status = req.str('status', 'ALL').toUpperCase();
    final records = [
      for (final entry in _data.entriesOf(_studentIndex(req)).reversed)
        if (switch (status) {
          'PUBLISHED' => entry.exam.reviewed,
          'MARKING' => !entry.exam.reviewed,
          _ => true,
        })
          _examRecord(entry),
    ];
    return demoPage(records, req);
  });

  marking.get('/app/study/exams/{examId}', (req) {
    return _examReport(_entryOf(_studentIndex(req), req.param('examId')));
  });

  marking.get('/app/study/exams/{examId}/papers/{subjectId}', (req) {
    final index = _studentIndex(req);
    final entry = _entryOf(index, req.param('examId'));
    final def = _subjectDef(entry.exam, req.param('subjectId'));
    final score = entry.subject(def.subjectId);
    final available = score != null && score.result.judges.isNotEmpty;
    final expires = DateTime.now().add(const Duration(minutes: 30));
    return <String, dynamic>{
      'subjectId': def.subjectId,
      'subjectName': def.subjectName,
      'paperAvailable': available,
      'imageUrl': available
          ? DemoMedia.url(
              DemoMarkingData.paperRef(
                def.subjectName,
                index,
                entry.exam.examId,
              ),
            )
          : '',
      'watermarkText': '${entry.person.name} ${entry.admissionNo} · 仅供本人学习',
      'urlExpiresTime': _dateTime(expires),
      'message': available
          ? ''
          : score != null
          ? '该科成绩为手工录入，暂无扫描原卷'
          : entry.exam.reviewed
          ? '本场考试暂无该科成绩'
          : '阅卷中，出分后可查看原卷',
    };
  });

  marking.get('/app/study/exams/{examId}/subjects/{subjectId}/standard', (req) {
    final exam = _examOf(req.param('examId'));
    final def = _subjectDef(exam, req.param('subjectId'));
    return <String, dynamic>{
      'subjectId': def.subjectId,
      'subjectName': def.subjectName,
      'fullScore': def.fullScore,
      'algorithm': def.trimmed ? 'trimmed' : 'mean',
      'diffThreshold': def.diffThreshold,
      'bands': [
        for (final band in DemoMarkingData.bandsFor(def))
          <String, dynamic>{
            'grade': band.grade,
            'min': band.min,
            'max': band.max,
            'description': band.description,
            'imageUrl': DemoMedia.url(band.imageRef),
          },
      ],
    };
  });

  marking.get('/app/study/growth', (req) {
    final index = _studentIndex(req);
    final subjectName = req.str('subjectName');
    final ranking = req.str('metric', 'SCORE').toUpperCase() == 'RANKING';
    final limit = math.max(1, math.min(20, req.intOf('limit', 7)));
    final entries = _data.entriesOf(index);
    final points = <Map<String, dynamic>>[];
    double? previousValue;
    for (final entry in entries.where((e) => e.scored)) {
      final double? score;
      final int? rank;
      final double maxScore;
      if (subjectName.isEmpty) {
        score = entry.total;
        rank = entry.totalRanking;
        maxScore = entry.exam.fullScore;
      } else {
        final subject = _subjectByName(entry, subjectName);
        if (subject == null) continue;
        score = subject.score;
        rank = subject.ranking;
        maxScore = subject.def.fullScore;
      }
      final value = ranking ? rank?.toDouble() : score;
      final before = previousValue;
      points.add(<String, dynamic>{
        'examId': entry.exam.examId,
        'examName': entry.exam.examName,
        'examTime': _examTime(entry.exam),
        'score': score,
        'maxScore': maxScore,
        'ranking': rank,
        'participantCount': _data.participantCount(entry.exam.examId),
        'value': value,
        'change': value == null || before == null
            ? null
            : ranking
            ? before - value
            : _round(value - before, 2),
      });
      previousValue = value;
    }
    final window = points.length > limit
        ? points.sublist(points.length - limit)
        : points;
    final values = [
      for (final point in window)
        if (point['value'] is double) point['value'] as double,
    ];
    return <String, dynamic>{
      'tabs': [
        <String, dynamic>{'subjectName': null, 'label': '总分'},
        for (final name in _subjectNamesOf(entries))
          <String, dynamic>{'subjectName': name, 'label': name},
      ],
      'points': window,
      'statistics': <String, dynamic>{
        'valueCount': values.length,
        'bestValue': values.isEmpty
            ? null
            : values.reduce(
                (a, b) => ranking ? (a < b ? a : b) : (a > b ? a : b),
              ),
        'averageValue': values.isEmpty
            ? null
            : _round(values.reduce((a, b) => a + b) / values.length, 1),
        'latestValue': window.isEmpty ? null : window.last['value'],
        'recentChange': window.isEmpty ? null : window.last['change'],
      },
    };
  });

  // ── 教职端（school-token）───────────────────────────────────────────

  marking.get('/school/teacher/exams', (req) {
    _requireStaff(req);
    return [
      for (final exam in _data.exams.reversed)
        <String, dynamic>{
          'examId': exam.examId,
          'examName': exam.examName,
          'examTime': _examTime(exam),
          'reviewStatus': exam.reviewed ? 1 : 0,
          'participantCount': exam.reviewed
              ? _data.participantCount(exam.examId)
              : _data.entriesOfExam(exam.examId).length,
          'subjects': [
            for (final subject in exam.subjects)
              <String, dynamic>{
                'subjectId': subject.subjectId,
                'subjectName': subject.subjectName,
                'fullScore': subject.fullScore,
              },
          ],
        },
    ];
  });

  marking.post('/school/score-query/page', (req) {
    _requireStaff(req);
    final exam = _examOf(req.str('examId'));
    const unranked = 1 << 30;
    final scored =
        _data.entriesOfExam(exam.examId).where((e) => e.scored).toList()
          ..sort((a, b) {
            final byRank = (a.totalRanking ?? unranked).compareTo(
              b.totalRanking ?? unranked,
            );
            return byRank != 0
                ? byRank
                : a.person.index.compareTo(b.person.index);
          });
    final matched = demoSearch(
      scored,
      req.str('studentName'),
      (entry) => [entry.person.name, entry.admissionNo],
    );
    return demoPage([for (final entry in matched) _scoreRow(entry)], req);
  });

  marking.post('/school/marking/gradeRule', (req) {
    _requireStaff(req);
    final def = _subjectDef(_examOf(req.str('examId')), req.str('subjectId'));
    return <String, dynamic>{
      'score': def.fullScore,
      'gradeList': [
        for (final band in DemoMarkingData.bandsFor(def))
          <String, dynamic>{
            'grade': band.grade,
            'min': band.min,
            'max': band.max,
            'imgUrl': DemoMedia.url(band.imageRef),
            'imgUrlDesc': band.description,
          },
      ],
      'algorithm': def.trimmed ? 1 : 0,
      'diffThreshold': def.diffThreshold,
    };
  });

  marking.get('/school/teacher/students/{archiveId}/exams/{examId}', (req) {
    _requireStaff(req);
    final person = _personOf(req.param('archiveId'));
    return _examReport(_entryOf(person.index, req.param('examId')));
  });

  marking.get(
    '/school/teacher/students/{archiveId}/exams/{examId}/subjects/{subjectId}/marking',
    (req) {
      _requireStaff(req);
      final person = _personOf(req.param('archiveId'));
      final entry = _entryOf(person.index, req.param('examId'));
      final def = _subjectDef(entry.exam, req.param('subjectId'));
      final score = entry.subject(def.subjectId);
      if (score == null) {
        throw const DemoApiException('该科暂无成绩，阅卷完成后可查看明细', code: 404);
      }
      final bands = DemoMarkingData.bandsFor(def);
      final result = score.result;
      return <String, dynamic>{
        'review': <String, dynamic>{
          'paperUrl': result.judges.isEmpty
              ? ''
              : DemoMedia.url(
                  DemoMarkingData.paperRef(
                    def.subjectName,
                    person.index,
                    entry.exam.examId,
                  ),
                ),
          'finalScore': score.score,
          'finalGrade': score.grade,
          'algorithm': def.trimmed ? 1 : 0,
          'diffThreshold': def.diffThreshold,
          'arbitrationStatus': result.arbitration == null ? null : 'RESOLVED',
          'everArbitrated': result.arbitration != null,
          'finalScoreOverridden': false,
          'teachers': [
            for (var i = 0; i < result.judges.length; i++)
              <String, dynamic>{
                'teacherName': DemoMarkingData.teacherOf(
                  def.subjectName,
                  person.index,
                  i,
                ),
                'score': result.judges[i],
                'grade': DemoMarkingData.gradeOf(result.judges[i], bands),
                'comment': i < result.comments.length
                    ? result.comments[i]
                    : DemoMarkingData.commentFor(
                        def.subjectName,
                        person.index,
                        i,
                      ),
              },
          ],
        },
        'maxScore': def.fullScore,
        'bands': [
          for (final band in bands)
            <String, dynamic>{
              'grade': band.grade,
              'minScore': band.min,
              'maxScore': band.max,
              'description': band.description,
              'imageUrl': DemoMedia.url(band.imageRef),
            },
        ],
      };
    },
  );

  marking.get('/school/teacher/students/{archiveId}/curve', (req) {
    _requireStaff(req);
    final person = _personOf(req.param('archiveId'));
    final subject = req.str('subject', 'TOTAL');
    final total = subject.toUpperCase() == 'TOTAL';
    final limit = req.intOf('limit');
    final entries = _data.entriesOf(person.index);
    final points = <Map<String, dynamic>>[];
    double? previousScore;
    for (final entry in entries.where((e) => e.scored)) {
      final double? score;
      final int? ranking;
      final double maxScore;
      if (total) {
        score = entry.total;
        ranking = entry.totalRanking;
        maxScore = entry.exam.fullScore;
      } else {
        final record = _subjectByName(entry, subject);
        if (record == null) continue;
        score = record.score;
        ranking = record.ranking;
        maxScore = record.def.fullScore;
      }
      final before = previousScore;
      points.add(<String, dynamic>{
        'examId': entry.exam.examId,
        'examName': entry.exam.examName,
        'examTime': _examTime(entry.exam),
        'score': score,
        'ranking': ranking,
        'scoreChange': score == null || before == null
            ? null
            : _round(score - before, 2),
        'maxScore': maxScore,
      });
      previousScore = score;
    }
    return <String, dynamic>{
      'points': limit > 0 && points.length > limit
          ? points.sublist(points.length - limit)
          : points,
      'subjects': _subjectNamesOf(entries),
    };
  });
}

DemoMarkingData get _data => DemoMarkingData.instance;

int _studentIndex(DemoRequest req) => req.account.personIndex ?? 1;

void _requireStaff(DemoRequest req) {
  if (!req.account.role.isStaff) {
    throw const DemoApiException('当前账号没有教职权限，无法查看班级学情', code: 403);
  }
}

DemoPerson _personOf(String archiveId) {
  final person = _data.personByArchiveId(archiveId);
  if (person == null) {
    throw const DemoApiException('未找到该学生档案', code: 404);
  }
  return person;
}

DemoExamDef _examOf(String examId) {
  final exam = _data.exam(examId);
  if (exam == null) {
    throw const DemoApiException('考试不存在或已撤销', code: 404);
  }
  return exam;
}

DemoExamEntry _entryOf(int personIndex, String examId) {
  final entry = _data.entryOf(personIndex, examId);
  if (entry == null) {
    throw const DemoApiException('未找到这场考试的报名记录', code: 404);
  }
  return entry;
}

DemoSubjectDef _subjectDef(DemoExamDef exam, String subjectId) {
  for (final subject in exam.subjects) {
    if (subject.subjectId == subjectId) return subject;
  }
  throw const DemoApiException('这场考试没有该科目', code: 404);
}

DemoSubjectScore? _subjectByName(DemoExamEntry entry, String subjectName) {
  for (final subject in entry.subjects ?? const <DemoSubjectScore>[]) {
    if (subject.def.subjectName == subjectName) return subject;
  }
  return null;
}

List<String> _subjectNamesOf(List<DemoExamEntry> entries) {
  final names = <String>[];
  for (final entry in entries) {
    for (final subject in entry.exam.subjects) {
      if (!names.contains(subject.subjectName)) names.add(subject.subjectName);
    }
  }
  return names;
}

String _examTime(DemoExamDef exam) => '${exam.examDate} 08:30:00';

String _two(int value) => value.toString().padLeft(2, '0');

String _dateTime(DateTime time) =>
    '${time.year}-${_two(time.month)}-${_two(time.day)} '
    '${_two(time.hour)}:${_two(time.minute)}:${_two(time.second)}';

double _round(double value, int digits) {
  final factor = math.pow(10, digits).toDouble();
  return (value * factor).round() / factor;
}

String _fmt(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
}

int _percent(double rate) => (rate * 100).round();

/// 与上一场有成绩的考试对比；名次变化为正表示进步。
({double? score, int? ranking, DemoExamEntry? previous}) _changesOf(
  DemoExamEntry entry,
) {
  if (!entry.scored) return (score: null, ranking: null, previous: null);
  final previous = _data.previousScoredEntry(
    entry.person.index,
    entry.exam.examId,
  );
  final total = entry.total;
  final previousTotal = previous?.total;
  final rank = entry.totalRanking;
  final previousRank = previous?.totalRanking;
  final comparable =
      previous != null && previous.exam.fullScore == entry.exam.fullScore;
  return (
    score: comparable && total != null && previousTotal != null
        ? _round(total - previousTotal, 2)
        : null,
    ranking: rank != null && previousRank != null ? previousRank - rank : null,
    previous: previous,
  );
}

Map<String, dynamic> _examRecord(DemoExamEntry entry) {
  final exam = entry.exam;
  final organization = entry.person.organizationName;
  final previous = entry.scored
      ? _data.previousScoredEntry(entry.person.index, exam.examId)
      : null;
  return <String, dynamic>{
    'examId': exam.examId,
    'examCode': exam.examCode,
    'examName': exam.examName,
    'examTime': _examTime(exam),
    'admissionNo': entry.admissionNo,
    'organizationName': organization,
    'status': exam.reviewed ? 'PUBLISHED' : 'MARKING',
    'totalScore': entry.total,
    'maxScore': exam.fullScore,
    'totalRanking': entry.totalRanking,
    'organizationRanking': entry.organizationRanking,
    'participantCount': exam.reviewed
        ? _data.participantCount(exam.examId)
        : null,
    'organizationParticipantCount': exam.reviewed
        ? _data.participantCount(exam.examId, organization)
        : null,
    'subjects': [
      for (final def in exam.subjects) _subjectRecord(entry, def, previous),
    ],
  };
}

Map<String, dynamic> _subjectRecord(
  DemoExamEntry entry,
  DemoSubjectDef def,
  DemoExamEntry? previous,
) {
  final score = entry.subject(def.subjectId);
  final before = previous == null
      ? null
      : _subjectByName(previous, def.subjectName);
  final grade = score?.grade ?? '';
  var description = '';
  for (final band in DemoMarkingData.bandsFor(def)) {
    if (band.grade == grade) description = band.description;
  }
  return <String, dynamic>{
    'subjectId': def.subjectId,
    'subjectName': def.subjectName,
    'score': score?.score,
    'maxScore': def.fullScore,
    'ranking': score?.ranking,
    'organizationRanking': score?.organizationRanking,
    'grade': grade,
    'gradeDescription': description,
    'scoreChange': score == null || before == null
        ? null
        : _round(score.score - before.score, 1),
    'scoreRate': score == null ? null : _round(score.score / def.fullScore, 4),
    'paperAvailable': score != null && score.result.judges.isNotEmpty,
  };
}

Map<String, dynamic> _examReport(DemoExamEntry entry) {
  final record = _examRecord(entry);
  final changes = _changesOf(entry);
  final rank = entry.totalRanking;
  final participants = _data.participantCount(entry.exam.examId);
  return <String, dynamic>{
    'exam': record,
    'subjects': record['subjects'],
    'scoreChange': changes.score,
    'rankingChange': changes.ranking,
    'previousExamId': changes.previous?.exam.examId,
    'surpassedPercent': rank != null && participants > 1
        ? ((participants - rank) / (participants - 1) * 100).round()
        : null,
    'interpretations': entry.scored
        ? _interpretations(entry, changes.previous)
        : const <Map<String, dynamic>>[],
    'organizationParticipantCount': record['organizationParticipantCount'],
  };
}

Map<String, dynamic> _scoreRow(DemoExamEntry entry) {
  final person = entry.person;
  return <String, dynamic>{
    'studentId': entry.studentId,
    'archiveId': person.archiveId,
    'studentName': person.name,
    'gender': person.gender,
    'avatarUrl': DemoMedia.url(person.avatarRef),
    'admissionNo': entry.admissionNo,
    'organizationName': person.organizationName,
    'totalScore': entry.total,
    'totalRanking': entry.totalRanking,
    'organizationRanking': entry.organizationRanking,
    'subjectScores': [
      for (final subject in entry.subjects ?? const <DemoSubjectScore>[])
        <String, dynamic>{
          'subjectId': subject.def.subjectId,
          'subjectName': subject.def.subjectName,
          'score': subject.score,
          'ranking': subject.ranking,
          'grade': subject.grade,
        },
    ],
  };
}

Map<String, dynamic> _interpretation(
  String type,
  String subjectId,
  String text,
) => <String, dynamic>{'type': type, 'subjectId': subjectId, 'text': text};

/// 表现解读：得分率最高的科目、进步最大的科目为优势；得分率最低的科目
/// 对照上一档标准、明显退步的科目为待提升。
List<Map<String, dynamic>> _interpretations(
  DemoExamEntry entry,
  DemoExamEntry? previous,
) {
  final subjects = [...?entry.subjects];
  if (subjects.isEmpty) return const <Map<String, dynamic>>[];
  double rateOf(DemoSubjectScore s) => s.score / s.def.fullScore;
  subjects.sort((a, b) => rateOf(b).compareTo(rateOf(a)));

  final changes = <DemoSubjectScore, double>{};
  if (previous != null) {
    for (final subject in subjects) {
      final before = _subjectByName(previous, subject.def.subjectName);
      if (before != null) {
        changes[subject] = _round(subject.score - before.score, 1);
      }
    }
  }

  final best = subjects.first;
  final items = <Map<String, dynamic>>[
    _interpretation(
      'STRENGTH',
      best.def.subjectId,
      '${best.def.subjectName} ${_fmt(best.score)} 分，评为 ${best.grade} 档，'
          '是本次得分率最高的科目（${_percent(rateOf(best))}%），'
          '科目排名第 ${best.ranking} 名。',
    ),
  ];

  final rising =
      changes.entries.where((e) => e.value >= 1 && e.key != best).toList()
        ..sort((a, b) => b.value.compareTo(a.value));
  if (rising.isNotEmpty) {
    final subject = rising.first.key;
    items.add(
      _interpretation(
        'STRENGTH',
        subject.def.subjectId,
        '${subject.def.subjectName}较上次提高 ${_fmt(rising.first.value)} 分，'
            '是进步最明显的科目，继续保持当前的训练节奏。',
      ),
    );
  } else {
    final previousRank = previous?.totalRanking;
    final currentRank = entry.totalRanking;
    final rankChange = previousRank != null && currentRank != null
        ? previousRank - currentRank
        : 0;
    if (rankChange > 0) {
      items.add(
        _interpretation('STRENGTH', '', '总排名较上次前进 $rankChange 名，整体状态稳步提升。'),
      );
    }
  }

  final weak = subjects.length > 1 ? subjects.last : null;
  if (weak != null && rateOf(weak) < rateOf(best)) {
    final bands = DemoMarkingData.bandsFor(weak.def);
    final index = bands.indexWhere((band) => band.grade == weak.grade);
    final next = index > 0 ? bands[index - 1] : null;
    final drop = changes[weak];
    final dropText = drop != null && drop <= -1
        ? '较上次下降 ${_fmt(-drop)} 分，'
        : '';
    items.add(
      _interpretation(
        'IMPROVEMENT',
        weak.def.subjectId,
        next == null
            ? '${weak.def.subjectName}得分率 ${_percent(rateOf(weak))}%，'
                  '$dropText相对其他科目略低，可对照 A 档样图打磨画面细节。'
            : '${weak.def.subjectName} ${_fmt(weak.score)} 分（${weak.grade} 档），'
                  '$dropText距 ${next.grade} 档还差 ${_fmt(next.min - weak.score)} 分。'
                  '${next.grade} 档要求：${next.description}',
      ),
    );
  }

  final falling =
      changes.entries
          .where((e) => e.value <= -2 && e.key != weak && e.key != best)
          .toList()
        ..sort((a, b) => a.value.compareTo(b.value));
  if (falling.isNotEmpty) {
    final subject = falling.first.key;
    items.add(
      _interpretation(
        'IMPROVEMENT',
        subject.def.subjectId,
        '${subject.def.subjectName}较上次下降 ${_fmt(-falling.first.value)} 分，'
            '建议打开原卷，对照评分标准找出失分点。',
      ),
    );
  }
  return items;
}
