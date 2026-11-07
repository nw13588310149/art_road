import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/ui/ui.dart';
import '../state/shell_controller.dart';
import '../state/shell_state.dart';
import '../ui/widgets/shell_notice_drawer.dart';

/// 消息的 `targetType`：后端按业务类型下发，客户端据此决定点开后去哪一页。
abstract final class ShellNoticeTargetType {
  /// 学情（成绩发布、原卷上线），targetId 为考试 id。
  static const study = 1;

  /// 作品（点评完成、新作品待点评），targetId 为作品 id。
  static const artwork = 2;

  /// 系统通知：没有目标页，点开只标为已读。
  static const system = 3;

  /// 书刊上新，targetId 为书刊 id。
  static const ebook = 4;

  /// 校园通知：打开智慧校园。
  static const campus = 5;

  /// 工具上新，targetId 为画室工具箱的工具 key（见 `toolbox_catalog.dart`）。
  static const toolbox = 6;
}

@immutable
class ShellNoticeDestination {
  const ShellNoticeDestination(this.route, [this.arguments]);

  final String route;
  final Map<String, dynamic>? arguments;
}

/// 消息点开后的目标页；系统通知等没有目标页时为 null。
ShellNoticeDestination? shellNoticeDestination(ShellNoticeItem item) {
  final id = item.targetId.trim();
  Map<String, dynamic>? args(String key) =>
      id.isEmpty ? null : <String, dynamic>{key: id};
  return switch (item.targetType) {
    ShellNoticeTargetType.study => ShellNoticeDestination(
      RoutePaths.studyCenter,
      args('examId'),
    ),
    ShellNoticeTargetType.artwork => ShellNoticeDestination(
      RoutePaths.artworks,
      args('artworkId'),
    ),
    ShellNoticeTargetType.ebook => ShellNoticeDestination(
      RoutePaths.ebooks,
      args('bookId'),
    ),
    ShellNoticeTargetType.campus => const ShellNoticeDestination(
      RoutePaths.smartCampus,
    ),
    ShellNoticeTargetType.toolbox => ShellNoticeDestination(
      RoutePaths.artToolbox,
      args('tool'),
    ),
    _ => null,
  };
}

/// 点开一条消息：先标为已读，再把目标页压栈打开（返回回到原页面）。
void openShellNotice(
  BuildContext context,
  WidgetRef ref,
  ShellNoticeItem item,
) {
  unawaited(ref.read(shellControllerProvider.notifier).markNoticeRead(item.id));
  final destination = shellNoticeDestination(item);
  if (destination == null) {
    return;
  }
  final user = ref.read(shellControllerProvider).user;
  if (user.id.isNotEmpty &&
      !user.isVipActive &&
      !ShellController.isRouteAllowedWithoutVip(destination.route)) {
    AppToast.show(context, '请先开通会员');
    return;
  }
  Navigator.of(
    context,
  ).pushNamed(destination.route, arguments: destination.arguments);
}

/// 打开通知抽屉（顶栏铃铛与首页「未读消息」共用），点开消息会跳到对应页面。
Future<void> showShellNotices(BuildContext context, WidgetRef ref) {
  final state = ref.read(shellControllerProvider);
  final controller = ref.read(shellControllerProvider.notifier);
  return showShellNoticeDrawer(
    context,
    items: state.noticeItems,
    unreadCount: state.unreadCount,
    onMarkAllRead: controller.markAllNoticeRead,
    onOpen: (item) => openShellNotice(context, ref, item),
  );
}
