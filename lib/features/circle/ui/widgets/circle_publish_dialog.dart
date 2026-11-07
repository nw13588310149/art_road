import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../../courseware/state/cloud_drive_controller.dart';
import '../../../courseware/ui/courseware_file_picker.dart';
import '../../state/circle_controller.dart';
import '../../state/circle_state.dart';
import '../../util/video_cover_frame_extractor.dart';

/// 可发布的动态类型；历史音频帖仍可浏览，但不再提供音频发布。
const _publishKinds = <PostMediaKind>[PostMediaKind.image, PostMediaKind.video];

String _kindLabelOf(PostMediaKind kind) {
  switch (kind) {
    case PostMediaKind.image:
      return '图片';
    case PostMediaKind.video:
      return '视频';
    case PostMediaKind.audio:
      return '音频';
  }
}

IconData _kindIconOf(PostMediaKind kind) {
  switch (kind) {
    case PostMediaKind.image:
      return Icons.image_outlined;
    case PostMediaKind.video:
      return Icons.videocam_outlined;
    case PostMediaKind.audio:
      return Icons.graphic_eq_rounded;
  }
}

/// 弹出「发布动态」对话框。返回 `true` 表示发布成功；其它情况返回 false /
/// null（用户主动取消）。
Future<bool?> showCirclePublishDialog(BuildContext context) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _CirclePublishDialog(),
  );
}

class _CirclePublishDialog extends ConsumerStatefulWidget {
  const _CirclePublishDialog();

  @override
  ConsumerState<_CirclePublishDialog> createState() =>
      _CirclePublishDialogState();
}

class _CirclePublishDialogState extends ConsumerState<_CirclePublishDialog> {
  PostMediaKind _kind = PostMediaKind.image;
  final TextEditingController _textCtrl = TextEditingController();

  String? _fileName;
  Uint8List? _fileBytes;
  String? _filePath;
  int? _fileSize;

  /// 上传后端 OSS 后返回的可保存 path；null 表示尚未上传 / 上传中。
  String? _uploadedPath;
  double _uploadProgress = 0;
  bool _uploading = false;
  String? _uploadError;
  bool _submitting = false;

  // ─── 视频帖可选的封面图（图片帖直接复用主资源当封面，不展示这块）。
  String? _coverFileName;
  Uint8List? _coverFileBytes;
  String? _coverFilePath;
  int? _coverFileSize;
  String? _coverUploadedPath;
  double _coverUploadProgress = 0;
  bool _coverUploading = false;
  String? _coverUploadError;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  bool get _hasText => _textCtrl.text.trim().isNotEmpty;
  bool get _hasUploaded => _uploadedPath != null && _uploadedPath!.isNotEmpty;

  bool get _needsCover =>
      _kind == PostMediaKind.video || _kind == PostMediaKind.audio;

  /// 正文必填、主资源上传完成才能发布；封面可选，但封面上传中不能发布。
  bool get _canSubmit =>
      _hasText &&
      _hasUploaded &&
      !_uploading &&
      !_submitting &&
      !_coverUploading;

  void _onSwitchKind(PostMediaKind k) {
    if (_kind == k) return;
    setState(() {
      _kind = k;
      // 切换类型清掉已选文件，避免「图片」类型里挂着视频。
      _resetFile();
      _resetCover();
    });
  }

  void _resetFile() {
    _fileName = null;
    _fileBytes = null;
    _filePath = null;
    _fileSize = null;
    _uploadedPath = null;
    _uploadProgress = 0;
    _uploading = false;
    _uploadError = null;
  }

  void _resetCover() {
    _coverFileName = null;
    _coverFileBytes = null;
    _coverFilePath = null;
    _coverFileSize = null;
    _coverUploadedPath = null;
    _coverUploadProgress = 0;
    _coverUploading = false;
    _coverUploadError = null;
  }

  Set<String> get _allowedExt {
    switch (_kind) {
      case PostMediaKind.image:
        return _imageExt;
      case PostMediaKind.video:
        return const {'mp4', 'mov', 'm4v', 'webm', 'avi', 'mkv'};
      case PostMediaKind.audio:
        return const {'mp3', 'm4a', 'wav', 'aac', 'ogg', 'flac', 'amr'};
    }
  }

  static const Set<String> _imageExt = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
    'heif',
  };

  String _extOf(String name) {
    final i = name.lastIndexOf('.');
    if (i < 0 || i == name.length - 1) return '';
    return name.substring(i + 1).toLowerCase();
  }

  CoursewarePickType get _pickTypeForKind {
    switch (_kind) {
      case PostMediaKind.image:
        return CoursewarePickType.image;
      case PostMediaKind.video:
        return CoursewarePickType.video;
      case PostMediaKind.audio:
        return CoursewarePickType.audio;
    }
  }

  Future<void> _pickFile() async {
    if (_uploading) return;
    // 图片 / 视频在 iOS 端走 FileType.image / video，直接拉起系统相册。
    final files = await pickCoursewareFiles(
      allowMultiple: false,
      type: _pickTypeForKind,
    );
    if (files.isEmpty || !mounted) return;
    final f = files.first;
    if (!_allowedExt.contains(_extOf(f.name))) {
      AppToast.showInfo(
        context,
        '请选择${_kindLabelOf(_kind)}文件（${_allowedExt.join(' / ')}）',
      );
      return;
    }
    setState(() {
      _resetFile();
      if (_kind == PostMediaKind.video) {
        _resetCover();
      }
      _fileName = f.name;
      _fileBytes = f.bytes;
      _filePath = f.path;
      _fileSize = f.size;
    });
    unawaited(_startUpload());
  }

  Future<void> _startUpload() async {
    if (_uploading) return;
    final name = _fileName;
    if (name == null) return;
    final controller = ref.read(cloudDriveControllerProvider.notifier);

    setState(() {
      _uploading = true;
      _uploadError = null;
      _uploadProgress = 0;
      _uploadedPath = null;
    });

    void onProgress(double p) {
      if (!mounted) return;
      setState(() => _uploadProgress = p.clamp(0.0, 0.99));
    }

    try {
      final saved = (_filePath != null && _filePath!.trim().isNotEmpty)
          ? await controller.uploadFilePathRaw(
              filePath: _filePath!,
              filename: name,
              onProgress: onProgress,
            )
          : await controller.uploadFileRaw(
              bytes: _fileBytes ?? Uint8List(0),
              filename: name,
              onProgress: onProgress,
            );
      if (!mounted) return;
      if (saved == null || saved.isEmpty) {
        setState(() {
          _uploading = false;
          _uploadProgress = 0;
          _uploadError = '上传失败，请重试';
        });
        return;
      }
      setState(() {
        _uploadedPath = saved;
        _uploadProgress = 1.0;
        _uploading = false;
      });
      if (_kind == PostMediaKind.video) {
        unawaited(_maybeAutoExtractVideoCover());
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadProgress = 0;
        _uploadError = '上传失败，请重试';
      });
    }
  }

  void _removeFile() {
    setState(_resetFile);
  }

  /// 视频上传完成后，若用户未手动选封面，则抽取第 10 帧并自动上传。
  Future<void> _maybeAutoExtractVideoCover() async {
    if (!mounted || _kind != PostMediaKind.video) return;
    if (_coverFileName != null || _coverUploading) return;

    final bytes = await extractVideoCoverFrame(
      filePath: _filePath,
      fileBytes: _fileBytes,
      frameIndex: 10,
    );
    if (!mounted || bytes == null || bytes.isEmpty) return;
    if (_coverFileName != null) return;

    final baseName = _fileName ?? 'video';
    final dot = baseName.lastIndexOf('.');
    final stem = dot > 0 ? baseName.substring(0, dot) : baseName;

    setState(() {
      _coverFileName = '${stem}_cover.jpg';
      _coverFileBytes = bytes;
      _coverFilePath = null;
      _coverFileSize = bytes.length;
    });
    await _startCoverUpload();
  }

  Future<void> _pickCover() async {
    if (_coverUploading) return;
    final files = await pickCoursewareFiles(
      allowMultiple: false,
      type: CoursewarePickType.image,
    );
    if (files.isEmpty || !mounted) return;
    final f = files.first;
    if (!_imageExt.contains(_extOf(f.name))) {
      AppToast.showInfo(context, '封面请选择 jpg / png / webp 等图片');
      return;
    }
    setState(() {
      _resetCover();
      _coverFileName = f.name;
      _coverFileBytes = f.bytes;
      _coverFilePath = f.path;
      _coverFileSize = f.size;
    });
    unawaited(_startCoverUpload());
  }

  Future<void> _startCoverUpload() async {
    if (_coverUploading) return;
    final name = _coverFileName;
    if (name == null) return;
    final controller = ref.read(cloudDriveControllerProvider.notifier);

    setState(() {
      _coverUploading = true;
      _coverUploadError = null;
      _coverUploadProgress = 0;
      _coverUploadedPath = null;
    });

    void onProgress(double p) {
      if (!mounted) return;
      setState(() => _coverUploadProgress = p.clamp(0.0, 0.99));
    }

    try {
      final saved =
          (_coverFilePath != null && _coverFilePath!.trim().isNotEmpty)
          ? await controller.uploadFilePathRaw(
              filePath: _coverFilePath!,
              filename: name,
              onProgress: onProgress,
            )
          : await controller.uploadFileRaw(
              bytes: _coverFileBytes ?? Uint8List(0),
              filename: name,
              onProgress: onProgress,
            );
      if (!mounted) return;
      if (saved == null || saved.isEmpty) {
        setState(() {
          _coverUploading = false;
          _coverUploadProgress = 0;
          _coverUploadError = '封面上传失败，请重试';
        });
        return;
      }
      setState(() {
        _coverUploadedPath = saved;
        _coverUploadProgress = 1.0;
        _coverUploading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _coverUploading = false;
        _coverUploadProgress = 0;
        _coverUploadError = '封面上传失败，请重试';
      });
    }
  }

  void _removeCover() {
    setState(_resetCover);
  }

  Future<void> _onSubmit() async {
    if (_submitting || !_canSubmit) return;
    setState(() => _submitting = true);
    final controller = ref.read(circleControllerProvider.notifier);
    final message = await controller.publishPost(
      content: _textCtrl.text.trim(),
      kind: _kind,
      mediaUrl: _uploadedPath!,
      coverImg: _coverUploadedPath ?? '',
    );
    if (!mounted) return;
    if (message != null && message.isNotEmpty) {
      setState(() => _submitting = false);
      AppToast.showError(context, message);
      return;
    }
    AppToast.showSuccess(context, '动态已发布');
    Navigator.of(context).pop(true);
  }

  void _onCancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: '发布动态',
      actions: [
        AppButton(
          label: '取消',
          variant: AppButtonVariant.secondary,
          enabled: !_submitting,
          onTap: _onCancel,
        ),
        AppButton(
          label: '发布',
          loading: _submitting,
          enabled: _canSubmit,
          onTap: _onSubmit,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSegmented<PostMediaKind>(
            segments: [
              for (final kind in _publishKinds)
                AppSegment(value: kind, label: _kindLabelOf(kind)),
            ],
            value: _kind,
            onChanged: _onSwitchKind,
            expand: true,
          ),
          const SizedBox(height: AppSpace.s16),
          AppInputField(
            controller: _textCtrl,
            label: '内容',
            hint: '分享作品、写生日记或模考心得',
            multiline: true,
            minLines: 4,
            maxLines: 6,
            maxLength: 500,
            required: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpace.s16),
          _MediaArea(
            kind: _kind,
            fileName: _fileName,
            fileSize: _fileSize,
            fileBytes: _fileBytes,
            uploading: _uploading,
            uploadProgress: _uploadProgress,
            uploadedPath: _uploadedPath,
            uploadError: _uploadError,
            onPick: _pickFile,
            onRemove: _removeFile,
            onRetry: _startUpload,
          ),
          if (_needsCover) ...[
            const SizedBox(height: AppSpace.s16),
            _CoverArea(
              fileName: _coverFileName,
              fileSize: _coverFileSize,
              fileBytes: _coverFileBytes,
              uploading: _coverUploading,
              uploadProgress: _coverUploadProgress,
              uploadedPath: _coverUploadedPath,
              uploadError: _coverUploadError,
              onPick: _pickCover,
              onRemove: _removeCover,
              onRetry: _startCoverUpload,
            ),
          ],
        ],
      ),
    );
  }
}

/// 已选文件行：缩略图 + 文件名 + 上传状态 + 操作按钮。
class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.kind,
    required this.fileName,
    required this.fileSize,
    required this.fileBytes,
    required this.uploading,
    required this.uploadProgress,
    required this.uploaded,
    required this.uploadError,
    required this.onRemove,
    required this.onRetry,
    this.onReplace,
  });

  final PostMediaKind kind;
  final String fileName;
  final int? fileSize;
  final Uint8List? fileBytes;
  final bool uploading;
  final double uploadProgress;
  final bool uploaded;
  final String? uploadError;
  final VoidCallback onRemove;
  final VoidCallback onRetry;
  final VoidCallback? onReplace;

  @override
  Widget build(BuildContext context) {
    final replace = onReplace;
    return Container(
      padding: const EdgeInsets.all(AppSpace.s12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.br12,
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          _MediaThumbnail(kind: kind, bytes: fileBytes),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body14Strong,
                ),
                const SizedBox(height: AppSpace.s4),
                _UploadStatusLine(
                  fileSize: fileSize,
                  uploading: uploading,
                  uploadProgress: uploadProgress,
                  uploaded: uploaded,
                  uploadError: uploadError,
                  onRetry: onRetry,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          if (replace != null && uploaded && !uploading)
            AppIconButton(
              icon: Icons.swap_horiz_rounded,
              semanticLabel: '重新选择',
              size: AppButtonSize.sm,
              filled: false,
              color: AppColors.textSecondary,
              onTap: replace,
            ),
          AppIconButton(
            icon: Icons.close_rounded,
            semanticLabel: '移除',
            size: AppButtonSize.sm,
            filled: false,
            color: AppColors.textTertiary,
            enabled: !uploading,
            onTap: onRemove,
          ),
        ],
      ),
    );
  }
}

class _MediaArea extends StatelessWidget {
  const _MediaArea({
    required this.kind,
    required this.fileName,
    required this.fileSize,
    required this.fileBytes,
    required this.uploading,
    required this.uploadProgress,
    required this.uploadedPath,
    required this.uploadError,
    required this.onPick,
    required this.onRemove,
    required this.onRetry,
  });

  final PostMediaKind kind;
  final String? fileName;
  final int? fileSize;
  final Uint8List? fileBytes;
  final bool uploading;
  final double uploadProgress;
  final String? uploadedPath;
  final String? uploadError;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final name = fileName;
    if (name == null) {
      final label = _kindLabelOf(kind);
      return AppPressable(
        onTap: onPick,
        semanticLabel: '上传$label',
        child: Container(
          height: 132,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: AppRadius.br12,
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _kindIconOf(kind),
                size: 32,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: AppSpace.s8),
              Text('点击上传$label', style: AppText.body14Strong),
              const SizedBox(height: AppSpace.s4),
              Text(
                kind == PostMediaKind.video
                    ? '支持 mp4 / mov / webm 等格式'
                    : '支持 jpg / png / gif / webp 等格式',
                style: AppText.caption12,
              ),
            ],
          ),
        ),
      );
    }
    return _FileRow(
      kind: kind,
      fileName: name,
      fileSize: fileSize,
      fileBytes: fileBytes,
      uploading: uploading,
      uploadProgress: uploadProgress,
      uploaded: uploadedPath != null,
      uploadError: uploadError,
      onRemove: onRemove,
      onRetry: onRetry,
    );
  }
}

/// 视频帖的「封面图」槽位（可选）。
class _CoverArea extends StatelessWidget {
  const _CoverArea({
    required this.fileName,
    required this.fileSize,
    required this.fileBytes,
    required this.uploading,
    required this.uploadProgress,
    required this.uploadedPath,
    required this.uploadError,
    required this.onPick,
    required this.onRemove,
    required this.onRetry,
  });

  final String? fileName;
  final int? fileSize;
  final Uint8List? fileBytes;
  final bool uploading;
  final double uploadProgress;
  final String? uploadedPath;
  final String? uploadError;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final name = fileName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('封面图', style: AppText.body14Strong),
            const SizedBox(width: AppSpace.s8),
            Text('可选', style: AppText.caption12),
          ],
        ),
        const SizedBox(height: AppSpace.s8),
        if (name == null)
          AppPressable(
            onTap: onPick,
            semanticLabel: '上传封面',
            child: Container(
              padding: const EdgeInsets.all(AppSpace.s12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: AppRadius.br12,
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.br8,
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 24,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('点击上传封面', style: AppText.body14Strong),
                        const SizedBox(height: AppSpace.s4),
                        Text(
                          '建议比例 16:9 或 1:1，支持 jpg / png / webp',
                          style: AppText.caption12,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          _FileRow(
            kind: PostMediaKind.image,
            fileName: name,
            fileSize: fileSize,
            fileBytes: fileBytes,
            uploading: uploading,
            uploadProgress: uploadProgress,
            uploaded: uploadedPath != null,
            uploadError: uploadError,
            onRemove: onRemove,
            onRetry: onRetry,
            onReplace: onPick,
          ),
      ],
    );
  }
}

class _MediaThumbnail extends StatelessWidget {
  const _MediaThumbnail({required this.kind, required this.bytes});

  final PostMediaKind kind;
  final Uint8List? bytes;

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    final data = bytes;
    final Widget child;
    if (kind == PostMediaKind.image && data != null && data.isNotEmpty) {
      child = Image.memory(
        data,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
      );
    } else {
      child = Container(
        width: _size,
        height: _size,
        alignment: Alignment.center,
        color: AppColors.surfaceSubtle,
        child: Icon(_kindIconOf(kind), size: 24, color: AppColors.textTertiary),
      );
    }
    return ClipRRect(borderRadius: AppRadius.br8, child: child);
  }
}

class _UploadStatusLine extends StatelessWidget {
  const _UploadStatusLine({
    required this.fileSize,
    required this.uploading,
    required this.uploadProgress,
    required this.uploaded,
    required this.uploadError,
    required this.onRetry,
  });

  final int? fileSize;
  final bool uploading;
  final double uploadProgress;
  final bool uploaded;
  final String? uploadError;
  final VoidCallback onRetry;

  static String _humanSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final error = uploadError;
    final size = _humanSize(fileSize);
    if (uploading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '上传中 ${(uploadProgress * 100).toStringAsFixed(0)}%',
            style: AppText.caption12,
          ),
          const SizedBox(height: AppSpace.s4),
          AppProgressBar(value: uploadProgress, height: 4),
        ],
      );
    }
    if (error != null) {
      return Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 14,
            color: AppColors.danger,
          ),
          const SizedBox(width: AppSpace.s4),
          Expanded(
            child: Text(
              error,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption12.copyWith(color: AppColors.danger),
            ),
          ),
          AppButton(
            label: '重试',
            variant: AppButtonVariant.text,
            size: AppButtonSize.sm,
            onTap: onRetry,
          ),
        ],
      );
    }
    if (uploaded) {
      return Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 14,
            color: AppColors.success,
          ),
          const SizedBox(width: AppSpace.s4),
          Text(
            size.isEmpty ? '已上传' : '已上传 · $size',
            style: AppText.caption12,
          ),
        ],
      );
    }
    return Text(size, style: AppText.caption12);
  }
}
