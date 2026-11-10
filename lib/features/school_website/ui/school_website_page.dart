import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../state/school_website_controller.dart';
import 'widgets/school_website_html_view.dart';

/// 画室官网：在外壳内容区内铺满渲染后端 HTML。
class SchoolWebsitePage extends ConsumerWidget {
  const SchoolWebsitePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(schoolWebsiteControllerProvider);
    final controller = ref.read(schoolWebsiteControllerProvider.notifier);

    final Widget body;
    if (state.loading) {
      body = const Center(child: AppLoadingIndicator());
    } else if (state.errorMessage.isNotEmpty) {
      body = AppErrorState(
        title: '官网加载失败',
        description: state.errorMessage,
        onRetry: controller.reload,
      );
    } else {
      body = SchoolWebsiteHtmlView(html: state.htmlContent);
    }

    return ClipRRect(
      borderRadius: AppRadius.br16,
      child: ColoredBox(color: AppColors.surface, child: body),
    );
  }
}
