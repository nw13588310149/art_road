import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../network/media_url.dart';
import 'app_colors.dart';

/// 图片：统一处理网络地址、后端相对路径、打包资源（`assets/...`）与演示数据引用
/// （`asset:assets/...`），加载中显示浅灰占位，失败显示占位图标，加载完成直接显示。
class AppImage extends StatelessWidget {
  const AppImage({
    required this.src,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.borderRadius,
    this.placeholder,
    this.error,
    super.key,
  });

  final String src;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final BorderRadius? borderRadius;

  /// 加载中与地址为空时显示；默认浅灰底。
  final Widget? placeholder;

  /// 加载失败时显示；默认浅灰底 + 裂图图标。
  final Widget? error;

  /// `asset:` 引用与 `assets/` 路径返回资源名，其余返回 null。
  static String? assetKeyOf(String src) {
    final value = src.trim();
    if (value.startsWith('asset:')) {
      return value.substring('asset:'.length);
    }
    if (value.startsWith('assets/')) {
      return value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final value = src.trim();
    final assetKey = assetKeyOf(value);
    Widget child;
    if (value.isEmpty) {
      child = placeholder ?? _fallback(Icons.image_outlined);
    } else if (assetKey != null) {
      child = Image.asset(
        assetKey,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        frameBuilder: (context, image, frame, synchronous) =>
            frame == null && !synchronous ? _loading() : image,
        errorBuilder: (context, _, _) =>
            error ?? _fallback(Icons.broken_image_outlined),
      );
    } else {
      child = CachedNetworkImage(
        imageUrl: MediaUrl.resolve(value),
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (context, _) => _loading(),
        errorWidget: (context, _, _) =>
            error ?? _fallback(Icons.broken_image_outlined),
      );
    }
    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return SizedBox(width: width, height: height, child: child);
  }

  Widget _loading() => placeholder ?? _fallback(null);

  Widget _fallback(IconData? icon) {
    return Container(
      width: width,
      height: height,
      color: AppColors.surfaceSubtle,
      alignment: Alignment.center,
      child: icon == null
          ? null
          : Icon(icon, size: 24, color: AppColors.textPlaceholder),
    );
  }
}
