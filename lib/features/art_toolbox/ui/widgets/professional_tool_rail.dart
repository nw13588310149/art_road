import 'package:flutter/material.dart';
import '../../../../core/ui/ui.dart';
import '../../data/toolbox_catalog.dart';
import 'page_tools_drawer.dart';

/// 44 点触控热区；长按显示名称，拖动握柄移动整列工具。
class ProfessionalToolRail extends StatelessWidget {
  const ProfessionalToolRail({
    required this.expanded,
    required this.selected,
    required this.onSelect,
    required this.onPointer,
    required this.onAllTools,
    required this.onToggle,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
    super.key,
  });
  final bool expanded;
  final ArtTool? selected;
  final ValueChanged<ArtTool> onSelect;
  final VoidCallback onPointer, onAllTools, onToggle, onDragCancel;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  @override
  Widget build(BuildContext context) => Material(
    key: const ValueKey('professional-tool-rail'),
    color: AppColors.surface,
    elevation: 3,
    borderRadius: AppRadius.br12,
    clipBehavior: Clip.antiAlias,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: AppRadius.br12,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            GestureDetector(
              onPanStart: onDragStart,
              onPanUpdate: onDragUpdate,
              onPanEnd: onDragEnd,
              onPanCancel: onDragCancel,
              child: RailButton(
                key: const ValueKey('floating-toolbox-handle'),
                icon: expanded ? Icons.drag_indicator : Icons.handyman_outlined,
                label: expanded ? '收起工具栏，拖动可移动' : '展开工具栏，拖动可移动',
                onTap: onToggle,
              ),
            ),
            if (expanded) ...[
              const Divider(height: 8),
              RailButton(
                icon: Icons.near_me_outlined,
                label: '恢复页面操作',
                selected: selected == null,
                onTap: onPointer,
              ),
              for (final tool in pageQuickTools)
                RailButton(
                  icon: tool.icon,
                  label:
                      '在当前页面使用${tool == ArtTool.quickSketch ? '速写计时' : tool.label}',
                  selected: selected == tool,
                  onTap: () => onSelect(tool),
                ),
              const Divider(height: 8),
              RailButton(
                icon: Icons.apps_rounded,
                label: '打开完整工具箱，17 个工具',
                onTap: onAllTools,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class RailButton extends StatelessWidget {
  const RailButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.enabled = true,
    super.key,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected, enabled;
  @override
  Widget build(BuildContext context) => AppPressable(
    semanticLabel: label,
    selected: selected,
    enabled: enabled,
    onTap: onTap,
    onLongPress: () => AppToast.show(context, label),
    child: Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.brandWash : Colors.transparent,
        borderRadius: AppRadius.br8,
      ),
      child: Icon(
        icon,
        size: 22,
        color: selected ? AppColors.brand : AppColors.ink,
      ),
    ),
  );
}
