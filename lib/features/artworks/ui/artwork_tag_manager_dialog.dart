import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/art/art_tokens.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/art_widgets.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../data/artwork_models.dart';
import '../data/artwork_rules.dart';
import '../state/artwork_tags_controller.dart';
import 'widgets/artwork_widgets.dart';

/// 「点评标签」管理弹窗：老师私有的常用点评标签。
Future<void> showArtworkTagManager(BuildContext context) {
  return showScaledDialog<void>(
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
  String _color = ArtColors.tagPalette.keys.first;
  bool _saving = false;
  String? _deletingId;

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
      _color = ArtColors.tagPalette.keys.first;
      _editing = true;
    });
  }

  void _startEdit(ArtworkTag tag) {
    _name.text = tag.name;
    _explanation.text = tag.explanation;
    final color = tag.color.toUpperCase();
    setState(() {
      _target = tag;
      _color = ArtColors.tagPalette.containsKey(color)
          ? color
          : ArtColors.tagPalette.keys.first;
      _editing = true;
    });
  }

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
    final confirmed = await showConfirmDialog(
      context: context,
      title: '删除标签',
      content: '确定删除「${tag.name}」吗？已经使用这个标签的点评不受影响。',
      confirmLabel: '删除',
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _deletingId = tag.id);
    final message = await ref
        .read(artworkTagsControllerProvider.notifier)
        .delete(tag.id);
    if (!mounted) {
      return;
    }
    setState(() => _deletingId = null);
    if (message != null) {
      AppToast.showError(context, message);
    } else {
      AppToast.showSuccess(context, '标签已删除');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(artworkTagsControllerProvider);
    final tags = state.tags;
    final maxHeight = math.min(MediaQuery.sizeOf(context).height * 0.86, 680.0);
    final title = !_editing ? '点评标签' : (_target == null ? '新建标签' : '编辑标签');
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ArtworkDialogHeader(
              title: title,
              subtitle: _editing
                  ? '标签仅自己可见，点评时一键选用，学生会看到标签与解释'
                  : '${tags.length}/${ArtworkRules.tagLimit} 个 · 仅自己可见',
              onClose: () => Navigator.of(context).maybePop(),
            ),
            Flexible(child: _editing ? _buildForm() : _buildList(state)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              child: _editing
                  ? Row(
                      children: [
                        Expanded(
                          child: ArtButton(
                            label: '取消',
                            primary: false,
                            height: 42,
                            onTap: _saving
                                ? null
                                : () => setState(() => _editing = false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ArtButton(
                            label: '保存',
                            height: 42,
                            loading: _saving,
                            onTap: () => _submit(tags),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: ArtButton(
                        label: '新建标签',
                        icon: Icons.add_rounded,
                        height: 42,
                        onTap: tags.length >= ArtworkRules.tagLimit
                            ? null
                            : _startCreate,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(ArtworkTagsState state) {
    if (state.loading && state.tags.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(heightFactor: 1, child: AppLoadingIndicator(size: 36)),
      );
    }
    if (state.tags.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sell_outlined,
              size: 32,
              color: ArtColors.brandSoft,
            ),
            const SizedBox(height: 10),
            Text(
              '还没有点评标签\n把常见问题做成标签，点评时一键选用',
              textAlign: TextAlign.center,
              style: ArtText.body(size: 13, color: ArtColors.ink3),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      itemCount: state.tags.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: ArtColors.line),
      itemBuilder: (context, index) {
        final tag = state.tags[index];
        return _TagRow(
          tag: tag,
          deleting: _deletingId == tag.id,
          onEdit: () => _startEdit(tag),
          onDelete: () => _delete(tag),
        );
      },
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('标签名称', style: ArtText.body(weight: AppFont.w500)),
          const SizedBox(height: 8),
          AppTextField(
            controller: _name,
            maxLength: ArtworkRules.tagNameLimit,
            style: ArtText.body(),
            onChanged: (_) => setState(() {}),
            decoration: artworkInputDecoration(hint: '例如：结构错误'),
          ),
          const SizedBox(height: 16),
          Text('标签解释', style: ArtText.body(weight: AppFont.w500)),
          const SizedBox(height: 8),
          AppTextField(
            controller: _explanation,
            maxLength: ArtworkRules.tagExplanationLimit,
            minLines: 3,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            style: ArtText.body(),
            decoration: artworkInputDecoration(
              hint: '说明问题表现和改进方法，学生查看点评时可以看到',
              showCounter: true,
            ),
          ),
          const SizedBox(height: 16),
          Text('颜色', style: ArtText.body(weight: AppFont.w500)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              for (final entry in ArtColors.tagPalette.entries)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _color = entry.key),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: entry.value,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color == entry.key
                            ? ArtColors.ink
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: _color == entry.key
                        ? const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('预览', style: ArtText.caption()),
              const SizedBox(width: 10),
              Flexible(
                child: ArtworkTagChip(
                  name: _name.text.trim().isEmpty ? '标签名称' : _name.text.trim(),
                  color: _color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({
    required this.tag,
    required this.deleting,
    required this.onEdit,
    required this.onDelete,
  });

  final ArtworkTag tag;
  final bool deleting;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: ArtColors.fromHex(tag.color),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        tag.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ArtText.body(weight: AppFont.w500),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '使用 ${tag.usageCount} 次',
                      style: ArtText.caption(size: 11),
                    ),
                  ],
                ),
                if (tag.explanation.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    tag.explanation,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ArtText.caption(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          ArtworkIconAction(
            icon: Icons.edit_outlined,
            tooltip: '编辑',
            onTap: deleting ? null : onEdit,
          ),
          const SizedBox(width: 6),
          ArtworkIconAction(
            icon: Icons.delete_outline_rounded,
            tooltip: '删除',
            color: ArtColors.danger,
            onTap: deleting ? null : onDelete,
          ),
        ],
      ),
    );
  }
}
