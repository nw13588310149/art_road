// 月考原卷讲评：老师按「考试 + 科目」挑代表卷、在卷面上标几处讲评，发布后学生在
// 成绩报告里听。解析一律宽松，字段缺失时回退为空串 / null / 空列表。
import 'package:flutter/foundation.dart';

import '../../artworks/data/artwork_models.dart';
import '../../artworks/data/artwork_rules.dart';

Map<String, dynamic> _map(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _mapList(Object? raw) {
  if (raw is! List) return const <Map<String, dynamic>>[];
  return [
    for (final item in raw)
      if (item is Map) _map(item),
  ];
}

String _str(Object? raw) {
  if (raw == null) return '';
  final text = raw.toString().trim();
  return text == 'null' ? '' : text;
}

double? _double(Object? raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(_str(raw));
}

int _int(Object? raw) {
  if (raw is num) return raw.round();
  return int.tryParse(_str(raw)) ?? 0;
}

bool _bool(Object? raw) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  final text = _str(raw).toLowerCase();
  return text == 'true' || text == '1';
}

/// 讲评的输入规则，与接口校验一致。卷面上的标记沿用作品定点点评的上限。
abstract final class ExamCritiqueRules {
  static const sharedPapers = 10;
  static const marksPerPaper = ArtworkRules.marksPerImage;
  static const markTextLimit = ArtworkRules.markTextLimit;
  static const summaryLimit = 500;
  static const voiceSeconds = 120;

  /// 「2026 年 9 月月考」在页头和清单里说成「9 月月考」。
  static String shortExamName(String name) =>
      name.replaceFirst(RegExp(r'^\d{4}\s*年\s*'), '');
}

/// 一个档位：分数区间和这一档有几张卷子（学生端没有人数）。
@immutable
class CritiqueBand {
  const CritiqueBand({
    required this.grade,
    this.min = 0,
    this.max = 0,
    this.count = 0,
  });

  final String grade;
  final double min;
  final double max;
  final int count;

  factory CritiqueBand.fromJson(Object? raw) {
    final json = _map(raw);
    return CritiqueBand(
      grade: _str(json['grade']).toUpperCase(),
      min: _double(json['min']) ?? 0,
      max: _double(json['max']) ?? 0,
      count: _int(json['count']),
    );
  }
}

List<CritiqueBand> _bands(Object? raw) =>
    _mapList(raw)
        .map(CritiqueBand.fromJson)
        .where((band) => band.grade.isNotEmpty)
        .toList()
      ..sort((a, b) => b.min.compareTo(a.min));

/// 讲评工作台里的一张候选卷：这一科有成绩的每位学生一张。
@immutable
class CritiqueCandidate {
  const CritiqueCandidate({
    required this.archiveId,
    this.studentName = '',
    this.organizationName = '',
    this.score,
    this.grade = '',
    this.imageUrl = '',
    this.suggested = false,
  });

  final String archiveId;
  final String studentName;
  final String organizationName;
  final double? score;
  final String grade;
  final String imageUrl;

  /// 这一档建议讲评的那一张（分数最接近这一档中间分）。
  final bool suggested;

  factory CritiqueCandidate.fromJson(Object? raw) {
    final json = _map(raw);
    return CritiqueCandidate(
      archiveId: _str(json['archiveId']),
      studentName: _str(json['studentName']),
      organizationName: _str(json['organizationName']),
      score: _double(json['score']),
      grade: _str(json['grade']).toUpperCase(),
      imageUrl: _str(json['imageUrl']),
      suggested: _bool(json['suggested']),
    );
  }
}

/// 讲评里的一张卷子：代表卷（[shared]，参加这场考试的学生都能看）或个人点评
/// （只给那一位学生看）。卷面上的几处讲评和作品定点点评同一结构。
@immutable
class CritiquePaper {
  const CritiquePaper({
    required this.id,
    this.archiveId = '',
    this.shared = true,
    this.mine = false,
    this.summary = '',
    this.voiceUrl = '',
    this.voiceSeconds = 0,
    this.marks = const <ArtworkMark>[],
    this.updatedTime = '',
    this.teacherName = '',
    this.studentName = '',
    this.organizationName = '',
    this.score,
    this.grade = '',
    this.imageUrl = '',
  });

  /// 学生端只有 id；教职端用 [archiveId] 和 [shared] 定位一张。
  final String id;
  final String archiveId;
  final bool shared;

  /// 学生端：这是给我本人的个人点评。
  final bool mine;
  final String summary;
  final String voiceUrl;
  final int voiceSeconds;
  final List<ArtworkMark> marks;
  final String updatedTime;
  final String teacherName;

  /// 学生端不公开姓名时为空。
  final String studentName;
  final String organizationName;
  final double? score;
  final String grade;
  final String imageUrl;

  factory CritiquePaper.fromJson(Object? raw) {
    final json = _map(raw);
    return CritiquePaper(
      id: _str(json['id']),
      archiveId: _str(json['archiveId']),
      shared: json.containsKey('shared') ? _bool(json['shared']) : true,
      mine: _bool(json['mine']),
      summary: _str(json['summary']),
      voiceUrl: _str(json['voiceUrl']),
      voiceSeconds: _int(json['voiceSeconds']),
      marks: [
        for (final item in _mapList(json['marks']))
          ArtworkMark.fromJson(<String, dynamic>{...item, 'imageIndex': 0}),
      ].where((mark) => !mark.isEmpty).toList(growable: false),
      updatedTime: _str(json['updatedTime']),
      teacherName: _str(json['teacherName']),
      studentName: _str(json['studentName']),
      organizationName: _str(json['organizationName']),
      score: _double(json['score']),
      grade: _str(json['grade']).toUpperCase(),
      imageUrl: _str(json['imageUrl']),
    );
  }

  /// 工作台里区分一张卷子：同一位学生可以既是代表卷、又有个人点评。
  String get key => critiquePaperKey(archiveId, shared: shared);

  bool get hasVoice => voiceUrl.isNotEmpty;

  bool get hasContent =>
      summary.trim().isNotEmpty || hasVoice || marks.isNotEmpty;

  CritiquePaper copyWith({
    String? summary,
    String? voiceUrl,
    int? voiceSeconds,
    List<ArtworkMark>? marks,
  }) {
    return CritiquePaper(
      id: id,
      archiveId: archiveId,
      shared: shared,
      mine: mine,
      summary: summary ?? this.summary,
      voiceUrl: voiceUrl ?? this.voiceUrl,
      voiceSeconds: voiceSeconds ?? this.voiceSeconds,
      marks: marks ?? this.marks,
      updatedTime: updatedTime,
      teacherName: teacherName,
      studentName: studentName,
      organizationName: organizationName,
      score: score,
      grade: grade,
      imageUrl: imageUrl,
    );
  }

  /// 保存时的请求体：去掉既没写字也没录音的标记。
  Map<String, dynamic> toSaveJson() => <String, dynamic>{
    'archiveId': archiveId,
    'shared': shared,
    'summary': summary.trim(),
    'voiceUrl': voiceUrl,
    'voiceSeconds': hasVoice ? voiceSeconds : 0,
    'marks': [
      for (final mark in marks)
        if (!mark.isEmpty) mark.toJson(),
    ],
  };

  /// 讲评内容相同（不比较出处）：判断有没有没保存的改动。
  bool sameContent(CritiquePaper other) =>
      summary.trim() == other.summary.trim() &&
      voiceUrl == other.voiceUrl &&
      (!hasVoice || voiceSeconds == other.voiceSeconds) &&
      listEquals(
        marks.where((m) => !m.isEmpty).toList(),
        other.marks.where((m) => !m.isEmpty).toList(),
      );

  /// 卷面上的标记带上编号，给图上编号、列表和浮层用。[paperKey] 让不同卷子的
  /// 标记在共用播放器里互不冲突。
  List<NumberedArtworkMark> numberedMarks(String paperKey) => [
    for (var i = 0; i < marks.length; i++)
      NumberedArtworkMark(
        mark: marks[i],
        number: i + 1,
        teacherId: paperKey,
        teacherName: teacherName,
      ),
  ];
}

String critiquePaperKey(String archiveId, {required bool shared}) =>
    '${shared ? 'shared' : 'personal'}:$archiveId';

/// 一份讲评（一场考试的一科）。
@immutable
class ExamCritique {
  const ExamCritique({
    this.published = false,
    this.showNames = false,
    this.publishTime = '',
    this.teacherName = '',
    this.updatedTime = '',
    this.papers = const <CritiquePaper>[],
  });

  final bool published;
  final bool showNames;
  final String publishTime;
  final String teacherName;
  final String updatedTime;
  final List<CritiquePaper> papers;

  factory ExamCritique.fromJson(Object? raw) {
    final json = _map(raw);
    return ExamCritique(
      published: _bool(json['published']),
      showNames: _bool(json['showNames']),
      publishTime: _str(json['publishTime']),
      teacherName: _str(json['teacherName']),
      updatedTime: _str(json['updatedTime']),
      papers: _mapList(json['papers']).map(CritiquePaper.fromJson).toList(),
    );
  }

  int get sharedCount => papers.where((p) => p.shared).length;
  int get personalCount => papers.where((p) => !p.shared).length;
}

/// 班级学情里那一科讲评的状态：未开始 / 草稿 N 张 / 已发布 N 张。
String critiqueStatusText(ExamCritique? critique) {
  final count = critique?.papers.length ?? 0;
  if (critique == null || count == 0) return '未开始';
  return critique.published ? '已发布 $count 张' : '草稿 $count 张';
}

/// 教职端讲评工作台的数据：这一科全部有成绩的卷子、档位和已有的讲评。
@immutable
class ExamCritiqueBoard {
  const ExamCritiqueBoard({
    required this.examId,
    required this.subjectId,
    this.examName = '',
    this.subjectName = '',
    this.fullScore,
    this.bands = const <CritiqueBand>[],
    this.candidates = const <CritiqueCandidate>[],
    this.critique = const ExamCritique(),
    this.canEdit = false,
  });

  final String examId;
  final String subjectId;
  final String examName;
  final String subjectName;
  final double? fullScore;

  /// 高档在前。
  final List<CritiqueBand> bands;

  /// 分数从高到低。
  final List<CritiqueCandidate> candidates;
  final ExamCritique critique;
  final bool canEdit;

  factory ExamCritiqueBoard.fromJson(Object? raw) {
    final json = _map(raw);
    final exam = _map(json['exam']);
    final subject = _map(json['subject']);
    return ExamCritiqueBoard(
      examId: _str(exam['examId']),
      subjectId: _str(subject['subjectId']),
      examName: _str(exam['examName']),
      subjectName: _str(subject['subjectName']),
      fullScore: _double(subject['fullScore']),
      bands: _bands(json['bands']),
      candidates: _mapList(
        json['papers'],
      ).map(CritiqueCandidate.fromJson).toList(),
      critique: ExamCritique.fromJson(json['critique']),
      canEdit: _bool(_map(json['access'])['canEdit']),
    );
  }

  CritiqueCandidate? candidate(String archiveId) {
    for (final item in candidates) {
      if (item.archiveId == archiveId) return item;
    }
    return null;
  }

  CritiquePaper? paper(String key) {
    for (final item in critique.papers) {
      if (item.key == key) return item;
    }
    return null;
  }

  List<CritiqueCandidate> candidatesIn(String grade) =>
      candidates.where((c) => c.grade == grade).toList();
}

/// 学生右栏里的一组：我的原卷 / 我这一档 / 上一档 / 其他档。
@immutable
class CritiqueSection {
  const CritiqueSection({required this.label, required this.paper});

  final String label;
  final CritiquePaper paper;
}

/// 学生端某一科已发布的讲评。
@immutable
class StudentExamCritique {
  const StudentExamCritique({
    required this.examId,
    required this.subjectId,
    this.examName = '',
    this.subjectName = '',
    this.published = false,
    this.showNames = false,
    this.publishTime = '',
    this.teacherName = '',
    this.watermarkText = '',
    this.myGrade = '',
    this.myScore,
    this.read = false,
    this.bands = const <CritiqueBand>[],
    this.papers = const <CritiquePaper>[],
  });

  final String examId;
  final String subjectId;
  final String examName;
  final String subjectName;
  final bool published;
  final bool showNames;
  final String publishTime;
  final String teacherName;
  final String watermarkText;
  final String myGrade;
  final double? myScore;
  final bool read;
  final List<CritiqueBand> bands;
  final List<CritiquePaper> papers;

  factory StudentExamCritique.fromJson(Object? raw) {
    final json = _map(raw);
    final exam = _map(json['exam']);
    final subject = _map(json['subject']);
    return StudentExamCritique(
      examId: _str(exam['examId']),
      subjectId: _str(subject['subjectId']),
      examName: _str(exam['examName']),
      subjectName: _str(subject['subjectName']),
      published: _bool(json['published']),
      showNames: _bool(json['showNames']),
      publishTime: _str(json['publishTime']),
      teacherName: _str(json['teacherName']),
      watermarkText: _str(json['watermarkText']),
      myGrade: _str(json['myGrade']).toUpperCase(),
      myScore: _double(json['myScore']),
      read: _bool(json['read']),
      bands: _bands(json['bands']),
      papers: _mapList(json['papers']).map(CritiquePaper.fromJson).toList(),
    );
  }

  StudentExamCritique markedRead() => StudentExamCritique(
    examId: examId,
    subjectId: subjectId,
    examName: examName,
    subjectName: subjectName,
    published: published,
    showNames: showNames,
    publishTime: publishTime,
    teacherName: teacherName,
    watermarkText: watermarkText,
    myGrade: myGrade,
    myScore: myScore,
    read: true,
    bands: bands,
    papers: papers,
  );

  /// 右栏的先后：给我本人的个人点评，我这一档，高一档，其余按档位从高到低。
  List<CritiqueSection> get sections =>
      orderCritiqueSections(papers, myGrade: myGrade, bands: bands);
}

/// 学生看讲评时卷子的先后：我的原卷、我这一档、上一档、其他档（从高到低）。
/// 同一组里保持接口给出的先后。
List<CritiqueSection> orderCritiqueSections(
  List<CritiquePaper> papers, {
  required String myGrade,
  List<CritiqueBand> bands = const <CritiqueBand>[],
}) {
  final grades = bands.isEmpty
      ? (papers.map((p) => p.grade).toSet().toList()..sort())
      : [for (final band in bands) band.grade];
  final mine = grades.indexOf(myGrade);
  final above = mine > 0 ? grades[mine - 1] : '';
  int rank(CritiquePaper paper) {
    if (paper.mine) return 0;
    if (paper.grade == myGrade) return 1;
    if (above.isNotEmpty && paper.grade == above) return 2;
    final index = grades.indexOf(paper.grade);
    return 3 + (index < 0 ? grades.length : index);
  }

  final indexed = papers.indexed.toList()
    ..sort((a, b) {
      final byRank = rank(a.$2).compareTo(rank(b.$2));
      return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
    });
  return [
    for (final (_, paper) in indexed)
      CritiqueSection(
        label: switch (rank(paper)) {
          0 => '我的原卷',
          1 => '我这一档',
          2 => '上一档',
          _ => '其他档',
        },
        paper: paper,
      ),
  ];
}
