import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../state/circle_state.dart';
import 'circle_action_buttons.dart';
import 'circle_badges.dart';
import 'circle_post_menu.dart';
import 'circle_video_play_button.dart';

/// 卡片模式下的单个帖子：作者 / 文字 / 配图 / 操作按钮。
///
/// 删除、举报收在作者行右侧的「···」菜单里，两者都没有时不显示菜单。
class CirclePostCard extends StatelessWidget {
  const CirclePostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onFavorite,
    required this.onTap,
    this.onDeletePost,
    this.onReportPost,
  });

  final CirclePost post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onFavorite;
  final VoidCallback onTap;
  final VoidCallback? onDeletePost;
  final VoidCallback? onReportPost;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s12,
        AppSpace.s12,
        AppSpace.s12,
        AppSpace.s8,
      ),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _CardAuthor(
            post: post,
            onDeletePost: onDeletePost,
            onReportPost: onReportPost,
          ),
          const SizedBox(height: AppSpace.s8),
          Text(
            post.text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppText.body14,
          ),
          const SizedBox(height: AppSpace.s4),
          Text(post.timeLabel, style: AppText.caption12),
          const SizedBox(height: AppSpace.s12),
          _CardImage(post: post),
          const SizedBox(height: AppSpace.s8),
          CircleActionRow(
            post: post,
            onLike: onLike,
            onComment: onComment,
            onFavorite: onFavorite,
          ),
        ],
      ),
    );
  }
}

class _CardAuthor extends StatelessWidget {
  const _CardAuthor({required this.post, this.onDeletePost, this.onReportPost});

  final CirclePost post;
  final VoidCallback? onDeletePost;
  final VoidCallback? onReportPost;

  @override
  Widget build(BuildContext context) {
    final role = formatCircleAuthorRole(post.author.role);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AppAvatar(name: post.author.name, url: post.author.avatarUrl),
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: AppSpace.s8,
                runSpacing: AppSpace.s4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    post.author.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body14Strong,
                  ),
                  for (final badge in post.badges)
                    CircleBadgeChip(badge: badge),
                ],
              ),
              if (role.isNotEmpty)
                Text(
                  role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption12,
                ),
            ],
          ),
        ),
        CirclePostMenuButton(onDelete: onDeletePost, onReport: onReportPost),
      ],
    );
  }
}

class _CardImage extends StatefulWidget {
  const _CardImage({required this.post});

  final CirclePost post;

  @override
  State<_CardImage> createState() => _CardImageState();
}

class _CardImageState extends State<_CardImage> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  double? _detectedAspectRatio;

  CirclePost get post => widget.post;

  @override
  void initState() {
    super.initState();
    _resolveMediaAspectRatio();
  }

  @override
  void didUpdateWidget(covariant _CardImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.imageUrl != widget.post.imageUrl ||
        oldWidget.post.mediaKind != widget.post.mediaKind) {
      _detectedAspectRatio = null;
      _resolveMediaAspectRatio();
    }
  }

  @override
  void dispose() {
    _clearImageStreamListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.br12,
      child: AspectRatio(
        aspectRatio: _effectiveAspectRatio,
        child: switch (post.mediaKind) {
          PostMediaKind.image => AppImage(src: post.imageUrl),
          PostMediaKind.video => _VideoCover(post: post),
          PostMediaKind.audio => _AudioCover(post: post),
        },
      ),
    );
  }

  double get _effectiveAspectRatio =>
      _detectedAspectRatio ?? _safeAspectRatio(post.imageAspectRatio);

  double _safeAspectRatio(double value) {
    if (value <= 0 || value.isNaN || value.isInfinite) return 3 / 4;
    return value.clamp(0.35, 2.4);
  }

  void _resolveMediaAspectRatio() {
    _clearImageStreamListener();
    final url = post.imageUrl;
    if (url.isEmpty) return;

    final provider = NetworkImage(url);
    final stream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      final width = info.image.width;
      final height = info.image.height;
      if (height <= 0 || width <= 0 || !mounted) return;
      final aspect = _safeAspectRatio(width / height);
      if ((_detectedAspectRatio ?? 0) == aspect) return;
      setState(() => _detectedAspectRatio = aspect);
    }, onError: (_, _) {});
    _imageStream = stream;
    _imageStreamListener = listener;
    stream.addListener(listener);
  }

  void _clearImageStreamListener() {
    final stream = _imageStream;
    final listener = _imageStreamListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _imageStream = null;
    _imageStreamListener = null;
  }
}

/// 视频帖封面：海报（没有时用墨色底）+ 中央播放按钮 + 左下「视频」标记。
class _VideoCover extends StatelessWidget {
  const _VideoCover({required this.post});

  final CirclePost post;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (post.imageUrl.isNotEmpty)
          AppImage(
            src: post.imageUrl,
            error: const ColoredBox(color: AppColors.ink),
          )
        else
          const ColoredBox(color: AppColors.ink),
        const Center(child: CircleVideoPlayButton()),
        const Positioned(
          left: AppSpace.s8,
          bottom: AppSpace.s8,
          child: _MediaTypeChip(icon: Icons.videocam_outlined, label: '视频'),
        ),
      ],
    );
  }
}

/// 音频帖封面：封面图（没有时用浅紫底 + 音频图标）+ 中央播放按钮 + 左下「音频」标记。
class _AudioCover extends StatelessWidget {
  const _AudioCover({required this.post});

  final CirclePost post;

  @override
  Widget build(BuildContext context) {
    const fallback = ColoredBox(
      color: AppColors.brandTint,
      child: Center(
        child: Icon(
          Icons.headphones_outlined,
          size: 48,
          color: AppColors.brandDeep,
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        if (post.imageUrl.isNotEmpty)
          AppImage(src: post.imageUrl, error: fallback)
        else
          fallback,
        const Center(child: CircleVideoPlayButton()),
        const Positioned(
          left: AppSpace.s8,
          bottom: AppSpace.s8,
          child: _MediaTypeChip(icon: Icons.headphones_outlined, label: '音频'),
        ),
      ],
    );
  }
}

class _MediaTypeChip extends StatelessWidget {
  const _MediaTypeChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSize.tag,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.6),
        borderRadius: AppRadius.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.onBrand),
          const SizedBox(width: AppSpace.s4),
          Text(
            label,
            style: AppText.caption12.copyWith(color: AppColors.onBrand),
          ),
        ],
      ),
    );
  }
}
