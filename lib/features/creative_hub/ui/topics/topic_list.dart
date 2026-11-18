import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../../shell/state/shell_controller.dart';
import '../../data/creative_models.dart';
import '../../state/creative_controllers.dart';
import '../creative_widgets.dart';
import 'topic_row.dart';

/// 优秀课件的入口屏：页头（名称、视图、搜索、新增），科目筛选，一行一份课件。
class TopicList extends ConsumerStatefulWidget {
  const TopicList({
    required this.onOpen,
    required this.onCreate,
    this.onBack,
    super.key,
  });
  final ValueChanged<LearningTopic> onOpen;
  final VoidCallback onCreate;

  /// 从别的页面带着科目、知识点进来时才有。
  final VoidCallback? onBack;

  @override
  ConsumerState<TopicList> createState() => _TopicListState();
}

class _TopicListState extends ConsumerState<TopicList> {
  late final _search = TextEditingController(
    text: ref.read(learningTopicsProvider).keyword,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _favorite(LearningTopic topic) async {
    final error = await ref
        .read(learningTopicsProvider.notifier)
        .favorite(topic.id);
    if (mounted && error != null) AppToast.showError(context, error);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(learningTopicsProvider.select((state) => state.keyword), (
      _,
      keyword,
    ) {
      if (_search.text != keyword) _search.text = keyword;
    });
    final state = ref.watch(learningTopicsProvider);
    final controller = ref.read(learningTopicsProvider.notifier);
    final student =
        ref.watch(shellControllerProvider.select((shell) => shell.user.role)) ==
        'student';
    return AppPageBody(
      builder: (context, wide) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTitleBar(
            title: '优秀课件',
            onBack: widget.onBack,
            tabs: AppViewTabs<String>(
              items: const [
                AppViewTab(value: 'all', label: '全部课件'),
                AppViewTab(value: 'saved', label: '我的收藏'),
                AppViewTab(value: 'mine', label: '我的发布'),
              ],
              value: state.view,
              onChanged: (view) => controller.filter(view: view),
            ),
            actions: [
              SizedBox(
                width: wide ? 260 : 220,
                child: AppSearchField(
                  controller: _search,
                  hint: '搜索课件、知识点',
                  onChanged: (keyword) => controller.filter(keyword: keyword),
                ),
              ),
              const SizedBox(width: AppSpace.s8),
              if (student)
                AppPlainButton(
                  label: '新增课件',
                  icon: Icons.add_rounded,
                  onTap: widget.onCreate,
                )
              else
                AppButton(
                  label: '新增课件',
                  icon: Icons.add_rounded,
                  onTap: widget.onCreate,
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          AppFilterBar<String>(
            items: [
              const AppFilterItem(value: '', label: '全部'),
              for (final subject in creativeSubjects)
                AppFilterItem(
                  value: subject,
                  label: topicSubjectLabel(subject),
                ),
            ],
            value: state.subject,
            onChanged: (subject) => controller.filter(subject: subject),
          ),
          const SizedBox(height: AppSpace.s16),
          _body(state, controller),
        ],
      ),
    );
  }

  Widget _body(
    CreativeState<LearningTopic> state,
    LearningTopicsController controller,
  ) {
    if (state.loading && state.items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < 6; i++) ...[
            const AppRule(),
            const TopicRowSkeleton(),
          ],
        ],
      );
    }
    if (state.error.isNotEmpty && state.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 48),
        child: AppErrorState(
          title: '课件加载失败',
          description: state.error,
          onRetry: controller.load,
        ),
      );
    }
    final rows = controller.visible;
    if (rows.isEmpty) return _empty(state, controller);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final topic in rows) ...[
          const AppRule(),
          TopicRow(
            topic: topic,
            withSubject: state.subject.isEmpty,
            onTap: () => widget.onOpen(topic),
            onFavorite: () => _favorite(topic),
          ),
        ],
        const AppRule(),
        const SizedBox(height: AppSpace.s16),
        Text('已显示全部 ${rows.length} 份课件', style: AppText.caption12),
      ],
    );
  }

  Widget _empty(
    CreativeState<LearningTopic> state,
    LearningTopicsController controller,
  ) {
    final keyword = state.keyword.trim();
    final inView = state.items.where(
      (topic) =>
          (state.view != 'saved' || topic.favorite) &&
          (state.view != 'mine' || topic.mine),
    );
    final scope = switch (state.view) {
      'saved' => '收藏的课件',
      'mine' => '发布的课件',
      _ => '课件',
    };
    final (title, description, action, onAction) = keyword.isNotEmpty
        ? (
            '没有找到与「$keyword」相关的课件',
            '换一个知识点或绘画技巧再搜。',
            '清除搜索',
            () => controller.filter(keyword: ''),
          )
        : state.subject.isNotEmpty && inView.isNotEmpty
        ? (
            '${topicSubjectLabel(state.subject)}还没有$scope',
            '换个科目看看。',
            '查看全部科目',
            () => controller.filter(subject: ''),
          )
        : state.view == 'saved'
        ? (
            '还没有收藏的课件',
            '在课件右侧点书签收藏，之后在这里就能找到。',
            '去看全部课件',
            () => controller.filter(view: 'all', subject: ''),
          )
        : state.view == 'mine'
        ? ('还没有发布过课件', '把一个知识点整理成几页资料，发布后会出现在这里。', '新增课件', widget.onCreate)
        : ('还没有课件', '老师和同学发布的课件会出现在这里。', null, null);
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: AppEmptyState(
        title: title,
        description: description,
        actionLabel: action,
        onAction: onAction,
      ),
    );
  }
}
