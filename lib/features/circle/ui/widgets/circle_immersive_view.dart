import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/scaled_dialog.dart';
import '../../../shell/ui/shell_layout.dart';
import '../../state/circle_controller.dart';
import '../../state/circle_state.dart';
import 'circle_action_buttons.dart';
import 'circle_badges.dart';
import 'circle_comment_panel.dart';
import 'circle_media_player.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

/// 沉浸模式：全屏单帖，纵向 PageView 翻页，右侧操作按钮，下方文字浮层；
/// 评论面板从右侧滑入，覆盖在沉浸面板之上。
class CircleImmersiveView extends StatefulWidget {
  const CircleImmersiveView({
    super.key,
    required this.state,
    required this.controller,
    required this.permissions,
    required this.mediaStopEpoch,
  });

  final CircleState state;
  final CircleController controller;
  final CirclePermissions permissions;
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
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
      );
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

  Future<void> _confirmDeletePost(BuildContext context, CirclePost post) async {
    final ok = await showConfirmDialog(
      context: context,
      title: '删除帖子',
      content: '确定删除这条动态吗？删除后不可恢复。',
    );
    if (!ok || !context.mounted) return;
    final message = await widget.controller.deletePost(post.id);
    if (!context.mounted) return;
    if (message != null && message.isNotEmpty) {
      AppToast.show(context, message);
    }
  }

  Future<void> _confirmDeleteComment(
    BuildContext context,
    String commentId,
  ) async {
    final ok = await showConfirmDialog(
      context: context,
      title: '删除评论',
      content: '确定删除这条评论吗？',
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
      return const ColoredBox(
        color: Color(0xFF0B081A),
        child: Center(
          child: Text(
            '暂无动态',
            style: TextStyle(
              color: Color(0xFFB6B5BB),
              fontSize: 14,
              fontFamily: 'PingFang SC',
            ),
          ),
        ),
      );
    }

    final commentsLoading = state.commentsLoadingPostId != null &&
        state.commentsLoadingPostId == _activePostId();

    return ColoredBox(
      color: const Color(0xFF0B081A),
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
                canDeletePost: widget.permissions.canDeletePost(post),
                onDeletePost: widget.permissions.canDeletePost(post)
                    ? () => _confirmDeletePost(context, post)
                    : null,
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
    required this.canDeletePost,
    this.onDeletePost,
  });

  final CirclePost post;
  final bool isActive;
  final int mediaStopEpoch;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onFavorite;
  final bool canDeletePost;
  final VoidCallback? onDeletePost;

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

        if (canDeletePost && onDeletePost != null)
          Positioned(
            top: ui(16),
            right: ui(16),
            child: GestureDetector(
              onTap: onDeletePost,
              behavior: HitTestBehavior.opaque,
              child: Image.asset(
                AppAssets.homeDel,
                width: ui(32),
                height: ui(32),
                fit: BoxFit.contain,
              ),
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
                    ? const [
                        Color(0x00000000),
                        Color(0x66000000),
                        Color(0x99000000),
                      ]
                    : const [
                        Color(0x000B081A),
                        Color(0xCC0B081A),
                        Color(0xFF0B081A),
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
    final ui = DashboardScaleScope.of(context).ui;
    final role = formatCircleAuthorRole(post.author.role);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            '@${post.author.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: ui(20),
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w600,
              height: 1,
              shadows: nameShadows,
            ),
          ),
        ),
        if (role.isNotEmpty) ...[
          SizedBox(width: ui(8)),
          Text(
            role,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFFB6B5BB),
              fontSize: ui(14),
              fontFamily: 'PingFang SC',
              height: 1,
            ),
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

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ImmersiveAuthorLine(
          post: post,
          nameShadows: const [
            Shadow(color: Color(0x80000000), blurRadius: 4),
          ],
        ),
        if (post.text.trim().isNotEmpty) ...[
          SizedBox(height: ui(8)),
          _ImmersiveScrollableBodyText(
            text: post.text,
            style: TextStyle(
              color: Colors.white,
              fontSize: ui(14),
              fontFamily: 'PingFang SC',
              height: 1.35,
              shadows: const [
                Shadow(color: Color(0x80000000), blurRadius: 4),
              ],
            ),
          ),
        ],
        if (post.badges.isNotEmpty) ...[
          SizedBox(height: ui(6)),
          CircleBadgeRow(badges: post.badges),
        ],
        SizedBox(height: ui(6)),
        Text(
          post.timeLabel,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: ui(14),
            fontFamily: 'PingFang SC',
          ),
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
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ImmersiveAuthorLine(post: post),
        if (post.badges.isNotEmpty) ...[
          SizedBox(height: ui(6)),
          CircleBadgeRow(badges: post.badges),
        ],
        SizedBox(height: ui(12)),
        _ImmersiveScrollableBodyText(
          text: post.text,
          style: TextStyle(
            color: Colors.white,
            fontSize: ui(14),
            fontFamily: 'PingFang SC',
            height: 24 / 14,
          ),
        ),
        SizedBox(height: ui(6)),
        Text(
          post.timeLabel,
          style: TextStyle(
            color: const Color(0xFFB6B5BB),
            fontSize: ui(14),
            fontFamily: 'PingFang SC',
          ),
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
        _ImmersiveAvatar(url: post.author.avatarUrl, size: avatarSize),
        SizedBox(height: gapAfterAvatar),
        CircleActionButton(
          iconAsset: post.liked ? AppAssets.circleFav1 : AppAssets.circleFav,
          count: post.likeCount,
          onTap: onLike,
          dark: true,
          iconSize: compact ? ui(28) : null,
        ),
        SizedBox(height: gapBetween),
        CircleActionButton(
          iconAsset: AppAssets.circleMsg,
          count: post.commentCount,
          onTap: onComment,
          dark: true,
          iconSize: compact ? ui(28) : null,
        ),
        SizedBox(height: gapBetween),
        CircleActionButton(
          iconAsset: post.favorited ? AppAssets.circleSc1 : AppAssets.circleSc,
          count: post.favoriteCount,
          onTap: onFavorite,
          dark: true,
          iconSize: compact ? ui(28) : null,
        ),
      ],
    );
  }
}

class _ImmersiveAvatar extends StatelessWidget {
  const _ImmersiveAvatar({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 与 shell 顶栏头像一致：外圈白底，内圈图片缩小 ui(4) 形成白边。
    final innerSize = size - ui(4);
    final fallback = Container(
      width: innerSize,
      height: innerSize,
      color: const Color(0xFF252035),
      alignment: Alignment.center,
      child: Icon(
        Icons.person,
        color: Colors.white.withValues(alpha: 0.6),
        size: innerSize * 0.55,
      ),
    );
    final avatarWidget = url.isNotEmpty
        ? Image.network(
            url,
            width: innerSize,
            height: innerSize,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => fallback,
          )
        : fallback;

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: ClipOval(
        child: SizedBox(width: innerSize, height: innerSize, child: avatarWidget),
      ),
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
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            opacity: visible ? 1 : 0,
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.38),
            ),
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
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      top: -ui(bleed),
      bottom: -ui(bleed),
      right: visible ? -ui(bleed) : -ui(440),
      width: ui(420 + bleed * 2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: visible ? 1 : 0,
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(radius),
            bottomRight: Radius.circular(radius),
          ),
          clipBehavior: Clip.hardEdge,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
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
