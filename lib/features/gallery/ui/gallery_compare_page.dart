import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../data/gallery_models.dart';
import '../data/gallery_repository.dart';

enum _CompareMode { sideBySide, reveal }

/// 全屏对比：左侧范画、右侧本人最近一次同科原卷（或相册照片），中间分隔条可拖动。
class GalleryComparePage extends ConsumerStatefulWidget {
  const GalleryComparePage({required this.work, super.key});

  final GalleryWork work;

  @override
  ConsumerState<GalleryComparePage> createState() => _GalleryComparePageState();
}

class _GalleryComparePageState extends ConsumerState<GalleryComparePage> {
  static const _grayMatrix = <double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ];

  bool _loadingPaper = true;
  String _mineUrl = '';
  Uint8List? _mineBytes;
  String _mineLabel = '我的原卷';
  double _split = 0.5;
  _CompareMode _mode = _CompareMode.sideBySide;
  bool _grayscale = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMyPaper());
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
  }

  void _dragDivider(double dx, double width) {
    if (width <= 0) {
      return;
    }
    _setSplit(_split + dx / width);
  }

  void _setSplit(double value) {
    setState(() => _split = value.clamp(0.15, 0.85));
  }

  Widget _filtered(Widget child) => _grayscale
      ? ColorFiltered(
          colorFilter: const ColorFilter.matrix(_grayMatrix),
          child: child,
        )
      : child;

  Widget _workImage() => _filtered(_CompareImage(url: widget.work.imageUrl));

  Widget _mineImage() {
    final bytes = _mineBytes;
    if (bytes != null) {
      return _filtered(
        Image.memory(
          bytes,
          fit: BoxFit.contain,
          cacheWidth: 2048,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => const _BrokenImage(),
        ),
      );
    }
    if (_mineUrl.isNotEmpty) {
      return _filtered(_CompareImage(url: _mineUrl));
    }
    if (_loadingPaper) {
      return const Center(child: AppLoadingIndicator(size: 36));
    }
    return _MissingPaper(subject: widget.work.subject, onPick: _pickPhoto);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _CompareTopBar(
              subtitle: widget.work.title,
              mode: _mode,
              grayscale: _grayscale,
              onClose: () => Navigator.of(context).maybePop(),
              onModeChanged: (mode) => setState(() => _mode = mode),
              onGrayscaleChanged: (value) => setState(() => _grayscale = value),
              onPickPhoto: _pickPhoto,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.s16,
                  0,
                  AppSpace.s16,
                  AppSpace.s8,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) =>
                      _mode == _CompareMode.sideBySide
                      ? _buildSideBySide(constraints.maxWidth)
                      : _buildReveal(constraints.maxWidth),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s16,
                0,
                AppSpace.s16,
                AppSpace.s12,
              ),
              child: Text(
                _mode == _CompareMode.sideBySide
                    ? '拖动中间分隔条调整两侧大小，双指可分别缩放；双击分隔条复位'
                    : '左右拖动分隔条，在同一画框内对照两幅作品；双击分隔条复位',
                textAlign: TextAlign.center,
                style: AppText.caption12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideBySide(double width) {
    final left = width * _split;
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: (left - 3).clamp(0.0, width).toDouble(),
          child: _ComparePane(label: '范画', child: _workImage()),
        ),
        Positioned(
          left: left + 3,
          top: 0,
          bottom: 0,
          right: 0,
          child: _ComparePane(label: _mineLabel, child: _mineImage()),
        ),
        Positioned(
          left: left - 22,
          top: 0,
          bottom: 0,
          width: 44,
          child: _DividerHandle(
            onDrag: (dx) => _dragDivider(dx, width),
            value: _split,
            onChanged: _setSplit,
          ),
        ),
      ],
    );
  }

  Widget _buildReveal(double width) {
    final x = width * _split;
    return ClipRRect(
      borderRadius: AppRadius.br12,
      child: ColoredBox(
        color: AppColors.surfaceSubtle,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _mineImage(),
            ClipRect(
              clipper: _LeftClipper(x),
              child: ColoredBox(
                color: AppColors.surfaceSubtle,
                child: _workImage(),
              ),
            ),
            const Positioned(
              left: AppSpace.s8,
              top: AppSpace.s8,
              child: _PaneLabel('范画'),
            ),
            Positioned(
              right: AppSpace.s8,
              top: AppSpace.s8,
              child: _PaneLabel(_mineLabel),
            ),
            Positioned(
              left: x - 22,
              top: 0,
              bottom: 0,
              width: 44,
              child: _DividerHandle(
                onDrag: (dx) => _dragDivider(dx, width),
                value: _split,
                onChanged: _setSplit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeftClipper extends CustomClipper<Rect> {
  const _LeftClipper(this.width);

  final double width;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, width, size.height);

  @override
  bool shouldReclip(covariant _LeftClipper oldClipper) =>
      oldClipper.width != width;
}

class _CompareTopBar extends StatelessWidget {
  const _CompareTopBar({
    required this.subtitle,
    required this.mode,
    required this.grayscale,
    required this.onClose,
    required this.onModeChanged,
    required this.onGrayscaleChanged,
    required this.onPickPhoto,
  });

  final String subtitle;
  final _CompareMode mode;
  final bool grayscale;
  final VoidCallback onClose;
  final ValueChanged<_CompareMode> onModeChanged;
  final ValueChanged<bool> onGrayscaleChanged;
  final VoidCallback onPickPhoto;

  @override
  Widget build(BuildContext context) {
    return AppPageHeader(
      title: '对比我的原卷',
      subtitle: subtitle,
      onBack: onClose,
      actions: [
        AppSegmented<_CompareMode>(
          size: AppControlSize.sm,
          segments: const [
            AppSegment(value: _CompareMode.sideBySide, label: '并排'),
            AppSegment(value: _CompareMode.reveal, label: '滑动'),
          ],
          value: mode,
          onChanged: onModeChanged,
        ),
        AppSegmented<bool>(
          size: AppControlSize.sm,
          segments: const [
            AppSegment(value: false, label: '彩色'),
            AppSegment(value: true, label: '灰度'),
          ],
          value: grayscale,
          onChanged: onGrayscaleChanged,
        ),
        AppButton(
          label: '选择照片',
          icon: Icons.photo_library_outlined,
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.sm,
          onTap: onPickPhoto,
        ),
      ],
    );
  }
}

class _ComparePane extends StatelessWidget {
  const _ComparePane({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.br12,
      child: ColoredBox(
        color: AppColors.surfaceSubtle,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5,
                child: SizedBox.expand(child: child),
              ),
            ),
            Positioned(
              left: AppSpace.s8,
              top: AppSpace.s8,
              child: _PaneLabel(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaneLabel extends StatelessWidget {
  const _PaneLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s8,
          vertical: AppSpace.s4,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.brPill,
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.caption12Strong.copyWith(color: AppColors.ink),
        ),
      ),
    );
  }
}

class _DividerHandle extends StatelessWidget {
  const _DividerHandle({
    required this.value,
    required this.onDrag,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double> onDrag;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final decreased = (value - 0.05).clamp(0.15, 0.85);
    final increased = (value + 0.05).clamp(0.15, 0.85);
    String percent(double fraction) => '${(fraction * 100).round()}%';
    void decrease() => onChanged(decreased);
    void increase() => onChanged(increased);
    void reset() => onChanged(0.5);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): decrease,
        const SingleActivator(LogicalKeyboardKey.arrowRight): increase,
        const SingleActivator(LogicalKeyboardKey.home): reset,
      },
      child: Focus(
        child: Semantics(
          slider: true,
          label: '对比分隔线',
          value: percent(value),
          decreasedValue: value > 0.15 ? percent(decreased) : null,
          increasedValue: value < 0.85 ? percent(increased) : null,
          onDecrease: value > 0.15 ? decrease : null,
          onIncrease: value < 0.85 ? increase : null,
          onTap: reset,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              excludeFromSemantics: true,
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
              onDoubleTap: reset,
              child: Builder(
                builder: (context) {
                  final focused = Focus.of(context).hasFocus;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 2,
                        decoration: const BoxDecoration(
                          color: AppColors.textSecondary,
                          borderRadius: AppRadius.brPill,
                        ),
                      ),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: focused ? AppColors.brand : AppColors.line,
                          ),
                        ),
                        child: const Icon(
                          Icons.compare_arrows_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
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
      placeholder: const Center(child: AppLoadingIndicator(size: 36)),
      error: const _BrokenImage(),
    );
  }
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.broken_image_outlined,
        size: 36,
        color: AppColors.textSecondary,
        semanticLabel: '图片加载失败',
      ),
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
      icon: Icons.image_search_rounded,
      title: '暂无可对比的$subject原卷',
      description: '阅卷完成后会显示最近一次考试的原卷，也可以选择照片进行对比',
      actionLabel: '从相册选择',
      onAction: onPick,
    );
  }
}
