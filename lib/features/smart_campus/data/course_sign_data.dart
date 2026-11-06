/// 签课管理 API 数据模型与 JSON 解析（管理员端）。
///
/// 考勤状态与后端一致：`0` 出勤 / `1` 缺勤 / `2` 迟到 / `3` 请假。
library;

import '../../../core/network/media_url.dart';
import '../../../core/network/snowflake_id.dart';

/// 课程 `type` 约定：0 = 大课，1 = 小课（课表、签课、班级等接口统一）。
bool isSmallCourseType(int type) => type == 1;

bool isBigCourseType(int type) => type == 0;

/// 小课 / 签课流程 `signStatus`：0 未签到 … 7 管理员驳回。
enum CourseSignFlowStatus {
  notSigned(0, '未签到'),
  teacherStart(1, '老师上课签到'),
  studentStart(2, '学生上课签到'),
  teacherEnd(3, '老师下课签到'),
  studentEnd(4, '学生下课签到'),
  studentEval(5, '学生评价'),
  adminConfirm(6, '教务老师确认'),
  adminReject(7, '教务老师驳回');

  const CourseSignFlowStatus(this.code, this.label);

  final int code;
  final String label;

  static CourseSignFlowStatus? fromApi(dynamic raw) {
    if (raw == null) return null;
    final code = int.tryParse(raw.toString());
    if (code == null) return null;
    for (final status in CourseSignFlowStatus.values) {
      if (status.code == code) return status;
    }
    return null;
  }

  static String labelFor(dynamic raw, {String fallback = '未签到'}) {
    return fromApi(raw)?.label ?? fallback;
  }
}

/// 大课是否已完成一键全班签到。
bool isBigClassBulkSignCompleted({
  required int courseSignStatus,
  required List<CourseSignStudent> students,
}) {
  if (courseSignStatus >= CourseSignFlowStatus.studentStart.code) {
    return true;
  }
  if (students.isNotEmpty && students.every((student) => student.status != null)) {
    return true;
  }
  return false;
}

/// 从课表时间字段提取 `HH:mm`（支持 `yyyy-MM-dd HH:mm:ss` / ISO / 纯时分）。
String? pickCourseClock(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed == 'null') return null;
  final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(trimmed);
  if (match == null) return null;
  return '${match.group(1)!.padLeft(2, '0')}:${match.group(2)}';
}

/// 解析课表时间点；纯时分串会落到 [reference] 当天（默认今天）。
DateTime? parseCourseDateTime(String? raw, {DateTime? reference}) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed == 'null') return null;

  final direct = DateTime.tryParse(trimmed);
  if (direct != null) return direct;

  final normalized = trimmed.contains(' ') && !trimmed.contains('T')
      ? trimmed.replaceFirst(' ', 'T')
      : trimmed;
  final parsed = DateTime.tryParse(normalized);
  if (parsed != null) return parsed;

  final clock = pickCourseClock(trimmed);
  if (clock == null) return null;
  final parts = clock.split(':');
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  final base = reference ?? DateTime.now();
  return DateTime(base.year, base.month, base.day, hour, minute);
}

/// 后端 `status` 字段：0-出勤 1-缺勤 2-迟到 3-请假；null 表示尚未签到。
enum CourseSignStatus {
  present(0, '出勤'),
  absent(1, '缺勤'),
  late(2, '迟到'),
  leave(3, '请假');

  const CourseSignStatus(this.code, this.label);

  final int code;
  final String label;

  /// 弹窗内可选项（仅 0–3）。
  static const List<CourseSignStatus> selectable = [
    present,
    absent,
    late,
    leave,
  ];

  static CourseSignStatus? fromApi(dynamic raw) {
    if (raw == null) return null;
    final code = int.tryParse(raw.toString());
    if (code == null) return null;
    for (final s in selectable) {
      if (s.code == code) return s;
    }
    return null;
  }
}

/// 班级筛选项（`classList` / 签课查询共用）。
class CourseSignClassOption {
  const CourseSignClassOption({
    required this.id,
    required this.name,
    required this.type,
  });

  final String id;
  final String name;

  /// 0=大班 1=小班
  final int type;

  factory CourseSignClassOption.fromJson(Map<String, dynamic> json) {
    final id = _pickString(json, ['id', 'classId', 'cId'], '');
    final name = _pickString(json, [
      'name',
      'className',
      'class',
      'fullName',
    ], '未命名班级');
    final typeRaw = json['type'];
    final type = int.tryParse(typeRaw?.toString() ?? '') ?? 0;
    return CourseSignClassOption(id: id, name: name, type: type);
  }
}

/// `courseSignSum0` / `courseSignSum1` 统计卡片数据（字段名做多 key 兜底）。
class CourseSignStats {
  const CourseSignStats({
    this.courseCount = 0,
    this.signedCourseCount = 0,
    this.studentSignedCount = 0,
    this.studentShouldCount = 0,
    this.pendingMakeupCount = 0,
    this.inProgressCount = 0,
    this.pendingAdminCount = 0,
    this.completedCount = 0,
  });

  final int courseCount;
  final int signedCourseCount;
  final int studentSignedCount;
  final int studentShouldCount;
  final int pendingMakeupCount;
  final int inProgressCount;
  final int pendingAdminCount;
  final int completedCount;

  factory CourseSignStats.fromJson(dynamic raw) {
    final map = _asMap(raw);
    if (map == null) return const CourseSignStats();
    int pick(List<String> keys) {
      for (final k in keys) {
        if (!map.containsKey(k)) continue;
        final v = int.tryParse(map[k]?.toString() ?? '');
        if (v != null) return v;
      }
      return 0;
    }

    return CourseSignStats(
      courseCount: pick([
        'courseCount',
        'courseNum',
        'totalCourseCount',
        'totalCount',
        'bigCourseCount',
        'smallCourseCount',
      ]),
      signedCourseCount: pick([
        'signedCourseCount',
        'completeCourseCount',
        'signedCount',
        'finishCount',
      ]),
      studentSignedCount: pick([
        'studentSignCount',
        'signedStudentCount',
        'signCount',
        'studentSignedCount',
      ]),
      studentShouldCount: pick([
        'studentShouldSignCount',
        'shouldSignCount',
        'studentCount',
        'shouldCount',
      ]),
      pendingMakeupCount: pick([
        'makeupPendingCount',
        'pendingMakeupCount',
        'makeupCount',
        'applyCount',
      ]),
      inProgressCount: pick(['inProgressCount', 'doingCount', 'progressCount']),
      pendingAdminCount: pick([
        'pendingAdminCount',
        'waitAdminCount',
        'adminConfirmCount',
      ]),
      completedCount: pick(['completedCount', 'finishCount', 'doneCount']),
    );
  }
}

class CourseSignStudent {
  CourseSignStudent({
    required this.studentId,
    required this.name,
    required this.studentNo,
    this.headUrl = '',
    this.status,
    this.checkInTime,
    this.checkOutTime,
    this.evaluationRating,
    this.evaluationMastery,
    this.evaluationNote,
    this.remark = '',
  });

  final String studentId;
  final String name;
  final String studentNo;
  final String headUrl;
  CourseSignStatus? status;
  String? checkInTime;
  String? checkOutTime;
  double? evaluationRating;
  String? evaluationMastery;
  String? evaluationNote;
  final String remark;

  CourseSignStudent copyWith({
    CourseSignStatus? status,
    bool clearStatus = false,
    String? remark,
  }) {
    return CourseSignStudent(
      studentId: studentId,
      name: name,
      studentNo: studentNo,
      headUrl: headUrl,
      status: clearStatus ? null : status ?? this.status,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
      evaluationRating: evaluationRating,
      evaluationMastery: evaluationMastery,
      evaluationNote: evaluationNote,
      remark: remark ?? this.remark,
    );
  }

  factory CourseSignStudent.fromJson(Map<String, dynamic> json) {
    final studentId = _pickString(json, [
      'studentId',
      'stuId',
      'userId',
      'id',
    ], '');
    final name = _pickStudentDisplayName(json);
    final studentNo = _pickString(json, [
      'no',
      'studentNo',
      'stuNo',
      'studentIdNo',
    ], '--');
    final headUrl = MediaUrl.resolve(
      _pickString(json, ['headUrl', 'avatar', 'avatarUrl', 'headImg'], ''),
    );
    final ratingRaw = json['score'] ?? json['rating'] ?? json['star'];
    final rating = ratingRaw == null
        ? null
        : double.tryParse(ratingRaw.toString());
    return CourseSignStudent(
      studentId: studentId,
      name: name,
      studentNo: studentNo,
      headUrl: headUrl,
      status: CourseSignStatus.fromApi(
        json['status'] ?? json['signStatus'] ?? json['attendanceStatus'],
      ),
      checkInTime: _pickStringNullable(json, [
        'checkInTime',
        'signInTime',
        'beginSignTime',
        'classBeginTime',
      ]),
      checkOutTime: _pickStringNullable(json, [
        'checkOutTime',
        'signOutTime',
        'endSignTime',
        'classEndTime',
      ]),
      evaluationRating: rating,
      evaluationMastery: _pickStringNullable(json, [
        'mastery',
        'masterLevel',
        'level',
      ]),
      evaluationNote: _pickStringNullable(json, [
        'evaluation',
        'evaluate',
        'comment',
        'remark',
        'note',
      ]),
      remark: _pickString(json, ['remark', 'teacherRemark'], ''),
    );
  }
}

/// 单节课程签到（大课 / 小课列表项）。
class CourseSignSession {
  CourseSignSession({
    required this.courseId,
    required this.courseName,
    required this.timeRange,
    required this.classroom,
    required this.students,
    this.teacherName = '',
    this.logoUrl = '',
    this.teacherHeadUrl = '',
    this.teacherCheckInTime,
    this.teacherCheckOutTime,
    this.adminConfirmed = false,
    this.signStep,
    this.signStatus = 0,
    this.courseStartTime = '',
    this.courseEndTime = '',
    this.courseType = 0,
    this.lineNum = 0,
    this.colorHex = '',
    this.className = '',
  });

  final String courseId;
  final String courseName;
  final String timeRange;
  final String classroom;
  final List<CourseSignStudent> students;
  final String teacherName;
  final String logoUrl;
  final String teacherHeadUrl;
  final String colorHex;
  final String className;
  final String? teacherCheckInTime;
  final String? teacherCheckOutTime;
  final bool adminConfirmed;

  /// 小课流程步骤（0–5），后端若下发 `signStep` / `step` 则直接使用。
  final int? signStep;

  /// 签课流程状态：0 未签到 … 7 管理员驳回。
  final int signStatus;
  final String courseStartTime;
  final String courseEndTime;
  final int courseType;
  final int lineNum;

  factory CourseSignSession.fromJson(Map<String, dynamic> json) {
    final courseId =
        pickFirstSnowflakeId(json, ['courseId', 'id', 'cId']) ?? '';
    final subjectMap = _asMap(json['subject']);
    final subjectName = subjectMap == null
        ? ''
        : _pickString(subjectMap, ['name', 'subjectName'], '');
    final courseName = _pickString(json, [
      'courseName',
      'subjectName',
      'name',
      'title',
    ], subjectName.isEmpty ? '未命名课程' : subjectName);
    final begin = _pickString(json, [
      'timeBegin',
      'beginTime',
      'startTime',
      'classBeginTime',
    ], '');
    final end = _pickString(json, [
      'timeEnd',
      'endTime',
      'finishTime',
      'classEndTime',
    ], '');
    final date = _pickString(json, ['date', 'courseDate'], '');
    final classroom = _pickString(json, [
      'classroomName',
      'classroom',
      'roomName',
      'address',
    ], '--');
    final teacherMap = _asMap(
      json['teacher'] ?? json['headTeacher'] ?? json['teacherSign'],
    );
    var teacherName = _pickString(json, [
      'teacherRealname',
      'teacherRealname',
      'teacherNickname',
      'teacherName',
    ], '');
    if (teacherName.isEmpty && teacherMap != null) {
      teacherName = _pickString(teacherMap, [
        'realname',
        'realName',
        'nickname',
        'name',
      ], '');
    }

    final studentsRaw =
        json['studentList'] ??
        json['students'] ??
        json['signStudentList'] ??
        json['studentSignList'] ??
        json['list'];
    final students = _parseStudentList(studentsRaw);

    final signStatusRaw =
        json['signStatus'] ?? json['signStep'] ?? json['step'] ?? json['flowStep'];
    final signStatus = int.tryParse(signStatusRaw?.toString() ?? '') ?? 0;
    final step = int.tryParse(signStatusRaw?.toString() ?? '');

    final courseStartTime = _pickString(json, [
      'courseStartTime',
      'startTime',
      'classBeginTime',
      'timeBegin',
      'beginTime',
    ], begin);
    final courseEndTime = _pickString(json, [
      'courseEndTime',
      'endTime',
      'classEndTime',
      'timeEnd',
      'finishTime',
    ], end);

    var timeRange = _pickString(json, ['timeRange', 'time', 'period'], '');
    if (timeRange.isEmpty && begin.isNotEmpty) {
      timeRange = end.isNotEmpty ? '$begin - $end' : begin;
    }
    if (timeRange.isEmpty) {
      final startClock = pickCourseClock(courseStartTime);
      final endClock = pickCourseClock(courseEndTime);
      if (startClock != null && endClock != null) {
        timeRange = '$startClock - $endClock';
      } else if (startClock != null) {
        timeRange = startClock;
      } else if (date.isNotEmpty) {
        timeRange = date;
      }
    }

    final adminConfirmedRaw =
        json['adminConfirm'] ?? json['adminConfirmed'] ?? json['confirmStatus'];
    final adminConfirmed =
        adminConfirmedRaw == true ||
        adminConfirmedRaw == 1 ||
        adminConfirmedRaw?.toString() == '1' ||
        signStatus == CourseSignFlowStatus.adminConfirm.code;

    return CourseSignSession(
      courseId: courseId,
      courseName: courseName,
      timeRange: timeRange,
      classroom: classroom,
      students: students,
      teacherName: teacherName,
      logoUrl: resolveCourseLogoUrl(json),
      teacherHeadUrl: resolveCourseTeacherHeadUrl(json, teacherMap: teacherMap),
      colorHex: _pickString(json, ['color'], ''),
      className: _pickString(json, ['className', 'class'], ''),
      teacherCheckInTime: _pickStringNullable(json, [
        'teacherCheckInTime',
        'teacherSignInTime',
      ]),
      teacherCheckOutTime: _pickStringNullable(json, [
        'teacherCheckOutTime',
        'teacherSignOutTime',
      ]),
      adminConfirmed: adminConfirmed,
      signStep: step,
      signStatus: signStatus,
      courseStartTime: courseStartTime,
      courseEndTime: courseEndTime,
      courseType:
          int.tryParse((json['type'] ?? json['classType'] ?? 0).toString()) ??
          0,
      lineNum:
          int.tryParse(
            (json['lineNum'] ?? json['periodIndex'] ?? json['sectionNum'] ?? 0)
                .toString(),
          ) ??
          0,
    );
  }

  CourseSignSession copyWith({
    List<CourseSignStudent>? students,
    int? signStep,
    int? signStatus,
    bool? adminConfirmed,
    String? courseStartTime,
    String? courseEndTime,
    String? timeRange,
    String? logoUrl,
    String? teacherHeadUrl,
    String? colorHex,
    String? className,
    String? teacherCheckInTime,
    String? teacherCheckOutTime,
  }) {
    return CourseSignSession(
      courseId: courseId,
      courseName: courseName,
      timeRange: timeRange ?? this.timeRange,
      classroom: classroom,
      students: students ?? this.students,
      teacherName: teacherName,
      logoUrl: logoUrl ?? this.logoUrl,
      teacherHeadUrl: teacherHeadUrl ?? this.teacherHeadUrl,
      colorHex: colorHex ?? this.colorHex,
      className: className ?? this.className,
      teacherCheckInTime: teacherCheckInTime ?? this.teacherCheckInTime,
      teacherCheckOutTime: teacherCheckOutTime ?? this.teacherCheckOutTime,
      adminConfirmed: adminConfirmed ?? this.adminConfirmed,
      signStep: signStep ?? this.signStep,
      signStatus: signStatus ?? this.signStatus,
      courseStartTime: courseStartTime ?? this.courseStartTime,
      courseEndTime: courseEndTime ?? this.courseEndTime,
      courseType: courseType,
      lineNum: lineNum,
    );
  }
}

List<CourseSignStudent> parseCourseCommentList(dynamic raw) {
  if (raw == null) return const [];
  final rows = _unwrapRows(raw);
  return rows
      .map((row) {
        final user = _asMap(
          row['student'] ?? row['user'] ?? row['schoolStudent'],
        );
        final merged = <String, dynamic>{
          ...?user,
          ...row,
          'evaluation': row['comment'] ?? row['evaluation'] ?? row['remark'],
          'score': row['score'] ?? row['rating'] ?? row['star'],
        };
        return CourseSignStudent.fromJson(merged);
      })
      .toList(growable: false);
}

List<CourseSignSession> parseCourseSignSessionList(dynamic raw) {
  if (raw == null) return const [];
  if (raw is List) {
    return _parseCourseSessionRows(raw);
  }
  final map = _asMap(raw);
  if (map == null) return const [];

  for (final key in ['records', 'list', 'rows', 'data']) {
    if (!map.containsKey(key)) continue;
    final inner = map[key];
    if (inner is List) {
      return _parseCourseSessionRows(inner);
    }
    final nested = parseCourseSignSessionList(inner);
    if (nested.isNotEmpty) return nested;
  }

  // teacher/student `courseList` 新格式：按日期分组
  // `{"2026-05-11": [{...}, ...], "2026-05-12": [...]}`。
  final fromDates = _parseDateGroupedCourseMap(map);
  if (fromDates.isNotEmpty) return fromDates;

  return const [];
}

/// 节次时间配置（`schoolTimeConfigList`），用于补全课表结束时间。
class CourseLineTimeConfig {
  const CourseLineTimeConfig({
    required this.lineNum,
    required this.start,
    required this.end,
  });

  final int lineNum;
  final String start;
  final String end;
}

const List<CourseLineTimeConfig> kDefaultCourseLineTimeConfigs = [
  CourseLineTimeConfig(lineNum: 1, start: '08:00', end: '08:40'),
  CourseLineTimeConfig(lineNum: 2, start: '08:50', end: '09:35'),
  CourseLineTimeConfig(lineNum: 3, start: '09:50', end: '10:30'),
  CourseLineTimeConfig(lineNum: 4, start: '10:30', end: '11:25'),
  CourseLineTimeConfig(lineNum: 5, start: '14:00', end: '14:45'),
];

List<CourseLineTimeConfig> parseCourseLineTimeConfigs(dynamic raw) {
  final rows = _unwrapRows(raw);
  final configs = <CourseLineTimeConfig>[];
  for (final row in rows) {
    final lineNumRaw = row['lineNum'];
    final lineNum = lineNumRaw is int
        ? lineNumRaw
        : (int.tryParse(lineNumRaw?.toString() ?? '') ?? 0);
    if (lineNum < 1) continue;
    final start = pickCourseClock(
          _pickString(row, ['timeBegin', 'startTime', 'beginTime', 'start'], ''),
        ) ??
        '';
    final end = pickCourseClock(
          _pickString(row, ['timeEnd', 'endTime', 'finishTime', 'end'], ''),
        ) ??
        '';
    if (start.isEmpty || end.isEmpty) continue;
    configs.add(CourseLineTimeConfig(lineNum: lineNum, start: start, end: end));
  }
  configs.sort((a, b) => a.lineNum.compareTo(b.lineNum));
  return configs;
}

({String start, String end}) resolveCourseSessionClocks(
  CourseSignSession session,
  List<CourseLineTimeConfig> configs,
) {
  final effectiveConfigs = configs.isNotEmpty
      ? configs
      : kDefaultCourseLineTimeConfigs;
  var start = pickCourseClock(session.courseStartTime) ?? '';
  var end = pickCourseClock(session.courseEndTime) ?? '';

  if (end.isEmpty && session.lineNum > 0) {
    CourseLineTimeConfig? matched;
    for (final config in effectiveConfigs) {
      if (config.lineNum == session.lineNum) {
        matched = config;
        break;
      }
    }
    matched ??= session.lineNum <= effectiveConfigs.length
        ? effectiveConfigs[session.lineNum - 1]
        : null;
    if (matched != null) {
      end = matched.end;
      if (start.isEmpty) start = matched.start;
    }
  }

  if (start.isEmpty && session.lineNum > 0) {
    for (final config in effectiveConfigs) {
      if (config.lineNum == session.lineNum) {
        start = config.start;
        break;
      }
    }
  }

  return (start: start, end: end);
}

List<CourseSignSession> enrichCourseSignSessions(
  List<CourseSignSession> sessions, {
  List<CourseLineTimeConfig> timeConfigs = const [],
}) {
  return [
    for (final session in sessions)
      _enrichCourseSignSession(session, timeConfigs: timeConfigs),
  ];
}

CourseSignSession _enrichCourseSignSession(
  CourseSignSession session, {
  required List<CourseLineTimeConfig> timeConfigs,
}) {
  final clocks = resolveCourseSessionClocks(session, timeConfigs);
  if (clocks.start.isEmpty && clocks.end.isEmpty) return session;

  final startRaw = session.courseStartTime.isNotEmpty
      ? session.courseStartTime
      : clocks.start;
  final endRaw = session.courseEndTime.isNotEmpty
      ? session.courseEndTime
      : clocks.end;
  final timeRange = clocks.start.isNotEmpty && clocks.end.isNotEmpty
      ? '${clocks.start} - ${clocks.end}'
      : (clocks.start.isNotEmpty ? clocks.start : session.timeRange);

  return session.copyWith(
    courseStartTime: startRaw,
    courseEndTime: endRaw,
    timeRange: timeRange,
  );
}

int _courseSessionSortKey(CourseSignSession session) {
  final startDt = parseCourseDateTime(session.courseStartTime);
  if (startDt != null) return startDt.millisecondsSinceEpoch;
  if (session.lineNum > 0) return session.lineNum * 60000;
  return 0;
}

List<CourseSignSession> sortCourseSignSessions(List<CourseSignSession> sessions) {
  final sorted = [...sessions]
    ..sort((a, b) {
      final byStart = _courseSessionSortKey(a).compareTo(_courseSessionSortKey(b));
      if (byStart != 0) return byStart;
      return a.lineNum.compareTo(b.lineNum);
    });
  return sorted;
}

String? pickDefaultCourseSignSessionId(
  List<CourseSignSession> sessions, {
  DateTime? now,
  List<CourseLineTimeConfig> timeConfigs = const [],
}) {
  if (sessions.isEmpty) return null;
  final current = now ?? DateTime.now();
  CourseSignSession? inProgress;
  CourseSignSession? upcoming;
  CourseSignSession? lastEnded;

  for (final session in sessions) {
    final clocks = resolveCourseSessionClocks(session, timeConfigs);
    final phase = resolveCourseSlotPhase(current, clocks.start, clocks.end);
    switch (phase) {
      case CourseSlotPhase.inProgress:
        inProgress ??= session;
      case CourseSlotPhase.upcoming:
        upcoming ??= session;
      case CourseSlotPhase.ended:
        lastEnded = session;
    }
  }

  final picked = inProgress ?? upcoming ?? lastEnded ?? sessions.first;
  return picked.courseId.isNotEmpty ? picked.courseId : null;
}

List<CourseSignSession> _parseCourseSessionRows(List<dynamic> raw) {
  return raw
      .map(
        (e) =>
            CourseSignSession.fromJson(_flattenCourseSessionRow(_asMap(e) ?? {})),
      )
      .where((s) => s.courseId.isNotEmpty || s.courseName.isNotEmpty)
      .toList(growable: false);
}

List<CourseSignSession> _parseDateGroupedCourseMap(Map<String, dynamic> map) {
  final sessions = <CourseSignSession>[];
  for (final entry in map.entries) {
    if (_isCourseListWrapperKey(entry.key)) continue;
    final value = entry.value;
    if (value is! List) continue;
    final dateKey = _parseDateKey(entry.key);
    for (final item in value) {
      final row = _asMap(item);
      if (row == null) continue;
      final flat = _flattenCourseSessionRow(row);
      if (dateKey != null &&
          (flat['date'] == null || flat['date'].toString().trim().isEmpty)) {
        flat['date'] = dateKey;
      }
      final session = CourseSignSession.fromJson(flat);
      if (session.courseId.isNotEmpty || session.courseName.isNotEmpty) {
        sessions.add(session);
      }
    }
  }
  return sessions;
}

bool _isCourseListWrapperKey(String key) {
  return const {
    'records',
    'list',
    'rows',
    'data',
    'total',
    'current',
    'size',
    'pages',
    'page',
    'pageSize',
  }.contains(key);
}

String? _parseDateKey(String key) {
  final trimmed = key.trim().split('T').first;
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) return null;
  return DateTime.tryParse(trimmed) != null ? trimmed : null;
}

Map<String, dynamic> _flattenCourseSessionRow(Map<String, dynamic> row) {
  final flat = Map<String, dynamic>.from(row);

  void mergeNested(String key, List<MapEntry<String, String>> fieldMap) {
    final nested = row[key];
    if (nested is! Map) return;
    final m = Map<String, dynamic>.from(nested);
    for (final entry in fieldMap) {
      final v = m[entry.key];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isEmpty || s == 'null') continue;
      flat.putIfAbsent(entry.value, () => v);
    }
  }

  mergeNested('teacher', [
    const MapEntry('realname', 'teacherRealname'),
    const MapEntry('realName', 'teacherRealname'),
    const MapEntry('nickname', 'teacherNickname'),
    const MapEntry('name', 'teacherName'),
  ]);
  mergeNested('headTeacher', [
    const MapEntry('realname', 'teacherRealname'),
    const MapEntry('realName', 'teacherRealname'),
    const MapEntry('nickname', 'teacherNickname'),
    const MapEntry('name', 'teacherName'),
  ]);
  mergeNested('teacherSign', [
    const MapEntry('signInTime', 'teacherSignInTime'),
    const MapEntry('signOutTime', 'teacherSignOutTime'),
    const MapEntry('nickname', 'teacherNickname'),
    const MapEntry('realname', 'teacherRealname'),
    const MapEntry('realName', 'teacherRealname'),
    const MapEntry('headUrl', 'teacherHeadUrl'),
  ]);
  mergeNested('subject', [
    const MapEntry('name', 'subjectName'),
    const MapEntry('subjectName', 'subjectName'),
  ]);
  mergeNested('schoolClass', [
    const MapEntry('name', 'className'),
    const MapEntry('className', 'className'),
    const MapEntry('id', 'classId'),
    const MapEntry('logo', 'logo'),
  ]);
  mergeNested('schoolClassroom', [
    const MapEntry('name', 'classroomName'),
    const MapEntry('roomName', 'classroomName'),
    const MapEntry('classroomName', 'classroomName'),
  ]);
  mergeNested('classroom', [
    const MapEntry('name', 'classroomName'),
    const MapEntry('roomName', 'classroomName'),
    const MapEntry('classroomName', 'classroomName'),
  ]);

  return flat;
}

List<CourseSignStudent> _parseStudentList(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .map((e) => CourseSignStudent.fromJson(_asMap(e) ?? {}))
      .toList(growable: false);
}

List<Map<String, dynamic>> _unwrapRows(dynamic raw) {
  if (raw is List) {
    return raw.map(_asMap).whereType<Map<String, dynamic>>().toList();
  }
  final map = _asMap(raw);
  if (map == null) return const [];
  for (final key in ['records', 'list', 'rows', 'data']) {
    final value = map[key];
    if (value is List) return _unwrapRows(value);
    if (value is Map) {
      final nested = _unwrapRows(value);
      if (nested.isNotEmpty) return nested;
    }
  }
  return const [];
}

List<CourseSignStudent> parseCourseSignStudentList(dynamic raw) {
  return _parseStudentList(raw);
}

List<CourseSignClassOption> parseCourseSignClassList(dynamic raw) {
  if (raw == null) return const [];
  List<dynamic> rows;
  if (raw is List) {
    rows = raw;
  } else {
    final map = _asMap(raw);
    if (map == null) return const [];
    final inner = map['records'] ?? map['list'] ?? map['rows'] ?? map['data'];
    if (inner is! List) return const [];
    rows = inner;
  }
  return rows
      .map((e) => CourseSignClassOption.fromJson(_asMap(e) ?? {}))
      .where((c) => c.id.isNotEmpty)
      .toList(growable: false);
}

String todayIsoDate() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

/// 课程时段阶段（按当日 `HH:mm` 起止判断）。
enum CourseSlotPhase { upcoming, inProgress, ended }

/// 签到操作区右上角倒计时快照。
class CourseSlotCountdownSnapshot {
  const CourseSlotCountdownSnapshot({
    required this.phase,
    required this.label,
    required this.timeText,
  });

  final CourseSlotPhase phase;
  final String label;
  final String timeText;
}

DateTime? dateTimeAtCourseClock(DateTime day, String hm) {
  final clock = pickCourseClock(hm) ?? hm.trim();
  if (clock.isEmpty) return null;
  final parts = clock.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return DateTime(day.year, day.month, day.day, hour, minute);
}

CourseSlotPhase resolveCourseSlotPhase(
  DateTime now,
  String startHm,
  String endHm,
) {
  final start = dateTimeAtCourseClock(now, startHm);
  final end = dateTimeAtCourseClock(now, endHm);
  if (start == null || end == null) return CourseSlotPhase.upcoming;
  if (now.isBefore(start)) return CourseSlotPhase.upcoming;
  if (now.isAfter(end)) return CourseSlotPhase.ended;
  return CourseSlotPhase.inProgress;
}

CourseSlotCountdownSnapshot buildCourseSlotCountdown({
  required DateTime now,
  required String startHm,
  required String endHm,
}) {
  final phase = resolveCourseSlotPhase(now, startHm, endHm);
  if (phase == CourseSlotPhase.ended) {
    return const CourseSlotCountdownSnapshot(
      phase: CourseSlotPhase.ended,
      label: '',
      timeText: '已结束',
    );
  }

  final start = dateTimeAtCourseClock(now, startHm);
  final end = dateTimeAtCourseClock(now, endHm);
  final target = phase == CourseSlotPhase.upcoming ? start : end;
  if (target == null) {
    return const CourseSlotCountdownSnapshot(
      phase: CourseSlotPhase.upcoming,
      label: '距上课',
      timeText: '--:--:--',
    );
  }

  final remaining = target.difference(now);
  final safe = remaining.isNegative ? Duration.zero : remaining;
  return CourseSlotCountdownSnapshot(
    phase: phase,
    label: phase == CourseSlotPhase.upcoming ? '距上课' : '距下课',
    timeText: formatCourseCountdownDuration(safe),
  );
}

String formatCourseCountdownDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  return null;
}

String _pickString(
  Map<String, dynamic> json,
  List<String> keys,
  String fallback,
) {
  for (final k in keys) {
    final v = json[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty && s != 'null') return s;
  }
  return fallback;
}

String? _pickStringNullable(Map<String, dynamic> json, List<String> keys) {
  for (final k in keys) {
    final v = json[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty && s != 'null') return s;
  }
  return null;
}

String _pickPersonDisplayName(
  Map<String, dynamic> json, {
  List<String> realnameKeys = const ['realname', 'realName'],
  List<String> nicknameKeys = const ['nickname', 'name'],
  String fallback = '未命名',
}) {
  final realname = _pickStringNullable(json, realnameKeys);
  if (realname != null) return realname;
  return _pickString(json, nicknameKeys, fallback);
}

String _pickStudentDisplayName(Map<String, dynamic> json) {
  return _pickPersonDisplayName(
    json,
    nicknameKeys: const ['nickname', 'name', 'stuName', 'studentName'],
  );
}

/// 课程/班级 `logo`：顶层或嵌套 `schoolClass` / `classInfo`。
String resolveCourseLogoUrl(Map<String, dynamic> json) {
  var raw = _pickString(json, ['logo', 'logoUrl', 'classLogo'], '');
  if (raw.isEmpty) {
    for (final key in ['schoolClass', 'classInfo', 'class']) {
      final nested = _asMap(json[key]);
      if (nested == null) continue;
      raw = _pickString(nested, ['logo', 'logoUrl', 'classLogo'], '');
      if (raw.isNotEmpty) break;
    }
  }
  return raw.isEmpty ? '' : MediaUrl.resolve(raw);
}

/// 任课老师头像：`teacher/courseList` 顶层 `teacherHeadUrl` 或嵌套 `teacher`。
String resolveCourseTeacherHeadUrl(
  Map<String, dynamic> json, {
  Map<String, dynamic>? teacherMap,
}) {
  var raw = _pickString(json, [
    'teacherHeadUrl',
    'teacherHead',
    'headUrl',
    'avatar',
    'avatarUrl',
    'headImg',
  ], '');
  if (raw.isEmpty) {
    final nested = teacherMap ?? _asMap(json['teacher'] ?? json['headTeacher']);
    if (nested != null) {
      raw = _pickString(nested, [
        'headUrl',
        'avatar',
        'avatarUrl',
        'headImg',
        'teacherHeadUrl',
      ], '');
    }
  }
  return raw.isEmpty ? '' : MediaUrl.resolve(raw);
}
