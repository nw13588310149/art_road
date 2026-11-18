import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/creative_controllers.dart';
import 'learning_topic_editor.dart';
import 'topics/topic_detail.dart';
import 'topics/topic_list.dart';

/// 优秀课件（`/micro-lessons`）：列表、详情和新增在同一个页面里切换。
///
/// 路由参数 `subject`、`keyword` 预先筛好列表（学情的「找学习资料」带着它们进来），
/// `topicId` 直接打开那一份课件。
class LearningTopicsPage extends ConsumerStatefulWidget {
  const LearningTopicsPage({super.key});
  @override
  ConsumerState<LearningTopicsPage> createState() => _LearningTopicsPageState();
}

class _LearningTopicsPageState extends ConsumerState<LearningTopicsPage> {
  String? _selected;
  bool _creating = false;
  bool _readArguments = false;
  bool _linked = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_readArguments) return;
    _readArguments = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _linked = args['subject'] != null || args['keyword'] != null;
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
    final items = ref.watch(learningTopicsProvider.select((s) => s.items));
    final topic = items.where((row) => row.id == _selected).firstOrNull;
    if (_creating) {
      return LearningTopicEditor(
        onClose: () => setState(() => _creating = false),
      );
    }
    if (topic != null) {
      return TopicDetail(
        key: ValueKey(topic.id),
        topic: topic,
        onBack: () => setState(() => _selected = null),
        onOpen: (next) => setState(() => _selected = next.id),
      );
    }
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return TopicList(
      onOpen: (row) => setState(() => _selected = row.id),
      onCreate: () => setState(() => _creating = true),
      onBack: _linked && canPop ? () => Navigator.maybePop(context) : null,
    );
  }
}
