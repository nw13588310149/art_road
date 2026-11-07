import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../state/circle_state.dart';

/// 帖子标签：置顶（品牌色）/ 热门（警示色），统一用 AppTag。
class CircleBadgeChip extends StatelessWidget {
  const CircleBadgeChip({super.key, required this.badge});

  final CircleBadge badge;

  @override
  Widget build(BuildContext context) {
    return switch (badge) {
      CircleBadge.pinned => const AppTag(
        label: '置顶',
        tone: AppTone.brand,
        icon: Icons.push_pin_outlined,
      ),
      CircleBadge.hot => const AppTag(
        label: '热门',
        tone: AppTone.warning,
        icon: Icons.local_fire_department_outlined,
      ),
    };
  }
}

/// 一行多个标签。
class CircleBadgeRow extends StatelessWidget {
  const CircleBadgeRow({super.key, required this.badges});

  final List<CircleBadge> badges;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: AppSpace.s4,
      runSpacing: AppSpace.s4,
      children: [for (final b in badges) CircleBadgeChip(badge: b)],
    );
  }
}
