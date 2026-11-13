import 'package:flutter/material.dart';

import '../../../shell/ui/shell_layout.dart';

/// 智慧校园首页快捷入口图标展示尺寸（各端统一）。
const double kSmartCampusQuickActionIconSize = 43;

/// 角标相对图标右上角的溢出像素（绝对定位绘制，不参与布局宽度）。
const double kSmartCampusQuickActionBadgeOutset = 2;

/// 固定 [size]×[size] 图标槽。
///
/// - 布局占位仅由图标槽决定（[SizedBox] + 全 [Positioned] 子节点）
/// - 角标相对图标槽右上角绝对定位（`right/top` 负偏移），完整溢出绘制
/// - 需配合外层 [SmartCampusHomeCard.clipContent] = false 避免裁切
class SmartCampusQuickActionIcon extends StatelessWidget {
  const SmartCampusQuickActionIcon({
    super.key,
    required this.assetPath,
    this.badgeLabel,
    this.size = kSmartCampusQuickActionIconSize,
  });

  final String assetPath;
  final String? badgeLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final slot = ui(size);
    final outset = ui(kSmartCampusQuickActionBadgeOutset);
    final showBadge = badgeLabel != null && badgeLabel!.isNotEmpty;

    return SizedBox(
      width: slot,
      height: slot,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: slot,
            height: slot,
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
            ),
          ),
          if (showBadge)
            Positioned(
              right: -outset,
              top: -outset,
              child: SmartCampusQuickActionBadge(label: badgeLabel!),
            ),
        ],
      ),
    );
  }
}

/// 快捷入口右上角红色数字角标。
class SmartCampusQuickActionBadge extends StatelessWidget {
  const SmartCampusQuickActionBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      constraints: BoxConstraints(minWidth: ui(16)),
      height: ui(15),
      padding: EdgeInsets.symmetric(horizontal: ui(4)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF04545),
        borderRadius: BorderRadius.circular(ui(20)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: ui(10),
          height: 1.0,
          fontWeight: FontWeight.w800,
          fontFamily: 'Manrope',
        ),
      ),
    );
  }
}
