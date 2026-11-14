import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/app_refresh_indicator.dart';
import '../data/artwork_models.dart';
import '../data/artwork_rules.dart';
import '../state/lead_reviews_controller.dart';
import 'widgets/artwork_review_actions.dart';

class LeadReviewsPage extends ConsumerWidget {
  const LeadReviewsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(leadReviewsControllerProvider);
    final controller = ref.read(leadReviewsControllerProvider.notifier);
    final items = state.visibleItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(
          title: '复核池',
          subtitle:
              '待复核 ${state.stats.pending} · 超时 ${state.stats.overdue} · 已复核 ${state.stats.done}',
          onBack: () => Navigator.of(context).maybePop(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            AppSpace.s4,
            AppSpace.page,
            AppSpace.s12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpace.s12,
            children: [
              AppSegmented<LeadPoolStatus>(
                value: state.status,
                segments: [
                  for (final status in LeadPoolStatus.values)
                    AppSegment(value: status, label: status.label),
                ],
                onChanged: (status) => unawaited(controller.setStatus(status)),
              ),
              Wrap(
                spacing: AppSpace.s12,
                runSpacing: AppSpace.s8,
                children: [
                  SizedBox(
                    width: 160,
                    child: AppSelect<String>(
                      value: state.teacherId,
                      options: [
                        const AppSelectOption(value: '', label: '全部老师'),
                        for (final teacher in state.teachers)
                          AppSelectOption(
                            value: teacher.id,
                            label: teacher.name,
                          ),
                      ],
                      onChanged: (id) => unawaited(controller.setTeacher(id)),
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: AppSelect<String>(
                      value: state.reason,
                      options: [
                        const AppSelectOption(value: '', label: '全部原因'),
                        for (final reason in artworkLeadReasonLabels.entries)
                          AppSelectOption(
                            value: reason.key,
                            label: reason.value,
                          ),
                      ],
                      onChanged: (reason) =>
                          unawaited(controller.setReason(reason)),
                    ),
                  ),
                  SizedBox(
                    width: 324,
                    child: AppSearchField(
                      hint: '搜索学生、老师或作品',
                      onChanged: (keyword) =>
                          unawaited(controller.setKeyword(keyword)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: state.loading || state.loadingList
              ? const Center(child: AppLoadingIndicator(size: 36))
              : state.listFailed
              ? AppErrorState(
                  title: '复核池加载失败',
                  description: state.errorMessage,
                  onRetry: controller.refresh,
                )
              : AppRefreshIndicator(
                  onRefresh: controller.refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.page,
                      0,
                      AppSpace.page,
                      AppSpace.s24,
                    ),
                    children: [
                      if (items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 80),
                          child: AppEmptyState(
                            icon: Icons.fact_check_outlined,
                            title: state.filtered
                                ? '没有符合筛选条件的作品'
                                : '暂无${state.status.label == '全部' ? '复核' : state.status.label}作品',
                            description: state.filtered
                                ? '试试调整筛选条件'
                                : '需要复核的作品会出现在这里',
                          ),
                        ),
                      for (final item in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.s12),
                          child: _LeadCard(
                            item: item,
                            onOpen: () async {
                              await Navigator.of(context).pushNamed(
                                RoutePaths.artworks,
                                arguments: {'artworkId': item.id},
                              );
                              if (context.mounted) await controller.refresh();
                            },
                          ),
                        ),
                      if (state.hasMore)
                        Center(
                          child: AppButton(
                            label: '加载更多',
                            variant: AppButtonVariant.secondary,
                            loading: state.loadingMore,
                            onTap: controller.loadMore,
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _LeadCard extends StatelessWidget {
  const _LeadCard({required this.item, required this.onOpen});

  final ArtworkSummary item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        spacing: AppSpace.s12,
        children: [
          SizedBox.square(
            dimension: 92,
            child: AppImage(src: item.coverUrl, borderRadius: AppRadius.br8),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpace.s4,
              children: [
                Text(
                  item.title,
                  style: AppText.body14Strong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${item.studentName} · ${item.teacherName} · ${item.subject}',
                  style: AppText.caption12,
                ),
                if (item.leadEnteredTime.isNotEmpty)
                  Text(
                    '进入复核池 ${ArtworkRules.shortTime(item.leadEnteredTime)}',
                    style: AppText.caption12,
                  ),
                Wrap(
                  spacing: AppSpace.s4,
                  runSpacing: AppSpace.s4,
                  children: [
                    if (item.leadOverdue)
                      const AppTag(label: '复核超时', tone: AppTone.danger),
                    for (final reason in item.leadReasons)
                      AppTag(label: artworkLeadReasonLabels[reason] ?? reason),
                  ],
                ),
              ],
            ),
          ),
          AppButton(
            label: item.leadStatus == ArtworkLeadStatus.inReview ? '复核' : '查看',
            variant: item.leadStatus == ArtworkLeadStatus.inReview
                ? AppButtonVariant.primary
                : AppButtonVariant.secondary,
            size: AppButtonSize.sm,
            onTap: onOpen,
          ),
        ],
      ),
    );
  }
}
