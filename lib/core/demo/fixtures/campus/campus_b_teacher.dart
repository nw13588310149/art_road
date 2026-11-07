/// 智慧校园 · 任课老师端演示接口（`/app/school/v2/teacher/*` 中与授课相关的
/// 部分）：身份、班级与课表、签课、小课申请、校级通知、学生名册、考评与作业、
/// 我的请假。班主任端的接口见 campus_b_head_teacher.dart。
library;

import 'dart:convert';

import '../../data/demo_marking_data.dart';
import '../../demo_accounts.dart';
import '../../demo_backend.dart';
import '../../demo_store.dart';
import 'campus_b_common.dart';
import 'campus_b_courses.dart';
import 'campus_b_homework.dart';
import 'campus_b_people.dart';
import 'campus_b_records.dart';

const String _base = '/app/school/v2/teacher';

void registerCampusBTeacher(DemoRouter r) {
  r.post('$_base/teacherRole', _teacherRole);
  r.post('$_base/classList', _classList);
  r.post('$_base/classroomList', (req) => cbClassroomList());
  r.post('$_base/courseList', _courseList);
  r.post('$_base/courseTeacherIndex', _courseTeacherIndex);

  r.post('$_base/courseAttendanceStat', _attendanceStat);
  r.post('$_base/courseAttendanceRecentList', _attendanceRecent);
  r.post('$_base/courseAttendanceHistory', _attendanceHistory);
  r.post('$_base/courseClassSignDetail', _signDetail);
  r.post('$_base/courseClassSignAll', _signAll);
  r.post('$_base/courseClassStudentSignUpdate', _signStudentUpdate);
  r.post('$_base/courseTeacherSignHistory', _signHistory);
  r.post('$_base/courseTeacherSignIn', _teacherSignIn);
  r.post('$_base/courseTeacherSignOut', _teacherSignOut);

  r.post('$_base/schoolSmallCourseApplySave', _applySave);
  r.post('$_base/schoolSmallCourseApplyList', _applyList);
  r.post('$_base/schoolSmallCourseApplyDetail', _applyDetail);

  r.post(
    '$_base/courseTeacherNoticeList',
    (req) => _noticeList(req, 'course_teacher'),
  );
  r.post(
    '$_base/headTeacherNoticeList',
    (req) => _noticeList(req, 'head_teacher'),
  );
  r.post('$_base/noticeDetail', _noticeDetail);

  r.post('$_base/studentList', _studentList);
  r.post('$_base/studentDetail', _studentDetail);
  r.post('$_base/studentExamRecordList', _studentExamRecords);

  r.post('$_base/examList', _examList);
  r.post('$_base/examStudentList', _examStudentList);
  r.post('$_base/examStudentScore', _examStudentScore);
  r.post('$_base/examStudentStat', _examStudentStat);
  r.post('$_base/examStudentRemind', _examStudentRemind);
  r.post('$_base/examFullDetail', _examFullDetail);

  r.post('$_base/teacherHomeworkSum', _homeworkSum);
  r.post('$_base/teacherHomeworkList', _homeworkList);
  r.post('$_base/teacherHomeworkSave', _homeworkSave);
  r.post('$_base/teacherHomeworkDetail', _homeworkDetail);
  r.post('$_base/teacherHomeworkCorrect', _homeworkCorrect);
  r.post('$_base/teacherHomeworkDelete', _homeworkDelete);
  r.post('$_base/studentHomeworkDetail', _studentHomeworkDetail);

  r.post('$_base/teacherLeaveList', _leaveList);
  r.post('$_base/teacherLeaveSave', _leaveSave);
  r.post('$_base/teacherLeaveDetail', _leaveDetail);
}

// ── 身份与班级 ────────────────────────────────────────────────────────

Object? _teacherRole(DemoRequest req) {
  final scope = cbScope(req);
  final staff = scope.staff;
  if (req.account.role == DemoRole.student || staff == null) {
    return const <Object>[];
  }
  return [
    <String, dynamic>{
      'id': staff.userId,
      'teacherId': staff.userId,
      'userId': staff.userId,
      'schoolId': '1',
      'campusId': cbCampusIdOf(staff.organizationName),
      'roles': cbStaffRoles(staff),
      'realname': staff.name,
      'no': cbStaffNo(staff),
      'teacherStatus': cbStaffOnLeave(staff.userId) ? '请假' : '在岗',
    },
  ];
}

Object? _classList(DemoRequest req) {
  final scope = cbScope(req);
  final type = cbStr(req.value('type')).isEmpty ? null : req.intOf('type');
  final ids = req.intOf('isHeadTeacher') == 1
      ? scope.headClassIds
      : scope.teachingClassIds;
  return [
    for (final id in ids)
      if (cbClass(id) case final c?
          when type == null || cbInt(c['type']) == type)
        cbClassJson(c),
  ];
}

/// 当前账号授课的课次；管理员视角为全部班级的课。
List<CbCourse> cbScopeCourses(CbScope scope, DateTime from, DateTime to) => [
  for (final c in cbCoursesBetween(from, to))
    if (scope.all || c.teacherUserId == scope.userId) c,
];

(DateTime, DateTime) _range(
  DemoRequest req, {
  required DateTime fallbackFrom,
  required DateTime fallbackTo,
  int maxDays = 62,
}) {
  var from = cbParseDay(req.str('beginDate')) ?? fallbackFrom;
  var to = cbParseDay(req.str('endDate')) ?? fallbackTo;
  if (to.isBefore(from)) {
    final swap = from;
    from = to;
    to = swap;
  }
  if (to.difference(from).inDays > maxDays) {
    from = cbAddDays(to, -maxDays);
  }
  return (from, to);
}

DateTime _mondayOf(DateTime day) => cbAddDays(cbDay(day), 1 - day.weekday);

Object? _courseList(DemoRequest req) {
  final monday = _mondayOf(DateTime.now());
  final (from, to) = _range(
    req,
    fallbackFrom: monday,
    fallbackTo: cbAddDays(monday, 6),
  );
  return cbCourseRowsByDate(cbScopeCourses(cbScope(req), from, to));
}

int _pendingHomework(CbScope scope) {
  var count = 0;
  for (final hw in cbHomework()) {
    if (scope.ownsTeacher(hw['teacherUserId'])) {
      count += cbHomeworkCounts(hw).pending;
    }
  }
  return count;
}

Object? _courseTeacherIndex(DemoRequest req) {
  final scope = cbScope(req);
  final now = DateTime.now();
  final today = cbScopeCourses(scope, cbToday(), cbToday());
  CbCourse? current;
  CbCourse? next;
  for (final c in today) {
    if (current == null && !now.isBefore(c.startAt) && now.isBefore(c.endAt)) {
      current = c;
    }
    if (next == null && c.startAt.isAfter(now)) {
      next = c;
    }
  }
  // 没有进行中的课时，「当前课程」展示今天下一节（前端按时间显示为未开始）。
  current ??= next;
  if (next == null) {
    final upcoming = cbScopeCourses(
      scope,
      cbAddDays(cbToday(), 1),
      cbAddDays(cbToday(), 7),
    );
    next = upcoming.isEmpty ? null : upcoming.first;
  }
  final monday = _mondayOf(now);
  return <String, dynamic>{
    'todayCourseCount': today.length,
    'pendingHomeworkCount': _pendingHomework(scope),
    'todayCourseList': [for (final c in today) cbCourseRow(c)],
    'currentCourse': current == null ? null : cbCourseRow(current),
    'nextCourse': next == null ? null : cbCourseRow(next),
    'weekCourseCount': cbScopeCourses(
      scope,
      monday,
      cbAddDays(monday, 6),
    ).length,
  };
}

// ── 签课 ──────────────────────────────────────────────────────────────

/// 「累计」从上一学年暑期集训算起，保证不少于「本学期」。
DateTime _historyStart() {
  final today = cbToday();
  final termStart = today.month >= 8
      ? DateTime(today.year, 8)
      : DateTime(today.year - 1, 8);
  return cbAddDays(termStart, -60);
}

/// 已结束或已开始签到的课次（考勤统计口径）。
List<CbCourse> _signedCourses(DemoRequest req, CbScope scope) {
  final (from, to) = _range(
    req,
    fallbackFrom: _historyStart(),
    fallbackTo: cbToday(),
    maxDays: 400,
  );
  final end = to.isAfter(cbToday()) ? cbToday() : to;
  final classId = req.str('classId');
  final courseId = req.str('courseId');
  final now = DateTime.now();
  return [
    for (final c in cbScopeCourses(scope, from, end))
      if ((classId.isEmpty || c.classId == classId) &&
          (courseId.isEmpty || c.id == courseId) &&
          (c.endAt.isBefore(now) || cbSignStatus(c) > 0))
        c,
  ];
}

Object? _attendanceStat(DemoRequest req) {
  final scope = cbScope(req);
  var total = 0;
  var present = 0;
  var late = 0;
  var absent = 0;
  var leave = 0;
  for (final c in _signedCourses(req, scope)) {
    final sign = cbSignOf(c);
    if (cbInt(sign['signStatus']) == 0) {
      continue;
    }
    total++;
    final counts = cbSignCounts(c, sign);
    present += counts.present;
    late += counts.late;
    absent += counts.absent;
    leave += counts.leave;
  }
  final expected = present + late + absent + leave;
  return <String, dynamic>{
    'totalCount': total,
    'normalCount': present,
    'lateCount': late,
    'absentCount': absent,
    'leaveCount': leave,
    'attendanceRate': expected == 0
        ? 0
        : cbRoundTo((present + late) * 100 / expected, 1),
  };
}

Map<String, dynamic> _historyRow(CbCourse c, CbScope scope) {
  final sign = cbSignOf(c);
  final counts = cbSignCounts(c, sign);
  final shouldCount = cbCourseStudents(c).length;
  return <String, dynamic>{
    ...cbCourseRow(c, sign: sign),
    'teacherId': scope.account.userId,
    'signInTime': sign['teacherSignInTime'],
    'signOutTime': sign['teacherSignOutTime'],
    'shouldCount': shouldCount,
    'presentCount': counts.present + counts.late,
    'lateCount': counts.late,
    'absentCount': counts.absent,
    'leaveCount': counts.leave,
    'method': c.isSmall ? '教师上下课签' : '教师一键签到',
  };
}

/// 已签到的课次（新到旧）；分页后再组装行，避免管理员视角一次构建上千行。
List<CbCourse> _historyCourses(DemoRequest req, CbScope scope) =>
    _signedCourses(req, scope).where((c) => cbSignStatus(c) > 0).toList()
      ..sort((a, b) => b.startAt.compareTo(a.startAt));

Map<String, dynamic> _historyPage(DemoRequest req, List<CbCourse> courses) {
  final scope = cbScope(req);
  final page = demoPage(courses, req);
  page['records'] = [
    for (final c in page['records'] as List) _historyRow(c as CbCourse, scope),
  ];
  return page;
}

Object? _signHistory(DemoRequest req) =>
    _historyPage(req, _historyCourses(req, cbScope(req)));

Object? _attendanceRecent(DemoRequest req) {
  final scope = cbScope(req);
  final size = req.intOf('size', 10).clamp(1, 50);
  return [
    for (final c in _historyCourses(req, scope).take(size))
      _historyRow(c, scope),
  ];
}

Object? _attendanceHistory(DemoRequest req) {
  final status = cbStr(req.value('status'));
  final courses = [
    for (final c in _historyCourses(req, cbScope(req)))
      if (status.isEmpty || cbSignStatus(c) == cbInt(status)) c,
  ];
  return _historyPage(req, courses);
}

CbCourse _courseOf(DemoRequest req) {
  final course = cbCourseById(req.str('courseId'));
  if (course == null) {
    throw const DemoApiException('课次不存在或已被删除');
  }
  return course;
}

Object? _signDetail(DemoRequest req) => cbSignDetailJson(_courseOf(req));

Object? _signAll(DemoRequest req) {
  final course = _courseOf(req);
  final sign = cbSignOf(course);
  final raw = sign['students'];
  final states = raw is Map
      ? raw.map((k, v) => MapEntry(k.toString(), v))
      : <String, dynamic>{};
  final now = cbDateTime(DateTime.now());
  final provided = <String>{};
  for (final item in req.listOf('students')) {
    if (item is! Map) {
      continue;
    }
    final sid = cbStr(item['studentId']);
    if (sid.isEmpty) {
      continue;
    }
    provided.add(sid);
    final status = cbInt(item['signStatus']);
    final state = Map<String, dynamic>.from(states[sid] as Map? ?? {});
    state['status'] = status;
    final remark = cbStr(item['remark']);
    if (remark.isNotEmpty) {
      state['remark'] = remark;
    }
    if (status == 0 || status == 2) {
      state['checkInTime'] ??= now;
    }
    states[sid] = state;
  }
  for (final sid in cbCourseStudents(course)) {
    if (!provided.contains(sid) && states[sid] == null) {
      states[sid] = <String, dynamic>{'status': 0, 'checkInTime': now};
    }
  }
  sign['students'] = states;
  if (cbInt(sign['signStatus']) < 2) {
    sign['signStatus'] = 2;
  }
  sign['teacherSignInTime'] ??= now;
  cbSaveSign(course, sign);
  return true;
}

Object? _signStudentUpdate(DemoRequest req) {
  final course = _courseOf(req);
  final studentId = req.str('studentId');
  if (!cbCourseStudents(course).contains(studentId)) {
    throw const DemoApiException('该学生不在本节课名单中');
  }
  cbSetStudentSign(
    course,
    studentId,
    req.intOf('signStatus'),
    remark: req.str('remark'),
  );
  return true;
}

Object? _teacherSignIn(DemoRequest req) {
  final course = _courseOf(req);
  final sign = cbSignOf(course);
  if (cbInt(sign['signStatus']) >= 1) {
    throw const DemoApiException('已完成上课签到');
  }
  sign['signStatus'] = 1;
  sign['teacherSignInTime'] = cbDateTime(DateTime.now());
  cbSaveSign(course, sign);
  return true;
}

Object? _teacherSignOut(DemoRequest req) {
  final course = _courseOf(req);
  final sign = cbSignOf(course);
  final status = cbInt(sign['signStatus']);
  if (status < 2) {
    throw const DemoApiException('请等待学生完成上课签到');
  }
  if (status >= 3) {
    throw const DemoApiException('已完成下课签到');
  }
  sign['signStatus'] = 3;
  sign['teacherSignOutTime'] = cbDateTime(DateTime.now());
  cbSaveSign(course, sign);
  return true;
}

// ── 小课申请 ──────────────────────────────────────────────────────────

Object? _applySave(DemoRequest req) {
  final scope = cbScope(req);
  final children = <Map<String, dynamic>>[];
  for (final item in req.listOf('courseList')) {
    if (item is! Map) {
      continue;
    }
    final date = cbStr(item['date']);
    if (cbParseDay(date) == null) {
      continue;
    }
    children.add(<String, dynamic>{
      'classId': cbStr(item['classId'], req.str('classId')),
      'classroomId': cbInt(item['classroomId'], req.intOf('classroomId')),
      'color': cbStr(item['color'], req.str('color', '#ACFBBA')),
      'date': date,
      'lineNum': cbInt(item['lineNum'], req.intOf('lineNum', 1)),
      'subjectId': cbInt(item['subjectId'], req.intOf('subjectId', 38)),
      'teacherId': cbStr(item['teacherId'], scope.userId),
      'studentIds': cbStrList(item['studentIds']),
    });
  }
  if (children.isEmpty) {
    throw const DemoApiException('请至少选择一个上课日期');
  }
  if (cbStrList(children.first['studentIds']).isEmpty) {
    throw const DemoApiException('请至少勾选一名参与学生');
  }
  final classId = req.str('classId', cbStr(children.first['classId']));
  if (cbClass(classId) == null) {
    throw const DemoApiException('班级不存在');
  }
  final subjectId = req.intOf(
    'subjectId',
    cbInt(children.first['subjectId'], 38),
  );
  cbApplies().add(<String, dynamic>{
    'id': DemoStore.nextId(),
    'schoolId': '1',
    'classId': classId,
    'teacherId': scope.userId,
    'subjectId': subjectId,
    'subjectName': cbSubjectNameOf(subjectId) ?? scope.staff?.subject ?? '素描',
    'lineNum': req.intOf('lineNum', cbInt(children.first['lineNum'], 1)),
    'color': req.str('color', cbStr(children.first['color'], '#ACFBBA')),
    'classroomId': req.intOf(
      'classroomId',
      cbInt(children.first['classroomId']),
    ),
    'status': 0,
    'reason': '',
    'createTime': cbDateTime(DateTime.now()),
    'auditTime': null,
    'auditTeacherId': null,
    'startDate': req.str('startDate', cbStr(children.first['date'])),
    'endDate': req.str('endDate', cbStr(children.last['date'])),
    'courseData': jsonEncode(children),
  });
  cbSaveApplies();
  return true;
}

Object? _applyList(DemoRequest req) {
  final scope = cbScope(req);
  final rows = [
    for (final apply in cbApplies())
      if (scope.ownsTeacher(apply['teacherId'])) apply,
  ]..sort((a, b) => cbStr(b['createTime']).compareTo(cbStr(a['createTime'])));
  return demoPage([for (final a in rows) cbApplyJson(a)], req);
}

Object? _applyDetail(DemoRequest req) {
  final id = req.str('id');
  for (final apply in cbApplies()) {
    if (cbStr(apply['id']) == id) {
      return cbApplyJson(apply);
    }
  }
  throw const DemoApiException('申请记录不存在');
}

// ── 校级通知 ──────────────────────────────────────────────────────────

Object? _noticeList(DemoRequest req, String scopeKey) {
  final rows = [
    for (final n in cbSortedNotices())
      if (cbNoticeStatus(n) == 1 && cbCsv(n['pushScope']).contains(scopeKey))
        cbNoticeJson(n),
  ];
  return demoPage(rows, req);
}

Object? _noticeDetail(DemoRequest req) {
  final id = req.str('id');
  for (final n in cbNotices()) {
    if (cbStr(n['id']) == id) {
      return cbNoticeJson(n);
    }
  }
  throw const DemoApiException('通知不存在或已删除');
}

// ── 学生名册 ──────────────────────────────────────────────────────────

/// 姓名、学号、手机、宿舍、家长手机任一包含关键字。
bool cbStudentMatches(DemoPerson p, String keyword) {
  final key = keyword.trim();
  if (key.isEmpty) {
    return true;
  }
  final parent = cbParentsOf(p).first;
  return p.name.contains(key) ||
      cbStudentNo(p).contains(key) ||
      p.phone.contains(key) ||
      cbBedInfo(p).contains(key) ||
      (parent['mobile'] ?? '').contains(key) ||
      (parent['name'] ?? '').contains(key);
}

Object? _studentList(DemoRequest req) {
  final scope = cbScope(req);
  final keyword = req.str('keyword');
  final status = req.str('studentStatus');
  final rows = <Map<String, dynamic>>[];
  for (final id in cbVisibleStudentIds(scope, classId: req.str('classId'))) {
    final p = cbPerson(id);
    if (p == null ||
        !cbStudentMatches(p, keyword) ||
        (status.isNotEmpty && cbStudentStatus(p) != status)) {
      continue;
    }
    rows.add(cbStudentRow(p));
  }
  return demoPage(rows, req);
}

DemoPerson _personOf(DemoRequest req, String key) {
  final p = cbPerson(req.str(key));
  if (p == null) {
    throw const DemoApiException('学生不存在');
  }
  return p;
}

Object? _studentDetail(DemoRequest req) =>
    cbStudentDetail(_personOf(req, 'id'));

Object? _studentExamRecords(DemoRequest req) =>
    cbStudentExamRecords(_personOf(req, 'studentId'));

// ── 考评管理（成绩来自阅卷演示数据） ──────────────────────────────────

DemoExamDef _examOf(DemoRequest req, String key) {
  final exam = DemoMarkingData.instance.exam(req.str(key));
  if (exam == null) {
    throw const DemoApiException('考试不存在');
  }
  return exam;
}

DemoSubjectDef _subjectOf(DemoExamDef exam, DemoRequest req) {
  final subjectId = req.str('subjectId');
  for (final def in exam.subjects) {
    if (def.subjectId == subjectId) {
      return def;
    }
  }
  throw const DemoApiException('该考试没有这个科目');
}

String _examRemark(DemoExamDef exam) {
  if (!exam.reviewed) {
    return '阅卷进行中：考生作品照片已收齐，请在本周内完成评分，成绩发布后同步到学情中心。';
  }
  final judges = exam.subjects.first.judgeCount;
  final rule = exam.subjects.first.trimmed ? '去掉最高分和最低分后取平均' : '取平均分';
  return '${exam.examName}共考素描、色彩、速写三科，每科满分 100 分；每份试卷由 $judges 位老师'
      '独立评阅后$rule，分差超过 10 分进入仲裁。';
}

/// 考评列表按「考试 × 任教科目」展开，只列出任教班级有考生的考试。
Object? _examList(DemoRequest req) {
  final scope = cbScope(req);
  final filter = req.str('classId');
  final classIds = filter.isEmpty
      ? [
          for (final id in scope.teachingClassIds)
            if (cbClass(id) case final c? when !cbIsSmallClass(c)) id,
        ]
      : [if (scope.all || scope.teachingClassIds.contains(filter)) filter];
  final data = DemoMarkingData.instance;
  final rows = <Map<String, dynamic>>[];
  for (final exam in data.exams.reversed) {
    bool registered(String sid) {
      final p = cbPerson(sid);
      return p != null && data.entryOf(p.index, exam.examId) != null;
    }

    final involved = [
      for (final cid in classIds)
        if (cbClassStudentIds(cid).any(registered)) cid,
    ];
    if (involved.isEmpty) {
      continue;
    }
    for (final subject in scope.examSubjects) {
      final def = exam.subjects
          .where((s) => s.subjectName == subject)
          .firstOrNull;
      if (def == null) {
        continue;
      }
      rows.add(<String, dynamic>{
        'id': exam.examId,
        'examId': exam.examId,
        'name': exam.examName,
        'examName': exam.examName,
        'examCode': exam.examCode,
        'examDate': exam.examDate,
        'status': exam.reviewed ? 1 : 0,
        'subjectId': int.parse(def.subjectId),
        'subjectName': subject,
        'subjectIds': [for (final s in exam.subjects) int.parse(s.subjectId)],
        'subjectNames': [for (final s in exam.subjects) s.subjectName],
        'fullScore': def.fullScore,
        'classList': [
          for (final cid in involved)
            <String, dynamic>{'id': cid, 'name': cbClassName(cid)},
        ],
        'remark': _examRemark(exam),
      });
    }
  }
  return rows;
}

typedef _ExamRow = ({
  DemoPerson person,
  DemoExamEntry entry,
  double? score,
  bool submitted,
  String comment,
});

/// [classId] 为空时统计老师任教的全部班级，否则只统计所选班级。
List<_ExamRow> _examRows(
  CbScope scope,
  DemoExamDef exam,
  DemoSubjectDef def, {
  String classId = '',
}) {
  final data = DemoMarkingData.instance;
  final rows = <_ExamRow>[];
  for (final sid in cbVisibleStudentIds(scope, classId: classId)) {
    final p = cbPerson(sid);
    final entry = p == null ? null : data.entryOf(p.index, exam.examId);
    if (p == null || entry == null) {
      continue;
    }
    final override = cbExamOverride(exam.examId, def.subjectId, p.archiveId);
    final score = cbSubjectScore(entry, def);
    final absent =
        exam.reviewed && entry.registration.results == null && override == null;
    rows.add((
      person: p,
      entry: entry,
      score: score,
      submitted: !absent,
      comment: score == null ? '' : cbSubjectComment(entry, def),
    ));
  }
  return rows;
}

String _submitTime(DemoExamDef exam, DemoSubjectDef def) =>
    '${exam.examDate} ${switch (def.subjectName) {
      '色彩' => '15:30:00',
      '速写' => '17:10:00',
      _ => '11:30:00',
    }}';

Object? _examStudentList(DemoRequest req) {
  final scope = cbScope(req);
  final exam = _examOf(req, 'examId');
  final def = _subjectOf(exam, req);
  final scoreStatus = cbStr(req.value('scoreStatus'));
  final rows = _examRows(scope, exam, def, classId: req.str('classId'))
    ..sort((a, b) {
      int rank(_ExamRow r) => !r.submitted ? 2 : (r.score == null ? 0 : 1);
      final byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) {
        return byRank;
      }
      return (b.score ?? 0).compareTo(a.score ?? 0);
    });
  return [
    for (final row in rows)
      if (scoreStatus.isEmpty ||
          cbInt(scoreStatus) == (row.score == null ? 0 : 1))
        () {
          final paper = row.submitted
              ? cbUrl(
                  DemoMarkingData.paperRef(
                    def.subjectName,
                    row.person.index,
                    exam.examId,
                  ),
                )
              : '';
          return <String, dynamic>{
            'studentId': row.person.archiveId,
            'userId': cbStudentUserId(row.person),
            'no': cbStudentNo(row.person),
            'realname': row.person.name,
            'headUrl': cbUrl(row.person.avatarRef),
            'className': cbStr(cbHomeClassOf(row.person)?['name']),
            'score': row.score,
            'scored': row.score != null,
            'scoreStatus': row.score == null ? 0 : 1,
            'path': paper,
            'submitFiles': [if (paper.isNotEmpty) paper],
            'submitTime': row.submitted ? _submitTime(exam, def) : null,
            'comment': row.comment,
            'admissionNo': row.entry.admissionNo,
          };
        }(),
  ];
}

Object? _examStudentScore(DemoRequest req) {
  final exam = _examOf(req, 'examId');
  final def = _subjectOf(exam, req);
  final p = _personOf(req, 'studentId');
  final score = cbNum(req.value('score'));
  if (score == null || score < 0 || score > def.fullScore) {
    throw DemoApiException('请输入 0–${def.fullScore.toInt()} 之间的分数');
  }
  cbSetExamScore(
    examId: exam.examId,
    subjectId: def.subjectId,
    studentId: p.archiveId,
    score: score,
    comment: req.str('comment'),
    path: cbRef(req.str('path')),
  );
  return true;
}

Object? _examStudentStat(DemoRequest req) {
  final scope = cbScope(req);
  final exam = _examOf(req, 'examId');
  final def = _subjectOf(exam, req);
  final rows = _examRows(scope, exam, def, classId: req.str('classId'));
  final scores = [
    for (final r in rows)
      if (r.score != null) r.score!,
  ];
  final submitted = rows.where((r) => r.submitted).length;
  final pass = scores.where((s) => s >= 60).length;
  final excellent = scores.where((s) => s >= 85).length;
  final avg = scores.isEmpty
      ? null
      : cbRoundTo(scores.reduce((a, b) => a + b) / scores.length, 1);
  return <String, dynamic>{
    'totalCount': rows.length,
    'attendCount': submitted,
    'submitCount': submitted,
    'unSubmitCount': rows.length - submitted,
    'scoreCount': scores.length,
    'scoredCount': scores.length,
    'unscoredCount': rows.where((r) => r.submitted && r.score == null).length,
    'avgScore': avg,
    'maxScore': scores.isEmpty ? null : scores.reduce((a, b) => a > b ? a : b),
    'minScore': scores.isEmpty ? null : scores.reduce((a, b) => a < b ? a : b),
    'passCount': pass,
    'passRate': cbPercent(pass, scores.length),
    'excellentCount': excellent,
    'excellentRate': cbPercent(excellent, scores.length),
  };
}

Object? _examStudentRemind(DemoRequest req) {
  final ids = req.listOf('studentIds');
  if (ids.isEmpty) {
    throw const DemoApiException('请选择需要提醒的学生');
  }
  return <String, dynamic>{'remindCount': ids.length};
}

Object? _examFullDetail(DemoRequest req) {
  final scope = cbScope(req);
  final exam = _examOf(req, 'id');
  final data = DemoMarkingData.instance;
  final persons = [
    for (final sid in cbVisibleStudentIds(scope))
      if (cbPerson(sid) case final p?
          when data.entryOf(p.index, exam.examId) != null)
        p,
  ]..sort((a, b) => a.index.compareTo(b.index));
  final seats = <Map<String, dynamic>>[];
  for (final def in exam.subjects) {
    final seatByCampus = <String, int>{};
    for (final p in persons) {
      final seat = (seatByCampus[p.organizationName] ?? 0) + 1;
      seatByCampus[p.organizationName] = seat;
      seats.add(<String, dynamic>{
        'studentId': p.archiveId,
        'no': cbStudentNo(p),
        'realname': p.name,
        'className': cbStr(cbHomeClassOf(p)?['name']),
        'subjectName': def.subjectName,
        'classroomName': cbClassroomName(
          cbClassroomId(p.organizationName, '考试大厅'),
        ),
        'seatNo': seat,
      });
    }
  }
  return <String, dynamic>{
    'exam': <String, dynamic>{
      'id': exam.examId,
      'name': exam.examName,
      'examDate': exam.examDate,
      'status': exam.reviewed ? 1 : 0,
      'remark': _examRemark(exam),
    },
    'seats': seats,
  };
}

// ── 作业 ──────────────────────────────────────────────────────────────

List<Map<String, dynamic>> _scopeHomework(DemoRequest req) {
  final scope = cbScope(req);
  final classId = req.str('classId');
  return [
    for (final hw in cbHomework())
      if (scope.ownsTeacher(hw['teacherUserId']) &&
          (classId.isEmpty ||
              classId == '0' ||
              cbStr(hw['classId']) == classId))
        hw,
  ];
}

Object? _homeworkSum(DemoRequest req) {
  final from = cbParseDay(req.str('beginDate'));
  final to = cbParseDay(req.str('endDate'));
  final list = [
    for (final hw in _scopeHomework(req))
      if (cbParseDay(hw['createTime']) case final created?
          when (from == null || !created.isBefore(from)) &&
              (to == null || !created.isAfter(to)))
        hw,
  ];
  var unsubmitted = 0;
  var pending = 0;
  var reviewed = 0;
  var ongoing = 0;
  final scores = <double>[];
  for (final hw in list) {
    final counts = cbHomeworkCounts(hw);
    unsubmitted += counts.unsubmitted;
    pending += counts.pending;
    reviewed += counts.reviewed;
    if (cbHomeworkStatus(hw) == 0) {
      ongoing++;
    }
    for (final r in cbRecordsOf(hw['id'])) {
      final score = cbNum(r['score']);
      if (cbInt(r['status']) == 2 && score != null) {
        scores.add(score);
      }
    }
  }
  final total = unsubmitted + pending + reviewed;
  return <String, dynamic>{
    'homeworkCount': list.length,
    'status0Count': unsubmitted,
    'status1Count': pending,
    'status2Count': reviewed,
    'completeRate': cbPercent(pending + reviewed, total),
    'avgScore': scores.isEmpty
        ? 0
        : cbRoundTo(scores.reduce((a, b) => a + b) / scores.length, 1),
    'maxScore': scores.isEmpty ? 0 : scores.reduce((a, b) => a > b ? a : b),
    'minScore': scores.isEmpty ? 0 : scores.reduce((a, b) => a < b ? a : b),
    'homeworkStatus0Count': ongoing,
    'homeworkStatus1Count': list.length - ongoing,
  };
}

Object? _homeworkList(DemoRequest req) {
  final status = cbStr(req.value('status'));
  final keyword = req.str('keyword');
  final list = [
    for (final hw in _scopeHomework(req))
      if ((keyword.isEmpty || cbStr(hw['title']).contains(keyword)) &&
          switch (status) {
            '0' => cbHomeworkStatus(hw) == 0,
            '1' => cbHomeworkStatus(hw) == 1,
            '2' => cbHomeworkCounts(hw).pending > 0,
            _ => true,
          })
        hw,
  ]..sort((a, b) => cbStr(b['createTime']).compareTo(cbStr(a['createTime'])));
  return demoPage([for (final hw in list) cbHomeworkJson(hw)], req);
}

Object? _homeworkSave(DemoRequest req) {
  final scope = cbScope(req);
  final classIds = [
    for (final id in cbStrList(req.value('classIds')))
      if (cbClass(id) != null) id,
  ];
  final title = req.str('title');
  if (title.isEmpty) {
    throw const DemoApiException('请输入作业标题');
  }
  if (classIds.isEmpty) {
    throw const DemoApiException('请选择至少一个发布班级');
  }
  final end = cbParse(req.str('endTime'));
  if (end == null) {
    throw const DemoApiException('请选择截止时间');
  }
  if (!end.isAfter(DateTime.now())) {
    throw const DemoApiException('截止时间需晚于当前时间');
  }
  final subjectId = req.intOf('subjectId', 38);
  final ids = cbCreateHomework(
    classIds: classIds,
    title: title,
    description: req.str('description'),
    endTime: cbDateTime(end),
    subjectId: subjectId,
    subjectName:
        cbSubjectNameOf(subjectId) ??
        ((scope.staff?.subject ?? '').isEmpty ? '素描' : scope.staff!.subject),
    teacherUserId: scope.userId,
    expectedExt: req.str('expectedExt', 'image'),
  );
  return <String, dynamic>{'ids': ids};
}

Map<String, dynamic> _homeworkOf(DemoRequest req) {
  final hw = cbHomeworkById(req.str('id'));
  if (hw == null) {
    throw const DemoApiException('作业不存在或已删除');
  }
  return hw;
}

Object? _homeworkDetail(DemoRequest req) =>
    cbHomeworkJson(_homeworkOf(req), withStudents: true);

Object? _homeworkDelete(DemoRequest req) {
  final hw = _homeworkOf(req);
  if (!cbScope(req).ownsTeacher(hw['teacherUserId'])) {
    throw const DemoApiException('只能删除自己布置的作业');
  }
  cbDeleteHomework(cbStr(hw['id']));
  return true;
}

Map<String, dynamic> _recordOf(DemoRequest req) {
  final record = cbRecordById(req.str('id'));
  if (record == null) {
    throw const DemoApiException('学生作业记录不存在');
  }
  return record;
}

Object? _homeworkCorrect(DemoRequest req) {
  final record = _recordOf(req);
  final score = req.intOf('score', -1);
  if (score < 0 || score > 100) {
    throw const DemoApiException('请输入有效分数（0-100）');
  }
  record['status'] = 2;
  record['score'] = score;
  record['feedback'] = req.str('feedback');
  record['teacherParam1'] = cbRef(req.str('teacherParam1'));
  record['teacherParam2'] = req.str('teacherParam2');
  record['teacherParam3'] = req.str('teacherParam3');
  record['correctTime'] = cbDateTime(DateTime.now());
  cbSaveHomework();
  return true;
}

Object? _studentHomeworkDetail(DemoRequest req) {
  final record = _recordOf(req);
  final hw = cbHomeworkById(record['homeworkId']) ?? const <String, dynamic>{};
  return <String, dynamic>{
    'homeworkStudent': cbRecordJson(record, hw),
    'homework': cbHomeworkJson(hw),
  };
}

// ── 我的请假 ──────────────────────────────────────────────────────────

Object? _leaveList(DemoRequest req) {
  final scope = cbScope(req);
  final status = cbStr(req.value('status'));
  final rows = [
    for (final m in cbTeacherLeaves())
      if (cbStr(m['teacherUserId']) == scope.userId &&
          (status.isEmpty || cbInt(m['status']) == cbInt(status)))
        m,
  ]..sort((a, b) => cbStr(b['createTime']).compareTo(cbStr(a['createTime'])));
  return demoPage([for (final m in rows) cbTeacherLeaveJson(m)], req);
}

Object? _leaveSave(DemoRequest req) {
  final scope = cbScope(req);
  final start = cbParse(req.str('startTime'));
  final end = cbParse(req.str('endTime'));
  if (start == null || end == null) {
    throw const DemoApiException('请选择请假起止时间');
  }
  if (!end.isAfter(start)) {
    throw const DemoApiException('结束时间需晚于开始时间');
  }
  final reason = req.str('leaveReason');
  if (reason.isEmpty) {
    throw const DemoApiException('请填写请假原因');
  }
  cbTeacherLeaves().add(<String, dynamic>{
    'id': DemoStore.nextId(),
    'teacherUserId': scope.userId,
    'type': req.intOf('type', 1),
    'startTime': cbDateTime(start),
    'endTime': cbDateTime(end),
    'leaveDuration': req.str('leaveDuration'),
    'leaveReason': reason,
    'shiftHandover': req.str('shiftHandover'),
    'status': 0,
    'auditReason': '',
    'auditTime': null,
    'createTime': cbDateTime(DateTime.now()),
  });
  cbSaveTeacherLeaves();
  return true;
}

Object? _leaveDetail(DemoRequest req) {
  final id = req.str('id');
  for (final m in cbTeacherLeaves()) {
    if (cbStr(m['id']) == id) {
      return cbTeacherLeaveJson(m);
    }
  }
  throw const DemoApiException('请假记录不存在');
}
