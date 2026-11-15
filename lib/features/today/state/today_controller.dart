import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo/demo_accounts.dart';
import '../../../core/demo/demo_config.dart';
import '../../../core/providers/app_providers.dart';
import '../../shell/state/shell_controller.dart';
import '../data/today_models.dart';
import '../data/today_repository.dart';
import 'today_board.dart';

/// 今日看板用的身份：优先 `/myInfo` 的 role；演示版回包前按登录 token 还原，
/// 页面不用等接口就能按身份排版。
String resolveTodayRole(
  String role, {
  required String token,
  bool demoMode = kDemoMode,
}) {
  final value = role.trim();
  if (value.isNotEmpty) {
    return value;
  }
  if (!demoMode || token.trim().isEmpty) {
    return '';
  }
  return DemoAccounts.fromToken(token).roleKey;
}

final todayRoleProvider = Provider.autoDispose<String>((ref) {
  final role = ref.watch(shellControllerProvider.select((s) => s.user.role));
  return resolveTodayRole(role, token: ref.read(appStorageProvider).token);
});

/// 今日看板的原始数据。身份未知、或学校信息还没就绪（智慧校园接口要带学校 id）
/// 时不发请求，返回空看板，页面显示占位。
///
/// 处理完一件事回到页面时用 `ref.invalidate(todaySnapshotProvider)` 重新取；
/// 重新取的过程中页面继续显示上一份数据。
final todaySnapshotProvider = FutureProvider.autoDispose<TodaySnapshot>((ref) {
  final role = ref.watch(todayRoleProvider);
  final schoolReady = ref.watch(
    shellControllerProvider.select((s) => s.isSchoolReady),
  );
  if (role.isEmpty || !schoolReady) {
    return TodaySnapshot.empty();
  }
  final isGroupLeader = ref.watch(
    shellControllerProvider.select((s) => s.user.isGroupLeader),
  );
  return ref
      .watch(todayRepositoryProvider)
      .load(role: role, isGroupLeader: isGroupLeader);
});

/// 当前身份的看板；数据还没到时为空。
final todayBoardProvider = Provider.autoDispose<TodayBoard?>((ref) {
  final snapshot = ref.watch(todaySnapshotProvider).valueOrNull;
  if (snapshot == null || snapshot.isEmpty) {
    return null;
  }
  return buildTodayBoard(snapshot);
});

/// 侧栏「今日」入口的角标：需要本人处理的事项数。
final todayPendingCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(todayBoardProvider)?.pendingCount ?? 0;
});
