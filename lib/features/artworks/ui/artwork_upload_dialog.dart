import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../../core/widgets/app_date_time_pickers.dart';
import '../data/artwork_models.dart';
import '../data/artwork_rules.dart';
import '../state/student_artworks_controller.dart';

/// 学生上传作品弹窗；提交成功返回 true。
Future<bool?> showArtworkUploadDialog(BuildContext context) {
  return showAppDialog<bool>(
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
      final discard = await showAppConfirm(
        context: context,
        title: '放弃上传？',
        message: '已选择的照片和填写的内容不会保存。',
        confirmLabel: '放弃',
        cancelLabel: '继续编辑',
        danger: true,
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _close();
        }
      },
      child: AppDialog(
        title: '上传作品',
        message: '老师会逐一点评，全部老师点评完成后可查看分数与评语',
        width: AppSize.dialogWide,
        actions: [
          AppButton(
            label: '取消',
            variant: AppButtonVariant.secondary,
            onTap: _submitting ? null : _close,
          ),
          AppButton(
            label: _submitting ? '提交中' : '提交作品',
            loading: _submitting,
            onTap: _submit,
          ),
        ],
        child: _buildForm(),
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
          spacing: AppSpace.s12,
          runSpacing: AppSpace.s12,
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
        const SizedBox(height: AppSpace.s20),
        AppInputField(
          controller: _title,
          label: '作品名称',
          required: true,
          hint: '例如：石膏头像结构练习',
          enabled: enabled,
          maxLength: ArtworkRules.titleLimit,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpace.s20),
        const _FieldLabel(label: '科目'),
        AppSegmented<String>(
          segments: [
            for (final subject in _subjects)
              AppSegment(value: subject, label: subject),
          ],
          value: _subject,
          enabled: enabled,
          onChanged: (subject) => setState(() => _subject = subject),
        ),
        if (_subject == _otherSubject) ...[
          const SizedBox(height: AppSpace.s12),
          AppInputField(
            controller: _customSubject,
            hint: '填写科目，如：设计、创作、书法',
            enabled: enabled,
            maxLength: ArtworkRules.subjectLimit,
          ),
        ],
        const SizedBox(height: AppSpace.s20),
        const _FieldLabel(label: '绘画日期'),
        _DateField(date: _date, onTap: enabled ? _pickDate : null),
        const SizedBox(height: AppSpace.s20),
        AppInputField(
          controller: _description,
          label: '作品说明（选填）',
          hint: '记录这张画的练习重点或遇到的困难，方便老师有针对性地点评',
          enabled: enabled,
          multiline: true,
          minLines: 3,
          maxLines: 5,
          maxLength: ArtworkRules.descriptionLimit,
        ),
        if (_submitting) ...[
          const SizedBox(height: AppSpace.s16),
          AppProgressBar(value: _progress, height: 6),
          const SizedBox(height: AppSpace.s4),
          Text(_progressText, style: AppText.caption12),
        ],
      ],
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(label, style: AppText.body14),
          if (hint.isNotEmpty) ...[
            const SizedBox(width: AppSpace.s8),
            Expanded(
              child: Text(
                hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption12,
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
    final remove = onRemove;
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: AppRadius.br8,
              child: Image.memory(
                image.bytes,
                fit: BoxFit.cover,
                cacheWidth: 240,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: AppColors.surfaceSubtle,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textPlaceholder,
                  ),
                ),
              ),
            ),
          ),
          if (remove != null)
            Positioned(
              top: AppSpace.s4,
              right: AppSpace.s4,
              child: AppPressable(
                onTap: remove,
                semanticLabel: '移除这张照片',
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.56),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: AppColors.onBrand,
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
    return AppPressable(
      onTap: loading ? null : onTap,
      enabled: onTap != null,
      semanticLabel: '添加照片',
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: AppColors.brandWash,
          borderRadius: AppRadius.br8,
          border: Border.all(color: AppColors.brandTint),
        ),
        child: loading
            ? const Center(child: AppLoadingIndicator(size: 24))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 24,
                    color: AppColors.brand,
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    '添加照片',
                    style: AppText.caption12.copyWith(
                      color: AppColors.brandDeep,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// 日期字段：整行可点，外观与下拉选择一致，右侧日历图标。
class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      enabled: onTap != null,
      semanticLabel: '选择绘画日期',
      child: Container(
        height: AppSize.control,
        padding: const EdgeInsets.only(
          left: AppSpace.s12,
          right: AppSpace.s8,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.br8,
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                ArtworkRules.ymd(date),
                style: AppText.number(size: 14),
              ),
            ),
            const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
