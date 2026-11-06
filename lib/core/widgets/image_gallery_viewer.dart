import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';
import 'package:flutter/gestures.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

/// 全屏图片查看器：半透明黑底 + PhotoViewGallery，支持
/// 双击 / 捏合缩放、左右滑切换、Hero 转场、按钮 90° 旋转（旋转后自动
/// 按最大可视区域等比适配；本次预览内所有图片共享同一旋转角度，关闭后恢复）。
///
/// 使用方法：
/// ```dart
/// showImageGallery(
///   context,
///   images: ['https://...', 'https://...'],
///   initialIndex: 0,
///   heroTagPrefix: 'theory_assignment',
/// );
/// ```
Future<void> showImageGallery(
  BuildContext context, {
  required List<String> images,
  int initialIndex = 0,
  String heroTagPrefix = 'image_gallery',
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) =>
          ImageGalleryViewer(
            images: images,
            initialIndex: initialIndex,
            heroTagPrefix: heroTagPrefix,
          ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// 与 [showImageGallery] 配合使用的全屏图片查看器组件。也可以单独使用。
class ImageGalleryViewer extends StatefulWidget {
  const ImageGalleryViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.heroTagPrefix = 'image_gallery',
  });

  final List<String> images;
  final int initialIndex;
  final String heroTagPrefix;

  @override
  State<ImageGalleryViewer> createState() => _ImageGalleryViewerState();
}

class _ImageGalleryViewerState extends State<ImageGalleryViewer> {
  late final PageController _controller;
  late final List<PhotoViewController> _photoControllers;
  late final List<PhotoViewScaleStateController> _scaleStateControllers;
  int _quarterTurns = 0;
  final Map<int, Size> _imageSizes = <int, Size>{};
  final Set<int> _sizeResolveStarted = <int>{};
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
    _photoControllers = List<PhotoViewController>.generate(
      widget.images.length,
      (_) => PhotoViewController(),
    );
    _scaleStateControllers = List<PhotoViewScaleStateController>.generate(
      widget.images.length,
      (_) => PhotoViewScaleStateController(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefetchImageSizes());
  }

  @override
  void dispose() {
    for (final photoController in _photoControllers) {
      photoController.dispose();
    }
    for (final scaleStateController in _scaleStateControllers) {
      scaleStateController.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  void _prefetchImageSizes() {
    if (!mounted) {
      return;
    }
    for (var index = 0; index < widget.images.length; index++) {
      _beginResolveImageSize(
        index,
        _galleryImageProvider(context, widget.images[index]),
      );
    }
  }

  void _beginResolveImageSize(int index, ImageProvider provider) {
    if (_sizeResolveStarted.contains(index)) {
      return;
    }
    _sizeResolveStarted.add(index);
    final stream = provider.resolve(createLocalImageConfiguration(context));
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        stream.removeListener(listener);
        if (!mounted) {
          return;
        }
        setState(() {
          _imageSizes[index] = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
        });
      },
      onError: (Object _, StackTrace? stackTrace) {
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
  }

  /// 像素尺寸归一化为逻辑比例（长边 = 1），与视口单位一致。
  Size _toLogicalSize(Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return const Size(1, 1);
    }
    if (size.width >= size.height) {
      return Size(1, size.height / size.width);
    }
    return Size(size.width / size.height, 1);
  }

  /// 旋转后的外接矩形（逻辑尺寸）。
  Size _effectiveLogicalSize(Size layoutSize, int quarterTurns) {
    if (quarterTurns.isOdd) {
      return Size(layoutSize.height, layoutSize.width);
    }
    return layoutSize;
  }

  /// 宽/高较大一侧贴近视口，不拉伸。
  double _containedScale(Size viewport, Size effectiveLogicalSize) {
    return math.min(
      viewport.width / effectiveLogicalSize.width,
      viewport.height / effectiveLogicalSize.height,
    );
  }

  PhotoViewGalleryPageOptions _buildPageOptions(
    BuildContext context,
    int index,
    ImageProvider imageProvider,
  ) {
    final image = widget.images[index];
    final heroTag = '${widget.heroTagPrefix}_${image}_$index';
    final imageSize = _imageSizes[index];

    if (imageSize != null && _quarterTurns != 0) {
      final viewport = MediaQuery.sizeOf(context);
      final layoutSize = _toLogicalSize(imageSize);
      final effectiveSize =
          _effectiveLogicalSize(layoutSize, _quarterTurns);
      final fittedScale = _containedScale(viewport, effectiveSize);

      return PhotoViewGalleryPageOptions.customChild(
        controller: _photoControllers[index],
        scaleStateController: _scaleStateControllers[index],
        child: Transform.rotate(
          angle: _quarterTurns * math.pi / 2,
          child: SizedBox(
            width: layoutSize.width,
            height: layoutSize.height,
            child: Image(
              image: imageProvider,
              fit: BoxFit.fill,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 48,
                ),
              ),
            ),
          ),
        ),
        childSize: layoutSize,
        minScale: fittedScale,
        maxScale: fittedScale * 4,
        initialScale: fittedScale,
        filterQuality: FilterQuality.none,
        heroAttributes: PhotoViewHeroAttributes(tag: heroTag),
      );
    }

    return PhotoViewGalleryPageOptions(
      controller: _photoControllers[index],
      scaleStateController: _scaleStateControllers[index],
      imageProvider: imageProvider,
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 4,
      initialScale: PhotoViewComputedScale.contained,
      filterQuality: FilterQuality.medium,
      heroAttributes: PhotoViewHeroAttributes(tag: heroTag),
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.white54,
          size: 48,
        ),
      ),
    );
  }

  void _resetPhotoViewStates() {
    for (var index = 0; index < _photoControllers.length; index++) {
      _photoControllers[index].updateMultiple(
        scale: null,
        position: Offset.zero,
        rotation: 0,
        rotationFocusPoint: null,
      );
      _scaleStateControllers[index].reset();
    }
  }

  void _rotateByQuarterTurns(int delta) {
    _resetPhotoViewStates();
    setState(() {
      _quarterTurns = (_quarterTurns + delta + 4) % 4;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaPadding = MediaQuery.of(context).padding;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          GestureBinding.instance.pointerSignalResolver.register(event, (_) {});
        }
      },
      child: Material(
        color: Colors.black87,
        child: SizedBox.expand(
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: ScrollConfiguration(
                  behavior: const MaterialScrollBehavior().copyWith(
                    dragDevices: <PointerDeviceKind>{
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  child: PhotoViewGallery.builder(
                    pageController: _controller,
                    itemCount: widget.images.length,
                    scrollPhysics: const BouncingScrollPhysics(),
                    backgroundDecoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                    loadingBuilder: (context, progress) {
                      if (progress == null) {
                        return const SizedBox.shrink();
                      }
                      return const Center(
                        child: AppLoadingIndicator(color: Colors.white),
                      );
                    },
                    onPageChanged: (i) {
                      setState(() => _currentIndex = i);
                      if (_quarterTurns != 0) {
                        _photoControllers[i].updateMultiple(
                          scale: null,
                          position: Offset.zero,
                          rotation: 0,
                          rotationFocusPoint: null,
                        );
                        _scaleStateControllers[i].reset();
                      }
                    },
                    builder: (context, index) {
                      final imageProvider = _galleryImageProvider(
                        context,
                        widget.images[index],
                      );
                      _beginResolveImageSize(index, imageProvider);
                      // 旋转走 Transform.rotate + 逻辑 childSize，并按旋转后外接矩形
                      // 显式计算 contained 缩放（长边贴近视口，不拉伸）。
                      return _buildPageOptions(context, index, imageProvider);
                    },
                  ),
                ),
              ),
              Positioned(
                top: mediaPadding.top + 12,
                right: 16,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: mediaPadding.bottom + 18,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _GalleryToolbarButton(
                        icon: Icons.rotate_left_rounded,
                        onTap: () => _rotateByQuarterTurns(-1),
                      ),
                      if (widget.images.length > 1) ...<Widget>[
                        const SizedBox(width: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_currentIndex + 1}/${widget.images.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontFamily: 'Manrope',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                      ] else
                        const SizedBox(width: 14),
                      _GalleryToolbarButton(
                        icon: Icons.rotate_right_rounded,
                        onTap: () => _rotateByQuarterTurns(1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalleryToolbarButton extends StatelessWidget {
  const _GalleryToolbarButton({
    required this.icon,
    required this.onTap,
  });

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
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

/// 画廊网络图：仅按视口较长边限制解码宽度，高度随原图比例缩放。
ImageProvider _galleryImageProvider(BuildContext context, String url) {
  final viewport = MediaQuery.sizeOf(context);
  final longestSide = viewport.width > viewport.height
      ? viewport.width
      : viewport.height;
  final cacheWidth = _galleryDecodeExtent(context, longestSide, 4096);
  if (cacheWidth == null) {
    return NetworkImage(url);
  }
  return ResizeImage(
    NetworkImage(url),
    width: cacheWidth,
  );
}

int? _galleryDecodeExtent(
  BuildContext context,
  double logicalExtent,
  int maxPixels,
) {
  if (!logicalExtent.isFinite || logicalExtent <= 0) {
    return null;
  }
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return (logicalExtent * dpr).ceil().clamp(1, maxPixels).toInt();
}
