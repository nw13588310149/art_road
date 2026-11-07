import 'package:flutter/material.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/ui/ui.dart';
import '../../personal_center/ui/my_qr_code_page.dart';
import 'terms_page.dart';

/// 1.0 遗留路由的承接页：已有新页面的直接渲染新页面，其余显示「暂未开放」。
class LegacyPlaceholderContent extends StatelessWidget {
  const LegacyPlaceholderContent({
    required this.routeName,
    required this.title,
    super.key,
  });

  final String routeName;
  final String title;

  void _back(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacementNamed(RoutePaths.home);
  }

  @override
  Widget build(BuildContext context) {
    switch (routeName) {
      case RoutePaths.qrcode:
        return const MyQrCodePage();
      case RoutePaths.xieyi:
        return TermsContent(onBack: () => _back(context));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(title: title, onBack: () => _back(context)),
        Expanded(
          child: AppEmptyState(
            icon: Icons.construction_outlined,
            title: '「$title」暂未开放',
            description: '该功能正在整理中，可以先返回继续使用其他功能',
            actionLabel: '返回',
            onAction: () => _back(context),
          ),
        ),
      ],
    );
  }
}
