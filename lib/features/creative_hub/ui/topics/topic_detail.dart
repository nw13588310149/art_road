import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../../artworks/ui/widgets/artwork_focus_panel.dart';
import '../../../shell/state/shell_controller.dart';
import '../../data/creative_models.dart';
import '../../state/creative_controllers.dart';
import 'topic_reader.dart';
import 'topic_row.dart';

const _practiceHint = '完成一次局部练习，附上调整说明，再通过任课老师的点评检查是否改善。';

/// 一份课件：页头是课件名、收藏和「开始阅读」；主栏是说明、阅读资料和练习，
/// 侧栏是同科目的其他课件。
class TopicDetail extends ConsumerWidget {
  const TopicDetail({
    required this.topic,
    required this.onBack,
    required this.onOpen,
    super.key,
  });
  final LearningTopic topic;
  final VoidCallback onBack;

  /// 打开侧栏里的另一份课件。
  final ValueChanged<LearningTopic> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final student =
        ref.watch(shellControllerProvider.select((shell) => shell.user.role)) ==
        'student';
    final others = ref
        .watch(learningTopicsProvider)
        .items
        .where((row) => row.id != topic.id);
    final sameSubject = others.where((row) => row.subject == topic.subject);
    final related = (sameSubject.isEmpty ? others : sameSubject)
        .take(4)
        .toList();
    final relatedTitle = sameSubject.isEmpty
        ? '更多课件'
        : '更多${topicSubjectLabel(topic.subject)}课件';
    return AppPageBody(
      builder: (context, wide) {
        final main = _main(context, wide, student, beside: related.isNotEmpty);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTitleBar(
              title: topic.title,
              onBack: onBack,
              actions: [
                AppPlainButton(
                  label: topic.favorite ? '已收藏' : '收藏',
                  icon: topic.favorite
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: topic.favorite ? AppColors.brand : AppColors.ink,
                  onTap: () async {
                    final error = await ref
                        .read(learningTopicsProvider.notifier)
                        .favorite(topic.id);
                    if (context.mounted && error != null) {
                      AppToast.showError(context, error);
                    }
                  },
                ),
                const SizedBox(width: AppSpace.s8),
                AppButton(
                  label: '开始阅读',
                  onTap: topic.resources.isEmpty
                      ? null
                      : () => openTopicResource(context, topic.resources.first),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s20),
            if (related.isEmpty)
              main
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: main),
                  SizedBox(width: AppPageBody.columnGap(wide)),
                  SizedBox(
                    width: AppPageBody.sideWidth(wide),
                    child: _related(relatedTitle, related),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _main(
    BuildContext context,
    bool wide,
    bool student, {
    required bool beside,
  }) {
    final exercise = topic.exercise.isEmpty
        ? '选择一份自己的作品，用今天的知识点完成一次局部改画。'
        : topic.exercise;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          [
            topicSubjectLabel(topic.subject),
            topic.level,
            '建议 ${topic.minutes} 分钟',
            '${topic.author} 整理',
          ].where((part) => part.isNotEmpty).join(' · '),
          style: AppText.body13,
        ),
        const SizedBox(height: AppSpace.s8),
        Text(topic.intro, style: AppText.body16),
        if (topic.tags.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s12),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [for (final tag in topic.tags) AppTag(label: tag)],
          ),
        ],
        const SizedBox(height: AppSpace.s24),
        const AppRule(),
        const SizedBox(height: AppSpace.s24),
        AppSectionTitle(
          title: '阅读资料',
          note: '${topic.resources.length} 份 · 点封面开始阅读',
        ),
        const SizedBox(height: AppSpace.s16),
        AppTileGrid(
          // 和侧栏并排时少一列，封面大小在每份课件里一样。
          columns: (wide ? 5 : 4) - (beside ? 1 : 0),
          gap: AppPageBody.tileGap(wide),
          children: [
            for (final resource in topic.resources)
              AppImageTile(
                image: AppImageTile.frame(
                  aspectRatio: 3 / 4,
                  child: ColoredBox(
                    color: AppColors.canvas,
                    child: AppImage(src: resource.cover, fit: BoxFit.contain),
                  ),
                ),
                title: resource.title,
                meta: topicResourceKind(resource),
                onTap: () => openTopicResource(context, resource),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.s24),
        const AppRule(),
        const SizedBox(height: AppSpace.s24),
        const AppSectionTitle(title: '读完，动笔试一试'),
        const SizedBox(height: AppSpace.s8),
        Text(exercise, style: AppText.body14),
        const SizedBox(height: AppSpace.s4),
        Text(_practiceHint, style: AppText.body13),
        if (student) ...[
          const SizedBox(height: AppSpace.s8),
          // 文字和上面的正文对齐，点击区域向左伸出。
          Transform.translate(
            offset: const Offset(-AppSpace.s12, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppPlainButton(
                  label: '开始练习',
                  icon: Icons.draw_outlined,
                  onTap: () => showArtworkPractice(
                    context,
                    subject: topic.subject,
                    title: topic.title,
                    instruction: topic.exercise.isEmpty
                        ? topic.intro
                        : topic.exercise,
                    sourceLabel: '优秀课件 · ${topic.title}',
                    sourceId: topic.id,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _related(String title, List<LearningTopic> related) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppSectionTitle(title: title),
      const SizedBox(height: AppSpace.s8),
      for (final row in related) ...[
        const AppRule(),
        AppPressable(
          onTap: () => onOpen(row),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body14Strong,
                ),
                Text(
                  [
                    if (row.subject != topic.subject)
                      topicSubjectLabel(row.subject),
                    row.level,
                    '${row.minutes} 分钟',
                    '${row.author} 整理',
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption12,
                ),
              ],
            ),
          ),
        ),
      ],
      const AppRule(),
    ],
  );
}
