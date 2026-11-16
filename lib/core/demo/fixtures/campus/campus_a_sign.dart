import '../../demo_accounts.dart';
import '../../demo_backend.dart';
import '../../demo_store.dart';
import 'campus_a_common.dart';
import 'campus_a_courses.dart';
import 'campus_a_leave.dart';
import 'campus_b_courses.dart';

/// 学生课表与课堂考勤：`courseList`、考勤统计与记录、补签。
///
/// 上课由任课老师签课，学生不用自己签到；课程结束后这里生成本人的考勤记录
/// （`status`：0 正常 / 1 缺勤 / 2 迟到 / 3 请假）。`courseList` 里的
/// `signStatus`：0 老师还没签课，2 已签课。补签申请约 2 分钟后由教务通过。
abstract final class CampusASign {
  static const _makeupAuditDelay = Duration(minutes: 2);

  static String _makeupKey(DemoAccount account) =>
      'campusA:courseMakeup:${account.userId}';

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

  /// 演示学生的固定缺勤课：最近一次可申请补签、已通过、已驳回各一节（与老师端一致）。
  static ({String open, String approved, String rejected}) _forcedAbsences() =>
      cbForcedAbsences();

  static List<Map<String, dynamic>> _seedMakeups(DemoAccount account) {
    final index = CampusA.personIndexOf(account);
    final forced = _forcedAbsences();
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
        'signType': '课堂补签',
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
        cbForcedMakeupTexts.rejected.reason,
        cbForcedMakeupTexts.rejected.remark,
      ),
      ?seed(
        '6301',
        forced.approved,
        1,
        cbForcedMakeupTexts.approved.reason,
        cbForcedMakeupTexts.approved.remark,
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

  static String _clockOf(DateTime time) =>
      '${CampusA.hm(time)}:${CampusA.two(time.second)}';

  /// 课程 + 本人的考勤结果（课表接口）。还没上完的课只有课程信息。
  static Map<String, dynamic> courseRow(
    DemoAccount account,
    CampusCourse course,
    DateTime now,
  ) {
    final row = course.row();
    final record = _record(account, course, now);
    row['signStatus'] = record == null ? 0 : 2;
    if (record != null) {
      row['signRecordId'] = record['id'];
      row['studentSignStatus'] = record['status'];
      row['studentSignInTime'] = record['signInTime'];
      row['signRemark'] = record['remark'];
    }
    return row;
  }

  // ── 签到记录 ────────────────────────────────────────────────────────

  /// 本人某节课的考勤记录；还没上完的课返回 null。
  static Map<String, dynamic>? _record(
    DemoAccount account,
    CampusCourse course,
    DateTime now,
  ) {
    final index = CampusA.personIndexOf(account);
    if (course.phaseAt(now) != CampusCoursePhase.ended) {
      return null;
    }
    final h = CampusA.hash('sign|$index|${course.id}');
    var status = 0;
    String? signIn;
    var remark = '';

    final leave = _leaveOverlap(account, course);
    final forced = _forcedAbsences();
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
    } else {
      final roll = h % 100;
      status = roll < 91 ? 0 : (roll < 97 ? 2 : 1);
    }
    if (status == 0 || status == 2) {
      final inAt = status == 2
          ? course.startAt.add(Duration(minutes: 3 + h % 10))
          : course.startAt.subtract(Duration(minutes: 2 + h % 8));
      signIn = _clockOf(inAt);
      if (status == 2) {
        remark = '迟到 ${3 + h % 10} 分钟';
      }
    }
    if (status == 1) {
      remark = makeup != null && makeup['status'] == 2
          ? '补签被驳回：${makeup['approveRemark']}'
          : '老师签课时没有到，记为缺勤';
    }
    return <String, dynamic>{
      'id': '9${course.id}',
      'courseId': course.id,
      'date': CampusA.date(course.day),
      'courseDate': CampusA.date(course.day),
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
      'studentSignInTime': signIn,
      'signMethod': '老师签课',
      'remark': remark,
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
      final index = CampusA.personIndexOf(account);
      final result = <String, dynamic>{};
      var day = from;
      while (!day.isAfter(to)) {
        result[CampusA.date(day)] = [
          for (final course in CampusACourses.forStudent(index, day, now))
            courseRow(account, course, now),
        ];
        day = DateTime(day.year, day.month, day.day + 1);
      }
      return result;
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
        'signType': '课堂补签',
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
}
