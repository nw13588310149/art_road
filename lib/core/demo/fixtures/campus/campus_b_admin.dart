/// 智慧校园 · 管理员（教务）端演示接口（`/app/school/v2/manager/*`）。
library;

import '../../data/demo_campus_data.dart';
import '../../data/demo_marking_data.dart';
import '../../demo_backend.dart';
import '../../demo_store.dart';
import '../interaction_circle.dart' show circlePendingReportCount;
import 'campus_b_common.dart';
import 'campus_b_courses.dart';
import 'campus_b_people.dart';
import 'campus_b_records.dart';

const String _base = '/app/school/v2/manager';

void registerCampusBAdmin(DemoRouter r) {
  r.post('$_base/indexSum', _indexSum);
  r.post('$_base/websocketLoginCount', _loginCount);
  r.post('$_base/workReminders', _workReminders);

  r.post('$_base/campusList', _campusList);
  r.post('$_base/classList', _classList);
  r.post('$_base/classSum', _classSum);
  r.post('$_base/classDetail', _classDetail);
  r.post('$_base/classroomList', (req) => cbClassroomList());
  r.post('$_base/classSave', _classSave);
  r.post('$_base/classUpdate', _classUpdate);

  r.post('$_base/studentList', _studentList);
  r.post('$_base/studentDetail', _studentDetail);
  r.post('$_base/studentExamRecordList', _studentExamRecords);
  r.post('$_base/studentSum', _studentSum);
  r.post('$_base/teacherList', _teacherList);
  r.post('$_base/teacherDetail', _teacherDetail);
  r.post('$_base/teacherSum', _teacherSum);

  r.post('$_base/courseList', _courseList);
  r.post('$_base/courseBatchSave', _courseBatchSave);
  r.post('$_base/courseDelete', _courseDelete);
  r.post('$_base/schoolSmallCourseApplyList', _applyList);
  r.post('$_base/schoolSmallCourseApplyDetail', _applyDetail);
  r.post('$_base/schoolSmallCourseApplyAudit', _applyAudit);

  r.post('$_base/schoolUserFaceList', _faceList);
  r.post('$_base/schoolUserFaceSum', _faceSum);
  r.post('$_base/schoolUserFaceDetail', _faceDetail);
  r.post('$_base/schoolUserFaceAudit', _faceAudit);
  r.post('$_base/schoolUserFaceSubmit', _faceSubmit);

  r.post('$_base/courseSignManager', _signManager);
  r.post('$_base/courseSignSum0', (req) => _signSum(req, 0));
  r.post('$_base/courseSignSum1', (req) => _signSum(req, 1));
  r.post('$_base/courseSignUpdateSignStatus', _signUpdate);
  r.post('$_base/courseCommentList', _commentList);
  r.post('$_base/courseSignConfirm', _signConfirm);
  r.post('$_base/courseSignMakeupList', _makeupList);
  r.post('$_base/courseSignMakeupDetail', _makeupDetail);
  r.post('$_base/courseSignMakeupAudit', _makeupAudit);

  r.post('$_base/teacherLeaveList', _leaveList);
  r.post('$_base/teacherLeaveDetail', _leaveDetail);
  r.post('$_base/teacherLeaveAudit', _leaveAudit);

  r.post('$_base/noticeManageList', _noticeList);
  r.post('$_base/noticeSave', _noticeSave);
  r.post('$_base/noticeDetail', _noticeDetail);
  r.post('$_base/noticeDelete', _noticeDelete);
}

// ── 首页 ──────────────────────────────────────────────────────────────

int _pendingApplies() =>
    cbApplies().where((a) => cbInt(a['status']) == 0).length;

int _pendingTeacherLeaves() =>
    cbTeacherLeaves().where((m) => cbInt(m['status']) == 0).length;

int _pendingFaces() => cbFaces().where((f) => cbInt(f['status']) == 0).length;

int _pendingSignMakeups() =>
    cbSignMakeups().where((m) => cbInt(m['status']) == 0).length;

/// 近一周等待教务确认的小课（学生已评价）。
List<CbCourse> _smallCoursesAwaitingConfirm() => [
  for (final c in cbCoursesBetween(cbAddDays(cbToday(), -6), cbToday()))
    if (c.isSmall && cbSignStatus(c) == 5) c,
];

int get _teacherCount =>
    DemoCampusData.staff.where((s) => s.subject.isNotEmpty).length;

Object? _indexSum(DemoRequest req) {
  final awaiting = _smallCoursesAwaitingConfirm().length;
  final leaves = _pendingTeacherLeaves();
  final applies = _pendingApplies();
  final faces = _pendingFaces();
  final makeups = _pendingSignMakeups();
  return <String, dynamic>{
    'studentCount': cbPersons.where(cbIsActive).length,
    'teacherCount': _teacherCount,
    'classCount': cbClasses().where((c) => !cbIsSmallClass(c)).length,
    'leaveStatus0Count': leaves,
    'postStatus0Count': circlePendingReportCount(),
    'smallCourseSignStatus5Count': awaiting,
    'userFaceNotRecordedCount': cbFaceMissingCount(),
    'toDoTodayCount': leaves + applies + faces + makeups + awaiting,
  };
}

/// 近七日使用人数：只统计已经过完的日子（截至昨天），人数不超过在籍学生 + 教职工。
Object? _loginCount(DemoRequest req) {
  var to = cbParseDay(req.str('endDate')) ?? cbToday();
  var from = cbParseDay(req.str('startDate')) ?? cbAddDays(to, -6);
  final yesterday = cbAddDays(cbToday(), -1);
  if (to.isAfter(yesterday)) {
    final shift = to.difference(yesterday).inDays;
    to = cbAddDays(to, -shift);
    from = cbAddDays(from, -shift);
  }
  if (to.difference(from).inDays > 62) {
    from = cbAddDays(to, -62);
  }
  final total = cbPersons.where(cbIsActive).length + _teacherCount;
  final result = <Map<String, dynamic>>[];
  for (var day = from; !day.isAfter(to); day = cbAddDays(day, 1)) {
    final weekend = day.weekday >= 6;
    final base = weekend ? (total * 0.6).round() : total - 2;
    final count = (base - cbHash('login|${cbDate(day)}') % 6).clamp(1, total);
    result.add(<String, dynamic>{'loginDate': cbDate(day), 'count': count});
  }
  return result;
}

Object? _workReminders(DemoRequest req) {
  final reminders = <Map<String, dynamic>>[];
  final leaves = [
    for (final m in cbTeacherLeaves())
      if (cbInt(m['status']) == 0) m,
  ]..sort((a, b) => cbStr(a['startTime']).compareTo(cbStr(b['startTime'])));
  if (leaves.isNotEmpty) {
    final first = leaves.first;
    reminders.add(<String, dynamic>{
      'tag': '审批',
      'title': '${leaves.length} 条教职工请假待审批',
      'subtitle':
          '最早一条：${cbStaffName(first['teacherUserId'])} '
          '${cbStr(first['startTime']).substring(5, 16)} 起，${cbStr(first['leaveReason'])}',
    });
  }
  final yesterday = cbAddDays(cbToday(), -1);
  for (final c in cbClasses()) {
    if (cbIsSmallClass(c)) {
      continue;
    }
    final absent = <String>[];
    for (final sid in cbActiveStudents(c['id'])) {
      final p = cbPerson(sid);
      final check = p == null ? null : cbDormCheck(p, yesterday, 1);
      if (check != null && check.status == '未打卡') {
        absent.add(p!.name);
      }
    }
    if (absent.isNotEmpty) {
      reminders.add(<String, dynamic>{
        'tag': '预警',
        'title': '${cbStr(c['name'])} · 昨晚查寝 ${absent.length} 人未打卡',
        'subtitle': '${absent.join('、')}未打卡，宿管已登记，待班主任确认是否转晚归备案。',
      });
    }
  }
  final applies = _pendingApplies();
  if (applies > 0) {
    reminders.add(<String, dynamic>{
      'tag': '排课',
      'title': '$applies 条小课申请待审核',
      'subtitle': '请在「排课与课表 · 小课申请审核」中处理，通过后自动写入课表。',
    });
  }
  final awaiting = _smallCoursesAwaitingConfirm();
  if (awaiting.isNotEmpty) {
    reminders.add(<String, dynamic>{
      'tag': '签课',
      'title': '${awaiting.length} 节小课待教务确认',
      'subtitle': '学生已完成课后评价，确认后计入老师课时。',
    });
  }
  final faces = _pendingFaces();
  final missing = cbFaceMissingCount();
  if (faces > 0 || missing > 0) {
    reminders.add(<String, dynamic>{
      'tag': '人脸',
      'title': '$faces 条人脸录入待审核',
      'subtitle': '另有 $missing 名在籍学生尚未录入人脸，会影响查寝刷脸打卡。',
    });
  }
  final reports = circlePendingReportCount();
  if (reports > 0) {
    reminders.add(<String, dynamic>{
      'tag': '校圈',
      'title': '$reports 条校圈举报待处理',
      'subtitle': '在「校圈治理 · 待处理」中查看举报原因，保留或删除。',
    });
  }
  final reviewing = DemoMarkingData.instance.exams.where((e) => !e.reviewed);
  for (final exam in reviewing) {
    reminders.add(<String, dynamic>{
      'tag': '考试',
      'title': '${exam.examName}阅卷进行中',
      'subtitle': '素描、色彩、速写三科正在评阅，完成后成绩同步到学情中心。',
    });
  }
  return reminders;
}

// ── 班级 ──────────────────────────────────────────────────────────────

Object? _campusList(DemoRequest req) => [
  for (var i = 0; i < cbCampusNames.length; i++)
    <String, dynamic>{
      'id': i + 1,
      'name': cbCampusNames[i],
      'address': const ['兰州市城关区东岗西路', '兰州市七里河区西津西路', '兰州市安宁区安宁西路'][i],
    },
];

Object? _classList(DemoRequest req) {
  final type = cbStr(req.value('type')).isEmpty ? null : req.intOf('type');
  final onlyHead = req.intOf('isHeadTeacher') == 1;
  return [
    for (final c in cbClasses())
      if ((type == null || cbInt(c['type']) == type) &&
          (!onlyHead || cbStr(c['headTeacherId'], '0') != '0'))
        cbClassJson(c),
  ];
}

Object? _classSum(DemoRequest req) {
  final classes = cbClasses();
  final assigned = <String>{
    for (final c in classes)
      if (!cbIsSmallClass(c)) ...cbStrList(c['studentIds']),
  };
  final active = cbPersons.where(cbIsActive).toList();
  return <String, dynamic>{
    'bigClassCount': classes.where((c) => !cbIsSmallClass(c)).length,
    'smallClassCount': classes.where(cbIsSmallClass).length,
    'studentCount': active.length,
    'teacherCount': _teacherCount,
    'unassignedStudentCount': active
        .where((p) => !assigned.contains(p.archiveId))
        .length,
  };
}

Map<String, dynamic> _classOf(Object? rawId) {
  final cls = cbClass(rawId);
  if (cls == null) {
    throw const DemoApiException('班级不存在');
  }
  return cls;
}

Object? _classDetail(DemoRequest req) {
  final cls = _classOf(req.str('classId', req.str('id')));
  return <String, dynamic>{
    ...cbClassJson(cls),
    'students': [
      for (final sid in cbStrList(cls['studentIds']))
        if (cbPerson(sid) case final p?) cbStudentRow(p),
    ],
    'teachers': [
      for (final uid in cbClassTeacherIds(cls))
        if (cbStaff(uid) case final s?) _teacherRow(s),
    ],
  };
}

/// 调入行政班的学生从原行政班移出，并记录调班信息。
void _moveIntoBigClass(String classId, List<String> studentIds) {
  final targetName = cbClassName(classId);
  final today = cbDate(DateTime.now());
  for (final c in cbClasses()) {
    if (cbIsSmallClass(c) || cbStr(c['id']) == classId) {
      continue;
    }
    final members = cbStrList(c['studentIds']);
    final moved = members.where(studentIds.contains).toList();
    if (moved.isEmpty) {
      continue;
    }
    c['studentIds'] = members.where((id) => !moved.contains(id)).toList();
    for (final sid in moved) {
      cbUpdateProfile(sid, <String, dynamic>{
        'lastChange': '$today 由${cbStr(c['name'])}调入$targetName',
      });
    }
  }
}

List<String> _studentIdsOf(DemoRequest req) => [
  for (final raw in req.listOf('studentIds'))
    if (cbPerson(raw) case final p?) p.archiveId,
];

String _staffUserId(Object? raw) {
  final id = cbStr(raw);
  if (id.isEmpty || id == '0') {
    return '0';
  }
  return cbStaff(id)?.userId ?? '0';
}

Object? _classSave(DemoRequest req) {
  final name = req.str('name');
  if (name.isEmpty) {
    throw const DemoApiException('请填写班级名称');
  }
  if (cbClasses().any((c) => cbStr(c['name']) == name)) {
    throw const DemoApiException('班级名称已存在');
  }
  final type = req.intOf('type') == 1 ? 1 : 0;
  final campusId = req.intOf('campusId', 1).clamp(1, cbCampusNames.length);
  final id = DemoStore.nextId();
  final studentIds = _studentIdsOf(req);
  if (type == 0) {
    _moveIntoBigClass(id, studentIds);
  }
  final teacherIds = [
    for (final uid in cbCsv(req.value('teacherIds')))
      if (cbStaff(uid) case final s?) s.userId,
  ];
  cbClasses().add(<String, dynamic>{
    'id': id,
    'name': name,
    'groupName': name,
    'type': type,
    'classCode': req.str('classCode'),
    'grade': '2027 届',
    'campusId': campusId,
    'campusName': cbCampusNameOf(campusId),
    'headTeacherId': type == 0 ? _staffUserId(req.value('headTeacherId')) : '0',
    'classroomId': req.intOf('classroomId'),
    'teacherIds': teacherIds.join(','),
    'studentIds': studentIds,
    'logo': type == 0
        ? 'asset:assets/demo/art/sketch-still-2.jpg'
        : 'asset:assets/demo/art/color-flower-1.jpg',
    'announcement': '',
    'mute': 0,
    'createTime': cbDateTime(DateTime.now()),
  });
  cbSaveClasses();
  return <String, dynamic>{'id': id};
}

Object? _classUpdate(DemoRequest req) {
  final cls = _classOf(req.str('id'));
  final body = req.bodyMap;
  final name = req.str('name');
  if (body.containsKey('name') && name.isNotEmpty) {
    if (cbClasses().any(
      (c) => cbStr(c['name']) == name && cbStr(c['id']) != cbStr(cls['id']),
    )) {
      throw const DemoApiException('班级名称已存在');
    }
    cls['name'] = name;
    if (cbStr(cls['groupName']).isEmpty) {
      cls['groupName'] = name;
    }
  }
  if (body.containsKey('classCode')) {
    cls['classCode'] = req.str('classCode');
  }
  if (body.containsKey('campusId') && req.intOf('campusId') > 0) {
    cls['campusId'] = req.intOf('campusId');
    cls['campusName'] = cbCampusNameOf(req.intOf('campusId'));
  }
  if (body.containsKey('headTeacherId') && !cbIsSmallClass(cls)) {
    cls['headTeacherId'] = _staffUserId(req.value('headTeacherId'));
  }
  if (body.containsKey('classroomId')) {
    cls['classroomId'] = req.intOf('classroomId');
  }
  if (body.containsKey('teacherIds')) {
    cls['teacherIds'] = [
      for (final uid in cbCsv(req.value('teacherIds')))
        if (cbStaff(uid) case final s?) s.userId,
    ].join(',');
  }
  if (body.containsKey('studentIds')) {
    final studentIds = _studentIdsOf(req);
    if (!cbIsSmallClass(cls)) {
      _moveIntoBigClass(cbStr(cls['id']), studentIds);
    }
    cls['studentIds'] = studentIds;
  }
  cbSaveClasses();
  return true;
}

// ── 学生与教师 ────────────────────────────────────────────────────────

bool _matches(DemoPerson p, String keyword) {
  final key = keyword.trim();
  if (key.isEmpty) {
    return true;
  }
  final parent = cbParentsOf(p).first;
  return p.name.contains(key) ||
      cbStudentNo(p).contains(key) ||
      p.phone.contains(key) ||
      cbBedInfo(p).contains(key) ||
      (parent['name'] ?? '').contains(key) ||
      (parent['mobile'] ?? '').contains(key);
}

Object? _studentList(DemoRequest req) {
  final classId = req.str('classId');
  final status = req.str('studentStatus');
  final keyword = req.str('keyword');
  final persons = classId.isEmpty
      ? cbPersons
      : [
          for (final sid in cbStrList(_classOf(classId)['studentIds']))
            ?cbPerson(sid),
        ];
  final rows = [
    for (final p in persons)
      if ((status.isEmpty || cbStudentStatus(p) == status) &&
          _matches(p, keyword))
        cbStudentRow(p),
  ];
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

Object? _studentSum(DemoRequest req) {
  final active = cbPersons.where(cbIsActive).toList();
  return <String, dynamic>{
    'normalCount': active.length,
    'residentCount': active.where((p) => cbBedInfo(p).isNotEmpty).length,
    'abnormalCount': cbPersons.length - active.length,
    'totalCount': cbPersons.length,
  };
}

/// 教职工简介，与学生端 / 群聊里看到的老师资料一致。
const Map<String, String> _staffIntro = {
  't-1': '中央美术学院造型专业毕业，主讲联考素描，擅长石膏像与头像结构训练，带班 8 年。',
  't-2': '西安美术学院油画系毕业，主讲素描静物与五官局部，注重明暗体系梳理。',
  't-3': '中国美术学院毕业，主讲色彩静物与风景写生，所带学生色彩高分率突出。',
  't-4': '西安美术学院毕业，联考冲刺1班班主任，主讲人物速写与默写训练。',
  't-5': '四川美术学院毕业，联考冲刺2班班主任，主讲色彩，擅长冷暖关系分析。',
  't-6': '鲁迅美术学院毕业，校考提高班班主任，主讲速写与创作构图。',
  't-7': '美术史论方向研究生，负责美术常识、艺术概论与校考面试指导。',
  't-8': '负责语文、英语文化课辅导，帮助学生兼顾专业与文化成绩。',
  't-9': '教务主管，统筹排课、考务安排与家校沟通。',
  'd-1': '宿舍管理老师，负责两栋学生公寓的查寝、安全巡查与生活服务。',
};

String _staffSubject(DemoCampusStaff s) {
  if (s.subject.isNotEmpty) {
    return s.subject;
  }
  return s.roles.contains('dormManager') ? '宿舍管理' : '教务管理';
}

String _staffDept(DemoCampusStaff s) {
  if (s.subject.isNotEmpty) {
    return '${s.subject}教研组';
  }
  return s.roles.contains('dormManager') ? '后勤处' : '教务处';
}

Map<String, dynamic> _teacherRow(DemoCampusStaff s) {
  final face = cbLatestFace(s.userId);
  final classes = [
    for (final c in cbClasses())
      if (cbClassTeacherIds(c).contains(s.userId) ||
          cbStr(c['headTeacherId']) == s.userId)
        cbStr(c['name']),
  ];
  final headOf = [
    for (final c in cbClasses())
      if (cbStr(c['headTeacherId']) == s.userId) cbStr(c['name']),
  ];
  final onLeave = cbStaffOnLeave(s.userId);
  return <String, dynamic>{
    'id': s.userId,
    'userId': s.userId,
    'teacherId': s.userId,
    'realname': s.name,
    'nickname': s.name,
    'name': s.name,
    'no': cbStaffNo(s),
    'workNo': cbStaffNo(s),
    'gender': s.gender,
    'mobile': s.phone,
    'phone': s.phone,
    'headUrl': '',
    'subject': _staffSubject(s),
    'subjectName': _staffSubject(s),
    'dept': _staffDept(s),
    'schoolCampusName': s.organizationName,
    'campusName': s.organizationName,
    'roles': cbStaffRoles(s),
    'teacherStatus': onLeave ? '请假' : '在岗',
    'introduce': _staffIntro[s.id] ?? '',
    'classNames': classes.join('、'),
    'headClassNames': headOf.join('、'),
    'remark': onLeave ? '今日请假，课程已安排代课。' : '',
    'faceImg': face == null ? '' : cbUrl(cbStr(face['faceImg'])),
    'entryDate': '20${20 + DemoCampusData.staff.indexOf(s) % 5}-08-20',
  };
}

Object? _teacherList(DemoRequest req) {
  final classId = req.str('classId');
  final keyword = req.str('keyword');
  final cls = classId.isEmpty ? null : _classOf(classId);
  final members = cls == null
      ? null
      : {...cbClassTeacherIds(cls), cbStr(cls['headTeacherId'])};
  final rows = [
    for (final s in DemoCampusData.staff)
      if ((members == null || members.contains(s.userId)) &&
          (keyword.isEmpty ||
              s.name.contains(keyword) ||
              cbStaffNo(s).contains(keyword) ||
              _staffSubject(s).contains(keyword)))
        _teacherRow(s),
  ];
  return demoPage(rows, req);
}

Object? _teacherDetail(DemoRequest req) {
  final s = cbStaff(req.str('id'));
  if (s == null) {
    throw const DemoApiException('教师不存在');
  }
  final row = _teacherRow(s);
  return <String, dynamic>{
    ...row,
    'user': <String, dynamic>{
      'id': s.userId,
      'realname': s.name,
      'nickname': s.name,
      'headUrl': '',
      'introduce': row['introduce'],
      'gender': s.gender,
      'mobile': s.phone,
      'remark': row['remark'],
    },
    'schoolTeacher': <String, dynamic>{
      'no': row['no'],
      'roles': row['roles'],
      'teacherStatus': row['teacherStatus'],
      'remark': row['remark'],
      'gender': s.gender,
      'entryDate': row['entryDate'],
    },
    'schoolCampus': <String, dynamic>{
      'id': cbCampusIdOf(s.organizationName),
      'name': s.organizationName,
    },
  };
}

Object? _teacherSum(DemoRequest req) {
  final staff = DemoCampusData.staff;
  final heads = <String>{
    for (final c in cbClasses())
      if (!cbIsSmallClass(c) && cbStr(c['headTeacherId'], '0') != '0')
        cbStr(c['headTeacherId']),
  };
  final onLeave = staff.where((s) => cbStaffOnLeave(s.userId)).length;
  return <String, dynamic>{
    'headTeacherCount': heads.length,
    'onDutyCount': staff.length - onLeave,
    'onLeaveCount': onLeave,
    'totalCount': staff.length,
  };
}

// ── 课表与小课申请 ────────────────────────────────────────────────────

Object? _courseList(DemoRequest req) {
  final today = cbToday();
  final monday = cbAddDays(today, 1 - today.weekday);
  final to = cbParseDay(req.str('endDate')) ?? cbAddDays(monday, 6);
  var from = cbParseDay(req.str('beginDate')) ?? monday;
  if (to.difference(from).inDays > 62) {
    from = cbAddDays(to, -62);
  }
  final classIds = <String>{
    if (req.str('classId').isNotEmpty) req.str('classId'),
    for (final id in req.listOf('classIdList')) cbStr(id),
  }..remove('');
  final teacherId = req.str('teacherId');
  final type = cbStr(req.value('type')).isEmpty ? null : req.intOf('type');
  return cbCourseRowsByDate([
    for (final c in cbCoursesBetween(from, to))
      if ((classIds.isEmpty || classIds.contains(c.classId)) &&
          (teacherId.isEmpty || c.teacherUserId == teacherId) &&
          (type == null || c.type == type))
        c,
  ]);
}

Object? _courseBatchSave(DemoRequest req) {
  final rows = cbBodyRows(req);
  if (rows.isEmpty) {
    throw const DemoApiException('没有需要保存的课程');
  }
  final extras = cbExtraCourses();
  for (final row in rows) {
    final cls = _classOf(row['classId']);
    final day = cbParseDay(row['date']);
    if (day == null) {
      throw const DemoApiException('上课日期格式不正确');
    }
    final subjectId = cbInt(row['subjectId'], 38);
    final subjectName = cbSubjectNameOf(subjectId) ?? '素描';
    extras.add(<String, dynamic>{
      'id': DemoStore.nextId(),
      'date': cbDate(day),
      'classId': cbStr(cls['id']),
      'classroomId': cbInt(row['classroomId'], cbInt(cls['classroomId'], 11)),
      'color': cbStr(row['color'], cbCourseColor(subjectName)),
      'lineNum': cbInt(row['lineNum'], 1),
      'subjectId': subjectId,
      'subjectName': subjectName,
      'teacherId': cbStaff(row['teacherId'])?.userId ?? cbStr(row['teacherId']),
      'type': cbIsSmallClass(cls) ? 1 : 0,
    });
  }
  DemoStore.save(cbExtraCoursesKey);
  return true;
}

Object? _courseDelete(DemoRequest req) {
  final ids = [
    for (final raw in req.listOf('id'))
      if (cbStr(raw).isNotEmpty) cbStr(raw),
  ];
  if (ids.isEmpty) {
    throw const DemoApiException('缺少有效的课程 id');
  }
  cbDeleteCourses(ids);
  return true;
}

Object? _applyList(DemoRequest req) {
  final status = cbStr(req.value('status'));
  final classId = req.str('classId');
  final teacherId = req.str('teacherId');
  final rows = [
    for (final a in cbApplies())
      if ((status.isEmpty || cbInt(a['status']) == cbInt(status)) &&
          (classId.isEmpty || cbStr(a['classId']) == classId) &&
          (teacherId.isEmpty || cbStr(a['teacherId']) == teacherId))
        a,
  ]..sort((a, b) => cbStr(b['createTime']).compareTo(cbStr(a['createTime'])));
  return demoPage([for (final a in rows) cbApplyJson(a)], req);
}

Map<String, dynamic> _applyOf(DemoRequest req) {
  final id = req.str('id');
  for (final a in cbApplies()) {
    if (cbStr(a['id']) == id) {
      return a;
    }
  }
  throw const DemoApiException('申请记录不存在');
}

Object? _applyDetail(DemoRequest req) => cbApplyJson(_applyOf(req));

Object? _applyAudit(DemoRequest req) {
  final apply = _applyOf(req);
  if (cbInt(apply['status']) != 0) {
    throw const DemoApiException('该申请已审核');
  }
  final status = req.intOf('status');
  final reason = req.str('reason');
  if (status == 2 && reason.isEmpty) {
    throw const DemoApiException('请填写驳回理由');
  }
  apply['status'] = status == 1 ? 1 : 2;
  apply['reason'] = status == 1
      ? (reason.isEmpty ? '审核通过，已写入课表' : reason)
      : reason;
  apply['auditTime'] = cbDateTime(DateTime.now());
  apply['auditTeacherId'] = cbScope(req).userId;
  cbSaveApplies();
  return true;
}

// ── 人脸库 ────────────────────────────────────────────────────────────

Object? _faceList(DemoRequest req) {
  final status = cbStr(req.value('status'));
  final keyword = req.str('keyword');
  final rows =
      [
          for (final f in cbFaces())
            if (status.isEmpty || cbInt(f['status']) == cbInt(status))
              cbFaceJson(f),
        ].where((row) {
          if (keyword.isEmpty) {
            return true;
          }
          return cbStr(row['realname']).contains(keyword) ||
              cbStr(row['no']).contains(keyword) ||
              cbStr(row['className']).contains(keyword);
        }).toList()
        ..sort(
          (a, b) => cbStr(b['updateTime']).compareTo(cbStr(a['updateTime'])),
        );
  return demoPage(rows, req);
}

Object? _faceSum(DemoRequest req) {
  final faces = cbFaces();
  return <String, dynamic>{
    'status0Count': faces.where((f) => cbInt(f['status']) == 0).length,
    'status1Count': faces.where((f) => cbInt(f['status']) == 1).length,
    'status2Count': faces.where((f) => cbInt(f['status']) == 2).length,
    'userFaceNotRecordedCount': cbFaceMissingCount(),
  };
}

Map<String, dynamic> _faceOf(DemoRequest req) {
  final id = req.str('id');
  for (final f in cbFaces()) {
    if (cbStr(f['id']) == id) {
      return f;
    }
  }
  throw const DemoApiException('人脸记录不存在');
}

Object? _faceDetail(DemoRequest req) => cbFaceJson(_faceOf(req));

Object? _faceAudit(DemoRequest req) {
  final face = _faceOf(req);
  final status = req.intOf('status');
  if (status != 1 && status != 2) {
    throw const DemoApiException('审核状态不正确');
  }
  final reason = req.str('reason');
  if (status == 2 && reason.isEmpty) {
    throw const DemoApiException('请填写驳回原因');
  }
  face['status'] = status;
  face['reason'] = status == 1 ? '通过' : reason;
  face['auditTime'] = cbDateTime(DateTime.now());
  face['auditUserName'] = cbScope(req).name;
  cbSaveFaces();
  return true;
}

Object? _faceSubmit(DemoRequest req) {
  final faceImg = cbRef(req.str('faceImg'));
  if (faceImg.isEmpty) {
    throw const DemoApiException('请先上传人脸照片');
  }
  final rawUser = req.str('userId');
  final student = cbPerson(rawUser);
  final staff = student == null ? cbStaff(rawUser) : null;
  if (student == null && staff == null) {
    throw const DemoApiException('人员不存在');
  }
  final userId = student != null ? cbStudentUserId(student) : staff!.userId;
  final now = cbDateTime(DateTime.now());
  final faces = cbFaces();
  final existing = faces.where((f) => cbStr(f['userId']) == userId).firstOrNull;
  final record = existing ?? <String, dynamic>{'id': DemoStore.nextId()};
  record
    ..['userId'] = userId
    ..['userType'] = student != null ? 'student' : 'teacher'
    ..['faceImg'] = faceImg
    ..['status'] = 0
    ..['reason'] = ''
    ..['createTime'] = record['createTime'] ?? now
    ..['updateTime'] = now
    ..['auditTime'] = null
    ..['auditUserName'] = null;
  if (existing == null) {
    faces.add(record);
  }
  cbSaveFaces();
  return true;
}

// ── 签课管理 ──────────────────────────────────────────────────────────

List<CbCourse> _signCourses(DemoRequest req, int type) {
  final day = cbParseDay(req.str('date')) ?? cbToday();
  final classId = req.str('classId');
  return [
    for (final c in cbCoursesOn(day))
      if (c.type == type && (classId.isEmpty || c.classId == classId)) c,
  ];
}

Object? _signManager(DemoRequest req) => [
  for (final c in _signCourses(req, req.intOf('type'))) cbSessionJson(c),
];

Object? _signSum(DemoRequest req, int type) {
  final courses = _signCourses(req, type);
  var signed = 0;
  var studentSigned = 0;
  var studentShould = 0;
  var completed = 0;
  var pendingAdmin = 0;
  var inProgress = 0;
  for (final c in courses) {
    final sign = cbSignOf(c);
    final status = cbInt(sign['signStatus']);
    final counts = cbSignCounts(c, sign);
    studentShould += cbCourseStudents(c).length;
    studentSigned += counts.present + counts.late;
    if (status >= 2) {
      signed++;
    }
    if (status == 6) {
      completed++;
    } else if (status == 5) {
      pendingAdmin++;
    } else if (status >= 1 && status <= 4) {
      inProgress++;
    }
  }
  return <String, dynamic>{
    'courseCount': courses.length,
    'signedCourseCount': signed,
    'studentSignCount': studentSigned,
    'studentShouldSignCount': studentShould,
    'makeupPendingCount': _pendingSignMakeups(),
    'inProgressCount': inProgress,
    'pendingAdminCount': pendingAdmin,
    'completedCount': type == 0 ? signed : completed,
  };
}

CbCourse _courseOf(DemoRequest req) {
  final course = cbCourseById(req.str('courseId'));
  if (course == null) {
    throw const DemoApiException('课次不存在或已被删除');
  }
  return course;
}

Object? _signUpdate(DemoRequest req) {
  final course = _courseOf(req);
  final studentId = cbPerson(req.str('studentId'))?.archiveId ?? '';
  if (!cbCourseStudents(course).contains(studentId)) {
    throw const DemoApiException('该学生不在本节课名单中');
  }
  final status = req.intOf('status', -1);
  if (status < 0 || status > 3) {
    throw const DemoApiException('签到状态不正确');
  }
  cbSetStudentSign(course, studentId, status, remark: '教务老师调整');
  return true;
}

Object? _commentList(DemoRequest req) {
  final course = _courseOf(req);
  final rows = <Map<String, dynamic>>[];
  for (final row in cbSignStudentRows(course, cbSignOf(course))) {
    if (row['score'] == null && cbStr(row['comment']).isEmpty) {
      continue;
    }
    rows.add(<String, dynamic>{
      'studentId': row['studentId'],
      'student': <String, dynamic>{
        'realname': row['realname'],
        'nickname': row['nickname'],
        'headUrl': row['headUrl'],
        'no': row['no'],
      },
      'score': row['score'],
      'comment': row['comment'],
      'createTime': row['signOutTime'],
    });
  }
  return rows;
}

Object? _signConfirm(DemoRequest req) {
  final course = _courseOf(req);
  final sign = cbSignOf(course);
  final current = cbInt(sign['signStatus']);
  if (current == 6) {
    throw const DemoApiException('该课程已确认完成');
  }
  if (current < 5) {
    throw const DemoApiException('学生尚未完成课后评价，暂不能确认');
  }
  final status = req.intOf('signStatus', 6) == 7 ? 7 : 6;
  sign['signStatus'] = status;
  sign['confirmRemark'] = req.str('remark');
  sign['confirmTime'] = cbDateTime(DateTime.now());
  cbSaveSign(course, sign);
  return true;
}

Object? _makeupList(DemoRequest req) {
  final status = cbStr(req.value('status'));
  final rows = [
    for (final m in cbSignMakeups())
      if (status.isEmpty || cbInt(m['status']) == cbInt(status)) m,
  ]..sort((a, b) => cbStr(b['createTime']).compareTo(cbStr(a['createTime'])));
  return demoPage([for (final m in rows) cbSignMakeupJson(m)], req);
}

Map<String, dynamic> _makeupOf(DemoRequest req) {
  final id = req.str('id');
  for (final m in cbSignMakeups()) {
    if (cbStr(m['id']) == id) {
      return m;
    }
  }
  throw const DemoApiException('补签申请不存在');
}

Object? _makeupDetail(DemoRequest req) => cbSignMakeupJson(_makeupOf(req));

Object? _makeupAudit(DemoRequest req) {
  final m = _makeupOf(req);
  if (cbInt(m['status']) != 0) {
    throw const DemoApiException('该补签申请已处理');
  }
  final status = req.intOf('status');
  if (status != 1 && status != 2) {
    throw const DemoApiException('审批状态不正确');
  }
  m['status'] = status;
  m['auditReason'] = req.str(
    'auditReason',
    status == 1 ? '已与任课老师核实，同意补签。' : '经核实与课堂考勤不符，不予补签。',
  );
  m['auditTime'] = cbDateTime(DateTime.now());
  cbSaveSignMakeups();
  final course = cbCourseById(m['courseId']);
  if (status == 1 && course != null) {
    cbSetStudentSign(course, cbStr(m['studentId']), 0, remark: '补签通过');
  }
  return true;
}

// ── 教职工请假审批 ────────────────────────────────────────────────────

Object? _leaveList(DemoRequest req) {
  final status = cbStr(req.value('status'));
  final rows = [
    for (final m in cbTeacherLeaves())
      if (status.isEmpty || cbInt(m['status']) == cbInt(status)) m,
  ]..sort((a, b) => cbStr(b['createTime']).compareTo(cbStr(a['createTime'])));
  return demoPage([for (final m in rows) cbTeacherLeaveJson(m)], req);
}

Map<String, dynamic> _leaveOf(DemoRequest req) {
  final id = req.str('id');
  for (final m in cbTeacherLeaves()) {
    if (cbStr(m['id']) == id) {
      return m;
    }
  }
  throw const DemoApiException('请假记录不存在');
}

Object? _leaveDetail(DemoRequest req) => cbTeacherLeaveJson(_leaveOf(req));

Object? _leaveAudit(DemoRequest req) {
  final m = _leaveOf(req);
  if (cbInt(m['status']) != 0) {
    throw const DemoApiException('该请假申请已审批');
  }
  final status = req.intOf('status');
  if (status != 1 && status != 2) {
    throw const DemoApiException('审批状态不正确');
  }
  final reason = req.str('auditReason');
  if (status == 2 && reason.isEmpty) {
    throw const DemoApiException('请填写驳回理由');
  }
  m['status'] = status;
  m['auditReason'] = status == 1 ? (reason.isEmpty ? '同意。' : reason) : reason;
  m['auditTime'] = cbDateTime(DateTime.now());
  cbSaveTeacherLeaves();
  return true;
}

// ── 通知管理 ──────────────────────────────────────────────────────────

Object? _noticeList(DemoRequest req) {
  final status = cbStr(req.value('status'));
  final type = req.str('type');
  final rows = [
    for (final n in cbSortedNotices())
      if ((status.isEmpty || cbNoticeStatus(n) == cbInt(status)) &&
          (type.isEmpty || cbStr(n['type']) == type))
        cbNoticeJson(n),
  ];
  return demoPage(rows, req);
}

Object? _noticeSave(DemoRequest req) {
  final title = req.str('title');
  final content = req.str('content');
  if (title.isEmpty) {
    throw const DemoApiException('请填写通知标题');
  }
  if (content.isEmpty) {
    throw const DemoApiException('请填写通知内容');
  }
  final scope = req.str('pushScope');
  if (scope.isEmpty) {
    throw const DemoApiException('请选择推送范围');
  }
  final mode = req.intOf('publishMode', 1);
  final now = DateTime.now();
  DateTime? scheduled;
  if (mode == 2) {
    scheduled = cbParse(req.str('scheduledTime'));
    if (scheduled == null || !scheduled.isAfter(now)) {
      throw const DemoApiException('定时发布时间需晚于当前时间');
    }
  }
  final account = cbScope(req);
  final id = req.str('id');
  final existing = id.isEmpty
      ? null
      : cbNotices().where((n) => cbStr(n['id']) == id).firstOrNull;
  final notice = existing ?? <String, dynamic>{'id': DemoStore.nextId()};
  notice
    ..['title'] = title
    ..['content'] = content
    ..['type'] = req.str('type', '通知')
    ..['priority'] = req.str('priority', '普通')
    ..['pushScope'] = scope
    ..['status'] = mode == 2 ? 2 : 1
    ..['publishMode'] = mode == 2 ? 2 : 1
    ..['publishedAt'] = mode == 2 ? null : cbDateTime(now)
    ..['scheduledTime'] = scheduled == null ? null : cbDateTime(scheduled)
    ..['createTime'] = notice['createTime'] ?? cbDateTime(now)
    ..['updateTime'] = cbDateTime(now)
    ..['creator'] = req.str('creator', account.name)
    ..['modifier'] = account.name
    ..['deptName'] = req.str('deptName', '教务处');
  if (existing == null) {
    cbNotices().add(notice);
  }
  cbSaveNotices();
  return <String, dynamic>{'id': notice['id']};
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

Object? _noticeDelete(DemoRequest req) {
  final id = req.str('id');
  final list = cbNotices();
  final before = list.length;
  list.removeWhere((n) => cbStr(n['id']) == id);
  if (list.length == before) {
    throw const DemoApiException('通知不存在或已删除');
  }
  cbSaveNotices();
  return true;
}
