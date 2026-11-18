import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../courseware/ui/courseware_file_picker.dart';
import '../data/creative_models.dart';
import '../state/creative_controllers.dart';
import 'creative_widgets.dart';
import 'topics/topic_resource_picker.dart';

/// 表单一栏的宽度：标签在上、输入框在下，读起来不用左右扫。
const _formWidth = 640.0;

/// 新增课件：单栏表单，「课件内容」和「阅读资料」两组，发布在页头右侧。
class LearningTopicEditor extends ConsumerStatefulWidget {
  const LearningTopicEditor({required this.onClose, super.key});
  final VoidCallback onClose;
  @override
  ConsumerState<LearningTopicEditor> createState() =>
      _LearningTopicEditorState();
}

class _LearningTopicEditorState extends ConsumerState<LearningTopicEditor> {
  final _title = TextEditingController(),
      _intro = TextEditingController(),
      _tags = TextEditingController(),
      _exercise = TextEditingController(),
      _minutes = TextEditingController(text: '10');
  String _subject = '素描', _level = '基础', _error = '';
  final List<ReadingResource> _selected = [];
  bool _uploading = false;

  /// 点过一次发布之后，字段边改边检查。
  bool _checked = false;

  @override
  void dispose() {
    for (final c in [_title, _intro, _tags, _exercise, _minutes]) {
      c.dispose();
    }
    super.dispose();
  }

  /// 和发布接口同样的规则，先在字段旁边说清楚哪里要改。
  Map<String, String> get _problems {
    int length(TextEditingController c) => c.text.trim().runes.length;
    final minutes = int.tryParse(_minutes.text.trim()) ?? 0;
    return {
      if (length(_title) < 2 || length(_title) > 40)
        'title': '课件名称须为 2 至 40 个字',
      if (length(_intro) < 10 || length(_intro) > 600)
        'intro': '学习说明须为 10 至 600 个字',
      if (minutes < 1 || minutes > 120) 'minutes': '建议时长须为 1 至 120 分钟',
      if (_selected.isEmpty) 'resources': '请至少选择 1 份阅读资料',
    };
  }

  bool get _dirty =>
      [_title, _intro, _tags, _exercise].any((c) => c.text.trim().isNotEmpty) ||
      _minutes.text.trim() != '10' ||
      _selected.isNotEmpty ||
      _subject != '素描' ||
      _level != '基础';

  Future<void> _leave() async {
    if (ref.read(learningTopicsProvider).busy) return;
    if (_dirty &&
        !await showAppConfirm(
          context: context,
          title: '放弃这份课件？',
          message: '填写的内容和选好的资料不会保存。',
          confirmLabel: '放弃',
          cancelLabel: '继续编辑',
          danger: true,
        )) {
      return;
    }
    if (mounted) widget.onClose();
  }

  void _toggle(ReadingResource resource) {
    final index = _selected.indexWhere((r) => r.id == resource.id);
    if (index < 0 && _selected.length >= topicResourceLimit) {
      AppToast.showInfo(context, '一份课件最多 $topicResourceLimit 份资料');
      return;
    }
    setState(() {
      if (index >= 0) {
        _selected.removeAt(index);
      } else {
        _selected.add(resource);
      }
    });
  }

  Future<void> _upload() async {
    setState(() {
      _uploading = true;
      _error = '';
    });
    try {
      final files = await pickCoursewareFiles(allowMultiple: true);
      final uploaded = <ReadingResource>[];
      for (final file in files.take(24)) {
        if (_selected.length >= topicResourceLimit) break;
        final resource = await ref
            .read(creativeUploadProvider.notifier)
            .upload(name: file.name, bytes: file.bytes, path: file.path);
        if (!mounted) return;
        uploaded.add(resource);
      }
      final images = uploaded.where((item) => !item.isPdf).toList();
      final combined = images.length > 1
          ? await ref
                .read(creativeUploadProvider.notifier)
                .imageBook(images.map((item) => item.id).toList())
          : images.firstOrNull;
      if (!mounted) return;
      setState(
        () => _selected.addAll(
          [
            for (final item in uploaded)
              if (item.isPdf) item,
            ?combined,
          ].take(topicResourceLimit - _selected.length),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error'.replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _checked = true;
      _error = '';
    });
    if (_problems.isNotEmpty) return;
    final error = await ref.read(learningTopicsProvider.notifier).publish({
      'title': _title.text.trim(),
      'intro': _intro.text.trim(),
      'subject': _subject,
      'level': _level,
      'minutes': int.tryParse(_minutes.text.trim()) ?? 0,
      'tags': _tags.text
          .split(RegExp('[,，、]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      'exercise': _exercise.text.trim(),
      'resourceIds': _selected.map((r) => r.id).toList(),
    });
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
    } else {
      AppToast.showSuccess(context, '课件已发布');
      widget.onClose();
    }
  }

  void _recheck(String _) {
    if (_checked) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(creativeUploadProvider);
    final busy = ref.watch(
      learningTopicsProvider.select((state) => state.busy),
    );
    final problems = _checked ? _problems : const <String, String>{};
    final notice = _error.isNotEmpty
        ? _error
        : problems.isNotEmpty
        ? '还有 ${problems.length} 处需要填写，已在下方标出'
        : '';
    // 页头不随表单滚动：资料在表单最下面，选完不用再滚回去找「发布课件」。
    return AppPageBody(
      scrollable: false,
      builder: (context, wide) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTitleBar(
            title: '新增课件',
            onBack: _leave,
            actions: [
              AppButton(
                label: '发布课件',
                loading: busy,
                onTap: busy || _uploading ? null : _save,
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: AppPageBody.bottom),
              child: _form(problems, notice, busy),
            ),
          ),
        ],
      ),
    );
  }

  Widget _form(Map<String, String> problems, String notice, bool busy) => Align(
    alignment: Alignment.topLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _formWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (notice.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s16),
            AppNotice(message: notice, tone: AppTone.danger),
          ],
          const SizedBox(height: AppSpace.s24),
          const AppSectionTitle(title: '课件内容'),
          const SizedBox(height: AppSpace.s16),
          ..._fields(problems),
          const SizedBox(height: AppSpace.s32),
          TopicResourcePicker(
            selected: _selected,
            uploading: _uploading,
            enabled: !busy,
            errorText: problems['resources'],
            onToggle: _toggle,
            onUpload: _upload,
          ),
        ],
      ),
    ),
  );

  List<Widget> _fields(Map<String, String> problems) => [
    AppInputField(
      controller: _title,
      label: '课件名称',
      hint: '例如：把明暗交界线画进体积里',
      required: true,
      maxLength: 40,
      errorText: problems['title'],
      onChanged: _recheck,
    ),
    const SizedBox(height: AppSpace.s16),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Labeled(
            label: '科目',
            required: true,
            child: CreativeSubjectSelect(
              value: _subject,
              onChanged: (value) => setState(() => _subject = value),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.s16),
        Expanded(
          child: _Labeled(
            label: '难度',
            required: true,
            child: AppSelect<String>(
              value: _level,
              options: const [
                AppSelectOption(value: '基础', label: '基础'),
                AppSelectOption(value: '进阶', label: '进阶'),
              ],
              onChanged: (value) => setState(() => _level = value),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.s16),
        Expanded(
          child: AppInputField(
            controller: _minutes,
            label: '建议时长（分钟）',
            required: true,
            keyboardType: TextInputType.number,
            errorText: problems['minutes'],
            onChanged: _recheck,
          ),
        ),
      ],
    ),
    const SizedBox(height: AppSpace.s16),
    AppInputField(
      controller: _intro,
      label: '学习说明',
      hint: '这份课件解决什么问题？读完可以尝试什么？',
      required: true,
      multiline: true,
      maxLength: 600,
      errorText: problems['intro'],
      onChanged: _recheck,
    ),
    const SizedBox(height: AppSpace.s16),
    AppInputField(
      controller: _tags,
      label: '知识点',
      hint: '用逗号分隔，如：明暗、体积、反光',
      maxLength: 80,
    ),
    const SizedBox(height: AppSpace.s16),
    AppInputField(
      controller: _exercise,
      label: '练习建议',
      hint: '读完怎么练，例如：选一张自己的作品做一次局部改画',
      multiline: true,
      minLines: 2,
      maxLines: 4,
      maxLength: 300,
    ),
  ];
}

/// 下拉框上面的字段名，和 `AppInputField` 的标签同一种写法。
class _Labeled extends StatelessWidget {
  const _Labeled({
    required this.label,
    required this.child,
    this.required = false,
  });
  final String label;
  final Widget child;
  final bool required;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text.rich(
        TextSpan(
          children: [
            if (required)
              TextSpan(
                text: '* ',
                style: AppText.body14.copyWith(color: AppColors.danger),
              ),
            TextSpan(text: label, style: AppText.body14),
          ],
        ),
      ),
      const SizedBox(height: 6),
      child,
    ],
  );
}
