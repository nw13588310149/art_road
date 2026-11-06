import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shell/state/shell_controller.dart';
import '../../smart_campus/data/teacher_repository.dart';
import 'circle_state.dart';

/// 拉取 `teacherRole` 并判断当前用户是否拥有管理员身份。
///
/// 身份集合中只要包含 `headmaster` / `manager` / `principal` / `admin`
/// 任一 token，即视为最高权限管理员（可删任意帖与评论）。
final circleTeacherRoleAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(
    shellControllerProvider.select(
      (s) => (
        id: s.user.id,
        role: s.user.role,
        identity: s.user.identity,
      ),
    ),
  );
  if (user.id.isEmpty) return false;
  if (CirclePermissions.shellUserIsAdmin(
    role: user.role,
    identity: user.identity,
  )) {
    return true;
  }
  if (!CirclePermissions.shouldFetchTeacherRole(
    role: user.role,
    identity: user.identity,
  )) {
    return false;
  }

  final response = await ref.read(teacherRepositoryProvider).teacherRole();
  if (response.code != 0) return false;
  return CirclePermissions.teacherRoleDataHasAdmin(response.data);
});

/// 校圈删除权限：myInfo 管理员 + `teacherRole` 管理员（取最高权限）。
final circlePermissionsProvider = Provider<CirclePermissions>((ref) {
  final user = ref.watch(shellControllerProvider).user;
  final teacherAdmin = ref.watch(circleTeacherRoleAdminProvider).value ?? false;
  return CirclePermissions(
    currentUserId: user.id,
    isAdmin:
        CirclePermissions.shellUserIsAdmin(
          role: user.role,
          identity: user.identity,
        ) ||
        teacherAdmin,
  );
});
