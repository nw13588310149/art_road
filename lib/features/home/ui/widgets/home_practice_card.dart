import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/art/art_subject.dart';
import '../../../../core/ui/ui.dart';
import '../../state/home_student_cards.dart';

/// 学生首页「今日练习」：1–3 条按高频问题与弱项科目推荐的练习，点开直达工具或范画库。
class HomePracticeCard extends ConsumerWidget {
  const HomePracticeCard({super.key});

  static const double _bodyHeight = 168;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final practices = ref.watch(homePracticeProvider);
    return AppCard(
      title: '今日练习',
      subtitle: '根据老师点评和最近一次月考推荐',
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
            for (var i = 0; i < items.length; i++)
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
