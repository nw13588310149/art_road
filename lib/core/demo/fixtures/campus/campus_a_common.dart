import '../../data/demo_campus_data.dart';
import '../../data/demo_marking_data.dart';
import '../../demo_accounts.dart';
import '../../demo_backend.dart';
import '../../demo_store.dart';
import '../../media/demo_media.dart';

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

  /// 「现在往前推」的时间点（列表种子用）。
  static String ago({int days = 0, int hours = 0, int minutes = 0}) =>
      dateTime(
        DateTime.now().subtract(
          Duration(days: days, hours: hours, minutes: minutes),
        ),
      );

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

/// 校级通知（学生端 / 宿管端首页通知列表共用一份）。
abstract final class CampusANotices {
  static const _key = 'campusA:schoolNotices';

  static List<Map<String, dynamic>> all() => DemoStore.list(_key, _seed);

  /// 推送范围包含 [scope]（student / dormitory / ...）的已发布通知，按发布时间倒序。
  static List<Map<String, dynamic>> forScope(String scope) {
    final list = [
      for (final n in all())
        if ((n['pushScope']?.toString() ?? '').split(',').contains(scope))
          n,
    ]..sort((a, b) => CampusA.compareTimeDesc(a, b, 'publishedAt'));
    return list;
  }

  static List<Map<String, dynamic>> _seed() {
    final exam = CampusA.nextMonthlyExamDay();
    final unified = CampusA.unifiedExamDay();
    final examLabel = '${exam.month} 月 ${exam.day} 日（周日）';
    final days = unified.difference(CampusA.today()).inDays;
    Map<String, dynamic> notice({
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
      'creator': creator,
      'deptName': dept,
      'status': 1,
      'publishMode': 1,
      'publishedAt': time,
      'createTime': time,
      'updateTime': time,
    };

    return [
      notice(
        id: '8101',
        title: '${exam.month} 月月考安排',
        content:
            '$examLabel举行${exam.month} 月月考，科目为素描（08:30—11:30）、色彩（13:30—16:30）、速写（17:00—18:00）。请各班于考前一天完成考场布置，考生凭准考证入场，画具自备。',
        type: '通知',
        priority: '重要',
        scope: 'student,course_teacher,head_teacher,parent',
        creator: '王敏',
        dept: '教务处',
        time: CampusA.ago(hours: 3),
      ),
      notice(
        id: '8102',
        title: '寒潮降温安全提示',
        content:
            '本周起兰州将迎来大幅降温，最低气温 -6℃。请同学们增添衣物，晚自习后结伴回宿舍；宿舍内严禁使用电热毯、暖手宝等大功率电器，宿管老师将加强夜间巡查。',
        type: '紧急',
        priority: '紧急',
        scope: 'student,course_teacher,head_teacher,dormitory,parent',
        creator: '王敏',
        dept: '后勤保障部',
        time: CampusA.ago(days: 1, hours: 2),
      ),
      notice(
        id: '8103',
        title: '黄河岸边色彩写生活动报名',
        content:
            '本周六下午组织色彩写生活动，地点：中山桥—白塔山沿线。请自备水粉工具、小马扎和水桶，13:30 在城东校区门口集合乘车，16:30 返校。报名请联系各班班主任。',
        type: '活动',
        priority: '普通',
        scope: 'student,course_teacher,head_teacher',
        creator: '刘芳',
        dept: '色彩教研组',
        time: CampusA.ago(days: 2, hours: 1),
      ),
      notice(
        id: '8104',
        title: '距甘肃省美术统考还有 $days 天',
        content:
            '甘肃省美术与设计类专业统考定于 ${unified.year} 年 ${unified.month} 月 ${unified.day} 日举行。冲刺阶段每周六上午安排一次全真模拟考试，请同学们调整作息，保证睡眠，按时归寝。',
        type: '通知',
        priority: '重要',
        scope: 'student,course_teacher,head_teacher,parent',
        creator: '王敏',
        dept: '教务处',
        time: CampusA.ago(days: 3, hours: 4),
      ),
      notice(
        id: '8105',
        title: '宿舍用电安全专项检查',
        content:
            '本周五 16:00 起对女生公寓 1 号楼、男生公寓 2 号楼进行用电安全专项检查，重点排查违规电器与私拉电线。请同学们提前自查，检查期间请留一名同学在宿舍配合。',
        type: '督导',
        priority: '重要',
        scope: 'student,dormitory,head_teacher',
        creator: '马红梅',
        dept: '宿管中心',
        time: CampusA.ago(days: 4, hours: 2),
      ),
      notice(
        id: '8106',
        title: '西安美术学院校考线上咨询会',
        content:
            '西安美术学院招生办将于下周三 19:30 举办线上校考咨询会，介绍造型、设计类专业考试要求。意向报考的同学请在班级群内接龙报名，届时在多媒体教室统一观看。',
        type: '活动',
        priority: '普通',
        scope: 'student,head_teacher',
        creator: '吴雨桐',
        dept: '升学指导中心',
        time: CampusA.ago(days: 5, hours: 3),
      ),
      notice(
        id: '8107',
        title: '宿管值班表调整',
        content:
            '自下周一起，晚查寝时间调整为 21:30—22:30，晨查寝 06:40—07:20。值班宿管请在查寝结束后 30 分钟内完成异常登记，并同步至班主任。',
        type: '会议',
        priority: '普通',
        scope: 'dormitory',
        creator: '王敏',
        dept: '后勤保障部',
        time: CampusA.ago(days: 6, hours: 1),
      ),
      notice(
        id: '8108',
        title: '教学研讨会通知',
        content:
            '下周二 10:00 在城东校区会议室召开冲刺阶段教学研讨会，议题：模考数据分析、各科提分方案、校考班课程调整。请各教研组长准备 10 分钟汇报。',
        type: '会议',
        priority: '普通',
        scope: 'course_teacher,head_teacher',
        creator: '王敏',
        dept: '教务处',
        time: CampusA.ago(days: 2, hours: 6),
      ),
    ];
  }

  /// 通知行（`parseAdminNoticeList` 结构）。
  static Map<String, dynamic> row(Map<String, dynamic> n) =>
      Map<String, dynamic>.from(n);
}
