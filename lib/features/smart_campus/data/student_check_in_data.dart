/// 学生端「课堂签到」：今日小课解析与签到状态推导。
library;

import '../../../core/network/snowflake_id.dart';
import 'course_sign_data.dart';

export 'course_sign_data.dart' show CourseSignFlowStatus, pickCourseClock;

enum StudentCourseSlotPhase { inProgress, upcoming, ended }

class StudentTimeConfig {
  const StudentTimeConfig({
    required this.lineNum,
    required this.start,
    required this.end,
  });

  final int lineNum;
  final String start;
  final String end;
}

const List<StudentTimeConfig> kDefaultStudentTimeConfigs = [
  StudentTimeConfig(lineNum: 1, start: '08:00', end: '08:40'),
  StudentTimeConfig(lineNum: 2, start: '08:50', end: '09:35'),
  StudentTimeConfig(lineNum: 3, start: '09:50', end: '10:30'),
  StudentTimeConfig(lineNum: 4, start: '10:30', end: '11:25'),
  StudentTimeConfig(lineNum: 5, start: '14:00', end: '14:45'),
];

class StudentTodayCourse {
  const StudentTodayCourse({
    required this.courseId,
    required this.subjectName,
    required this.teacherName,
    required this.location,
    required this.timeStart,
    required this.timeEnd,
    required this.durationLabel,
    required this.lineNum,
    required this.phase,
    this.signRecordId = '',
    this.courseSignStatus = 0,
    this.teacherSignInTime,
    this.teacherSignOutTime,
    this.studentSignInTime,
    this.studentSignOutTime,
    this.signMethod = '按键打卡',
    this.fenceLabel,
    this.evaluationScore,
    this.evaluationComment,
    this.teacherHeadUrl = '',
    this.teacherId = '',
  });

  final String courseId;
  final String subjectName;
  final String teacherName;
  final String location;
  final String timeStart;
  final String timeEnd;
  final String durationLabel;
  final int lineNum;
  final StudentCourseSlotPhase phase;

  /// 签到记录主键（`courseSignDetail` 的 `id`），与 [courseId] 不同。
  final String signRecordId;

  /// 课程签到流程状态：0 未签到 … 7 管理员驳回。
  final int courseSignStatus;
  final String? teacherSignInTime;
  final String? teacherSignOutTime;
  final String? studentSignInTime;
  final String? studentSignOutTime;
  final String signMethod;
  final String? fenceLabel;
  final double? evaluationScore;
  final String? evaluationComment;

  /// 任课老师头像（`teacherHeadUrl`，相对路径，渲染前经 `MediaUrl.resolve`）。
  final String teacherHeadUrl;

  /// 任课老师 id（`teacherId`），用于跨接口回填教师头像。
  final String teacherId;

  String get periodLabel =>
      lineNum > 0 ? '第$lineNum节' : '今日课程';

  String get timeRange => '$timeStart-$timeEnd';

  // 学生端签到流程门控，统一以课程流程状态 [courseSignStatus] 为准（来源于
  // `courseList` 的 `signStatus`，老师签到后会随之推进）：
  //   0 未签到 → 1 老师上课签 → 2 学生上课签 → 3 老师下课签 → 4 学生下课签 → 5 学生评价
  // 学生端接口（`courseSignDetail`）只回本人考勤记录，不含流程状态与老师时间，
  // 因此这里不再依赖打卡时间反推，避免轮询时把流程状态覆盖丢失。

  /// 老师是否已上课签到（流程 ≥1）。
  bool get teacherSignedIn =>
      courseSignStatus >= CourseSignFlowStatus.teacherStart.code;

  /// 老师是否已下课签到（流程 ≥3）。
  bool get teacherSignedOut =>
      courseSignStatus >= CourseSignFlowStatus.teacherEnd.code;

  /// 学生是否已上课签到（流程 ≥2）。
  bool get studentSignedIn =>
      courseSignStatus >= CourseSignFlowStatus.studentStart.code;

  /// 学生是否已下课签到（流程 ≥4）。
  bool get studentSignedOut =>
      courseSignStatus >= CourseSignFlowStatus.studentEnd.code;

  /// 学生是否已评价（流程 ≥5）。
  bool get studentEvaluated =>
      courseSignStatus >= CourseSignFlowStatus.studentEval.code;

  /// 学生上课签到：老师已上课签、学生尚未上课签（流程恰为 1）。
  bool get canCheckIn =>
      courseSignStatus == CourseSignFlowStatus.teacherStart.code;

  /// 学生下课签到：老师已下课签、学生尚未下课签（流程恰为 3）。
  bool get canCheckOut =>
      courseSignStatus == CourseSignFlowStatus.teacherEnd.code;

  /// 学生评价：学生已下课签、尚未评价（流程恰为 4）。
  bool get canComment =>
      courseSignStatus == CourseSignFlowStatus.studentEnd.code;

  StudentTodayCourse copyWith({
    String? signRecordId,
    int? courseSignStatus,
    String? teacherSignInTime,
    String? teacherSignOutTime,
    String? studentSignInTime,
    String? studentSignOutTime,
    String? signMethod,
    String? fenceLabel,
    double? evaluationScore,
    String? evaluationComment,
  }) {
    return StudentTodayCourse(
      courseId: courseId,
      subjectName: subjectName,
      teacherName: teacherName,
      location: location,
      timeStart: timeStart,
      timeEnd: timeEnd,
      durationLabel: durationLabel,
      lineNum: lineNum,
      phase: phase,
      signRecordId: signRecordId ?? this.signRecordId,
      courseSignStatus: courseSignStatus ?? this.courseSignStatus,
      teacherSignInTime: teacherSignInTime ?? this.teacherSignInTime,
      teacherSignOutTime: teacherSignOutTime ?? this.teacherSignOutTime,
      studentSignInTime: studentSignInTime ?? this.studentSignInTime,
      studentSignOutTime: studentSignOutTime ?? this.studentSignOutTime,
      signMethod: signMethod ?? this.signMethod,
      fenceLabel: fenceLabel ?? this.fenceLabel,
      evaluationScore: evaluationScore ?? this.evaluationScore,
      evaluationComment: evaluationComment ?? this.evaluationComment,
      teacherHeadUrl: teacherHeadUrl,
      teacherId: teacherId,
    );
  }

}

List<StudentTodayCourse> parseStudentTodaySmallCourses({
  required dynamic raw,
  required List<StudentTimeConfig> timeConfigs,
  required DateTime now,
  String todayIso = '',
}) {
  final configs =
      timeConfigs.isNotEmpty ? timeConfigs : kDefaultStudentTimeConfigs;
  final rows = _extractCourseRows(raw);
  final courses = <StudentTodayCourse>[];

  for (final row in rows) {
    final flat = _flattenCourseRow(row);
    if (!_isSmallCourse(flat)) continue;

    final dateStr = _pickString(flat, ['date', 'classDate', 'courseDate'], '');
    if (todayIso.isNotEmpty &&
        dateStr.isNotEmpty &&
        !_sameDay(dateStr, todayIso)) {
      continue;
    }

    final courseId = readSnowflakeId(flat['id'] ?? flat['courseId']) ?? '';
    if (courseId.isEmpty) continue;

    final times = _resolveRowTimes(flat, configs);
    if (times.start.isEmpty || times.end.isEmpty) continue;

    final subjectName = _pickString(flat, [
      'subjectName',
      'courseName',
      'subject',
      'name',
    ], '—');
    final teacherName = _pickString(flat, [
      'teacherRealname',
      'teacherName',
      'realname',
      'realName',
      'teacherNickname',
      'teacher',
    ], '—');
    final location = _pickString(flat, [
      'classroomName',
      'roomName',
      'classroom',
    ], '—');

    final mins = _minutesBetweenHm(times.start, times.end);
    final durationLabel = mins > 0 ? '$mins分钟' : '—';

    final scoreRaw = flat['score'] ?? flat['commentScore'] ?? flat['studentScore'];
    final score = scoreRaw == null
        ? null
        : double.tryParse(scoreRaw.toString());

    courses.add(
      StudentTodayCourse(
        courseId: courseId,
        subjectName: subjectName,
        teacherName: teacherName,
        location: location,
        timeStart: times.start,
        timeEnd: times.end,
        durationLabel: durationLabel,
        lineNum: times.lineNum,
        phase: _slotPhase(now, times.start, times.end),
        courseSignStatus: _pickInt(flat, [
          'courseSignStatus',
          'signStatus',
          'signStep',
        ]),
        teacherSignInTime: _pickNullable(flat, [
          'teacherSignInTime',
          'teacherCheckInTime',
          'teacherSignTime',
        ]),
        teacherSignOutTime: _pickNullable(flat, [
          'teacherSignOutTime',
          'teacherCheckOutTime',
        ]),
        studentSignInTime: _pickNullable(flat, [
          'studentSignInTime',
          'studentCheckInTime',
          'signInTime',
          'checkInTime',
        ]),
        studentSignOutTime: _pickNullable(flat, [
          'studentSignOutTime',
          'studentCheckOutTime',
          'signOutTime',
          'checkOutTime',
        ]),
        signMethod: _pickString(flat, [
          'signMethod',
          'signTypeName',
          'checkMethod',
          'method',
        ], '按键打卡'),
        fenceLabel: _pickNullable(flat, [
          'fenceLabel',
          'fenceName',
          'locationTip',
        ]),
        evaluationScore: score,
        evaluationComment: _pickNullable(flat, [
          'comment',
          'studentComment',
          'evaluation',
          'evaluate',
        ]),
        teacherHeadUrl: _pickString(flat, [
          'teacherHeadUrl',
          'headUrl',
        ], ''),
        teacherId: readSnowflakeId(flat['teacherId']) ?? '',
      ),
    );
  }

  courses.sort((a, b) {
    final byStart = _hmSortKey(a.timeStart).compareTo(_hmSortKey(b.timeStart));
    if (byStart != 0) return byStart;
    return a.lineNum.compareTo(b.lineNum);
  });
  return courses;
}

StudentTodayCourse? pickActiveStudentCourse(List<StudentTodayCourse> courses) {
  if (courses.isEmpty) return null;
  for (final c in courses) {
    if (c.phase == StudentCourseSlotPhase.inProgress) return c;
  }
  for (final c in courses) {
    if (c.phase == StudentCourseSlotPhase.upcoming) return c;
  }
  return courses.last;
}

List<StudentTimeConfig> parseStudentTimeConfigs(dynamic raw) {
  final list = _extractList(raw);
  final configs = <StudentTimeConfig>[];
  for (final m in list) {
    final lineNumRaw = m['lineNum'];
    final lineNum = lineNumRaw is int
        ? lineNumRaw
        : (int.tryParse(lineNumRaw?.toString() ?? '') ?? 0);
    if (lineNum < 1) continue;
    final start = _trimHm(
      _pickString(m, ['timeBegin', 'startTime', 'beginTime', 'start'], ''),
    );
    final end = _trimHm(
      _pickString(m, ['timeEnd', 'endTime', 'finishTime', 'end'], ''),
    );
    if (start.isEmpty || end.isEmpty) continue;
    configs.add(StudentTimeConfig(lineNum: lineNum, start: start, end: end));
  }
  configs.sort((a, b) => a.lineNum.compareTo(b.lineNum));
  return configs;
}

String formatChineseDateTitle(DateTime date) {
  const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return '${date.year}年${date.month}月${date.day}日 '
      '${weekdays[date.weekday - 1]}';
}

String todayIsoDate() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

class _ResolvedRowTimes {
  const _ResolvedRowTimes({
    required this.lineNum,
    required this.start,
    required this.end,
  });

  final int lineNum;
  final String start;
  final String end;
}

_ResolvedRowTimes _resolveRowTimes(
  Map<String, dynamic> row,
  List<StudentTimeConfig> configs,
) {
  final lineNumRaw = row['lineNum'];
  final lineNum = lineNumRaw is int
      ? lineNumRaw
      : (int.tryParse(lineNumRaw?.toString() ?? '') ?? 0);

  if (lineNum > 0) {
    for (final c in configs) {
      if (c.lineNum == lineNum) {
        return _ResolvedRowTimes(lineNum: lineNum, start: c.start, end: c.end);
      }
    }
    if (lineNum <= configs.length) {
      final c = configs[lineNum - 1];
      return _ResolvedRowTimes(lineNum: lineNum, start: c.start, end: c.end);
    }
  }

  final start = _trimHm(
    _pickString(row, ['timeBegin', 'startTime', 'beginTime', 'start'], ''),
  );
  final end = _trimHm(
    _pickString(row, ['timeEnd', 'endTime', 'finishTime', 'end'], ''),
  );
  return _ResolvedRowTimes(lineNum: lineNum, start: start, end: end);
}

bool _isSmallCourse(Map<String, dynamic> json) {
  final typeRaw = json['type'];
  final type = typeRaw is int
      ? typeRaw
      : (int.tryParse(typeRaw?.toString() ?? '') ?? 0);
  return type == 1;
}

StudentCourseSlotPhase _slotPhase(DateTime now, String startHm, String endHm) {
  final start = _dateAtHm(now, startHm);
  final end = _dateAtHm(now, endHm);
  if (start == null || end == null) return StudentCourseSlotPhase.upcoming;
  if (now.isBefore(start)) return StudentCourseSlotPhase.upcoming;
  if (now.isAfter(end)) return StudentCourseSlotPhase.ended;
  return StudentCourseSlotPhase.inProgress;
}

DateTime? _dateAtHm(DateTime day, String hm) {
  final parts = hm.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return DateTime(day.year, day.month, day.day, h, m);
}

int _hmSortKey(String hm) {
  final parts = hm.split(':');
  if (parts.length < 2) return 0;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  return h * 60 + m;
}

int _minutesBetweenHm(String start, String end) {
  final a = _hmSortKey(start);
  final b = _hmSortKey(end);
  if (a <= 0 || b <= 0 || b <= a) return 0;
  return b - a;
}

bool _sameDay(String dateStr, String todayIso) {
  final d = DateTime.tryParse(dateStr.split('T').first);
  if (d == null) return dateStr.startsWith(todayIso);
  final iso =
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  return iso == todayIso;
}

Map<String, dynamic> _flattenCourseRow(Map<String, dynamic> row) {
  final flat = Map<String, dynamic>.from(row);

  void mergeNested(String key, List<MapEntry<String, String>> fieldMap) {
    final nested = row[key];
    if (nested is! Map) return;
    final m = Map<String, dynamic>.from(nested);
    for (final entry in fieldMap) {
      final v = m[entry.key];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isEmpty) continue;
      flat.putIfAbsent(entry.value, () => s);
    }
  }

  mergeNested('teacher', [
    const MapEntry('realname', 'teacherRealname'),
    const MapEntry('realName', 'teacherRealname'),
    const MapEntry('nickname', 'teacherNickname'),
    const MapEntry('name', 'teacherName'),
  ]);
  mergeNested('subject', [
    const MapEntry('name', 'subjectName'),
    const MapEntry('subjectName', 'subjectName'),
  ]);
  mergeNested('schoolClass', [
    const MapEntry('name', 'className'),
    const MapEntry('className', 'className'),
    const MapEntry('id', 'classId'),
  ]);
  mergeNested('schoolClassroom', [
    const MapEntry('name', 'classroomName'),
    const MapEntry('roomName', 'classroomName'),
  ]);

  return flat;
}

List<Map<String, dynamic>> _extractCourseRows(dynamic raw) {
  final list = <Map<String, dynamic>>[];
  if (raw is Map) {
    for (final entry in raw.entries) {
      final v = entry.value;
      if (v is List) {
        for (final item in v) {
          if (item is Map) {
            list.add(_flattenCourseRow(Map<String, dynamic>.from(item)));
          }
        }
      }
    }
  } else if (raw is List) {
    for (final item in raw) {
      if (item is Map) {
        list.add(_flattenCourseRow(Map<String, dynamic>.from(item)));
      }
    }
  }
  return list;
}

List<Map<String, dynamic>> _extractList(dynamic raw) {
  if (raw is List) {
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }
  final map = raw is Map ? Map<String, dynamic>.from(raw) : null;
  if (map == null) return const [];
  for (final key in ['records', 'list', 'data', 'rows']) {
    final inner = map[key];
    if (inner is List) {
      return [
        for (final item in inner)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
    }
  }
  return const [];
}

String _pickString(
  Map<String, dynamic> json,
  List<String> keys, [
  String fallback = '',
]) {
  for (final key in keys) {
    final raw = json[key];
    if (raw == null) continue;
    final text = raw.toString().trim();
    if (text.isNotEmpty && text != 'null') return text;
  }
  return fallback;
}

String? _pickNullable(Map<String, dynamic> json, List<String> keys) {
  final value = _pickString(json, keys, '');
  return value.isEmpty ? null : value;
}

String _trimHm(String value) {
  if (value.isEmpty) return value;
  final parts = value.split(':');
  if (parts.length >= 2) {
    return '${parts[0]}:${parts[1]}';
  }
  return value;
}

// ── 签到统计 / 记录 / 详情 ─────────────────────────────────────────────

enum StudentCheckInHistoryRange { week, month, semester }

extension StudentCheckInHistoryRangeX on StudentCheckInHistoryRange {
  ({String beginDate, String endDate}) dates(DateTime now) {
    switch (this) {
      case StudentCheckInHistoryRange.week:
        final monday = DateTime(
          now.year,
          now.month,
          now.day - (now.weekday - 1),
        );
        final sunday = monday.add(const Duration(days: 6));
        return (beginDate: _isoDate(monday), endDate: _isoDate(sunday));
      case StudentCheckInHistoryRange.month:
        final begin = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0);
        return (beginDate: _isoDate(begin), endDate: _isoDate(end));
      case StudentCheckInHistoryRange.semester:
        final month = now.month;
        if (month >= 2 && month <= 7) {
          return (
            beginDate: _isoDate(DateTime(now.year, 2, 1)),
            endDate: _isoDate(DateTime(now.year, 7, 31)),
          );
        }
        if (month >= 8) {
          return (
            beginDate: _isoDate(DateTime(now.year, 8, 1)),
            endDate: _isoDate(DateTime(now.year + 1, 1, 31)),
          );
        }
        return (
          beginDate: _isoDate(DateTime(now.year - 1, 8, 1)),
          endDate: _isoDate(DateTime(now.year, 1, 31)),
        );
    }
  }
}

/// 本学期统计区间（与历史抽屉「本学期」一致）。
({String beginDate, String endDate}) studentCheckInSemesterDates(DateTime now) {
  return StudentCheckInHistoryRange.semester.dates(now);
}

/// 学生签到统计（`courseSignStat`）。实测返回字段：
/// `totalCount` / `normalCount` / `absentCount` / `lateCount` /
/// `leaveCount` / `attendanceRate`(如 "0%")。
class StudentCheckInStat {
  const StudentCheckInStat({
    this.totalCount = 0,
    this.normalCount = 0,
    this.absentCount = 0,
    this.lateCount = 0,
    this.leaveCount = 0,
    this.attendanceRate = 0,
  });

  /// 应签课次。
  final int totalCount;

  /// 正常签到课次。
  final int normalCount;

  /// 缺勤课次。
  final int absentCount;

  /// 迟到课次。
  final int lateCount;

  /// 请假课次。
  final int leaveCount;

  /// 出勤率，0–100 百分比数值（展示时自行补 %）。
  final double attendanceRate;

  factory StudentCheckInStat.fromJson(dynamic raw) {
    final map = _unwrapMap(raw) ?? const <String, dynamic>{};
    final rateRaw = map['attendanceRate'] ??
        map['onTimeRate'] ??
        map['punctualityRate'] ??
        map['rate'];
    double rate = 0;
    if (rateRaw != null) {
      // 兼容 "0%" / "96.5%" / 0.965 等格式。
      final cleaned = rateRaw.toString().replaceAll('%', '').trim();
      final parsed = double.tryParse(cleaned);
      if (parsed != null) {
        rate = parsed > 0 && parsed <= 1 ? parsed * 100 : parsed;
      }
    }
    return StudentCheckInStat(
      totalCount: _pickInt(map, ['totalCount', 'shouldCount', 'shouldSignCount']),
      normalCount: _pickInt(map, ['normalCount', 'presentCount', 'signedCount']),
      absentCount: _pickInt(map, ['absentCount', 'absentNum']),
      lateCount: _pickInt(map, ['lateCount', 'lateNum']),
      leaveCount: _pickInt(map, ['leaveCount', 'leaveNum']),
      attendanceRate: rate,
    );
  }
}

/// 学生签到记录（最近记录 / 历史列表共用）。
class StudentSignRecordItem {
  const StudentSignRecordItem({
    required this.signRecordId,
    required this.courseId,
    required this.date,
    required this.subjectName,
    required this.teacherName,
    required this.location,
    required this.durationLabel,
    required this.isAbsent,
    required this.courseType,
    this.timeStart = '',
    this.timeEnd = '',
    this.studentSignInTime,
    this.studentSignOutTime,
    this.method = '',
    this.note = '',
    this.teacherHeadUrl = '',
    this.lineNum = 0,
    this.className = '',
    this.teacherId = '',
  });

  final String signRecordId;
  final String courseId;
  final String date;
  final String subjectName;
  final String teacherName;
  final String location;
  final String durationLabel;
  final bool isAbsent;
  final int courseType;

  /// 课表起止时间（`timeBegin` / `timeEnd`，`HH:mm`）。
  final String timeStart;
  final String timeEnd;
  final String? studentSignInTime;
  final String? studentSignOutTime;
  final String method;
  final String note;

  /// 任课老师头像（`teacherHeadUrl`，相对路径，渲染前经 `MediaUrl.resolve`）。
  final String teacherHeadUrl;

  /// 节次序号（`lineNum`）。
  final int lineNum;

  /// 所属班级名（`className`）。
  final String className;

  /// 任课老师 id（`teacherId`），用于跨接口回填教师头像。
  final String teacherId;

  bool get isSmallCourse => courseType == 1;

  factory StudentSignRecordItem.fromJson(Map<String, dynamic> json) {
    final flat = _flattenSignRecordRow(json);
    final type = _pickInt(flat, ['type', 'courseType', 'classType']);
    final status = _pickInt(flat, ['status', 'signStatus', 'attendanceStatus']);
    final absentFlag = flat['isAbsent'] == true ||
        flat['absent'] == true ||
        status == 1;
    final begin = _trimHm(
      _pickString(flat, ['timeBegin', 'startTime', 'beginTime'], ''),
    );
    final end = _trimHm(
      _pickString(flat, ['timeEnd', 'endTime', 'finishTime'], ''),
    );
    final mins = _minutesBetweenHm(begin, end);
    return StudentSignRecordItem(
      signRecordId: readSnowflakeId(flat['id']) ?? '',
      courseId: readSnowflakeId(flat['courseId']) ?? '',
      date: _pickString(flat, ['date', 'courseDate', 'classDate'], ''),
      subjectName: _pickString(flat, [
        'subjectName',
        'courseName',
        'name',
      ], '—'),
      teacherName: _pickString(flat, [
        'teacherName',
        'teacherRealname',
        'realname',
      ], '—'),
      location: _pickString(flat, [
        'classroomName',
        'roomName',
        'classroom',
        'location',
      ], '—'),
      durationLabel: mins > 0 ? '$mins分钟' : '—',
      isAbsent: absentFlag,
      courseType: type,
      timeStart: begin,
      timeEnd: end,
      studentSignInTime: _pickNullable(flat, [
        'studentSignInTime',
        'signInTime',
        'checkInTime',
      ]),
      studentSignOutTime: _pickNullable(flat, [
        'studentSignOutTime',
        'signOutTime',
        'checkOutTime',
      ]),
      method: _pickString(flat, [
        'signMethod',
        'method',
        'signTypeName',
      ], ''),
      note: _pickString(flat, [
        'remark',
        'note',
        'reason',
        'description',
      ], ''),
      teacherHeadUrl: _pickString(flat, [
        'teacherHeadUrl',
        'headUrl',
      ], ''),
      lineNum: _pickInt(flat, ['lineNum']),
      className: _pickString(flat, ['className'], ''),
      teacherId: readSnowflakeId(flat['teacherId']) ?? '',
    );
  }
}

String? _normalizeStudentSignClock(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed == '-') return null;
  return pickCourseClock(trimmed) ?? trimmed;
}

/// 学生端「单条签到记录详情」(`courseSignDetail`)。
///
/// 实测返回是**学生本人**的扁平考勤记录，**不含**课程流程状态、老师签到
/// 时间或学生子对象：
/// ```json
/// {"id":"59","courseId":"...","status":1,"signInTime":null,
///  "signOutTime":null,"comment":null,"score":null}
/// ```
/// 因此本类只承载本人签到时间 / 考勤结果 / 评价，流程状态另由 `courseList`
/// 的 `signStatus` 提供。`status`：0 出勤 / 1 缺勤 / 2 迟到 / 3 请假。
class StudentCourseSignDetail {
  const StudentCourseSignDetail({
    required this.signRecordId,
    required this.courseId,
    this.attendanceStatus = 0,
    this.studentSignInTime,
    this.studentSignOutTime,
    this.evaluationScore,
    this.evaluationComment,
  });

  final String signRecordId;
  final String courseId;

  /// 本人考勤结果：0 出勤 / 1 缺勤 / 2 迟到 / 3 请假。
  final int attendanceStatus;
  final String? studentSignInTime;
  final String? studentSignOutTime;
  final double? evaluationScore;
  final String? evaluationComment;

  factory StudentCourseSignDetail.fromJson(dynamic raw) {
    final map = _unwrapMap(raw) ?? const <String, dynamic>{};
    final scoreRaw = map['score'] ?? map['commentScore'] ?? map['studentScore'];
    return StudentCourseSignDetail(
      signRecordId: readSnowflakeId(map['id']) ?? '',
      courseId: readSnowflakeId(map['courseId']) ?? '',
      attendanceStatus: _pickInt(map, [
        'status',
        'signStatus',
        'attendanceStatus',
      ]),
      studentSignInTime: _normalizeStudentSignClock(
        _pickNullable(map, [
          'signInTime',
          'studentSignInTime',
          'studentCheckInTime',
          'checkInTime',
        ]),
      ),
      studentSignOutTime: _normalizeStudentSignClock(
        _pickNullable(map, [
          'signOutTime',
          'studentSignOutTime',
          'studentCheckOutTime',
          'checkOutTime',
        ]),
      ),
      evaluationScore: scoreRaw == null
          ? null
          : double.tryParse(scoreRaw.toString()),
      evaluationComment: _pickNullable(map, [
        'comment',
        'studentComment',
        'evaluation',
        'evaluate',
      ]),
    );
  }

  /// 仅回填本人相关字段；**不触碰** [StudentTodayCourse.courseSignStatus]
  /// 与老师签到时间（它们来自 `courseList`，否则轮询会把流程状态覆盖丢失）。
  StudentTodayCourse applyTo(StudentTodayCourse course) {
    return course.copyWith(
      signRecordId: signRecordId.isNotEmpty
          ? signRecordId
          : course.signRecordId,
      studentSignInTime: studentSignInTime ?? course.studentSignInTime,
      studentSignOutTime: studentSignOutTime ?? course.studentSignOutTime,
      evaluationScore: evaluationScore ?? course.evaluationScore,
      evaluationComment: evaluationComment ?? course.evaluationComment,
    );
  }
}

List<StudentSignRecordItem> parseStudentSignRecordList(dynamic raw) {
  final rows = _extractSignRecordRows(raw);
  return rows
      .map(StudentSignRecordItem.fromJson)
      .where((item) => item.date.isNotEmpty || item.subjectName != '—')
      .toList(growable: false);
}

/// 用最近/历史签到记录里的 `id` 回填今日小课的 [StudentTodayCourse.signRecordId]。
List<StudentTodayCourse> attachSignRecordIdsToCourses(
  List<StudentTodayCourse> courses,
  List<StudentSignRecordItem> records,
) {
  if (courses.isEmpty || records.isEmpty) return courses;
  final byCourseId = <String, String>{};
  for (final record in records) {
    if (record.signRecordId.isEmpty || record.courseId.isEmpty) continue;
    byCourseId.putIfAbsent(record.courseId, () => record.signRecordId);
  }
  if (byCourseId.isEmpty) return courses;
  return [
    for (final course in courses)
      course.copyWith(
        signRecordId: byCourseId[course.courseId] ?? course.signRecordId,
      ),
  ];
}

String? findSignRecordIdForCourse(
  String courseId, {
  required List<StudentTodayCourse> courses,
  required List<StudentSignRecordItem> recentRecords,
  List<StudentSignRecordItem> historyRecords = const [],
}) {
  if (courseId.isEmpty) return null;
  for (final course in courses) {
    if (course.courseId == courseId && course.signRecordId.isNotEmpty) {
      return course.signRecordId;
    }
  }
  for (final record in recentRecords) {
    if (record.courseId == courseId && record.signRecordId.isNotEmpty) {
      return record.signRecordId;
    }
  }
  for (final record in historyRecords) {
    if (record.courseId == courseId && record.signRecordId.isNotEmpty) {
      return record.signRecordId;
    }
  }
  return null;
}

Map<String, dynamic> _flattenSignRecordRow(Map<String, dynamic> row) {
  final flat = Map<String, dynamic>.from(row);
  void merge(String key, List<MapEntry<String, String>> aliases) {
    final nested = row[key];
    if (nested is! Map) return;
    final m = Map<String, dynamic>.from(nested);
    for (final entry in aliases) {
      final v = m[entry.key];
      if (v == null) continue;
      flat.putIfAbsent(entry.value, () => v);
    }
  }

  merge('course', const [
    MapEntry('id', 'courseId'),
    MapEntry('date', 'courseDate'),
    MapEntry('type', 'courseType'),
  ]);
  merge('subject', const [
    MapEntry('name', 'subjectName'),
  ]);
  merge('teacher', const [
    MapEntry('realname', 'teacherRealname'),
    MapEntry('name', 'teacherName'),
  ]);
  merge('classroom', const [
    MapEntry('name', 'classroomName'),
  ]);
  merge('schoolClassroom', const [
    MapEntry('name', 'classroomName'),
  ]);
  return flat;
}

List<Map<String, dynamic>> _extractSignRecordRows(dynamic raw) {
  if (raw is List) {
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }
  final map = _unwrapMap(raw);
  if (map == null) return const [];
  for (final key in ['records', 'list', 'rows', 'data']) {
    final value = map[key];
    if (value is List) {
      return [
        for (final item in value)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
    }
  }
  return const [];
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

String _isoDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

// ── 课堂补签申请 ─────────────────────────────────────────────────────────

class StudentCourseSignMakeupItem {
  const StudentCourseSignMakeupItem({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.signTypeRaw,
    required this.reason,
    required this.status,
    required this.statusText,
    required this.createTime,
    this.auditTime = '',
    this.auditReason = '',
    this.className = '',
    this.courseDate = '',
    this.lineNum = 0,
    this.teacherHeadUrl = '',
  });

  final String id;
  final String courseId;
  final String courseName;

  /// 补签类型原始值：后端可能下发中文（`上课签`/`下课签`）、数字串（`1`/`2`）
  /// 或异常值（`????`）。统一经 [signTypeLabel] 归一化展示。
  final String signTypeRaw;
  final String reason;
  final int status;
  final String statusText;
  final String createTime;
  final String auditTime;
  final String auditReason;
  final String className;
  final String courseDate;
  final int lineNum;
  final String teacherHeadUrl;

  String get signTypeLabel => _courseSignMakeupSignTypeLabel(signTypeRaw);

  String get displayStatus =>
      statusText.isNotEmpty ? statusText : _courseSignMakeupStatusLabel(status);

  factory StudentCourseSignMakeupItem.fromJson(Map<String, dynamic> json) {
    final flat = _flattenSignRecordRow(json);
    return StudentCourseSignMakeupItem(
      id: readSnowflakeId(flat['id']) ?? '',
      courseId: readSnowflakeId(flat['courseId']) ?? '',
      courseName: _pickString(flat, [
        'subjectName',
        'courseName',
        'name',
      ], '未命名课程'),
      signTypeRaw: _pickString(flat, ['signType'], ''),
      reason: _pickString(flat, ['reason'], ''),
      status: _pickInt(flat, ['status', 'auditStatus']),
      statusText: _pickString(flat, ['statusText', 'auditStatusText']),
      createTime: _pickString(flat, ['createTime', 'applyTime']),
      auditTime: _pickString(flat, ['approveTime', 'auditTime', 'updateTime']),
      auditReason: _pickString(flat, [
        'approveRemark',
        'auditReason',
        'auditRemark',
        'remark',
      ]),
      className: _pickString(flat, ['className'], ''),
      courseDate: _pickString(flat, ['courseDate', 'date'], ''),
      lineNum: _pickInt(flat, ['lineNum']),
      teacherHeadUrl: _pickString(flat, ['teacherHeadUrl', 'headUrl'], ''),
    );
  }
}

List<StudentCourseSignMakeupItem> parseStudentCourseSignMakeupList(dynamic raw) {
  return _extractSignRecordRows(raw)
      .map(StudentCourseSignMakeupItem.fromJson)
      .where((item) => item.id.isNotEmpty)
      .toList(growable: false);
}

String _courseSignMakeupStatusLabel(int status) {
  return switch (status) {
    0 => '待审批',
    1 => '已通过',
    2 => '已驳回',
    _ => '未知',
  };
}

/// 将补签详情接口数据转为详情弹窗字段行。
List<({String label, String value})> parseStudentCourseSignMakeupDetailRows(
  dynamic raw,
) {
  final map = _unwrapMap(raw) ?? const <String, dynamic>{};
  final flat = _flattenSignRecordRow(map);
  final className = _pickString(flat, ['className'], '');
  final reason = _pickString(flat, ['reason'], '');
  return [
    (label: '课程名称', value: _pickString(flat, ['subjectName', 'courseName'], '—')),
    if (className.isNotEmpty) (label: '所属班级', value: className),
    (
      label: '补签类型',
      value: _courseSignMakeupSignTypeLabel(
        _pickString(flat, ['signType'], ''),
      ),
    ),
    (label: '上课日期', value: _pickString(flat, ['courseDate', 'date'], '—')),
    if (reason.isNotEmpty) (label: '申请原因', value: reason),
    (
      label: '审批状态',
      value: _pickString(
        flat,
        ['statusText'],
        _courseSignMakeupStatusLabel(_pickInt(flat, ['status'])),
      ),
    ),
    (
      label: '审批意见',
      value: _pickString(flat, ['approveRemark', 'auditReason', 'auditRemark'], '—'),
    ),
    (label: '申请时间', value: _pickString(flat, ['createTime', 'applyTime'], '—')),
    (
      label: '审批时间',
      value: _pickString(flat, ['approveTime', 'auditTime', 'updateTime'], '—'),
    ),
  ];
}

/// 归一化补签类型标签，兼容中文 / 数字串 / 异常值。
String _courseSignMakeupSignTypeLabel(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return '课堂补签';
  if (t.contains('上课')) return '上课签';
  if (t.contains('下课')) return '下课签';
  if (t == '1') return '上课签';
  if (t == '2') return '下课签';
  return '课堂补签';
}
