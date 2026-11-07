import 'dart:typed_data';

import '../../data/demo_campus_data.dart';
import '../../demo_accounts.dart';
import '../../demo_backend.dart';
import '../../demo_store.dart';
import 'campus_a_common.dart';
import 'campus_a_xlsx.dart';

/// 一条查寝结果（某天某场次某学生）。
class CampusDormCheck {
  const CampusDormCheck({
    required this.day,
    required this.session,
    required this.personIndex,
    required this.status,
    required this.checkTime,
    required this.remark,
    required this.pending,
  });

  final DateTime day;

  /// 1 晚查寝 / 2 晨查寝。
  final int session;
  final int personIndex;

  /// 正常 / 晚归 / 未打卡 / 缺勤。
  final String status;
  final String checkTime;
  final String remark;

  /// 场次尚未结束且未打卡（查寝进行中 / 未开始）。
  final bool pending;

  String get id => '${CampusA.compact(day)}$session${CampusA.two(personIndex)}';

  String get key => '${CampusA.date(day)}|$session|$personIndex';

  bool get abnormal => status != '正常';
}

/// 宿舍与查寝：学生端 `student/myDormitoryInfo`、`student/dormitory*`，
/// 宿管端 `dormitory/*`（按宿舍查寝、历史、异常处理、补卡审核、班级查寝动态）。
///
/// 床位沿用 [DemoCampusData.beds]（女生公寓1号楼 / 男生公寓2号楼）。查寝结果按
/// 「日期 + 场次 + 学生」稳定生成，宿管打卡、改状态、补卡审批写入 [DemoStore]
/// 后覆盖生成结果；当天场次在截止前显示为待查寝。学生端 `userId` 使用档案 id
/// （六位数字），保证 Web 端数字 id 不丢精度。
abstract final class CampusADorm {
  static const _overrideKey = 'campusA:dorm:overrides';
  static const _handleKey = 'campusA:dorm:handles';
  static const _makeupKey = 'campusA:dorm:makeups';

  static const _sessions = <int, ({String name, String open, String deadline})>{
    1: (name: '晚查寝', open: '21:30', deadline: '22:30'),
    2: (name: '晨查寝', open: '06:40', deadline: '07:20'),
  };

  static String sessionName(int session) => _sessions[session]!.name;

  static String deadlineLabel(int session) =>
      '${_sessions[session]!.deadline}前';

  static int sessionOf(String checkType) => checkType.contains('晨') ? 2 : 1;

  // ── 楼栋 / 房间 ──────────────────────────────────────────────────────

  static String buildingIdOf(String building) =>
      building.contains('女') ? '61' : '62';

  static String floorIdOf(DemoDormBed bed) =>
      '${buildingIdOf(bed.building)}${CampusA.two(int.tryParse(bed.floor.replaceAll('层', '')) ?? 1)}';

  static String roomIdOf(DemoDormBed bed) =>
      '${buildingIdOf(bed.building)}${bed.room}';

  static DemoDormBed? bedOf(int personIndex) =>
      DemoCampusData.bedOf(personIndex);

  static List<DemoDormBed> _beds({
    String? buildingId,
    String? floorId,
    String? roomId,
  }) => [
    for (final bed in DemoCampusData.beds)
      if ((buildingId == null || buildingIdOf(bed.building) == buildingId) &&
          (floorId == null || floorIdOf(bed) == floorId) &&
          (roomId == null || roomIdOf(bed) == roomId))
        bed,
  ];

  static Map<String, dynamic> _placeFields(DemoDormBed bed) =>
      <String, dynamic>{
        'buildingId': buildingIdOf(bed.building),
        'buildingName': bed.building,
        'floorId': floorIdOf(bed),
        'floorName': bed.floor,
        'roomId': roomIdOf(bed),
        'roomName': bed.room,
        'bedId': '${roomIdOf(bed)}${bed.bed}',
        'bedName': '${bed.bed}号床',
      };

  static Map<String, dynamic> _studentFields(int index) {
    final p = CampusA.person(index);
    final c = CampusA.classOf(index);
    final head = CampusA.avatarUrl(index);
    return <String, dynamic>{
      'userId': p.archiveId,
      'studentId': p.archiveId,
      'studentName': p.name,
      'realname': p.name,
      'studentNo': CampusA.studentNo(index),
      'studentHeadUrl': head,
      'gender': p.gender,
      'classId': c.id,
      'className': c.name,
      'user': <String, dynamic>{
        'id': p.archiveId,
        'realname': p.name,
        'mobile': p.phoneMasked,
        'gender': p.gender,
        'headUrl': head,
      },
    };
  }

  // ── 查寝结果 ────────────────────────────────────────────────────────

  static Map<String, dynamic> _overrides() =>
      DemoStore.map(_overrideKey, () => <String, dynamic>{});

  static Map<String, dynamic> _handles() =>
      DemoStore.map(_handleKey, () => <String, dynamic>{});

  static const _lateRemarks = <String>[
    '画室加练晚归，已向班主任报备',
    '取快递晚归 15 分钟，已登记',
    '晚自习改画结束较晚，已电话联系班主任',
  ];

  static const _eveningMissRemarks = <String>[
    '人脸识别未通过，待补卡',
    '未按时归寝，已上报班主任',
    '请假离校未及时销假',
  ];

  static const _morningMissRemarks = <String>['晨检未刷脸，宿管现场确认在寝', '人脸识别设备故障，待补卡'];

  /// 稳定生成的「场次结束后」结果。
  static ({String status, String time, String remark}) _generated(
    DateTime day,
    int session,
    int index,
  ) {
    if (index == DemoAccounts.student.personIndex &&
        session == 1 &&
        day == CampusA.daysAgo(3)) {
      return (status: '晚归', time: '22:41', remark: '素描加练晚归 10 分钟，已向班主任报备');
    }
    final h = CampusA.hash('dorm|${CampusA.date(day)}|$session|$index');
    final roll = h % 100;
    String clock(String from, int minutes) =>
        CampusA.hm(CampusA.at(day, from).add(Duration(minutes: minutes)));
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

  static CampusDormCheck check(
    DateTime day,
    int session,
    int index,
    DateTime now,
  ) {
    final key = '${CampusA.date(day)}|$session|$index';
    final makeups = [
      for (final m in makeupList())
        if (m['personIndex'] == index &&
            m['checkDate'] == CampusA.date(day) &&
            sessionOf(m['checkType'].toString()) == session)
          m,
    ];
    for (final m in makeups) {
      if (m['status'] == 1) {
        return CampusDormCheck(
          day: day,
          session: session,
          personIndex: index,
          status: '正常',
          checkTime: _sessions[session]!.deadline,
          remark: '补卡已通过：${m['reason']}',
          pending: false,
        );
      }
    }
    final override = _overrides()[key];
    if (override is Map) {
      return CampusDormCheck(
        day: day,
        session: session,
        personIndex: index,
        status: override['status'].toString(),
        checkTime: override['checkTime']?.toString() ?? '',
        remark: override['remark']?.toString() ?? '',
        pending: false,
      );
    }
    final seededMakeup = makeups.where((m) => m['seeded'] == true).firstOrNull;
    final generated = seededMakeup != null
        ? (status: '未打卡', time: '', remark: '已提交补卡申请：${seededMakeup['reason']}')
        : _generated(day, session, index);
    final spec = _sessions[session]!;
    final today = CampusA.dayOf(now);
    var pending = false;
    if (day.isAfter(today)) {
      pending = true;
    } else if (day == today) {
      final deadline = CampusA.at(day, spec.deadline);
      if (now.isBefore(deadline)) {
        final checkedAt = generated.time.isEmpty
            ? null
            : CampusA.at(day, generated.time);
        final inWindow = !now.isBefore(CampusA.at(day, spec.open));
        pending =
            !(inWindow &&
                checkedAt != null &&
                !checkedAt.isAfter(now) &&
                generated.status != '未打卡');
      }
    }
    if (pending) {
      return CampusDormCheck(
        day: day,
        session: session,
        personIndex: index,
        status: '未打卡',
        checkTime: '',
        remark: '',
        pending: true,
      );
    }
    return CampusDormCheck(
      day: day,
      session: session,
      personIndex: index,
      status: generated.status,
      checkTime: generated.time,
      remark: generated.remark,
      pending: false,
    );
  }

  static CampusDormCheck? checkById(String id, DateTime now) {
    if (id.length != 11) {
      return null;
    }
    final day = DateTime.tryParse(
      '${id.substring(0, 4)}-${id.substring(4, 6)}-${id.substring(6, 8)}',
    );
    final session = int.tryParse(id.substring(8, 9));
    final index = int.tryParse(id.substring(9));
    if (day == null ||
        session == null ||
        index == null ||
        bedOf(index) == null) {
      return null;
    }
    return check(day, session, index, now);
  }

  /// 「当前场次」：当天 12 点前为晨查寝，之后为晚查寝；其它日期按晚查寝。
  static int currentSession(DateTime day, DateTime now) =>
      day == CampusA.dayOf(now) && now.hour < 12 ? 2 : 1;

  /// 最近一个已经开始的查寝批次：晨查寝 06:40 起、晚查寝 21:30 起；
  /// 当天晨查寝开始前取前一晚的晚查寝。工作台指标按这个批次统计。
  static ({DateTime day, int session}) latestBatch(DateTime now) {
    final today = CampusA.dayOf(now);
    final clock = CampusA.hm(now);
    if (clock.compareTo('21:30') >= 0) return (day: today, session: 1);
    if (clock.compareTo('06:40') >= 0) return (day: today, session: 2);
    return (day: today.subtract(const Duration(days: 1)), session: 1);
  }

  static Map<String, dynamic> record(CampusDormCheck c) {
    final bed = bedOf(c.personIndex);
    final handle = _handles()[c.key];
    final handled = handle is Map
        ? (handle['handleStatus'] as num?)?.toInt() ?? 0
        : (c.abnormal && c.day.isBefore(CampusA.daysAgo(1)) ? 1 : 0);
    final handleRemark = handle is Map
        ? handle['handleRemark']?.toString() ?? ''
        : (handled == 1 ? '宿管已与班主任核实并登记' : '');
    return <String, dynamic>{
      'id': c.id,
      'checkId': c.id,
      ..._studentFields(c.personIndex),
      ...?(bed == null ? null : _placeFields(bed)),
      'checkDate': CampusA.date(c.day),
      'checkType': sessionName(c.session),
      'checkDeadline': deadlineLabel(c.session),
      'checkTime': c.checkTime,
      'status': c.status,
      'statusText': c.pending ? '待查寝' : c.status,
      'remark': c.remark,
      'anomalyReason': c.abnormal ? c.remark : '',
      'handleStatus': c.abnormal ? handled : 0,
      'handleStatusText': handled == 1 ? '已处理' : '待处理',
      'handleRemark': handleRemark,
    };
  }

  /// [from]–[to] 已结束（或已打卡）的查寝结果，日期倒序、晚查寝在前。
  static List<CampusDormCheck> checks({
    required DateTime from,
    required DateTime to,
    required Iterable<int> people,
  }) {
    final now = DateTime.now();
    final today = CampusA.dayOf(now);
    final last = to.isAfter(today) ? today : to;
    final floor = today.subtract(const Duration(days: 90));
    final list = <CampusDormCheck>[];
    var day = last;
    final start = from.isBefore(floor) ? floor : from;
    while (!day.isBefore(start)) {
      for (final session in const [1, 2]) {
        for (final index in people) {
          final c = check(day, session, index, now);
          if (!c.pending) {
            list.add(c);
          }
        }
      }
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return list;
  }

  static ({DateTime from, DateTime to}) _range(
    DemoRequest req,
    int fallbackDays,
  ) {
    final today = CampusA.today();
    final to = CampusA.parseDay(req.str('endDate')) ?? today;
    final from =
        CampusA.parseDay(req.str('beginDate')) ??
        to.subtract(Duration(days: fallbackDays));
    return (from: from, to: to);
  }

  static bool _statusMatches(CampusDormCheck c, String status) {
    if (status.isEmpty) return true;
    if (status == '异常') return c.abnormal;
    if (status == '正常') return c.status == '正常';
    if (status == '晚归' || status == '迟到') return c.status == '晚归';
    return c.status == status;
  }

  // ── 补卡 ────────────────────────────────────────────────────────────

  static List<Map<String, dynamic>> makeupList() =>
      DemoStore.list(_makeupKey, _seedMakeups);

  static List<Map<String, dynamic>> _seedMakeups() {
    Map<String, dynamic> seed(
      String id,
      int index,
      int daysAgo,
      int session,
      String reason,
      int status, [
      String audit = '',
    ]) {
      final day = CampusA.daysAgo(daysAgo);
      final created = CampusA.at(
        day.add(Duration(days: session == 1 ? 1 : 0)),
        session == 1 ? '07:50' : '08:10',
      );
      return <String, dynamic>{
        'id': id,
        'personIndex': index,
        'checkDate': CampusA.date(day),
        'checkType': sessionName(session),
        'reason': reason,
        'attachment': '',
        'status': status,
        'statusText': const ['待审批', '已通过', '已驳回'][status],
        'auditReason': audit,
        'approverName': status == 0 ? '' : '马红梅',
        'createTime': CampusA.dateTime(created),
        'auditTime': status == 0
            ? ''
            : CampusA.dateTime(created.add(const Duration(hours: 2))),
        'seeded': true,
      };
    }

    return [
      seed('5503', 7, 1, 1, '画室加练忘记打卡，22:10 已回寝，室友可以作证', 0),
      seed('5505', 19, 1, 2, '身体不适在寝室休息，未下楼刷脸', 0),
      seed('5504', 12, 2, 2, '早起去画室占位置，出门前忘记刷脸', 0),
      seed('5501', 1, 6, 2, '早上人脸识别一直失败，马老师现场确认我在寝室', 0),
      seed('5507', 24, 3, 1, '打卡设备离线，22:05 已回寝', 1, '已核实设备离线记录，同意补卡'),
      seed('5506', 5, 4, 1, '外出取快递晚归', 2, '晚归超过 30 分钟且未提前报备，不予补卡'),
      seed('5502', 1, 12, 1, '晚自习改画到 22:20，回寝后打卡设备离线', 1, '已核实打卡设备离线，同意补卡'),
    ];
  }

  static Map<String, dynamic> makeupRow(Map<String, dynamic> m) {
    final index = (m['personIndex'] as num).toInt();
    final bed = bedOf(index);
    return <String, dynamic>{
      ..._studentFields(index),
      ...?(bed == null ? null : _placeFields(bed)),
      'id': m['id'],
      'checkDate': m['checkDate'],
      'checkType': m['checkType'],
      'reason': m['reason'],
      'attachment': (m['attachment']?.toString() ?? '').isEmpty
          ? ''
          : CampusA.media(m['attachment'].toString()),
      'status': m['status'],
      'statusText': m['statusText'],
      'auditReason': m['auditReason'],
      'approveRemark': m['auditReason'],
      'approverName': m['approverName'],
      'createTime': m['createTime'],
      'applyTime': m['createTime'],
      'auditTime': m['auditTime'],
      'approveTime': m['auditTime'],
    };
  }

  static List<Map<String, dynamic>> _makeupRows({
    Iterable<int>? people,
    int? status,
    String? buildingId,
  }) {
    final set = people?.toSet();
    final list = [
      for (final m in makeupList())
        if ((set == null || set.contains((m['personIndex'] as num).toInt())) &&
            (status == null || m['status'] == status) &&
            (buildingId == null ||
                buildingIdOf(
                      bedOf((m['personIndex'] as num).toInt())?.building ?? '',
                    ) ==
                    buildingId))
          makeupRow(m),
    ]..sort(CampusA.compareTimeDesc);
    return list;
  }

  static Map<String, dynamic> _audit(DemoAccount account, DemoRequest req) {
    final item = CampusA.findById(makeupList(), req.str('id'));
    if (item == null) {
      throw const DemoApiException('补卡申请不存在');
    }
    if (item['status'] != 0) {
      throw const DemoApiException('该补卡申请已处理');
    }
    final status = req.intOf('status');
    if (status != 1 && status != 2) {
      throw const DemoApiException('审批结果无效');
    }
    final reason = req.str('auditReason');
    item
      ..['status'] = status
      ..['statusText'] = status == 1 ? '已通过' : '已驳回'
      ..['auditReason'] = reason.isNotEmpty
          ? reason
          : (status == 1 ? '情况属实，同意补卡' : '理由不充分，不予补卡')
      ..['approverName'] = CampusA.displayName(account)
      ..['auditTime'] = CampusA.dateTime(DateTime.now());
    DemoStore.save(_makeupKey);
    return item;
  }

  // ── 统计 ────────────────────────────────────────────────────────────

  static Iterable<int> get _allPeople =>
      DemoCampusData.beds.map((b) => b.personIndex);

  static ({int beds, int normal, int late, int notChecked}) _sessionStat(
    Iterable<int> people,
    DateTime day,
    int session,
  ) {
    final now = DateTime.now();
    var normal = 0;
    var late = 0;
    var notChecked = 0;
    var beds = 0;
    for (final index in people) {
      beds++;
      final c = check(day, session, index, now);
      switch (c.status) {
        case '正常':
          normal++;
        case '晚归':
          late++;
        default:
          notChecked++;
      }
    }
    return (beds: beds, normal: normal, late: late, notChecked: notChecked);
  }

  static const _duties = <(String, String, String, String)>[
    ('晨查寝', '两栋公寓晨间查寝 + 人脸核验', '06:40', '07:20'),
    ('午间巡查', '午休纪律巡查（1 层走廊与公共区域）', '12:30', '13:30'),
    ('安全检查', '宿舍用电安全检查（违规电器排查）', '16:00', '17:00'),
    ('晚查寝', '两栋公寓晚间查寝 + 晚归登记', '21:30', '22:30'),
    ('熄灯巡查', '熄灯后楼层巡查，关闭公共区域照明', '23:00', '23:30'),
  ];

  static Map<String, dynamic> _index() {
    final now = DateTime.now();
    final today = CampusA.dayOf(now);
    final batch = latestBatch(now);
    final stat = _sessionStat(_allPeople, batch.day, batch.session);
    final recent = checks(
      from: CampusA.daysAgo(1),
      to: today,
      people: _allPeople,
    );
    final unhandled = recent
        .where((c) => c.abnormal && record(c)['handleStatus'] == 0)
        .length;
    final duties = [
      for (final d in _duties)
        <String, dynamic>{
          'checkType': d.$1,
          'title': d.$2,
          'timeFrom': d.$3,
          'timeTo': d.$4,
        },
    ];
    final clock = CampusA.hm(now);
    Map<String, dynamic>? current;
    for (final d in duties) {
      if (clock.compareTo(d['timeTo'].toString()) <= 0) {
        current = d;
        break;
      }
    }
    return <String, dynamic>{
      'managedBuildingCount': 2,
      'totalBedCount': DemoCampusData.beds.length,
      'todayNormalCount': stat.normal,
      'todayLateCount': stat.late,
      'todayAbsentCount': stat.notChecked,
      'checkType': sessionName(batch.session),
      'checkDate': CampusA.date(batch.day),
      'pendingMakeupCount': makeupList().where((m) => m['status'] == 0).length,
      'unhandledExceptionCount': unhandled,
      'managedAreaList': [
        for (final b in _buildings())
          <String, dynamic>{'buildingName': b['buildingName']},
      ],
      'currentTask': current ?? duties.first,
      'todayDutyList': duties,
    };
  }

  static List<Map<String, dynamic>> _buildings() {
    final map = <String, Map<String, dynamic>>{};
    for (final bed in DemoCampusData.beds) {
      final id = buildingIdOf(bed.building);
      final entry = map.putIfAbsent(
        id,
        () => <String, dynamic>{
          'buildingId': id,
          'buildingName': bed.building,
          'rooms': <String>{},
          'floors': <String>{},
          'assignedBedCount': 0,
        },
      );
      (entry['rooms'] as Set<String>).add(roomIdOf(bed));
      (entry['floors'] as Set<String>).add(floorIdOf(bed));
      entry['assignedBedCount'] = (entry['assignedBedCount'] as int) + 1;
    }
    return [
      for (final e in map.values)
        <String, dynamic>{
          'buildingId': e['buildingId'],
          'buildingName': e['buildingName'],
          'roomCount': (e['rooms'] as Set<String>).length,
          'floorCount': (e['floors'] as Set<String>).length,
          'bedCount': (e['rooms'] as Set<String>).length * 4,
          'assignedBedCount': e['assignedBedCount'],
          'managerName': '马红梅',
        },
    ];
  }

  static List<Map<String, dynamic>> _rooms(
    DateTime day, {
    String? buildingId,
    String? floorId,
  }) {
    final now = DateTime.now();
    final session = currentSession(day, now);
    final grouped = <String, List<DemoDormBed>>{};
    for (final bed in _beds(buildingId: buildingId, floorId: floorId)) {
      grouped.putIfAbsent(roomIdOf(bed), () => <DemoDormBed>[]).add(bed);
    }
    return [
      for (final entry in grouped.entries)
        () {
          final beds = entry.value..sort((a, b) => a.bed.compareTo(b.bed));
          final users = [
            for (final bed in beds)
              () {
                final c = check(day, session, bed.personIndex, now);
                return <String, dynamic>{
                  ..._studentFields(bed.personIndex),
                  'bedName': '${bed.bed}号床',
                  'status': c.status,
                  'checkStatus': c.status,
                  'checkTime': c.checkTime,
                };
              }(),
          ];
          return <String, dynamic>{
            ..._placeFields(beds.first),
            'checkType': sessionName(session),
            'checkDate': CampusA.date(day),
            'checkDeadline': deadlineLabel(session),
            'allChecked': users.every((u) => u['status'] != '未打卡'),
            'userList': users,
          };
        }(),
    ]..sort((a, b) => a['roomId'].toString().compareTo(b['roomId'].toString()));
  }

  static void _setStatus(
    DateTime day,
    int session,
    int index,
    String status,
    DemoAccount account,
  ) {
    final now = DateTime.now();
    _overrides()['${CampusA.date(day)}|$session|$index'] = <String, dynamic>{
      'status': status,
      'checkTime': status == '正常' || status == '晚归' ? CampusA.hm(now) : '',
      'remark': switch (status) {
        '晚归' => '宿管${CampusA.displayName(account)}登记晚归',
        '缺勤' => '未归寝，已通知班主任',
        '未打卡' => '',
        _ => '',
      },
    };
  }

  static String? _optional(DemoRequest req, String key) {
    final value = req.str(key);
    return value.isEmpty ? null : value;
  }

  static Iterable<int> _classPeople(String classId) => CampusA.studentsOf(
    classId,
  ).map((p) => p.index).where((i) => bedOf(i) != null);

  /// 学生最近一次已有结果的查寝（班级查寝动态）。
  static CampusDormCheck _latest(int index, DateTime now) {
    final today = CampusA.dayOf(now);
    for (var back = 0; back < 3; back++) {
      final day = today.subtract(Duration(days: back));
      for (final session in const [1, 2]) {
        final c = check(day, session, index, now);
        if (!c.pending) {
          return c;
        }
      }
    }
    return check(today.subtract(const Duration(days: 1)), 1, index, now);
  }

  static Uint8List _export(DemoRequest req) {
    final range = _range(req, 0);
    final status = req.str('status');
    final beds = _beds(
      buildingId: _optional(req, 'buildingId'),
      floorId: _optional(req, 'floorId'),
      roomId: _optional(req, 'roomId'),
    );
    final list = checks(
      from: range.from,
      to: range.to,
      people: beds.map((b) => b.personIndex),
    ).where((c) => _statusMatches(c, status)).toList();
    if (list.isEmpty) {
      return Uint8List(0);
    }
    return CampusAXlsx.build(
      sheetName: '查寝记录',
      rows: [
        const [
          '查寝日期',
          '场次',
          '宿舍楼',
          '楼层',
          '宿舍',
          '床位',
          '学生',
          '学号',
          '班级',
          '查寝状态',
          '打卡时间',
          '备注',
          '处理状态',
        ],
        for (final c in list)
          () {
            final r = record(c);
            return [
              r['checkDate'].toString(),
              r['checkType'].toString(),
              r['buildingName']?.toString() ?? '',
              r['floorName']?.toString() ?? '',
              r['roomName']?.toString() ?? '',
              r['bedName']?.toString() ?? '',
              r['studentName'].toString(),
              r['studentNo'].toString(),
              r['className'].toString(),
              r['status'].toString(),
              r['checkTime'].toString().isEmpty
                  ? '—'
                  : r['checkTime'].toString(),
              r['remark'].toString(),
              c.abnormal ? r['handleStatusText'].toString() : '—',
            ];
          }(),
      ],
    );
  }

  // ── 接口 ────────────────────────────────────────────────────────────

  static void register(DemoRouter r) {
    _registerStudent(r);
    _registerManager(r);
    _registerClass(r);
  }

  static void _registerStudent(DemoRouter r) {
    const base = '/app/school/v2/student';

    r.post('$base/myDormitoryInfo', (req) {
      final index = CampusA.personIndexOf(req.account);
      final bed = bedOf(index);
      if (bed == null) {
        return <String, dynamic>{};
      }
      final manager = CampusA.staff('d-1');
      return <String, dynamic>{
        ..._placeFields(bed),
        'checkInDate': '2026-07-12',
        'roommates': [
          for (final other in _beds(roomId: roomIdOf(bed)))
            if (other.personIndex != index)
              CampusA.person(other.personIndex).name,
        ],
        'dormManager': manager.name,
        'dormManagerPhone': manager.phone,
      };
    });

    r.post('$base/dormitoryCheckStat', (req) {
      final index = CampusA.personIndexOf(req.account);
      final range = _range(req, 30);
      final list = checks(from: range.from, to: range.to, people: [index]);
      return <String, dynamic>{
        'totalCount': list.length,
        'normalCount': list.where((c) => c.status == '正常').length,
        'lateCount': list.where((c) => c.status == '晚归').length,
        'absentCount': list
            .where((c) => c.status != '正常' && c.status != '晚归')
            .length,
        'pendingMakeupCount': makeupList()
            .where((m) => m['personIndex'] == index && m['status'] == 0)
            .length,
      };
    });

    r.post('$base/dormitoryCheckHistory', (req) {
      final index = CampusA.personIndexOf(req.account);
      final range = _range(req, 30);
      final status = req.str('status');
      final list = [
        for (final c in checks(from: range.from, to: range.to, people: [index]))
          if (_statusMatches(c, status)) record(c),
      ];
      return CampusA.page(list, req);
    });

    r.post('$base/dormitoryCheckDetail', (req) {
      final c = checkById(req.str('id'), DateTime.now());
      if (c == null) {
        throw const DemoApiException('查寝记录不存在');
      }
      return record(c);
    });

    r.post('$base/dormitoryMakeupSave', (req) {
      final account = req.account;
      final index = CampusA.personIndexOf(account);
      final day = CampusA.parseDay(req.str('date'));
      final checkType = req.str('checkType', '晚查寝');
      final reason = req.str('reason');
      if (day == null || day.isAfter(CampusA.today())) {
        throw const DemoApiException('请选择需要补卡的日期');
      }
      if (reason.isEmpty) {
        throw const DemoApiException('请填写补卡原因');
      }
      final session = sessionOf(checkType);
      final duplicated = makeupList().any(
        (m) =>
            m['personIndex'] == index &&
            m['checkDate'] == CampusA.date(day) &&
            sessionOf(m['checkType'].toString()) == session &&
            m['status'] != 2,
      );
      if (duplicated) {
        throw const DemoApiException('该场次已提交过补卡申请');
      }
      makeupList().insert(0, <String, dynamic>{
        'id': DemoStore.nextId(),
        'personIndex': index,
        'checkDate': CampusA.date(day),
        'checkType': sessionName(session),
        'reason': reason,
        'attachment': CampusA.toRef(req.str('attachment')),
        'status': 0,
        'statusText': '待审批',
        'auditReason': '',
        'approverName': '',
        'createTime': CampusA.dateTime(DateTime.now()),
        'auditTime': '',
      });
      DemoStore.save(_makeupKey);
      return true;
    });

    r.post('$base/dormitoryMakeupList', (req) {
      final index = CampusA.personIndexOf(req.account);
      final status = req.value('status') == null ? null : req.intOf('status');
      return CampusA.page(_makeupRows(people: [index], status: status), req);
    });

    r.post('$base/dormitoryMakeupDetail', (req) {
      final item = CampusA.findById(makeupList(), req.str('id'));
      if (item == null) {
        throw const DemoApiException('补卡申请不存在');
      }
      return makeupRow(item);
    });

    r.post('$base/dormitoryMakeupCancel', (req) {
      final index = CampusA.personIndexOf(req.account);
      final list = makeupList();
      final item = CampusA.findById(list, req.str('id'));
      if (item == null || item['personIndex'] != index) {
        throw const DemoApiException('补卡申请不存在');
      }
      if (item['status'] != 0) {
        throw const DemoApiException('已审批的申请不能撤销');
      }
      list.remove(item);
      DemoStore.save(_makeupKey);
      return true;
    });
  }

  static void _registerManager(DemoRouter r) {
    const base = '/app/school/v2/dormitory';

    r.post('$base/noticeList', (req) {
      return CampusA.page([
        for (final n in CampusANotices.forScope('dormitory'))
          CampusANotices.row(n),
      ], req);
    });

    r.post('$base/noticeDetail', (req) {
      final notice = CampusA.findById(CampusANotices.all(), req.str('id'));
      if (notice == null) {
        throw const DemoApiException('通知不存在或已撤回');
      }
      return CampusANotices.row(notice);
    });

    r.post('$base/index', (req) => _index());

    r.post('$base/dormitoryManagedBuildingList', (req) => _buildings());

    r.post('$base/dormitoryFloorList', (req) {
      final buildingId = req.str('buildingId');
      final floors = <String, Map<String, dynamic>>{};
      for (final bed in _beds(buildingId: buildingId)) {
        final entry = floors.putIfAbsent(
          floorIdOf(bed),
          () => <String, dynamic>{
            'floorId': floorIdOf(bed),
            'floorName': bed.floor,
            'buildingId': buildingId,
            'rooms': <String>{},
            'assignedBedCount': 0,
          },
        );
        (entry['rooms'] as Set<String>).add(roomIdOf(bed));
        entry['assignedBedCount'] = (entry['assignedBedCount'] as int) + 1;
      }
      return [
        for (final f in floors.values)
          <String, dynamic>{
            'floorId': f['floorId'],
            'floorName': f['floorName'],
            'buildingId': f['buildingId'],
            'roomCount': (f['rooms'] as Set<String>).length,
            'assignedBedCount': f['assignedBedCount'],
          },
      ];
    });

    r.post('$base/dormitoryCheckStat', (req) {
      final now = DateTime.now();
      final today = CampusA.dayOf(now);
      final session = currentSession(today, now);
      final stat = _sessionStat(_allPeople, today, session);
      return <String, dynamic>{
        'bedCount': stat.beds,
        'normalCount': stat.normal,
        'lateCount': stat.late,
        'notCheckedCount': stat.notChecked,
        'checkType': sessionName(session),
        'checkDeadline': deadlineLabel(session),
      };
    });

    r.post('$base/dormitoryCheckRoomList', (req) {
      final day = CampusA.parseDay(req.str('date')) ?? CampusA.today();
      return _rooms(
        day,
        buildingId: _optional(req, 'buildingId'),
        floorId: _optional(req, 'floorId'),
      );
    });

    r.post('$base/dormitoryCheckRoomOneClick', (req) {
      final account = req.account;
      final now = DateTime.now();
      final day = CampusA.parseDay(req.str('date')) ?? CampusA.dayOf(now);
      final session = currentSession(day, now);
      final beds = _beds(roomId: req.str('roomId'));
      if (beds.isEmpty) {
        throw const DemoApiException('宿舍不存在');
      }
      for (final bed in beds) {
        if (check(day, session, bed.personIndex, now).status == '未打卡') {
          _setStatus(day, session, bed.personIndex, '正常', account);
        }
      }
      DemoStore.save(_overrideKey);
      return true;
    });

    r.post('$base/dormitoryCheckUserUpdate', (req) {
      final account = req.account;
      final now = DateTime.now();
      final index = CampusA.personIndexById(req.str('userId'));
      if (index == null || bedOf(index) == null) {
        throw const DemoApiException('未找到该住宿生');
      }
      final status = req.str('status', '正常');
      if (!const ['正常', '晚归', '未打卡', '缺勤'].contains(status)) {
        throw const DemoApiException('查寝状态无效');
      }
      final day = CampusA.parseDay(req.str('date')) ?? CampusA.dayOf(now);
      _setStatus(day, currentSession(day, now), index, status, account);
      DemoStore.save(_overrideKey);
      return true;
    });

    r.post('$base/dormitoryCheckHistory', (req) {
      final range = _range(req, 0);
      final beds = _beds(
        buildingId: _optional(req, 'buildingId'),
        floorId: _optional(req, 'floorId'),
        roomId: _optional(req, 'roomId'),
      );
      final status = req.str('status');
      final list = [
        for (final c in checks(
          from: range.from,
          to: range.to,
          people: beds.map((b) => b.personIndex),
        ))
          if (_statusMatches(c, status)) record(c),
      ];
      return CampusA.page(list, req);
    });

    r.post('$base/dormitoryCheckDetail', (req) {
      final c = checkById(req.str('id'), DateTime.now());
      if (c == null) {
        throw const DemoApiException('查寝记录不存在');
      }
      return record(c);
    });

    r.post('$base/dormitoryCheckExceptionHandle', (req) {
      final account = req.account;
      final c = checkById(req.str('checkId'), DateTime.now());
      if (c == null) {
        throw const DemoApiException('查寝记录不存在');
      }
      final remark = req.str('remark');
      _handles()[c.key] = <String, dynamic>{
        'handleStatus': req.intOf('handleStatus', 1),
        'handleRemark': remark.isEmpty
            ? '${CampusA.displayName(account)}已核实处理'
            : remark,
        'handleTime': CampusA.dateTime(DateTime.now()),
      };
      DemoStore.save(_handleKey);
      return true;
    });

    r.get('$base/dormitoryCheckExport', (req) => DemoBytes(_export(req)));

    r.post('$base/dormitoryMakeupList', (req) {
      final status = req.value('status') == null ? null : req.intOf('status');
      return CampusA.page(
        _makeupRows(status: status, buildingId: _optional(req, 'buildingId')),
        req,
      );
    });

    r.post('$base/dormitoryMakeupDetail', (req) {
      final item = CampusA.findById(makeupList(), req.str('id'));
      if (item == null) {
        throw const DemoApiException('补卡申请不存在');
      }
      return makeupRow(item);
    });

    r.post('$base/dormitoryMakeupAudit', (req) {
      _audit(req.account, req);
      return true;
    });
  }

  static void _registerClass(DemoRouter r) {
    const base = '/app/school/v2/dormitory';

    r.post('$base/classDormitoryDynamicList', (req) {
      final now = DateTime.now();
      final status = req.str('status');
      final list = [
        for (final index in _classPeople(req.str('classId')))
          () {
            final c = _latest(index, now);
            return (c, record(c));
          }(),
      ];
      return CampusA.page([
        for (final item in list)
          if (_statusMatches(item.$1, status)) item.$2,
      ], req);
    });

    r.post('$base/classDormitoryCheckStat', (req) {
      final people = _classPeople(req.str('classId')).toList();
      final range = _range(req, 0);
      final list = checks(from: range.from, to: range.to, people: people);
      final set = people.toSet();
      return <String, dynamic>{
        'studentCount': people.length,
        'normalCount': list.where((c) => c.status == '正常').length,
        'lateCount': list.where((c) => c.status == '晚归').length,
        'absentCount': list
            .where((c) => c.status != '正常' && c.status != '晚归')
            .length,
        'makeupApprovedCount': makeupList()
            .where(
              (m) =>
                  m['status'] == 1 &&
                  set.contains((m['personIndex'] as num).toInt()),
            )
            .length,
      };
    });

    r.post('$base/classDormitoryCheckHistory', (req) {
      final range = _range(req, 0);
      final status = req.str('status');
      final student = CampusA.personIndexById(req.str('studentId'));
      final people = student == null
          ? _classPeople(req.str('classId')).toList()
          : [student];
      final list = [
        for (final c in checks(from: range.from, to: range.to, people: people))
          if (_statusMatches(c, status)) record(c),
      ];
      return CampusA.page(list, req);
    });

    r.post('$base/classDormitoryCheckDetail', (req) {
      final c = checkById(req.str('id'), DateTime.now());
      if (c == null) {
        throw const DemoApiException('查寝记录不存在');
      }
      return record(c);
    });

    r.post('$base/classDormitoryMakeupList', (req) {
      final status = req.value('status') == null ? null : req.intOf('status');
      return CampusA.page(
        _makeupRows(people: _classPeople(req.str('classId')), status: status),
        req,
      );
    });

    r.post('$base/classDormitoryMakeupDetail', (req) {
      final item = CampusA.findById(makeupList(), req.str('id'));
      if (item == null) {
        throw const DemoApiException('补卡申请不存在');
      }
      return makeupRow(item);
    });

    r.post('$base/classDormitoryMakeupAudit', (req) {
      _audit(req.account, req);
      return true;
    });
  }
}
