import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../data/gallery_models.dart';
import '../data/gallery_repository.dart';
import 'widgets/compare_divider.dart';
import 'widgets/gallery_images.dart';

enum _CompareMode { sideBySide, reveal }

/// 全屏对比：左边范画，右边本人最近一次同科原卷（或相册照片）。
///
/// 不带外壳：白色顶栏放返回、作品名和两组切换，下面是中性灰的画布。并排时两幅画
/// 按同样的高度显示，大小可比；滑动时两幅画放进同一个画框。名称写在画的上方，
/// 不压在画上。分隔条可以拖动，双击复位。
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

  /// 画上方那一行名称的高度。
  static const double _labelHeight = 32;

  bool _loadingPaper = true;
  String _mineUrl = '';
  Uint8List? _mineBytes;
  String _mineLabel = '我的原卷';
  double? _mineAspect;

  /// 并排时分隔条的位置；为 null 时放在让两幅画都尽量大的位置（复位也回到那里）。
  double? _sideSplit;

  /// 滑动时分隔条在画框里的位置。
  double _revealSplit = 0.5;
  _CompareMode _mode = _CompareMode.sideBySide;
  bool _grayscale = false;

  ImageStream? _aspectStream;
  ImageStreamListener? _aspectListener;

  bool get _hasMine => _mineBytes != null || _mineUrl.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMyPaper());
  }

  @override
  void dispose() {
    _stopAspect();
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
    if (paper != null && _mineBytes == null) {
      _resolveMineAspect(galleryImageProvider(paper.imageUrl));
    }
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
      _mineAspect = null;
      _mineLabel = '我的照片';
      _loadingPaper = false;
    });
    _resolveMineAspect(MemoryImage(bytes));
  }

  /// 读出本人这幅画的宽高比，并排时按它算出和范画相同的显示高度。
  void _resolveMineAspect(ImageProvider provider) {
    _stopAspect();
    final stream = provider.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener((info, _) {
      final ratio = info.image.width / info.image.height;
      info.dispose();
      _stopAspect();
      if (mounted && ratio > 0) {
        setState(() => _mineAspect = ratio);
      }
    }, onError: (_, _) => _stopAspect());
    _aspectStream = stream;
    _aspectListener = listener;
    stream.addListener(listener);
  }

  void _stopAspect() {
    final stream = _aspectStream;
    final listener = _aspectListener;
    _aspectStream = null;
    _aspectListener = null;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
  }

  static double _clampSplit(double value) =>
      value.clamp(CompareDivider.min, CompareDivider.max).toDouble();

  static double _ratio(double value) => value > 0 ? value : 1;

  double get _workRatio => _ratio(widget.work.aspectRatio);

  double get _mineRatio => _ratio(_mineAspect ?? _workRatio);

  /// 两幅画按同一高度放下时左右宽度之比，就是让两幅画都最大的分隔位置。
  double _balancedSplit(double width) {
    if (!_hasMine || width <= 0) {
      return 0.5;
    }
    const gap = CompareDivider.extent;
    final left = (width - gap) * _workRatio / (_workRatio + _mineRatio);
    return _clampSplit((left + gap / 2) / width);
  }

  void _setSideSplit(double? value) =>
      setState(() => _sideSplit = value == null ? null : _clampSplit(value));

  void _setRevealSplit(double value) =>
      setState(() => _revealSplit = _clampSplit(value));

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
          errorBuilder: (context, error, stackTrace) =>
              const GalleryBrokenImage(),
        ),
      );
    }
    if (_mineUrl.isNotEmpty) {
      return _filtered(_CompareImage(url: _mineUrl));
    }
    if (_loadingPaper) {
      return const Center(child: AppLoadingIndicator());
    }
    return _MissingPaper(subject: widget.work.subject, onPick: _pickPhoto);
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
              mode: _mode,
              grayscale: _grayscale,
              onClose: () => Navigator.of(context).maybePop(),
              onModeChanged: (mode) => setState(() => _mode = mode),
              onGrayscaleChanged: (value) => setState(() => _grayscale = value),
              onPickPhoto: _pickPhoto,
            ),
            const AppRule(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.s24,
                  AppSpace.s16,
                  AppSpace.s24,
                  0,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final area = constraints.biggest;
                    return _mode == _CompareMode.sideBySide
                        ? _buildSideBySide(area)
                        : _buildReveal(area);
                  },
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: Center(
                child: Text(
                  _mode == _CompareMode.sideBySide
                      ? '拖动中间分隔条调整两侧大小，双指可分别缩放；双击分隔条复位'
                      : '左右拖动分隔条，在同一画框内对照两幅作品；双击分隔条复位',
                  style: AppText.caption12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideBySide(Size area) {
    const gap = CompareDivider.extent;
    final split = _sideSplit ?? _balancedSplit(area.width);
    final splitX = area.width * split;
    final leftWidth = math.max(0.0, splitX - gap / 2);
    final rightWidth = math.max(0.0, area.width - splitX - gap / 2);
    final workRatio = _workRatio;
    final mineRatio = _mineRatio;
    // 两幅画取同一个高度：都要完整放进各自那一侧。
    var height = math.min(area.height - _labelHeight, leftWidth / workRatio);
    if (_hasMine) {
      height = math.min(height, rightWidth / mineRatio);
    }
    height = math.max(0, height);
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: leftWidth,
          child: _ComparePane(
            label: '范画',
            size: Size(height * workRatio, height),
            child: _workImage(),
          ),
        ),
        Positioned(
          left: splitX + gap / 2,
          top: 0,
          bottom: 0,
          width: rightWidth,
          child: _hasMine
              ? _ComparePane(
                  label: _mineLabel,
                  size: Size(height * mineRatio, height),
                  child: _mineImage(),
                )
              : _mineImage(),
        ),
        Positioned(
          left: splitX - gap / 2,
          top: 0,
          bottom: 0,
          width: gap,
          child: CompareDivider(
            value: split,
            onDrag: (dx) {
              if (area.width > 0) {
                _setSideSplit(split + dx / area.width);
              }
            },
            onChanged: _setSideSplit,
            onReset: () => _setSideSplit(null),
          ),
        ),
      ],
    );
  }

  /// 两幅画按同一高度叠在一个画框里，画框和较宽的那幅一样宽。
  Widget _buildReveal(Size area) {
    final ratio = _hasMine ? math.max(_workRatio, _mineRatio) : _workRatio;
    final maxHeight = math.max(0.0, area.height - _labelHeight);
    var frameWidth = area.width;
    var frameHeight = frameWidth / ratio;
    if (frameHeight > maxHeight) {
      frameHeight = maxHeight;
      frameWidth = frameHeight * ratio;
    }
    final x = frameWidth * _revealSplit;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: frameWidth,
            height: _labelHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(child: _PaneLabel('范画')),
                const SizedBox(width: AppSpace.s16),
                Expanded(child: _PaneLabel(_mineLabel, alignEnd: true)),
              ],
            ),
          ),
          SizedBox(
            width: frameWidth,
            height: frameHeight,
            child: Stack(
              children: [
                Positioned.fill(child: _mineImage()),
                Positioned.fill(
                  child: ClipRect(
                    clipper: _LeftClipper(x),
                    child: ColoredBox(
                      color: AppColors.canvas,
                      child: _workImage(),
                    ),
                  ),
                ),
                Positioned(
                  left: x - CompareDivider.extent / 2,
                  top: 0,
                  bottom: 0,
                  width: CompareDivider.extent,
                  child: CompareDivider(
                    value: _revealSplit,
                    onDrag: (dx) {
                      if (frameWidth > 0) {
                        _setRevealSplit(_revealSplit + dx / frameWidth);
                      }
                    },
                    onChanged: _setRevealSplit,
                    onReset: () => _setRevealSplit(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
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

/// 白色顶栏：返回和作品名在左，并排 / 滑动、彩色 / 灰度和「选择照片」在右。
class _CompareTopBar extends StatelessWidget {
  const _CompareTopBar({
    required this.title,
    required this.mode,
    required this.grayscale,
    required this.onClose,
    required this.onModeChanged,
    required this.onGrayscaleChanged,
    required this.onPickPhoto,
  });

  final String title;
  final _CompareMode mode;
  final bool grayscale;
  final VoidCallback onClose;
  final ValueChanged<_CompareMode> onModeChanged;
  final ValueChanged<bool> onGrayscaleChanged;
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
        child: AppTitleBar(
          title: title,
          onBack: onClose,
          actions: [
            AppViewTabs<_CompareMode>(
              items: const [
                AppViewTab(value: _CompareMode.sideBySide, label: '并排'),
                AppViewTab(value: _CompareMode.reveal, label: '滑动'),
              ],
              value: mode,
              onChanged: onModeChanged,
            ),
            // 两组切换之间放一条短竖线，不然读起来像四个页签。
            const SizedBox(height: 20, child: AppRule.vertical(gap: 33)),
            AppViewTabs<bool>(
              items: const [
                AppViewTab(value: false, label: '彩色'),
                AppViewTab(value: true, label: '灰度'),
              ],
              value: grayscale,
              onChanged: onGrayscaleChanged,
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
    );
  }
}

/// 一幅画和它上方的名称；[size] 是画按比例算好的显示尺寸，整体居中。
class _ComparePane extends StatelessWidget {
  const _ComparePane({
    required this.label,
    required this.size,
    required this.child,
  });

  final String label;
  final Size size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: size.width,
            height: _GalleryComparePageState._labelHeight,
            child: _PaneLabel(label),
          ),
          SizedBox.fromSize(
            size: size,
            child: InteractiveViewer(
              maxScale: 5,
              child: SizedBox.expand(child: child),
            ),
          ),
        ],
      ),
    );
  }
}

/// 画上方的名称：一行，放不下时省略。
class _PaneLabel extends StatelessWidget {
  const _PaneLabel(this.text, {this.alignEnd = false});

  final String text;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignEnd ? Alignment.topRight : Alignment.topLeft,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        style: AppText.body14,
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
