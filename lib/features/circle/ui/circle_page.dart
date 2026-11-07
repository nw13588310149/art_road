import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/ui/ui.dart';
import '../state/circle_controller.dart';
import '../state/circle_permissions_provider.dart';
import '../state/circle_state.dart';
import 'widgets/circle_immersive_view.dart';
import 'widgets/circle_list_view.dart';
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

  /// 管理员「校圈治理」入口：标题改为校圈治理，不提供发布入口。
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
              AppPageHeader(
                title: governance ? '校圈治理' : '校圈',
                subtitle: governance
                    ? '查看画室动态，删除不合适的内容'
                    : '画室同学和老师分享的作品与日常',
                onBack: () => _handleBack(context, controller),
                actions: [
                  AppSegmented<CircleMode>(
                    segments: const [
                      AppSegment(value: CircleMode.list, label: '卡片'),
                      AppSegment(value: CircleMode.immersive, label: '大图'),
                    ],
                    value: state.mode,
                    onChanged: controller.setMode,
                  ),
                  if (!governance)
                    AppButton(
                      label: '发布动态',
                      icon: Icons.add_rounded,
                      size: AppButtonSize.sm,
                      onTap: () => showCirclePublishDialog(context),
                    ),
                ],
              ),
              Expanded(
                child: state.mode == CircleMode.immersive
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
                            mediaStopEpoch: state.mediaStopEpoch,
                          ),
                        ),
                      )
                    : CircleListView(
                        key: const ValueKey('list'),
                        state: state,
                        controller: controller,
                        permissions: permissions,
                        onPublish: governance
                            ? null
                            : () => showCirclePublishDialog(context),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
