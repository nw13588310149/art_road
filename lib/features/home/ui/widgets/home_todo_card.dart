import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/widgets/app_asset_graphic.dart';
import '../../../school/state/school_config_controller.dart';
import '../../../shell/state/shell_controller.dart';
import '../../state/home_dashboard_state.dart';
import '../../state/home_staff_cards.dart';

/// 班主任、宿管、管理员首页的「今日待办」：每行点开进入智慧校园对应视图（或作品点评、通知）。
///
/// [side] 为 true 时放在右栏、与左侧等高：行带说明，[footer] 贴底；
/// 否则放在学情速览旁，只显示标题与数字。
class HomeTodoCard extends ConsumerWidget {
  const HomeTodoCard({
    required this.role,
    required this.onAction,
    this.side = false,
    this.footer,
    super.key,
  });

  final String role;
  final ValueChanged<HomeTodoAction> onAction;
  final bool side;
  final Widget? footer;

  HomeTodoInput _input(WidgetRef ref) {
    final unread = ref.watch(
      shellControllerProvider.select((s) => s.unreadCount),
    );
    switch (homeRoleKind(role)) {
      case 'headTeacher':
        final stats = ref.watch(homeReviewStatsProvider);
        return HomeTodoInput(
          unreadNotices: unread,
          pendingReviews: stats.valueOrNull?.pending,
          reviewsLoading: stats.isLoading && !stats.hasValue,
        );
      case 'dormManager':
        final config = ref.watch(schoolDormitoryCheckConfigProvider);
        final times = config.valueOrNull;
        return HomeTodoInput(
          unreadNotices: unread,
          eveningCheck: times?.eveningDeadline ?? '',
          morningCheck: times?.morningDeadline ?? '',
          checkLoading: config.isLoading && !config.hasValue,
        );
      case 'admin':
        final summary = ref.watch(homeAdminTodoProvider);
        return HomeTodoInput(
          unreadNotices: unread,
          leaveApprovals: summary.valueOrNull?.leaves,
          signConfirmations: summary.valueOrNull?.signs,
          adminLoading: summary.isLoading && !summary.hasValue,
        );
    }
    return HomeTodoInput(unreadNotices: unread);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = buildHomeTodos(role, _input(ref));
    final attention = items.where((item) => item.attention).length;
    final action = footer;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: side ? MainAxisSize.max : MainAxisSize.min,
        children: [
          AppSectionHeader(
            title: '今日待办',
            subtitle: attention > 0 ? '$attention 项需处理' : null,
          ),
          SizedBox(height: side ? AppSpace.s8 : AppSpace.s4),
          for (var i = 0; i < items.length; i++)
            _TodoRow(
              item: items[i],
              dense: !side,
              divider: i < items.length - 1,
              onTap: () => onAction(items[i].action),
            ),
          if (action != null) ...[
            if (side) const Spacer() else const SizedBox(height: AppSpace.s16),
            action,
          ],
        ],
      ),
    );
  }
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({
    required this.item,
    required this.dense,
    required this.divider,
    required this.onTap,
  });

  final HomeTodoItem item;
  final bool dense;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget trailing;
    if (item.loading) {
      trailing = const AppSkeleton(width: 28, height: 16);
    } else if (item.value.isEmpty) {
      trailing = const SizedBox.shrink();
    } else {
      trailing = Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: item.value,
              style: AppText.number(
                color: item.attention ? AppColors.warning : AppColors.ink,
              ),
            ),
            if (item.unit.isNotEmpty)
              TextSpan(text: ' ${item.unit}', style: AppText.caption12),
          ],
        ),
      );
    }
    return AppPressable(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: dense ? 40 : 56),
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
        decoration: divider
            ? const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
              )
            : null,
        child: Row(
          children: [
            AppAssetGraphic(item.iconAsset, width: 24, height: 24),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body14Strong,
                  ),
                  if (!dense && item.subtitle.isNotEmpty)
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption12,
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            trailing,
            const SizedBox(width: AppSpace.s4),
            const AppAssetGraphic(AppAssets.listChevron, width: 20, height: 20),
          ],
        ),
      ),
    );
  }
}
