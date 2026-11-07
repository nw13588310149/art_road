/// 智慧校园演示数据（B 部分：任课老师 / 班主任 / 管理员）的公共工具：
/// 时间与 id、媒体引用、身份范围、班级名册、教室与科目。
library;

import 'dart:convert';

import '../../data/demo_campus_data.dart';
import '../../data/demo_marking_data.dart';
import '../../demo_accounts.dart';
import '../../demo_backend.dart';
import '../../demo_clock.dart';
import '../../demo_store.dart';
import '../../media/demo_media.dart';

// ── 时间 ──────────────────────────────────────────────────────────────

String cbTwo(int value) => value.toString().padLeft(2, '0');

String cbDate(DateTime d) => '${d.year}-${cbTwo(d.month)}-${cbTwo(d.day)}';

String cbDateTime(DateTime d) =>
    '${cbDate(d)} ${cbTwo(d.hour)}:${cbTwo(d.minute)}:${cbTwo(d.second)}';

String cbHm(DateTime d) => '${cbTwo(d.hour)}:${cbTwo(d.minute)}';

DateTime cbDay(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime cbToday() => cbDay(DateTime.now());

DateTime cbAddDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

/// [day] 当天的 `HH:mm` 时刻。
DateTime cbAt(DateTime day, String hm) {
  final parts = hm.split(':');
  final hour = int.tryParse(parts.first) ?? 0;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return DateTime(day.year, day.month, day.day, hour, minute);
}

/// 相对今天偏移 [days] 天的 `HH:mm` 时刻。
DateTime cbRel(int days, String hm) => cbAt(cbAddDays(cbToday(), days), hm);

/// 已经发生的事（提交、审批、消息）落在 [days] 天（通常为 0 或负数）的 `HH:mm`；
/// 晚于 [DemoClock.now] 时逐日前移，保证列表里不出现未来时间，时刻仍在白天。
DateTime cbPast(int days, String hm) =>
    cbRel(days - cbPastShift(days, hm), hm);

/// 把一天里的任意时刻按比例压进白天 08:30–21:30（同一天内先后顺序不变），
/// 用于按比例插值生成的提交时间，避免出现凌晨。
DateTime cbDaytime(DateTime t) {
  final minutes = 510 + (t.hour * 60 + t.minute) * 780 ~/ 1440;
  return DateTime(t.year, t.month, t.day, minutes ~/ 60, minutes % 60);
}

/// 不晚于 [DemoClock.now]。
DateTime cbNotAfterNow(DateTime t) {
  final limit = DemoClock.now();
  return t.isAfter(limit) ? limit : t;
}

/// [cbPast] 需要整体前移的天数；同一段对话按最后一条算出后统一前移，先后顺序不乱。
int cbPastShift(int days, String hm) {
  final limit = DemoClock.now();
  var shift = 0;
  while (cbRel(days - shift, hm).isAfter(limit)) {
    shift++;
  }
  return shift;
}

/// 以 [DemoClock.now] 为基准往前推：先退 [days] 个整天，再只在白天
/// （08:30–21:30）里往前数 [ago]，跳过夜间；越早的事时间越早，秒数归零。
DateTime cbAgo(Duration ago, {int days = 0}) {
  final now = DemoClock.now();
  var t = DateTime(
    now.year,
    now.month,
    now.day - days,
    now.hour,
    now.minute,
  );
  var left = ago;
  while (true) {
    final dayStart = DateTime(t.year, t.month, t.day, 8, 30);
    final available = t.difference(dayStart);
    if (left <= available) {
      return t.subtract(left);
    }
    left -= available;
    t = DateTime(t.year, t.month, t.day - 1, 21, 30);
  }
}

DateTime? cbParse(Object? raw) {
  final text = raw?.toString().trim() ?? '';
  if (text.isEmpty || text == 'null') {
    return null;
  }
  return DateTime.tryParse(text);
}

/// 请求里的 `yyyy-MM-dd`；缺省时返回 null。
DateTime? cbParseDay(Object? raw) {
  final parsed = cbParse(raw);
  return parsed == null ? null : cbDay(parsed);
}

const List<String> cbWeekdayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

// ── 通用取值 ──────────────────────────────────────────────────────────

/// 稳定哈希：同一输入在每次启动都得到相同结果，用于演示数据的确定性抖动。
int cbHash(String text) {
  var h = 17;
  for (final unit in text.codeUnits) {
    h = (h * 31 + unit) & 0x3fffffff;
  }
  return h;
}

int cbInt(Object? raw, [int fallback = 0]) {
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.toInt();
  }
  return int.tryParse(raw?.toString().trim() ?? '') ?? fallback;
}

double? cbNum(Object? raw) {
  if (raw is num) {
    return raw.toDouble();
  }
  return double.tryParse(raw?.toString().trim() ?? '');
}

String cbStr(Object? raw, [String fallback = '']) {
  final text = raw?.toString().trim() ?? '';
  return text.isEmpty || text == 'null' ? fallback : text;
}

List<String> cbStrList(Object? raw) {
  if (raw is List) {
    return [
      for (final item in raw)
        if (cbStr(item).isNotEmpty) cbStr(item),
    ];
  }
  return cbCsv(raw);
}

List<String> cbCsv(Object? raw) => cbStr(raw)
    .split(RegExp(r'[,，]'))
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();

/// JSON 风格深拷贝，避免修改演示数据时串改缓存。
Map<String, dynamic> cbCopy(Map<dynamic, dynamic> source) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(source)) as Map);

/// 请求体为数组（如 `courseBatchSave`）时的元素列表。
List<Map<String, dynamic>> cbBodyRows(DemoRequest req) {
  final body = req.body;
  if (body is! List) {
    return const [];
  }
  return [
    for (final item in body)
      if (item is Map) item.map((k, v) => MapEntry(k.toString(), v)),
  ];
}

String cbRound1(double value) => value.toStringAsFixed(1);

double cbRoundTo(double value, int digits) {
  final factor = digits == 1 ? 10 : 100;
  return (value * factor).round() / factor;
}

String cbPercent(int part, int total) =>
    total == 0 ? '0.00%' : '${(part * 100 / total).toStringAsFixed(2)}%';

// ── 媒体 ──────────────────────────────────────────────────────────────

String cbUrl(String ref) => DemoMedia.url(ref);

/// 把前端回传的演示媒体绝对地址还原成可持久化的引用（端口每次启动会变）。
String cbRef(String value) {
  final text = value.trim();
  final base = DemoMedia.fileBaseUrl;
  if (base.isEmpty || !text.startsWith(base)) {
    return text;
  }
  final rest = text.substring(base.length);
  if (rest.startsWith('a/')) {
    return 'asset:${Uri.decodeFull(rest.substring(2))}';
  }
  return rest;
}

// ── 科目 ──────────────────────────────────────────────────────────────

/// 科目 id 与阅卷数据（素描 38 / 色彩 39 / 速写 40）和学生端课表一致。
const Map<String, int> cbSubjectIds = {
  '素描': 38,
  '色彩': 39,
  '速写': 40,
  '美术常识': 41,
  '文化课': 42,
  '模拟考试': 43,
};

/// 课程名归到任课科目（如「色彩写生」→ 色彩），模拟考试由素描老师监考。
String cbSubjectKey(String courseName) {
  for (final (key, subject) in const [
    ('素描', '素描'),
    ('色彩', '色彩'),
    ('速写', '速写'),
    ('常识', '美术常识'),
    ('文化', '文化课'),
    ('模拟', '素描'),
  ]) {
    if (courseName.contains(key)) {
      return subject;
    }
  }
  return courseName;
}

int cbSubjectIdOf(String name) {
  if (name.contains('模拟')) {
    return 43;
  }
  return cbSubjectIds[cbSubjectKey(name)] ?? 43;
}

String? cbSubjectNameOf(int id) {
  for (final entry in cbSubjectIds.entries) {
    if (entry.value == id) {
      return entry.key;
    }
  }
  return null;
}

/// 课程卡底色，与学生端课表同一套配色。
String cbCourseColor(String courseName, {bool small = false}) {
  if (small) {
    return '#A49AF4';
  }
  for (final (key, color) in const [
    ('模拟', '#FE96EB'),
    ('写生', '#C5E53E'),
    ('素描', '#8C63FF'),
    ('色彩', '#F99C5D'),
    ('速写', '#71D4D0'),
    ('常识', '#A8C3FE'),
  ]) {
    if (courseName.contains(key)) {
      return color;
    }
  }
  return '#FEEA98';
}

// ── 校区与教室 ────────────────────────────────────────────────────────

const List<String> cbCampusNames = DemoMarkingData.organizations;

int cbCampusIdOf(String organizationName) {
  final index = cbCampusNames.indexOf(organizationName);
  return index < 0 ? 1 : index + 1;
}

String cbCampusNameOf(int id) =>
    id >= 1 && id <= cbCampusNames.length ? cbCampusNames[id - 1] : '城东校区';

String cbCampusShort(String organizationName) =>
    organizationName.replaceAll('校区', '');

/// 教室名与课表模板一致（`城东校区 · 素描教室 A`）。
const List<String> cbRoomNames = [
  '素描教室 A',
  '色彩教室 B',
  '速写教室 C',
  '多媒体教室',
  '考试大厅',
  '室外写生',
  '小课教室 1',
  '小课教室 2',
  '小课教室 3',
];

const Map<String, int> _roomCapacity = {
  '素描教室 A': 40,
  '色彩教室 B': 40,
  '速写教室 C': 40,
  '多媒体教室': 60,
  '考试大厅': 120,
  '室外写生': 60,
  '小课教室 1': 6,
  '小课教室 2': 6,
  '小课教室 3': 6,
};

/// 教室 id = 校区序号 × 10 + 教室序号（11 = 城东校区素描教室 A）。
int cbClassroomId(String organizationName, String room) {
  final index = cbRoomNames.indexOf(room);
  return cbCampusIdOf(organizationName) * 10 + (index < 0 ? 0 : index) + 1;
}

String cbClassroomName(int id) {
  final campus = id ~/ 10;
  final room = id % 10 - 1;
  if (campus < 1 || campus > cbCampusNames.length || room < 0) {
    return '';
  }
  if (room >= cbRoomNames.length) {
    return '';
  }
  return '${cbCampusNames[campus - 1]} · ${cbRoomNames[room]}';
}

List<Map<String, dynamic>> cbClassroomList() => [
  for (var c = 0; c < cbCampusNames.length; c++)
    for (var r = 0; r < cbRoomNames.length; r++)
      <String, dynamic>{
        'id': (c + 1) * 10 + r + 1,
        'classroomId': (c + 1) * 10 + r + 1,
        'name': cbClassroomName((c + 1) * 10 + r + 1),
        'classroomName': cbClassroomName((c + 1) * 10 + r + 1),
        'campusId': c + 1,
        'campusName': cbCampusNames[c],
        'capacity': _roomCapacity[cbRoomNames[r]],
      },
];

// ── 节次 ──────────────────────────────────────────────────────────────

/// 节次即 [DemoClock.daySlots]：1 上午 08:30–11:30 / 2 下午 14:00–17:00 /
/// 3 晚上 19:00–21:00，学生端、老师端、管理端与首页共用。
final Map<int, (String, String)> cbLineTimes = {
  for (var i = 0; i < DemoClock.daySlots.length; i++)
    i + 1: DemoClock.daySlots[i],
};

const List<String> cbLineNames = ['上午', '下午', '晚上'];

int cbLineNumOf(String start) {
  final hour = int.tryParse(start.split(':').first) ?? 8;
  if (hour < 12) {
    return 1;
  }
  return hour < 18 ? 2 : 3;
}

(String, String) cbLineTime(int lineNum) =>
    cbLineTimes[lineNum.clamp(1, cbLineTimes.length)]!;

// ── 学生 ──────────────────────────────────────────────────────────────

List<DemoPerson> get cbPersons => DemoMarkingData.instance.persons;

/// 学生在智慧校园接口里的 id（学生档案 id，纯数字）。
String cbStudentId(DemoPerson p) => p.archiveId;

/// 学生平台用户 id：1 号学生与学生演示账号一致。
String cbStudentUserId(DemoPerson p) => p.index == 1
    ? DemoAccounts.student.userId
    : '18800000001${p.index.toString().padLeft(8, '0')}';

String cbStudentNo(DemoPerson p) => '2027${p.index.toString().padLeft(3, '0')}';

final Map<String, DemoPerson> _personIndex = {
  for (final p in DemoMarkingData.instance.persons) ...{
    p.archiveId: p,
    cbStudentUserId(p): p,
    cbStudentNo(p): p,
  },
};

/// 按学生档案 id、平台用户 id 或学号查找学生。
DemoPerson? cbPerson(Object? rawId) => _personIndex[cbStr(rawId)];

/// 学籍状态：38 号学生因手腕骨折办理休学，其余在籍。
String cbStudentStatus(DemoPerson p) => p.index == 38 ? '休学' : '在籍';

bool cbIsActive(DemoPerson p) => cbStudentStatus(p) == '在籍';

String cbBedInfo(DemoPerson p) {
  final bed = DemoCampusData.bedOf(p.index);
  return bed == null ? '' : '${bed.display} · ${bed.bed}号床';
}

String cbBedId(DemoPerson p) =>
    DemoCampusData.bedOf(p.index) == null ? '0' : '${8000 + p.index}';

const List<String> _fatherGiven = ['建国', '志强', '海涛', '永明', '国华', '振宇', '立军'];
const List<String> _motherGiven = ['秀兰', '丽娟', '春梅', '晓燕', '玉珍', '美玲', '慧敏'];
const List<String> _motherSurname = ['王', '李', '张', '刘', '陈', '赵', '马'];

/// 家长信息：双号学生第一联系人为母亲，单号为父亲。
List<Map<String, String>> cbParentsOf(DemoPerson p) {
  final surname = p.name.substring(0, 1);
  final father = '$surname${_fatherGiven[p.index % _fatherGiven.length]}';
  final mother =
      '${_motherSurname[p.index % _motherSurname.length]}'
      '${_motherGiven[(p.index * 3) % _motherGiven.length]}';
  String mobile(int salt) {
    final tail = (31000000 + p.index * 104729 + salt * 7919) % 100000000;
    return '${salt.isEven ? '137' : '158'}${tail.toString().padLeft(8, '0')}';
  }

  final fatherEntry = {'name': father, 'relation': '父亲', 'mobile': mobile(1)};
  final motherEntry = {'name': mother, 'relation': '母亲', 'mobile': mobile(2)};
  return p.index.isEven
      ? [motherEntry, fatherEntry]
      : [fatherEntry, motherEntry];
}

// ── 教职工 ────────────────────────────────────────────────────────────

DemoCampusStaff? cbStaff(Object? rawId) {
  final id = cbStr(rawId);
  if (id.isEmpty) {
    return null;
  }
  for (final s in DemoCampusData.staff) {
    if (s.id == id || s.userId == id) {
      return s;
    }
  }
  return null;
}

String cbStaffName(Object? rawId) => cbStaff(rawId)?.name ?? '';

String cbStaffNo(DemoCampusStaff s) =>
    'MS${(DemoCampusData.staff.indexOf(s) + 1).toString().padLeft(3, '0')}';

// ── 班级（可编辑名册） ────────────────────────────────────────────────

const String cbClassesKey = 'campus_b:classes';

const Map<String, String> _classLogos = {
  '501': 'asset:assets/demo/art/sketch-portrait-1.jpg',
  '502': 'asset:assets/demo/art/color-still-2.jpg',
  '503': 'asset:assets/demo/art/speed-figure-1.jpg',
  '601': 'asset:assets/demo/art/sketch-bust-1.jpg',
  '602': 'asset:assets/demo/art/color-landscape-1.jpg',
  '603': 'asset:assets/demo/art/speed-group-1.jpg',
};

const Map<String, String> _classCodes = {
  '501': 'LK2701',
  '502': 'LK2702',
  '503': 'XK2701',
  '601': 'XB2701',
  '602': 'XB2702',
  '603': 'XB2703',
};

const Map<String, String> _classNotices = {
  '501': '本周目标：石膏头像长期作业收尾，周六模拟考试请提前 20 分钟到考试大厅。',
  '502': '色彩静物三张作业周五前交，周六下午写生请自备折叠凳。',
  '503': '校考提高班本周以速写场景组合为主，作品集照片周日前上传。',
  '601': '素描精进小班：每次课带上一周的长期作业，课上逐张讲评。',
  '602': '色彩专项小班：本阶段练习灰调静物，调色盘提前清洗。',
  '603': '速写强化小班：每次课 20 张动态默写，课后拍照上传。',
};

/// 小班（type = 1）：成员来自大班的重点学生。
const List<
  ({String id, String name, String org, String teacher, List<int> members})
>
_smallClasses = [
  (
    id: '601',
    name: '素描精进小班',
    org: '城东校区',
    teacher: 't-1',
    members: [1, 3, 6, 9, 4, 7],
  ),
  (
    id: '602',
    name: '色彩专项小班',
    org: '城西校区',
    teacher: 't-3',
    members: [10, 13, 16, 19, 22],
  ),
  (
    id: '603',
    name: '速写强化小班',
    org: '城东校区',
    teacher: 't-4',
    members: [12, 15, 18, 5, 8],
  ),
];

List<Map<String, dynamic>> _seedClasses() {
  final teacherIds = <String, List<String>>{};
  for (final s in DemoCampusData.staff) {
    for (final cid in s.classIds) {
      teacherIds.putIfAbsent(cid, () => <String>[]).add(s.userId);
    }
  }
  return [
    for (final c in DemoCampusData.classes)
      <String, dynamic>{
        'id': c.id,
        'name': c.name,
        'groupName': c.name,
        'type': 0,
        'classCode': _classCodes[c.id] ?? '',
        'grade': c.grade,
        'campusId': cbCampusIdOf(c.organizationName),
        'campusName': c.organizationName,
        'headTeacherId':
            DemoCampusData.staffById(c.headTeacherId)?.userId ?? '0',
        'classroomId': cbClassroomId(c.organizationName, cbRoomNames.first),
        'teacherIds': (teacherIds[c.id] ?? const <String>[]).join(','),
        'studentIds': [for (final p in c.students) p.archiveId],
        'logo': _classLogos[c.id] ?? '',
        'announcement': _classNotices[c.id] ?? '',
        'mute': 0,
        'createTime': '2026-08-25 09:00:00',
      },
    for (final s in _smallClasses)
      <String, dynamic>{
        'id': s.id,
        'name': s.name,
        'groupName': s.name,
        'type': 1,
        'classCode': _classCodes[s.id] ?? '',
        'grade': '2027 届',
        'campusId': cbCampusIdOf(s.org),
        'campusName': s.org,
        'headTeacherId': '0',
        'classroomId': cbClassroomId(s.org, cbRoomNames.first),
        'teacherIds': DemoCampusData.staffById(s.teacher)?.userId ?? '',
        'studentIds': [
          for (final index in s.members)
            DemoMarkingData.instance.person(index).archiveId,
        ],
        'logo': _classLogos[s.id] ?? '',
        'announcement': _classNotices[s.id] ?? '',
        'mute': 0,
        'createTime': '2026-09-10 09:00:00',
      },
  ];
}

List<Map<String, dynamic>> cbClasses() =>
    DemoStore.list(cbClassesKey, _seedClasses);

void cbSaveClasses() => DemoStore.save(cbClassesKey);

Map<String, dynamic>? cbClass(Object? rawId) {
  final id = cbStr(rawId);
  for (final c in cbClasses()) {
    if (cbStr(c['id']) == id) {
      return c;
    }
  }
  return null;
}

String cbClassName(Object? rawId) => cbStr(cbClass(rawId)?['name']);

bool cbIsSmallClass(Map<String, dynamic> c) => cbInt(c['type']) == 1;

List<String> cbClassStudentIds(Object? rawId) =>
    cbStrList(cbClass(rawId)?['studentIds']);

/// 在籍学生（休学学生不进入考勤、查寝名单）。
List<String> cbActiveStudents(Object? classId) => [
  for (final id in cbClassStudentIds(classId))
    if (cbPerson(id) case final p? when cbIsActive(p)) id,
];

/// 学生所在的行政班（大班）；未分班时返回 null。
Map<String, dynamic>? cbHomeClassOf(DemoPerson p) {
  for (final c in cbClasses()) {
    if (!cbIsSmallClass(c) &&
        cbStrList(c['studentIds']).contains(p.archiveId)) {
      return c;
    }
  }
  return null;
}

String cbClassLogo(Object? classId) => cbUrl(cbStr(cbClass(classId)?['logo']));

/// 班级的任课老师（平台用户 id）。
List<String> cbClassTeacherIds(Map<String, dynamic> c) =>
    cbCsv(c['teacherIds']);

/// 某科目在某班的任课老师姓名。
String cbSubjectTeacherOf(Object? classId, String subjectName) {
  final c = cbClass(classId);
  if (c == null) {
    return '';
  }
  final key = cbSubjectKey(subjectName);
  for (final uid in cbClassTeacherIds(c)) {
    final staff = cbStaff(uid);
    if (staff != null && staff.subject == key) {
      return staff.name;
    }
  }
  for (final s in DemoCampusData.staff) {
    if (s.subject == key) {
      return s.name;
    }
  }
  return '';
}

// ── 身份范围 ──────────────────────────────────────────────────────────

/// 当前请求账号在智慧校园里的数据范围：管理员看全部班级。
class CbScope {
  CbScope._(this.account, this.staff, this.all);

  final DemoAccount account;
  final DemoCampusStaff? staff;
  final bool all;

  String get userId => staff?.userId ?? account.userId;

  String get name => staff?.name ?? account.name;

  bool get isStaff => account.role.isStaff;

  /// 任教班级（含担任班主任的班级）。
  List<String> get teachingClassIds {
    if (all) {
      return [for (final c in cbClasses()) cbStr(c['id'])];
    }
    final uid = userId;
    return [
      for (final c in cbClasses())
        if (cbClassTeacherIds(c).contains(uid) ||
            cbStr(c['headTeacherId']) == uid)
          cbStr(c['id']),
    ];
  }

  /// 担任班主任的行政班。
  List<String> get headClassIds {
    final uid = userId;
    return [
      for (final c in cbClasses())
        if (!cbIsSmallClass(c) && (all || cbStr(c['headTeacherId']) == uid))
          cbStr(c['id']),
    ];
  }

  /// 任教的美术考试科目（考评管理按科目出卷）。
  List<String> get examSubjects {
    if (all) {
      return const ['素描', '色彩', '速写'];
    }
    final subject = staff?.subject ?? '';
    return const ['素描', '色彩', '速写'].contains(subject) ? [subject] : const [];
  }

  bool ownsTeacher(Object? teacherUserId) =>
      all || cbStr(teacherUserId) == userId;
}

CbScope cbScope(DemoRequest req) {
  final account = req.account;
  if (account.role == DemoRole.admin) {
    return CbScope._(account, DemoCampusData.staffById('t-9'), true);
  }
  if (account.role == DemoRole.student) {
    return CbScope._(account, null, false);
  }
  final staff =
      DemoCampusData.staffByUserId(account.userId) ??
      (account.teacherId == null
          ? null
          : DemoCampusData.staffById(account.teacherId!));
  return CbScope._(account, staff, false);
}

/// 教职工身份 CSV（与 `teacherRole.roles` 一致），班主任身份按班级实时判断。
String cbStaffRoles(DemoCampusStaff s) {
  final tokens = <String>[];
  if (s.roles.contains('admin')) {
    tokens.add('manager');
  }
  if (cbClasses().any(
    (c) => !cbIsSmallClass(c) && cbStr(c['headTeacherId']) == s.userId,
  )) {
    tokens.add('head_teacher');
  }
  if (s.subject.isNotEmpty) {
    tokens.add('course_teacher');
  }
  if (s.roles.contains('dormManager')) {
    tokens.add('dormitory');
  }
  return tokens.join(',');
}

/// 班级列表项（任课老师、班主任、管理员、宿管共用）。
Map<String, dynamic> cbClassJson(Map<String, dynamic> c) {
  final id = cbStr(c['id']);
  final head = cbStaff(c['headTeacherId']);
  final classroomId = cbInt(c['classroomId']);
  final studentIds = cbStrList(c['studentIds']);
  final teacherIds = cbClassTeacherIds(c);
  return <String, dynamic>{
    'id': id,
    'classId': id,
    'name': cbStr(c['name']),
    'className': cbStr(c['name']),
    'groupName': cbStr(c['groupName'], cbStr(c['name'])),
    'type': cbInt(c['type']),
    'classType': cbInt(c['type']),
    'classCode': cbStr(c['classCode']),
    'grade': cbStr(c['grade']),
    'campusId': cbInt(c['campusId'], 1),
    'campusName': cbStr(c['campusName']),
    'schoolCampusName': cbStr(c['campusName']),
    'logo': cbUrl(cbStr(c['logo'])),
    'headTeacherId': head?.userId ?? '0',
    'headTeacherName': head?.name ?? '',
    'headTeacher': head == null
        ? null
        : <String, dynamic>{
            'id': head.userId,
            'realname': head.name,
            'nickname': head.name,
            'mobile': head.phone,
            'gender': head.gender,
            'headUrl': '',
            'introduce': '${head.subject}老师 · ${head.organizationName}',
          },
    'classroomId': classroomId,
    'classroomName': cbClassroomName(classroomId),
    'schoolClassroom': classroomId == 0
        ? null
        : <String, dynamic>{
            'id': classroomId,
            'name': cbClassroomName(classroomId),
          },
    'teacherIds': teacherIds.join(','),
    'teacherNames': [for (final uid in teacherIds) cbStaffName(uid)].join('、'),
    'teacherCount': teacherIds.length,
    'studentIds': studentIds,
    'studentCount': studentIds.length,
    'announcement': cbStr(c['announcement']),
    'mute': cbInt(c['mute']),
    'createTime': cbStr(c['createTime']),
  };
}

/// 学生所属的、当前账号可见的班级（优先行政班）。
List<String> cbVisibleStudentIds(CbScope scope, {String classId = ''}) {
  final classIds = classId.isEmpty
      ? scope.teachingClassIds
      : [if (scope.all || scope.teachingClassIds.contains(classId)) classId];
  final seen = <String>{};
  final result = <String>[];
  for (final cid in classIds) {
    for (final sid in cbClassStudentIds(cid)) {
      if (seen.add(sid)) {
        result.add(sid);
      }
    }
  }
  return result;
}
