import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/art/art_subject.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/demo/demo_clock.dart';
import '../../../artworks/state/artwork_tasks_controller.dart';
import '../../../artworks/ui/artwork_upload_dialog.dart';
import '../../state/home_student_cards.dart';

/// 今日任务优先显示当天到期的作业，再给出练习建议。
class HomePracticeCard extends ConsumerWidget {
  const HomePracticeCard({super.key});

  static const double _bodyHeight = 168;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final practices = ref.watch(homePracticeProvider);
    final date = DemoClock.now().toIso8601String().substring(0, 10);
    final taskState = ref.watch(artworkTasksControllerProvider);
    final tasks = taskState.items
        .where((task) => task.dueTime.startsWith(date))
        .take(3)
        .toList();
    return AppCard(
      title: '今日任务',
      child: practices.when(
        loading: () => const _PracticeSkeleton(),
        error: (_, _) => SizedBox(
          height: _bodyHeight,
          child: AppErrorState(
            title: '练习建议加载失败',
            description: '请稍后重试',
            onRetry: () => ref.invalidate(homePracticeProvider),
          ),
        ),
        data: (items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (taskState.errorMessage.isNotEmpty)
              AppButton(
                label: '重新加载作业',
                variant: AppButtonVariant.text,
                onTap: ref
                    .read(artworkTasksControllerProvider.notifier)
                    .refresh,
              ),
            for (final task in tasks)
              AppListRow(
                title: task.title,
                subtitle: '${task.subject} · 今日到期',
                trailing: task.status == 'PENDING' || task.status == 'OVERDUE'
                    ? AppButton(
                        label: '去提交',
                        size: AppButtonSize.sm,
                        onTap: () async {
                          final saved = await showArtworkUploadDialog(
                            context,
                            taskId: task.id,
                            title: task.title,
                            subject: task.subject,
                          );
                          if (context.mounted && saved == true) {
                            AppToast.showSuccess(context, '作品已提交');
                          }
                        },
                      )
                    : AppTag(label: task.status == 'REVIEWED' ? '已点评' : '已提交'),
              ),
            for (
              var i = 0;
              i < items.length && i < (tasks.isEmpty ? 3 : 1);
              i++
            )
              _PracticeRow(
                item: items[i],
                divider: i < items.length - 1,
                onTap: () => Navigator.of(
                  context,
                ).pushNamed(items[i].route, arguments: items[i].arguments),
              ),
          ],
        ),
      ),
    );
  }
}

class _PracticeRow extends StatelessWidget {
  const _PracticeRow({
    required this.item,
    required this.divider,
    required this.onTap,
  });

  final HomePractice item;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subject = ArtSubject.tryParse(item.subject);
    final tag = item.tag;
    return AppPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
        decoration: divider
            ? const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
              )
            : null,
        child: Row(
          children: [
            AppIconTile(
              icon: item.icon,
              size: 36,
              color: subject?.accent ?? AppColors.brand,
              background: subject?.accentSoft ?? AppColors.brandWash,
            ),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body14Strong,
                        ),
                      ),
                      if (tag.isNotEmpty) ...[
                        const SizedBox(width: AppSpace.s8),
                        switch (item.source) {
                          HomePracticeSource.problem => AppTag(
                            label: tag,
                            tone: AppTone.warning,
                          ),
                          HomePracticeSource.weakSubject => AppTag.subject(tag),
                          HomePracticeSource.basics => AppTag(label: tag),
                        },
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.reason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption12,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.s12),
            Text('去练习', style: AppText.body13.copyWith(color: AppColors.brand)),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppColors.brand,
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeSkeleton extends StatelessWidget {
  const _PracticeSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: HomePracticeCard._bodyHeight,
      child: Column(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(height: AppSpace.s20),
            const Row(
              children: [
                AppSkeleton(width: 36, height: 36, radius: AppRadius.control),
                SizedBox(width: AppSpace.s12),
                Expanded(child: AppSkeletonText(lines: 2)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
