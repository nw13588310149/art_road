/// 演示账号：登录页「体验身份」与演示后端共用。
///
/// token 形如 `demo.<role>.<mobile>`，演示后端凭请求头里的 token 还原当前身份，
/// 冷启动后无需额外存储即可继续以同一身份请求。
enum DemoRole {
  student('学生'),
  teacher('任课老师'),
  headTeacher('班主任'),
  dormManager('宿管'),
  admin('管理员');

  const DemoRole(this.label);

  final String label;

  bool get isStaff => this != DemoRole.student;
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

  /// 老师在阅卷演示数据中的 id（作品点评、标签归属）。
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

  static const all = <DemoAccount>[
    student,
    teacher,
    headTeacher,
    dormManager,
    admin,
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
