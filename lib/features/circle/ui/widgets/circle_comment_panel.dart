import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../state/circle_state.dart';

/// 大图模式下从右侧滑入的评论面板：标题、可滚动评论列表、底部输入条。
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
    final post = widget.post;
    final Widget body;
    if (post == null) {
      body = const SizedBox.shrink();
    } else if (widget.commentsLoading) {
      body = const Center(child: AppLoadingIndicator());
    } else if (post.comments.isEmpty) {
      body = const AppEmptyState(
        icon: Icons.mode_comment_outlined,
        title: '还没有评论',
        description: '写下你的看法，作者会收到提醒',
      );
    } else {
      body = _CommentList(
        post: post,
        permissions: widget.permissions,
        comments: post.comments,
        onLike: widget.onCommentLikeTap,
        onDeleteComment: widget.onDeleteComment,
      );
    }
    return Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          _PanelHeader(count: post?.commentCount ?? 0, onClose: widget.onClose),
          const Divider(height: 1, thickness: 1, color: AppColors.lineSoft),
          Expanded(child: body),
          const Divider(height: 1, thickness: 1, color: AppColors.lineSoft),
          _InputBar(
            controller: _input,
            focusNode: _focus,
            onSend: _handleSubmit,
          ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s8,
        AppSpace.s8,
        AppSpace.s8,
      ),
      child: Row(
        children: [
          Text('评论', style: AppText.title16),
          const SizedBox(width: AppSpace.s8),
          Text(
            formatCircleCount(count),
            style: AppText.number(size: 14, color: AppColors.textTertiary),
          ),
          const Spacer(),
          AppIconButton(
            icon: Icons.close_rounded,
            semanticLabel: '关闭评论',
            size: AppButtonSize.sm,
            filled: false,
            color: AppColors.textSecondary,
            onTap: onClose,
          ),
        ],
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
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s16,
        AppSpace.s16,
        AppSpace.s20,
      ),
      itemCount: comments.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s20),
      itemBuilder: (context, index) {
        final c = comments[index];
        final canDelete =
            onDeleteComment != null && permissions.canDeleteComment(post, c);
        return _CommentTile(
          comment: c,
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
    this.onDelete,
  });

  final CircleComment comment;
  final VoidCallback onLike;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final role = formatCircleAuthorRole(comment.author.role);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppAvatar(name: comment.author.name, url: comment.author.avatarUrl),
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: comment.author.name,
                      style: AppText.body14Strong,
                    ),
                    if (role.isNotEmpty)
                      TextSpan(text: '  $role', style: AppText.caption12),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpace.s4),
              Text(comment.text, style: AppText.body14),
              const SizedBox(height: AppSpace.s4),
              Row(
                children: [
                  if (comment.timeLabel.isNotEmpty)
                    Text(comment.timeLabel, style: AppText.caption12),
                  if (onDelete != null) ...[
                    const SizedBox(width: AppSpace.s12),
                    AppPressable(
                      onTap: onDelete,
                      semanticLabel: '删除评论',
                      child: Text('删除', style: AppText.caption12),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpace.s8),
        AppPressable(
          onTap: onLike,
          semanticLabel: comment.liked ? '取消点赞' : '点赞',
          selected: comment.liked,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                comment.liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 20,
                color: comment.liked
                    ? AppColors.brand
                    : AppColors.textTertiary,
              ),
              const SizedBox(height: 2),
              Text(
                formatCircleCount(comment.likeCount),
                style: AppText.number(
                  size: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.all(AppSpace.s12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: AppSize.buttonSm,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
              decoration: const BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: AppRadius.br8,
              ),
              alignment: Alignment.centerLeft,
              child: AppTextField(
                controller: controller,
                focusNode: focusNode,
                onSubmitted: (_) => onSend(),
                textInputAction: TextInputAction.send,
                cursorColor: AppColors.brand,
                style: AppText.body14,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: '写下你的评论',
                  hintStyle: AppText.body14.copyWith(
                    color: AppColors.textPlaceholder,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => AppButton(
              label: '发送',
              size: AppButtonSize.sm,
              onTap: value.text.trim().isEmpty ? null : onSend,
            ),
          ),
        ],
      ),
    );
  }
}
