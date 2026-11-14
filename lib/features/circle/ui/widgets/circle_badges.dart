import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../../../core/widgets/app_asset_graphic.dart';
import '../../../shell/ui/shell_layout.dart';
import '../../state/circle_state.dart';

const _kPinIcon = 'assets/images/school/1.png';
const _kHotIcon = 'assets/images/school/2.png';

/// 单个标签胶囊：置顶 / 热门。
class CircleBadgeChip extends StatelessWidget {
  const CircleBadgeChip({super.key, required this.badge});

  final CircleBadge badge;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final pinned = badge == CircleBadge.pinned;
    final bg = pinned ? AppColors.brandTint : const Color(0xFFFFE5E7);
    final fg = pinned ? AppColors.brand : const Color(0xFFFF323C);
    final iconAsset = pinned ? _kPinIcon : _kHotIcon;
    final label = pinned ? '置顶' : '热门';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(2)),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppAssetGraphic(iconAsset, width: ui(12), height: ui(12)),
          SizedBox(width: ui(2)),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: ui(11),
              fontFamily: 'PingFang SC',
              height: 15.24 / 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// 一行多个标签。
class CircleBadgeRow extends StatelessWidget {
  const CircleBadgeRow({super.key, required this.badges});

  final List<CircleBadge> badges;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (badges.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: ui(6),
      runSpacing: ui(4),
      children: [for (final b in badges) CircleBadgeChip(badge: b)],
    );
  }
}
