import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import '../ui/ui.dart';
import 'image_viewer_page.dart';
import 'image_viewer_tools.dart';

export 'image_viewer_tools.dart';

/// 看图页的路由名。随页工具栏据此在看图时让开（看图页有自己的工具）。
const imageViewerRouteName = '/image-viewer';

/// 全屏看图：应用里所有「点图放大」都走这里。
///
/// 不透明的深色底，看不到下面的页面；顶栏是关闭、名称、第几张和旋转；画完整显示，
/// 双指缩放、双击放大、左右滑或方向键翻页。[tools] 为 true 且 App 注入了
/// [imageViewerToolkitProvider] 时，画面下方是看画工具（灰度、明度色阶、眯眼模糊等）。
///
/// - [titles]：每张图的名称；只给一个时所有图共用。
/// - [headers]：网络图需要鉴权时一起发送。
/// - [tools]：证件照、人脸照片这类不需要看画工具的图传 false。
/// - [heroTagPrefix]：保留给旧的调用方，看图页只淡入，不做 Hero 转场。
///
/// ```dart
/// showImageGallery(
///   context,
///   images: ['https://...', 'asset:assets/demo/art/sketch-bust-1.jpg'],
///   initialIndex: 1,
///   titles: ['作业原图', '大卫石膏像'],
/// );
/// ```
Future<void> showImageGallery(
  BuildContext context, {
  required List<String> images,
  int initialIndex = 0,
  String heroTagPrefix = 'image_gallery',
  List<String> titles = const <String>[],
  Map<String, String>? headers,
  bool tools = true,
}) async {
  if (images.isEmpty) {
    return;
  }
  await Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      settings: const RouteSettings(name: imageViewerRouteName),
      fullscreenDialog: true,
      transitionDuration: AppMotion.overlayMax,
      reverseTransitionDuration: AppMotion.overlay,
      pageBuilder: (context, animation, secondaryAnimation) =>
          ImageGalleryViewer(
            images: images,
            initialIndex: initialIndex,
            heroTagPrefix: heroTagPrefix,
            titles: titles,
            headers: headers,
            tools: tools,
          ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// 与 [showImageGallery] 配合使用的看图页，也可以单独放进一个路由。
class ImageGalleryViewer extends ConsumerStatefulWidget {
  const ImageGalleryViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.heroTagPrefix = 'image_gallery',
    this.titles = const <String>[],
    this.headers,
    this.tools = true,
  });

  final List<String> images;
  final int initialIndex;
  final String heroTagPrefix;
  final List<String> titles;
  final Map<String, String>? headers;
  final bool tools;

  @override
  ConsumerState<ImageGalleryViewer> createState() => _ImageGalleryViewerState();
}

class _ImageGalleryViewerState extends ConsumerState<ImageGalleryViewer> {
  late final PageController _pages;
  final FocusNode _focus = FocusNode(debugLabel: 'Image viewer');
  late int _index;
  int _quarterTurns = 0;
  ImageViewerToolSession? _session;

  /// 已加载的页交来的图片（归各页所有），切换时交给工具会话。
  final Map<int, ui.Image> _images = <int, ui.Image>{};
  final Map<String, ImageProvider> _providers = <String, ImageProvider>{};

  int get _count => widget.images.length;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, math.max(0, _count - 1));
    _pages = PageController(initialPage: _index);
    if (widget.tools) {
      _session = ref.read(imageViewerToolkitProvider)?.createSession()
        ?..show(_item(_index), null)
        ..addListener(_toolsChanged);
    }
    // 方向键和 Esc 要落在看图页上，打开时不管焦点原来在哪都拿过来。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _session
      ?..removeListener(_toolsChanged)
      ..dispose();
    _pages.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _toolsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  ImageViewerItem _item(int index) {
    final titles = widget.titles;
    final title = titles.length == _count
        ? titles[index]
        : (titles.length == 1 ? titles.first : '');
    return ImageViewerItem(
      index: index,
      src: widget.images[index],
      title: title.trim(),
    );
  }

  ImageProvider _provider(BuildContext context, String src) {
    final viewport = MediaQuery.sizeOf(context);
    final extent =
        (math.max(viewport.width, viewport.height) *
                MediaQuery.devicePixelRatioOf(context))
            .ceil()
            .clamp(1, 4096);
    return _providers.putIfAbsent(
      '$src@$extent',
      () =>
          imageViewerProvider(src, headers: widget.headers, maxExtent: extent),
    );
  }

  void _onImage(int index, ui.Image? image) {
    if (image == null) {
      _images.remove(index);
      return;
    }
    _images[index] = image;
    if (index == _index) {
      _session?.show(_item(index), image);
    }
  }

  void _onPageChanged(int index) {
    setState(() => _index = index);
    _session?.show(_item(index), _images[index]);
  }

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= _count) {
      return;
    }
    _pages.jumpToPage(next);
  }

  void _rotate(int delta) =>
      setState(() => _quarterTurns = (_quarterTurns + delta + 4) % 4);

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final item = _item(_index);
    final session = _session;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go(1),
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: Material(
          color: AppColors.canvasDark,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ViewerTopBar(
                  title: item.title,
                  index: _index,
                  count: _count,
                  onClose: _close,
                  onPrevious: _index > 0 ? () => _go(-1) : null,
                  onNext: _index < _count - 1 ? () => _go(1) : null,
                  onRotate: _rotate,
                ),
                Expanded(child: _buildPages()),
                if (session != null) session.buildBar(context, item),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPages() {
    final session = _session;
    return ScrollConfiguration(
      behavior: const MaterialScrollBehavior().copyWith(
        dragDevices: <PointerDeviceKind>{
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      child: PhotoViewGestureDetectorScope(
        axis: Axis.horizontal,
        child: PageView.builder(
          controller: _pages,
          itemCount: _count,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) {
            final item = _item(index);
            return ClipRect(
              child: ImageViewerPage(
                key: ValueKey('${item.index}:${item.src}'),
                index: index,
                provider: _provider(context, item.src),
                quarterTurns: _quarterTurns,
                semanticLabel: item.title.isEmpty
                    ? '图片 ${index + 1} / $_count'
                    : item.title,
                onImage: _onImage,
                builder: session == null
                    ? null
                    : (context, image, scale) =>
                          session.buildImage(context, item, image, scale),
                onTap: session == null
                    ? null
                    : (position) => session.tapImage(item, position),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 顶栏：关闭、名称、第几张（多张时带上一张 / 下一张）、旋转。
class _ViewerTopBar extends StatelessWidget {
  const _ViewerTopBar({
    required this.title,
    required this.index,
    required this.count,
    required this.onClose,
    required this.onPrevious,
    required this.onNext,
    required this.onRotate,
  });

  final String title;
  final int index;
  final int count;
  final VoidCallback onClose;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<int> onRotate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24),
        child: Row(
          children: [
            AppBackButton(
              onTap: onClose,
              semanticLabel: '关闭',
              color: AppColors.onCanvasDark,
            ),
            const SizedBox(width: AppSpace.s4),
            Expanded(
              child: Row(
                children: [
                  if (title.isNotEmpty)
                    Flexible(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.title20.copyWith(
                            color: AppColors.onCanvasDark,
                          ),
                        ),
                      ),
                    ),
                  if (count > 1) ...[
                    SizedBox(width: title.isEmpty ? 0 : AppSpace.s16),
                    AppIconAction(
                      icon: Icons.chevron_left_rounded,
                      semanticLabel: '上一张',
                      color: AppColors.onCanvasDark,
                      onTap: onPrevious,
                    ),
                    Text(
                      '${index + 1} / $count',
                      semanticsLabel: '第 ${index + 1} 张，共 $count 张',
                      style: AppText.number(
                        size: 14,
                        color: AppColors.onCanvasDarkMuted,
                      ),
                    ),
                    AppIconAction(
                      icon: Icons.chevron_right_rounded,
                      semanticLabel: '下一张',
                      color: AppColors.onCanvasDark,
                      onTap: onNext,
                    ),
                  ],
                ],
              ),
            ),
            AppIconAction(
              icon: Icons.rotate_left_rounded,
              semanticLabel: '向左旋转',
              color: AppColors.onCanvasDark,
              onTap: () => onRotate(-1),
            ),
            AppIconAction(
              icon: Icons.rotate_right_rounded,
              semanticLabel: '向右旋转',
              color: AppColors.onCanvasDark,
              onTap: () => onRotate(1),
            ),
          ],
        ),
      ),
    );
  }
}
