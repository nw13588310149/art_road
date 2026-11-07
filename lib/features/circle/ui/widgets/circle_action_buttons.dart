import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../state/circle_state.dart';

/// 单个操作按钮（点赞 / 评论 / 收藏）：图标 + 数量。
///
/// 卡片模式横排、三级灰图标；大图模式（[dark]）竖排、白色图标。激活态统一品牌紫。
/// 大图模式的按钮可能压在浅色画面（白纸素描）上，图标和数字带一层柔和投影。
class CircleActionButton extends StatelessWidget {
  const CircleActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
    this.active = false,
    this.activeIcon,
    this.dark = false,
  });

  final IconData icon;
  final IconData? activeIcon;

  /// 读屏文字，如「点赞」。
  final String label;
  final int count;
  final VoidCallback onTap;
  final bool active;
  final bool dark;

  static final _darkShadows = <Shadow>[
    Shadow(color: AppColors.ink.withValues(alpha: 0.5), blurRadius: 4),
  ];

  @override
  Widget build(BuildContext context) {
    final idleColor = dark ? AppColors.onBrand : AppColors.textTertiary;
    final color = active ? AppColors.brand : idleColor;
    final shadows = dark ? _darkShadows : null;
    final glyph = Icon(
      active ? (activeIcon ?? icon) : icon,
      size: dark ? 28 : 20,
      color: color,
      shadows: shadows,
    );
    final number = Text(
      formatCircleCount(count),
      maxLines: 1,
      style: AppText.number(
        size: dark ? 14 : 13,
        color: dark ? AppColors.onBrand : AppColors.textSecondary,
      ).copyWith(shadows: shadows),
    );
    return AppPressable(
      onTap: onTap,
      semanticLabel: label,
      selected: active,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
        child: dark
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  glyph,
                  const SizedBox(height: AppSpace.s4),
                  number,
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  glyph,
                  const SizedBox(width: AppSpace.s4),
                  number,
                ],
              ),
      ),
    );
  }
}

/// 卡片模式下的一行三个操作按钮。
class CircleActionRow extends StatelessWidget {
  const CircleActionRow({
    super.key,
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onFavorite,
  });

  final CirclePost post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: CircleActionButton(
              icon: Icons.favorite_border_rounded,
              activeIcon: Icons.favorite_rounded,
              label: post.liked ? '取消点赞' : '点赞',
              active: post.liked,
              count: post.likeCount,
              onTap: onLike,
            ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: CircleActionButton(
              icon: Icons.chat_bubble_outline_rounded,
              label: '评论',
              count: post.commentCount,
              onTap: onComment,
            ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: CircleActionButton(
              icon: Icons.bookmark_border_rounded,
              activeIcon: Icons.bookmark_rounded,
              label: post.favorited ? '取消收藏' : '收藏',
              active: post.favorited,
              count: post.favoriteCount,
              onTap: onFavorite,
            ),
          ),
        ),
      ],
    );
  }
}
