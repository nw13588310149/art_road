/// 智慧校园演示课表：由各班的周课表模板和管理员排课按日期即时生成；
/// 签课状态与学生课堂补签按课次持久化。课程只有一种，都是整班上课。
library;

import '../../data/demo_campus_data.dart';
import '../../demo_store.dart';
import 'campus_b_common.dart';

class CbCourse {
  const CbCourse({
    required this.id,
    required this.day,
    required this.classId,
    required this.subjectName,
    required this.teacherUserId,
    required this.start,
    required this.end,
    required this.lineNum,
    required this.classroomId,
    required this.color,
    this.subjectIdValue,
  });

  final String id;
  final DateTime day;
  final String classId;
  final String subjectName;
  final String teacherUserId;
  final String start;
  final String end;
  final int lineNum;
  final int classroomId;
  final String color;
  final int? subjectIdValue;

  int get subjectId => subjectIdValue ?? cbSubjectIdOf(subjectName);

  String get date => cbDate(day);

  DateTime get startAt => cbAt(day, start);

  DateTime get endAt => cbAt(day, end);
}

// ── 课表来源 ──────────────────────────────────────────────────────────

/// [day] 所在周（周一开始）往后 [weeks] 周的星期 [weekday]。
DateTime cbWeekday(DateTime day, int weekday, {int weeks = 0}) {
  final monday = cbAddDays(cbDay(day), 1 - day.weekday);
  return cbAddDays(monday, weeks * 7 + weekday - 1);
}

/// 模板生成的课次 id：`7` + 日期 + 班级 + 节次（与学生端课表的课次 id 一致）。
String _generatedId(DateTime day, String classId, int lineNum) =>
    '7${day.year}${cbTwo(day.month)}${cbTwo(day.day)}$classId$lineNum';

/// 模板生成的课次 id 里的日期：`7yyyyMMdd…`（13 位）。
DateTime? _dayOfGeneratedId(String id) {
  final generated = id.length == 13 && id.startsWith('7');
  if (!generated) {
    return null;
  }
  final year = int.tryParse(id.substring(1, 5));
  final month = int.tryParse(id.substring(5, 7));
  final day = int.tryParse(id.substring(7, 9));
  if (year == null || month == null || day == null) {
    return null;
  }
  return DateTime(year, month, day);
}

const String cbExtraCoursesKey = 'campus_b:course_extra';
const String cbDeletedCoursesKey = 'campus_b:course_deleted';

/// 管理员在排课页写入的课。
List<Map<String, dynamic>> cbExtraCourses() =>
    DemoStore.list(cbExtraCoursesKey, () => <Map<String, dynamic>>[]);

List<Map<String, dynamic>> _deletedRows() =>
    DemoStore.list(cbDeletedCoursesKey, () => <Map<String, dynamic>>[]);

/// 删除课次：管理员新增的课直接移除，模板生成的课记入删除名单。
void cbDeleteCourses(Iterable<String> ids) {
  final extras = cbExtraCourses();
  final deleted = _deletedRows();
  final known = {for (final m in deleted) cbStr(m['id'])};
  for (final id in ids) {
    final before = extras.length;
    extras.removeWhere((m) => cbStr(m['id']) == id);
    if (extras.length == before && known.add(id)) {
      deleted.add(<String, dynamic>{'id': id});
    }
  }
  DemoStore.save(cbExtraCoursesKey);
  DemoStore.save(cbDeletedCoursesKey);
}

CbCourse _extraCourse(Map<String, dynamic> m) {
  final lineNum = cbInt(m['lineNum'], 1);
  final (start, end) = cbLineTime(lineNum);
  return CbCourse(
    id: cbStr(m['id']),
    day: cbParseDay(m['date']) ?? cbToday(),
    classId: cbStr(m['classId']),
    subjectName: cbStr(m['subjectName'], '素描'),
    subjectIdValue: cbInt(m['subjectId'], 38),
    teacherUserId: cbStr(m['teacherId']),
    start: start,
    end: end,
    lineNum: lineNum,
    classroomId: cbInt(m['classroomId'], 11),
    color: cbStr(m['color'], cbCourseColor(cbStr(m['subjectName'], '素描'))),
  );
}

// ── 按日期取课 ────────────────────────────────────────────────────────

List<CbCourse> cbCoursesOn(DateTime date) {
  final day = cbDay(date);
  final deleted = {for (final m in _deletedRows()) cbStr(m['id'])};
  final result = <CbCourse>[];
  for (final c in DemoCampusData.classes) {
    if (cbClass(c.id) == null) {
      continue;
    }
    for (final slot in DemoCampusData.timetableOf(c.id)) {
      if (slot.weekday != day.weekday) {
        continue;
      }
      final lineNum = cbLineNumOf(slot.start);
      final id = _generatedId(day, c.id, lineNum);
      if (deleted.contains(id)) {
        continue;
      }
      result.add(
        CbCourse(
          id: id,
          day: day,
          classId: c.id,
          subjectName: slot.courseName,
          teacherUserId: DemoCampusData.staffById(slot.teacherId)?.userId ?? '',
          start: slot.start,
          end: slot.end,
          lineNum: lineNum,
          classroomId: cbClassroomId(c.organizationName, slot.room),
          color: cbCourseColor(slot.courseName),
        ),
      );
    }
  }
  final date0 = cbDate(day);
  for (final m in cbExtraCourses()) {
    if (cbStr(m['date']) == date0) {
      result.add(_extraCourse(m));
    }
  }
  result.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    return byStart != 0 ? byStart : a.classId.compareTo(b.classId);
  });
  return result;
}

List<CbCourse> cbCoursesBetween(DateTime from, DateTime to) {
  final result = <CbCourse>[];
  var day = cbDay(from);
  final last = cbDay(to);
  var guard = 0;
  while (!day.isAfter(last) && guard < 400) {
    result.addAll(cbCoursesOn(day));
    day = cbAddDays(day, 1);
    guard++;
  }
  return result;
}

CbCourse? cbCourseById(Object? rawId) {
  final id = cbStr(rawId);
  if (id.isEmpty) {
    return null;
  }
  final day = _dayOfGeneratedId(id);
  if (day != null) {
    for (final c in cbCoursesOn(day)) {
      if (c.id == id) {
        return c;
      }
    }
  }
  for (final m in cbExtraCourses()) {
    if (cbStr(m['id']) == id) {
      return _extraCourse(m);
    }
  }
  return null;
}

/// 课次学生名单：班级的在籍学生。
List<String> cbCourseStudents(CbCourse c) => cbActiveStudents(c.classId);

// ── 签到状态 ──────────────────────────────────────────────────────────

const String cbSignsKey = 'campus_b:course_signs';

Map<String, dynamic> _signStore() =>
    DemoStore.map(cbSignsKey, () => <String, dynamic>{});

/// 已结束课次的默认签课：老师已一键签课；有补签申请的学生按申请结果记为
/// 出勤或缺勤。`signStatus`：0 还没签课，2 已签课。
Map<String, dynamic> _defaultSign(CbCourse c) {
  final now = DateTime.now();
  if (!now.isAfter(c.endAt)) {
    return <String, dynamic>{'signStatus': 0, 'students': <String, dynamic>{}};
  }
  final students = <String, dynamic>{};
  final teacherSeed = cbHash(c.teacherUserId);
  final late = cbHash(c.id) % 10 < teacherSeed % 5;
  final teacherIn = c.startAt.add(
    Duration(minutes: late ? 12 + teacherSeed % 7 : -4),
  );
  final makeups = {
    for (final m in cbSignMakeups())
      if (cbStr(m['courseId']) == c.id) cbStr(m['studentId']): m,
  };
  final forced = cbForcedAbsences();
  for (final sid in cbCourseStudents(c)) {
    final makeup = makeups[sid];
    final isForced =
        sid == _demoStudentId &&
        (c.id == forced.open ||
            c.id == forced.approved ||
            c.id == forced.rejected);
    if (makeup != null || isForced) {
      final approved = makeup != null && cbInt(makeup['status']) == 1;
      students[sid] = approved
          ? <String, dynamic>{
              'status': 0,
              'checkInTime': cbDateTime(c.startAt),
              'remark': '补签通过',
            }
          : <String, dynamic>{
              'status': cbInt(makeup?['finalStatus'], 1),
              'remark': makeup == null ? '未签到' : '已提交补签申请',
            };
      continue;
    }
    final roll = cbHash('${c.id}|$sid') % 100;
    final status = roll < 86
        ? 0
        : roll < 93
        ? 2
        : roll < 97
        ? 3
        : 1;
    final present = status == 0 || status == 2;
    final checkIn = status == 2
        ? c.startAt.add(Duration(minutes: 6 + roll % 12))
        : c.startAt.subtract(Duration(minutes: 1 + roll % 6));
    students[sid] = <String, dynamic>{
      'status': status,
      if (present) 'checkInTime': cbDateTime(checkIn),
      if (status == 3) 'remark': '已提交请假条',
    };
  }
  return <String, dynamic>{
    'signStatus': 2,
    'teacherSignInTime': cbDateTime(teacherIn),
    'students': students,
  };
}

Map<String, dynamic> _studentStates(Map<String, dynamic> sign) {
  final raw = sign['students'];
  if (raw is Map) {
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }
  return <String, dynamic>{};
}

/// 课次当前的签课状态。
Map<String, dynamic> cbSignOf(CbCourse c) {
  final stored = _signStore()[c.id];
  return stored is Map ? cbCopy(stored) : _defaultSign(c);
}

void cbSaveSign(CbCourse c, Map<String, dynamic> sign) {
  _signStore()[c.id] = sign;
  DemoStore.save(cbSignsKey);
}

int cbSignStatus(CbCourse c) => cbInt(cbSignOf(c)['signStatus']);

/// 修改一名学生的考勤（0 出勤 / 1 缺勤 / 2 迟到 / 3 请假）。
void cbSetStudentSign(
  CbCourse c,
  String studentId,
  int status, {
  String remark = '',
}) {
  final sign = cbSignOf(c);
  final states = _studentStates(sign);
  final state = Map<String, dynamic>.from(states[studentId] as Map? ?? {});
  state['status'] = status;
  if (remark.isNotEmpty) {
    state['remark'] = remark;
  }
  if ((status == 0 || status == 2) && state['checkInTime'] == null) {
    state['checkInTime'] = cbDateTime(DateTime.now());
  }
  states[studentId] = state;
  sign['students'] = states;
  cbSaveSign(c, sign);
}

({int present, int late, int absent, int leave, int unsigned}) cbSignCounts(
  CbCourse c, [
  Map<String, dynamic>? sign,
]) {
  final states = _studentStates(sign ?? cbSignOf(c));
  var present = 0;
  var late = 0;
  var absent = 0;
  var leave = 0;
  var unsigned = 0;
  for (final sid in cbCourseStudents(c)) {
    final state = states[sid];
    final status = state is Map ? state['status'] : null;
    switch (status) {
      case 0:
        present++;
      case 2:
        late++;
      case 1:
        absent++;
      case 3:
        leave++;
      default:
        unsigned++;
    }
  }
  return (
    present: present,
    late: late,
    absent: absent,
    leave: leave,
    unsigned: unsigned,
  );
}

// ── JSON ──────────────────────────────────────────────────────────────

Map<String, dynamic> cbCourseRow(CbCourse c, {Map<String, dynamic>? sign}) {
  final teacher = cbStaff(c.teacherUserId);
  final state = sign ?? cbSignOf(c);
  final students = cbCourseStudents(c);
  final counts = cbSignCounts(c, state);
  final teacherName = teacher?.name ?? '';
  return <String, dynamic>{
    'id': c.id,
    'courseId': c.id,
    'date': c.date,
    'courseDate': c.date,
    'weekday': c.day.weekday,
    'lineNum': c.lineNum,
    'timeBegin': '${c.start}:00',
    'timeEnd': '${c.end}:00',
    'courseStartTime': '${c.date} ${c.start}:00',
    'courseEndTime': '${c.date} ${c.end}:00',
    'classId': c.classId,
    'className': cbClassName(c.classId),
    'logo': cbClassLogo(c.classId),
    'subjectId': c.subjectId,
    'subjectName': c.subjectName,
    'courseName': c.subjectName,
    'teacherId': c.teacherUserId,
    'teacherRealname': teacherName,
    'teacherNickname': teacherName,
    'teacherName': teacherName,
    'classroomId': c.classroomId,
    'classroomName': cbClassroomName(c.classroomId),
    'color': c.color,
    'signStatus': cbInt(state['signStatus']),
    'studentCount': students.length,
    'attendCount': counts.present + counts.late,
  };
}

/// 课表接口的按日期分组结构：`{"2026-11-02": [...], ...}`。
Map<String, dynamic> cbCourseRowsByDate(Iterable<CbCourse> courses) {
  final result = <String, dynamic>{};
  for (final c in courses) {
    (result.putIfAbsent(c.date, () => <Map<String, dynamic>>[]) as List).add(
      cbCourseRow(c),
    );
  }
  return result;
}

List<Map<String, dynamic>> cbSignStudentRows(
  CbCourse c,
  Map<String, dynamic> sign,
) {
  final states = _studentStates(sign);
  final rows = <Map<String, dynamic>>[];
  for (final sid in cbCourseStudents(c)) {
    final p = cbPerson(sid);
    if (p == null) {
      continue;
    }
    final state = states[sid] is Map ? states[sid] as Map : null;
    rows.add(<String, dynamic>{
      'studentId': p.archiveId,
      'userId': cbStudentUserId(p),
      'realname': p.name,
      'nickname': p.name,
      'no': cbStudentNo(p),
      'headUrl': cbUrl(p.avatarRef),
      'status': state?['status'],
      'signInTime': state?['checkInTime'],
      'remark': cbStr(state?['remark']),
    });
  }
  return rows;
}

/// 任课老师「签课管理」课次详情。
Map<String, dynamic> cbSignDetailJson(CbCourse c) {
  final sign = cbSignOf(c);
  final rows = cbSignStudentRows(c, sign);
  final counts = cbSignCounts(c, sign);
  final teacherIn = cbStr(sign['teacherSignInTime']);
  return <String, dynamic>{
    ...cbCourseRow(c, sign: sign),
    'courseSignStatus': cbInt(sign['signStatus']),
    'shouldCount': rows.length,
    'presentCount': counts.present + counts.late,
    'studentList': rows,
    if (teacherIn.isNotEmpty)
      'teacherSignIn': <String, dynamic>{'signInTime': teacherIn},
  };
}

/// 管理员「签课管理」课次卡片（含学生签到明细）。
Map<String, dynamic> cbSessionJson(CbCourse c) {
  final sign = cbSignOf(c);
  final teacherName = cbStaffName(c.teacherUserId);
  return <String, dynamic>{
    ...cbCourseRow(c, sign: sign),
    'studentList': cbSignStudentRows(c, sign),
    'teacherSignInTime': sign['teacherSignInTime'],
    'teacher': <String, dynamic>{
      'realname': teacherName,
      'nickname': teacherName,
      'headUrl': '',
    },
  };
}

// ── 课堂补签（学生申请，管理员审核） ──────────────────────────────────

const String cbSignMakeupsKey = 'campus_b:sign_makeups';

/// 演示学生林小雨（学生端账号）的档案 id。
const String _demoStudentId = '900001';

DateTime _weekdayOnOrBefore(DateTime day) {
  var d = cbDay(day);
  while (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
    d = cbAddDays(d, -1);
  }
  return d;
}

/// 林小雨的固定缺勤课（学生端与老师端共用）：可申请补签、已通过、已驳回各一节，
/// 都是工作日上午或下午的课（周一至周六的上午、下午都有课）。
({String open, String approved, String rejected}) cbForcedAbsences() {
  final today = cbToday();
  String id(int daysAgo, int lineNum) => _generatedId(
    _weekdayOnOrBefore(cbAddDays(today, -daysAgo)),
    '501',
    lineNum,
  );
  return (open: id(2, 2), approved: id(9, 1), rejected: id(16, 2));
}

/// 补签申请的原因与审核意见（学生端与管理端共用）。
const cbForcedMakeupTexts = (
  approved: (reason: '人脸识别设备故障未能打卡，任课老师可以作证', remark: '经任课老师确认情况属实，同意补签'),
  rejected: (reason: '下午身体不舒服回宿舍休息，忘记请假', remark: '未提前请假，按缺勤处理；后续请先向班主任报备'),
);

List<Map<String, dynamic>> _seedSignMakeups() {
  final result = <Map<String, dynamic>>[];
  final forced = cbForcedAbsences();
  for (final (id, courseId, status, reason, remark) in [
    (
      '6302',
      forced.rejected,
      2,
      cbForcedMakeupTexts.rejected.reason,
      cbForcedMakeupTexts.rejected.remark,
    ),
    (
      '6301',
      forced.approved,
      1,
      cbForcedMakeupTexts.approved.reason,
      cbForcedMakeupTexts.approved.remark,
    ),
  ]) {
    final course = cbCourseById(courseId);
    if (course == null) {
      continue;
    }
    final applied = course.endAt.add(const Duration(hours: 14));
    result.add(<String, dynamic>{
      'id': id,
      'studentId': _demoStudentId,
      'classId': course.classId,
      'courseId': courseId,
      'signType': '1',
      'reason': reason,
      'status': status,
      'finalStatus': 1,
      'auditReason': remark,
      'auditTime': cbDateTime(applied.add(const Duration(hours: 3))),
      'createTime': cbDateTime(applied),
    });
  }
  final picks = <(int, int, String, String, int, String, int)>[
    (1, 12, '1', '上课时人脸识别失败，人一直在教室，请老师补签。', 0, '', 1),
    (2, 21, '1', '去校医室换药迟到 10 分钟，课堂全程在场。', 0, '', 1),
    (1, 13, '1', '平板没电没能扫码签到，任课老师可以证明。', 0, '', 1),
    (3, 6, '1', '画板挡住了镜头没识别到，课上一直在画。', 1, '已与任课老师核实，同意补签。', 1),
    (4, 25, '1', '路上堵车迟到。', 2, '迟到超过 30 分钟，按迟到处理。', 2),
  ];
  var seq = 1;
  for (final (daysAgo, index, signType, reason, status, audit, finalStatus)
      in picks) {
    final studentId = '${900000 + index}';
    final p = cbPerson(studentId);
    final classId = p == null ? '' : cbStr(cbHomeClassOf(p)?['id']);
    CbCourse? course;
    for (var back = daysAgo; back < daysAgo + 7 && course == null; back++) {
      for (final c in cbCoursesOn(cbAddDays(cbToday(), -back))) {
        if (c.classId == classId) {
          course = c;
          break;
        }
      }
    }
    if (course == null) {
      continue;
    }
    final created = course.endAt.add(Duration(minutes: 40 + seq * 7));
    result.add(<String, dynamic>{
      'id': '43${seq.toString().padLeft(5, '0')}',
      'studentId': studentId,
      'classId': classId,
      'courseId': course.id,
      'signType': signType,
      'reason': reason,
      'status': status,
      'finalStatus': finalStatus,
      'auditReason': audit,
      'auditTime': status == 0
          ? null
          : cbDateTime(created.add(const Duration(hours: 2))),
      'createTime': cbDateTime(created),
    });
    seq++;
  }
  return result;
}

List<Map<String, dynamic>> cbSignMakeups() =>
    DemoStore.list(cbSignMakeupsKey, _seedSignMakeups);

void cbSaveSignMakeups() => DemoStore.save(cbSignMakeupsKey);

Map<String, dynamic> cbSignMakeupJson(Map<String, dynamic> m) {
  final p = cbPerson(m['studentId']);
  final course = cbCourseById(m['courseId']);
  return <String, dynamic>{
    ...m,
    'studentName': p?.name ?? '',
    'studentRealname': p?.name ?? '',
    'studentNo': p == null ? '' : cbStudentNo(p),
    'studentHeadUrl': p == null ? '' : cbUrl(p.avatarRef),
    'className': cbClassName(m['classId']),
    'subjectName': course?.subjectName ?? '',
    'courseName': course?.subjectName ?? '',
    'courseDate': course?.date ?? '',
    'lineNum': course?.lineNum ?? 0,
    'teacherName': cbStaffName(course?.teacherUserId),
    'approveRemark': cbStr(m['auditReason']),
  };
}
