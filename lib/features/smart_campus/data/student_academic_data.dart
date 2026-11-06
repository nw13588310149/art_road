import '../../../core/network/snowflake_id.dart';

double _doubleOf(dynamic value) => value is num
    ? value.toDouble()
    : double.tryParse('$value'.replaceAll('%', '').trim()) ?? 0;

int _intOf(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

String _stringOf(dynamic value) => value?.toString().trim() ?? '';

List<Map<dynamic, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const [];
  return value.whereType<Map<dynamic, dynamic>>().toList();
}

class StudentExamOverview {
  const StudentExamOverview({
    required this.avgScore,
    required this.bestExamName,
    required this.bestExamScore,
    required this.latestClassRank,
    required this.latestClassTotal,
    required this.latestSchoolRank,
    required this.latestSchoolTotal,
    required this.distribution,
    required this.trends,
  });

  factory StudentExamOverview.fromData(dynamic data) {
    final map = data is Map ? data : const <dynamic, dynamic>{};
    final best = map['bestExam'] is Map
        ? map['bestExam'] as Map
        : const <dynamic, dynamic>{};
    final classRank = map['latestClassRank'] is Map
        ? map['latestClassRank'] as Map
        : const <dynamic, dynamic>{};
    final schoolRank = map['latestSchoolRank'] is Map
        ? map['latestSchoolRank'] as Map
        : const <dynamic, dynamic>{};
    return StudentExamOverview(
      avgScore: _doubleOf(map['avgScore']),
      bestExamName: _stringOf(best['examName']),
      bestExamScore: _doubleOf(best['score']),
      latestClassRank: _intOf(classRank['rank']),
      latestClassTotal: _intOf(classRank['total']),
      latestSchoolRank: _intOf(schoolRank['rank']),
      latestSchoolTotal: _intOf(schoolRank['total']),
      distribution: _mapList(
        map['distribution'],
      ).map(StudentScoreDistribution.fromMap).toList(),
      trends: _mapList(map['trendList']).map(StudentExamTrend.fromMap).toList(),
    );
  }

  final double avgScore;
  final String bestExamName;
  final double bestExamScore;
  final int latestClassRank;
  final int latestClassTotal;
  final int latestSchoolRank;
  final int latestSchoolTotal;
  final List<StudentScoreDistribution> distribution;
  final List<StudentExamTrend> trends;

  /// 班级名次变化（最近两场有效排名对比）：正=进步（名次变小）、负=退步、
  /// 0=持平；趋势不足两场时为 null（不展示徽章）。
  int? get classRankTrend => _rankTrend((t) => t.classRank);

  /// 全校名次变化，规则同 [classRankTrend]。
  int? get schoolRankTrend => _rankTrend((t) => t.schoolRank);

  int? _rankTrend(int Function(StudentExamTrend) pick) {
    final ranked = trends.where((t) => pick(t) > 0).toList(growable: false);
    if (ranked.length < 2) return null;
    final previous = pick(ranked[ranked.length - 2]);
    final current = pick(ranked.last);
    return previous - current; // 名次变小 → 正值（进步）
  }
}

class StudentScoreDistribution {
  const StudentScoreDistribution({
    required this.range,
    required this.percent,
    required this.count,
  });

  factory StudentScoreDistribution.fromMap(Map<dynamic, dynamic> map) =>
      StudentScoreDistribution(
        range: _stringOf(map['range'] ?? map['label'] ?? map['scoreRange']),
        percent: _doubleOf(map['percent'] ?? map['percentage'] ?? map['ratio']),
        count: _intOf(map['count'] ?? map['num']),
      );

  final String range;
  final double percent;
  final int count;
}

class StudentExamTrend {
  const StudentExamTrend({
    required this.examId,
    required this.examName,
    required this.examDate,
    required this.totalScore,
    required this.classRank,
    required this.schoolRank,
    required this.subjectScores,
  });

  factory StudentExamTrend.fromMap(Map<dynamic, dynamic> map) =>
      StudentExamTrend(
        examId: readSnowflakeId(map['examId']) ?? _stringOf(map['examId']),
        examName: _stringOf(map['examName']),
        examDate: _stringOf(map['examDate']),
        totalScore: _doubleOf(
          map['totalScore'] ?? map['avgScore'] ?? map['score'],
        ),
        classRank: _intOf(map['classRank'] ?? map['classSort']),
        schoolRank: _intOf(map['schoolRank'] ?? map['schoolSort']),
        subjectScores: _mapList(
          map['subjectScores'],
        ).map(StudentExamSubjectScore.fromMap).toList(),
      );

  final String examId;
  final String examName;
  final String examDate;
  final double totalScore;
  final int classRank;
  final int schoolRank;
  final List<StudentExamSubjectScore> subjectScores;
}

class StudentExamRecord {
  const StudentExamRecord({
    required this.examId,
    required this.examName,
    required this.examDate,
    required this.totalScore,
    required this.passSubjectCount,
    required this.excellentSubjectCount,
    required this.classRank,
    required this.schoolRank,
    required this.subjectScores,
  });

  factory StudentExamRecord.fromMap(Map<dynamic, dynamic> map) =>
      StudentExamRecord(
        examId: readSnowflakeId(map['examId']) ?? _stringOf(map['examId']),
        examName: _stringOf(map['examName']),
        examDate: _stringOf(map['examDate']),
        totalScore: _doubleOf(map['totalScore']),
        passSubjectCount: _intOf(map['passSubjectCount']),
        excellentSubjectCount: _intOf(map['excellentSubjectCount']),
        classRank: _intOf(map['classRank']),
        schoolRank: _intOf(map['schoolRank']),
        subjectScores: _mapList(
          map['subjectScores'],
        ).map(StudentExamSubjectScore.fromMap).toList(),
      );

  /// 考试 id（雪花 long，String 形式避免 Web 精度丢失），用于查询考场座位。
  final String examId;
  final String examName;
  final String examDate;
  final double totalScore;
  final int passSubjectCount;
  final int excellentSubjectCount;
  final int classRank;
  final int schoolRank;
  final List<StudentExamSubjectScore> subjectScores;
}

class StudentExamSubjectScore {
  const StudentExamSubjectScore({
    required this.subjectId,
    required this.subjectName,
    required this.score,
    required this.classRank,
    required this.schoolRank,
    required this.comment,
    required this.path,
    required this.headUrl,
    required this.nickname,
  });

  factory StudentExamSubjectScore.fromMap(Map<dynamic, dynamic> map) =>
      StudentExamSubjectScore(
        subjectId: _intOf(map['subjectId']),
        subjectName: _stringOf(map['subjectName']),
        score: map['score'] == null ? null : _doubleOf(map['score']),
        classRank: _intOf(map['classRank'] ?? map['classSort']),
        schoolRank: _intOf(map['schoolRank'] ?? map['schoolSort']),
        comment: _stringOf(map['comment']),
        path: _stringOf(map['path']),
        headUrl: _stringOf(map['headUrl']),
        nickname: _stringOf(map['nickname']),
      );

  final int subjectId;
  final String subjectName;
  final double? score;
  final int classRank;
  final int schoolRank;
  final String comment;
  final String path;
  final String headUrl;
  final String nickname;
}

/// 学生「我的作业」统计（`student/studentHomeworkSum`）。实测字段：
/// `subjectAvgScores` / `teacherAvgScores` / `scoreRanges` /
/// `total` / `pending` / `submitted` / `reviewed` / `overdue`。
class StudentHomeworkSummary {
  const StudentHomeworkSummary({
    required this.subjectAvgScores,
    required this.teacherAvgScores,
    required this.scoreRanges,
    this.total = 0,
    this.pending = 0,
    this.submitted = 0,
    this.reviewed = 0,
    this.overdue = 0,
  });

  factory StudentHomeworkSummary.fromData(dynamic data) {
    final map = data is Map ? data : const <dynamic, dynamic>{};
    return StudentHomeworkSummary(
      subjectAvgScores: _mapList(
        map['subjectAvgScores'],
      ).map(StudentSubjectAverage.fromMap).toList(),
      teacherAvgScores: _mapList(
        map['teacherAvgScores'],
      ).map(StudentSubjectAverage.fromMap).toList(),
      scoreRanges: _mapList(
        map['scoreRanges'],
      ).map(StudentScoreDistribution.fromMap).toList(),
      total: _intOf(map['total']),
      pending: _intOf(map['pending']),
      submitted: _intOf(map['submitted']),
      reviewed: _intOf(map['reviewed']),
      overdue: _intOf(map['overdue']),
    );
  }

  /// 按科目作业均分。
  final List<StudentSubjectAverage> subjectAvgScores;

  /// 按任课老师作业均分。
  final List<StudentSubjectAverage> teacherAvgScores;

  /// 作业分数段分布。
  final List<StudentScoreDistribution> scoreRanges;

  /// 作业总数。
  final int total;

  /// 待提交数。
  final int pending;

  /// 已提交（待批阅）数。
  final int submitted;

  /// 已批阅数。
  final int reviewed;

  /// 已逾期数。
  final int overdue;

  /// 总体作业均分：对各科目均分中 >0 的项取算术平均；无数据返回 0。
  double get overallAvgScore {
    final scores = subjectAvgScores
        .map((e) => e.score)
        .where((s) => s > 0)
        .toList();
    if (scores.isEmpty) return 0;
    final sum = scores.fold<double>(0, (a, b) => a + b);
    return sum / scores.length;
  }
}

class StudentSubjectAverage {
  const StudentSubjectAverage({required this.subjectName, required this.score});

  /// 同时兼容「按科目」(`subjectName`) 与「按老师」(`teacherName`) 两种行，
  /// 分值兼容 `avgScore` / `score` / `avg`。
  factory StudentSubjectAverage.fromMap(Map<dynamic, dynamic> map) =>
      StudentSubjectAverage(
        subjectName: _stringOf(
          map['subjectName'] ??
              map['teacherName'] ??
              map['teacherRealname'] ??
              map['name'],
        ),
        score: _doubleOf(map['avgScore'] ?? map['score'] ?? map['avg']),
      );

  final String subjectName;
  final double score;
}

/// 学生「我的考场座位」（`student/examSeat` → `StudentExamSeatRes`）。
class StudentExamSeat {
  const StudentExamSeat({
    required this.examName,
    required this.examDate,
    required this.remark,
    required this.seats,
  });

  factory StudentExamSeat.fromData(dynamic data) {
    final map = data is Map ? data : const <dynamic, dynamic>{};
    return StudentExamSeat(
      examName: _stringOf(map['examName']),
      examDate: _stringOf(map['examDate']),
      remark: _stringOf(map['remark']),
      seats: _mapList(map['seats']).map(StudentExamSeatItem.fromMap).toList(),
    );
  }

  final String examName;
  final String examDate;
  final String remark;
  final List<StudentExamSeatItem> seats;
}

/// 单科目的考场座位（`SubjectSeat`）。未安排时 [classroomName] 为空、[seatNo] 为 null。
class StudentExamSeatItem {
  const StudentExamSeatItem({
    required this.subjectName,
    required this.classroomName,
    required this.seatNo,
  });

  factory StudentExamSeatItem.fromMap(Map<dynamic, dynamic> map) {
    final rawSeat = map['seatNo'];
    return StudentExamSeatItem(
      subjectName: _stringOf(map['subjectName']),
      classroomName: _stringOf(map['classroomName']),
      seatNo: rawSeat == null ? null : int.tryParse('$rawSeat'),
    );
  }

  final String subjectName;
  final String classroomName;
  final int? seatNo;

  /// 是否已编排考场（教室与座位号齐全）。
  bool get arranged => classroomName.isNotEmpty && seatNo != null;
}
