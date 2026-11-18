import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

import '../../../../core/network/media_url.dart';
import '../../../../core/ui/ui.dart';

/// 和 `AppImage` 同样的地址规则：打包资源走 `AssetImage`，其余按网络图加载。
ImageProvider galleryImageProvider(String src) {
  final assetKey = AppImage.assetKeyOf(src);
  if (assetKey != null) {
    return AssetImage(assetKey);
  }
  return CachedNetworkImageProvider(MediaUrl.resolve(src));
}

/// 可缩放的一幅画：完整显示，双指 / 双击放大，底色和画布一致。
class GalleryZoomImage extends StatelessWidget {
  const GalleryZoomImage({
    required this.src,
    this.background = AppColors.canvas,
    super.key,
  });

  final String src;
  final Color background;

  @override
  Widget build(BuildContext context) {
    if (src.isEmpty) {
      return const GalleryBrokenImage();
    }
    return PhotoView(
      key: ValueKey(src),
      imageProvider: galleryImageProvider(src),
      backgroundDecoration: BoxDecoration(color: background),
      minScale: PhotoViewComputedScale.contained,
      initialScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 3,
      filterQuality: FilterQuality.medium,
      loadingBuilder: (context, event) =>
          const Center(child: AppLoadingIndicator()),
      errorBuilder: (context, error, stackTrace) => const GalleryBrokenImage(),
    );
  }
}

/// 图片加载失败。
class GalleryBrokenImage extends StatelessWidget {
  const GalleryBrokenImage({this.color = AppColors.textTertiary, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.broken_image_outlined,
        size: 48,
        color: color,
        semanticLabel: '图片加载失败',
      ),
    );
  }
}
