import '../../../core/network/snowflake_id.dart';

class AdminStudentExamRecord {
  const AdminStudentExamRecord({
    required this.examId,
    required this.examName,
    required this.examDate,
    required this.totalScore,
    required this.classRank,
    required this.schoolRank,
    required this.teacherNames,
    required this.subjectScores,
  });

  final String examId;
  final String examName;
  final String examDate;
  final num? totalScore;
  final int classRank;
  final int schoolRank;
  final String teacherNames;
  final List<AdminStudentSubjectScore> subjectScores;

  factory AdminStudentExamRecord.fromJson(Map<String, dynamic> map) {
    return AdminStudentExamRecord(
      examId: pickFirstSnowflakeId(map, ['examId', 'id']) ?? '',
      examName: _pickString(map, ['examName', 'name'], '未命名考试'),
      examDate: _pickString(map, ['examDate', 'date']),
      totalScore: _readNum(map['totalScore']),
      classRank: _readInt(map['classRank']),
      schoolRank: _readInt(map['schoolRank']),
      teacherNames: _pickString(map, ['teacherNames']),
      subjectScores: _unwrapList(
        map['subjectScores'],
      ).map(AdminStudentSubjectScore.fromJson).toList(growable: false),
    );
  }
}

class AdminStudentSubjectScore {
  const AdminStudentSubjectScore({
    required this.subjectName,
    required this.score,
    required this.comment,
  });

  final String subjectName;
  final num? score;
  final String comment;

  factory AdminStudentSubjectScore.fromJson(Map<String, dynamic> map) {
    return AdminStudentSubjectScore(
      subjectName: _pickString(map, ['subjectName', 'name'], '未命名科目'),
      score: _readNum(map['score']),
      comment: _pickString(map, ['comment']),
    );
  }
}

List<AdminStudentExamRecord> parseAdminStudentExamRecords(dynamic raw) {
  return _unwrapList(
    raw,
  ).map(AdminStudentExamRecord.fromJson).toList(growable: false);
}

List<Map<String, dynamic>> _unwrapList(dynamic raw) {
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);
    for (final key in ['data', 'records', 'list', 'rows']) {
      final nested = _unwrapList(map[key]);
      if (nested.isNotEmpty) return nested;
    }
  }
  return const [];
}

String _pickString(
  Map<String, dynamic> map,
  List<String> keys, [
  String fallback = '',
]) {
  for (final key in keys) {
    final value = map[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value != 'null') return value;
  }
  return fallback;
}

int _readInt(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}

num? _readNum(dynamic raw) {
  if (raw is num) return raw;
  return num.tryParse(raw?.toString() ?? '');
}
