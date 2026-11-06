import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';

import '../../shell/ui/shell_layout.dart';
import '../state/school_website_controller.dart';
import 'widgets/school_website_html_view.dart';

/// 校园官网（微校）：在 Shell 主内容区内 100% 铺满渲染后端 HTML。
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

/// 单独 Consumer 子树，避免整页因 html 加载状态反复重建 Shell 外层。
class _SchoolWebsiteBody extends ConsumerWidget {
  const _SchoolWebsiteBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(schoolWebsiteControllerProvider);

    if (state.loading) {
      return const Center(child: AppLoadingIndicator());
    }
    if (state.errorMessage.isNotEmpty) {
      return Center(
        child: Text(
          state.errorMessage,
          style: const TextStyle(
            color: Color(0xFF6D6B75),
            fontSize: 14,
            fontFamily: 'PingFang SC',
          ),
        ),
      );
    }

    return SchoolWebsiteHtmlView(html: state.htmlContent);
  }
}
