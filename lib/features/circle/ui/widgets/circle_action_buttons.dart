import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/widgets/app_asset_graphic.dart';
import '../../state/circle_state.dart';

/// 单个操作按钮（点赞 / 评论 / 收藏）：图标 + 数量。
///
/// 卡片模式横排，大图模式（[dark]）竖排。
class CircleActionButton extends StatelessWidget {
  const CircleActionButton({
    super.key,
    required this.iconAsset,
    required this.label,
    required this.count,
    required this.onTap,
    this.active = false,
    this.dark = false,
  });

  final String iconAsset;

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
    final shadows = dark ? _darkShadows : null;
    final size = dark ? 28.0 : 24.0;
    final glyph = AppAssetGraphic(iconAsset, width: size, height: size);
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
              iconAsset: post.liked
                  ? AppAssets.circleLiked
                  : AppAssets.circleLike,
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
              iconAsset: AppAssets.circleComment,
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
              iconAsset: post.favorited
                  ? AppAssets.circleSaved
                  : AppAssets.circleSave,
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
