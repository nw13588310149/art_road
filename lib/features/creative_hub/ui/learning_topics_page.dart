import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../artworks/ui/widgets/artwork_focus_panel.dart';
import '../../shell/state/shell_controller.dart';
import '../data/creative_models.dart';
import '../state/creative_controllers.dart';
import 'creative_widgets.dart';
import 'learning_topic_editor.dart';

class LearningTopicsPage extends ConsumerStatefulWidget {
  const LearningTopicsPage({super.key});
  @override
  ConsumerState<LearningTopicsPage> createState() => _LearningTopicsPageState();
}

class _LearningTopicsPageState extends ConsumerState<LearningTopicsPage> {
  String? _selected;
  bool _creating = false;
  bool _readArguments = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_readArguments) return;
    _readArguments = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(learningTopicsProvider.notifier)
            .filter(
              subject: args['subject']?.toString() ?? '',
              keyword: args['keyword']?.toString() ?? '',
            );
        if (args['topicId'] != null) {
          setState(() => _selected = args['topicId'].toString());
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(learningTopicsProvider);
    final controller = ref.read(learningTopicsProvider.notifier);
    final topic = state.items.where((row) => row.id == _selected).firstOrNull;
    if (_creating) {
      return LearningTopicEditor(
        onClose: () => setState(() => _creating = false),
      );
    }
    if (topic != null) return _detail(topic);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          CreativeHeading(
            title: '小课件',
            subtitle: '美术的小课间，围绕一个知识点读几页、练一笔。',
            actions: [
              AppButton(
                label: '新增小课件',
                icon: Icons.add,
                onTap: () => setState(() => _creating = true),
              ),
            ],
          ),
          Row(
            children: [
              AppSegmented<String>(
                value: state.view,
                onChanged: (value) => controller.filter(view: value),
                segments: const [
                  AppSegment(value: 'all', label: '发现专题'),
                  AppSegment(value: 'saved', label: '我的收藏'),
                  AppSegment(value: 'mine', label: '我的发布'),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 240,
                child: AppSearchField(
                  hint: '搜索知识点、绘画技巧',
                  onChanged: (value) => controller.filter(keyword: value),
                ),
              ),
            ],
          ),
          CreativeSubjectFilter(
            value: state.subject,
            onChanged: (value) => controller.filter(subject: value),
          ),
          if (state.keyword.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: Text('当前知识点：${state.keyword}', style: AppText.body13),
                ),
                AppButton(
                  label: '清除关键词',
                  variant: AppButtonVariant.text,
                  size: AppButtonSize.sm,
                  onTap: () => controller.filter(keyword: ''),
                ),
              ],
            ),
          Expanded(
            child: state.loading
                ? const Center(child: AppLoadingIndicator())
                : state.error.isNotEmpty
                ? AppErrorState(
                    title: '专题加载失败',
                    description: state.error,
                    onRetry: controller.load,
                  )
                : controller.visible.isEmpty
                ? AppEmptyState(
                    title: state.view == 'saved' ? '还没有收藏的小课件' : '暂无匹配专题',
                    description: '试试其他知识点，或创建自己的阅读专题。',
                    actionLabel: '查看本科目全部专题',
                    onAction: () => controller.filter(keyword: '', view: 'all'),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) => GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: constraints.maxWidth >= 880 ? 3 : 2,
                        mainAxisExtent: 322,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: controller.visible.length,
                      itemBuilder: (context, index) =>
                          _card(controller.visible[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _card(LearningTopic topic) => AppCard(
    padding: EdgeInsets.zero,
    onTap: () => setState(() => _selected = topic.id),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 154,
          decoration: const BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AppImage(
                  src: topic.cover,
                  height: 140,
                  fit: BoxFit.contain,
                ),
              ),
              if (topic.resources.length > 1) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: AppImage(
                    src: topic.resources[1].cover,
                    height: 118,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppTag.subject(topic.subject),
                  const Spacer(),
                  Text(
                    '${topic.minutes} 分钟 · ${topic.resources.length} 份资料',
                    style: AppText.caption12,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                topic.title,
                style: AppText.title16,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                topic.tags.join(' / '),
                style: AppText.body13,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${topic.author} · ${topic.level}',
                      style: AppText.caption12,
                    ),
                  ),
                  AppIconButton(
                    icon: topic.favorite
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    semanticLabel: topic.favorite ? '取消收藏专题' : '收藏专题',
                    filled: false,
                    size: AppButtonSize.sm,
                    onTap: () async {
                      final error = await ref
                          .read(learningTopicsProvider.notifier)
                          .favorite(topic.id);
                      if (mounted && error != null) {
                        AppToast.showError(context, error);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _detail(LearningTopic topic) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 20,
      children: [
        CreativeHeading(
          title: '阅读专题',
          subtitle:
              '${topic.subject} · ${topic.level} · 建议 ${topic.minutes} 分钟',
          onBack: () => setState(() => _selected = null),
          actions: [
            AppButton(
              label: topic.favorite ? '已收藏' : '收藏专题',
              variant: AppButtonVariant.secondary,
              icon: topic.favorite ? Icons.bookmark : Icons.bookmark_border,
              onTap: () async {
                final error = await ref
                    .read(learningTopicsProvider.notifier)
                    .favorite(topic.id);
                if (mounted && error != null) {
                  AppToast.showError(context, error);
                }
              },
            ),
          ],
        ),
        Expanded(
          child: ListView(
            children: [
              AppCard(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppImage(
                      src: topic.cover,
                      width: 155,
                      height: 208,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 28),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(topic.title, style: AppText.title24),
                          const SizedBox(height: 12),
                          Text(topic.intro, style: AppText.body16),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final tag in topic.tags) AppTag(label: tag),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '${topic.author} 整理 · ${topic.resources.length} 份阅读资料',
                            style: AppText.body13,
                          ),
                          const SizedBox(height: 16),
                          AppButton(
                            label: '开始阅读',
                            icon: Icons.auto_stories_outlined,
                            onTap: topic.resources.isEmpty
                                ? null
                                : () => openReadingResource(
                                    context,
                                    topic.resources.first,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AppCard(
                title: '阅读资料',
                subtitle: '按需选择，PDF 与图片书籍均可阅读',
                child: Column(
                  children: [
                    for (final resource in topic.resources)
                      ReadingResourceTile(resource: resource),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                title: '读完，动笔试一试',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.exercise.isEmpty
                          ? '选择一份自己的作品，用今天的知识点完成一次局部改画。'
                          : topic.exercise,
                      style: AppText.body14,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '完成一次局部练习，附上调整说明，再通过任课老师的点评检查是否改善。',
                      style: AppText.body13.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (ref.watch(shellControllerProvider).user.role ==
                        'student')
                      AppButton(
                        label: '开始专题练习',
                        icon: Icons.draw_outlined,
                        onTap: () => showArtworkPractice(
                          context,
                          subject: topic.subject,
                          title: topic.title,
                          instruction: topic.exercise.isEmpty
                              ? topic.intro
                              : topic.exercise,
                          sourceLabel: '小课件 · ${topic.title}',
                          sourceId: topic.id,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
