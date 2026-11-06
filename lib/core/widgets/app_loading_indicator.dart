import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../theme/app_theme.dart';

/// 与首页 [HomePage] 对齐的全局 loading 尺寸（逻辑像素）。
const double kAppLoadingIndicatorSize = 45;

/// 全局统一的 loading 环粗细（仅 determinate 进度环使用）。
const double kAppLoadingIndicatorStrokeWidth = 2;

/// 全局 loading / 下拉刷新共用的 GIF 动画。
class AppLoadingGif extends StatelessWidget {
  const AppLoadingGif({
    super.key,
    this.size = kAppLoadingIndicatorSize,
    this.opacity = 1,
  });

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      AppAssets.homeLoading,
      width: size,
      height: size,
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );
    if (opacity >= 1) {
      return SizedBox(width: size, height: size, child: image);
    }
    return SizedBox(
      width: size,
      height: size,
      child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: image),
    );
  }
}

/// 项目统一的 loading：默认展示 [AppAssets.homeLoading] GIF；
/// 带 [value] 时用于 determinate 进度（上传、PDF 等），仍为品牌紫圆环。
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.color,
    this.size = kAppLoadingIndicatorSize,
    this.strokeWidth = kAppLoadingIndicatorStrokeWidth,
    this.value,
  });

  final Color? color;
  final double size;
  final double strokeWidth;

  /// `null` 为 indeterminate（GIF）；`0..1` 为 determinate 进度。
  final double? value;

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return AppLoadingGif(size: size);
    }
    final effectiveColor = color ?? AppTheme.brandColor;
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        value: value,
        strokeWidth: strokeWidth,
        color: effectiveColor,
        backgroundColor: effectiveColor.withValues(alpha: 0.12),
      ),
    );
  }
}

/// 页面初次进入 loading：相对 [child] 主容器全区域居中指示器（保留 header/tab 等），
/// 不依据下方列表/网格渲染区定位。
class PageInitLoadingShell extends StatelessWidget {
  const PageInitLoadingShell({
    super.key,
    required this.loading,
    required this.child,
    this.scrimColor = Colors.transparent,
  });

  final bool loading;
  final Widget child;

  /// loading 蒙层底色；传 [Colors.transparent] 可只保留居中指示器。
  final Color scrimColor;

  @override
  Widget build(BuildContext context) {
    return MainContentLoadingShell(
      loading: loading,
      preserveChrome: true,
      scrimColor: scrimColor,
      child: child,
    );
  }
}

/// 主内容区统一 loading：整区只显示一个指示器，避免多个列表/分区各自转圈。
///
/// [preserveChrome] 为 true 时 loading 期间仍渲染 [child]（保留 banner/tab 等），
/// 并在其上覆盖居中 loading（默认无遮罩）。初次进入请优先 [PageInitLoadingShell]。
class MainContentLoadingShell extends StatelessWidget {
  const MainContentLoadingShell({
    super.key,
    required this.loading,
    required this.child,
    this.preserveChrome = false,
    this.minHeight,
    this.scrimColor = Colors.transparent,
  });

  final bool loading;
  final Widget child;
  final bool preserveChrome;
  final double? minHeight;

  /// loading 蒙层底色；传 [Colors.transparent] 可只保留居中指示器。
  final Color scrimColor;

  @override
  Widget build(BuildContext context) {
    if (!loading) {
      return child;
    }
    if (preserveChrome) {
      return Stack(
        children: [
          child,
          Positioned.fill(
            child: AppLoadingOverlay(scrimColor: scrimColor),
          ),
        ],
      );
    }
    final body = const Center(child: AppLoadingIndicator());
    if (minHeight != null) {
      return SizedBox(height: minHeight, child: body);
    }
    return body;
  }
}

/// 全屏 loading 层：默认仅居中 GIF，不铺白色遮罩。
class AppLoadingOverlay extends StatelessWidget {
  const AppLoadingOverlay({
    super.key,
    this.size,
    this.scrimColor = Colors.transparent,
    this.ignorePointer = true,
  });

  final double? size;
  final Color scrimColor;
  final bool ignorePointer;

  @override
  Widget build(BuildContext context) {
    final body = ColoredBox(
      color: scrimColor,
      child: Center(
        child: AppLoadingGif(size: size ?? kAppLoadingIndicatorSize),
      ),
    );
    return ignorePointer ? IgnorePointer(child: body) : body;
  }
}
