import 'package:flutter/material.dart';

import 'app_icon_button.dart';
import 'app_spacing.dart';

/// 页面工具栏：只呈现返回、操作和筛选。页面名称和说明用于无障碍导航。
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const <Widget>[],
    this.bottom,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpace.page,
      AppSpace.s12,
      AppSpace.page,
      AppSpace.s12,
    ),
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget? bottom;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final hasActions = onBack != null || actions.isNotEmpty;
    final filters = bottom;
    if (!hasActions && filters == null) return const SizedBox.shrink();

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: title,
      hint: subtitle,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasActions)
              Row(
                children: [
                  if (onBack != null) ...[
                    AppIconButton.back(onTap: onBack),
                    const SizedBox(width: AppSpace.s12),
                  ],
                  if (actions.isNotEmpty)
                    Expanded(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpace.s8,
                        runSpacing: AppSpace.s8,
                        children: actions,
                      ),
                    ),
                ],
              ),
            if (hasActions && filters != null)
              const SizedBox(height: AppSpace.s12),
            ?filters,
          ],
        ),
      ),
    );
  }
}
