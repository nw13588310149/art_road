import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/circle_controller.dart';
import '../state/circle_permissions_provider.dart';
import '../state/circle_state.dart';
import 'widgets/circle_immersive_view.dart';
import 'widgets/circle_list_view.dart';
import 'widgets/circle_publish_dialog.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

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
  const CirclePage({super.key, this.onBack});

  /// 智慧校园等内嵌场景：返回 dashboard / 来源页，不走 Navigator pop。
  final VoidCallback? onBack;

  void _handleBack(BuildContext context, CircleController controller) {
    controller.stopMediaPlayback();
    if (onBack != null) {
      onBack!();
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(circleControllerProvider);
    final controller = ref.read(circleControllerProvider.notifier);
    final ui = DashboardScaleScope.of(context).ui;

    // 顶部标题栏与下方内容区是两个独立的 16 圆角面板，
    // 中间留 16px 透明间距让 Dashboard 的 #EFF3FC 背景透出来。
    // 智慧校园 overlay 等入口用 ColoredBox 包一层后直接挂本页，树里没有
    // Scaffold/Material，Text 会落到 _errorTextStyle 并在 iOS 上出现黄色下划线。
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                width: constraints.maxWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CircleHeader(
                      mode: state.mode,
                      onBack: () => _handleBack(context, controller),
                      onModeChanged: controller.setMode,
                    ),
                    SizedBox(height: ui(16)),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(ui(16)),
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            Positioned.fill(
                              child: _CircleBody(
                                state: state,
                                controller: controller,
                                permissions:
                                    ref.watch(circlePermissionsProvider),
                              ),
                            ),
                            // 沉浸模式下铺满全屏显示视频/图片，FAB 会挡视线，隐藏掉。
                            if (state.mode != CircleMode.immersive)
                              Positioned(
                                right: ui(20),
                                bottom: ui(20),
                                child: _PublishFab(
                                  onTap: () =>
                                      showCirclePublishDialog(context),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Header: 背景图 + 返回按钮 + 标题 "校圈" + 沉浸/列表 切换胶囊
// ─────────────────────────────────────────────────────────────────────

class _CircleHeader extends StatelessWidget {
  const _CircleHeader({
    required this.mode,
    required this.onBack,
    required this.onModeChanged,
  });

  final CircleMode mode;
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
        image: DecorationImage(
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
              child: Text(
                '校圈',
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
          _CircleModeSwitch(mode: mode, onChanged: onModeChanged),
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
    return GestureDetector(
      onTap: onTap,
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
                        color: const Color(0xFF8741FF),
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
  });

  final CircleState state;
  final CircleController controller;
  final CirclePermissions permissions;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ...previousChildren,
            ?currentChild,
          ],
        );
      },
      child: state.mode == CircleMode.immersive
          ? CircleImmersiveView(
              key: const ValueKey('immersive'),
              state: state,
              controller: controller,
              permissions: permissions,
              mediaStopEpoch: state.mediaStopEpoch,
            )
          : CircleListView(
              key: const ValueKey('list'),
              state: state,
              controller: controller,
              permissions: permissions,
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
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: '发布动态',
          child: Container(
            width: ui(48),
            height: ui(48),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0x40A07BFF),
                  blurRadius: ui(16),
                  offset: Offset(0, ui(6)),
                ),
              ],
            ),
            child: Image.asset(
              AppAssets.schoolFabAdd,
              width: ui(48),
              height: ui(48),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
