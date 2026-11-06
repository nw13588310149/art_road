import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/art/art_tokens.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/widgets/app_date_time_pickers.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/art_widgets.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../data/artwork_models.dart';
import '../data/artwork_rules.dart';
import '../state/student_artworks_controller.dart';
import 'widgets/artwork_widgets.dart';

/// 学生上传作品弹窗；提交成功返回 true。
Future<bool?> showArtworkUploadDialog(BuildContext context) {
  return showScaledDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const ArtworkUploadDialog(),
  );
}

class ArtworkUploadDialog extends ConsumerStatefulWidget {
  const ArtworkUploadDialog({super.key});

  @override
  ConsumerState<ArtworkUploadDialog> createState() =>
      _ArtworkUploadDialogState();
}

class _ArtworkUploadDialogState extends ConsumerState<ArtworkUploadDialog> {
  static const _subjects = <String>['素描', '色彩', '速写', '其他'];
  static const _otherSubject = '其他';

  final _images = <ArtworkDraftImage>[];
  final _uploaded = <ArtworkDraftImage, String>{};
  final _title = TextEditingController();
  final _customSubject = TextEditingController();
  final _description = TextEditingController();
  String _subject = _subjects.first;
  DateTime _date = ArtworkRules.dateOnly(DateTime.now());
  bool _picking = false;
  bool _submitting = false;
  double _progress = 0;
  String _progressText = '';

  @override
  void dispose() {
    _title.dispose();
    _customSubject.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _hasInput =>
      _images.isNotEmpty ||
      _title.text.trim().isNotEmpty ||
      _description.text.trim().isNotEmpty;

  String get _resolvedSubject =>
      _subject == _otherSubject ? _customSubject.text.trim() : _subject;

  Future<void> _close() async {
    if (_submitting) {
      return;
    }
    if (_hasInput) {
      final discard = await showConfirmDialog(
        context: context,
        title: '放弃上传？',
        content: '已选择的照片和填写的内容不会保存。',
        confirmLabel: '放弃',
        cancelLabel: '继续编辑',
      );
      if (!discard || !mounted) {
        return;
      }
    }
    Navigator.of(context).pop(false);
  }

  Future<void> _pickImages() async {
    if (_picking || _submitting) {
      return;
    }
    final remaining = ArtworkRules.imageLimit - _images.length;
    if (remaining <= 0) {
      AppToast.showError(context, '每份作品最多 ${ArtworkRules.imageLimit} 张照片');
      return;
    }
    setState(() => _picking = true);
    FilePickerResult? result;
    var failed = false;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
        compressionQuality: 85,
      );
    } catch (_) {
      failed = true;
    }
    if (!mounted) {
      return;
    }
    setState(() => _picking = false);
    if (failed) {
      AppToast.showError(context, '无法打开相册，请稍后重试');
      return;
    }
    if (result == null) {
      return;
    }
    String? problem;
    final picked = <ArtworkDraftImage>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      final error = ArtworkRules.imageError(bytes);
      if (error != null || bytes == null) {
        problem ??= error;
        continue;
      }
      final name = file.name.trim();
      picked.add(
        ArtworkDraftImage(
          bytes: bytes,
          name: name.isEmpty ? 'artwork.jpg' : name,
        ),
      );
    }
    if (picked.length > remaining) {
      problem ??= '每份作品最多 ${ArtworkRules.imageLimit} 张照片，已保留前 $remaining 张';
    }
    setState(() => _images.addAll(picked.take(remaining)));
    if (problem != null) {
      AppToast.showError(context, problem);
    }
  }

  Future<void> _pickDate() async {
    final today = ArtworkRules.dateOnly(DateTime.now());
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _date.isAfter(today) ? today : _date,
      firstDate: DateTime(today.year - 5),
      lastDate: today,
      helpText: '选择绘画日期',
    );
    if (picked != null && mounted) {
      setState(() => _date = ArtworkRules.dateOnly(picked));
    }
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    FocusScope.of(context).unfocus();
    final error = ArtworkRules.validateDraft(
      imageCount: _images.length,
      title: _title.text,
      subject: _resolvedSubject,
      drawingDate: _date,
      description: _description.text,
    );
    if (error != null) {
      AppToast.showError(context, error);
      return;
    }
    final total = _images.length;
    setState(() {
      _submitting = true;
      _progress = 0;
      _progressText = '正在上传第 1/$total 张照片…';
    });
    final message = await ref
        .read(studentArtworksControllerProvider.notifier)
        .submit(
          ArtworkDraft(
            title: _title.text.trim(),
            subject: _resolvedSubject,
            drawingDate: ArtworkRules.ymd(_date),
            description: _description.text.trim(),
            images: List<ArtworkDraftImage>.of(_images),
          ),
          uploaded: _uploaded,
          onProgress: (done, count) {
            if (!mounted) {
              return;
            }
            setState(() {
              _progress = done / (count + 1);
              _progressText = done < count
                  ? '正在上传第 ${done + 1}/$count 张照片…'
                  : '照片已上传，正在提交作品…';
            });
          },
        );
    if (!mounted) {
      return;
    }
    if (message != null) {
      setState(() => _submitting = false);
      AppToast.showError(context, message);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _close();
        }
      },
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 600, maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ArtworkDialogHeader(
                title: '上传作品',
                subtitle: '老师会逐一点评，全部老师点评完成后可查看分数与评语',
                onClose: _submitting ? null : _close,
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: _buildForm(),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final enabled = !_submitting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(
          label: '作品照片',
          hint:
              '${_images.length}/${ArtworkRules.imageLimit} · JPG / PNG，单张不超过 20MB',
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final image in _images)
              _PickedThumb(
                image: image,
                onRemove: enabled
                    ? () => setState(() => _images.remove(image))
                    : null,
              ),
            if (_images.length < ArtworkRules.imageLimit)
              _AddImageTile(
                loading: _picking,
                onTap: enabled ? _pickImages : null,
              ),
          ],
        ),
        const SizedBox(height: 18),
        const _FieldLabel(label: '作品名称'),
        AppTextField(
          controller: _title,
          enabled: enabled,
          maxLength: ArtworkRules.titleLimit,
          textInputAction: TextInputAction.next,
          style: ArtText.body(),
          decoration: artworkInputDecoration(hint: '例如：石膏头像结构练习'),
        ),
        const SizedBox(height: 18),
        const _FieldLabel(label: '科目'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final subject in _subjects)
              _ChoicePill(
                label: subject,
                selected: _subject == subject,
                onTap: enabled
                    ? () => setState(() => _subject = subject)
                    : null,
              ),
          ],
        ),
        if (_subject == _otherSubject) ...[
          const SizedBox(height: 10),
          AppTextField(
            controller: _customSubject,
            enabled: enabled,
            maxLength: ArtworkRules.subjectLimit,
            style: ArtText.body(),
            decoration: artworkInputDecoration(hint: '填写科目，如：设计、创作、书法'),
          ),
        ],
        const SizedBox(height: 18),
        const _FieldLabel(label: '绘画日期'),
        _DateField(date: _date, onTap: enabled ? _pickDate : null),
        const SizedBox(height: 18),
        const _FieldLabel(label: '作品说明', hint: '选填'),
        AppTextField(
          controller: _description,
          enabled: enabled,
          maxLength: ArtworkRules.descriptionLimit,
          minLines: 3,
          maxLines: 6,
          keyboardType: TextInputType.multiline,
          style: ArtText.body(),
          decoration: artworkInputDecoration(
            hint: '记录这张画的练习重点或遇到的困难，方便老师有针对性地点评',
            showCounter: true,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_submitting) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 6,
                color: ArtColors.brand,
                backgroundColor: ArtColors.brandWash,
              ),
            ),
            const SizedBox(height: 6),
            Text(_progressText, style: ArtText.caption()),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: ArtButton(
                  label: '取消',
                  primary: false,
                  height: 42,
                  onTap: _submitting ? null : _close,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ArtButton(
                  label: _submitting ? '提交中' : '提交作品',
                  height: 42,
                  loading: _submitting,
                  onTap: _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.hint = ''});

  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label, style: ArtText.body(weight: AppFont.w500)),
          if (hint.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ArtText.caption(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PickedThumb extends StatelessWidget {
  const _PickedThumb({required this.image, required this.onRemove});

  final ArtworkDraftImage image;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                image.bytes,
                fit: BoxFit.cover,
                cacheWidth: 240,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: ArtColors.subtle,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: ArtColors.ink4,
                  ),
                ),
              ),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddImageTile extends StatelessWidget {
  const _AddImageTile({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: loading ? null : onTap,
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: ArtColors.brandWash,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ArtColors.brandLight),
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ArtColors.brand,
                  ),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 26,
                    color: onTap == null ? ArtColors.ink4 : ArtColors.brand,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '添加照片',
                    style: ArtText.caption(
                      size: 11,
                      color: ArtColors.brandDeep,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? ArtColors.brand : ArtColors.subtle,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? ArtColors.brand : ArtColors.line,
          ),
        ),
        child: Text(
          label,
          style: ArtText.body(
            size: 13,
            color: selected ? Colors.white : ArtColors.ink2,
            weight: selected ? AppFont.w500 : AppFont.w400,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: ArtColors.subtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ArtColors.line),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 17,
              color: ArtColors.ink3,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(ArtworkRules.ymd(date), style: ArtText.body()),
            ),
            Text('修改', style: ArtText.caption(color: ArtColors.brandDeep)),
          ],
        ),
      ),
    );
  }
}
