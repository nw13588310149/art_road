import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../state/circle_controller.dart';
import '../../state/circle_state.dart';
import 'circle_post_actions.dart';
import 'circle_post_card.dart';

/// 卡片模式：瀑布流。按列累计估算高度，把每张卡片放到当前最矮的那一列。
class CircleListView extends StatelessWidget {
  const CircleListView({
    super.key,
    required this.state,
    required this.controller,
    required this.menuActions,
    this.onPublish,
  });

  final CircleState state;
  final CircleController controller;
  final CirclePostMenuActions menuActions;

  /// 为空时（校圈治理）空状态不引导发布。
  final VoidCallback? onPublish;

  static const _gap = AppSpace.s16;

  static int _columnCount(double width) {
    if (width < 520) return 1;
    if (width < 900) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final posts = state.visiblePosts;

    if (state.listLoading && posts.isEmpty) {
      return const _CircleListSkeleton();
    }

    if (posts.isEmpty) {
      final searching = state.searchKeyword.trim().isNotEmpty;
      final canPublish = onPublish != null;
      return AppRefreshIndicator(
        onRefresh: () => controller.refreshPosts(),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: AppEmptyState(
                icon: Icons.forum_outlined,
                title: searching ? '没有找到相关动态' : '还没有动态',
                description: searching
                    ? '换个关键词试试'
                    : (canPublish
                          ? '分享一张作品或写生日记，同学和老师都能看到'
                          : '同学和老师发布的动态会出现在这里'),
                actionLabel: searching || !canPublish ? null : '发布动态',
                onAction: searching ? null : onPublish,
              ),
            ),
          ),
        ),
      );
    }

    return AppRefreshIndicator(
      onRefresh: () => controller.refreshPosts(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = constraints.maxWidth - AppSpace.page * 2;
          final columns = _columnCount(available);
          final colWidth = (available - _gap * (columns - 1)) / columns;

          final columnsContent = List<List<CirclePost>>.generate(
            columns,
            (_) => <CirclePost>[],
          );
          final columnsHeight = List<double>.filled(columns, 0);

          for (final post in posts) {
            final estImgH = colWidth / post.imageAspectRatio;
            final estCardH = 12 + 44 + 8 + 72 + estImgH + 60;
            var target = 0;
            for (var i = 1; i < columns; i++) {
              if (columnsHeight[i] < columnsHeight[target]) target = i;
            }
            columnsContent[target].add(post);
            columnsHeight[target] += estCardH + _gap;
          }

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              AppSpace.s4,
              AppSpace.page,
              AppSpace.s24,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < columns; i++) ...[
                  if (i > 0) const SizedBox(width: _gap),
                  SizedBox(
                    width: colWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final post in columnsContent[i]) ...[
                          CirclePostCard(
                            post: post,
                            onLike: () => _withToast(
                              context,
                              () => controller.toggleLike(post.id),
                            ),
                            onComment: () => _onCommentTap(post.id),
                            onFavorite: () =>
                                controller.toggleFavorite(post.id),
                            onTap: () => _onCardTap(post.id),
                            onDeletePost: menuActions.deleteFor(context, post),
                            onReportPost: menuActions.reportFor(context, post),
                          ),
                          const SizedBox(height: _gap),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _withToast(
    BuildContext context,
    Future<String?> Function() action,
  ) async {
    final message = await action();
    if (!context.mounted || message == null || message.isEmpty) return;
    AppToast.show(context, message);
  }

  void _onCardTap(String postId) {
    final index = state.visiblePosts.indexWhere((p) => p.id == postId);
    if (index < 0) return;
    controller
      ..setImmersiveIndex(index)
      ..setMode(CircleMode.immersive);
  }

  void _onCommentTap(String postId) {
    final index = state.visiblePosts.indexWhere((p) => p.id == postId);
    if (index < 0) return;
    controller
      ..setImmersiveIndex(index)
      ..setMode(CircleMode.immersive);
    unawaited(controller.openCommentPanel(postId));
  }
}

class _CircleListSkeleton extends StatelessWidget {
  const _CircleListSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - AppSpace.page * 2;
        final columns = CircleListView._columnCount(available);
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            AppSpace.s4,
            AppSpace.page,
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < columns; i++) ...[
                if (i > 0) const SizedBox(width: CircleListView._gap),
                const Expanded(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AppSkeleton.circle(size: 40),
                            SizedBox(width: AppSpace.s12),
                            Expanded(child: AppSkeletonText(lines: 2)),
                          ],
                        ),
                        SizedBox(height: AppSpace.s12),
                        AppSkeletonText(lines: 2),
                        SizedBox(height: AppSpace.s12),
                        AppSkeleton(height: 200, radius: AppRadius.card),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
