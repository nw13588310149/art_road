import 'package:flutter/material.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';

/// 智慧校园空状态：统一渲染组件库 [AppEmptyState]（48 图标块 + 标题 + 说明 +
/// 至多一个操作），保留旧的参数以便各页逐步迁移。
///
/// [illustration] 为旧参数，插图不再绘制；[compact] 只缩小上下留白。
class SmartCampusEmptyState extends StatelessWidget {
  const SmartCampusEmptyState({
    super.key,
    required this.title,
    this.subtitle = '',
    this.illustration,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    this.padding,
  });

  final String title;
  final String subtitle;
  final String? illustration;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          padding ??
          EdgeInsets.symmetric(
            vertical: compact ? AppSpace.s16 : AppSpace.s32,
          ),
      child: AppEmptyState(
        icon: icon,
        title: title,
        description: subtitle.isEmpty ? null : subtitle,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
    );
  }
}
