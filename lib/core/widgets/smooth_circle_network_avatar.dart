import 'package:flutter/material.dart';

/// 网络圆形头像。
///
/// iPad 等高分屏上若仅用默认 [ClipOval] + [Image.network]，圆形边缘易出现
/// 锯齿/毛边。此处统一：
/// - [Clip.antiAliasWithSaveLayer] 裁圆；
/// - [FilterQuality.medium] 缩放采样；
/// - [cacheWidth]/[cacheHeight] 按 DPR 解码，避免过小位图被放大。
class SmoothCircleNetworkAvatar extends StatelessWidget {
  const SmoothCircleNetworkAvatar({
    super.key,
    required this.url,
    required this.size,
    this.placeholder,
    this.filterQuality = FilterQuality.medium,
  });

  final String url;
  final double size;
  final Widget? placeholder;
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final decodePx = (size * dpr).round().clamp(48, 256);

    final Widget inner;
    if (trimmed.isEmpty) {
      inner = placeholder ?? _defaultPlaceholder(size);
    } else {
      inner = Image.network(
        trimmed,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: filterQuality,
        cacheWidth: decodePx,
        cacheHeight: decodePx,
        errorBuilder: (_, _, _) => placeholder ?? _defaultPlaceholder(size),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        clipBehavior: Clip.antiAliasWithSaveLayer,
        child: inner,
      ),
    );
  }

  static Widget _defaultPlaceholder(double size) => Container(
    color: const Color(0xFFEAE5FF),
    alignment: Alignment.center,
    child: Icon(
      Icons.person,
      color: const Color(0xFF8741FF),
      size: size * 0.55,
    ),
  );
}
