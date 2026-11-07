import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/app_asset_graphic.dart';
import '../state/circle_controller.dart';
import '../state/circle_governance_controller.dart';
import '../state/circle_governance_state.dart';
import '../state/circle_permissions_provider.dart';
import '../state/circle_state.dart';
import 'widgets/circle_governance_view.dart';
import 'widgets/circle_immersive_view.dart';
import 'widgets/circle_list_view.dart';
import 'widgets/circle_post_actions.dart';
import 'widgets/circle_publish_dialog.dart';

/// 校圈页仅允许纵向滚动，禁止横向拖拽与 overscroll。
class _CirclePageScrollBehavior extends MaterialScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (details.direction == AxisDirection.left ||
        details.direction == AxisDirection.right) {
      return child;
    }
    return super.buildOverscrollIndicator(context, child, details);
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}

class CirclePage extends ConsumerWidget {
  const CirclePage({super.key, this.onBack, this.governance = false});

  /// 智慧校园等内嵌场景：返回 dashboard / 来源页，不走 Navigator pop。
  final VoidCallback? onBack;

  /// 管理员「校圈治理」：待处理 / 已处理 / 全部动态三个页签，处理举报、
  /// 删除需写明原因；不提供发布入口。
  final bool governance;

  void _handleBack(BuildContext context, CircleController controller) {
    controller.stopMediaPlayback();
    if (onBack != null) {
      onBack!();
      return;
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacementNamed(RoutePaths.home);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(circleControllerProvider);
    final controller = ref.read(circleControllerProvider.notifier);
    final permissions = ref.watch(circlePermissionsProvider);
    final governanceTab = governance
        ? ref.watch(circleGovernanceControllerProvider.select((s) => s.tab))
        : CircleGovernanceTab.all;
    final showFeed = governanceTab == CircleGovernanceTab.all;
    final menuActions = CirclePostMenuActions(
      permissions: permissions,
      controller: controller,
      onGovernanceDelete: governance
          ? (post) => runGovernanceDelete(
              context,
              submit: (reason, remark) => ref
                  .read(circleGovernanceControllerProvider.notifier)
                  .deletePost(post.id, reason: reason, remark: remark),
            )
          : null,
    );

    // 智慧校园 overlay 等入口直接挂本页，树里没有 Scaffold / Material，
    // 需要自带 Material，否则 Text 会落到默认错误样式。
    return Material(
      type: MaterialType.transparency,
      child: ScrollConfiguration(
        behavior: _CirclePageScrollBehavior(),
        child: PopScope(
          canPop: onBack == null,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) {
              controller.stopMediaPlayback();
              return;
            }
            if (onBack != null) {
              _handleBack(context, controller);
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                padding: EdgeInsets.zero,
                bordered: false,
                backgroundImage: const DecorationImage(
                  image: AssetImage(AppAssets.xiaoquanHeaderBg),
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                ),
                child: AppPageHeader(
                  title: governance ? '校圈治理' : '校圈',
                  subtitle: governance
                      ? '处理同学和老师举报的动态，删除时需写明原因'
                      : '画室同学和老师分享的作品与日常',
                  onBack: () => _handleBack(context, controller),
                  actions: [
                    if (showFeed)
                      AppSegmented<CircleMode>(
                        trackColor: AppColors.page,
                        segments: const [
                          AppSegment(value: CircleMode.immersive, label: '沉浸'),
                          AppSegment(value: CircleMode.list, label: '列表'),
                        ],
                        value: state.mode,
                        onChanged: controller.setMode,
                      ),
                  ],
                  bottom: governance
                      ? _GovernanceTabs(
                          onLeaveFeed: controller.stopMediaPlayback,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: AppSpace.s12),
              Expanded(
                child: !showFeed
                    ? const CircleGovernanceView()
                    : state.mode == CircleMode.immersive
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpace.page,
                          AppSpace.s4,
                          AppSpace.page,
                          AppSpace.s24,
                        ),
                        child: ClipRRect(
                          borderRadius: AppRadius.br16,
                          child: CircleImmersiveView(
                            key: const ValueKey('immersive'),
                            state: state,
                            controller: controller,
                            permissions: permissions,
                            menuActions: menuActions,
                            mediaStopEpoch: state.mediaStopEpoch,
                          ),
                        ),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          CircleListView(
                            key: const ValueKey('list'),
                            state: state,
                            controller: controller,
                            menuActions: menuActions,
                            onPublish: governance
                                ? null
                                : () => showCirclePublishDialog(context),
                          ),
                          if (!governance && state.visiblePosts.isNotEmpty)
                            Positioned(
                              right: AppSpace.s20,
                              bottom: AppSpace.s20,
                              child: AppPressable(
                                semanticLabel: '发布动态',
                                onTap: () => showCirclePublishDialog(context),
                                child: const AppAssetGraphic(
                                  AppAssets.circlePublish,
                                  width: 48,
                                  height: 48,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 治理页签：「待处理」带数量（与管理员工作台「校圈治理」的数字同源），
/// 首次加载完成前不显示数量。
class _GovernanceTabs extends ConsumerWidget {
  const _GovernanceTabs({required this.onLeaveFeed});

  /// 离开「全部动态」前停掉大图模式里正在播放的视频。
  final VoidCallback onLeaveFeed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(
      circleGovernanceControllerProvider.select((s) => s.tab),
    );
    final pendingCount = ref.watch(
      circleGovernanceControllerProvider.select(
        (s) => s.loaded ? s.pendingTotal : null,
      ),
    );
    return AppTabs<CircleGovernanceTab>(
      tabs: [
        AppTab(
          value: CircleGovernanceTab.pending,
          label: '待处理',
          count: pendingCount,
        ),
        const AppTab(value: CircleGovernanceTab.handled, label: '已处理'),
        const AppTab(value: CircleGovernanceTab.all, label: '全部动态'),
      ],
      value: tab,
      onChanged: (next) {
        if (tab == CircleGovernanceTab.all && next != tab) onLeaveFeed();
        ref.read(circleGovernanceControllerProvider.notifier).setTab(next);
      },
    );
  }
}
