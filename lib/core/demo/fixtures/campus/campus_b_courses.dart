/// 智慧校园演示课表：由周课表模板、小班固定课、管理员排课与已通过的
/// 小课申请按日期即时生成；签到状态与学生课堂补签按课次持久化。
library;

import 'dart:convert';

import '../../data/demo_campus_data.dart';
import '../../demo_store.dart';
import 'campus_b_common.dart';

class CbCourse {
  const CbCourse({
    required this.id,
    required this.day,
    required this.classId,
    required this.type,
    required this.subjectName,
    required this.teacherUserId,
    required this.start,
    required this.end,
    required this.lineNum,
    required this.classroomId,
    required this.color,
    this.studentIds = const [],
    this.subjectIdValue,
  });

  final String id;
  final DateTime day;
  final String classId;

  /// 0 = 大课，1 = 小课。
  final int type;
  final String subjectName;
  final String teacherUserId;
  final String start;
  final String end;
  final int lineNum;
  final int classroomId;
  final String color;

  /// 小课参与学生；为空表示整班。
  final List<String> studentIds;
  final int? subjectIdValue;

  int get subjectId => subjectIdValue ?? cbSubjectIdOf(subjectName);

  String get date => cbDate(day);

  DateTime get startAt => cbAt(day, start);

  DateTime get endAt => cbAt(day, end);

  bool get isSmall => type == 1;
}

// ── 课表来源 ──────────────────────────────────────────────────────────

/// 小班固定课：放在大班不排课的周二晚上与周日，成员不会撞上本班大课。
const List<({String classId, DemoTimetableSlot slot})> _smallPlan = [
  (classId: '601', slot: DemoTimetableSlot.am(7, '素描', 't-1', '素描教室 A')),
  (classId: '602', slot: DemoTimetableSlot.eve(2, '色彩', 't-3', '色彩教室 B')),
  (classId: '602', slot: DemoTimetableSlot.pm(7, '色彩', 't-3', '色彩教室 B')),
  (classId: '603', slot: DemoTimetableSlot.eve(2, '速写', 't-4', '速写教室 C')),
  (classId: '603', slot: DemoTimetableSlot.pm(7, '速写', 't-4', '速写教室 C')),
];

/// [day] 所在周（周一开始）往后 [weeks] 周的星期 [weekday]。
DateTime cbWeekday(DateTime day, int weekday, {int weeks = 0}) {
  final monday = cbAddDays(cbDay(day), 1 - day.weekday);
  return cbAddDays(monday, weeks * 7 + weekday - 1);
}

/// 模板生成的课次 id：`7` + 日期 + 班级 + 节次（与学生端课表的课次 id 一致）。
String _generatedId(DateTime day, String classId, int lineNum) =>
    '7${day.year}${cbTwo(day.month)}${cbTwo(day.day)}$classId$lineNum';

/// 课次 id 中的日期：大课 `7yyyyMMdd…`（13 位）、学生个人小课 `8yyyyMMdd…`（10 位）。
DateTime? _dayOfGeneratedId(String id) {
  final generated =
      (id.length == 13 && id.startsWith('7')) ||
      (id.length == 10 && id.startsWith('8'));
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

/// 管理员在排课页写入的大课。
List<Map<String, dynamic>> cbExtraCourses() =>
    DemoStore.list(cbExtraCoursesKey, () => <Map<String, dynamic>>[]);

List<Map<String, dynamic>> _deletedRows() =>
    DemoStore.list(cbDeletedCoursesKey, () => <Map<String, dynamic>>[]);

/// 删除课次：管理员新增的课直接移除，模板 / 申请生成的课记入删除名单。
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
    type: cbInt(m['type']),
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

// ── 小课申请 ──────────────────────────────────────────────────────────

const String cbAppliesKey = 'campus_b:small_course_applies';

List<Map<String, dynamic>> cbApplies() =>
    DemoStore.list(cbAppliesKey, _seedApplies);

void cbSaveApplies() => DemoStore.save(cbAppliesKey);

/// 申请的逐次课程（`courseData` 为 JSON 字符串，与后端一致）。
List<Map<String, dynamic>> cbApplyChildren(Map<String, dynamic> apply) {
  final raw = apply['courseData'];
  Object? decoded = raw;
  if (raw is String && raw.isNotEmpty) {
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      decoded = null;
    }
  }
  if (decoded is! List) {
    return const [];
  }
  return [
    for (final item in decoded)
      if (item is Map) item.map((k, v) => MapEntry(k.toString(), v)),
  ];
}

String cbApplyCourseId(Map<String, dynamic> apply, int index) =>
    '6${cbStr(apply['id'])}${cbTwo(index)}';

List<Map<String, dynamic>> _seedApplies() {
  final today = cbToday();
  DateTime upcoming(int weekday) {
    final day = cbWeekday(today, weekday);
    return day.isAfter(today) ? day : cbAddDays(day, 7);
  }

  Map<String, dynamic> build({
    required String id,
    required String staffId,
    required String classId,
    required String subject,
    required int lineNum,
    required List<DateTime> days,
    required List<int> students,
    required int status,
    required int createdDaysAgo,
    String reason = '',
    String color = '#ACFBBA',
  }) {
    final staff = DemoCampusData.staffById(staffId);
    final cls = cbClass(classId);
    final org = cbStr(cls?['campusName'], '城东校区');
    final classroomId = cbClassroomId(org, switch (subject) {
      '色彩' => '色彩教室 B',
      '速写' => '速写教室 C',
      _ => '素描教室 A',
    });
    final dates = [for (final d in days) cbDate(d)];
    final studentIds = [for (final i in students) '${900000 + i}'];
    final created = cbPast(
      -createdDaysAgo,
      '10:20',
    ).add(Duration(minutes: cbHash(id) % 50));
    return <String, dynamic>{
      'id': id,
      'schoolId': '1',
      'classId': classId,
      'teacherId': staff?.userId ?? '',
      'subjectId': cbSubjectIdOf(subject),
      'subjectName': subject,
      'lineNum': lineNum,
      'color': color,
      'classroomId': classroomId,
      'status': status,
      'reason': reason,
      'createTime': cbDateTime(created),
      'auditTime': status == 0
          ? null
          : cbDateTime(created.add(const Duration(hours: 5))),
      'auditTeacherId': status == 0
          ? null
          : DemoCampusData.staffById('t-9')?.userId,
      'startDate': dates.first,
      'endDate': dates.last,
      'courseData': jsonEncode([
        for (final date in dates)
          <String, dynamic>{
            'classId': classId,
            'classroomId': classroomId,
            'color': color,
            'date': date,
            'lineNum': lineNum,
            'subjectId': cbSubjectIdOf(subject),
            'teacherId': staff?.userId ?? '',
            'studentIds': studentIds,
          },
      ]),
    };
  }

  // 申请都落在申请老师和学生都空闲的时段（周日、周四 / 周六晚上）。
  return [
    build(
      id: '3700001',
      staffId: 't-1',
      classId: '601',
      subject: '素描',
      lineNum: 2,
      days: [upcoming(DateTime.sunday)],
      students: [1, 3, 6],
      status: 0,
      createdDaysAgo: 0,
    ),
    build(
      id: '3700002',
      staffId: 't-4',
      classId: '603',
      subject: '速写',
      lineNum: 1,
      days: [
        for (var w = 0; w < 5; w++)
          cbAddDays(upcoming(DateTime.sunday), w * 7),
      ],
      students: [12, 15, 18, 5],
      status: 0,
      createdDaysAgo: 1,
      color: '#BFE6FF',
    ),
    build(
      id: '3700003',
      staffId: 't-1',
      classId: '501',
      subject: '素描',
      lineNum: 3,
      days: [cbWeekday(today, DateTime.thursday, weeks: -1)],
      students: [12, 15],
      status: 1,
      createdDaysAgo: 12,
    ),
    build(
      id: '3700004',
      staffId: 't-3',
      classId: '602',
      subject: '色彩',
      lineNum: 2,
      days: [upcoming(DateTime.saturday)],
      students: [10, 13, 16],
      status: 2,
      createdDaysAgo: 2,
      reason: '当天下午刘芳老师带联考冲刺1班外出写生，时间冲突，请改到周六晚上再申请。',
      color: '#FFD6B8',
    ),
    build(
      id: '3700005',
      staffId: 't-3',
      classId: '602',
      subject: '色彩',
      lineNum: 3,
      days: [upcoming(DateTime.saturday)],
      students: [19, 22],
      status: 0,
      createdDaysAgo: 0,
      color: '#FFD6B8',
    ),
  ];
}

List<CbCourse> _applyCourses(DateTime? onDay) {
  final result = <CbCourse>[];
  for (final apply in cbApplies()) {
    if (cbInt(apply['status']) != 1) {
      continue;
    }
    final children = cbApplyChildren(apply);
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      final day = cbParseDay(child['date']);
      if (day == null || (onDay != null && day != onDay)) {
        continue;
      }
      final lineNum = cbInt(child['lineNum'] ?? apply['lineNum'], 1);
      final (start, end) = cbLineTime(lineNum);
      final subjectId = cbInt(child['subjectId'] ?? apply['subjectId'], 38);
      final subjectName =
          cbSubjectNameOf(subjectId) ?? cbStr(apply['subjectName'], '素描');
      result.add(
        CbCourse(
          id: cbApplyCourseId(apply, i),
          day: day,
          classId: cbStr(child['classId'] ?? apply['classId']),
          type: 1,
          subjectName: subjectName,
          subjectIdValue: subjectId,
          teacherUserId: cbStr(child['teacherId'] ?? apply['teacherId']),
          start: start,
          end: end,
          lineNum: lineNum,
          classroomId: cbInt(child['classroomId'] ?? apply['classroomId'], 11),
          color: cbStr(child['color'] ?? apply['color'], '#ACFBBA'),
          studentIds: cbStrList(child['studentIds']),
        ),
      );
    }
  }
  return result;
}

/// 学生端林小雨的个人改画小课（[DemoCampusData.demoStudentSmallCourses]），
/// 老师端同步展示；课次 id 为 `8` + 日期 + 节次。
List<CbCourse> _demoStudentSmallCourses(DateTime day) {
  final compact = '${day.year}${cbTwo(day.month)}${cbTwo(day.day)}';
  final home = DemoCampusData.classById('501');
  final org = home?.organizationName ?? '城东校区';
  return [
    for (final slot in DemoCampusData.demoStudentSmallCourses)
      if (slot.weekday == day.weekday)
        CbCourse(
          id: '8$compact${cbLineNumOf(slot.start)}',
          day: day,
          classId: '501',
          type: 1,
          subjectName: slot.courseName,
          teacherUserId: DemoCampusData.staffById(slot.teacherId)?.userId ?? '',
          start: slot.start,
          end: slot.end,
          lineNum: cbLineNumOf(slot.start),
          classroomId: cbClassroomId(org, slot.room),
          color: cbCourseColor(slot.courseName, small: true),
          studentIds: const [_demoStudentId],
        ),
  ];
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
          type: 0,
          subjectName: slot.courseName,
          teacherUserId:
              DemoCampusData.staffById(slot.teacherId)?.userId ?? '',
          start: slot.start,
          end: slot.end,
          lineNum: lineNum,
          classroomId: cbClassroomId(c.organizationName, slot.room),
          color: cbCourseColor(slot.courseName),
        ),
      );
    }
  }
  for (final plan in _smallPlan) {
    final slot = plan.slot;
    final cls = cbClass(plan.classId);
    final lineNum = cbLineNumOf(slot.start);
    final id = _generatedId(day, plan.classId, lineNum);
    if (slot.weekday != day.weekday || cls == null || deleted.contains(id)) {
      continue;
    }
    result.add(
      CbCourse(
        id: id,
        day: day,
        classId: plan.classId,
        type: 1,
        subjectName: slot.courseName,
        teacherUserId: DemoCampusData.staffById(slot.teacherId)?.userId ?? '',
        start: slot.start,
        end: slot.end,
        lineNum: lineNum,
        classroomId: cbClassroomId(
          cbStr(cls['campusName'], '城东校区'),
          slot.room,
        ),
        color: cbCourseColor(slot.courseName, small: true),
      ),
    );
  }
  for (final c in _demoStudentSmallCourses(day)) {
    if (!deleted.contains(c.id)) {
      result.add(c);
    }
  }
  final date0 = cbDate(day);
  for (final m in cbExtraCourses()) {
    if (cbStr(m['date']) == date0) {
      result.add(_extraCourse(m));
    }
  }
  for (final c in _applyCourses(day)) {
    if (!deleted.contains(c.id)) {
      result.add(c);
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
  for (final c in _applyCourses(null)) {
    if (c.id == id) {
      return c;
    }
  }
  return null;
}

/// 课次学生名单：小课为申请勾选的学生，大课为班级在籍学生。
List<String> cbCourseStudents(CbCourse c) {
  if (c.studentIds.isEmpty) {
    return cbActiveStudents(c.classId);
  }
  return [
    for (final id in c.studentIds)
      if (cbPerson(id) case final p? when cbIsActive(p)) p.archiveId,
  ];
}

// ── 签到状态 ──────────────────────────────────────────────────────────

const String cbSignsKey = 'campus_b:course_signs';

Map<String, dynamic> _signStore() =>
    DemoStore.map(cbSignsKey, () => <String, dynamic>{});

const List<String> _evalComments = [
  '老师示范很清楚，暗部的处理终于明白了',
  '讲评很细，知道下一张该怎么改了',
  '节奏有点快，希望多留点时间画',
  '动态线讲得很透彻，收获很大',
  '冷暖关系讲得很实用，回去马上练',
];

/// 已结束课次的默认签到：大课已一键签到，小课按日期处于待确认 / 已确认；
/// 有补签申请的学生按申请结果记为出勤或缺勤。
Map<String, dynamic> _defaultSign(CbCourse c) {
  final now = DateTime.now();
  if (!now.isAfter(c.endAt)) {
    return <String, dynamic>{'signStatus': 0, 'students': <String, dynamic>{}};
  }
  final students = <String, dynamic>{};
  final teacherIn = c.startAt.subtract(const Duration(minutes: 4));
  final teacherOut = c.endAt.add(const Duration(minutes: 2));
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
      if (present && c.isSmall)
        'checkOutTime': cbDateTime(teacherOut.add(Duration(minutes: roll % 4))),
      if (present && c.isSmall) 'score': roll % 3 == 0 ? 4 : 5,
      if (present && c.isSmall)
        'comment': _evalComments[roll % _evalComments.length],
      if (status == 3) 'remark': '已提交请假条',
    };
  }
  final int status;
  if (!c.isSmall) {
    status = 2;
  } else {
    status = c.day.isBefore(cbAddDays(cbToday(), -1)) ? 6 : 5;
  }
  return <String, dynamic>{
    'signStatus': status,
    'teacherSignInTime': cbDateTime(teacherIn),
    if (c.isSmall) 'teacherSignOutTime': cbDateTime(teacherOut),
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

/// 小课演示推进：老师上课签到 8 秒后学生完成签到；下课签到后学生陆续签退、评价。
Map<String, dynamic> _advance(CbCourse c, Map<String, dynamic> sign) {
  if (!c.isSmall) {
    return sign;
  }
  final now = DateTime.now();
  var status = cbInt(sign['signStatus']);
  final states = _studentStates(sign);
  if (status == 1) {
    final teacherIn = cbParse(sign['teacherSignInTime']);
    if (teacherIn != null && now.difference(teacherIn).inSeconds >= 8) {
      status = 2;
      for (final sid in cbCourseStudents(c)) {
        final state = Map<String, dynamic>.from(states[sid] as Map? ?? {});
        state['status'] ??= 0;
        state['checkInTime'] ??= cbDateTime(
          teacherIn.add(Duration(seconds: 5 + cbHash(sid) % 3)),
        );
        states[sid] = state;
      }
    }
  }
  if (status == 3) {
    final teacherOut = cbParse(sign['teacherSignOutTime']);
    final seconds = teacherOut == null
        ? 0
        : now.difference(teacherOut).inSeconds;
    if (teacherOut != null && seconds >= 8) {
      status = seconds >= 16 ? 5 : 4;
      for (final sid in cbCourseStudents(c)) {
        final state = Map<String, dynamic>.from(states[sid] as Map? ?? {});
        state['checkOutTime'] ??= cbDateTime(
          teacherOut.add(Duration(seconds: 6 + cbHash(sid) % 2)),
        );
        if (status == 5) {
          final roll = cbHash('${c.id}|$sid') % 100;
          state['score'] ??= roll % 3 == 0 ? 4 : 5;
          state['comment'] ??= _evalComments[roll % _evalComments.length];
        }
        states[sid] = state;
      }
    }
  }
  sign['signStatus'] = status;
  sign['students'] = states;
  return sign;
}

/// 课次当前签到状态（含演示推进）。
Map<String, dynamic> cbSignOf(CbCourse c) {
  final stored = _signStore()[c.id];
  final base = stored is Map ? cbCopy(stored) : _defaultSign(c);
  return _advance(c, base);
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
  final cls = cbClass(c.classId);
  final className = c.isSmall && cls != null && !cbIsSmallClass(cls)
      ? '${cbStr(cls['name'])} · 小课'
      : cbStr(cls?['name']);
  return <String, dynamic>{
    'id': c.id,
    'courseId': c.id,
    'date': c.date,
    'courseDate': c.date,
    'weekday': c.day.weekday,
    'lineNum': c.lineNum,
    'type': c.type,
    'timeBegin': '${c.start}:00',
    'timeEnd': '${c.end}:00',
    'courseStartTime': '${c.date} ${c.start}:00',
    'courseEndTime': '${c.date} ${c.end}:00',
    'classId': c.classId,
    'className': className,
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
    if (c.isSmall) 'attendCount': counts.present + counts.late,
    if (c.isSmall) 'totalCount': students.length,
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
      'signOutTime': state?['checkOutTime'],
      'remark': cbStr(state?['remark']),
      if (c.isSmall && state?['score'] != null) 'score': state?['score'],
      if (c.isSmall && cbStr(state?['comment']).isNotEmpty)
        'comment': state?['comment'],
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
  final teacherOut = cbStr(sign['teacherSignOutTime']);
  return <String, dynamic>{
    ...cbCourseRow(c, sign: sign),
    'courseSignStatus': cbInt(sign['signStatus']),
    'shouldCount': rows.length,
    'presentCount': counts.present + counts.late,
    'studentList': rows,
    if (teacherIn.isNotEmpty)
      'teacherSignIn': <String, dynamic>{
        'signInTime': teacherIn,
        if (teacherOut.isNotEmpty) 'signOutTime': teacherOut,
      },
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
    'teacherSignOutTime': sign['teacherSignOutTime'],
    'teacher': <String, dynamic>{
      'realname': teacherName,
      'nickname': teacherName,
      'headUrl': '',
    },
  };
}

/// 小课申请记录（任课老师「我的申请」与管理员审核共用）。
Map<String, dynamic> cbApplyJson(Map<String, dynamic> apply) {
  final teacher = cbStaff(apply['teacherId']);
  final children = cbApplyChildren(apply);
  final subjectId = cbInt(apply['subjectId'], 38);
  return <String, dynamic>{
    ...apply,
    'className': cbClassName(apply['classId']),
    'classroomName': cbClassroomName(cbInt(apply['classroomId'])),
    'subjectName': cbSubjectNameOf(subjectId) ?? cbStr(apply['subjectName']),
    'teacherRealname': teacher?.name ?? '',
    'teacherName': teacher?.name ?? '',
    'courseCount': children.length,
    'studentNames': [
      for (final id
          in children.isEmpty
              ? const <String>[]
              : cbStrList(children.first['studentIds']))
        cbPerson(id)?.name ?? '',
    ].where((n) => n.isNotEmpty).join('、'),
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
/// 都是工作日上午或下午的大课（周一至周六的上午、下午都有课）。
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
  approved: (
    reason: '人脸识别设备故障未能打卡，任课老师可以作证',
    remark: '经任课老师确认情况属实，同意补签',
  ),
  rejected: (
    reason: '下午身体不舒服回宿舍休息，忘记请假',
    remark: '未提前请假，按缺勤处理；后续请先向班主任报备',
  ),
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
    (3, 6, '2', '下课签退时平板没电了。', 1, '已与任课老师核实，同意补签。', 1),
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
        if (c.classId == classId && !c.isSmall) {
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
    'type': course?.type ?? 0,
    'teacherName': cbStaffName(course?.teacherUserId),
    'approveRemark': cbStr(m['auditReason']),
  };
}
