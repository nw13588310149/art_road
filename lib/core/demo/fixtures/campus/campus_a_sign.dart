import '../../demo_accounts.dart';
import '../../demo_backend.dart';
import '../../demo_store.dart';
import 'campus_a_common.dart';
import 'campus_a_courses.dart';
import 'campus_a_leave.dart';

/// 学生课表与课堂签到：`courseList`、小课签到 / 签退 / 评价、签到统计与记录、补签。
///
/// 小课流程 `signStatus`：0 未签到 → 1 老师上课签 → 2 学生上课签 → 3 老师下课签
/// → 4 学生下课签 → 5 学生评价。学生上课签到约 20 秒后由老师完成下课签到，
/// 学生端 5 秒轮询即可看到「下课签到」按钮亮起。补签申请约 2 分钟后由教务通过。
abstract final class CampusASign {
  static const _teacherSignOutDelay = Duration(seconds: 20);
  static const _makeupAuditDelay = Duration(minutes: 2);

  static const _evaluations = <String>[
    '老师讲得很细，暗部层次终于理顺了',
    '一对一改画收获很大，构图问题找到了原因',
    '示范很清楚，回去按老师说的多练',
    '节奏有点快，但干货很多',
  ];

  static String _actionKey(DemoAccount account) =>
      'campusA:courseSign:${account.userId}';

  static String _makeupKey(DemoAccount account) =>
      'campusA:courseMakeup:${account.userId}';

  static Map<String, dynamic> _actions(DemoAccount account) =>
      DemoStore.map(_actionKey(account), () => <String, dynamic>{});

  static Map<String, dynamic>? _actionOf(DemoAccount account, String id) {
    final value = _actions(account)[id];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  // ── 补签 ────────────────────────────────────────────────────────────

  static List<Map<String, dynamic>> makeups(DemoAccount account) {
    final key = _makeupKey(account);
    final list = DemoStore.list(key, () => _seedMakeups(account));
    final now = DateTime.now().millisecondsSinceEpoch;
    var changed = false;
    for (final item in list) {
      final submitted = (item['submittedAtMs'] as num?)?.toInt();
      if (item['status'] == 0 &&
          submitted != null &&
          now - submitted >= _makeupAuditDelay.inMilliseconds) {
        item['status'] = 1;
        item['statusText'] = '已通过';
        item['approveRemark'] = '经任课老师确认情况属实，同意补签';
        item['approverName'] = '王敏';
        item['approveTime'] = CampusA.dateTime(
          DateTime.fromMillisecondsSinceEpoch(
            submitted + _makeupAuditDelay.inMilliseconds,
          ),
        );
        changed = true;
      }
    }
    if (changed) {
      DemoStore.save(key);
    }
    return list;
  }

  /// 演示学生的固定缺勤课：最近一次可申请补签、已通过、已驳回各一节。
  static ({String open, String approved, String rejected}) _forcedAbsences(
    int personIndex,
  ) {
    final c = CampusA.classOf(personIndex);
    return (
      open: CampusACourses.courseIdFor(
        c,
        CampusACourses.weekdayOnOrBefore(CampusA.daysAgo(2)),
        3,
      ),
      approved: CampusACourses.courseIdFor(
        c,
        CampusACourses.weekdayOnOrBefore(CampusA.daysAgo(9)),
        2,
      ),
      rejected: CampusACourses.courseIdFor(
        c,
        CampusACourses.weekdayOnOrBefore(CampusA.daysAgo(16)),
        3,
      ),
    );
  }

  static List<Map<String, dynamic>> _seedMakeups(DemoAccount account) {
    final index = CampusA.personIndexOf(account);
    final forced = _forcedAbsences(index);
    final now = DateTime.now();
    Map<String, dynamic>? seed(
      String id,
      String courseId,
      int status,
      String reason,
      String remark,
    ) {
      final course = CampusACourses.findForStudent(courseId, index, now);
      if (course == null) {
        return null;
      }
      final applied = course.endAt.add(const Duration(hours: 14));
      return <String, dynamic>{
        ..._makeupCourseFields(course),
        'id': id,
        'signType': '上课签',
        'reason': reason,
        'status': status,
        'statusText': status == 1 ? '已通过' : '已驳回',
        'createTime': CampusA.dateTime(applied),
        'approveTime': CampusA.dateTime(applied.add(const Duration(hours: 3))),
        'approveRemark': remark,
        'approverName': '王敏',
      };
    }

    return [
      ?seed(
        '6302',
        forced.rejected,
        2,
        '当晚身体不舒服提前回宿舍了，忘记请假',
        '未提前请假，按缺勤处理；后续请先向班主任报备',
      ),
      ?seed(
        '6301',
        forced.approved,
        1,
        '人脸识别设备故障未能打卡，任课老师可以作证',
        '经任课老师确认情况属实，同意补签',
      ),
    ];
  }

  static Map<String, dynamic> _makeupCourseFields(CampusCourse course) =>
      <String, dynamic>{
        'courseId': course.id,
        'subjectName': course.subjectName,
        'courseName': course.subjectName,
        'className': course.schoolClass.name,
        'courseDate': CampusA.date(course.day),
        'lineNum': course.lineNum,
        'teacherName': course.teacher.name,
        'teacherHeadUrl': '',
      };

  static Map<String, dynamic>? _makeupFor(
    DemoAccount account,
    String courseId,
  ) {
    for (final item in makeups(account)) {
      if (item['courseId'] == courseId) {
        return item;
      }
    }
    return null;
  }

  // ── 课程流程 ────────────────────────────────────────────────────────

  static int flowStatus(
    CampusCourse course,
    Map<String, dynamic>? action,
    DateTime now,
  ) {
    if (action != null) {
      if (action['comment'] != null) return 5;
      if (action['signOut'] != null) return 4;
      if (action['signIn'] != null) {
        final at = (action['signInAt'] as num?)?.toInt() ?? 0;
        return now.millisecondsSinceEpoch - at >=
                _teacherSignOutDelay.inMilliseconds
            ? 3
            : 2;
      }
    }
    return switch (course.phaseAt(now)) {
      CampusCoursePhase.ended => 5,
      CampusCoursePhase.inProgress => 1,
      CampusCoursePhase.upcoming => 0,
    };
  }

  static String _clockOf(DateTime time) =>
      '${CampusA.hm(time)}:${CampusA.two(time.second)}';

  /// 今日小课在 `courseList` 中附带的签到流程字段。
  static Map<String, dynamic> _todaySignFields(
    DemoAccount account,
    CampusCourse course,
    DateTime now,
  ) {
    final action = _actionOf(account, course.id);
    final status = flowStatus(course, action, now);
    final record = _record(account, course, now);
    final signInAt = (action?['signInAt'] as num?)?.toInt();
    String? teacherOut;
    if (status >= 3) {
      teacherOut = signInAt != null && action?['signIn'] != null
          ? _clockOf(
              DateTime.fromMillisecondsSinceEpoch(
                signInAt + _teacherSignOutDelay.inMilliseconds,
              ),
            )
          : '${course.end}:00';
    }
    return <String, dynamic>{
      'signStatus': status,
      'courseSignStatus': status,
      'teacherSignInTime': status >= 1
          ? _clockOf(course.startAt.subtract(const Duration(minutes: 2)))
          : null,
      'teacherSignOutTime': teacherOut,
      'studentSignInTime': record?['signInTime'],
      'studentSignOutTime': record?['signOutTime'],
      'score': record?['score'],
      'comment': record?['comment'],
      'signMethod': '按键打卡',
      'fenceLabel': '${course.schoolClass.organizationName} · 电子围栏 300 米内可签到',
    };
  }

  /// 课程 + 本人签到流程（课表接口）。
  static Map<String, dynamic> courseRow(
    DemoAccount account,
    CampusCourse course,
    DateTime now,
  ) {
    final row = course.row();
    if (course.isSmall && course.day == CampusA.dayOf(now)) {
      row.addAll(_todaySignFields(account, course, now));
    } else if (course.day.isBefore(CampusA.dayOf(now)) ||
        course.phaseAt(now) == CampusCoursePhase.ended) {
      row['signStatus'] = 5;
    } else {
      row['signStatus'] = 0;
    }
    return row;
  }

  // ── 签到记录 ────────────────────────────────────────────────────────

  /// 本人某节课的签到记录；尚未开始 / 进行中且未操作的课程返回 null。
  static Map<String, dynamic>? _record(
    DemoAccount account,
    CampusCourse course,
    DateTime now,
  ) {
    final index = CampusA.personIndexOf(account);
    final action = _actionOf(account, course.id);
    final isToday = course.day == CampusA.dayOf(now);
    final ended = course.phaseAt(now) == CampusCoursePhase.ended;
    if (!ended && action == null) {
      return null;
    }
    final h = CampusA.hash('sign|$index|${course.id}');
    var status = 0;
    String? signIn;
    String? signOut;
    double? score;
    String? comment;
    var remark = '';

    if (action != null) {
      signIn = action['signIn']?.toString();
      signOut = action['signOut']?.toString();
      score = (action['score'] as num?)?.toDouble();
      comment = action['comment']?.toString();
      final signInAt = (action['signInAt'] as num?)?.toInt();
      if (signInAt != null &&
          DateTime.fromMillisecondsSinceEpoch(
            signInAt,
          ).isAfter(course.startAt.add(const Duration(minutes: 30)))) {
        status = 2;
        remark = '上课签到晚于开课 30 分钟，记为迟到';
      }
    } else {
      final leave = _leaveOverlap(account, course);
      final forced = _forcedAbsences(index);
      final isForced =
          index == DemoAccounts.student.personIndex &&
          (course.id == forced.open ||
              course.id == forced.approved ||
              course.id == forced.rejected);
      final makeup = _makeupFor(account, course.id);
      if (leave != null) {
        status = 3;
        remark = '已请假：$leave';
      } else if (makeup != null && makeup['status'] == 1) {
        status = 0;
        remark = '补签已通过：${makeup['reason']}';
      } else if (isForced) {
        status = 1;
      } else if (isToday && course.isSmall) {
        status = course.autoComplete ? 0 : 1;
      } else {
        final roll = h % 100;
        status = roll < 91 ? 0 : (roll < 97 ? 2 : 1);
      }
      if (status == 0 || status == 2) {
        final inAt = status == 2
            ? course.startAt.add(Duration(minutes: 3 + h % 10))
            : course.startAt.subtract(Duration(minutes: 2 + h % 8));
        signIn = _clockOf(inAt.add(Duration(seconds: h % 60)));
        signOut = _clockOf(
          course.endAt.add(Duration(minutes: h % 5, seconds: (h ~/ 7) % 60)),
        );
        if (status == 2) {
          remark = '迟到 ${3 + h % 10} 分钟';
        }
        if (course.isSmall) {
          score = 4.0 + (h % 2);
          comment = _evaluations[h % _evaluations.length];
        }
      }
      if (status == 1) {
        remark = makeup != null && makeup['status'] == 2
            ? '补签被驳回：${makeup['approveRemark']}'
            : '未检测到上下课打卡，记为缺勤';
      }
    }
    return <String, dynamic>{
      'id': '9${course.id}',
      'courseId': course.id,
      'date': CampusA.date(course.day),
      'courseDate': CampusA.date(course.day),
      'type': course.type,
      'courseType': course.type,
      'lineNum': course.lineNum,
      'subjectName': course.subjectName,
      'courseName': course.subjectName,
      'teacherId': course.teacher.userId,
      'teacherName': course.teacher.name,
      'teacherHeadUrl': '',
      'className': course.schoolClass.name,
      'classroomName': course.room,
      'timeBegin': course.start,
      'timeEnd': course.end,
      'status': status,
      'signInTime': signIn,
      'signOutTime': signOut,
      'studentSignInTime': signIn,
      'studentSignOutTime': signOut,
      'signMethod': course.isSmall ? '按键打卡' : '刷脸签到',
      'remark': remark,
      'score': score,
      'comment': comment,
    };
  }

  static String? _leaveOverlap(DemoAccount account, CampusCourse course) {
    for (final leave in CampusALeaves.approved(account)) {
      if (leave.start.isBefore(course.endAt) &&
          leave.end.isAfter(course.startAt)) {
        return leave.reason;
      }
    }
    return null;
  }

  /// [from]–[to] 之间（含）已发生的签到记录，按时间倒序。
  static List<Map<String, dynamic>> records(
    DemoAccount account,
    DateTime from,
    DateTime to,
  ) {
    final now = DateTime.now();
    final today = CampusA.dayOf(now);
    final index = CampusA.personIndexOf(account);
    final floor = today.subtract(const Duration(days: 120));
    var day = from.isBefore(floor) ? floor : CampusA.dayOf(from);
    final last = to.isAfter(today) ? today : CampusA.dayOf(to);
    final list = <Map<String, dynamic>>[];
    while (!day.isAfter(last)) {
      for (final course in CampusACourses.forStudent(index, day, now)) {
        final record = _record(account, course, now);
        if (record != null) {
          list.add(record);
        }
      }
      day = DateTime(day.year, day.month, day.day + 1);
    }
    list.sort((a, b) {
      final byDate = b['date'].toString().compareTo(a['date'].toString());
      if (byDate != 0) return byDate;
      return b['timeBegin'].toString().compareTo(a['timeBegin'].toString());
    });
    return list;
  }

  static ({DateTime from, DateTime to}) _range(DemoRequest req) {
    final today = CampusA.today();
    final from =
        CampusA.parseDay(req.str('beginDate')) ??
        today.subtract(const Duration(days: 30));
    final to = CampusA.parseDay(req.str('endDate')) ?? today;
    return (from: from, to: to);
  }

  /// 今日课程数（学生首页「今日课程」）。
  static int todayCourseCount(DemoAccount account) => CampusACourses.forStudent(
    CampusA.personIndexOf(account),
    CampusA.today(),
    DateTime.now(),
  ).length;

  // ── 接口 ────────────────────────────────────────────────────────────

  static void register(DemoRouter r) {
    const base = '/app/school/v2/student';

    r.any('/app/school/v2/user/schoolTimeConfigList', (req) {
      return [
        for (final slot in CampusACourses.slots)
          <String, dynamic>{
            'id': '${slot.lineNum}',
            'lineNum': slot.lineNum,
            'name': slot.name,
            'timeBegin': slot.start,
            'timeEnd': slot.end,
            'startTime': slot.start,
            'endTime': slot.end,
          },
      ];
    });

    r.post('$base/courseList', (req) {
      final account = req.account;
      final now = DateTime.now();
      final today = CampusA.dayOf(now);
      final from = CampusA.parseDay(req.str('beginDate')) ?? today;
      var to = CampusA.parseDay(req.str('endDate')) ?? from;
      if (to.difference(from).inDays > 62) {
        to = from.add(const Duration(days: 62));
      }
      final typeFilter = req.value('type') == null ? null : req.intOf('type');
      final index = CampusA.personIndexOf(account);
      final result = <String, dynamic>{};
      var day = from;
      while (!day.isAfter(to)) {
        result[CampusA.date(day)] = [
          for (final course in CampusACourses.forStudent(index, day, now))
            if (typeFilter == null || course.type == typeFilter)
              courseRow(account, course, now),
        ];
        day = DateTime(day.year, day.month, day.day + 1);
      }
      return result;
    });

    r.post('$base/courseStudentSignIn', (req) {
      final account = req.account;
      final now = DateTime.now();
      final course = _todaySmallCourse(account, req.str('courseId'), now);
      final status = flowStatus(course, _actionOf(account, course.id), now);
      if (status == 0) {
        throw const DemoApiException('老师尚未上课签到，请稍后再试');
      }
      if (status >= 2) {
        throw const DemoApiException('本节课已完成上课签到');
      }
      _actions(account)[course.id] = <String, dynamic>{
        'signIn': _clockOf(now),
        'signInAt': now.millisecondsSinceEpoch,
      };
      DemoStore.save(_actionKey(account));
      return true;
    });

    r.post('$base/courseStudentSignOut', (req) {
      final account = req.account;
      final now = DateTime.now();
      final course = _todaySmallCourse(account, req.str('courseId'), now);
      final action = _actionOf(account, course.id);
      final status = flowStatus(course, action, now);
      if (status < 3 || action == null) {
        throw const DemoApiException('老师尚未下课签到，暂不能签退');
      }
      if (status >= 4) {
        throw const DemoApiException('本节课已完成下课签到');
      }
      _actions(account)[course.id] = <String, dynamic>{
        ...action,
        'signOut': _clockOf(now),
      };
      DemoStore.save(_actionKey(account));
      return true;
    });

    r.post('$base/courseStudentComment', (req) {
      final account = req.account;
      final now = DateTime.now();
      final course = _todaySmallCourse(account, req.str('courseId'), now);
      final action = _actionOf(account, course.id);
      if (flowStatus(course, action, now) != 4 || action == null) {
        throw const DemoApiException('下课签到后才能评价本节课');
      }
      final comment = req.str('comment');
      _actions(account)[course.id] = <String, dynamic>{
        ...action,
        'comment': comment.isEmpty ? '老师讲得很清楚，收获很大' : comment,
        'score': req.intOf('score', 5).clamp(1, 5),
      };
      DemoStore.save(_actionKey(account));
      return true;
    });

    r.post('$base/courseSignStat', (req) {
      final range = _range(req);
      final list = records(req.account, range.from, range.to);
      int count(int status) => list.where((e) => e['status'] == status).length;
      final total = list.length;
      final normal = count(0);
      final late = count(2);
      final rate = total == 0 ? 0 : (normal + late) * 100 / total;
      return <String, dynamic>{
        'totalCount': total,
        'normalCount': normal,
        'lateCount': late,
        'absentCount': count(1),
        'leaveCount': count(3),
        'attendanceRate': '${rate.toStringAsFixed(1)}%',
      };
    });

    r.post('$base/courseSignRecentList', (req) {
      final today = CampusA.today();
      final size = req.intOf('size', 6).clamp(1, 50);
      return records(
        req.account,
        today.subtract(const Duration(days: 21)),
        today,
      ).take(size).toList();
    });

    r.post('$base/courseSignHistory', (req) {
      final range = _range(req);
      final status = req.value('status') == null ? null : req.intOf('status');
      final list = [
        for (final record in records(req.account, range.from, range.to))
          if (status == null || record['status'] == status) record,
      ];
      return CampusA.page(list, req);
    });

    r.post('$base/courseSignDetail', (req) {
      final account = req.account;
      final id = req.str('id');
      final courseId = id.startsWith('9') ? id.substring(1) : id;
      final now = DateTime.now();
      final course = CampusACourses.findForStudent(
        courseId,
        CampusA.personIndexOf(account),
        now,
      );
      final record = course == null ? null : _record(account, course, now);
      if (record == null) {
        throw const DemoApiException('签到记录不存在');
      }
      return record;
    });

    r.post('$base/courseSignMakeupSave', (req) {
      final account = req.account;
      final now = DateTime.now();
      final course = CampusACourses.findForStudent(
        req.str('courseId'),
        CampusA.personIndexOf(account),
        now,
      );
      if (course == null) {
        throw const DemoApiException('课程不存在');
      }
      final existing = _makeupFor(account, course.id);
      if (existing != null && existing['status'] != 2) {
        throw const DemoApiException('该课程已提交过补签申请');
      }
      final reason = req.str('reason');
      if (reason.isEmpty) {
        throw const DemoApiException('请填写补签原因');
      }
      final list = makeups(account)
        ..removeWhere((e) => e['courseId'] == course.id);
      list.insert(0, <String, dynamic>{
        ..._makeupCourseFields(course),
        'id': DemoStore.nextId(),
        'signType': req.str('signType', '上课签'),
        'reason': reason,
        'attachment': req.str('attachment'),
        'status': 0,
        'statusText': '待审批',
        'createTime': CampusA.dateTime(now),
        'approveTime': '',
        'approveRemark': '',
        'submittedAtMs': now.millisecondsSinceEpoch,
      });
      DemoStore.save(_makeupKey(account));
      return true;
    });

    r.post('$base/courseSignMakeupList', (req) {
      final status = req.value('status') == null ? null : req.intOf('status');
      final list = [
        for (final item in makeups(req.account))
          if (status == null || item['status'] == status)
            Map<String, dynamic>.from(item)..remove('submittedAtMs'),
      ]..sort(CampusA.compareTimeDesc);
      return CampusA.page(list, req);
    });

    r.post('$base/courseSignMakeupDetail', (req) {
      final item = CampusA.findById(makeups(req.account), req.str('id'));
      if (item == null) {
        throw const DemoApiException('补签申请不存在');
      }
      return Map<String, dynamic>.from(item)..remove('submittedAtMs');
    });
  }

  static CampusCourse _todaySmallCourse(
    DemoAccount account,
    String courseId,
    DateTime now,
  ) {
    final course = CampusACourses.findForStudent(
      courseId,
      CampusA.personIndexOf(account),
      now,
    );
    if (course == null || !course.isSmall || course.day != CampusA.dayOf(now)) {
      throw const DemoApiException('只能对今日小课进行签到');
    }
    return course;
  }
}
