import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';

import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/scaled_dialog.dart';
import '../../../shell/ui/shell_layout.dart';
import '../../state/circle_controller.dart';
import '../../state/circle_state.dart';
import 'circle_post_card.dart';

/// 列表模式：瀑布流。沿 Y 方向按列累计高度，把每个卡片填到当前最矮的那一列。
class CircleListView extends StatelessWidget {
  const CircleListView({
    super.key,
    required this.state,
    required this.controller,
    required this.permissions,
  });

  final CircleState state;
  final CircleController controller;
  final CirclePermissions permissions;

  static int _columnCount(double width, double Function(double) ui) {
    if (width < ui(520)) return 1;
    if (width < ui(900)) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final posts = state.visiblePosts;

    if (state.listLoading && posts.isEmpty) {
      return Container(
        color: const Color(0xFFEFF3FC),
        alignment: Alignment.center,
        child: const AppLoadingIndicator(),
      );
    }

    if (posts.isEmpty) {
      return Container(
        color: const Color(0xFFEFF3FC),
        child: AppRefreshIndicator(
          onRefresh: () => controller.refreshPosts(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: ui(120)),
              const Center(
                child: Text(
                  '暂无动态',
                  style: TextStyle(
                    color: Color(0xFFB6B5BB),
                    fontSize: 14,
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      color: const Color(0xFFEFF3FC),
      // 外层 AnimatedSwitcher 默认按 center 对齐子节点；列表内容不满一屏时
      // SingleChildScrollView 会收缩到内容高度并被垂直居中，导致渲染完成后
      // 顶部凭空多出一段间距。这里强制铺满并顶对齐，让首张卡片紧贴顶部。
      alignment: Alignment.topCenter,
      child: AppRefreshIndicator(
        onRefresh: () => controller.refreshPosts(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final gap = ui(16);
            final available = constraints.maxWidth;
            final columns = _columnCount(available, ui);
            final colWidth =
                (available - gap * (columns - 1)) / columns;

            final columnsContent = List<List<CirclePost>>.generate(
              columns,
              (_) => <CirclePost>[],
            );
            final columnsHeight = List<double>.filled(columns, 0);

            for (final post in posts) {
              final estTextH = ui(72);
              final estImgH = colWidth / post.imageAspectRatio;
              final estCardH =
                  ui(12) + ui(44) + ui(8) + estTextH + estImgH + ui(60);
              var target = 0;
              for (var i = 1; i < columns; i++) {
                if (columnsHeight[i] < columnsHeight[target]) target = i;
              }
              columnsContent[target].add(post);
              columnsHeight[target] += estCardH + gap;
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              padding: EdgeInsets.only(bottom: gap),
              child: SizedBox(
                width: available,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < columns; i++) ...[
                      if (i > 0) SizedBox(width: gap),
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
                                onDeletePost: permissions.canDeletePost(post)
                                    ? () => _confirmDeletePost(context, post)
                                    : null,
                              ),
                              SizedBox(height: gap),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
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

  Future<void> _confirmDeletePost(
    BuildContext context,
    CirclePost post,
  ) async {
    final ok = await showConfirmDialog(
      context: context,
      title: '删除帖子',
      content: '确定删除这条动态吗？删除后不可恢复。',
    );
    if (!ok || !context.mounted) return;
    final message = await controller.deletePost(post.id);
    if (!context.mounted) return;
    if (message != null && message.isNotEmpty) {
      AppToast.show(context, message);
    }
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
