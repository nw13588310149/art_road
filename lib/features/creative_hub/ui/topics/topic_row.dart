import 'package:flutter/material.dart';

import '../../../../core/art/art_subject.dart';
import '../../../../core/ui/ui.dart';
import '../../data/creative_models.dart';

/// 科目的显示名，和筛选条一致。
String topicSubjectLabel(String subject) =>
    ArtSubject.tryParse(subject)?.label ?? subject;

/// 一份课件的说明行：科目、难度、建议时长、资料份数、整理人。
/// 已经按科目筛选时不再写科目。
String topicMeta(LearningTopic topic, {bool withSubject = true}) => [
  if (withSubject) topicSubjectLabel(topic.subject),
  topic.level,
  '${topic.minutes} 分钟',
  '${topic.resources.length} 份资料',
  '${topic.author} 整理',
].where((part) => part.isNotEmpty).join(' · ');

/// 课件的封面缩略图：按原比例完整显示在中性底上，不裁。
class TopicCover extends StatelessWidget {
  const TopicCover({required this.src, required this.width, super.key});
  final String src;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: AppImageTile.frame(
      aspectRatio: 3 / 4,
      child: ColoredBox(
        color: AppColors.canvas,
        child: AppImage(src: src, fit: BoxFit.contain),
      ),
    ),
  );
}

/// 列表里的一行：封面、名称、一句说明和说明行，行尾是收藏。整行打开详情。
class TopicRow extends StatelessWidget {
  const TopicRow({
    required this.topic,
    required this.onTap,
    required this.onFavorite,
    this.withSubject = true,
    super.key,
  });
  final LearningTopic topic;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final bool withSubject;

  @override
  Widget build(BuildContext context) {
    final meta = topicMeta(topic, withSubject: withSubject);
    return Row(
      children: [
        Expanded(
          child: AppPressable(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s16),
              child: Row(
                children: [
                  TopicCover(src: topic.cover, width: 48),
                  const SizedBox(width: AppSpace.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topic.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body14Strong,
                        ),
                        if (topic.intro.isNotEmpty)
                          Text(
                            topic.intro,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body13,
                          ),
                        const SizedBox(height: AppSpace.s4),
                        Text(
                          meta,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption12,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.s12),
        // 收藏的状态靠实心图标表示；一屏里可能有好几份已收藏，不用品牌紫。
        Transform.translate(
          offset: const Offset(12, 0),
          child: AppIconAction(
            icon: Icons.bookmark_border_rounded,
            activeIcon: Icons.bookmark_rounded,
            active: topic.favorite,
            activeColor: AppColors.ink,
            semanticLabel: topic.favorite ? '取消收藏课件' : '收藏课件',
            onTap: onFavorite,
          ),
        ),
      ],
    );
  }
}

/// 加载时占住和一行同样的位置。
class TopicRowSkeleton extends StatelessWidget {
  const TopicRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpace.s16),
    child: Row(
      children: [
        AppSkeleton(width: 48, height: 64, radius: 6),
        SizedBox(width: AppSpace.s16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeleton(width: 220, height: 16),
              SizedBox(height: AppSpace.s8),
              AppSkeleton(width: 360, height: 13),
              SizedBox(height: AppSpace.s8),
              AppSkeleton(width: 200, height: 12),
            ],
          ),
        ),
      ],
    ),
  );
}
