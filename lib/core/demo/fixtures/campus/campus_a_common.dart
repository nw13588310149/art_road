import '../../data/demo_campus_data.dart';
import '../../data/demo_marking_data.dart';
import '../../demo_accounts.dart';
import '../../demo_backend.dart';
import '../../demo_clock.dart';
import '../../media/demo_media.dart';
import 'campus_b_common.dart';
import 'campus_b_records.dart';

/// 智慧校园演示接口（学生 / 群聊 / 宿管 / 信箱）共用的日期、身份与媒体工具。
///
/// 学生沿用 [DemoMarkingData.persons]，班级、教职工、宿舍沿用
/// [DemoCampusData]，各接口看到的是同一批人。
abstract final class CampusA {
  static DemoMarkingData get data => DemoMarkingData.instance;

  // ── 日期 ────────────────────────────────────────────────────────────

  static String two(int value) => value.toString().padLeft(2, '0');

  static String date(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

  static String dateTime(DateTime d) =>
      '${date(d)} ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';

  static String hm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

  static String compact(DateTime d) => '${d.year}${two(d.month)}${two(d.day)}';

  static DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime today() => dayOf(DateTime.now());

  static DateTime daysAgo(int days) =>
      today().subtract(Duration(days: days));

  static DateTime? parseDay(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return null;
    }
    final parsed = DateTime.tryParse(text);
    return parsed == null ? null : dayOf(parsed);
  }

  static DateTime? parseDateTime(String raw) => DateTime.tryParse(raw.trim());

  /// `HH:mm` 落到指定日期。
  static DateTime at(DateTime day, String clock) {
    final parts = clock.split(':');
    return DateTime(
      day.year,
      day.month,
      day.day,
      int.tryParse(parts.first) ?? 0,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  /// 「现在往前推」的时间点（列表种子用）：以 [DemoClock.now] 为基准，只在白天
  /// 里往前数，秒数归零，不会出现凌晨或未来时间（见 [cbAgo]）。
  static String ago({int days = 0, int hours = 0, int minutes = 0}) =>
      dateTime(cbAgo(Duration(hours: hours, minutes: minutes), days: days));

  /// [daysAgo] 天前的固定时刻 `HH:mm`；晚于 [DemoClock.now] 时逐日前移。
  static DateTime pastAt(int daysAgo, String clock) {
    final limit = DemoClock.now();
    var t = at(today().subtract(Duration(days: daysAgo)), clock);
    while (t.isAfter(limit)) {
      t = t.subtract(const Duration(days: 1));
    }
    return t;
  }

  /// 某月第三个周日（月考惯例日期，与学情中心 4–10 月考试一致）。
  static DateTime thirdSunday(int year, int month) {
    final first = DateTime(year, month);
    final offset = (DateTime.sunday - first.weekday) % 7;
    return DateTime(year, month, 1 + offset + 14);
  }

  /// 下一场月考：本月第三个周日未过则取本月，否则取下月。
  static DateTime nextMonthlyExamDay() {
    final now = today();
    final current = thirdSunday(now.year, now.month);
    if (!current.isBefore(now)) {
      return current;
    }
    return thirdSunday(
      now.month == 12 ? now.year + 1 : now.year,
      now.month == 12 ? 1 : now.month + 1,
    );
  }

  /// 甘肃省美术统考：12 月第一个周日。
  static DateTime unifiedExamDay() {
    final now = today();
    DateTime firstSunday(int year) {
      final first = DateTime(year, 12);
      return DateTime(year, 12, 1 + (DateTime.sunday - first.weekday) % 7);
    }

    final thisYear = firstSunday(now.year);
    return thisYear.isBefore(now) ? firstSunday(now.year + 1) : thisYear;
  }

  /// 与平台无关的稳定散列，Web 与原生生成同一份演示数据。
  static int hash(String key) {
    var h = 7;
    for (final unit in key.codeUnits) {
      h = (h * 131 + unit) % 1000000007;
    }
    return h;
  }

  // ── 学生 ────────────────────────────────────────────────────────────

  static List<DemoPerson> get persons => data.persons;

  static DemoPerson person(int index) => data.person(index);

  /// 学生端接口：教职工切到「学生端」视角时按演示学生林小雨展示。
  static int personIndexOf(DemoAccount account) =>
      account.personIndex ?? DemoAccounts.student.personIndex ?? 1;

  /// 平台用户 id：演示学生与 `myInfo` 一致，其余学生按序号派生，
  /// 须与教师端 / 管理端演示接口的派生规则保持一致。
  static String studentUserId(int index) =>
      index == DemoAccounts.student.personIndex
      ? DemoAccounts.student.userId
      : '18800000001${index.toString().padLeft(8, '0')}';

  static String studentNo(int index) =>
      '2027${index.toString().padLeft(3, '0')}';

  /// 按档案 id / 平台 id / 学号还原学生序号。
  static int? personIndexById(String raw) {
    final id = raw.trim();
    if (id.isEmpty) {
      return null;
    }
    for (final p in persons) {
      if (p.archiveId == id ||
          studentUserId(p.index) == id ||
          studentNo(p.index) == id) {
        return p.index;
      }
    }
    return null;
  }

  static String avatarUrl(int index) => DemoMedia.url(person(index).avatarRef);

  static DemoCampusClass classOf(int index) =>
      DemoCampusData.classOfPerson(index);

  /// 班级学生；未知班级 id 时返回全部学生，避免页面空白。
  static List<DemoPerson> studentsOf(String classId) =>
      DemoCampusData.classById(classId)?.students ?? persons;

  static const _targetSchools = <String>[
    '中国美术学院',
    '西安美术学院',
    '四川美术学院',
    '中央美术学院',
    '广州美术学院',
    '湖北美术学院',
    '鲁迅美术学院',
    '天津美术学院',
    '西北师范大学美术学院',
    '清华大学美术学院',
  ];

  static String targetSchool(int index) => index == 1
      ? '西安美术学院'
      : _targetSchools[(index * 3) % _targetSchools.length];

  static const _classRoles = <int, String>{
    3: '班长',
    6: '学习委员',
    9: '画室管理员',
    12: '宣传委员',
    4: '班长',
    7: '学习委员',
    5: '班长',
    8: '画室管理员',
  };

  static String classRole(int index) => _classRoles[index] ?? '';

  // ── 教职工 ──────────────────────────────────────────────────────────

  static DemoCampusStaff staff(String id) =>
      DemoCampusData.staffById(id) ?? DemoCampusData.staff.first;

  static DemoCampusStaff headTeacherOf(DemoCampusClass c) =>
      staff(c.headTeacherId);

  /// 班级任课老师（按 [DemoCampusStaff.classIds]）。
  static List<DemoCampusStaff> teachersOf(DemoCampusClass c) => [
    for (final s in DemoCampusData.staff)
      if (s.classIds.contains(c.id)) s,
  ];

  static const _staffIntro = <String, String>{
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

  static String staffIntro(DemoCampusStaff s) =>
      _staffIntro[s.id] ?? '示范画室教学团队成员。';

  static String staffEmail(DemoCampusStaff s) =>
      'art${s.phone.substring(s.phone.length - 4)}@shifanhuashi.cn';

  /// 教职工的平台资料（`teacherList` / `headTeacher` 等嵌套对象）。
  static Map<String, dynamic> staffUser(DemoCampusStaff s) => <String, dynamic>{
    'id': s.userId,
    'userId': s.userId,
    'realname': s.name,
    'nickname': s.name,
    'gender': s.gender,
    'mobile': s.phone,
    'email': staffEmail(s),
    'headUrl': '',
    'introduce': staffIntro(s),
    'subjectName': s.subject,
    'courseTag': s.subject,
  };

  // ── 当前账号 ────────────────────────────────────────────────────────

  static bool isStudent(DemoAccount account) =>
      account.role == DemoRole.student;

  static String displayName(DemoAccount account) => isStudent(account)
      ? person(personIndexOf(account)).name
      : account.name;

  static String headRefOf(DemoAccount account) =>
      isStudent(account) ? person(personIndexOf(account)).avatarRef : '';

  // ── 媒体 ────────────────────────────────────────────────────────────

  static String media(String ref) => DemoMedia.url(ref);

  /// 上传接口回来的绝对地址转回可持久化的引用（去掉易变的本地服务端口）。
  static String toRef(String url) {
    final value = url.trim();
    final base = DemoMedia.fileBaseUrl;
    if (base.isEmpty || !value.startsWith(base)) {
      return value;
    }
    final rest = value.substring(base.length);
    return rest.startsWith('/') ? rest.substring(1) : rest;
  }

  static String fileNameOf(String path) {
    final clean = path.split('?').first;
    final index = clean.lastIndexOf('/');
    return index >= 0 ? clean.substring(index + 1) : clean;
  }

  // ── 工具 ────────────────────────────────────────────────────────────

  static Map<String, dynamic> page(List<Object?> all, DemoRequest req) =>
      demoPage(all, req);

  static Map<String, dynamic>? findById(
    List<Map<String, dynamic>> list,
    String id,
  ) {
    for (final item in list) {
      if (item['id']?.toString() == id) {
        return item;
      }
    }
    return null;
  }

  static int compareTimeDesc(
    Map<String, dynamic> a,
    Map<String, dynamic> b, [
    String key = 'createTime',
  ]) => (b[key]?.toString() ?? '').compareTo(a[key]?.toString() ?? '');
}

/// 校级通知：与老师端、管理端读同一份（[cbNotices]），管理员发布或撤回后
/// 学生端、宿管端同步看到。
abstract final class CampusANotices {
  static List<Map<String, dynamic>> all() => [
    for (final n in cbNotices()) cbNoticeJson(n),
  ];

  /// 推送范围包含 [scope]（student / dormitory / ...）的已发布通知，按发布时间倒序。
  static List<Map<String, dynamic>> forScope(String scope) => [
    for (final n in cbSortedNotices())
      if (cbNoticeStatus(n) == 1 &&
          (n['pushScope']?.toString() ?? '').split(',').contains(scope))
        cbNoticeJson(n),
  ];

  /// 通知行（`parseAdminNoticeList` 结构）。
  static Map<String, dynamic> row(Map<String, dynamic> n) =>
      Map<String, dynamic>.from(n);
}
