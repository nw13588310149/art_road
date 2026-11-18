import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../data/gallery_models.dart';
import '../data/gallery_repository.dart';
import 'widgets/gallery_images.dart';

/// 全屏对比：左边范画，右边本人最近一次同科原卷（或相册照片）。
///
/// 不带外壳：白色顶栏放返回、作品名和两组切换（并排 / 滑动 / 叠加、彩色 / 灰度），
/// 下面是中性灰的画布（`AppCompareView`），画布下面一行是提示和锁定、旋转、
/// 翻转、交换、复位。默认锁定：缩放一侧，另一侧看同一处。
class GalleryComparePage extends ConsumerStatefulWidget {
  const GalleryComparePage({required this.work, super.key});

  final GalleryWork work;

  @override
  ConsumerState<GalleryComparePage> createState() => _GalleryComparePageState();
}

class _GalleryComparePageState extends ConsumerState<GalleryComparePage> {
  final _compare = AppCompareController();

  bool _loadingPaper = true;
  String _mineUrl = '';
  Uint8List? _mineBytes;
  String _mineLabel = '我的原卷';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMyPaper());
  }

  @override
  void dispose() {
    _compare.dispose();
    super.dispose();
  }

  Future<void> _loadMyPaper() async {
    final paper = await ref
        .read(galleryRepositoryProvider)
        .findLatestPaper(widget.work.subject);
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingPaper = false;
      if (paper != null && _mineBytes == null) {
        _mineUrl = paper.imageUrl;
        _mineLabel = paper.examName.isEmpty
            ? '我的原卷'
            : '我的原卷 · ${paper.examName}';
      }
    });
    if (paper == null && _mineBytes == null) {
      AppToast.showInfo(context, '暂未找到你的${widget.work.subject}原卷，可从相册选择照片对比');
    }
  }

  Future<void> _pickPhoto() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
    } catch (_) {
      if (mounted) {
        AppToast.showError(context, '无法打开相册，请检查相册访问权限');
      }
      return;
    }
    final file = result?.files.firstOrNull;
    final bytes = file?.bytes;
    if (!mounted || bytes == null || bytes.isEmpty) {
      return;
    }
    setState(() {
      _mineBytes = bytes;
      _mineLabel = '我的照片';
      _loadingPaper = false;
    });
    _compare.resetZoom();
  }

  AppComparePane get _workPane {
    final work = widget.work;
    return AppComparePane(
      label: '范画',
      aspectRatio: work.aspectRatio > 0 ? work.aspectRatio : null,
      image: galleryImageProvider(work.imageUrl),
      child: _CompareImage(url: work.imageUrl),
    );
  }

  AppComparePane get _minePane {
    final bytes = _mineBytes;
    if (bytes != null) {
      return AppComparePane(
        label: _mineLabel,
        image: MemoryImage(bytes),
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          cacheWidth: 2048,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              const GalleryBrokenImage(),
        ),
      );
    }
    if (_mineUrl.isNotEmpty) {
      return AppComparePane(
        label: _mineLabel,
        image: galleryImageProvider(_mineUrl),
        child: _CompareImage(url: _mineUrl),
      );
    }
    return AppComparePane.placeholder(
      label: _mineLabel,
      child: _loadingPaper
          ? const Center(child: AppLoadingIndicator())
          : _MissingPaper(subject: widget.work.subject, onPick: _pickPhoto),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CompareTopBar(
              title: widget.work.title,
              controller: _compare,
              onClose: () => Navigator.of(context).maybePop(),
              onPickPhoto: _pickPhoto,
            ),
            const AppRule(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.s24,
                  AppSpace.s4,
                  AppSpace.s24,
                  0,
                ),
                child: AppCompareView(
                  controller: _compare,
                  first: _workPane,
                  second: _minePane,
                  autofocus: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24),
              child: AppCompareFooter(controller: _compare),
            ),
            const SizedBox(height: AppSpace.s8),
          ],
        ),
      ),
    );
  }
}

/// 白色顶栏：返回和作品名在左，并排 / 滑动 / 叠加、彩色 / 灰度和「选择照片」在右。
class _CompareTopBar extends StatelessWidget {
  const _CompareTopBar({
    required this.title,
    required this.controller,
    required this.onClose,
    required this.onPickPhoto,
  });

  final String title;
  final AppCompareController controller;
  final VoidCallback onClose;
  final VoidCallback onPickPhoto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '对比我的原卷',
      child: Container(
        height: 64,
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24),
        alignment: Alignment.center,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => AppTitleBar(
            title: title,
            onBack: onClose,
            actions: [
              AppCompareModeTabs(controller: controller),
              // 两组切换之间放一条短竖线，不然读起来像一组页签。
              const SizedBox(height: 20, child: AppRule.vertical(gap: 33)),
              AppViewTabs<bool>(
                items: const [
                  AppViewTab(value: false, label: '彩色'),
                  AppViewTab(value: true, label: '灰度'),
                ],
                value: controller.grayscale,
                onChanged: controller.setGrayscale,
              ),
              const SizedBox(width: AppSpace.s20),
              AppPlainButton(
                label: '选择照片',
                icon: Icons.photo_library_outlined,
                onTap: onPickPhoto,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 对比用的图片：完整显示，加载中转圈，失败显示裂图；不做淡入。
class _CompareImage extends StatelessWidget {
  const _CompareImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return AppImage(
      src: url,
      fit: BoxFit.contain,
      placeholder: const Center(child: AppLoadingIndicator()),
      error: const GalleryBrokenImage(),
    );
  }
}

class _MissingPaper extends StatelessWidget {
  const _MissingPaper({required this.subject, required this.onPick});

  final String subject;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.image_outlined,
      title: '暂无可对比的$subject原卷',
      description: '阅卷完成后会显示最近一次考试的原卷，也可以选择照片进行对比',
      actionLabel: '从相册选择',
      onAction: onPick,
    );
  }
}
