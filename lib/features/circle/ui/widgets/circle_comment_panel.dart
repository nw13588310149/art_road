import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_text_field.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/app_asset_graphic.dart';
import '../../../shell/ui/shell_layout.dart';
import '../../state/circle_state.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

/// 沉浸模式下从右侧滑入的评论面板（抖音风）。
/// 顶部标题、可滚动评论列表、底部输入框三段式布局。
class CircleCommentPanel extends StatefulWidget {
  const CircleCommentPanel({
    super.key,
    required this.post,
    required this.onClose,
    required this.onSubmit,
    required this.onCommentLikeTap,
    required this.permissions,
    this.commentsLoading = false,
    this.onDeleteComment,
  });

  final CirclePost? post;
  final VoidCallback onClose;
  final ValueChanged<String> onSubmit;
  final ValueChanged<String> onCommentLikeTap;
  final CirclePermissions permissions;

  /// 正在为当前帖拉取评论列表时为 true。
  final bool commentsLoading;

  /// 删除评论（commentId）；由外层做二次确认与接口调用。
  final ValueChanged<String>? onDeleteComment;

  @override
  State<CircleCommentPanel> createState() => _CircleCommentPanelState();
}

class _CircleCommentPanelState extends State<CircleCommentPanel> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final post = widget.post;
    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          _PanelHeader(count: post?.commentCount ?? 0, onClose: widget.onClose),
          Container(height: 1, color: const Color(0xFFF3F2F3)),
          Expanded(
            child: post == null
                ? const SizedBox.shrink()
                : Stack(
                    children: [
                      if (widget.commentsLoading)
                        const Center(
                          child: AppLoadingIndicator(),
                        ),
                      if (!widget.commentsLoading)
                        (post.comments.isEmpty
                            ? const _CommentEmpty()
                            : _CommentList(
                                post: post,
                                permissions: widget.permissions,
                                comments: post.comments,
                                onLike: widget.onCommentLikeTap,
                                onDeleteComment: widget.onDeleteComment,
                              )),
                    ],
                  ),
          ),
          Container(height: 1, color: const Color(0xFFF3F2F3)),
          _InputBar(
            controller: _input,
            focusNode: _focus,
            onSend: _handleSubmit,
          ),
          SizedBox(height: ui(8)),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.count, required this.onClose});

  final int count;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: ui(52),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        child: Row(
          children: [
            Text(
              '评论',
              style: TextStyle(
                color: const Color(0xFF0B081A),
                fontSize: ui(16),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w600,
              ),
            ),
            SizedBox(width: ui(8)),
            Text(
              formatCircleCount(count),
              style: TextStyle(
                color: const Color(0xFFB6B5BB),
                fontSize: ui(14),
                fontFamily: 'PingFang SC',
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onClose,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: ui(28),
                height: ui(28),
                alignment: Alignment.center,
                child: Icon(
                  Icons.close_rounded,
                  size: ui(18),
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentList extends StatelessWidget {
  const _CommentList({
    required this.post,
    required this.permissions,
    required this.comments,
    required this.onLike,
    required this.onDeleteComment,
  });

  final CirclePost post;
  final CirclePermissions permissions;
  final List<CircleComment> comments;
  final ValueChanged<String> onLike;
  final ValueChanged<String>? onDeleteComment;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(ui(16), ui(16), ui(16), ui(20)),
      itemCount: comments.length,
      separatorBuilder: (_, _) => SizedBox(height: ui(20)),
      itemBuilder: (context, index) {
        final c = comments[index];
        final canDelete = onDeleteComment != null &&
            permissions.canDeleteComment(post, c);
        return _CommentTile(
          comment: c,
          showDelete: canDelete,
          onLike: () => onLike(c.id),
          onDelete: canDelete ? () => onDeleteComment!(c.id) : null,
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.onLike,
    required this.showDelete,
    this.onDelete,
  });

  final CircleComment comment;
  final VoidCallback onLike;
  final bool showDelete;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentAvatar(url: comment.author.avatarUrl, size: ui(44)),
        SizedBox(width: ui(11)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                comment.author.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF0B081A),
                  fontSize: ui(16),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w600,
                ),
              ),
              Transform.translate(
                offset: Offset(0, -ui(2)),
                child: Text(
                  formatCircleAuthorRole(comment.author.role),
                  style: TextStyle(
                    color: const Color(0xFFB6B5BB),
                    fontSize: ui(13),
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ),
              SizedBox(height: ui(8)),
              Text(
                comment.text,
                style: TextStyle(
                  color: const Color(0xFF000000),
                  fontSize: ui(14),
                  fontFamily: 'PingFang SC',
                  height: 19.6 / 14,
                ),
              ),
              SizedBox(height: ui(6)),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: ui(12),
                runSpacing: ui(4),
                children: [
                  if (comment.timeLabel.isNotEmpty)
                    Text(
                      comment.timeLabel,
                      style: TextStyle(
                        color: const Color(0xFFB6B5BB),
                        fontSize: ui(12),
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                  Text(
                    '回复',
                    style: TextStyle(
                      color: const Color(0xFFB6B5BB),
                      fontSize: ui(12),
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                  if (showDelete && onDelete != null)
                    GestureDetector(
                      onTap: onDelete,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        '删除',
                        style: TextStyle(
                          color: const Color(0xFFB6B5BB),
                          fontSize: ui(12),
                          fontFamily: 'PingFang SC',
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(width: ui(8)),
        _CommentLike(comment: comment, onTap: onLike),
      ],
    );
  }
}

class _CommentAvatar extends StatelessWidget {
  const _CommentAvatar({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? Container(
                color: const Color(0xFFEAE5FF),
                alignment: Alignment.center,
                child: Icon(
                  Icons.person,
                  color: const Color(0xFF8741FF),
                  size: size * 0.55,
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  color: const Color(0xFFEAE5FF),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.person,
                    color: const Color(0xFF8741FF),
                    size: size * 0.55,
                  ),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(color: const Color(0xFFF3F4F8));
                },
              ),
      ),
    );
  }
}

class _CommentLike extends StatelessWidget {
  const _CommentLike({required this.comment, required this.onTap});

  final CircleComment comment;
  final VoidCallback onTap;

  static const _activeCanvasExtent = 94.0;
  static const _inactiveCanvasExtent = 80.0;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final iconAsset =
        comment.liked ? AppAssets.circleFav1 : AppAssets.circleFav2;
    final baseSize = ui(20);
    final iconBoxSize = baseSize * _activeCanvasExtent / _inactiveCanvasExtent;
    final visualSize =
        iconAsset == AppAssets.circleFav2 ? iconBoxSize : baseSize;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: iconBoxSize,
            height: iconBoxSize,
            child: Center(
              child: AppAssetGraphic(
                iconAsset,
                width: visualSize,
                height: visualSize,
              ),
            ),
          ),
          SizedBox(height: ui(2)),
          Text(
            formatCircleCount(comment.likeCount),
            style: TextStyle(
              color: const Color(0xFF0B081A),
              fontSize: ui(12),
              fontFamily: 'PingFang SC',
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentEmpty extends StatelessWidget {
  const _CommentEmpty();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.mode_comment_outlined,
            size: ui(40),
            color: const Color(0xFFB6B5BB),
          ),
          SizedBox(height: ui(10)),
          Text(
            '抢沙发吧～',
            style: TextStyle(
              color: const Color(0xFFB6B5BB),
              fontSize: ui(14),
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(16), ui(10), ui(16), ui(10)),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: ui(40),
              padding: EdgeInsets.symmetric(horizontal: ui(14)),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F8),
                borderRadius: BorderRadius.circular(ui(20)),
              ),
              alignment: Alignment.centerLeft,
              child: AppTextField(
                controller: controller,
                focusNode: focusNode,
                onSubmitted: (_) => onSend(),
                textInputAction: TextInputAction.send,
                cursorColor: const Color(0xFF8741FF),
                cursorWidth: 1.5,
                cursorHeight: ui(16),
                style: TextStyle(
                  color: const Color(0xFF0B081A),
                  fontSize: ui(14),
                  fontFamily: 'PingFang SC',
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: '说点什么…',
                  hintStyle: TextStyle(
                    color: const Color(0xFFB6B5BB),
                    fontSize: ui(14),
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: ui(10)),
          GestureDetector(
            onTap: onSend,
            child: Container(
              height: ui(40),
              padding: EdgeInsets.symmetric(horizontal: ui(20)),
              decoration: BoxDecoration(
                color: const Color(0xFF8741FF),
                borderRadius: BorderRadius.circular(ui(20)),
              ),
              alignment: Alignment.center,
              child: Text(
                '发送',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ui(14),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
