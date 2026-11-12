/// 演示账号：登录页「体验身份」与演示后端共用。
///
/// token 形如 `demo.<role>.<mobile>`，演示后端凭请求头里的 token 还原当前身份，
/// 冷启动后无需额外存储即可继续以同一身份请求。
enum DemoRole {
  student('学生'),
  teacher('任课老师'),
  subjectLead('科目组长'),
  headTeacher('班主任'),
  dormManager('宿管'),
  admin('管理员'),
  principal('校长');

  const DemoRole(this.label);

  final String label;

  bool get isStaff => this != DemoRole.student;

  /// 全校范围的管理身份：教务管理员与校长。
  bool get managesSchool =>
      this == DemoRole.admin || this == DemoRole.principal;

  /// 有个人授课课表的教职身份：任课老师、科目组长、班主任。
  bool get teaches =>
      this == DemoRole.teacher ||
      this == DemoRole.subjectLead ||
      this == DemoRole.headTeacher;
}

class DemoAccount {
  const DemoAccount({
    required this.role,
    required this.mobile,
    required this.name,
    required this.userId,
    required this.gender,
    this.personIndex,
    this.teacherId,
  });

  final DemoRole role;
  final String mobile;
  final String name;

  /// 平台用户 id（字符串承载雪花 id）。
  final String userId;
  final String gender;

  /// 学生在阅卷演示数据中的序号（[DemoMarkingData.persons] 的 index）。
  final int? personIndex;

  /// 教职工 id（与 [DemoCampusStaff.id] 一致；作品点评、标签归属）。
  final String? teacherId;

  /// 后端 `myInfo.user.role` 取值。
  String get roleKey => role.name;

  String get token => 'demo.${role.name}.$mobile';

  DemoAccount copyWithMobile(String value) => DemoAccount(
    role: role,
    mobile: value,
    name: name,
    userId: userId,
    gender: gender,
    personIndex: personIndex,
    teacherId: teacherId,
  );
}

abstract final class DemoAccounts {
  static const student = DemoAccount(
    role: DemoRole.student,
    mobile: '13809310001',
    name: '林小雨',
    userId: '1880000000000000001',
    gender: '女',
    personIndex: 1,
  );
  static const teacher = DemoAccount(
    role: DemoRole.teacher,
    mobile: '13809310002',
    name: '李静',
    userId: '1880000000000000002',
    gender: '女',
    teacherId: 't-1',
  );

  /// 素描组组长：复核李静（演示任课老师）的点评，闭环上每一环都有体验账号。
  static const subjectLead = DemoAccount(
    role: DemoRole.subjectLead,
    mobile: '13809310012',
    name: '张明远',
    userId: '1880000000000000012',
    gender: '男',
    teacherId: 't-2',
  );
  static const headTeacher = DemoAccount(
    role: DemoRole.headTeacher,
    mobile: '13809310003',
    name: '赵雪',
    userId: '1880000000000000003',
    gender: '女',
    teacherId: 't-4',
  );
  static const dormManager = DemoAccount(
    role: DemoRole.dormManager,
    mobile: '13809310004',
    name: '马红梅',
    userId: '1880000000000000004',
    gender: '女',
  );
  static const admin = DemoAccount(
    role: DemoRole.admin,
    mobile: '13809310005',
    name: '王敏',
    userId: '1880000000000000005',
    gender: '女',
    teacherId: 't-9',
  );

  /// 校长：分管城东校区，并单独分管安宁校区的校考提高班。
  static const principal = DemoAccount(
    role: DemoRole.principal,
    mobile: '13809310006',
    name: '秦文博',
    userId: '1880000000000000006',
    gender: '男',
    teacherId: 'p-1',
  );

  /// 登录页「体验身份」的顺序：学生 → 老师 → 组长 → 班主任 → 宿管 → 管理员 → 校长。
  static const all = <DemoAccount>[
    student,
    teacher,
    subjectLead,
    headTeacher,
    dormManager,
    admin,
    principal,
  ];

  /// 登录：预置手机号命中对应身份；其他手机号一律以学生身份进入。
  static DemoAccount byMobile(String mobile) {
    for (final account in all) {
      if (account.mobile == mobile) {
        return account;
      }
    }
    return student.copyWithMobile(mobile);
  }

  static DemoAccount fromToken(String? token) {
    final parts = (token ?? '').split('.');
    if (parts.length == 3 && parts.first == 'demo') {
      final role = DemoRole.values.where((r) => r.name == parts[1]).firstOrNull;
      if (role != null) {
        final base = all.firstWhere((a) => a.role == role);
        return base.mobile == parts[2] ? base : base.copyWithMobile(parts[2]);
      }
    }
    return student;
  }
}
