import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_pressable.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// 内容卡片：白底 + 1px 浅描边 + 圆角 16，静止时没有阴影。
///
/// 传 [title] 时顶部带标题行，[trailing] 放在标题行右侧（如「更多」、筛选）。
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpace.card),
    this.onTap,
    this.color = AppColors.surface,
    this.radius = AppRadius.card,
    this.bordered = true,
    super.key,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final double radius;

  /// 放在白色面板里的浅灰子卡片可关掉描边。
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final heading = title;
    final note = subtitle;
    Widget body = child;
    if (heading != null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: heading, style: AppText.title16),
                      if (note != null && note.isNotEmpty)
                        TextSpan(text: '  $note', style: AppText.caption12),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpace.s12),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          child,
        ],
      );
    }
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: bordered ? Border.all(color: AppColors.lineSoft) : null,
      ),
      child: body,
    );
    if (onTap == null) {
      return card;
    }
    return AppPressable(onTap: onTap, child: card);
  }
}
