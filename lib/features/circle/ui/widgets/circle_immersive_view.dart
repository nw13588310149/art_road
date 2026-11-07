import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/ui/ui.dart';
import '../../../shell/ui/shell_layout.dart';
import '../../state/circle_controller.dart';
import '../../state/circle_state.dart';
import 'circle_action_buttons.dart';
import 'circle_badges.dart';
import 'circle_comment_panel.dart';
import 'circle_media_player.dart';
import 'circle_post_actions.dart';
import 'circle_post_menu.dart';

/// 沉浸模式：全屏单帖，纵向 PageView 翻页，右侧操作按钮，下方文字浮层；
/// 评论面板从右侧滑入，覆盖在沉浸面板之上。
class CircleImmersiveView extends StatefulWidget {
  const CircleImmersiveView({
    super.key,
    required this.state,
    required this.controller,
    required this.permissions,
    required this.menuActions,
    required this.mediaStopEpoch,
  });

  final CircleState state;
  final CircleController controller;
  final CirclePermissions permissions;
  final CirclePostMenuActions menuActions;
  final int mediaStopEpoch;

  @override
  State<CircleImmersiveView> createState() => _CircleImmersiveViewState();
}

class _CircleImmersiveViewState extends State<CircleImmersiveView> {
  late final PageController _pageController = PageController(
    initialPage: widget.state.immersiveIndex,
  );

  @override
  void didUpdateWidget(covariant CircleImmersiveView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.state.immersiveIndex;
    if (_pageController.hasClients && _pageController.page?.round() != target) {
      _pageController.jumpToPage(target);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String? _activePostId() {
    final s = widget.state;
    if (s.commentTargetPostId.isNotEmpty) return s.commentTargetPostId;
    return s.currentImmersivePost?.id;
  }

  Future<void> _togglePostLike(BuildContext context, String postId) async {
    final message = await widget.controller.toggleLike(postId);
    if (!context.mounted || message == null || message.isEmpty) return;
    AppToast.show(context, message);
  }

  Future<void> _submitComment(
    BuildContext context,
    String postId,
    String text,
  ) async {
    final message = await widget.controller.addComment(postId, text);
    if (!context.mounted || message == null || message.isEmpty) return;
    AppToast.show(context, message);
  }

  Future<void> _toggleCommentLike(
    BuildContext context,
    String postId,
    String commentId,
  ) async {
    final message =
        await widget.controller.toggleCommentLike(postId, commentId);
    if (!context.mounted || message == null || message.isEmpty) return;
    AppToast.show(context, message);
  }

  Future<void> _confirmDeleteComment(
    BuildContext context,
    String commentId,
  ) async {
    final ok = await showAppConfirm(
      context: context,
      title: '删除评论',
      message: '删除后不可恢复。',
      danger: true,
    );
    if (!ok || !context.mounted) return;
    final postId = _activePostId();
    if (postId == null) return;
    final message = await widget.controller.deleteComment(
      postId: postId,
      commentId: commentId,
    );
    if (!context.mounted) return;
    if (message != null && message.isNotEmpty) {
      AppToast.show(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final state = widget.state;
    final controller = widget.controller;
    final posts = state.visiblePosts;

    if (posts.isEmpty) {
      return ColoredBox(
        color: AppColors.surface,
        child: state.listLoading
            ? const Center(child: AppLoadingIndicator())
            : AppEmptyState(
                icon: Icons.forum_outlined,
                title: '还没有动态',
                description: widget.menuActions.governance
                    ? '同学和老师发布的动态会出现在这里'
                    : '分享一张作品或写生日记，同学和老师都能看到',
              ),
      );
    }

    final commentsLoading = state.commentsLoadingPostId != null &&
        state.commentsLoadingPostId == _activePostId();

    return ColoredBox(
      color: AppColors.ink,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            physics: const ClampingScrollPhysics(),
            itemCount: posts.length,
            onPageChanged: controller.setImmersiveIndex,
            itemBuilder: (context, index) {
              final post = posts[index];
              return _ImmersiveSlide(
                post: post,
                isActive: index == state.immersiveIndex,
                mediaStopEpoch: widget.mediaStopEpoch,
                onDeletePost: widget.menuActions.deleteFor(context, post),
                onReportPost: widget.menuActions.reportFor(context, post),
                onLike: () => unawaited(_togglePostLike(context, post.id)),
                onComment: () => unawaited(controller.openCommentPanel(post.id)),
                onFavorite: () => controller.toggleFavorite(post.id),
              );
            },
          ),

          _AnimatedCommentScrim(
            visible: state.commentPanelOpen,
            panelWidth: ui(420),
            onTap: controller.closeCommentPanel,
          ),

          _AnimatedCommentPanel(
            visible: state.commentPanelOpen,
            child: CircleCommentPanel(
              post: state.commentTargetPost ?? state.currentImmersivePost,
              permissions: widget.permissions,
              commentsLoading: commentsLoading,
              onClose: controller.closeCommentPanel,
              onSubmit: (text) {
                final id = _activePostId();
                if (id != null) {
                  unawaited(_submitComment(context, id, text));
                }
              },
              onCommentLikeTap: (commentId) {
                final id = _activePostId();
                if (id != null) {
                  unawaited(_toggleCommentLike(context, id, commentId));
                }
              },
              onDeleteComment: (commentId) =>
                  unawaited(_confirmDeleteComment(context, commentId)),
            ),
          ),

        ],
      ),
    );
  }
}

/// 单帖：背景图 + 底部渐变 + 文本 + 右侧操作。
class _ImmersiveSlide extends StatelessWidget {
  const _ImmersiveSlide({
    required this.post,
    required this.isActive,
    required this.mediaStopEpoch,
    required this.onLike,
    required this.onComment,
    required this.onFavorite,
    this.onDeletePost,
    this.onReportPost,
  });

  final CirclePost post;
  final bool isActive;
  final int mediaStopEpoch;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onFavorite;
  final VoidCallback? onDeletePost;
  final VoidCallback? onReportPost;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final isDouyinLayout =
        post.mediaKind == PostMediaKind.video ||
        post.mediaKind == PostMediaKind.audio;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: CircleMediaPlayer(
            post: post,
            isActive: isActive,
            mediaStopEpoch: mediaStopEpoch,
          ),
        ),

        if (onDeletePost != null || onReportPost != null)
          Positioned(
            top: AppSpace.s16,
            right: AppSpace.s16,
            child: CirclePostMenuButton(
              onDelete: onDeletePost,
              onReport: onReportPost,
              onDark: true,
            ),
          ),

        // 视频 / 音频帖：抖音式轻渐变；图片保留原渐变。
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: isDouyinLayout ? ui(180) : ui(220),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDouyinLayout
                    ? [
                        AppColors.ink.withValues(alpha: 0),
                        AppColors.ink.withValues(alpha: 0.4),
                        AppColors.ink.withValues(alpha: 0.6),
                      ]
                    : [
                        AppColors.ink.withValues(alpha: 0),
                        AppColors.ink.withValues(alpha: 0.8),
                        AppColors.ink,
                      ],
                stops: isDouyinLayout ? const [0, 0.55, 1] : const [0, 0.6, 1],
              ),
            ),
          ),
        ),

        // 左下：作者 + 文案；距左 32、距底 29.5。
        Positioned(
          left: ui(32),
          right: ui(isDouyinLayout ? 88 : 160),
          bottom: ui(29.5),
          child: isDouyinLayout
              ? _DouyinVideoTextBlock(post: post)
              : _ImmersiveTextBlock(post: post),
        ),

        // 右下：头像 + 点赞 / 评论 / 收藏；最底部元素距容器底 32。
        Positioned(
          right: ui(35),
          bottom: ui(32),
          child: _ImmersiveActions(
            post: post,
            onLike: onLike,
            onComment: onComment,
            onFavorite: onFavorite,
            compact: isDouyinLayout,
          ),
        ),
      ],
    );
  }
}

/// 沉浸模式左下：昵称 + 身份同一行、中线对齐；身份与列表模式一致走中文映射。
class _ImmersiveAuthorLine extends StatelessWidget {
  const _ImmersiveAuthorLine({
    required this.post,
    this.nameShadows,
  });

  final CirclePost post;
  final List<Shadow>? nameShadows;

  @override
  Widget build(BuildContext context) {
    final role = formatCircleAuthorRole(post.author.role);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            '@${post.author.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.title20.copyWith(
              color: AppColors.onBrand,
              shadows: nameShadows,
            ),
          ),
        ),
        if (role.isNotEmpty) ...[
          const SizedBox(width: AppSpace.s8),
          Text(
            role,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body14.copyWith(color: AppColors.textPlaceholder),
          ),
        ],
      ],
    );
  }
}

/// 沉浸左下正文：默认最多露出两行高度，超出可在该区域内纵向滚动查看。
class _ImmersiveScrollableBodyText extends StatelessWidget {
  const _ImmersiveScrollableBodyText({
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  static const _maxLines = 2;

  @override
  Widget build(BuildContext context) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    final fontSize = style.fontSize ?? 14;
    final heightFactor = style.height ?? 1.0;
    final maxHeight = fontSize * heightFactor * _maxLines;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Text(text, style: style),
        ),
      ),
    );
  }
}

/// 抖音风左下信息区：@昵称 + 身份 → 正文 → 时间，纵向排列。
class _DouyinVideoTextBlock extends StatelessWidget {
  const _DouyinVideoTextBlock({required this.post});

  final CirclePost post;

  static final _textShadow = <Shadow>[
    Shadow(color: AppColors.ink.withValues(alpha: 0.5), blurRadius: 4),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ImmersiveAuthorLine(post: post, nameShadows: _textShadow),
        if (post.text.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpace.s8),
          _ImmersiveScrollableBodyText(
            text: post.text,
            style: AppText.body14.copyWith(
              color: AppColors.onBrand,
              shadows: _textShadow,
            ),
          ),
        ],
        if (post.badges.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s8),
          CircleBadgeRow(badges: post.badges),
        ],
        const SizedBox(height: AppSpace.s8),
        Text(
          post.timeLabel,
          style: AppText.body13.copyWith(color: AppColors.textPlaceholder),
        ),
      ],
    );
  }
}

class _ImmersiveTextBlock extends StatelessWidget {
  const _ImmersiveTextBlock({required this.post});

  final CirclePost post;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ImmersiveAuthorLine(post: post),
        if (post.badges.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s8),
          CircleBadgeRow(badges: post.badges),
        ],
        const SizedBox(height: AppSpace.s12),
        _ImmersiveScrollableBodyText(
          text: post.text,
          style: AppText.body14.copyWith(color: AppColors.onBrand),
        ),
        const SizedBox(height: AppSpace.s8),
        Text(
          post.timeLabel,
          style: AppText.body13.copyWith(color: AppColors.textPlaceholder),
        ),
      ],
    );
  }
}

class _ImmersiveActions extends StatelessWidget {
  const _ImmersiveActions({
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onFavorite,
    this.compact = false,
  });

  final CirclePost post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onFavorite;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final avatarSize = compact ? ui(48) : ui(44);
    final gapAfterAvatar = ui(24);
    final gapBetween = compact ? ui(14) : ui(16);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ImmersiveAvatar(
          name: post.author.name,
          url: post.author.avatarUrl,
          size: avatarSize,
        ),
        SizedBox(height: gapAfterAvatar),
        CircleActionButton(
          iconAsset: post.liked
              ? AppAssets.circleLiked
              : AppAssets.circleLikeOnImage,
          label: post.liked ? '取消点赞' : '点赞',
          active: post.liked,
          count: post.likeCount,
          onTap: onLike,
          dark: true,
        ),
        SizedBox(height: gapBetween),
        CircleActionButton(
          iconAsset: AppAssets.circleCommentOnImage,
          label: '评论',
          count: post.commentCount,
          onTap: onComment,
          dark: true,
        ),
        SizedBox(height: gapBetween),
        CircleActionButton(
          iconAsset: post.favorited
              ? AppAssets.circleSaved
              : AppAssets.circleSaveOnImage,
          label: post.favorited ? '取消收藏' : '收藏',
          active: post.favorited,
          count: post.favoriteCount,
          onTap: onFavorite,
          dark: true,
        ),
      ],
    );
  }
}

class _ImmersiveAvatar extends StatelessWidget {
  const _ImmersiveAvatar({
    required this.name,
    required this.url,
    required this.size,
  });

  final String name;
  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    // 外圈白底 2px，深色画面上头像轮廓清楚。
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: AppAvatar(name: name, url: url, size: size - 4),
    );
  }
}

/// 评论区打开时，左侧背景遮罩做淡入淡出过渡。
class _AnimatedCommentScrim extends StatelessWidget {
  const _AnimatedCommentScrim({
    required this.visible,
    required this.panelWidth,
    required this.onTap,
  });

  final bool visible;
  final double panelWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      bottom: 0,
      right: panelWidth,
      child: IgnorePointer(
        ignoring: !visible,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedOpacity(
            duration: AppMotion.overlay,
            curve: AppMotion.overlayCurve,
            opacity: visible ? 1 : 0,
            child: const ColoredBox(color: AppColors.scrim),
          ),
        ),
      ),
    );
  }
}

/// 用 AnimatedPositioned 包装的右侧滑入面板。
class _AnimatedCommentPanel extends StatelessWidget {
  const _AnimatedCommentPanel({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final radius = ui(16);
    // 外扩 2px，由外层 [CirclePage] ClipRRect 裁切，避免圆角 anti-alias 缝。
    const bleed = 2.0;
    return AnimatedPositioned(
      duration: AppMotion.overlay,
      curve: AppMotion.overlayCurve,
      top: -ui(bleed),
      bottom: -ui(bleed),
      right: visible ? -ui(bleed) : -ui(440),
      width: ui(420 + bleed * 2),
      child: AnimatedOpacity(
        duration: AppMotion.overlay,
        opacity: visible ? 1 : 0,
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(radius),
            bottomRight: Radius.circular(radius),
          ),
          clipBehavior: Clip.hardEdge,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(radius),
                bottomRight: Radius.circular(radius),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
