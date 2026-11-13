/// 演示账号：登录页「体验身份」与演示后端共用。
///
/// token 形如 `demo.<role>.<mobile>`，演示后端凭请求头里的 token 还原当前身份，
/// 冷启动后无需额外存储即可继续以同一身份请求。
enum DemoRole {
  student('学生'),
  teacher('任课老师'),
  groupLeader('组长'),
  headTeacher('班主任'),
  dormManager('宿管'),
  admin('管理员'),
  principal('校长');

  const DemoRole(this.label);

  final String label;

  bool get isStaff => this != DemoRole.student;

  /// 带课的老师：任课老师、教学组长（也带课）与班主任。
  bool get teaches =>
      this == DemoRole.teacher ||
      this == DemoRole.groupLeader ||
      this == DemoRole.headTeacher;

  /// 看全校数据、用管理端的身份：管理员与校长。
  bool get managesSchool =>
      this == DemoRole.admin || this == DemoRole.principal;
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
    this.groupLeaderSubjects = const <String>[],
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

  /// 教学组长所管科目（如素描组）。空列表表示不是组长。
  final List<String> groupLeaderSubjects;

  /// 是否教学组长（任课老师 + 组长权限）。
  bool get isGroupLeader => groupLeaderSubjects.isNotEmpty;

  /// 后端 `myInfo.user.role` 取值。组长在后端仍是任课老师，组长身份另由
  /// `myInfo.user.groupLeader` 下发。
  String get roleKey =>
      role == DemoRole.groupLeader ? DemoRole.teacher.name : role.name;

  String get token => 'demo.${role.name}.$mobile';

  DemoAccount copyWithMobile(String value) => DemoAccount(
    role: role,
    mobile: value,
    name: name,
    userId: userId,
    gender: gender,
    personIndex: personIndex,
    teacherId: teacherId,
    groupLeaderSubjects: groupLeaderSubjects,
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

  /// 素描组长：自己也带课，另负责复核本组老师的点评。
  static const groupLeader = DemoAccount(
    role: DemoRole.groupLeader,
    mobile: '13809310012',
    name: '张明远',
    userId: '1880000000000000012',
    gender: '男',
    teacherId: 't-2',
    groupLeaderSubjects: <String>['素描'],
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

  /// 总校长：看三个校区的全部数据，可以点评、推优任何作品。
  static const principal = DemoAccount(
    role: DemoRole.principal,
    mobile: '13809310006',
    name: '陈建华',
    userId: '1880000000000000006',
    gender: '男',
    teacherId: 'p-1',
  );

  static const all = <DemoAccount>[
    student,
    teacher,
    groupLeader,
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
