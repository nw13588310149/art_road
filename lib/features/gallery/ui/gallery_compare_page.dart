import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/art/art_tokens.dart';
import '../../../core/network/media_url.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_toast.dart';
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
  static const _background = Color(0xFF15141B);
  static const _paneColor = Color(0xFF211F29);
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
      AppToast.show(context, '暂未找到你的${widget.work.subject}原卷，可从相册选择照片对比');
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
        AppToast.show(context, '无法打开相册，请检查相册访问权限');
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
    setState(() => _split = (_split + dx / width).clamp(0.15, 0.85));
  }

  Widget _filtered(Widget child) => _grayscale
      ? ColorFiltered(
          colorFilter: const ColorFilter.matrix(_grayMatrix),
          child: child,
        )
      : child;

  Widget _workImage() => _filtered(_CompareNetworkImage(widget.work.imageUrl));

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
      return _filtered(_CompareNetworkImage(_mineUrl));
    }
    if (_loadingPaper) {
      return const Center(child: AppLoadingIndicator(size: 36));
    }
    return _MissingPaper(subject: widget.work.subject, onPick: _pickPhoto);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            _CompareTopBar(
              subtitle: widget.work.title,
              mode: _mode,
              grayscale: _grayscale,
              onClose: () => Navigator.of(context).maybePop(),
              onModeChanged: (mode) => setState(() => _mode = mode),
              onToggleGrayscale: () => setState(() => _grayscale = !_grayscale),
              onPickPhoto: _pickPhoto,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: LayoutBuilder(
                  builder: (context, constraints) =>
                      _mode == _CompareMode.sideBySide
                      ? _buildSideBySide(constraints.maxWidth)
                      : _buildReveal(constraints.maxWidth),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _mode == _CompareMode.sideBySide
                    ? '拖动中间分隔条调整两侧大小，双指可分别缩放；双击分隔条复位'
                    : '左右拖动分隔条，在同一画框内对照两幅作品；双击分隔条复位',
                style: ArtText.caption(
                  color: Colors.white.withValues(alpha: 0.55),
                ),
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
          child: _ComparePane(
            color: _paneColor,
            label: '范画',
            child: _workImage(),
          ),
        ),
        Positioned(
          left: left + 3,
          top: 0,
          bottom: 0,
          right: 0,
          child: _ComparePane(
            color: _paneColor,
            label: _mineLabel,
            child: _mineImage(),
          ),
        ),
        Positioned(
          left: left - 20,
          top: 0,
          bottom: 0,
          width: 40,
          child: _DividerHandle(
            onDrag: (dx) => _dragDivider(dx, width),
            onReset: () => setState(() => _split = 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildReveal(double width) {
    final x = width * _split;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: _paneColor,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _mineImage(),
            ClipRect(
              clipper: _LeftClipper(x),
              child: ColoredBox(color: _paneColor, child: _workImage()),
            ),
            const Positioned(left: 10, top: 10, child: _PaneLabel('范画')),
            Positioned(right: 10, top: 10, child: _PaneLabel(_mineLabel)),
            Positioned(
              left: x - 20,
              top: 0,
              bottom: 0,
              width: 40,
              child: _DividerHandle(
                onDrag: (dx) => _dragDivider(dx, width),
                onReset: () => setState(() => _split = 0.5),
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
    required this.onToggleGrayscale,
    required this.onPickPhoto,
  });

  final String subtitle;
  final _CompareMode mode;
  final bool grayscale;
  final VoidCallback onClose;
  final ValueChanged<_CompareMode> onModeChanged;
  final VoidCallback onToggleGrayscale;
  final VoidCallback onPickPhoto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          _DarkIconButton(icon: Icons.close_rounded, onTap: onClose),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '对比我的原卷',
                  style: ArtText.title(size: 17, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ArtText.caption(
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          _ModeSwitch(value: mode, onChanged: onModeChanged),
          const SizedBox(width: 8),
          _DarkPillButton(
            icon: Icons.filter_b_and_w_rounded,
            label: '灰度',
            active: grayscale,
            onTap: onToggleGrayscale,
          ),
          const SizedBox(width: 8),
          _DarkPillButton(
            icon: Icons.photo_library_outlined,
            label: '选择照片',
            onTap: onPickPhoto,
          ),
        ],
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.value, required this.onChanged});

  final _CompareMode value;
  final ValueChanged<_CompareMode> onChanged;

  static const _labels = <_CompareMode, String>{
    _CompareMode.sideBySide: '并排',
    _CompareMode.reveal: '滑动',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final mode in _CompareMode.values)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: mode == value ? ArtColors.brand : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _labels[mode]!,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    color: Colors.white.withValues(
                      alpha: mode == value ? 1 : 0.7,
                    ),
                    fontWeight: AppFont.w500,
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DarkIconButton extends StatelessWidget {
  const _DarkIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _DarkPillButton extends StatelessWidget {
  const _DarkPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? ArtColors.brand : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                height: 1.2,
                color: Colors.white,
                fontWeight: AppFont.w500,
                fontFamily: 'PingFang SC',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparePane extends StatelessWidget {
  const _ComparePane({
    required this.color,
    required this.label,
    required this.child,
  });

  final Color color;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: color,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5,
                child: SizedBox.expand(child: child),
              ),
            ),
            Positioned(left: 10, top: 10, child: _PaneLabel(label)),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ArtText.caption(color: Colors.white),
        ),
      ),
    );
  }
}

class _DividerHandle extends StatelessWidget {
  const _DividerHandle({required this.onDrag, required this.onReset});

  final ValueChanged<double> onDrag;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        onDoubleTap: onReset,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.compare_arrows_rounded,
                size: 20,
                color: ArtColors.brandDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompareNetworkImage extends StatelessWidget {
  const _CompareNetworkImage(this.url);

  final String url;

  @override
  Widget build(BuildContext context) {
    final resolved = MediaUrl.resolve(url);
    if (resolved.isEmpty) {
      return const _BrokenImage();
    }
    return CachedNetworkImage(
      imageUrl: resolved,
      fit: BoxFit.contain,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (context, _) =>
          const Center(child: AppLoadingIndicator(size: 36)),
      errorWidget: (context, _, _) => const _BrokenImage(),
    );
  }
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.broken_image_outlined,
        size: 36,
        color: Colors.white.withValues(alpha: 0.4),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_search_rounded,
              size: 40,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              '暂无可对比的$subject原卷',
              textAlign: TextAlign.center,
              style: ArtText.body(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              '阅卷完成后会自动显示最近一次考试的原卷，\n也可以拍下自己的作品进行对比',
              textAlign: TextAlign.center,
              style: ArtText.caption(
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 14),
            _DarkPillButton(
              icon: Icons.photo_library_outlined,
              label: '从相册选择',
              active: true,
              onTap: onPick,
            ),
          ],
        ),
      ),
    );
  }
}
