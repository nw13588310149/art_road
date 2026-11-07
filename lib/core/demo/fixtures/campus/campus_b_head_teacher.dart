/// 智慧校园 · 班主任端演示接口（`/app/school/v2/teacher/*` 中与班级管理相关的
/// 部分）：班级工作台、班级成绩、查寝与补卡、重点关注、班级通知、家校沟通、
/// 学生请假审批。
library;

import '../../data/demo_marking_data.dart';
import '../../demo_backend.dart';
import '../../demo_store.dart';
import 'campus_b_common.dart';
import 'campus_b_people.dart';
import 'campus_b_records.dart';

const String _base = '/app/school/v2/teacher';

void registerCampusBHeadTeacher(DemoRouter r) {
  r.post('$_base/headTeacherIndex', _index);
  r.post('$_base/headTeacherClassOverview', _classOverview);
  r.post('$_base/headTeacherClassScoreOverview', _scoreOverview);

  r.post('$_base/dormNormalStat', _dormNormalStat);
  r.post('$_base/classDormitoryDynamicList', _dormDynamic);
  r.post('$_base/classDormitoryCheckHistory', _dormHistory);
  r.post('$_base/classDormitoryCheckStat', _dormStat);
  r.post('$_base/classDormitoryCheckDetail', _dormDetail);
  r.post('$_base/classDormitoryMakeupList', _makeupList);
  r.post('$_base/classDormitoryMakeupDetail', _makeupDetail);
  r.post('$_base/classDormitoryMakeupAudit', _makeupAudit);

  r.post('$_base/focusStudentAdd', _focusAdd);
  r.post('$_base/focusStudentRemove', _focusRemove);
  r.post('$_base/focusStudentList', _focusList);

  r.post('$_base/classUpdate', _classUpdate);
  r.post('$_base/schoolClassNoticeList', _classNoticeList);
  r.post('$_base/schoolClassNoticeSave', _classNoticeSave);
  r.post('$_base/schoolClassNoticeDel', _classNoticeDelete);
  r.post('$_base/schoolClassNoticeDetail', _classNoticeDetail);

  r.post('$_base/chatStat', _chatStat);
  r.post('$_base/chatConversationList', _chatConversations);
  r.post('$_base/chatMessageList', _chatMessages);
  r.post('$_base/chatSend', _chatSend);

  r.post('$_base/studentUpdate', _studentUpdate);
  r.post('$_base/headTeacherStudentLeaveList', _leaveList);
  r.post('$_base/headTeacherStudentLeaveAudit', _leaveAudit);
  r.post('$_base/headTeacherStudentLeaveDetail', _leaveDetail);
}

// ── 工作台首页 ────────────────────────────────────────────────────────

String _leaveTypeLabel(Object? type) => cbInt(type) == 0 ? '病假' : '事假';

String _shortTime(Object? raw) {
  final at = cbParse(raw);
  if (at == null) {
    return '';
  }
  final today = cbToday();
  final day = cbDay(at);
  if (day == today) {
    return '今天 ${cbHm(at)}';
  }
  if (day == cbAddDays(today, -1)) {
    return '昨天 ${cbHm(at)}';
  }
  return '${cbTwo(at.month)}-${cbTwo(at.day)} ${cbHm(at)}';
}

/// 班级在籍住校生昨晚 / 今晨的查寝异常。
List<CbDormCheck> _recentDormIssues(List<String> classIds) {
  final ids = <String>{for (final cid in classIds) ...cbActiveStudents(cid)};
  final today = cbToday();
  return [
    for (final check in cbDormChecks(ids.toList(), cbAddDays(today, -1), today))
      if (check.status != '正常' &&
          (check.day == today ||
              (check.evening && check.day == cbAddDays(today, -1))))
        check,
  ];
}

Object? _index(DemoRequest req) {
  final scope = cbScope(req);
  final classIds = scope.headClassIds;
  final classSet = classIds.toSet();
  final leaves = [
    for (final m in cbStudentLeaves())
      if (classSet.contains(cbStr(m['classId']))) m,
  ]..sort((a, b) => cbStr(b['createTime']).compareTo(cbStr(a['createTime'])));
  final pendingLeaves = leaves.where((m) => cbInt(m['status']) == 1).toList();
  final makeups = [
    for (final m in cbDormMakeups())
      if (classSet.contains(cbDormMakeupClassId(m)) && cbInt(m['status']) == 0)
        m,
  ];
  final issues = _recentDormIssues(classIds);
  final chats = [
    for (final c in cbChatConversations())
      if (classSet.contains(cbStr(c['classId']))) c,
  ];
  final unread = chats.fold<int>(0, (sum, c) => sum + cbInt(c['unreadCount']));
  final waiting = chats.where((c) => c['waitingReply'] == true).length;

  final todo = <Map<String, dynamic>>[
    for (final m in pendingLeaves.take(2))
      <String, dynamic>{
        'title': cbInt(m['status']) == 1 ? '待我审批' : '待家长确认',
        'time': _shortTime(m['createTime']),
        'desc':
            '${cbPerson(m['studentId'])?.name ?? ''}${_leaveTypeLabel(m['type'])}'
            '：${cbStr(m['leaveReason'])}',
        'tag': '请假',
      },
    if (makeups.isNotEmpty)
      <String, dynamic>{
        'title': '待审核',
        'time': _shortTime(makeups.first['createTime']),
        'desc': makeups.length == 1
            ? '${cbPerson(makeups.first['studentId'])?.name ?? ''}申请 '
                  '${cbStr(makeups.first['checkDate']).substring(5)} '
                  '${cbStr(makeups.first['checkType'])}补卡'
            : '${cbPerson(makeups.first['studentId'])?.name ?? ''}等 '
                  '${makeups.length} 人申请查寝补卡',
        'tag': '补卡',
      },
    for (final check in issues.take(1))
      <String, dynamic>{
        'title': '需处理',
        'time':
            '${check.day == cbToday() ? (check.evening ? '今晚' : '今晨') : '昨晚'}'
            '${check.evening ? '查寝' : '晨检'}',
        'desc':
            '${check.person.name} ${check.status}'
            '${check.remark.isEmpty ? '' : '，${check.remark}'}',
        'tag': '查寝',
      },
  ];

  final notices = [
    for (final n in cbClassNotices())
      if (classSet.contains(cbStr(n['classId']))) n,
  ]..sort((a, b) => cbStr(b['createTime']).compareTo(cbStr(a['createTime'])));
  final approved = leaves.where((m) => cbInt(m['status']) == 3).toList();
  final recent = <Map<String, dynamic>>[
    for (final c in chats.where((c) => c['waitingReply'] == true).take(1))
      <String, dynamic>{
        'title': '',
        'time': _shortTime(c['lastMessageTime']),
        'desc':
            '${cbStr(c['parentName'])}（${cbPerson(c['studentId'])?.name ?? ''}${cbStr(c['parentRelation'])}）'
            '：${cbStr(c['lastMessage'])}',
        'tag': '家校',
      },
    for (final n in notices.take(1))
      <String, dynamic>{
        'title': '',
        'time': _shortTime(n['createTime']),
        'desc': '发布班级通知「${cbStr(n['title'])}」',
        'tag': '班级',
      },
    for (final m in approved.take(1))
      <String, dynamic>{
        'title': '',
        'time': _shortTime(m['teacherAuditTime'] ?? m['createTime']),
        'desc':
            '已批准${cbPerson(m['studentId'])?.name ?? ''}的${_leaveTypeLabel(m['type'])}',
        'tag': '请假',
      },
  ];

  return <String, dynamic>{
    'chatUnreadCount': unread,
    'chatWaitingCount': waiting,
    'classList': [
      for (final id in classIds)
        <String, dynamic>{
          'classId': id,
          'className': cbClassName(id),
          'studentCount': cbActiveStudents(id).length,
          'logo': cbClassLogo(id),
        },
    ],
    'pendingLeaveCount': pendingLeaves.length,
    'pendingMakeupCount': makeups.length,
    'todayAbnormalDormCount': issues.length,
    'todoList': todo,
    'recentList': recent,
  };
}

Object? _classOverview(DemoRequest req) {
  final classId = req.str('classId');
  final cls = cbClass(classId);
  if (cls == null) {
    throw const DemoApiException('班级不存在');
  }
  final persons = [
    for (final sid in cbClassStudentIds(classId)) ?cbPerson(sid),
  ];
  final issues = _recentDormIssues([classId]);
  return <String, dynamic>{
    'classId': classId,
    'className': cbStr(cls['name']),
    'studentCount': persons.length,
    'activeCount': persons.where(cbIsActive).length,
    'maleCount': persons.where((p) => p.gender == '男').length,
    'femaleCount': persons.where((p) => p.gender == '女').length,
    'residentCount': persons.where((p) => cbBedInfo(p).isNotEmpty).length,
    'pendingLeaveCount': cbStudentLeaves()
        .where((m) => cbStr(m['classId']) == classId && cbInt(m['status']) == 1)
        .length,
    'focusCount': cbFocus().where((m) => cbStr(m['classId']) == classId).length,
    'todayAbnormalDormCount': issues.length,
  };
}

// ── 班级成绩 ──────────────────────────────────────────────────────────

Object? _scoreOverview(DemoRequest req) {
  final classId = req.str('classId');
  if (cbClass(classId) == null) {
    throw const DemoApiException('班级不存在');
  }
  final data = DemoMarkingData.instance;
  final persons = [
    for (final sid in cbClassStudentIds(classId)) ?cbPerson(sid),
  ];
  final exams = [
    for (final exam in data.exams)
      if (persons.any((p) => data.entryOf(p.index, exam.examId) != null)) exam,
  ];
  double? average(DemoExamDef exam, DemoSubjectDef def) {
    final scores = <double>[];
    for (final p in persons) {
      final entry = data.entryOf(p.index, exam.examId);
      final score = entry == null ? null : cbSubjectScore(entry, def);
      if (score != null) {
        scores.add(score);
      }
    }
    return scores.isEmpty
        ? null
        : cbRoundTo(scores.reduce((a, b) => a + b) / scores.length, 1);
  }

  final axis = [
    for (final exam in exams)
      if (exam.subjects.any((def) => average(exam, def) != null)) exam,
  ];
  final requested = req.str('examId');
  final current =
      exams.where((e) => e.examId == requested).firstOrNull ??
      (axis.isNotEmpty ? axis.last : (exams.isNotEmpty ? exams.last : null));

  final subjectFilter = req.intOf('subjectId');
  final keyword = req.str('keyword');
  final records = <Map<String, dynamic>>[];
  if (current != null) {
    final ranked = [
      for (final p in persons)
        if (data.entryOf(p.index, current.examId) case final entry?)
          (person: p, entry: entry),
    ]..sort((a, b) => (b.entry.total ?? 0).compareTo(a.entry.total ?? 0));
    for (final item in ranked) {
      if (keyword.isNotEmpty &&
          !item.person.name.contains(keyword) &&
          !cbStudentNo(item.person).contains(keyword)) {
        continue;
      }
      for (final def in current.subjects) {
        if (subjectFilter > 0 && int.parse(def.subjectId) != subjectFilter) {
          continue;
        }
        final score = cbSubjectScore(item.entry, def);
        if (score == null) {
          continue;
        }
        records.add(<String, dynamic>{
          'studentId': item.person.archiveId,
          'realname': item.person.name,
          'nickname': item.person.name,
          'no': cbStudentNo(item.person),
          'headUrl': cbUrl(item.person.avatarRef),
          'subjectId': int.parse(def.subjectId),
          'subjectName': def.subjectName,
          'score': score.round(),
          'teacherName': cbSubjectTeacherOf(classId, def.subjectName),
          'comment': cbSubjectComment(item.entry, def),
          'hasStudentAudio': false,
          'hasStudentVideo': false,
          'hasVideoComment': false,
          'hasAudioComment': false,
        });
      }
    }
  }
  final pageNum = req.page;
  final pageSize = req.size;
  final start = (pageNum - 1) * pageSize;
  return <String, dynamic>{
    'examAxis': [
      for (final exam in axis)
        <String, dynamic>{
          'examId': exam.examId,
          'name': exam.examName,
          'examDate': exam.examDate,
        },
    ],
    'trendLines': [
      for (final name in const ['素描', '色彩', '速写'])
        <String, dynamic>{
          'subjectId': cbSubjectIds[name],
          'subjectName': name,
          'avgScores': [
            for (final exam in axis)
              average(
                    exam,
                    exam.subjects.firstWhere((s) => s.subjectName == name),
                  ) ??
                  0,
          ],
        },
    ],
    'examTabs': [
      for (final exam in exams)
        <String, dynamic>{
          'examId': exam.examId,
          'name': exam.reviewed ? exam.examName : '${exam.examName}（阅卷中）',
          'examDate': exam.examDate,
        },
    ],
    'currentExamId': current?.examId ?? '',
    'studentScores': <String, dynamic>{
      'records': start >= records.length
          ? const <Map<String, dynamic>>[]
          : records.sublist(start, (start + pageSize).clamp(0, records.length)),
      'total': records.length,
      'pageNum': pageNum,
      'pageSize': pageSize,
    },
  };
}

// ── 查寝 ──────────────────────────────────────────────────────────────

String _classIdOf(DemoRequest req, CbScope scope) {
  final classId = req.str('classId');
  if (classId.isNotEmpty) {
    return classId;
  }
  final ids = scope.headClassIds;
  return ids.isEmpty ? '' : ids.first;
}

Object? _dormNormalStat(DemoRequest req) {
  final scope = cbScope(req);
  final from = cbParseDay(req.str('beginDate')) ?? cbAddDays(cbToday(), -6);
  var to = cbParseDay(req.str('endDate')) ?? cbToday();
  if (to.difference(from).inDays > 31) {
    to = cbAddDays(from, 31);
  }
  final students = <String>{
    for (final cid in scope.headClassIds) ...cbActiveStudents(cid),
  };
  final result = <Map<String, dynamic>>[];
  for (var day = from; !day.isAfter(to); day = cbAddDays(day, 1)) {
    var normal = 0;
    var total = 0;
    for (final sid in students) {
      final p = cbPerson(sid);
      if (p == null) {
        continue;
      }
      final check = cbDormCheck(p, day, 1) ?? cbDormCheck(p, day, 2);
      if (check == null) {
        continue;
      }
      total++;
      if (check.status == '正常') {
        normal++;
      }
    }
    result.add(<String, dynamic>{
      'date': cbDate(day),
      'normalCount': normal,
      'totalCount': total,
    });
  }
  return result;
}

List<Map<String, dynamic>> _filterByStatus(
  List<Map<String, dynamic>> rows,
  String status,
) {
  if (status.isEmpty) {
    return rows;
  }
  return [
    for (final row in rows)
      if (cbStr(row['status']) == status ||
          (status == '异常' && cbStr(row['status']) != '正常'))
        row,
  ];
}

Object? _dormDynamic(DemoRequest req) {
  final classId = _classIdOf(req, cbScope(req));
  final rows = <Map<String, dynamic>>[];
  for (final sid in cbActiveStudents(classId)) {
    final p = cbPerson(sid);
    final check = p == null ? null : cbLatestDormCheck(p);
    if (check != null) {
      rows.add(cbDormCheckJson(check));
    }
  }
  return demoPage(_filterByStatus(rows, req.str('status')), req);
}

Object? _dormHistory(DemoRequest req) {
  final classId = _classIdOf(req, cbScope(req));
  final to = cbParseDay(req.str('endDate')) ?? cbToday();
  var from = cbParseDay(req.str('beginDate')) ?? cbAddDays(to, -6);
  if (to.difference(from).inDays > 31) {
    from = cbAddDays(to, -31);
  }
  final studentFilter = cbPerson(req.str('studentId'))?.archiveId;
  final ids = [
    for (final sid in cbActiveStudents(classId))
      if (studentFilter == null || sid == studentFilter) sid,
  ];
  final rows = [
    for (final check in cbDormChecks(ids, from, to)) cbDormCheckJson(check),
  ];
  return demoPage(_filterByStatus(rows, req.str('status')), req);
}

Object? _dormStat(DemoRequest req) {
  final classId = _classIdOf(req, cbScope(req));
  final to = cbParseDay(req.str('endDate')) ?? cbToday();
  final from = cbParseDay(req.str('beginDate')) ?? to;
  final students = [
    for (final sid in cbActiveStudents(classId))
      if (cbPerson(sid) case final p? when cbBedInfo(p).isNotEmpty) sid,
  ];
  var normal = 0;
  var late = 0;
  var absent = 0;
  for (final check in cbDormChecks(students, from, to)) {
    switch (check.status) {
      case '正常':
        normal++;
      case '晚归':
      case '迟到':
        late++;
      default:
        absent++;
    }
  }
  final approved = cbDormMakeups().where((m) {
    final day = cbParseDay(m['checkDate']);
    return cbDormMakeupClassId(m) == classId &&
        cbInt(m['status']) == 1 &&
        day != null &&
        !day.isBefore(from) &&
        !day.isAfter(to);
  }).length;
  return <String, dynamic>{
    'classId': classId,
    'className': cbClassName(classId),
    'studentCount': students.length,
    'normalCount': normal,
    'lateCount': late,
    'absentCount': absent,
    'makeupApprovedCount': approved,
  };
}

Object? _dormDetail(DemoRequest req) {
  final check = cbDormCheckById(req.str('id'));
  if (check == null) {
    throw const DemoApiException('查寝记录不存在');
  }
  return cbDormCheckJson(check);
}

Object? _makeupList(DemoRequest req) {
  final classId = _classIdOf(req, cbScope(req));
  final status = cbStr(req.value('status'));
  final rows = [
    for (final m in cbDormMakeups())
      if (cbDormMakeupClassId(m) == classId &&
          (status.isEmpty || cbInt(m['status']) == cbInt(status)))
        m,
  ]..sort((a, b) => cbStr(b['createTime']).compareTo(cbStr(a['createTime'])));
  return demoPage([for (final m in rows) cbDormMakeupJson(m)], req);
}

Map<String, dynamic> _makeupOf(DemoRequest req) {
  final id = req.str('id');
  for (final m in cbDormMakeups()) {
    if (cbStr(m['id']) == id) {
      return m;
    }
  }
  throw const DemoApiException('补卡申请不存在');
}

Object? _makeupDetail(DemoRequest req) => cbDormMakeupJson(_makeupOf(req));

Object? _makeupAudit(DemoRequest req) {
  final m = _makeupOf(req);
  if (cbInt(m['status']) != 0) {
    throw const DemoApiException('该补卡申请已处理');
  }
  final status = req.intOf('status');
  if (status != 1 && status != 2) {
    throw const DemoApiException('审批状态不正确');
  }
  m['status'] = status;
  m['auditReason'] = req.str(
    'auditReason',
    status == 1 ? '已核实，同意补卡。' : '与宿管记录不符，补卡不予通过。',
  );
  m['auditTime'] = cbDateTime(DateTime.now());
  cbSaveDormMakeups();
  return true;
}

// ── 重点关注 ──────────────────────────────────────────────────────────

bool _ownsFocus(CbScope scope, Map<String, dynamic> m) =>
    scope.all ||
    cbStr(m['teacherUserId']) == scope.userId ||
    scope.headClassIds.contains(cbStr(m['classId']));

Object? _focusList(DemoRequest req) {
  final scope = cbScope(req);
  final rows = [
    for (final m in cbFocus())
      if (_ownsFocus(scope, m)) m,
  ]..sort((a, b) => cbStr(b['createTime']).compareTo(cbStr(a['createTime'])));
  return [for (final m in rows) cbFocusJson(m)];
}

Object? _focusAdd(DemoRequest req) {
  final scope = cbScope(req);
  final p = cbPerson(req.str('studentId'));
  if (p == null) {
    throw const DemoApiException('学生不存在');
  }
  final reason = req.str('reason');
  if (reason.isEmpty) {
    throw const DemoApiException('请填写关注原因');
  }
  final list = cbFocus();
  final existing = list
      .where((m) => cbStr(m['studentId']) == p.archiveId)
      .firstOrNull;
  final entry = existing ?? <String, dynamic>{'studentId': p.archiveId};
  entry
    ..['classId'] = req.str('classId', cbStr(cbHomeClassOf(p)?['id']))
    ..['tag'] = req.str('tag', '学业关注')
    ..['reason'] = reason
    ..['teacherUserId'] = scope.userId
    ..['createTime'] = cbDateTime(DateTime.now());
  if (existing == null) {
    list.add(entry);
  }
  cbSaveFocus();
  return true;
}

Object? _focusRemove(DemoRequest req) {
  final p = cbPerson(req.str('id'));
  final id = p?.archiveId ?? req.str('id');
  cbFocus().removeWhere((m) => cbStr(m['studentId']) == id);
  cbSaveFocus();
  return true;
}

// ── 班级群资料与班级通知 ──────────────────────────────────────────────

Object? _classUpdate(DemoRequest req) {
  final cls = cbClass(req.str('id', req.str('classId')));
  if (cls == null) {
    throw const DemoApiException('班级不存在');
  }
  final groupName = req.str('groupName');
  if (groupName.isNotEmpty) {
    cls['groupName'] = groupName;
  }
  final logo = req.str('logo');
  if (logo.isNotEmpty) {
    cls['logo'] = cbRef(logo);
  }
  final announcement = req.str('announcement');
  if (announcement.isNotEmpty) {
    cls['announcement'] = announcement;
  }
  cbSaveClasses();
  return true;
}

Object? _classNoticeList(DemoRequest req) {
  final classId = req.str('classId');
  final rows = [
    for (final n in cbClassNotices())
      if (cbStr(n['classId']) == classId) n,
  ]..sort((a, b) => cbStr(b['createTime']).compareTo(cbStr(a['createTime'])));
  return demoPage([for (final n in rows) cbClassNoticeJson(n)], req);
}

Object? _classNoticeSave(DemoRequest req) {
  final scope = cbScope(req);
  final classId = req.str('classId');
  if (cbClass(classId) == null) {
    throw const DemoApiException('班级不存在');
  }
  final title = req.str('title');
  final content = req.str('content');
  if (title.isEmpty) {
    throw const DemoApiException('请填写通知标题');
  }
  if (content.isEmpty) {
    throw const DemoApiException('请填写通知内容');
  }
  cbClassNotices().add(<String, dynamic>{
    'id': DemoStore.nextId(),
    'classId': classId,
    'title': title,
    'content': content,
    'creatorId': scope.userId,
    'creator': scope.name,
    'createTime': cbDateTime(DateTime.now()),
  });
  cbSaveClassNotices();
  return true;
}

Object? _classNoticeDelete(DemoRequest req) {
  final id = req.str('id');
  final list = cbClassNotices();
  final before = list.length;
  list.removeWhere((n) => cbStr(n['id']) == id);
  if (list.length == before) {
    throw const DemoApiException('通知不存在或已删除');
  }
  cbSaveClassNotices();
  return true;
}

Object? _classNoticeDetail(DemoRequest req) {
  final id = req.str('id');
  for (final n in cbClassNotices()) {
    if (cbStr(n['id']) == id) {
      return cbClassNoticeJson(n);
    }
  }
  throw const DemoApiException('通知不存在或已删除');
}

// ── 家校沟通 ──────────────────────────────────────────────────────────

List<Map<String, dynamic>> _scopeConversations(CbScope scope) {
  final classIds = scope.headClassIds.toSet();
  return [
    for (final c in cbChatConversations())
      if (classIds.contains(cbStr(c['classId']))) c,
  ];
}

Object? _chatStat(DemoRequest req) {
  final list = _scopeConversations(cbScope(req));
  return <String, dynamic>{
    'totalCount': list.length,
    'unreadCount': list.fold<int>(0, (sum, c) => sum + cbInt(c['unreadCount'])),
    'waitingReplyCount': list.where((c) => c['waitingReply'] == true).length,
  };
}

Object? _chatConversations(DemoRequest req) {
  final tab = req.str('tab', 'all');
  final keyword = req.str('keyword');
  final rows =
      [
        for (final c in _scopeConversations(cbScope(req)))
          if (switch (tab) {
                'unread' => cbInt(c['unreadCount']) > 0,
                'waitingReply' => c['waitingReply'] == true,
                _ => true,
              } &&
              (keyword.isEmpty ||
                  (cbPerson(c['studentId'])?.name ?? '').contains(keyword) ||
                  cbStr(c['parentName']).contains(keyword)))
            c,
      ]..sort(
        (a, b) =>
            cbStr(b['lastMessageTime']).compareTo(cbStr(a['lastMessageTime'])),
      );
  return demoPage([for (final c in rows) cbConversationJson(c)], req);
}

Object? _chatMessages(DemoRequest req) {
  final id = req.str('conversationId');
  final conversation = cbChatConversations()
      .where((c) => cbStr(c['id']) == id)
      .firstOrNull;
  if (conversation == null) {
    throw const DemoApiException('会话不存在');
  }
  if (cbInt(conversation['unreadCount']) > 0) {
    conversation['unreadCount'] = 0;
    cbSaveChats();
  }
  final rows = [
    for (final m in cbChatMessages())
      if (cbStr(m['conversationId']) == id) m,
  ]..sort((a, b) => cbStr(b['createTime']).compareTo(cbStr(a['createTime'])));
  return demoPage([for (final m in rows) cbMessageJson(m)], req);
}

Object? _chatSend(DemoRequest req) {
  final scope = cbScope(req);
  final content = req.str('content');
  if (content.isEmpty) {
    throw const DemoApiException('请输入消息内容');
  }
  final p = cbPerson(req.str('studentId'));
  if (p == null) {
    throw const DemoApiException('学生不存在');
  }
  final now = cbDateTime(DateTime.now());
  final conversations = cbChatConversations();
  var conversation = conversations
      .where((c) => cbStr(c['studentId']) == p.archiveId)
      .firstOrNull;
  if (conversation == null) {
    final parent = cbParentsOf(p).first;
    conversation = <String, dynamic>{
      'id': DemoStore.nextId(),
      'classId': cbStr(cbHomeClassOf(p)?['id']),
      'studentId': p.archiveId,
      'parentId': req.str('parentId', cbParentUserId(p)),
      'parentName': parent['name'],
      'parentRelation': parent['relation'],
      'parentMobile': parent['mobile'],
      'studentTags': cbStr(cbProfileOf(p.archiveId)['tags']),
    };
    conversations.add(conversation);
  }
  final messageId = DemoStore.nextId();
  cbChatMessages().add(<String, dynamic>{
    'id': messageId,
    'conversationId': cbStr(conversation['id']),
    'senderType': 'teacher',
    'senderName': scope.name,
    'content': content,
    'messageType': 1,
    'fileUrl': '',
    'createTime': now,
  });
  conversation
    ..['lastMessage'] = content
    ..['lastSenderType'] = 'teacher'
    ..['lastMessageTime'] = now
    ..['waitingReply'] = false
    ..['unreadCount'] = 0;
  cbSaveChats();
  return <String, dynamic>{'id': messageId};
}

// ── 学生资料与请假审批 ────────────────────────────────────────────────

Object? _studentUpdate(DemoRequest req) {
  final p = cbPerson(req.str('studentId'));
  if (p == null) {
    throw const DemoApiException('学生不存在');
  }
  cbUpdateProfile(p.archiveId, <String, dynamic>{
    'remark': cbStr(req.value('remark')),
    'tags': cbCsv(req.value('tags')).join(','),
  });
  return true;
}

Object? _leaveList(DemoRequest req) {
  final classIds = cbScope(req).headClassIds.toSet();
  final statusList = [for (final s in req.listOf('statusList')) cbInt(s)];
  final status = cbStr(req.value('status'));
  final rows = [
    for (final m in cbStudentLeaves())
      if (classIds.contains(cbStr(m['classId'])) &&
          (statusList.isNotEmpty
              ? statusList.contains(cbInt(m['status']))
              : (status.isEmpty || cbInt(m['status']) == cbInt(status))))
        m,
  ]..sort((a, b) => cbStr(b['createTime']).compareTo(cbStr(a['createTime'])));
  return demoPage([for (final m in rows) cbStudentLeaveJson(m)], req);
}

Map<String, dynamic> _leaveOf(DemoRequest req) {
  final id = req.str('id');
  for (final m in cbStudentLeaves()) {
    if (cbStr(m['id']) == id) {
      return m;
    }
  }
  throw const DemoApiException('请假记录不存在');
}

Object? _leaveAudit(DemoRequest req) {
  final m = _leaveOf(req);
  if (cbInt(m['status']) > 1) {
    throw const DemoApiException('该请假申请已处理');
  }
  final status = req.intOf('status');
  if (status != 3 && status != 4) {
    throw const DemoApiException('审批状态不正确');
  }
  m['status'] = status;
  m['teacherAuditReason'] = req.str(
    'teacherAuditReason',
    status == 3 ? '同意请假' : '不予批准请假',
  );
  m['teacherAuditTime'] = cbDateTime(DateTime.now());
  cbSaveStudentLeaves();
  return true;
}

Object? _leaveDetail(DemoRequest req) => cbStudentLeaveJson(_leaveOf(req));
