import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../courseware/ui/courseware_file_picker.dart';
import '../data/creative_models.dart';
import '../state/creative_controllers.dart';
import 'creative_widgets.dart';

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
  @override
  void dispose() {
    for (final c in [_title, _intro, _tags, _exercise, _minutes]) {
      c.dispose();
    }
    super.dispose();
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
        if (_selected.length >= 12) break;
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
          ].take(12 - _selected.length),
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
    final error = await ref.read(learningTopicsProvider.notifier).publish({
      'title': _title.text.trim(),
      'intro': _intro.text.trim(),
      'subject': _subject,
      'level': _level,
      'minutes': int.tryParse(_minutes.text) ?? 0,
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
      AppToast.showSuccess(context, '小课件已发布');
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(creativeUploadProvider);
    final resources = ref.watch(readingResourcesProvider);
    final busy = ref.watch(
      learningTopicsProvider.select((state) => state.busy),
    );
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          CreativeHeading(
            title: '新增小课件',
            subtitle: '把一个知识点，整理成一份可阅读的专题。',
            onBack: busy ? null : widget.onClose,
            actions: [
              AppButton(
                label: '发布小课件',
                loading: busy,
                onTap: busy || _uploading ? null : _save,
              ),
            ],
          ),
          if (_error.isNotEmpty)
            AppNotice(message: _error, tone: AppTone.danger),
          Expanded(
            child: LayoutBuilder(
              builder: (context, size) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 20,
                children: [
                  Expanded(
                    flex: 6,
                    child: ListView(
                      children: [
                        AppCard(
                          title: '专题内容',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: 16,
                            children: [
                              AppInputField(
                                controller: _title,
                                label: '专题名称',
                                hint: '例如：把明暗交界线画进体积里',
                                required: true,
                                maxLength: 40,
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: CreativeSubjectSelect(
                                      value: _subject,
                                      onChanged: (value) =>
                                          setState(() => _subject = value),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: AppSelect<String>(
                                      value: _level,
                                      options: const [
                                        AppSelectOption(
                                          value: '基础',
                                          label: '基础',
                                        ),
                                        AppSelectOption(
                                          value: '进阶',
                                          label: '进阶',
                                        ),
                                      ],
                                      onChanged: (value) =>
                                          setState(() => _level = value),
                                    ),
                                  ),
                                ],
                              ),
                              AppInputField(
                                controller: _intro,
                                label: '学习说明',
                                hint: '这份小课件解决什么问题？读完可以尝试什么？',
                                required: true,
                                multiline: true,
                                maxLength: 600,
                              ),
                              AppInputField(
                                controller: _tags,
                                label: '知识点',
                                hint: '用逗号分隔，如：明暗、体积、反光',
                                maxLength: 80,
                              ),
                              AppInputField(
                                controller: _minutes,
                                label: '建议阅读时长（分钟）',
                                keyboardType: TextInputType.number,
                              ),
                              AppInputField(
                                controller: _exercise,
                                label: '练习建议（可选）',
                                multiline: true,
                                minLines: 2,
                                maxLines: 4,
                                maxLength: 300,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: ListView(
                      children: [
                        AppCard(
                          title: '阅读资料',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: 12,
                            children: [
                              Text(
                                '支持 PDF、JPG、PNG，每份不超过 20 MB',
                                style: AppText.body13,
                              ),
                              AppButton(
                                label: '上传 PDF / 图片',
                                icon: Icons.file_upload_outlined,
                                variant: AppButtonVariant.secondary,
                                loading: _uploading,
                                onTap: _uploading || busy ? null : _upload,
                              ),
                              Text(
                                '已选择 ${_selected.length} / 12 份 · 第一份作为专题封面',
                                style: AppText.caption12,
                              ),
                              for (final resource in _selected)
                                ReadingResourceTile(
                                  resource: resource,
                                  trailing: AppIconButton(
                                    icon: Icons.close,
                                    semanticLabel: '移除${resource.title}',
                                    size: AppButtonSize.sm,
                                    filled: false,
                                    onTap: () => setState(
                                      () => _selected.remove(resource),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppCard(
                          title: '从示例书籍中选择',
                          child: resources.when(
                            loading: () => const AppLoadingIndicator(),
                            error: (error, _) => AppErrorState(
                              title: '资料加载失败',
                              onRetry: () =>
                                  ref.invalidate(readingResourcesProvider),
                            ),
                            data: (items) => Column(
                              children: [
                                for (final resource in items.where(
                                  (item) => !item.id.startsWith('sample-'),
                                ))
                                  ReadingResourceTile(
                                    resource: resource,
                                    trailing: AppCheckbox(
                                      semanticLabel: '选择${resource.title}',
                                      value: _selected.any(
                                        (r) => r.id == resource.id,
                                      ),
                                      onChanged: (checked) => setState(() {
                                        if (checked && _selected.length < 12) {
                                          _selected.add(resource);
                                        } else {
                                          _selected.removeWhere(
                                            (r) => r.id == resource.id,
                                          );
                                        }
                                      }),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
