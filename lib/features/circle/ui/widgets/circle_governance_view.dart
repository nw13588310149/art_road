import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../state/circle_governance_controller.dart';
import '../../state/circle_governance_state.dart';
import '../../state/circle_state.dart';
import 'circle_post_actions.dart';

/// 「校圈治理」的待处理 / 已处理列表。
class CircleGovernanceView extends ConsumerWidget {
  const CircleGovernanceView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(circleGovernanceControllerProvider);
    final controller = ref.read(circleGovernanceControllerProvider.notifier);
    ref.listen(circleGovernanceControllerProvider.select((s) => s.error), (
      previous,
      next,
    ) {
      final current = ref.read(circleGovernanceControllerProvider);
      if (next != null && next != previous && current.loaded) {
        AppToast.showError(context, next);
      }
    });

    if (!state.loaded) {
      final error = state.error;
      if (error != null && !state.loading) {
        return AppErrorState(
          title: '举报记录加载失败',
          description: error,
          onRetry: controller.load,
        );
      }
      return const _CaseListSkeleton();
    }

    final pendingTab = state.tab == CircleGovernanceTab.pending;
    final items = pendingTab ? state.pending : state.handled;
    if (items.isEmpty) {
      return AppRefreshIndicator(
        onRefresh: controller.load,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: pendingTab
                  ? const AppEmptyState(
                      icon: Icons.task_alt_rounded,
                      title: '没有待处理的举报',
                      description: '同学和老师举报的动态会出现在这里，处理后移到「已处理」',
                    )
                  : const AppEmptyState(
                      icon: Icons.history_rounded,
                      title: '还没有处理记录',
                      description: '在「待处理」里保留或删除动态后，记录会保存在这里',
                    ),
            ),
          ),
        ),
      );
    }

    return AppRefreshIndicator(
      onRefresh: controller.load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpace.page,
          AppSpace.s4,
          AppSpace.page,
          AppSpace.s24,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s12),
        itemBuilder: (context, index) {
          final item = items[index];
          return CircleReportCaseCard(
            key: ValueKey(item.id),
            item: item,
            busy: state.busyIds.contains(item.id),
            onKeep: pendingTab
                ? () => runGovernanceKeep(
                    context,
                    submit: () => controller.keep(item.id),
                  )
                : null,
            onDelete: pendingTab
                ? () => runGovernanceDelete(
                    context,
                    submit: (reason, remark) => controller.delete(
                      item.id,
                      reason: reason,
                      remark: remark,
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }
}

/// 一条举报记录：举报概况（已处理时为处理结果）+ 被举报的动态 + 说明 + 操作。
class CircleReportCaseCard extends StatelessWidget {
  const CircleReportCaseCard({
    super.key,
    required this.item,
    this.busy = false,
    this.onKeep,
    this.onDelete,
  });

  final CircleReportCase item;
  final bool busy;
  final VoidCallback? onKeep;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final showActions = item.pending && (onKeep != null || onDelete != null);
    final reasonSummary = [
      for (final r in item.reasons) '${r.reason} ${r.count} 人',
    ].join('、');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.pending)
            _PendingSummary(item: item)
          else
            _HandledSummary(item: item),
          const SizedBox(height: AppSpace.s12),
          _PostPreview(post: item.post),
          if (item.pending && item.latestRemark.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s12),
            _NoteLine(label: '举报说明', text: item.latestRemark),
          ],
          if (!item.pending && reasonSummary.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s12),
            _NoteLine(label: '举报原因', text: reasonSummary),
          ],
          if (!item.pending && item.handleRemark.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s4),
            _NoteLine(label: '处理说明', text: item.handleRemark),
          ],
          if (showActions) ...[
            const SizedBox(height: AppSpace.s12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  label: '保留',
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.sm,
                  enabled: !busy,
                  onTap: onKeep,
                ),
                const SizedBox(width: AppSpace.s8),
                AppButton(
                  label: '删除',
                  variant: AppButtonVariant.danger,
                  size: AppButtonSize.sm,
                  enabled: !busy,
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingSummary extends StatelessWidget {
  const _PendingSummary({required this.item});

  final CircleReportCase item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.flag_outlined, size: 16, color: AppColors.warning),
        const SizedBox(width: AppSpace.s4),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${item.reportCount}',
                style: AppText.number(size: 14),
              ),
              TextSpan(text: ' 人举报', style: AppText.body14Strong),
            ],
          ),
        ),
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: Wrap(
            spacing: AppSpace.s4,
            runSpacing: AppSpace.s4,
            children: [
              for (final r in item.reasons)
                AppTag(
                  label: r.count > 1 ? '${r.reason} ${r.count}' : r.reason,
                  tone: AppTone.warning,
                ),
            ],
          ),
        ),
        if (item.lastReportTime.isNotEmpty) ...[
          const SizedBox(width: AppSpace.s12),
          Text('最近举报 ${item.lastReportTime}', style: AppText.caption12),
        ],
      ],
    );
  }
}

class _HandledSummary extends StatelessWidget {
  const _HandledSummary({required this.item});

  final CircleReportCase item;

  @override
  Widget build(BuildContext context) {
    final deleted = item.result == CircleReportResult.deleted;
    final reason = item.handleReason.isEmpty ? '未填写' : item.handleReason;
    final handledBy = [
      if (item.handlerName.isNotEmpty) item.handlerName,
      if (item.handleTime.isNotEmpty) item.handleTime,
    ].join(' · ');
    return Row(
      children: [
        AppStatusTag(
          label: deleted ? '已删除' : '已保留',
          tone: deleted ? AppTone.danger : AppTone.success,
        ),
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: Text(
            '${deleted ? '删除原因' : '处理结果'}：$reason',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body14,
          ),
        ),
        if (handledBy.isNotEmpty) ...[
          const SizedBox(width: AppSpace.s12),
          Text('$handledBy 处理', style: AppText.caption12),
        ],
      ],
    );
  }
}

class _PostPreview extends StatelessWidget {
  const _PostPreview({required this.post});

  final CirclePost? post;

  @override
  Widget build(BuildContext context) {
    final post = this.post;
    if (post == null) {
      return Text('动态内容已无法查看', style: AppText.body13);
    }
    final role = formatCircleAuthorRole(post.author.role);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PostThumb(post: post),
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  AppAvatar(
                    name: post.author.name,
                    url: post.author.avatarUrl,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: Row(
                      children: [
                        Text(post.author.name, style: AppText.body14Strong),
                        if (role.isNotEmpty) ...[
                          const SizedBox(width: AppSpace.s8),
                          Flexible(
                            child: Text(
                              role,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (post.timeLabel.isNotEmpty) ...[
                    const SizedBox(width: AppSpace.s12),
                    Text('${post.timeLabel} 发布', style: AppText.caption12),
                  ],
                ],
              ),
              const SizedBox(height: AppSpace.s4),
              Text(
                post.text.isEmpty ? '（没有文字内容）' : post.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppText.body14,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PostThumb extends StatelessWidget {
  const _PostThumb({required this.post});

  final CirclePost post;

  static const double _size = 72;

  @override
  Widget build(BuildContext context) {
    if (post.imageUrl.isEmpty) {
      return Container(
        width: _size,
        height: _size,
        decoration: const BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: AppRadius.br8,
        ),
        child: const Icon(
          Icons.notes_rounded,
          size: 24,
          color: AppColors.textTertiary,
        ),
      );
    }
    final image = AppImage(
      src: post.imageUrl,
      width: _size,
      height: _size,
      borderRadius: AppRadius.br8,
    );
    if (post.mediaKind == PostMediaKind.image) return image;
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          Center(
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                post.mediaKind == PostMediaKind.video
                    ? Icons.play_arrow_rounded
                    : Icons.headphones_outlined,
                size: 18,
                color: AppColors.onBrand,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteLine extends StatelessWidget {
  const _NoteLine({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label：',
            style: AppText.body13.copyWith(color: AppColors.textTertiary),
          ),
          TextSpan(text: text, style: AppText.body13),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _CaseListSkeleton extends StatelessWidget {
  const _CaseListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.page,
        AppSpace.s4,
        AppSpace.page,
        0,
      ),
      children: [
        for (var i = 0; i < 3; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpace.s12),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppSkeleton(width: 160, height: 22),
                      Spacer(),
                      AppSkeleton(width: 112),
                    ],
                  ),
                  SizedBox(height: AppSpace.s12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeleton(width: 72, height: 72, radius: AppRadius.control),
                      SizedBox(width: AppSpace.s12),
                      Expanded(child: AppSkeletonText(lines: 3)),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
