// 学情中心数据模型：解析一律宽松，字段缺失或类型不符时回退为空串 / null。

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

int? _int(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  final text = _str(raw);
  return int.tryParse(text) ?? double.tryParse(text)?.round();
}

bool _bool(Object? raw) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  final text = _str(raw).toLowerCase();
  return text == 'true' || text == '1';
}

/// 阅卷系统性别：0 女 / 1 男，演示数据直接给中文。
String _gender(Object? raw) {
  final text = _str(raw);
  return switch (text) {
    '0' => '女',
    '1' => '男',
    _ => text,
  };
}

String _datePart(String time) =>
    time.length >= 10 ? time.substring(0, 10) : time;

enum StudyExamStatus { published, marking }

class StudyProfile {
  const StudyProfile({
    this.archiveId = '',
    this.name = '',
    this.gender = '',
    this.idCardMasked = '',
    this.avatarUrl = '',
    this.organizationName = '',
    this.schoolName = '',
    this.studentNo = '',
  });

  final String archiveId;
  final String name;
  final String gender;
  final String idCardMasked;
  final String avatarUrl;
  final String organizationName;
  final String schoolName;

  /// 画室学号（与学生名册一致）；准考证号每场考试不同，只在考试卡上显示。
  final String studentNo;

  factory StudyProfile.fromJson(Object? raw) {
    final json = _map(raw);
    return StudyProfile(
      archiveId: _str(json['archiveId']),
      name: _str(json['name']),
      gender: _gender(json['gender']),
      idCardMasked: _str(json['idCardMasked']),
      avatarUrl: _str(json['avatarUrl']),
      organizationName: _str(json['organizationName']),
      schoolName: _str(json['schoolName']),
      studentNo: _str(json['studentNo']),
    );
  }
}

class StudyStatistics {
  const StudyStatistics({this.total = 0, this.published = 0, this.pending = 0});

  final int total;
  final int published;
  final int pending;

  factory StudyStatistics.fromJson(Object? raw) {
    final json = _map(raw);
    return StudyStatistics(
      total: _int(json['total']) ?? 0,
      published: _int(json['published']) ?? 0,
      pending: _int(json['pending']) ?? 0,
    );
  }
}

class StudySubjectRecord {
  const StudySubjectRecord({
    required this.subjectId,
    this.subjectName = '',
    this.score,
    this.maxScore,
    this.ranking,
    this.organizationRanking,
    this.grade = '',
    this.gradeDescription = '',
    this.scoreChange,
    this.scoreRate,
    this.paperAvailable = false,
  });

  final String subjectId;
  final String subjectName;
  final double? score;
  final double? maxScore;
  final int? ranking;
  final int? organizationRanking;
  final String grade;
  final String gradeDescription;
  final double? scoreChange;
  final double? scoreRate;
  final bool paperAvailable;

  factory StudySubjectRecord.fromJson(Object? raw) {
    final json = _map(raw);
    return StudySubjectRecord(
      subjectId: _str(json['subjectId']),
      subjectName: _str(json['subjectName']),
      score: _double(json['score']),
      maxScore: _double(json['maxScore'] ?? json['fullScore']),
      ranking: _int(json['ranking']),
      organizationRanking: _int(json['organizationRanking']),
      grade: _str(json['grade']).toUpperCase(),
      gradeDescription: _str(json['gradeDescription']),
      scoreChange: _double(json['scoreChange']),
      scoreRate: _double(json['scoreRate']),
      paperAvailable: _bool(json['paperAvailable']),
    );
  }

  bool get hasScore => score != null;

  /// 得分率 0–1；接口未给出时按分数 / 满分计算。
  double? get rate {
    final explicit = scoreRate;
    if (explicit != null) return explicit.clamp(0.0, 1.0);
    final value = score;
    final full = maxScore;
    if (value == null || full == null || full <= 0) return null;
    return (value / full).clamp(0.0, 1.0);
  }
}

class StudyExamRecord {
  const StudyExamRecord({
    required this.examId,
    this.examCode = '',
    this.examName = '',
    this.examTime = '',
    this.admissionNo = '',
    this.organizationName = '',
    this.status = StudyExamStatus.marking,
    this.totalScore,
    this.maxScore,
    this.totalRanking,
    this.organizationRanking,
    this.participantCount,
    this.organizationParticipantCount,
    this.subjects = const <StudySubjectRecord>[],
  });

  final String examId;
  final String examCode;
  final String examName;

  /// `YYYY-MM-DD HH:mm:ss`。
  final String examTime;
  final String admissionNo;
  final String organizationName;
  final StudyExamStatus status;
  final double? totalScore;
  final double? maxScore;
  final int? totalRanking;
  final int? organizationRanking;
  final int? participantCount;
  final int? organizationParticipantCount;
  final List<StudySubjectRecord> subjects;

  factory StudyExamRecord.fromJson(Object? raw) {
    final json = _map(raw);
    return StudyExamRecord(
      examId: _str(json['examId']),
      examCode: _str(json['examCode']),
      examName: _str(json['examName']),
      examTime: _str(json['examTime']),
      admissionNo: _str(json['admissionNo']),
      organizationName: _str(json['organizationName']),
      status: _str(json['status']).toUpperCase() == 'PUBLISHED'
          ? StudyExamStatus.published
          : StudyExamStatus.marking,
      totalScore: _double(json['totalScore']),
      maxScore: _double(json['maxScore']),
      totalRanking: _int(json['totalRanking']),
      organizationRanking: _int(json['organizationRanking']),
      participantCount: _int(json['participantCount']),
      organizationParticipantCount: _int(json['organizationParticipantCount']),
      subjects: _mapList(
        json['subjects'],
      ).map(StudySubjectRecord.fromJson).toList(),
    );
  }

  bool get isPublished => status == StudyExamStatus.published;

  bool get hasScore => totalScore != null;

  String get examDate => _datePart(examTime);

  StudySubjectRecord? subjectById(String subjectId) {
    for (final subject in subjects) {
      if (subject.subjectId == subjectId) return subject;
    }
    return null;
  }

  StudyExamRecord withSubjects(List<StudySubjectRecord> value) {
    return StudyExamRecord(
      examId: examId,
      examCode: examCode,
      examName: examName,
      examTime: examTime,
      admissionNo: admissionNo,
      organizationName: organizationName,
      status: status,
      totalScore: totalScore,
      maxScore: maxScore,
      totalRanking: totalRanking,
      organizationRanking: organizationRanking,
      participantCount: participantCount,
      organizationParticipantCount: organizationParticipantCount,
      subjects: value,
    );
  }
}

class StudyRecentStage {
  const StudyRecentStage({
    required this.exam,
    this.scoreChange,
    this.rankingChange,
  });

  final StudyExamRecord exam;
  final double? scoreChange;

  /// 名次变化：正数表示名次上升（进步）。
  final int? rankingChange;
}

class StudyOverview {
  const StudyOverview({
    this.profile = const StudyProfile(),
    this.statistics = const StudyStatistics(),
    this.recentStage,
    this.exams = const <StudyExamRecord>[],
  });

  final StudyProfile profile;
  final StudyStatistics statistics;
  final StudyRecentStage? recentStage;

  /// 最近的考试（新 → 旧，最多 6 场）。
  final List<StudyExamRecord> exams;

  factory StudyOverview.fromJson(Object? raw) {
    final json = _map(raw);
    final stage = _map(json['recentStage']);
    final stageExam = stage['exam'];
    return StudyOverview(
      profile: StudyProfile.fromJson(json['profile']),
      statistics: StudyStatistics.fromJson(json['statistics']),
      recentStage: stageExam is Map
          ? StudyRecentStage(
              exam: StudyExamRecord.fromJson(stageExam),
              scoreChange: _double(stage['scoreChange']),
              rankingChange: _int(stage['rankingChange']),
            )
          : null,
      exams: _mapList(json['exams']).map(StudyExamRecord.fromJson).toList(),
    );
  }
}

class StudyInterpretation {
  const StudyInterpretation({
    required this.type,
    required this.text,
    this.subjectId = '',
  });

  /// `STRENGTH` 优势 / `IMPROVEMENT` 待提升。
  final String type;
  final String subjectId;
  final String text;

  bool get isStrength => type == 'STRENGTH';

  factory StudyInterpretation.fromJson(Object? raw) {
    final json = _map(raw);
    return StudyInterpretation(
      type: _str(json['type']).toUpperCase(),
      subjectId: _str(json['subjectId']),
      text: _str(json['text']),
    );
  }
}

class StudyExamReport {
  const StudyExamReport({
    required this.exam,
    this.subjects = const <StudySubjectRecord>[],
    this.scoreChange,
    this.rankingChange,
    this.previousExamId = '',
    this.surpassedPercent,
    this.interpretations = const <StudyInterpretation>[],
    this.organizationParticipantCount,
  });

  final StudyExamRecord exam;
  final List<StudySubjectRecord> subjects;
  final double? scoreChange;

  /// 名次变化：正数表示名次上升（进步）。
  final int? rankingChange;
  final String previousExamId;
  final int? surpassedPercent;
  final List<StudyInterpretation> interpretations;
  final int? organizationParticipantCount;

  factory StudyExamReport.fromJson(Object? raw) {
    final json = _map(raw);
    final exam = StudyExamRecord.fromJson(json['exam']);
    return StudyExamReport(
      exam: exam,
      subjects: json['subjects'] is List
          ? _mapList(json['subjects']).map(StudySubjectRecord.fromJson).toList()
          : exam.subjects,
      scoreChange: _double(json['scoreChange']),
      rankingChange: _int(json['rankingChange']),
      previousExamId: _str(json['previousExamId']),
      surpassedPercent: _int(json['surpassedPercent']),
      interpretations: _mapList(json['interpretations'])
          .map(StudyInterpretation.fromJson)
          .where((item) => item.text.isNotEmpty)
          .toList(),
      organizationParticipantCount:
          _int(json['organizationParticipantCount']) ??
          exam.organizationParticipantCount,
    );
  }
}

class StudyPaper {
  const StudyPaper({
    required this.subjectId,
    this.subjectName = '',
    this.paperAvailable = false,
    this.imageUrl = '',
    this.watermarkText = '',
    this.urlExpiresTime = '',
    this.message = '',
  });

  final String subjectId;
  final String subjectName;
  final bool paperAvailable;
  final String imageUrl;
  final String watermarkText;
  final String urlExpiresTime;
  final String message;

  bool get viewable => paperAvailable && imageUrl.isNotEmpty;

  factory StudyPaper.fromJson(Object? raw, {String subjectId = ''}) {
    final json = _map(raw);
    final id = _str(json['subjectId']);
    return StudyPaper(
      subjectId: id.isEmpty ? subjectId : id,
      subjectName: _str(json['subjectName']),
      paperAvailable: _bool(json['paperAvailable']),
      imageUrl: _str(json['imageUrl']),
      watermarkText: _str(json['watermarkText']),
      urlExpiresTime: _str(json['urlExpiresTime']),
      message: _str(json['message']),
    );
  }
}

enum ScoringAlgorithm {
  mean('算术平均'),
  trimmed('截尾平均');

  const ScoringAlgorithm(this.label);

  final String label;

  /// 兼容学生端 `mean` / `trimmed` 与机构端 0 / 1。
  static ScoringAlgorithm parse(Object? raw) {
    final text = _str(raw).toLowerCase();
    return text == 'trimmed' || text == '1'
        ? ScoringAlgorithm.trimmed
        : ScoringAlgorithm.mean;
  }
}

class GradeBandInfo {
  const GradeBandInfo({
    required this.grade,
    required this.min,
    required this.max,
    this.description = '',
    this.imageUrl = '',
  });

  final String grade;
  final double min;
  final double max;
  final String description;
  final String imageUrl;

  /// 兼容评分标准（min / max / imageUrl）、机构打分规则（imgUrl / imgUrlDesc）
  /// 与阅卷明细（minScore / maxScore）三种结构。
  factory GradeBandInfo.fromJson(Object? raw) {
    final json = _map(raw);
    return GradeBandInfo(
      grade: _str(json['grade']).toUpperCase(),
      min: _double(json['min'] ?? json['minScore']) ?? 0,
      max: _double(json['max'] ?? json['maxScore']) ?? 0,
      description: _str(json['description'] ?? json['imgUrlDesc']),
      imageUrl: _str(json['imageUrl'] ?? json['imgUrl']),
    );
  }
}

List<GradeBandInfo> _parseBands(Object? raw) {
  return _mapList(raw)
      .map(GradeBandInfo.fromJson)
      .where((band) => band.grade.isNotEmpty)
      .toList()
    ..sort((a, b) => b.min.compareTo(a.min));
}

class GradeStandard {
  const GradeStandard({
    this.subjectId = '',
    this.subjectName = '',
    this.fullScore,
    this.algorithm = ScoringAlgorithm.mean,
    this.diffThreshold,
    this.bands = const <GradeBandInfo>[],
  });

  final String subjectId;
  final String subjectName;
  final double? fullScore;
  final ScoringAlgorithm algorithm;
  final double? diffThreshold;

  /// 高档在前（A → E）。
  final List<GradeBandInfo> bands;

  /// 同时解析学生端评分标准（fullScore / bands）与机构端打分规则（score / gradeList）。
  factory GradeStandard.fromJson(
    Object? raw, {
    String subjectId = '',
    String subjectName = '',
  }) {
    final json = _map(raw);
    final id = _str(json['subjectId']);
    final name = _str(json['subjectName']);
    return GradeStandard(
      subjectId: id.isEmpty ? subjectId : id,
      subjectName: name.isEmpty ? subjectName : name,
      fullScore: _double(json['fullScore'] ?? json['score']),
      algorithm: ScoringAlgorithm.parse(json['algorithm']),
      diffThreshold: _double(json['diffThreshold']),
      bands: _parseBands(json['bands'] ?? json['gradeList']),
    );
  }

  GradeBandInfo? get topBand => bands.isEmpty ? null : bands.first;
}

enum GrowthMetric {
  score('SCORE', '分数'),
  ranking('RANKING', '排名');

  const GrowthMetric(this.code, this.label);

  final String code;
  final String label;
}

class GrowthTab {
  const GrowthTab({required this.label, this.subjectName = ''});

  /// 空串表示总分。
  final String subjectName;
  final String label;

  factory GrowthTab.fromJson(Object? raw) {
    final json = _map(raw);
    final name = _str(json['subjectName']);
    final label = _str(json['label']);
    return GrowthTab(
      subjectName: name,
      label: label.isNotEmpty ? label : (name.isEmpty ? '总分' : name),
    );
  }
}

class GrowthPoint {
  const GrowthPoint({
    required this.examId,
    this.examName = '',
    this.examTime = '',
    this.score,
    this.maxScore,
    this.ranking,
    this.participantCount,
    this.value,
    this.change,
  });

  final String examId;
  final String examName;
  final String examTime;
  final double? score;
  final double? maxScore;
  final int? ranking;
  final int? participantCount;
  final double? value;

  /// 与上一次相比：分数为差值；排名为「上次名次 - 本次名次」，正数表示进步。
  final double? change;

  factory GrowthPoint.fromJson(Object? raw) {
    final json = _map(raw);
    return GrowthPoint(
      examId: _str(json['examId']),
      examName: _str(json['examName']),
      examTime: _str(json['examTime']),
      score: _double(json['score']),
      maxScore: _double(json['maxScore']),
      ranking: _int(json['ranking']),
      participantCount: _int(json['participantCount']),
      value: _double(json['value']),
      change: _double(json['change']),
    );
  }

  String get examDate => _datePart(examTime);
}

class GrowthStatistics {
  const GrowthStatistics({
    this.valueCount = 0,
    this.bestValue,
    this.averageValue,
    this.latestValue,
    this.recentChange,
  });

  final int valueCount;
  final double? bestValue;
  final double? averageValue;
  final double? latestValue;
  final double? recentChange;

  factory GrowthStatistics.fromJson(Object? raw) {
    final json = _map(raw);
    return GrowthStatistics(
      valueCount: _int(json['valueCount']) ?? 0,
      bestValue: _double(json['bestValue']),
      averageValue: _double(json['averageValue']),
      latestValue: _double(json['latestValue']),
      recentChange: _double(json['recentChange']),
    );
  }
}

class GrowthResult {
  const GrowthResult({
    this.tabs = const <GrowthTab>[],
    this.points = const <GrowthPoint>[],
    this.statistics = const GrowthStatistics(),
  });

  final List<GrowthTab> tabs;

  /// 旧 → 新，仅含已出分的考试。
  final List<GrowthPoint> points;
  final GrowthStatistics statistics;

  factory GrowthResult.fromJson(Object? raw) {
    final json = _map(raw);
    return GrowthResult(
      tabs: _mapList(json['tabs']).map(GrowthTab.fromJson).toList(),
      points: _mapList(json['points']).map(GrowthPoint.fromJson).toList(),
      statistics: GrowthStatistics.fromJson(json['statistics']),
    );
  }
}

class StudyPage<T> {
  const StudyPage({
    required this.records,
    this.total = 0,
    this.current = 1,
    this.pages = 0,
  });

  final List<T> records;
  final int total;
  final int current;
  final int pages;

  bool get hasMore => current < pages;

  /// 兼容标准分页 `{records, total, current, pages}` 与直接返回数组。
  factory StudyPage.fromJson(Object? raw, T Function(Object? item) parse) {
    final json = _map(raw);
    final list = raw is List ? raw : json['records'];
    final records = list is List ? list.map(parse).toList() : List<T>.empty();
    final total = _int(json['total']) ?? records.length;
    final size = _int(json['size']) ?? records.length;
    final current = _int(json['current']) ?? 1;
    final pages =
        _int(json['pages']) ??
        (size > 0 ? (total + size - 1) ~/ size : (records.isEmpty ? 0 : 1));
    return StudyPage<T>(
      records: records,
      total: total,
      current: current,
      pages: pages,
    );
  }
}

class TeacherExamSubject {
  const TeacherExamSubject({
    required this.subjectId,
    required this.subjectName,
    this.fullScore,
  });

  final String subjectId;
  final String subjectName;
  final double? fullScore;

  factory TeacherExamSubject.fromJson(Object? raw) {
    final json = _map(raw);
    return TeacherExamSubject(
      subjectId: _str(json['subjectId']),
      subjectName: _str(json['subjectName']),
      fullScore: _double(json['fullScore'] ?? json['maxScore']),
    );
  }
}

class TeacherExam {
  const TeacherExam({
    required this.examId,
    this.examName = '',
    this.examTime = '',
    this.reviewStatus = 0,
    this.participantCount = 0,
    this.subjects = const <TeacherExamSubject>[],
  });

  final String examId;
  final String examName;
  final String examTime;

  /// 1 已发布 / 0 阅卷中。
  final int reviewStatus;
  final int participantCount;
  final List<TeacherExamSubject> subjects;

  factory TeacherExam.fromJson(Object? raw) {
    final json = _map(raw);
    return TeacherExam(
      examId: _str(json['examId']),
      examName: _str(json['examName']),
      examTime: _str(json['examTime']),
      reviewStatus: _int(json['reviewStatus']) ?? 0,
      participantCount: _int(json['participantCount']) ?? 0,
      subjects: _mapList(
        json['subjects'],
      ).map(TeacherExamSubject.fromJson).toList(),
    );
  }

  bool get isPublished => reviewStatus == 1;

  String get examDate => _datePart(examTime);

  double? get fullScore {
    if (subjects.isEmpty) return null;
    var sum = 0.0;
    for (final subject in subjects) {
      final full = subject.fullScore;
      if (full == null) return null;
      sum += full;
    }
    return sum;
  }

  TeacherExamSubject? subjectNamed(String name) {
    for (final subject in subjects) {
      if (subject.subjectName == name) return subject;
    }
    return null;
  }
}

class ScoreQuerySubject {
  const ScoreQuerySubject({
    required this.subjectId,
    required this.subjectName,
    this.score,
    this.ranking,
    this.grade = '',
  });

  final String subjectId;
  final String subjectName;
  final double? score;
  final int? ranking;
  final String grade;

  factory ScoreQuerySubject.fromJson(Object? raw) {
    final json = _map(raw);
    return ScoreQuerySubject(
      subjectId: _str(json['subjectId']),
      subjectName: _str(json['subjectName']),
      score: _double(json['score']),
      ranking: _int(json['ranking']),
      grade: _str(json['grade']).toUpperCase(),
    );
  }
}

class ScoreQueryRow {
  const ScoreQueryRow({
    required this.studentId,
    required this.archiveId,
    required this.studentName,
    this.gender = '',
    this.avatarUrl = '',
    this.admissionNo = '',
    this.organizationName = '',
    this.totalScore,
    this.totalRanking,
    this.organizationRanking,
    this.subjectScores = const <ScoreQuerySubject>[],
  });

  final String studentId;
  final String archiveId;
  final String studentName;
  final String gender;
  final String avatarUrl;
  final String admissionNo;
  final String organizationName;
  final double? totalScore;
  final int? totalRanking;
  final int? organizationRanking;
  final List<ScoreQuerySubject> subjectScores;

  factory ScoreQueryRow.fromJson(Object? raw) {
    final json = _map(raw);
    return ScoreQueryRow(
      studentId: _str(json['studentId']),
      archiveId: _str(json['archiveId']),
      studentName: _str(json['studentName']),
      gender: _gender(json['gender']),
      avatarUrl: _str(json['avatarUrl']),
      admissionNo: _str(json['admissionNo']),
      organizationName: _str(json['organizationName']),
      totalScore: _double(json['totalScore']),
      totalRanking: _int(json['totalRanking']),
      organizationRanking: _int(json['organizationRanking']),
      subjectScores: _mapList(
        json['subjectScores'],
      ).map(ScoreQuerySubject.fromJson).toList(),
    );
  }

  ScoreQuerySubject? subjectNamed(String name) {
    for (final subject in subjectScores) {
      if (subject.subjectName == name) return subject;
    }
    return null;
  }
}

class MarkingJudge {
  const MarkingJudge({
    required this.teacherName,
    this.score,
    this.grade = '',
    this.comment = '',
  });

  final String teacherName;
  final double? score;
  final String grade;
  final String comment;

  factory MarkingJudge.fromJson(Object? raw) {
    final json = _map(raw);
    return MarkingJudge(
      teacherName: _str(json['teacherName']),
      score: _double(json['score']),
      grade: _str(json['grade']).toUpperCase(),
      comment: _str(json['comment']),
    );
  }
}

class MarkingReview {
  const MarkingReview({
    this.paperUrl = '',
    this.finalScore,
    this.finalGrade = '',
    this.algorithm = ScoringAlgorithm.mean,
    this.diffThreshold,
    this.arbitrationStatus = '',
    this.everArbitrated = false,
    this.finalScoreOverridden = false,
    this.teachers = const <MarkingJudge>[],
    this.maxScore,
    this.bands = const <GradeBandInfo>[],
  });

  final String paperUrl;
  final double? finalScore;
  final String finalGrade;
  final ScoringAlgorithm algorithm;
  final double? diffThreshold;

  /// `RESOLVED` 仲裁已完成；空串表示未进入仲裁。
  final String arbitrationStatus;
  final bool everArbitrated;
  final bool finalScoreOverridden;
  final List<MarkingJudge> teachers;
  final double? maxScore;
  final List<GradeBandInfo> bands;

  factory MarkingReview.fromJson(Object? raw) {
    final json = _map(raw);
    final review = _map(json['review']);
    return MarkingReview(
      paperUrl: _str(review['paperUrl']),
      finalScore: _double(review['finalScore']),
      finalGrade: _str(review['finalGrade']).toUpperCase(),
      algorithm: ScoringAlgorithm.parse(review['algorithm']),
      diffThreshold: _double(review['diffThreshold']),
      arbitrationStatus: _str(review['arbitrationStatus']).toUpperCase(),
      everArbitrated: _bool(review['everArbitrated']),
      finalScoreOverridden: _bool(review['finalScoreOverridden']),
      teachers: _mapList(
        review['teachers'],
      ).map(MarkingJudge.fromJson).toList(),
      maxScore: _double(json['maxScore']),
      bands: _parseBands(json['bands']),
    );
  }

  bool get arbitrated => everArbitrated || arbitrationStatus.isNotEmpty;

  bool get arbitrationPending =>
      arbitrationStatus.isNotEmpty && arbitrationStatus != 'RESOLVED';
}

class StaffCurvePoint {
  const StaffCurvePoint({
    required this.examId,
    this.examName = '',
    this.examTime = '',
    this.score,
    this.ranking,
    this.scoreChange,
    this.maxScore,
  });

  final String examId;
  final String examName;
  final String examTime;
  final double? score;
  final int? ranking;
  final double? scoreChange;
  final double? maxScore;

  factory StaffCurvePoint.fromJson(Object? raw) {
    final json = _map(raw);
    return StaffCurvePoint(
      examId: _str(json['examId']),
      examName: _str(json['examName']),
      examTime: _str(json['examTime']),
      score: _double(json['score']),
      ranking: _int(json['ranking']),
      scoreChange: _double(json['scoreChange']),
      maxScore: _double(json['maxScore']),
    );
  }
}

class StudentCurve {
  const StudentCurve({
    this.points = const <StaffCurvePoint>[],
    this.subjects = const <String>[],
  });

  /// 旧 → 新。
  final List<StaffCurvePoint> points;
  final List<String> subjects;

  factory StudentCurve.fromJson(Object? raw) {
    final json = _map(raw);
    final subjects = json['subjects'];
    return StudentCurve(
      points: _mapList(json['points']).map(StaffCurvePoint.fromJson).toList(),
      subjects: subjects is List
          ? [
              for (final name in subjects)
                if (_str(name).isNotEmpty) _str(name),
            ]
          : const <String>[],
    );
  }
}
