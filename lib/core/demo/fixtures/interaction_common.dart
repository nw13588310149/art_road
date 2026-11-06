import 'dart:convert';

import '../data/demo_campus_data.dart';
import '../data/demo_marking_data.dart';
import '../demo_accounts.dart';
import '../demo_store.dart';
import '../media/demo_media.dart';

/// 演示数据统一的时间文本：`yyyy-MM-dd HH:mm:ss`。
String demoTimeText(DateTime time) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
}

/// 把客户端回传的绝对媒体地址还原成可持久化的引用：演示媒体服务的端口
/// 每次启动都会变化，存绝对地址会在重启后失效。
String demoMediaRefOf(String urlOrRef) {
  final value = urlOrRef.trim();
  final base = DemoMedia.fileBaseUrl;
  if (base.isNotEmpty && value.startsWith(base)) {
    return value.substring(base.length);
  }
  return value;
}

/// 缓存的种子交给 [DemoStore] 前先深拷贝：写操作改的是副本，
/// `DemoStore.reset()` 之后仍能拿到干净的种子。
List<Map<String, dynamic>> demoCloneSeed(List<Map<String, dynamic>> seed) => [
  for (final item in seed)
    Map<String, dynamic>.from(jsonDecode(jsonEncode(item)) as Map),
];

/// 演示账号的个人资料（与 `/app/user/userinfoUpdate` 共用同一份存储）。
Map<String, dynamic> demoProfileOf(DemoAccount account) =>
    DemoStore.map('profile:${account.userId}', () => <String, dynamic>{});

/// 学生在平台侧的用户 id：演示学生账号沿用登录账号 id，其余学生按档案序号生成。
String demoStudentUserId(int personIndex) => personIndex == 1
    ? DemoAccounts.student.userId
    : '18800000001${personIndex.toString().padLeft(5, '0')}';

/// 动态 / 评论作者的展示信息。
class DemoAuthorCard {
  const DemoAuthorCard({
    required this.userId,
    required this.name,
    required this.identity,
    required this.avatarRef,
  });

  final String userId;
  final String name;

  /// 名字下方的身份文案，例如「联考冲刺1班 · 城东校区」。
  final String identity;

  /// `asset:` 引用或上传引用；空串时前端按姓名首字生成头像。
  final String avatarRef;

  Map<String, dynamic> toUserJson() => <String, dynamic>{
    'id': userId,
    'nickname': name,
    'realname': name,
    'headUrl': DemoMedia.url(avatarRef),
    'identity': identity,
  };
}

DemoAuthorCard demoStudentAuthor(int personIndex) {
  final person = DemoMarkingData.instance.person(personIndex);
  final klass = DemoCampusData.classOfPerson(personIndex);
  return DemoAuthorCard(
    userId: demoStudentUserId(personIndex),
    name: person.name,
    identity: '${klass.name} · ${person.organizationName}',
    avatarRef: person.avatarRef,
  );
}

DemoAuthorCard demoStaffAuthor(DemoCampusStaff staff) {
  final String identity;
  if (staff.roles.contains('admin')) {
    identity = '教务处 · ${DemoCampusData.schoolName}';
  } else if (staff.roles.contains('dormManager')) {
    identity = '宿管老师 · ${staff.organizationName}';
  } else {
    identity = '${staff.subject}老师 · ${staff.organizationName}';
  }
  return DemoAuthorCard(
    userId: staff.userId,
    name: staff.name,
    identity: identity,
    avatarRef: '',
  );
}

/// 当前登录账号的作者信息：昵称、头像以个人资料的最新值为准。
DemoAuthorCard demoAccountAuthor(DemoAccount account) {
  final profile = demoProfileOf(account);
  final nickname = profile['nickname']?.toString().trim() ?? '';
  final headRef = demoMediaRefOf(profile['headUrl']?.toString() ?? '');
  final personIndex = account.personIndex;
  if (account.role == DemoRole.student && personIndex != null) {
    final base = demoStudentAuthor(personIndex);
    return DemoAuthorCard(
      userId: account.userId,
      name: nickname.isNotEmpty ? nickname : account.name,
      identity: base.identity,
      avatarRef: headRef.isNotEmpty ? headRef : base.avatarRef,
    );
  }
  final staff = DemoCampusData.staffByUserId(account.userId);
  final base = staff == null ? null : demoStaffAuthor(staff);
  return DemoAuthorCard(
    userId: account.userId,
    name: nickname.isNotEmpty ? nickname : account.name,
    identity: base?.identity ?? account.role.label,
    avatarRef: headRef,
  );
}

/// 按用户 id 还原作者：演示账号取实时资料，其余取学生档案 / 教职工名册。
DemoAuthorCard? demoAuthorByUserId(String userId) {
  for (final account in DemoAccounts.all) {
    if (account.userId == userId) {
      return demoAccountAuthor(account);
    }
  }
  final staff = DemoCampusData.staffByUserId(userId);
  if (staff != null) {
    return demoStaffAuthor(staff);
  }
  for (final person in DemoMarkingData.instance.persons) {
    if (demoStudentUserId(person.index) == userId) {
      return demoStudentAuthor(person.index);
    }
  }
  return null;
}
