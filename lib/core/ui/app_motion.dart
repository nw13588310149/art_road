import 'package:flutter/animation.dart';

/// 动效：点击与选中没有任何动画，只有浮层（弹窗、抽屉、气泡、轻提示）可以在
/// 200ms 内淡入或滑入。
abstract final class AppMotion {
  static const Duration overlay = Duration(milliseconds: 180);
  static const Duration overlayMax = Duration(milliseconds: 200);
  static const Curve overlayCurve = Curves.easeOutCubic;
}
