import 'package:flutter/material.dart';

import '../../../shell/ui/shell_layout.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';
import 'smart_campus_home_card.dart';
import 'smart_campus_quick_action_icon.dart';

/// 智慧校园首页快捷入口容器内边距（与管理员端一致）。
const double kSmartCampusQuickActionsCardPaddingH = 24;
const double kSmartCampusQuickActionsCardPaddingV = 28;

/// 快捷入口网格：每行 5 个，行间距 24，列间距 12。
const int kSmartCampusQuickActionsRowSize = 5;
const double kSmartCampusQuickActionsRowGap = 24;
const double kSmartCampusQuickActionsColGap = 12;

/// 单个入口 cell 上下内边距、图标与文案间距。
const double kSmartCampusQuickActionCellPaddingV = 4;
const double kSmartCampusQuickActionLabelGap = 8;

class SmartCampusQuickActionItem {
  const SmartCampusQuickActionItem({
    required this.label,
    required this.assetPath,
    this.badgeLabel,
    this.onTap,
  });

  final String label;
  final String assetPath;
  final String? badgeLabel;
  final VoidCallback? onTap;
}

/// 智慧校园各端首页快捷入口白卡：布局与管理员端完全统一。
class SmartCampusQuickActionsCard extends StatelessWidget {
  const SmartCampusQuickActionsCard({
    super.key,
    required this.items,
    this.rowSize = kSmartCampusQuickActionsRowSize,
    this.iconSize = kSmartCampusQuickActionIconSize,
  });

  final List<SmartCampusQuickActionItem> items;
  final int rowSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final rowCount = items.isEmpty ? 0 : ((items.length - 1) ~/ rowSize) + 1;

    return SmartCampusHomeCard(
      clipContent: false,
      padding: EdgeInsets.symmetric(
        horizontal: ui(kSmartCampusQuickActionsCardPaddingH),
        vertical: ui(kSmartCampusQuickActionsCardPaddingV),
      ),
      child: Column(
        children: [
          for (var ri = 0; ri < rowCount; ri++) ...[
            if (ri > 0) SizedBox(height: ui(kSmartCampusQuickActionsRowGap)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var ci = 0; ci < rowSize; ci++) ...[
                  if (ci > 0) SizedBox(width: ui(kSmartCampusQuickActionsColGap)),
                  Expanded(
                    child: () {
                      final idx = ri * rowSize + ci;
                      if (idx < items.length) {
                        return SmartCampusQuickActionCell(
                          item: items[idx],
                          iconSize: iconSize,
                        );
                      }
                      return const SizedBox.shrink();
                    }(),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 单个快捷入口：图标槽固定居中；角标相对 icon 绝对定位，不参与列宽。
class SmartCampusQuickActionCell extends StatelessWidget {
  const SmartCampusQuickActionCell({
    super.key,
    required this.item,
    this.iconSize = kSmartCampusQuickActionIconSize,
  });

  final SmartCampusQuickActionItem item;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final slot = ui(iconSize);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: item.onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: ui(kSmartCampusQuickActionCellPaddingV),
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 仅 slot×slot 参与列宽；角标在 icon 组件内绝对定位溢出
              SizedBox(
                width: slot,
                height: slot,
                child: SmartCampusQuickActionIcon(
                  assetPath: item.assetPath,
                  badgeLabel: item.badgeLabel,
                  size: iconSize,
                ),
              ),
              SizedBox(height: ui(kSmartCampusQuickActionLabelGap)),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(14),
                  height: 1.2,
                  fontWeight: AppFont.w500,
                  color: const Color(0xFF1A1A1A),
                  fontFamily: 'PingFang SC',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
