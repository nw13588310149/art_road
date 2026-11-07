import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../data/artwork_models.dart';
import '../data/artwork_rules.dart';
import '../state/artwork_tags_controller.dart';
import 'widgets/artwork_widgets.dart';

/// 「点评标签」管理弹窗：老师私有的常用点评标签，分「问题」「亮点」两类。
Future<void> showArtworkTagManager(BuildContext context) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => const ArtworkTagManagerDialog(),
  );
}

class ArtworkTagManagerDialog extends ConsumerStatefulWidget {
  const ArtworkTagManagerDialog({super.key});

  @override
  ConsumerState<ArtworkTagManagerDialog> createState() =>
      _ArtworkTagManagerDialogState();
}

class _ArtworkTagManagerDialogState
    extends ConsumerState<ArtworkTagManagerDialog> {
  final _name = TextEditingController();
  final _explanation = TextEditingController();
  bool _editing = false;
  ArtworkTag? _target;
  bool _highlight = false;
  bool _saving = false;
  bool _deleting = false;

  @override
  void dispose() {
    _name.dispose();
    _explanation.dispose();
    super.dispose();
  }

  void _startCreate() {
    _name.clear();
    _explanation.clear();
    setState(() {
      _target = null;
      _highlight = false;
      _editing = true;
    });
  }

  void _startEdit(ArtworkTag tag) {
    _name.text = tag.name;
    _explanation.text = tag.explanation;
    setState(() {
      _target = tag;
      _highlight = ArtworkRules.isHighlightTag(tag.color);
      _editing = true;
    });
  }

  String get _color => _highlight
      ? ArtworkRules.highlightTagColor
      : ArtworkRules.problemTagColor;

  Future<void> _submit(List<ArtworkTag> tags) async {
    if (_saving) {
      return;
    }
    final target = _target;
    if (target == null && tags.length >= ArtworkRules.tagLimit) {
      AppToast.showError(context, '最多可以创建 ${ArtworkRules.tagLimit} 个标签');
      return;
    }
    final error = ArtworkRules.validateTag(
      name: _name.text,
      explanation: _explanation.text,
      color: _color,
      otherNames: tags.where((t) => t.id != target?.id).map((t) => t.name),
    );
    if (error != null) {
      AppToast.showError(context, error);
      return;
    }
    setState(() => _saving = true);
    final controller = ref.read(artworkTagsControllerProvider.notifier);
    final message = target == null
        ? await controller.create(
            name: _name.text,
            explanation: _explanation.text,
            color: _color,
          )
        : await controller.update(
            target.id,
            name: _name.text,
            explanation: _explanation.text,
            color: _color,
          );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (message != null) {
      AppToast.showError(context, message);
      return;
    }
    AppToast.showSuccess(context, target == null ? '标签已创建' : '标签已更新');
    setState(() => _editing = false);
  }

  Future<void> _delete(ArtworkTag tag) async {
    final confirmed = await showAppConfirm(
      context: context,
      title: '删除标签',
      message: '确定删除「${tag.name}」吗？已经使用这个标签的点评不受影响。',
      confirmLabel: '删除',
      danger: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _deleting = true);
    final message = await ref
        .read(artworkTagsControllerProvider.notifier)
        .delete(tag.id);
    if (!mounted) {
      return;
    }
    setState(() => _deleting = false);
    if (message != null) {
      AppToast.showError(context, message);
      return;
    }
    AppToast.showSuccess(context, '标签已删除');
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(artworkTagsControllerProvider);
    final tags = state.tags;
    if (_editing) {
      final target = _target;
      return AppDialog(
        title: target == null ? '新建标签' : '编辑标签',
        message: '标签仅自己可见，点评时一键选用；学生会看到标签与解释',
        width: AppSize.dialogWide,
        actions: [
          AppButton(
            label: '取消',
            variant: AppButtonVariant.secondary,
            onTap: _saving || _deleting
                ? null
                : () => setState(() => _editing = false),
          ),
          AppButton(
            label: '保存',
            loading: _saving,
            onTap: _deleting ? null : () => _submit(tags),
          ),
        ],
        child: _buildForm(target),
      );
    }
    return AppDialog(
      title: '点评标签',
      message: '共 ${tags.length} 个，最多 ${ArtworkRules.tagLimit} 个 · 仅自己可见',
      width: AppSize.dialogWide,
      showClose: true,
      fillActions: false,
      actions: [
        AppButton(
          label: '新建标签',
          icon: Icons.add_rounded,
          size: AppButtonSize.sm,
          onTap: tags.length >= ArtworkRules.tagLimit ? null : _startCreate,
        ),
      ],
      child: _buildList(state),
    );
  }

  Widget _buildList(ArtworkTagsState state) {
    if (state.loading && state.tags.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: AppLoadingIndicator(size: 36)),
      );
    }
    if (state.tags.isEmpty) {
      return const SizedBox(
        height: 200,
        child: AppEmptyState(
          icon: Icons.sell_outlined,
          title: '还没有点评标签',
          description: '把常见问题和亮点做成标签，点评时一键选用',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < state.tags.length; i++)
          _TagRow(
            tag: state.tags[i],
            divider: i < state.tags.length - 1,
            onTap: () => _startEdit(state.tags[i]),
          ),
      ],
    );
  }

  Widget _buildForm(ArtworkTag? target) {
    final name = _name.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppInputField(
          controller: _name,
          label: '标签名称',
          required: true,
          hint: '例如：结构错误',
          maxLength: ArtworkRules.tagNameLimit,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpace.s16),
        Text('标签类型', style: AppText.body14),
        const SizedBox(height: 6),
        AppSegmented<bool>(
          segments: const [
            AppSegment(value: false, label: '问题'),
            AppSegment(value: true, label: '亮点'),
          ],
          value: _highlight,
          onChanged: (value) => setState(() => _highlight = value),
        ),
        const SizedBox(height: AppSpace.s16),
        AppInputField(
          controller: _explanation,
          label: '标签解释',
          hint: '说明问题表现和改进方法，学生查看点评时可以看到',
          multiline: true,
          minLines: 3,
          maxLines: 5,
          maxLength: ArtworkRules.tagExplanationLimit,
        ),
        const SizedBox(height: AppSpace.s16),
        Row(
          children: [
            Text('预览', style: AppText.caption12),
            const SizedBox(width: AppSpace.s12),
            ArtworkReviewTag(name: name.isEmpty ? '标签名称' : name, color: _color),
            const Spacer(),
            if (target != null)
              AppButton(
                label: '删除标签',
                icon: Icons.delete_outline_rounded,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                loading: _deleting,
                onTap: _saving ? null : () => _delete(target),
              ),
          ],
        ),
      ],
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({
    required this.tag,
    required this.divider,
    required this.onTap,
  });

  final ArtworkTag tag;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlight = ArtworkRules.isHighlightTag(tag.color);
    return AppPressable(
      onTap: onTap,
      semanticLabel: '编辑标签${tag.name}',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
        decoration: BoxDecoration(
          border: divider
              ? const Border(bottom: BorderSide(color: AppColors.lineSoft))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpace.s8,
                    runSpacing: AppSpace.s4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(tag.name, style: AppText.body14Strong),
                      AppTag(
                        label: highlight ? '亮点' : '问题',
                        tone: highlight ? AppTone.success : AppTone.warning,
                      ),
                      Text('使用 ${tag.usageCount} 次', style: AppText.caption12),
                    ],
                  ),
                  if (tag.explanation.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.s4),
                    Text(
                      tag.explanation,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body13,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.edit_outlined,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
