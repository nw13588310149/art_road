import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

import '../network/media_url.dart';
import '../ui/ui.dart';

/// 看图页的图片地址规则，和 `AppImage` 一致：打包资源走 `AssetImage`，`blob:` / `data:`
/// 直接读，其余按网络图加载（带 [headers] 时一起发送）。解码时长边不超过 [maxExtent]。
ImageProvider imageViewerProvider(
  String src, {
  Map<String, String>? headers,
  int? maxExtent,
}) {
  final value = src.trim();
  final assetKey = AppImage.assetKeyOf(value);
  final ImageProvider base;
  if (assetKey != null) {
    base = AssetImage(assetKey);
  } else {
    final url = MediaUrl.resolve(value);
    if (url.startsWith('data:')) {
      base = MemoryImage(UriData.parse(url).contentAsBytes());
    } else if (url.startsWith('blob:')) {
      base = NetworkImage(url, headers: headers);
    } else {
      base = CachedNetworkImageProvider(url, headers: headers);
    }
  }
  if (maxExtent == null) {
    return base;
  }
  return ResizeImage(
    base,
    width: maxExtent,
    height: maxExtent,
    policy: ResizeImagePolicy.fit,
    allowUpscaling: false,
  );
}

/// 每个图片像素在屏幕上的长度：缩放过就取 PhotoView 的倍数，否则是完整显示时的倍数。
class _ViewerScale extends ChangeNotifier implements ValueListenable<double> {
  _ViewerScale(this.controller) {
    _subscription = controller.outputStateStream.listen((_) {
      notifyListeners();
    });
  }

  final PhotoViewController controller;
  late final StreamSubscription<PhotoViewControllerValue> _subscription;
  double fallback = 1;

  @override
  double get value => controller.scale ?? fallback;

  @override
  void dispose() {
    _subscription.cancel();
    controller.dispose();
    super.dispose();
  }
}

/// 看图页的一页：加载一张图，完整显示，可以双指缩放、双击放大、拖动；按 [quarterTurns] 旋转。
///
/// 画面在图片自己的坐标系里搭（[builder]），叠加的网格、标记随缩放、平移、旋转一起走。
/// 这一页持有解码后的图片，卸载时释放；[onImage] 告诉看图页这张图可以用了。
class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({
    required this.index,
    required this.provider,
    required this.quarterTurns,
    required this.semanticLabel,
    required this.onImage,
    this.builder,
    this.onTap,
    super.key,
  });

  final int index;
  final ImageProvider provider;
  final int quarterTurns;
  final String semanticLabel;
  final void Function(int index, ui.Image? image) onImage;
  final Widget Function(
    BuildContext context,
    ui.Image image,
    ValueListenable<double> scale,
  )?
  builder;

  /// 点在图片上的相对位置（0–1，图片自己的方向）。
  final ValueChanged<Offset>? onTap;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(
    _onFrame,
    onError: _onError,
  );
  ImageInfo? _info;
  bool _failed = false;
  _ViewerScale _scale = _ViewerScale(PhotoViewController());
  final GlobalKey _picture = GlobalKey();

  /// PhotoView 先按视口大小排版、再整体缩放画面，画面超出视口的部分在命中测试里点不到；
  /// 所以由 PhotoView 自己接单击，再用坐标变换换算到图片上。
  void _handleTap(TapUpDetails details) {
    final onTap = widget.onTap;
    final box = _picture.currentContext?.findRenderObject();
    if (onTap == null || box is! RenderBox || !box.hasSize) {
      return;
    }
    final local = box.globalToLocal(details.globalPosition);
    final size = box.size;
    if (!(Offset.zero & size).contains(local)) {
      return;
    }
    onTap(Offset(local.dx / size.width, local.dy / size.height));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ImageViewerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider != widget.provider) {
      _resolve();
    }
    if (oldWidget.quarterTurns != widget.quarterTurns) {
      // 旋转后从完整显示重新开始。
      final previous = _scale;
      _scale = _ViewerScale(PhotoViewController());
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  void _resolve() {
    final stream = widget.provider.resolve(
      createLocalImageConfiguration(context),
    );
    if (stream.key == _stream?.key) {
      return;
    }
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  void _onFrame(ImageInfo info, bool synchronousCall) {
    final previous = _info;
    void apply() {
      if (!mounted) {
        info.dispose();
        return;
      }
      setState(() {
        _info = info;
        _failed = false;
      });
      widget.onImage(widget.index, info.image);
      previous?.dispose();
    }

    // 缓存里已有的图会在解析时同步回调，那时还在构建，推到这一帧之后。
    if (synchronousCall) {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
  }

  void _onError(Object error, StackTrace? stackTrace) {
    if (mounted) {
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    widget.onImage(widget.index, null);
    _info?.dispose();
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    if (info == null) {
      return Center(
        child: _failed
            ? const _BrokenImage()
            : const AppLoadingIndicator(color: AppColors.onCanvasDark),
      );
    }
    final image = info.image;
    final width = image.width.toDouble();
    final height = image.height.toDouble();
    final turns = widget.quarterTurns % 4;
    final childSize = turns.isOdd ? Size(height, width) : Size(width, height);
    final scale = _scale;
    return LayoutBuilder(
      builder: (context, constraints) {
        // 完整显示时四周留一点空，放大后仍可以用满整块画面。
        final fitSize = Size(
          math.max(1, constraints.maxWidth - 2 * AppSpace.s24),
          math.max(1, constraints.maxHeight - 2 * AppSpace.s16),
        );
        scale.fallback = math.min(
          fitSize.width / childSize.width,
          fitSize.height / childSize.height,
        );
        return Semantics(
          image: true,
          label: widget.semanticLabel,
          child: PhotoView.customChild(
            key: ValueKey(scale),
            controller: scale.controller,
            childSize: childSize,
            customSize: fitSize,
            backgroundDecoration: const BoxDecoration(
              color: AppColors.canvasDark,
            ),
            minScale: PhotoViewComputedScale.contained,
            initialScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.contained * 8,
            // 只有 none 时 PhotoView 才用矩阵缩放自定义子组件；画面清晰度由 RawImage 自己的 filterQuality 决定。
            filterQuality: FilterQuality.none,
            onTapUp: widget.onTap == null
                ? null
                : (context, details, value) => _handleTap(details),
            child: RotatedBox(
              quarterTurns: turns,
              child: SizedBox(
                key: _picture,
                width: width,
                height: height,
                child:
                    widget.builder?.call(context, image, scale) ??
                    RawImage(
                      image: image,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.medium,
                    ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.broken_image_outlined,
          size: 48,
          color: AppColors.onCanvasDarkMuted,
        ),
        const SizedBox(height: AppSpace.s8),
        Text(
          '图片加载失败',
          style: AppText.body14.copyWith(color: AppColors.onCanvasDarkMuted),
        ),
      ],
    );
  }
}
