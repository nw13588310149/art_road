import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_icon_button.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// 页头：可选返回按钮 + 标题 + 副标题 + 右侧操作，[bottom] 放筛选条或页签。
///
/// 多个操作之间自动留 8px 间距；主操作放在最右侧。
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const <Widget>[],
    this.bottom,
    this.centerTitle = false,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpace.page,
      AppSpace.s16,
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
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    final note = subtitle;
    final back = onBack == null
        ? null
        : AppIconButton(
            icon: centerTitle
                ? Icons.chevron_left_rounded
                : Icons.arrow_back_ios_new_rounded,
            semanticLabel: '返回',
            size: AppButtonSize.sm,
            onTap: onBack,
          );
    final titleBlock = Column(
      crossAxisAlignment: centerTitle
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: centerTitle ? AppText.title16 : AppText.title20,
        ),
        if (note != null && note.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body13,
          ),
        ],
      ],
    );
    if (centerTitle) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
            ),
            child: NavigationToolbar(
              leading: back,
              middle: titleBlock,
              trailing: actions.isEmpty
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(width: AppSpace.s8),
                          actions[i],
                        ],
                      ],
                    ),
            ),
          ),
          if (bottom case final filters?)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.page,
                AppSpace.s12,
                AppSpace.page,
                AppSpace.s8,
              ),
              child: filters,
            ),
        ],
      );
    }
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (back != null) ...[back, const SizedBox(width: AppSpace.s12)],
              Expanded(child: titleBlock),
              for (var i = 0; i < actions.length; i++) ...[
                SizedBox(width: i == 0 ? AppSpace.s12 : AppSpace.s8),
                actions[i],
              ],
            ],
          ),
          if (bottom != null) ...[
            const SizedBox(height: AppSpace.s12),
            bottom!,
          ],
        ],
      ),
    );
  }
}
