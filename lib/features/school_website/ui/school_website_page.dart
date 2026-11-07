import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/ui/ui.dart';
import '../state/school_website_controller.dart';
import 'widgets/school_website_html_view.dart';

/// 画室官网：页头 + 下方嵌入后端下发的官网 HTML。
class SchoolWebsitePage extends ConsumerWidget {
  const SchoolWebsitePage({super.key});

  void _back(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacementNamed(RoutePaths.school);
  }

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(
          title: state.title.isEmpty ? '画室官网' : state.title,
          subtitle: '画室简介、课程、师资与联系方式',
          onBack: () => _back(context),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              AppSpace.s4,
              AppSpace.page,
              AppSpace.s24,
            ),
            child: ClipRRect(
              borderRadius: AppRadius.br12,
              child: ColoredBox(color: AppColors.surface, child: body),
            ),
          ),
        ),
      ],
    );
  }
}
