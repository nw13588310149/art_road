import 'package:flutter/material.dart';

import 'app_loading_indicator.dart';

/// Material 下拉刷新指示器默认外框尺寸。
const double kAppRefreshIndicatorSize = 41.0;

/// 下拉刷新区域使用的 GIF 指示器（与全局页面 loading 同源）。
class AppRefreshProgressIndicator extends StatelessWidget {
  const AppRefreshProgressIndicator({
    super.key,
    this.opacity = 1,
    this.semanticsLabel,
    this.semanticsValue,
  });

  final double opacity;
  final String? semanticsLabel;
  final String? semanticsValue;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      value: semanticsValue,
      child: AppLoadingGif(
        size: kAppRefreshIndicatorSize,
        opacity: opacity,
      ),
    );
  }
}
