import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/app_refresh_indicator.dart';
import '../data/artwork_models.dart';
import '../data/artwork_rules.dart';
import '../state/lead_reviews_controller.dart';

/// 组长复核池：最小可用列表与简易复核表单。
class LeadReviewsPage extends ConsumerWidget {
  const LeadReviewsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(leadReviewsControllerProvider);
    final controller = ref.read(leadReviewsControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(
          title: '复核池',
          subtitle: '待复核 ${state.pending} · 超时 ${state.overdue} · 已复核 ${state.done}',
          onBack: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: state.loading && state.items.isEmpty
              ? const Center(child: AppLoadingIndicator(size: 36))
              : state.errorMessage.isNotEmpty && state.items.isEmpty
              ? AppErrorState(
                  title: '复核池加载失败',
                  description: state.errorMessage,
                  onRetry: controller.refresh,
                )
              : AppRefreshIndicator(
                  onRefresh: controller.refresh,
                  child: state.items.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            AppEmptyState(
                              icon: Icons.fact_check_outlined,
                              title: '暂无待复核作品',
                              description: '老师请组长复核、分数异常、点评过简或抽中后会出现在这里',
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpace.page,
                            AppSpace.s8,
                            AppSpace.page,
                            AppSpace.s24,
                          ),
                          itemCount: state.items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpace.s12),
                          itemBuilder: (context, index) {
                            final item = state.items[index];
                            return _LeadCard(
                              item: item,
                              onOpen: () => Navigator.of(context).pushNamed(
                                RoutePaths.artworks,
                                arguments: <String, dynamic>{
                                  'artworkId': item.id,
                                },
                              ),
                              onReview: () => _openReviewSheet(
                                context,
                                ref,
                                item,
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }

  Future<void> _openReviewSheet(
    BuildContext context,
    WidgetRef ref,
    ArtworkSummary item,
  ) async {
    final action = ValueNotifier<String>('KEEP');
    final stars = ValueNotifier<int>(4);
    final score = TextEditingController(
      text: item.finalScore == null
          ? ''
          : ArtworkRules.formatScore(item.finalScore),
    );
    final reason = TextEditingController();
    final content = TextEditingController();
    final note = TextEditingController();
    try {
      final confirmed = await showAppDialog<bool>(
        context: context,
        builder: (context) {
          return AppDialog(
            title: '提交复核',
            actions: [
              AppButton(
                label: '取消',
                variant: AppButtonVariant.quiet,
                onTap: () => Navigator.of(context).pop(false),
              ),
              AppButton(
                label: '提交',
                onTap: () => Navigator.of(context).pop(true),
              ),
            ],
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(item.title, style: AppText.body14),
                  const SizedBox(height: AppSpace.s12),
                  ValueListenableBuilder<String>(
                    valueListenable: action,
                    builder: (context, value, _) {
                      return AppSegmented<String>(
                        segments: const [
                          AppSegment(value: 'KEEP', label: '维持'),
                          AppSegment(value: 'ADJUST', label: '调分'),
                          AppSegment(value: 'SUPPLEMENT', label: '补充'),
                        ],
                        value: value,
                        onChanged: (next) => action.value = next,
                      );
                    },
                  ),
                  const SizedBox(height: AppSpace.s12),
                  ValueListenableBuilder<int>(
                    valueListenable: stars,
                    builder: (context, value, _) {
                      return Wrap(
                        spacing: 8,
                        children: [
                          for (var i = 1; i <= 5; i++)
                            AppChip(
                              label: '$i 星',
                              selected: value == i,
                              onTap: () => stars.value = i,
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpace.s12),
                  ValueListenableBuilder<String>(
                    valueListenable: action,
                    builder: (context, value, _) {
                      if (value == 'ADJUST') {
                        return Column(
                          children: [
                            AppInputField(
                              controller: score,
                              label: '调整后分数',
                            ),
                            const SizedBox(height: AppSpace.s8),
                            AppInputField(
                              controller: reason,
                              label: '调分理由（至少 10 字）',
                              maxLines: 3,
                            ),
                          ],
                        );
                      }
                      if (value == 'SUPPLEMENT') {
                        return AppInputField(
                          controller: content,
                          label: '补充评语',
                          maxLines: 3,
                        );
                      }
                      return AppInputField(
                        controller: note,
                        label: '点评质量意见（可选）',
                        maxLines: 2,
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (confirmed != true || !context.mounted) {
        return;
      }
      final parsed = double.tryParse(score.text.trim());
      final error = await ref
          .read(leadReviewsControllerProvider.notifier)
          .submit(
            artworkId: item.id,
            action: action.value,
            score: action.value == 'ADJUST' ? parsed : null,
            reason: reason.text,
            content: content.text,
            qualityStars: stars.value,
            qualityNote: note.text,
            maxScore: item.maxScore,
          );
      if (!context.mounted) {
        return;
      }
      if (error != null) {
        AppToast.showError(context, error);
      } else {
        AppToast.showSuccess(context, '复核已提交');
      }
    } finally {
      action.dispose();
      stars.dispose();
      score.dispose();
      reason.dispose();
      content.dispose();
      note.dispose();
    }
  }
}

class _LeadCard extends StatelessWidget {
  const _LeadCard({
    required this.item,
    required this.onOpen,
    required this.onReview,
  });

  final ArtworkSummary item;
  final VoidCallback onOpen;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: AppImage(src: item.coverUrl, borderRadius: AppRadius.br8),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: AppText.body14),
                const SizedBox(height: 4),
                Text(
                  '${item.studentName} · ${item.teacherName} · ${item.subject}',
                  style: AppText.caption12,
                ),
                if (item.leadOverdue)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '复核超时',
                      style: AppText.caption12.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          AppButton(
            label: '查看',
            variant: AppButtonVariant.quiet,
            size: AppButtonSize.sm,
            onTap: onOpen,
          ),
          const SizedBox(width: 8),
          AppButton(
            label: item.leadStatus == ArtworkLeadStatus.inReview
                ? '复核'
                : '已复核',
            size: AppButtonSize.sm,
            onTap: item.leadStatus == ArtworkLeadStatus.inReview
                ? onReview
                : null,
          ),
        ],
      ),
    );
  }
}
