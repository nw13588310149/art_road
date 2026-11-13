import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/school_website_controller.dart';
import 'widgets/school_website_html_view.dart';

/// 画室官网：在外壳内容区内铺满渲染后端 HTML。
class SchoolWebsitePage extends ConsumerWidget {
  const SchoolWebsitePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = DashboardScaleScope.of(context).ui;

    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(ShellLayoutSpec.panelRadius)),
      clipBehavior: Clip.hardEdge,
      child: const ColoredBox(
        color: Colors.white,
        child: _SchoolWebsiteBody(),
      ),
    );
  }
}

/// 单独 Consumer 子树，避免整页因 html 加载状态反复重建外壳外层。
class _SchoolWebsiteBody extends ConsumerWidget {
  const _SchoolWebsiteBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(schoolWebsiteControllerProvider);
    final controller = ref.read(schoolWebsiteControllerProvider.notifier);

    if (state.loading) {
      return const Center(child: AppLoadingIndicator());
    }
    if (state.errorMessage.isNotEmpty) {
      return AppErrorState(
        title: '官网加载失败',
        description: state.errorMessage,
        onRetry: controller.reload,
      );
    }

    return SchoolWebsiteHtmlView(html: state.htmlContent);
  }
}
