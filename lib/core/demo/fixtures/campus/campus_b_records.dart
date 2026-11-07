/// 智慧校园演示记录：学生 / 教职工请假、校级与班级通知、重点关注、查寝与
/// 补卡、家校沟通。种子数据按首次读取时的日期生成。
library;

import '../../data/demo_campus_data.dart';
import '../../data/demo_marking_data.dart';
import '../../demo_accounts.dart';
import '../../demo_store.dart';
import 'campus_a_leave.dart';
import 'campus_b_common.dart';

DemoPerson _p(int index) => DemoMarkingData.instance.person(index);

String _sid(int index) => '${900000 + index}';

// ── 学生请假 ──────────────────────────────────────────────────────────

const String cbStudentLeavesKey = 'campus_b:student_leaves';

List<Map<String, dynamic>> _seedStudentLeaves() {
  Map<String, dynamic> leave({
    required String id,
    required int index,
    required int type,
    required (int, String) start,
    required (int, String) end,
    required String duration,
    required String reason,
    required int status,
    required (int, String) created,
    String parentReason = '',
    String teacherReason = '',
  }) {
    final createdAt = cbPast(created.$1, created.$2);
    final cls = cbHomeClassOf(_p(index));
    return <String, dynamic>{
      'id': id,
      'studentId': _sid(index),
      'classId': cbStr(cls?['id']),
      'type': type,
      'startTime': cbDateTime(cbRel(start.$1, start.$2)),
      'endTime': cbDateTime(cbRel(end.$1, end.$2)),
      'leaveDuration': duration,
      'leaveReason': reason,
      'status': status,
      'parentAuditReason': parentReason,
      'teacherAuditReason': teacherReason,
      'parentAuditTime': status == 0
          ? null
          : cbDateTime(createdAt.add(const Duration(minutes: 15))),
      'teacherAuditTime': status >= 3
          ? cbDateTime(createdAt.add(const Duration(minutes: 40)))
          : null,
      'createTime': cbDateTime(createdAt),
    };
  }

  String ago(int hours, int minutes) =>
      cbDateTime(cbAgo(Duration(hours: hours, minutes: minutes)));
  String at(int days, String hm) => cbDateTime(cbRel(days, hm));
  Map<String, dynamic> mirrored(Map<String, dynamic> m) => <String, dynamic>{
    'studentId': _sid(1),
    'classId': cbStr(cbHomeClassOf(_p(1))?['id']),
    'parentAuditReason': '',
    'teacherAuditReason': '',
    ...m,
  };

  return [
    // 林小雨的请假与学生端一致（同一 id、时间与审批意见）。
    mirrored(<String, dynamic>{
      'id': '6205',
      'type': 1,
      'startTime': at(6, '08:30'),
      'endTime': at(7, '21:00'),
      'leaveDuration': '2 天',
      'leaveReason': '周末回家复查视力并重新配眼镜',
      'createTime': ago(2, 14),
      'status': 0,
    }),
    mirrored(<String, dynamic>{
      'id': '6204',
      'type': 0,
      'startTime': at(1, '14:00'),
      'endTime': at(1, '17:00'),
      'leaveDuration': '3 小时',
      'leaveReason': '牙疼复诊（兰州市口腔医院），需家长陪同',
      'createTime': ago(20, 37),
      'status': 1,
      'parentAuditReason': '已同意，复诊由家长陪同',
      'parentAuditTime': ago(19, 52),
    }),
    mirrored(<String, dynamic>{
      'id': '6203',
      'type': 1,
      'startTime': at(-5, '08:30'),
      'endTime': at(-4, '21:00'),
      'leaveDuration': '2 天',
      'leaveReason': '去西安参加美院校考咨询会',
      'createTime': at(-7, '20:16'),
      'status': 4,
      'parentAuditReason': '家长同意',
      'parentAuditTime': at(-7, '21:02'),
      'teacherAuditReason': '冲刺阶段不建议外出两天，可参加下周三的线上咨询会（赵雪）',
      'teacherAuditTime': at(-6, '08:40'),
    }),
    mirrored(<String, dynamic>{
      'id': '6202',
      'type': 1,
      'startTime': at(-14, '14:00'),
      'endTime': at(-14, '17:00'),
      'leaveDuration': '3 小时',
      'leaveReason': '回家取冬季衣物和新买的画具',
      'createTime': at(-15, '19:30'),
      'status': 3,
      'parentAuditReason': '同意，下午接孩子回家',
      'parentAuditTime': at(-15, '19:45'),
      'teacherAuditReason': '同意请假，晚课前返校',
      'teacherAuditTime': at(-15, '21:10'),
    }),
    mirrored(<String, dynamic>{
      'id': '6201',
      'type': 0,
      'startTime': at(-26, '08:30'),
      'endTime': at(-26, '21:00'),
      'leaveDuration': '1 天',
      'leaveReason': '感冒发烧到 38.5℃，去医院就诊输液',
      'createTime': at(-27, '20:05'),
      'status': 3,
      'parentAuditReason': '孩子发烧需要休息，家长同意',
      'parentAuditTime': at(-27, '20:20'),
      'teacherAuditReason': '同意请假，注意休息，落下的素描课找李静老师补',
      'teacherAuditTime': at(-27, '21:10'),
    }),
    leave(
      id: '3100001',
      index: 9,
      type: 1,
      start: (1, '08:30'),
      end: (2, '17:00'),
      duration: '2',
      reason: '家中有事需回老家一趟，周日晚上返校。',
      status: 1,
      created: (0, '08:40'),
      parentReason: '同意，周日晚上送孩子返校。',
    ),
    leave(
      id: '3100002',
      index: 21,
      type: 0,
      start: (0, '14:00'),
      end: (0, '17:00'),
      duration: '0.5',
      reason: '感冒发烧 38.2℃，下午去医院就诊。',
      status: 0,
      created: (0, '11:40'),
    ),
    leave(
      id: '3100003',
      index: 3,
      type: 1,
      start: (-3, '14:00'),
      end: (-3, '17:00'),
      duration: '0.5',
      reason: '去考点现场确认校考报名信息。',
      status: 3,
      created: (-4, '20:05'),
      parentReason: '同意。',
      teacherReason: '同意请假，回来补上下午的色彩作业。',
    ),
    leave(
      id: '3100004',
      index: 30,
      type: 0,
      start: (-6, '08:30'),
      end: (-5, '17:00'),
      duration: '2',
      reason: '急性肠胃炎，医生建议休息两天。',
      status: 3,
      created: (-7, '20:40'),
      parentReason: '已带孩子就医。',
      teacherReason: '注意休息，作业按时补交。',
    ),
    leave(
      id: '3100005',
      index: 15,
      type: 1,
      start: (3, '08:30'),
      end: (3, '11:30'),
      duration: '0.5',
      reason: '参加校考咨询会。',
      status: 4,
      created: (-1, '19:20'),
      parentReason: '同意。',
      teacherReason: '周六上午为模拟考试，请改到下午。',
    ),
    leave(
      id: '3100006',
      index: 36,
      type: 1,
      start: (5, '08:30'),
      end: (6, '21:00'),
      duration: '2',
      reason: '姐姐结婚，需要回家两天。',
      status: 1,
      created: (-1, '20:50'),
      parentReason: '家长已知晓，周日晚上送回学校。',
    ),
    leave(
      id: '3100007',
      index: 12,
      type: 0,
      start: (-1, '19:00'),
      end: (-1, '21:00'),
      duration: '2 小时',
      reason: '手腕拉伤，晚自习去校医室处理。',
      status: 3,
      created: (-1, '18:40'),
      parentReason: '同意。',
      teacherReason: '同意请假',
    ),
    leave(
      id: '3100008',
      index: 4,
      type: 0,
      start: (0, '08:30'),
      end: (0, '11:30'),
      duration: '0.5',
      reason: '牙疼去口腔医院复诊。',
      status: 1,
      created: (-1, '20:35'),
      parentReason: '同意，我陪孩子去。',
    ),
    leave(
      id: '3100009',
      index: 25,
      type: 1,
      start: (2, '14:00'),
      end: (2, '17:00'),
      duration: '0.5',
      reason: '回户籍所在地办理身份证换证。',
      status: 0,
      created: (0, '09:50'),
    ),
    leave(
      id: '3100010',
      index: 31,
      type: 1,
      start: (-2, '08:30'),
      end: (-2, '17:00'),
      duration: '1',
      reason: '想回家休息一天。',
      status: 2,
      created: (-3, '21:15'),
      parentReason: '临近联考，不同意请假。',
    ),
    leave(
      id: '3100011',
      index: 8,
      type: 0,
      start: (0, '08:30'),
      end: (1, '17:00'),
      duration: '2',
      reason: '扁桃体发炎，需要输液两天。',
      status: 1,
      created: (-1, '21:00'),
      parentReason: '同意。',
    ),
    leave(
      id: '3100012',
      index: 20,
      type: 1,
      start: (-8, '14:00'),
      end: (-8, '17:00'),
      duration: '0.5',
      reason: '参加美院招生宣讲会。',
      status: 3,
      created: (-9, '20:00'),
      parentReason: '同意。',
      teacherReason: '同意请假',
    ),
    leave(
      id: '3100013',
      index: 38,
      type: 0,
      start: (-10, '08:30'),
      end: (25, '17:00'),
      duration: '36',
      reason: '右手腕骨折，申请长假休养。',
      status: 3,
      created: (-10, '09:30'),
      parentReason: '医院诊断证明已上传。',
      teacherReason: '同意，安心休养，复课前联系我。',
    ),
  ];
}

/// 林小雨（演示学生账号）的请假直接取学生端存储，班主任审批后学生端同步可见；
/// 其他学生的请假仍使用本地种子。
List<Map<String, dynamic>> cbStudentLeaves() {
  final own = DemoStore.list(cbStudentLeavesKey, _seedStudentLeaves);
  final linked = CampusALeaves.listOf(DemoAccounts.student);
  final classId = cbStr(cbHomeClassOf(_p(1))?['id']);
  for (final m in linked) {
    m['studentId'] = _sid(1);
    m['classId'] = classId;
  }
  return [
    ...linked,
    for (final m in own)
      if (cbStr(m['studentId']) != _sid(1)) m,
  ];
}

void cbSaveStudentLeaves() {
  DemoStore.save(cbStudentLeavesKey);
  CampusALeaves.save(DemoAccounts.student);
}

Map<String, dynamic> cbStudentLeaveJson(Map<String, dynamic> m) {
  final p = cbPerson(m['studentId']);
  return <String, dynamic>{
    ...m,
    'studentId': p == null ? cbStr(m['studentId']) : cbStudentNo(p),
    'studentUserId': p == null ? '' : cbStudentUserId(p),
    'className': cbClassName(m['classId']),
    'student': <String, dynamic>{
      'id': cbStr(m['studentId']),
      'realname': p?.name ?? '',
      'nickname': p?.name ?? '',
      'studentNo': p == null ? '' : cbStudentNo(p),
      'headUrl': p == null ? '' : cbUrl(p.avatarRef),
      'mobile': p?.phone ?? '',
      'bedInfo': p == null ? '' : cbBedInfo(p),
    },
    'parent': p == null
        ? null
        : <String, dynamic>{
            'realname': cbParentsOf(p).first['name'],
            'relation': cbParentsOf(p).first['relation'],
            'mobile': cbParentsOf(p).first['mobile'],
          },
  };
}

// ── 教职工请假 ────────────────────────────────────────────────────────

const String cbTeacherLeavesKey = 'campus_b:teacher_leaves';

List<Map<String, dynamic>> _seedTeacherLeaves() {
  Map<String, dynamic> leave({
    required String id,
    required String staffId,
    required int type,
    required (int, String) start,
    required (int, String) end,
    required String duration,
    required String reason,
    required String handover,
    required int status,
    required (int, String) created,
    String auditReason = '',
  }) {
    final createdAt = cbPast(created.$1, created.$2);
    return <String, dynamic>{
      'id': id,
      'teacherUserId': DemoCampusData.staffById(staffId)?.userId ?? '',
      'type': type,
      'startTime': cbDateTime(cbRel(start.$1, start.$2)),
      'endTime': cbDateTime(cbRel(end.$1, end.$2)),
      'leaveDuration': duration,
      'leaveReason': reason,
      'shiftHandover': handover,
      'status': status,
      'auditReason': auditReason,
      'auditTime': status == 0
          ? null
          : cbDateTime(createdAt.add(const Duration(minutes: 50))),
      'createTime': cbDateTime(createdAt),
    };
  }

  return [
    leave(
      id: '3200001',
      staffId: 't-1',
      type: 1,
      start: (4, '08:30'),
      end: (4, '17:00'),
      duration: '1',
      reason: '参加省美术联考阅卷培训。',
      handover: '当天素描课请张明远老师代课，石膏头像长期作业照常进行。',
      status: 0,
      created: (0, '09:20'),
    ),
    leave(
      id: '3200002',
      staffId: 't-1',
      type: 0,
      start: (-12, '08:30'),
      end: (-11, '17:00'),
      duration: '2',
      reason: '急性肠胃炎，医院建议休息两天。',
      handover: '素描课由刘芳老师代管，作业讲评顺延。',
      status: 1,
      created: (-13, '20:15'),
      auditReason: '同意，注意休息。',
    ),
    leave(
      id: '3200003',
      staffId: 't-4',
      type: 1,
      start: (-20, '14:00'),
      end: (-20, '17:00'),
      duration: '0.5',
      reason: '孩子学校召开家长会。',
      handover: '速写课改为默写练习，周强老师巡堂。',
      status: 1,
      created: (-21, '18:00'),
      auditReason: '同意。',
    ),
    leave(
      id: '3200004',
      staffId: 't-3',
      type: 1,
      start: (2, '14:00'),
      end: (2, '17:00'),
      duration: '0.5',
      reason: '带队提前踩点冬季写生基地。',
      handover: '色彩课改为静物默写，王海波老师代管课堂纪律。',
      status: 0,
      created: (-1, '16:40'),
    ),
    leave(
      id: '3200005',
      staffId: 't-6',
      type: 1,
      start: (-3, '08:30'),
      end: (-3, '21:00'),
      duration: '1',
      reason: '回老家办理房产手续。',
      handover: '速写课由赵雪老师代课。',
      status: 2,
      created: (-5, '12:30'),
      auditReason: '本周校考集训课时紧张，请调整到下周。',
    ),
    leave(
      id: '3200006',
      staffId: 'd-1',
      type: 1,
      start: (1, '08:30'),
      end: (1, '21:00'),
      duration: '1',
      reason: '家中老人住院，需要陪护一天。',
      handover: '女生公寓由值班宿管代查寝，钥匙与查寝平板已交接。',
      status: 0,
      created: (0, '10:05'),
    ),
    leave(
      id: '3200007',
      staffId: 't-8',
      type: 0,
      start: (-1, '08:30'),
      end: (1, '21:00'),
      duration: '3',
      reason: '腰椎间盘突出复发，医生建议卧床休息。',
      handover: '文化课改为录播课，作业在班级群布置。',
      status: 1,
      created: (-2, '20:30'),
      auditReason: '同意，祝早日康复。',
    ),
    leave(
      id: '3200008',
      staffId: 't-7',
      type: 1,
      start: (6, '08:30'),
      end: (6, '17:00'),
      duration: '1',
      reason: '参加省美协美术理论研讨会。',
      handover: '美术常识课改为自习，复习资料已发到班级群。',
      status: 0,
      created: (0, '08:40'),
    ),
    leave(
      id: '3200009',
      staffId: 't-2',
      type: 0,
      start: (-30, '08:30'),
      end: (-29, '17:00'),
      duration: '2',
      reason: '重感冒发烧。',
      handover: '素描课由李静老师代课。',
      status: 1,
      created: (-31, '20:00'),
      auditReason: '同意。',
    ),
    leave(
      id: '3200010',
      staffId: 'd-1',
      type: 0,
      start: (-15, '08:30'),
      end: (-15, '21:00'),
      duration: '1',
      reason: '发烧需要就医。',
      handover: '查寝由男生公寓宿管代班。',
      status: 1,
      created: (-16, '20:50'),
      auditReason: '同意。',
    ),
  ];
}

List<Map<String, dynamic>> cbTeacherLeaves() =>
    DemoStore.list(cbTeacherLeavesKey, _seedTeacherLeaves);

void cbSaveTeacherLeaves() => DemoStore.save(cbTeacherLeavesKey);

Map<String, dynamic> cbTeacherLeaveJson(Map<String, dynamic> m) {
  final staff = cbStaff(m['teacherUserId']);
  return <String, dynamic>{
    ...m,
    'teacherId': staff == null ? '' : cbStaffNo(staff),
    'teacher': <String, dynamic>{
      'id': staff?.userId ?? '',
      'realname': staff?.name ?? '',
      'nickname': staff?.name ?? '',
      'mobile': staff?.phone ?? '',
      'headUrl': '',
      'gender': staff?.gender ?? '',
    },
    'roleName': staff == null
        ? ''
        : (staff.roles.contains('dormManager') ? '宿管' : '${staff.subject}老师'),
  };
}

/// 已批准且覆盖当前时刻的请假。
bool cbStaffOnLeave(String userId) {
  final now = DateTime.now();
  for (final m in cbTeacherLeaves()) {
    if (cbStr(m['teacherUserId']) != userId || cbInt(m['status']) != 1) {
      continue;
    }
    final start = cbParse(m['startTime']);
    final end = cbParse(m['endTime']);
    if (start != null &&
        end != null &&
        !now.isBefore(start) &&
        !now.isAfter(end)) {
      return true;
    }
  }
  return false;
}

// ── 校级通知 ──────────────────────────────────────────────────────────

const String cbNoticesKey = 'campus_b:notices';

/// 下一场月考：本月第三个周日，已过则顺延到下月（与学生端通知一致）。
DateTime _nextMonthlyExamDay() {
  DateTime thirdSunday(int year, int month) {
    final first = DateTime(year, month);
    return DateTime(
      year,
      month,
      1 + (DateTime.sunday - first.weekday) % 7 + 14,
    );
  }

  final today = cbToday();
  final current = thirdSunday(today.year, today.month);
  if (!current.isBefore(today)) {
    return current;
  }
  return today.month == 12
      ? thirdSunday(today.year + 1, 1)
      : thirdSunday(today.year, today.month + 1);
}

/// 甘肃省美术统考：12 月第一个周日。
DateTime _unifiedExamDay() {
  DateTime firstSunday(int year) {
    final first = DateTime(year, 12);
    return DateTime(year, 12, 1 + (DateTime.sunday - first.weekday) % 7);
  }

  final today = cbToday();
  final thisYear = firstSunday(today.year);
  return thisYear.isBefore(today) ? firstSunday(today.year + 1) : thisYear;
}

/// 月考三科的考试时间（学生端考试安排、校级通知、班级通知共用）。
const String cbMonthlyExamTimes =
    '素描（08:30—11:30）、色彩（14:00—17:00）、速写（19:00—20:00）';

/// 校级通知（学生端、宿管端、老师端、管理端共用一份）。8101–8108 为发给
/// 学生 / 宿管 / 老师的通知，其余为教务端的督导、定时与撤回通知。
List<Map<String, dynamic>> _seedNotices() {
  String ago(int days, String hm) => cbDateTime(cbPast(-days, hm));
  Map<String, dynamic> published({
    required String id,
    required String title,
    required String content,
    required String type,
    required String priority,
    required String scope,
    required String creator,
    required String dept,
    required String time,
  }) => <String, dynamic>{
    'id': id,
    'title': title,
    'content': content,
    'type': type,
    'priority': priority,
    'pushScope': scope,
    'status': 1,
    'publishMode': 1,
    'publishedAt': time,
    'scheduledTime': null,
    'createTime': time,
    'updateTime': time,
    'creator': creator,
    'modifier': creator,
    'deptName': dept,
  };
  Map<String, dynamic> notice({
    required String id,
    required String title,
    required String content,
    required String type,
    required String priority,
    required String scope,
    required int status,
    required int days,
    String hm = '09:30',
  }) {
    final at = status == 2 ? cbRel(days, hm) : cbPast(days, hm);
    final created = status == 2 ? cbPast(0, '08:50') : at;
    return <String, dynamic>{
      'id': id,
      'title': title,
      'content': content,
      'type': type,
      'priority': priority,
      'pushScope': scope,
      'status': status,
      'publishMode': status == 2 ? 2 : 1,
      'publishedAt': status == 1 || status == 3 ? cbDateTime(at) : null,
      'scheduledTime': status == 2 ? cbDateTime(at) : null,
      'createTime': cbDateTime(created),
      'updateTime': status == 3
          ? cbDateTime(at.add(const Duration(hours: 2)))
          : cbDateTime(created),
      'creator': '王敏',
      'modifier': '王敏',
      'deptName': '教务处',
    };
  }

  final exam = _nextMonthlyExamDay();
  final unified = _unifiedExamDay();
  final examLabel = '${exam.month} 月 ${exam.day} 日（周日）';
  final countdownAt = cbPast(-3, '08:50');
  final days = unified.difference(cbDay(countdownAt)).inDays;
  return [
    published(
      id: '8101',
      title: '${exam.month} 月月考安排',
      content:
          '$examLabel举行${exam.month} 月月考，一天考完：$cbMonthlyExamTimes。'
          '请各班于考前一天完成考场布置，考生凭准考证入场，画具自备。',
      type: '通知',
      priority: '重要',
      scope: 'student,course_teacher,head_teacher,parent',
      creator: '王敏',
      dept: '教务处',
      time: ago(0, '09:10'),
    ),
    published(
      id: '8102',
      title: '寒潮降温安全提示',
      content:
          '本周起兰州将迎来大幅降温，最低气温 -6℃。请同学们增添衣物，晚自习后结伴回宿舍；'
          '宿舍内严禁使用电热毯、暖手宝等大功率电器，宿管老师将加强夜间巡查。',
      type: '通知',
      priority: '紧急',
      scope: 'student,course_teacher,head_teacher,dormitory,parent',
      creator: '王敏',
      dept: '后勤保障部',
      time: ago(1, '16:20'),
    ),
    published(
      id: '8103',
      title: '黄河岸边色彩写生活动报名',
      content:
          '本周六下午组织色彩写生活动，地点：中山桥—白塔山沿线。请自备水粉工具、小马扎和水桶，'
          '13:30 在城东校区门口集合乘车，17:00 返校。报名请联系各班班主任。',
      type: '活动',
      priority: '普通',
      scope: 'student,course_teacher,head_teacher',
      creator: '刘芳',
      dept: '色彩教研组',
      time: ago(2, '10:35'),
    ),
    published(
      id: '8104',
      title: '距甘肃省美术统考还有 $days 天',
      content:
          '甘肃省美术与设计类专业统考定于 ${unified.year} 年 ${unified.month} 月 ${unified.day} 日举行。'
          '冲刺阶段每周六上午安排一次全真模拟考试，请同学们调整作息，保持充足睡眠，按时归寝。',
      type: '通知',
      priority: '重要',
      scope: 'student,course_teacher,head_teacher,parent',
      creator: '王敏',
      dept: '教务处',
      time: cbDateTime(countdownAt),
    ),
    published(
      id: '8105',
      title: '宿舍用电安全专项检查',
      content:
          '本周五 16:00 起对女生公寓 1 号楼、男生公寓 2 号楼进行用电安全专项检查，重点排查违规电器'
          '与私拉电线。请同学们提前自查，检查期间请留一名同学在宿舍配合。',
      type: '督导',
      priority: '重要',
      scope: 'student,dormitory,head_teacher',
      creator: '马红梅',
      dept: '宿管中心',
      time: ago(4, '15:40'),
    ),
    published(
      id: '8106',
      title: '西安美术学院校考线上咨询会',
      content:
          '西安美术学院招生办将于下周三 19:30 举办线上校考咨询会，介绍造型、设计类专业考试要求。'
          '意向报考的同学请在班级群内接龙报名，届时在多媒体教室统一观看。',
      type: '活动',
      priority: '普通',
      scope: 'student,head_teacher',
      creator: '吴雨桐',
      dept: '升学指导中心',
      time: ago(5, '11:15'),
    ),
    published(
      id: '8107',
      title: '宿管值班表调整',
      content:
          '自下周一起，晚查寝时间调整为 21:30—22:30，晨查寝 06:40—07:20。值班宿管请在查寝结束后 '
          '30 分钟内完成异常登记，并同步至班主任。',
      type: '会议',
      priority: '普通',
      scope: 'dormitory',
      creator: '王敏',
      dept: '后勤保障部',
      time: ago(6, '17:05'),
    ),
    published(
      id: '8108',
      title: '教学研讨会通知',
      content:
          '下周二 10:00 在城东校区会议室召开冲刺阶段教学研讨会，议题：模考数据分析、各科训练计划、'
          '校考班课程调整。请各教研组长准备 10 分钟汇报。',
      type: '会议',
      priority: '普通',
      scope: 'course_teacher,head_teacher',
      creator: '王敏',
      dept: '教务处',
      time: ago(2, '14:25'),
    ),
    notice(
      id: '3300002',
      title: '本周教学督导听课安排',
      content: '教务处将于本周三、周四随堂听课，重点关注素描石膏像示范与色彩静物讲评环节，请任课老师提前准备教案与范画。',
      type: '督导',
      priority: '普通',
      scope: 'course_teacher,head_teacher',
      status: 1,
      days: -2,
    ),
    notice(
      id: '3300003',
      title: '冬季风景写生报名',
      content: '12 月中旬组织联考冲刺班赴兰州周边写生基地进行三天风景色彩写生，请班主任统计报名，并提醒学生准备防寒衣物与写生工具。',
      type: '活动',
      priority: '普通',
      scope: 'student,head_teacher,parent',
      status: 1,
      days: -3,
      hm: '15:00',
    ),
    notice(
      id: '3300005',
      title: '教研会议：联考评分标准解读',
      content:
          '本周五 19:30 在城东校区多媒体教室召开教研会，解读甘肃省美术联考素描、色彩、速写评分标准，并对 10 月月考试卷集体复评。',
      type: '会议',
      priority: '重要',
      scope: 'course_teacher,head_teacher',
      status: 1,
      days: -4,
      hm: '10:00',
    ),
    notice(
      id: '3300006',
      title: '校考报名材料准备提醒',
      content: '各美院校考报名陆续开启，班主任请协助学生核对身份证、证件照与作品集要求，确保报名信息准确无误。',
      type: '通知',
      priority: '普通',
      scope: 'student,head_teacher,parent',
      status: 1,
      days: -6,
    ),
    notice(
      id: '3300008',
      title: '10 月月考成绩分析会',
      content: '10 月月考成绩发布后次日召开成绩分析会，请各任课老师准备单科分析与重点学生名单。',
      type: '会议',
      priority: '普通',
      scope: 'course_teacher,head_teacher',
      status: 2,
      days: 3,
      hm: '19:00',
    ),
    notice(
      id: '3300009',
      title: '元旦放假安排',
      content: '元旦放假三天，返校时间与晚自习安排另行通知，请班主任提前统计离校学生。',
      type: '通知',
      priority: '普通',
      scope: 'student,course_teacher,head_teacher,dormitory,parent',
      status: 2,
      days: 20,
      hm: '09:00',
    ),
    notice(
      id: '3300010',
      title: '关于调整晚自习时间的通知',
      content: '原定晚自习调整方案已取消，仍按原时间 19:00–21:00 执行。',
      type: '通知',
      priority: '普通',
      scope: 'student,head_teacher',
      status: 3,
      days: -5,
      hm: '11:00',
    ),
  ];
}

List<Map<String, dynamic>> cbNotices() =>
    DemoStore.list(cbNoticesKey, _seedNotices);

void cbSaveNotices() => DemoStore.save(cbNoticesKey);

/// 定时通知到点后视为已发布。
int cbNoticeStatus(Map<String, dynamic> m) {
  final status = cbInt(m['status']);
  if (status == 2) {
    final at = cbParse(m['scheduledTime']);
    if (at != null && !at.isAfter(DateTime.now())) {
      return 1;
    }
  }
  return status;
}

String _noticeSortKey(Map<String, dynamic> m) => cbStr(
  m['publishedAt'] ?? m['scheduledTime'] ?? m['createTime'],
  cbStr(m['createTime']),
);

Map<String, dynamic> cbNoticeJson(Map<String, dynamic> m) {
  final status = cbNoticeStatus(m);
  return <String, dynamic>{
    ...m,
    'status': status,
    if (status == 1 && m['publishedAt'] == null)
      'publishedAt': m['scheduledTime'] ?? m['createTime'],
  };
}

List<Map<String, dynamic>> cbSortedNotices() =>
    [...cbNotices()]
      ..sort((a, b) => _noticeSortKey(b).compareTo(_noticeSortKey(a)));

// ── 班级通知 ──────────────────────────────────────────────────────────

const String cbClassNoticesKey = 'campus_b:class_notices';

/// 每班 5 条班级通知；学生端「我的班级」读的也是这一份。
List<Map<String, dynamic>> _seedClassNotices() {
  final exam = _nextMonthlyExamDay();
  final result = <Map<String, dynamic>>[];
  for (var i = 0; i < DemoCampusData.classes.length; i++) {
    final c = DemoCampusData.classes[i];
    final head = DemoCampusData.staffById(c.headTeacherId);
    final afternoon = c.id == '503' ? '14:00 起创作构图课' : '14:00 起色彩写生';
    final items = <(String, String, int, String)>[
      (
        '本周六模拟考试安排',
        '本周六 08:30—11:30 在${c.organizationName}考试大厅进行素描模拟考试，$afternoon。'
            '请携带画板、2B—8B 铅笔、可塑橡皮与水粉工具，提前 15 分钟入场。',
        1,
        '18:40',
      ),
      (
        '归寝纪律提醒',
        '近期降温，部分同学晚归。请大家 22:30 前完成人脸打卡，确需晚归须提前在「我的请假」中'
            '提交申请并告知宿管老师。',
        2,
        '21:05',
      ),
      (
        '${exam.month} 月月考报名确认',
        '${exam.month} 月 ${exam.day} 日（周日）进行月考，一天考完：$cbMonthlyExamTimes。'
            '请在本周五前于班级群内接龙确认参考，准考证考前一天统一发放。',
        3,
        '12:20',
      ),
      (
        '水粉颜料集中采购',
        '色彩组统一采购马利 24 色水粉颜料与白色补充装，需要的同学周四前把名单交给画室管理员，'
            '费用多退少补。',
        5,
        '16:05',
      ),
      (
        '家长开放日通知',
        '下周日上午 9:00 举行家长开放日，展示近期优秀作品并进行一对一学情沟通，请提前告知家长。',
        8,
        '10:30',
      ),
    ];
    for (var n = 0; n < items.length; n++) {
      result.add(<String, dynamic>{
        'id': '83${i + 1}${n + 1}',
        'classId': c.id,
        'title': items[n].$1,
        'content': items[n].$2,
        'creatorId': head?.userId ?? '',
        'creator': head?.name ?? '',
        'createTime': cbDateTime(cbPast(-items[n].$3, items[n].$4)),
      });
    }
  }
  return result;
}

List<Map<String, dynamic>> cbClassNotices() =>
    DemoStore.list(cbClassNoticesKey, _seedClassNotices);

void cbSaveClassNotices() => DemoStore.save(cbClassNoticesKey);

Map<String, dynamic> cbClassNoticeJson(Map<String, dynamic> m) =>
    <String, dynamic>{
      ...m,
      'className': cbClassName(m['classId']),
      'teacherName': cbStr(m['creator']),
    };

// ── 重点关注 ──────────────────────────────────────────────────────────

const String cbFocusKey = 'campus_b:focus_students';

List<Map<String, dynamic>> _seedFocus() {
  Map<String, dynamic> focus(
    int index,
    String classId,
    String tag,
    String reason,
    int days,
    String hm,
  ) => <String, dynamic>{
    'studentId': _sid(index),
    'classId': classId,
    'tag': tag,
    'reason': reason,
    'teacherUserId': cbStr(cbClass(classId)?['headTeacherId']),
    'createTime': cbDateTime(cbRel(days, hm)),
  };

  return [
    focus(9, '501', '心理关注', '刚转学过来，晚上偶尔失眠想家，每周谈心一次。', -2, '16:20'),
    focus(15, '501', '学业关注', '文化课英语偏弱，已安排晚自习辅导。', -5, '10:00'),
    focus(30, '501', '考勤关注', '本月两次晚归，已与家长电话沟通。', -1, '09:30'),
    focus(13, '502', '学业关注', '色彩画面偏灰，跟进每周小色稿练习。', -3, '15:10'),
    focus(20, '503', '行为关注', '课堂上频繁使用手机，已约谈并告知家长。', -4, '11:45'),
  ];
}

List<Map<String, dynamic>> cbFocus() => DemoStore.list(cbFocusKey, _seedFocus);

void cbSaveFocus() => DemoStore.save(cbFocusKey);

Map<String, dynamic> cbFocusJson(Map<String, dynamic> m) {
  final p = cbPerson(m['studentId']);
  return <String, dynamic>{
    'studentId': cbStr(m['studentId']),
    'userId': p == null ? '' : cbStudentUserId(p),
    'studentName': p?.name ?? '',
    'realname': p?.name ?? '',
    'studentHeadUrl': p == null ? '' : cbUrl(p.avatarRef),
    'studentNo': p == null ? '' : cbStudentNo(p),
    'classId': cbStr(m['classId']),
    'className': cbClassName(m['classId']),
    'tag': cbStr(m['tag']),
    'reason': cbStr(m['reason']),
    'createTime': cbStr(m['createTime']),
  };
}

// ── 查寝补卡 ──────────────────────────────────────────────────────────

const String cbDormMakeupsKey = 'campus_b:dorm_makeups';

/// 与宿管端补卡种子一致（同一批学生、日期与理由）。
List<Map<String, dynamic>> _seedDormMakeups() {
  Map<String, dynamic> makeup(
    String id,
    int index,
    int daysAgo,
    int session,
    String reason,
    int status, [
    String audit = '',
  ]) {
    final day = cbAddDays(cbToday(), -daysAgo);
    final created = cbAt(
      cbAddDays(day, session == 1 ? 1 : 0),
      session == 1 ? '08:40' : '09:10',
    );
    return <String, dynamic>{
      'id': id,
      'studentId': _sid(index),
      'checkDate': cbDate(day),
      'checkType': session == 1 ? '晚查寝' : '晨查寝',
      'reason': reason,
      'status': status,
      'auditReason': audit,
      'approverName': status == 0 ? '' : '马红梅',
      'auditTime': status == 0
          ? null
          : cbDateTime(created.add(const Duration(hours: 2))),
      'createTime': cbDateTime(created),
      'seeded': true,
    };
  }

  return [
    makeup('5503', 7, 2, 1, '画室加练忘记打卡，22:10 已回寝，室友可以作证', 0),
    makeup('5505', 19, 1, 2, '身体不适在寝室休息，未下楼刷脸', 0),
    makeup('5504', 12, 2, 2, '早起去画室占位置，出门前忘记刷脸', 0),
    makeup('5501', 1, 6, 2, '早上人脸识别一直失败，马老师现场确认我在寝室', 0),
    makeup('5507', 24, 3, 1, '打卡设备离线，22:05 已回寝', 1, '已核实设备离线记录，同意补卡'),
    makeup('5506', 5, 4, 1, '外出取快递晚归', 2, '晚归超过 30 分钟且未提前报备，不予补卡'),
    makeup('5502', 1, 12, 1, '晚自习改画到 22:20，回寝后打卡设备离线', 1, '已核实打卡设备离线，同意补卡'),
  ];
}

List<Map<String, dynamic>> cbDormMakeups() =>
    DemoStore.list(cbDormMakeupsKey, _seedDormMakeups);

void cbSaveDormMakeups() => DemoStore.save(cbDormMakeupsKey);

/// 补卡申请所属班级（按学生当前行政班）。
String cbDormMakeupClassId(Map<String, dynamic> m) {
  final p = cbPerson(m['studentId']);
  return p == null ? '' : cbStr(cbHomeClassOf(p)?['id']);
}

Map<String, dynamic> cbDormMakeupJson(Map<String, dynamic> m) {
  final p = cbPerson(m['studentId']);
  final status = cbInt(m['status']);
  final bed = p == null ? null : DemoCampusData.bedOf(p.index);
  final classId = cbDormMakeupClassId(m);
  return <String, dynamic>{
    ...m,
    'userId': p == null ? '' : cbStudentUserId(p),
    'studentName': p?.name ?? '',
    'realname': p?.name ?? '',
    'studentNo': p == null ? '' : cbStudentNo(p),
    'studentHeadUrl': p == null ? '' : cbUrl(p.avatarRef),
    'classId': classId,
    'className': cbClassName(classId),
    'buildingName': bed?.building ?? '',
    'floorName': bed?.floor ?? '',
    'roomName': bed?.room ?? '',
    'bedName': bed == null ? '' : '${bed.bed}号床',
    'statusText': const ['待审批', '已通过', '已驳回'][status.clamp(0, 2)],
    'approveRemark': cbStr(m['auditReason']),
    'applyTime': m['createTime'],
  };
}

// ── 查寝记录（按日期即时生成，与宿管端同一套规则） ────────────────────

/// 场次：1 晚查寝（21:30 开始，22:30 截止）/ 2 晨查寝（06:40 开始，07:20 截止）。
const Map<int, (String, String, String)> _dormSessions = {
  1: ('晚查寝', '21:30', '22:30'),
  2: ('晨查寝', '06:40', '07:20'),
};

const List<String> _lateRemarks = [
  '画室加练晚归，已向班主任报备',
  '取快递晚归 15 分钟，已登记',
  '晚自习改画结束较晚，已电话联系班主任',
];

const List<String> _eveningMissRemarks = [
  '人脸识别未通过，待补卡',
  '未按时归寝，已上报班主任',
  '请假离校未及时销假',
];

const List<String> _morningMissRemarks = ['晨检未刷脸，宿管现场确认在寝', '人脸识别设备故障，待补卡'];

int _dormHash(String key) {
  var h = 7;
  for (final unit in key.codeUnits) {
    h = (h * 131 + unit) % 1000000007;
  }
  return h;
}

class CbDormCheck {
  const CbDormCheck({
    required this.person,
    required this.day,
    required this.session,
    required this.status,
    this.time = '',
    this.remark = '',
  });

  final DemoPerson person;
  final DateTime day;

  /// 1 晚查寝 / 2 晨查寝。
  final int session;

  /// 正常 / 晚归 / 未打卡。
  final String status;

  /// 打卡时刻 `HH:mm`，未打卡为空。
  final String time;
  final String remark;

  bool get evening => session == 1;

  String get id =>
      '${day.year}${cbTwo(day.month)}${cbTwo(day.day)}$session${cbTwo(person.index)}';
}

({String status, String time, String remark}) _dormGenerated(
  DateTime day,
  int session,
  int index,
) {
  if (index == 1 && session == 1 && day == cbAddDays(cbToday(), -3)) {
    return (status: '晚归', time: '22:41', remark: '素描加练晚归 10 分钟，已向班主任报备');
  }
  final h = _dormHash('dorm|${cbDate(day)}|$session|$index');
  final roll = h % 100;
  String clock(String from, int minutes) =>
      cbHm(cbAt(day, from).add(Duration(minutes: minutes)));
  if (session == 1) {
    if (roll < 88) {
      return (status: '正常', time: clock('21:30', h % 50), remark: '');
    }
    if (roll < 95) {
      return (
        status: '晚归',
        time: clock('22:31', h % 28),
        remark: _lateRemarks[h % _lateRemarks.length],
      );
    }
    return (
      status: '未打卡',
      time: '',
      remark: _eveningMissRemarks[h % _eveningMissRemarks.length],
    );
  }
  if (roll < 94) {
    return (status: '正常', time: clock('06:40', h % 38), remark: '');
  }
  return (
    status: '未打卡',
    time: '',
    remark: _morningMissRemarks[h % _morningMissRemarks.length],
  );
}

/// 某学生某场查寝；场次未结束且尚未打卡、无床位或休学时返回 null。
CbDormCheck? cbDormCheck(DemoPerson p, DateTime day, int session) {
  if (DemoCampusData.bedOf(p.index) == null || !cbIsActive(p)) {
    return null;
  }
  final (_, open, deadline) = _dormSessions[session]!;
  final date = cbDate(day);
  final type = session == 1 ? '晚查寝' : '晨查寝';
  ({String status, String time, String remark})? result;
  for (final m in cbDormMakeups()) {
    if (cbStr(m['studentId']) != p.archiveId ||
        cbStr(m['checkDate']) != date ||
        cbStr(m['checkType']) != type) {
      continue;
    }
    if (cbInt(m['status']) == 1) {
      result = (
        status: '正常',
        time: deadline,
        remark: '补卡已通过：${cbStr(m['reason'])}',
      );
      break;
    }
    if (m['seeded'] == true) {
      result ??= (
        status: '未打卡',
        time: '',
        remark: '已提交补卡申请：${cbStr(m['reason'])}',
      );
    }
  }
  final generated = result ?? _dormGenerated(day, session, p.index);
  final now = DateTime.now();
  final today = cbToday();
  if (day.isAfter(today)) {
    return null;
  }
  if (day == today && now.isBefore(cbAt(day, deadline))) {
    final checkedAt = generated.time.isEmpty ? null : cbAt(day, generated.time);
    final done =
        !now.isBefore(cbAt(day, open)) &&
        checkedAt != null &&
        !checkedAt.isAfter(now) &&
        generated.status != '未打卡';
    if (!done) {
      return null;
    }
  }
  return CbDormCheck(
    person: p,
    day: day,
    session: session,
    status: generated.status,
    time: generated.time,
    remark: generated.remark,
  );
}

/// [studentIds] 在日期区间内已完成的查寝记录（日期倒序、晚查寝在前）。
List<CbDormCheck> cbDormChecks(
  List<String> studentIds,
  DateTime from,
  DateTime to,
) {
  final result = <CbDormCheck>[];
  final today = cbToday();
  var day = to.isAfter(today) ? today : cbDay(to);
  final first = cbDay(from);
  var guard = 0;
  while (!day.isBefore(first) && guard < 120) {
    for (final session in const [1, 2]) {
      for (final sid in studentIds) {
        final p = cbPerson(sid);
        final check = p == null ? null : cbDormCheck(p, day, session);
        if (check != null) {
          result.add(check);
        }
      }
    }
    day = cbAddDays(day, -1);
    guard++;
  }
  return result;
}

/// 学生最近一场已完成的查寝。
CbDormCheck? cbLatestDormCheck(DemoPerson p) {
  final today = cbToday();
  return cbDormCheck(p, today, 1) ??
      cbDormCheck(p, today, 2) ??
      cbDormCheck(p, cbAddDays(today, -1), 1);
}

CbDormCheck? cbDormCheckById(String id) {
  if (id.length != 11) {
    return null;
  }
  final day = cbParseDay(
    '${id.substring(0, 4)}-${id.substring(4, 6)}-${id.substring(6, 8)}',
  );
  final session = int.tryParse(id.substring(8, 9));
  final index = int.tryParse(id.substring(9));
  if (day == null || index == null || (session != 1 && session != 2)) {
    return null;
  }
  final p = cbPerson('${900000 + index}');
  return p == null ? null : cbDormCheck(p, day, session!);
}

Map<String, dynamic> cbDormCheckJson(CbDormCheck c) {
  final p = c.person;
  final bed = DemoCampusData.bedOf(p.index);
  final home = cbHomeClassOf(p);
  final (name, _, deadline) = _dormSessions[c.session]!;
  return <String, dynamic>{
    'id': c.id,
    'checkId': c.id,
    'userId': p.archiveId,
    'studentId': p.archiveId,
    'studentName': p.name,
    'realname': p.name,
    'studentNo': cbStudentNo(p),
    'studentHeadUrl': cbUrl(p.avatarRef),
    'gender': p.gender,
    'classId': cbStr(home?['id']),
    'className': cbStr(home?['name']),
    'buildingName': bed?.building ?? '',
    'floorName': bed?.floor ?? '',
    'roomName': bed?.room ?? '',
    'bedName': bed == null ? '' : '${bed.bed}号床',
    'bedInfo': cbBedInfo(p),
    'checkDate': cbDate(c.day),
    'checkTime': c.time,
    'checkType': name,
    'checkDeadline': '$deadline前',
    'status': c.status,
    'statusText': c.status,
    'handleStatus': 0,
    'remark': c.remark,
    'dormManager': '马红梅',
  };
}

// ── 家校沟通 ──────────────────────────────────────────────────────────

const String cbChatConversationsKey = 'campus_b:chat_conversations';
const String cbChatMessagesKey = 'campus_b:chat_messages';

String cbParentUserId(DemoPerson p) =>
    '18800000002${p.index.toString().padLeft(8, '0')}';

typedef _Msg = (
  String sender,
  int days,
  String hm,
  String content,
  String image,
);

const Map<int, List<_Msg>> _chatScripts = {
  1: [
    ('parent', -2, '20:15', '赵老师您好，小雨这周素描石膏像画得怎么样？她说明暗交界线总是画不准。', ''),
    (
      'teacher',
      -2,
      '21:02',
      '您好，这周进步很明显，结构已经交代清楚了，暗部层次还要再整体一些，周末我请李静老师再单独讲一下。',
      '',
    ),
    ('parent', -2, '21:10', '太感谢了，辛苦老师们。', ''),
    ('parent', 0, '07:45', '老师，周六模拟考试需要家长到场吗？', ''),
  ],
  9: [
    ('parent', -1, '22:40', '老师，孩子刚转过来，晚上给我打电话说睡不着，麻烦您多关注一下。', ''),
    ('teacher', -1, '22:55', '收到，我明天找他聊聊，宿管老师也会多留意他。', ''),
    ('parent', 0, '08:30', '谢谢老师，这是孩子周末在家画的静物，麻烦老师看看。', ''),
    ('parent', 0, '08:31', '[图片]', 'asset:assets/demo/art/sketch-still-1.jpg'),
  ],
  21: [
    ('parent', 0, '11:20', '老师，孩子发烧了，下午想请假去医院，我已经在小程序提交了请假。', ''),
    ('teacher', 0, '11:35', '好的，请假申请收到了，注意多喝水，有情况随时联系我。', ''),
  ],
  15: [
    ('teacher', -3, '19:30', '孙磊老师反馈孩子英语作文进步不大，建议周末在家多练一练。', ''),
    ('parent', -3, '20:05', '好的老师，我们会督促他。专业课这边还跟得上吗？', ''),
    ('teacher', -3, '20:20', '专业课没问题，色彩最近提升很快，月考色彩进了班级前五。', ''),
  ],
  30: [
    ('parent', -1, '23:10', '老师，昨晚孩子在画室赶作业回宿舍晚了，不是故意晚归，麻烦您见谅。', ''),
    ('parent', -1, '23:12', '他说已经提交补卡申请了。', ''),
  ],
  2: [
    ('parent', -1, '19:40', '王老师，孩子速写手部总是画不好，有没有推荐的练习方法？', ''),
    ('teacher', -1, '20:10', '可以每天对着自己的手画 10 张小速写，先抓大的动态和比例，周五我检查。', ''),
    ('parent', -1, '20:12', '好的，谢谢王老师。', ''),
  ],
  10: [('parent', 0, '09:05', '王老师，周六下午写生天气冷，需要给孩子准备什么？', '')],
  13: [
    ('teacher', -4, '18:30', '孩子最近色彩画面偏灰，我给她加了小色稿练习，请家长多鼓励。', ''),
    ('parent', -4, '19:00', '好的，谢谢老师费心。', ''),
  ],
  5: [
    ('parent', -2, '21:20', '周老师，孩子想报中央美院的校考，以他现在的水平有希望吗？', ''),
    ('teacher', -2, '21:45', '速写基础不错，素描还需要加强，按目前进度冲一冲是有机会的。', ''),
    ('parent', 0, '07:20', '好的，那我们周末带他去报名点确认一下信息。', ''),
  ],
  38: [
    ('parent', -3, '10:15', '周老师，孩子手腕恢复得不错，医生说下个月可以复课。', ''),
    ('teacher', -3, '10:40', '太好了，复课前一周告诉我，我帮他把落下的课程安排一下。', ''),
  ],
};

List<Map<String, dynamic>> _seedConversations() {
  final result = <Map<String, dynamic>>[];
  var seq = 1;
  for (final entry in _chatScripts.entries) {
    final p = _p(entry.key);
    final cls = cbHomeClassOf(p);
    final parent = cbParentsOf(p).first;
    final script = entry.value;
    var unread = 0;
    for (final msg in script.reversed) {
      if (msg.$1 != 'parent') {
        break;
      }
      unread++;
    }
    final last = script.last;
    final profileTags = switch (entry.key) {
      1 => '素描尖子',
      9 => '画室管理员,住校适应期',
      15 => '文化课薄弱',
      30 => '晚归',
      _ => '',
    };
    result.add(<String, dynamic>{
      'id': '41${seq.toString().padLeft(5, '0')}',
      'classId': cbStr(cls?['id']),
      'studentId': p.archiveId,
      'parentId': cbParentUserId(p),
      'parentName': parent['name'],
      'parentRelation': parent['relation'],
      'parentMobile': parent['mobile'],
      'studentTags': profileTags,
      'unreadCount': unread,
      'waitingReply': last.$1 == 'parent',
      'lastSenderType': last.$1,
      'lastMessage': last.$5.isEmpty ? last.$4 : '[图片]',
      'lastMessageTime': cbDateTime(cbRel(last.$2, last.$3)),
    });
    seq++;
  }
  return result;
}

List<Map<String, dynamic>> _seedMessages() {
  final result = <Map<String, dynamic>>[];
  var conv = 1;
  for (final script in _chatScripts.values) {
    var seq = 1;
    for (final msg in script) {
      result.add(<String, dynamic>{
        'id':
            '42${conv.toString().padLeft(2, '0')}${seq.toString().padLeft(3, '0')}',
        'conversationId': '41${conv.toString().padLeft(5, '0')}',
        'senderType': msg.$1,
        'content': msg.$4,
        'messageType': msg.$5.isEmpty ? 1 : 2,
        'fileUrl': msg.$5,
        'createTime': cbDateTime(cbRel(msg.$2, msg.$3)),
      });
      seq++;
    }
    conv++;
  }
  return result;
}

List<Map<String, dynamic>> cbChatConversations() =>
    DemoStore.list(cbChatConversationsKey, _seedConversations);

List<Map<String, dynamic>> cbChatMessages() =>
    DemoStore.list(cbChatMessagesKey, _seedMessages);

void cbSaveChats() {
  DemoStore.save(cbChatConversationsKey);
  DemoStore.save(cbChatMessagesKey);
}

Map<String, dynamic> cbConversationJson(Map<String, dynamic> m) {
  final p = cbPerson(m['studentId']);
  final cls = cbClass(m['classId']);
  return <String, dynamic>{
    ...m,
    'studentName': p?.name ?? '',
    'studentNo': p == null ? '' : cbStudentNo(p),
    'studentHeadUrl': p == null ? '' : cbUrl(p.avatarRef),
    'parentHeadUrl': '',
    'className': cbStr(cls?['name']),
    'teacherName': cbStaffName(cls?['headTeacherId']),
  };
}

Map<String, dynamic> cbMessageJson(Map<String, dynamic> m) {
  final file = cbStr(m['fileUrl']);
  return <String, dynamic>{...m, 'fileUrl': file.isEmpty ? '' : cbUrl(file)};
}
