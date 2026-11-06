import '../../demo_accounts.dart';
import '../../demo_backend.dart';
import '../../demo_store.dart';
import 'campus_a_common.dart';

/// 学生请假：`studentLeaveList` / `studentLeaveDetail` / `studentLeaveSave`。
///
/// 状态：0 待家长审批 / 1 待班主任审批 / 2 家长拒绝 / 3 已通过 / 4 班主任拒绝。
/// 新提交的申请约 30 秒后由家长在小程序同意，进入「待班主任审批」。
abstract final class CampusALeaves {
  static const _parentDelay = Duration(seconds: 30);

  static String _key(DemoAccount account) => 'campusA:leaves:${account.userId}';

  static List<Map<String, dynamic>> listOf(DemoAccount account) {
    final key = _key(account);
    final list = DemoStore.list(key, () => _seed(account));
    final now = DateTime.now().millisecondsSinceEpoch;
    var changed = false;
    for (final item in list) {
      final submitted = (item['submittedAtMs'] as num?)?.toInt();
      if (item['status'] == 0 &&
          submitted != null &&
          now - submitted >= _parentDelay.inMilliseconds) {
        item['status'] = 1;
        item['parentAuditReason'] = '家长已在小程序确认，同意请假';
        item['parentAuditTime'] = CampusA.dateTime(
          DateTime.fromMillisecondsSinceEpoch(
            submitted + _parentDelay.inMilliseconds,
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

  /// 已通过的请假时段（课堂签到记为「请假」）。
  static List<({DateTime start, DateTime end, String reason})> approved(
    DemoAccount account,
  ) => [
    for (final item in listOf(account))
      if (item['status'] == 3)
        (
          start: CampusA.parseDateTime(item['startTime'].toString()) ??
              DateTime(2000),
          end: CampusA.parseDateTime(item['endTime'].toString()) ??
              DateTime(2000),
          reason: item['leaveReason'].toString(),
        ),
  ];

  static int pendingCount(DemoAccount account) => listOf(
    account,
  ).where((item) => item['status'] == 0 || item['status'] == 1).length;

  static Map<String, dynamic> row(
    DemoAccount account,
    Map<String, dynamic> item,
  ) {
    final index = CampusA.personIndexOf(account);
    final person = CampusA.person(index);
    final schoolClass = CampusA.classOf(index);
    return <String, dynamic>{
      ...item,
      'studentId': CampusA.studentNo(index),
      'userId': CampusA.studentUserId(index),
      'classId': schoolClass.id,
      'className': schoolClass.name,
      'student': <String, dynamic>{
        'id': CampusA.studentUserId(index),
        'realname': person.name,
        'nickname': person.name,
        'studentNo': CampusA.studentNo(index),
        'headUrl': CampusA.avatarUrl(index),
        'gender': person.gender,
      },
    }..remove('submittedAtMs');
  }

  static List<Map<String, dynamic>> _seed(DemoAccount account) {
    final today = CampusA.today();
    String at(DateTime day, String clock) =>
        CampusA.dateTime(CampusA.at(day, clock));
    DateTime offset(int days) => today.add(Duration(days: days));
    final headTeacher = CampusA.headTeacherOf(
      CampusA.classOf(CampusA.personIndexOf(account)),
    );
    return [
      <String, dynamic>{
        'id': '6205',
        'type': 1,
        'startTime': at(offset(6), '08:00'),
        'endTime': at(offset(7), '21:00'),
        'leaveDuration': '2天',
        'leaveReason': '周末回家复查视力并重新配眼镜',
        'createTime': CampusA.ago(hours: 2),
        'status': 0,
        'parentAuditReason': '',
        'teacherAuditReason': '',
      },
      <String, dynamic>{
        'id': '6204',
        'type': 0,
        'startTime': at(offset(1), '14:00'),
        'endTime': at(offset(1), '17:30'),
        'leaveDuration': '3.5小时',
        'leaveReason': '牙疼复诊（兰州市口腔医院），需家长陪同',
        'createTime': CampusA.ago(hours: 20),
        'status': 1,
        'parentAuditReason': '已同意，复诊由家长陪同',
        'parentAuditTime': CampusA.ago(hours: 19),
        'teacherAuditReason': '',
      },
      <String, dynamic>{
        'id': '6203',
        'type': 1,
        'startTime': at(offset(-5), '08:00'),
        'endTime': at(offset(-4), '21:00'),
        'leaveDuration': '2天',
        'leaveReason': '去西安参加美院校考咨询会',
        'createTime': at(offset(-7), '20:16:00'),
        'status': 4,
        'parentAuditReason': '家长同意',
        'parentAuditTime': at(offset(-7), '21:02'),
        'teacherAuditReason':
            '冲刺阶段不建议外出两天，可参加下周三的线上咨询会（${headTeacher.name}）',
        'teacherAuditTime': at(offset(-6), '08:40'),
      },
      <String, dynamic>{
        'id': '6202',
        'type': 1,
        'startTime': at(offset(-14), '14:00'),
        'endTime': at(offset(-14), '17:30'),
        'leaveDuration': '3.5小时',
        'leaveReason': '回家取冬季衣物和新买的画具',
        'createTime': at(offset(-15), '19:30'),
        'status': 3,
        'parentAuditReason': '同意，下午接孩子回家',
        'parentAuditTime': at(offset(-15), '19:45'),
        'teacherAuditReason': '同意请假，晚课前返校',
        'teacherAuditTime': at(offset(-15), '21:10'),
      },
      <String, dynamic>{
        'id': '6201',
        'type': 0,
        'startTime': at(offset(-26), '08:00'),
        'endTime': at(offset(-26), '21:00'),
        'leaveDuration': '1天',
        'leaveReason': '感冒发烧到 38.5℃，去医院就诊输液',
        'createTime': at(offset(-27), '22:05'),
        'status': 3,
        'parentAuditReason': '孩子发烧需要休息，家长同意',
        'parentAuditTime': at(offset(-27), '22:20'),
        'teacherAuditReason': '同意请假，注意休息，落下的素描课找李静老师补',
        'teacherAuditTime': at(offset(-26), '07:30'),
      },
    ];
  }

  static void register(DemoRouter r) {
    const base = '/app/school/v2/student';

    r.post('$base/studentLeaveList', (req) {
      final account = req.account;
      final list = [
        for (final item in listOf(account)) row(account, item),
      ]..sort(CampusA.compareTimeDesc);
      return CampusA.page(list, req);
    });

    r.post('$base/studentLeaveDetail', (req) {
      final account = req.account;
      final item = CampusA.findById(listOf(account), req.str('id'));
      if (item == null) {
        throw const DemoApiException('请假记录不存在');
      }
      return row(account, item);
    });

    r.post('$base/studentLeaveSave', (req) {
      final account = req.account;
      final start = CampusA.parseDateTime(req.str('startTime'));
      final end = CampusA.parseDateTime(req.str('endTime'));
      final reason = req.str('leaveReason');
      if (start == null || end == null || !end.isAfter(start)) {
        throw const DemoApiException('请选择正确的请假起止时间');
      }
      if (reason.isEmpty) {
        throw const DemoApiException('请填写请假事由');
      }
      final list = listOf(account);
      list.insert(0, <String, dynamic>{
        'id': DemoStore.nextId(),
        'type': req.intOf('type', 1),
        'startTime': CampusA.dateTime(start),
        'endTime': CampusA.dateTime(end),
        'leaveDuration': req.str('leaveDuration', '—'),
        'leaveReason': reason,
        'createTime': CampusA.dateTime(DateTime.now()),
        'status': 0,
        'parentAuditReason': '',
        'teacherAuditReason': '',
        'submittedAtMs': DateTime.now().millisecondsSinceEpoch,
      });
      DemoStore.save(_key(account));
      return true;
    });
  }
}
