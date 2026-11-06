import 'package:flutter/material.dart';

import '../../../core/network/snowflake_id.dart';

/// 班主任班级工作台 · 成绩页聚合（`headTeacherClassScoreOverview`）。
class HeadTeacherClassScoreOverview {
  const HeadTeacherClassScoreOverview({
    required this.examAxis,
    required this.trendLines,
    required this.examTabs,
    required this.currentExamId,
    required this.studentScores,
  });

  final List<HeadTeacherScoreExamAxis> examAxis;
  final List<HeadTeacherScoreTrendLine> trendLines;
  final List<HeadTeacherScoreExamTab> examTabs;
  final String currentExamId;
  final HeadTeacherStudentScoresPage studentScores;

  factory HeadTeacherClassScoreOverview.fromData(dynamic data) {
    if (data is! Map) {
      return HeadTeacherClassScoreOverview.zero;
    }
    final map = Map<String, dynamic>.from(data);
    final studentRaw = map['studentScores'];
    return HeadTeacherClassScoreOverview(
      examAxis: _mapList(map['examAxis'])
          .map(HeadTeacherScoreExamAxis.fromJson)
          .where((item) => item.examId.isNotEmpty)
          .toList(),
      trendLines: _mapList(map['trendLines'])
          .map(HeadTeacherScoreTrendLine.fromJson)
          .toList(),
      examTabs: _mapList(map['examTabs'])
          .map(HeadTeacherScoreExamTab.fromJson)
          .where((item) => item.examId.isNotEmpty)
          .toList(),
      currentExamId: pickFirstSnowflakeId(map, ['currentExamId']) ?? '',
      studentScores: studentRaw is Map
          ? HeadTeacherStudentScoresPage.fromJson(
              Map<String, dynamic>.from(studentRaw),
            )
          : HeadTeacherStudentScoresPage.zero,
    );
  }

  static const HeadTeacherClassScoreOverview zero = HeadTeacherClassScoreOverview(
    examAxis: [],
    trendLines: [],
    examTabs: [],
    currentExamId: '',
    studentScores: HeadTeacherStudentScoresPage.zero,
  );

  bool get hasChartData =>
      examAxis.length >= 2 &&
      trendLines.any((line) => line.avgScores.length >= 2);

  int indexOfCurrentExam() {
    if (currentExamId.isEmpty || examTabs.isEmpty) return 0;
    final idx = examTabs.indexWhere((tab) => tab.examId == currentExamId);
    return idx >= 0 ? idx : 0;
  }
}

class HeadTeacherScoreExamAxis {
  const HeadTeacherScoreExamAxis({
    required this.examId,
    required this.name,
    required this.examDate,
  });

  final String examId;
  final String name;
  final String examDate;

  factory HeadTeacherScoreExamAxis.fromJson(Map<String, dynamic> json) {
    return HeadTeacherScoreExamAxis(
      examId: pickFirstSnowflakeId(json, ['examId', 'id']) ?? '',
      name: _pickString(json, ['name', 'examName', 'title']),
      examDate: _pickString(json, ['examDate', 'date']),
    );
  }

  String get axisLabel {
    if (examDate.length >= 10) {
      final month = int.tryParse(examDate.substring(5, 7));
      final day = int.tryParse(examDate.substring(8, 10));
      if (month != null && day != null) {
        return '$month月$day日';
      }
    }
    final name = this.name.trim();
    if (name.length <= 6) return name;
    return '${name.substring(0, 6)}…';
  }
}

class HeadTeacherScoreTrendLine {
  const HeadTeacherScoreTrendLine({
    required this.subjectId,
    required this.subjectName,
    required this.avgScores,
  });

  final int subjectId;
  final String subjectName;
  final List<double> avgScores;

  factory HeadTeacherScoreTrendLine.fromJson(Map<String, dynamic> json) {
    final scoresRaw = json['avgScores'];
    final scores = <double>[];
    if (scoresRaw is List) {
      for (final value in scoresRaw) {
        if (value is num) {
          scores.add(value.toDouble());
        } else {
          scores.add(double.tryParse('$value') ?? 0);
        }
      }
    }
    return HeadTeacherScoreTrendLine(
      subjectId: _pickInt(json, ['subjectId', 'id']),
      subjectName: _pickString(json, ['subjectName', 'name', 'subject']),
      avgScores: scores,
    );
  }
}

class HeadTeacherScoreExamTab {
  const HeadTeacherScoreExamTab({
    required this.examId,
    required this.name,
    required this.examDate,
  });

  final String examId;
  final String name;
  final String examDate;

  factory HeadTeacherScoreExamTab.fromJson(Map<String, dynamic> json) {
    return HeadTeacherScoreExamTab(
      examId: pickFirstSnowflakeId(json, ['examId', 'id']) ?? '',
      name: _pickString(json, ['name', 'examName', 'title']),
      examDate: _pickString(json, ['examDate', 'date']),
    );
  }
}

class HeadTeacherStudentScoresPage {
  const HeadTeacherStudentScoresPage({
    required this.records,
    required this.total,
    required this.pageNum,
    required this.pageSize,
  });

  final List<HeadTeacherStudentScoreRecord> records;
  final int total;
  final int pageNum;
  final int pageSize;

  static const HeadTeacherStudentScoresPage zero = HeadTeacherStudentScoresPage(
    records: [],
    total: 0,
    pageNum: 1,
    pageSize: 10,
  );

  factory HeadTeacherStudentScoresPage.fromJson(Map<String, dynamic> json) {
    final recordsRaw = json['records'] ?? json['list'];
    final records = recordsRaw is List
        ? recordsRaw
            .whereType<Map>()
            .map((item) => HeadTeacherStudentScoreRecord.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .where((item) => item.studentId.isNotEmpty)
            .toList()
        : const <HeadTeacherStudentScoreRecord>[];
    return HeadTeacherStudentScoresPage(
      records: records,
      total: _pickInt(json, ['total', 'count']),
      pageNum: _pickInt(json, ['pageNum', 'current'], fallback: 1),
      pageSize: _pickInt(json, ['pageSize', 'size'], fallback: 10),
    );
  }

  bool get hasMore => records.length < total;
}

class HeadTeacherStudentScoreRecord {
  const HeadTeacherStudentScoreRecord({
    required this.studentId,
    required this.realname,
    required this.nickname,
    required this.no,
    required this.headUrl,
    required this.subjectId,
    required this.subjectName,
    required this.score,
    required this.teacherName,
    required this.comment,
    required this.hasStudentAudio,
    required this.hasStudentVideo,
    required this.hasVideoComment,
    required this.hasAudioComment,
  });

  final String studentId;
  final String realname;
  final String nickname;
  final String no;
  final String headUrl;
  final int subjectId;
  final String subjectName;
  final int score;
  final String teacherName;
  final String comment;
  final bool hasStudentAudio;
  final bool hasStudentVideo;
  final bool hasVideoComment;
  final bool hasAudioComment;

  factory HeadTeacherStudentScoreRecord.fromJson(Map<String, dynamic> json) {
    return HeadTeacherStudentScoreRecord(
      studentId: pickFirstSnowflakeId(json, ['studentId', 'id']) ?? '',
      realname: _pickString(json, ['realname']),
      nickname: _pickString(json, ['nickname']),
      no: _pickString(json, ['no', 'studentNo', 'code']),
      headUrl: _pickString(json, ['headUrl', 'avatar', 'avatarUrl']),
      subjectId: _pickInt(json, ['subjectId']),
      subjectName: _pickString(json, ['subjectName', 'subject']),
      score: _pickInt(json, ['score']),
      teacherName: _pickString(json, ['teacherName', 'teacher']),
      comment: _pickString(json, ['comment', 'remark', 'feedback']),
      hasStudentAudio: _pickBool(json, ['hasStudentAudio']),
      hasStudentVideo: _pickBool(json, ['hasStudentVideo']),
      hasVideoComment: _pickBool(json, ['hasVideoComment']),
      hasAudioComment: _pickBool(json, ['hasAudioComment']),
    );
  }

  String get displayName {
    if (realname.isNotEmpty) return realname;
    if (nickname.isNotEmpty) return nickname;
    return '—';
  }

  String get avatarChar {
    final name = displayName;
    return name.isNotEmpty ? name.characters.first : '—';
  }
}

const List<Color> kHeadTeacherScoreTrendColors = [
  Color(0xFF8741FF),
  Color(0xFF325BFF),
  Color(0xFFFF323C),
  Color(0xFFDBEE49),
  Color(0xFF00B578),
  Color(0xFFFF8F1F),
];

List<Map<String, dynamic>> _mapList(dynamic raw) {
  if (raw is List) {
    return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }
  return const [];
}

int _pickInt(
  Map<String, dynamic> json,
  List<String> keys, {
  int fallback = 0,
}) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    if (value is int) return value;
    final parsed = int.tryParse(value.toString());
    if (parsed != null) return parsed;
  }
  return fallback;
}

String _pickString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty && text != 'null') return text;
  }
  return '';
}

bool _pickBool(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().trim().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
  }
  return false;
}
