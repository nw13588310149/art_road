import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/ui/ui.dart';
import '../../shell/ui/shell_layout.dart';
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
    final ui = DashboardScaleScope.of(context).ui;
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
    final showPublish =
        !governance && state.mode != CircleMode.immersive;

    // 顶部标题栏与下方内容区是两个独立的 16 圆角面板，中间留 16 透明间距
    // 露出外壳的 #EFF3FC 底色。智慧校园 overlay 等入口直接挂本页，树里没有
    // Scaffold / Material，需要自带 Material，否则 Text 会落到默认错误样式。
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
              _CircleHeader(
                title: governance ? '校圈治理' : '校圈',
                mode: state.mode,
                showModeSwitch: showFeed,
                onBack: () => _handleBack(context, controller),
                onModeChanged: controller.setMode,
              ),
              SizedBox(height: ui(16)),
              if (governance) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: CircleGovernanceTabs(
                    onLeaveFeed: controller.stopMediaPlayback,
                  ),
                ),
                SizedBox(height: ui(16)),
              ],
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(ui(16)),
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned.fill(
                        child: showFeed
                            ? _CircleBody(
                                state: state,
                                controller: controller,
                                permissions: permissions,
                                menuActions: menuActions,
                                showPublish: !governance,
                              )
                            : const CircleGovernanceView(),
                      ),
                      // 沉浸模式下铺满显示视频 / 图片，发布按钮会挡视线，隐藏掉。
                      if (showPublish)
                        Positioned(
                          right: ui(20),
                          bottom: ui(20),
                          child: _PublishFab(
                            onTap: () => showCirclePublishDialog(context),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Header: 背景图 + 返回按钮 + 居中标题 + 沉浸 / 列表 切换胶囊
// ─────────────────────────────────────────────────────────────────────

class _CircleHeader extends StatelessWidget {
  const _CircleHeader({
    required this.title,
    required this.mode,
    required this.showModeSwitch,
    required this.onBack,
    required this.onModeChanged,
  });

  final String title;
  final CircleMode mode;
  final bool showModeSwitch;
  final VoidCallback onBack;
  final ValueChanged<CircleMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(62),
      padding: EdgeInsets.symmetric(horizontal: ui(16)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(16)),
        image: const DecorationImage(
          image: AssetImage(AppAssets.xiaoquanHeaderBg),
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          _CircleBackButton(onTap: onBack),
          Expanded(
            child: Center(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: TextStyle(
                    color: const Color(0xFF0B081A),
                    fontSize: ui(16),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          if (showModeSwitch)
            _CircleModeSwitch(mode: mode, onChanged: onModeChanged)
          else
            SizedBox(width: ui(_CircleModeSwitch._switchWidth)),
        ],
      ),
    );
  }
}

class _CircleBackButton extends StatelessWidget {
  const _CircleBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return AppPressable(
      onTap: onTap,
      semanticLabel: '返回',
      child: Container(
        width: ui(32),
        height: ui(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3), width: 1),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.chevron_left,
          color: const Color(0xFF1C274C),
          size: ui(20),
        ),
      ),
    );
  }
}

class _CircleModeSwitch extends StatelessWidget {
  const _CircleModeSwitch({required this.mode, required this.onChanged});

  final CircleMode mode;
  final ValueChanged<CircleMode> onChanged;

  static const _switchWidth = 116.0;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final selectedIndex = mode == CircleMode.immersive ? 0 : 1;

    return SizedBox(
      width: ui(_switchWidth),
      child: Container(
        height: ui(36),
        padding: EdgeInsets.all(ui(2)),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F2FC),
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final segmentWidth = constraints.maxWidth / 2;
            return SizedBox(
              height: constraints.maxHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    left: selectedIndex * segmentWidth,
                    top: 0,
                    bottom: 0,
                    width: segmentWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(ui(6)),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _ModeSegment(
                          label: '沉浸',
                          selected: mode == CircleMode.immersive,
                          onTap: () => onChanged(CircleMode.immersive),
                        ),
                      ),
                      Expanded(
                        child: _ModeSegment(
                          label: '列表',
                          selected: mode == CircleMode.list,
                          onTap: () => onChanged(CircleMode.list),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ModeSegment extends StatelessWidget {
  const _ModeSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return AppPressable(
      onTap: onTap,
      selected: selected,
      child: SizedBox.expand(
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF000000),
              fontSize: ui(12),
              fontFamily: 'PingFang SC',
              fontWeight: selected ? AppFont.w500 : AppFont.w400,
              height: 1,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Body: 根据 mode 切换列表 / 沉浸视图
// ─────────────────────────────────────────────────────────────────────

class _CircleBody extends StatelessWidget {
  const _CircleBody({
    required this.state,
    required this.controller,
    required this.permissions,
    required this.menuActions,
    required this.showPublish,
  });

  final CircleState state;
  final CircleController controller;
  final CirclePermissions permissions;
  final CirclePostMenuActions menuActions;

  /// 列表底部是否给右下角发布按钮留位置。
  final bool showPublish;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: [...previousChildren, ?currentChild],
        );
      },
      child: state.mode == CircleMode.immersive
          ? CircleImmersiveView(
              key: const ValueKey('immersive'),
              state: state,
              controller: controller,
              permissions: permissions,
              menuActions: menuActions,
              mediaStopEpoch: state.mediaStopEpoch,
            )
          : CircleListView(
              key: const ValueKey('list'),
              state: state,
              controller: controller,
              menuActions: menuActions,
              reservePublishSpace: showPublish,
            ),
    );
  }
}

/// 校圈右下角悬浮发布按钮：48×48 紫色 + 号，点击弹出发布动态对话框。
class _PublishFab extends StatelessWidget {
  const _PublishFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return AppPressable(
      onTap: onTap,
      semanticLabel: '发布动态',
      child: Tooltip(
        message: '发布动态',
        excludeFromSemantics: true,
        child: Container(
          width: ui(48),
          height: ui(48),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.brand.withValues(alpha: 0.25),
                blurRadius: ui(16),
                offset: Offset(0, ui(6)),
              ),
            ],
          ),
          child: Image.asset(
            AppAssets.circlePublish,
            width: ui(48),
            height: ui(48),
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 校圈治理：黑底状态页签（与学生管理等原版页签同款）
// ─────────────────────────────────────────────────────────────────────

/// 治理页签：「待处理」带数量（与管理员工作台「校圈治理」的数字同源），
/// 首次加载完成前不显示数量。
class CircleGovernanceTabs extends ConsumerWidget {
  const CircleGovernanceTabs({super.key, required this.onLeaveFeed});

  /// 离开「全部动态」前停掉大图模式里正在播放的视频。
  final VoidCallback onLeaveFeed;

  static const _tabs = <(CircleGovernanceTab, String)>[
    (CircleGovernanceTab.pending, '待处理'),
    (CircleGovernanceTab.handled, '已处理'),
    (CircleGovernanceTab.all, '全部动态'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = DashboardScaleScope.of(context).ui;
    final tab = ref.watch(
      circleGovernanceControllerProvider.select((s) => s.tab),
    );
    final pendingCount = ref.watch(
      circleGovernanceControllerProvider.select(
        (s) => s.loaded ? s.pendingTotal : null,
      ),
    );
    return Container(
      height: ui(44),
      padding: EdgeInsets.all(ui(4)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: const Color(0xFFF3F2F3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (value, label) in _tabs)
            _GovernanceTabPill(
              label: label,
              count: value == CircleGovernanceTab.pending ? pendingCount : null,
              active: value == tab,
              onTap: () {
                if (tab == CircleGovernanceTab.all && value != tab) {
                  onLeaveFeed();
                }
                ref
                    .read(circleGovernanceControllerProvider.notifier)
                    .setTab(value);
              },
            ),
        ],
      ),
    );
  }
}

class _GovernanceTabPill extends StatelessWidget {
  const _GovernanceTabPill({
    required this.label,
    required this.active,
    required this.onTap,
    this.count,
  });

  final String label;
  final int? count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final style = TextStyle(
      fontSize: ui(14),
      height: 1,
      fontWeight: AppFont.w500,
      color: active ? Colors.white : const Color(0xFF6D6B75),
      fontFamily: 'PingFang SC',
    );
    final count = this.count;
    return AppPressable(
      onTap: onTap,
      selected: active,
      child: Container(
        height: ui(36),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        margin: EdgeInsets.symmetric(horizontal: ui(2)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0B081A) : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: style),
            if (count != null) ...[
              SizedBox(width: ui(4)),
              Text('($count)', style: style),
            ],
          ],
        ),
      ),
    );
  }
}
