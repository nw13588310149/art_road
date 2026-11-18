import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

import '../../../core/ui/ui.dart';
import 'widgets/gallery_images.dart';

/// 全屏看画：不透明的深色底，看不到下面的页面；画完整显示，可以缩放和旋转。
Future<void> showGalleryViewer(
  BuildContext context, {
  required String src,
  required String title,
  required double aspectRatio,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      fullscreenDialog: true,
      transitionDuration: AppMotion.overlayMax,
      reverseTransitionDuration: AppMotion.overlay,
      pageBuilder: (context, animation, secondaryAnimation) =>
          GalleryViewerPage(src: src, title: title, aspectRatio: aspectRatio),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class GalleryViewerPage extends StatefulWidget {
  const GalleryViewerPage({
    required this.src,
    required this.title,
    required this.aspectRatio,
    super.key,
  });

  final String src;
  final String title;

  /// 宽 / 高，旋转后按新的外接比例完整显示。
  final double aspectRatio;

  @override
  State<GalleryViewerPage> createState() => _GalleryViewerPageState();
}

class _GalleryViewerPageState extends State<GalleryViewerPage> {
  static const _light = AppColors.surface;

  int _quarterTurns = 0;

  void _rotate(int delta) =>
      setState(() => _quarterTurns = (_quarterTurns + delta + 4) % 4);

  @override
  Widget build(BuildContext context) {
    final ratio = widget.aspectRatio > 0 ? widget.aspectRatio : 1.0;
    const base = 1000.0;
    final size = _quarterTurns.isOdd
        ? Size(base, base * ratio)
        : Size(base * ratio, base);
    return Scaffold(
      backgroundColor: AppColors.canvasDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24),
              child: Row(
                children: [
                  AppBackButton(
                    onTap: () => Navigator.of(context).maybePop(),
                    semanticLabel: '关闭',
                    color: _light,
                  ),
                  const SizedBox(width: AppSpace.s4),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.title20.copyWith(color: _light),
                    ),
                  ),
                  AppIconAction(
                    icon: Icons.rotate_left_rounded,
                    semanticLabel: '向左旋转',
                    color: _light,
                    onTap: () => _rotate(-1),
                  ),
                  AppIconAction(
                    icon: Icons.rotate_right_rounded,
                    semanticLabel: '向右旋转',
                    color: _light,
                    onTap: () => _rotate(1),
                  ),
                ],
              ),
            ),
            Expanded(
              child: widget.src.isEmpty
                  ? const GalleryBrokenImage(color: _light)
                  : PhotoView.customChild(
                      key: ValueKey(_quarterTurns),
                      childSize: size,
                      backgroundDecoration: const BoxDecoration(
                        color: AppColors.canvasDark,
                      ),
                      minScale: PhotoViewComputedScale.contained,
                      initialScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.contained * 4,
                      child: RotatedBox(
                        quarterTurns: _quarterTurns,
                        child: Image(
                          image: galleryImageProvider(widget.src),
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.medium,
                          gaplessPlayback: true,
                          errorBuilder: (context, error, stackTrace) =>
                              const GalleryBrokenImage(color: _light),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: AppSpace.s24),
          ],
        ),
      ),
    );
  }
}
