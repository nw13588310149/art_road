import '../../../core/network/snowflake_id.dart';
import 'course_sign_data.dart';

enum TeacherAttendanceRange { total, term, month }

extension TeacherAttendanceRangeX on TeacherAttendanceRange {
  ({String? beginDate, String? endDate}) dates(DateTime now) {
    switch (this) {
      case TeacherAttendanceRange.total:
        return (beginDate: null, endDate: null);
      case TeacherAttendanceRange.term:
        final beginsInPreviousYear = now.month < 8;
        final begin = beginsInPreviousYear
            ? DateTime(now.year - 1, 8)
            : DateTime(now.year, 8);
        final end = beginsInPreviousYear
            ? DateTime(now.year, 7, 31)
            : DateTime(now.year + 1, 7, 31);
        return (beginDate: _isoDate(begin), endDate: _isoDate(end));
      case TeacherAttendanceRange.month:
        final begin = DateTime(now.year, now.month);
        final end = DateTime(now.year, now.month + 1, 0);
        return (beginDate: _isoDate(begin), endDate: _isoDate(end));
    }
  }
}

class TeacherAttendanceSummary {
  const TeacherAttendanceSummary({
    this.totalCount = 0,
    this.normalCount = 0,
    this.absentCount = 0,
    this.lateCount = 0,
    this.leaveCount = 0,
    this.attendanceRate = 0,
  });

  /// 签课总次数。
  final int totalCount;

  /// 正常签到次数。
  final int normalCount;

  /// 缺勤人次。
  final int absentCount;

  /// 迟到人次。
  final int lateCount;

  /// 请假人次。
  final int leaveCount;

  /// 出勤率，0–100 百分比数值（展示时自行补 %）。
  final double attendanceRate;

  factory TeacherAttendanceSummary.fromJson(dynamic raw) {
    final map = _unwrapMap(raw);
    if (map == null) return const TeacherAttendanceSummary();
    final rateRaw = map['attendanceRate'] ??
        map['onTimeRate'] ??
        map['punctualityRate'] ??
        map['rate'];
    var rate = 0.0;
    if (rateRaw != null) {
      final cleaned = rateRaw.toString().replaceAll('%', '').trim();
      final parsed = double.tryParse(cleaned);
      if (parsed != null) {
        rate = parsed > 0 && parsed <= 1 ? parsed * 100 : parsed;
      }
    }
    return TeacherAttendanceSummary(
      totalCount: _pickInt(map, [
        'totalCount',
        'signedCourseCount',
        'courseSignCount',
        'signCourseCount',
        'courseCount',
      ]),
      normalCount: _pickInt(map, [
        'normalCount',
        'presentCount',
        'signedCount',
      ]),
      absentCount: _pickInt(map, [
        'absentCount',
        'studentAbsentCount',
        'absenceCount',
        'absentNum',
      ]),
      lateCount: _pickInt(map, [
        'lateCount',
        'studentLateCount',
        'lateStudentCount',
        'lateNum',
      ]),
      leaveCount: _pickInt(map, ['leaveCount', 'leaveNum']),
      attendanceRate: rate,
    );
  }
}

class TeacherSignHistoryItem {
  const TeacherSignHistoryItem({
    required this.courseId,
    required this.date,
    required this.time,
    required this.courseName,
    required this.courseType,
    required this.lineNum,
    required this.className,
    required this.logoUrl,
    required this.signStatus,
    this.signInTime = '',
    this.signOutTime = '',
    this.canMakeup = false,
    this.makeupStatus,
    this.teacherId = '',
    this.teacherName = '',
    this.classroom = '',
    this.shouldCount = 0,
    this.presentCount = 0,
    this.method = '',
  });

  final String courseId;
  final String date;
  final String time;
  final String courseName;
  final int courseType;
  final int lineNum;
  final String className;
  final String logoUrl;
  final int signStatus;
  final String signInTime;
  final String signOutTime;
  final bool canMakeup;
  final int? makeupStatus;

  /// 任课老师 id；用于过滤「本人上过」的课次。
  final String teacherId;
  final String teacherName;
  final String classroom;
  final int shouldCount;
  final int presentCount;
  final String method;

  String get signStatusLabel => CourseSignFlowStatus.labelFor(signStatus);

  String get signInClock =>
      signInTime.trim().isEmpty ? '' : _clock(signInTime);

  String get signOutClock =>
      signOutTime.trim().isEmpty ? '' : _clock(signOutTime);

  String get avatarSeed {
    if (className.isNotEmpty && className != '--') return className;
    if (courseName.isNotEmpty) return courseName;
    return teacherName.isEmpty ? '?' : teacherName;
  }

  String get subtitle {
    final classLabel = className.isNotEmpty && className != '--'
        ? className
        : (classroom.isNotEmpty && classroom != '--' ? classroom : '');
    if (classLabel.isEmpty) return signStatusLabel;
    return '$classLabel·$signStatusLabel';
  }

  bool get hasAttendanceCounts => shouldCount > 0 || presentCount > 0;

  /// 是否大课 / 小课之一。
  bool get isBigOrSmallCourse =>
      isBigCourseType(courseType) || isSmallCourseType(courseType);

  /// 教师是否已完成该课次签到（大课一键入册 / 小课上下课签）。
  bool get isTeacherTaught {
    if (signInTime.trim().isNotEmpty || signOutTime.trim().isNotEmpty) {
      return true;
    }
    if (isSmallCourseType(courseType)) {
      return signStatus >= CourseSignFlowStatus.teacherStart.code;
    }
    if (isBigCourseType(courseType)) {
      return signStatus >= CourseSignFlowStatus.studentStart.code ||
          presentCount > 0;
    }
    return false;
  }

  /// 是否属于当前登录教师本人授课。
  bool belongsToTeacher(String? currentTeacherId) {
    if (currentTeacherId == null || currentTeacherId.isEmpty) return true;
    if (teacherId.isEmpty) return true;
    return teacherId == currentTeacherId;
  }

  factory TeacherSignHistoryItem.fromJson(Map<String, dynamic> json) {
    final flat = _flattenHistoryMap(json);
    final type = _pickInt(flat, ['type', 'courseType', 'classType']);
    final signInRaw = _pickString(flat, [
      'signInTime',
      'teacherSignInTime',
      'timeBegin',
      'beginTime',
    ]);
    final signOutRaw = _pickString(flat, [
      'signOutTime',
      'teacherSignOutTime',
      'timeEnd',
      'endTime',
    ]);
    final makeupRaw = flat['makeupStatus'];
    final makeupStatus = makeupRaw == null
        ? null
        : int.tryParse(makeupRaw.toString());
    return TeacherSignHistoryItem(
      courseId: pickFirstSnowflakeId(flat, ['courseId', 'id']) ?? '',
      date: _pickString(flat, ['date', 'courseDate', 'signDate', 'createTime']),
      time: signInRaw.isEmpty ? '' : _clock(signInRaw),
      courseName: _pickString(flat, [
        'courseName',
        'subjectName',
        'name',
        'title',
      ], fallback: '未命名课程'),
      courseType: type,
      lineNum: _pickInt(flat, ['lineNum', 'periodIndex', 'sectionNum']),
      className: _pickString(flat, [
        'className',
        'class',
        'classTitle',
        'gradeClassName',
      ], fallback: '--'),
      logoUrl: resolveCourseLogoUrl(flat),
      signStatus: _pickInt(flat, ['signStatus', 'courseSignStatus']),
      signInTime: signInRaw,
      signOutTime: signOutRaw,
      canMakeup: flat['canMakeup'] == true,
      makeupStatus: makeupStatus,
      teacherId: pickFirstSnowflakeId(flat, [
            'teacherId',
            'teacherUserId',
            'userId',
          ]) ??
          '',
      teacherName: _pickString(flat, [
        'teacherName',
        'teacherRealname',
        'realname',
      ], fallback: '任课老师'),
      classroom: _pickString(flat, [
        'classroomName',
        'roomName',
        'classroom',
        'address',
      ], fallback: '--'),
      shouldCount: _pickInt(flat, [
        'shouldCount',
        'studentShouldCount',
        'studentCount',
        'expectedCount',
      ]),
      presentCount: _pickInt(flat, [
        'presentCount',
        'studentPresentCount',
        'signedCount',
        'actualCount',
      ]),
      method: _pickString(flat, [
        'method',
        'signMethod',
        'signTypeName',
      ], fallback: type == 0 ? '教师一键签到' : '教师上下课签'),
    );
  }
}

class TeacherClassSignDetail {
  const TeacherClassSignDetail({
    required this.courseId,
    required this.courseSignStatus,
    required this.shouldCount,
    required this.presentCount,
    required this.students,
    this.teacherSignInTime,
    this.teacherSignOutTime,
    this.colorHex = '',
    this.className = '',
    this.logoUrl = '',
  });

  final String courseId;
  final int courseSignStatus;
  final int shouldCount;
  final int presentCount;
  final List<CourseSignStudent> students;
  final String? teacherSignInTime;
  final String? teacherSignOutTime;
  final String colorHex;
  final String className;
  final String logoUrl;

  factory TeacherClassSignDetail.fromJson(dynamic raw) {
    final map = _unwrapMap(raw) ?? const <String, dynamic>{};
    final merged = _mergeCourseDetailMap(map);
    final teacherSignIn = _asMap(merged['teacherSignIn']);
    return TeacherClassSignDetail(
      courseId: pickFirstSnowflakeId(merged, ['courseId', 'id']) ?? '',
      courseSignStatus: _pickInt(merged, ['courseSignStatus', 'signStatus']),
      shouldCount: _pickInt(merged, ['shouldCount', 'studentCount']),
      presentCount: _pickInt(merged, ['presentCount', 'signedCount']),
      students: parseCourseSignStudentList(
        merged['studentList'] ?? merged['students'] ?? merged['list'],
      ),
      teacherSignInTime: teacherSignIn == null
          ? null
          : _pickString(teacherSignIn, ['signInTime', 'teacherSignInTime']),
      teacherSignOutTime: teacherSignIn == null
          ? null
          : _pickString(teacherSignIn, ['signOutTime', 'teacherSignOutTime']),
      colorHex: _pickString(merged, ['color']),
      className: _pickString(merged, ['className', 'class']),
      logoUrl: resolveCourseLogoUrl(merged),
    );
  }
}

Map<String, dynamic> _mergeCourseDetailMap(Map<String, dynamic> map) {
  final merged = Map<String, dynamic>.from(map);
  final course = _asMap(map['course']);
  if (course == null) return merged;
  for (final entry in course.entries) {
    merged.putIfAbsent(entry.key, () => entry.value);
  }
  merged.putIfAbsent('courseId', () => course['id']);
  return merged;
}

List<TeacherSignHistoryItem> parseTeacherSignHistoryList(dynamic raw) {
  final rows = _unwrapList(raw);
  return rows
      .map((item) => TeacherSignHistoryItem.fromJson(item))
      .toList(growable: false);
}

/// 历史 / 最近签课：仅保留当前教师本人已完成签到的大课、小课。
List<TeacherSignHistoryItem> filterTeacherTaughtSignHistory(
  List<TeacherSignHistoryItem> records, {
  String? currentTeacherId,
}) {
  return records
      .where(
        (item) =>
            item.isBigOrSmallCourse &&
            item.belongsToTeacher(currentTeacherId) &&
            item.isTeacherTaught,
      )
      .toList(growable: false);
}

Map<String, dynamic> _flattenHistoryMap(Map<String, dynamic> source) {
  final result = Map<String, dynamic>.from(source);
  void merge(dynamic raw, Map<String, String> aliases) {
    final nested = _asMap(raw);
    if (nested == null) return;
    for (final entry in nested.entries) {
      result.putIfAbsent(entry.key, () => entry.value);
      final alias = aliases[entry.key];
      if (alias != null) result.putIfAbsent(alias, () => entry.value);
    }
  }

  merge(source['course'], const {
    'id': 'courseId',
    'date': 'courseDate',
    'type': 'courseType',
    'lineNum': 'lineNum',
    'timeBegin': 'timeBegin',
    'timeEnd': 'timeEnd',
  });
  merge(source['subject'], const {'name': 'subjectName'});
  merge(source['teacher'], const {
    'realname': 'teacherRealname',
    'id': 'teacherId',
    'userId': 'teacherUserId',
  });
  merge(source['classroom'], const {'name': 'classroomName'});
  merge(source['class'], const {
    'name': 'className',
    'className': 'className',
    'logo': 'logo',
  });
  merge(source['schoolClass'], const {
    'name': 'className',
    'className': 'className',
    'logo': 'logo',
  });
  merge(source['classInfo'], const {
    'name': 'className',
    'className': 'className',
    'logo': 'logo',
  });
  return result;
}

Map<String, dynamic>? _unwrapMap(dynamic raw) {
  final map = _asMap(raw);
  if (map == null) return null;
  for (final key in ['data', 'result', 'record']) {
    final nested = _asMap(map[key]);
    if (nested != null) return nested;
  }
  return map;
}

List<Map<String, dynamic>> _unwrapList(dynamic raw) {
  if (raw is List) {
    return raw.map(_asMap).whereType<Map<String, dynamic>>().toList();
  }
  final map = _asMap(raw);
  if (map == null) return const [];
  for (final key in ['records', 'list', 'rows', 'data']) {
    final value = map[key];
    if (value is List) {
      return value.map(_asMap).whereType<Map<String, dynamic>>().toList();
    }
    final nested = _asMap(value);
    if (nested != null) {
      final list = _unwrapList(nested);
      if (list.isNotEmpty) return list;
    }
  }
  return const [];
}

Map<String, dynamic>? _asMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

int _pickInt(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = int.tryParse(map[key]?.toString() ?? '');
    if (value != null) return value;
  }
  return 0;
}

String _pickString(
  Map<String, dynamic> map,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = map[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value != 'null') return value;
  }
  return fallback;
}

String _clock(String value) {
  final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(value);
  if (match == null) return value;
  return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
}

String _isoDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
