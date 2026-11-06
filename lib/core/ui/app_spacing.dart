import 'package:flutter/painting.dart';

/// 间距阶梯：4 / 8 / 12 / 16 / 20 / 24 / 32。
abstract final class AppSpace {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;

  /// 页面左右版心。
  static const double page = s20;

  /// 卡片内距。
  static const double card = s16;
}

/// 圆角：按钮与控件 8，卡片与弹窗 12，大面板 16，标签与筛选胶囊 999。
abstract final class AppRadius {
  static const double checkbox = 4;
  static const double control = 8;
  static const double card = 12;
  static const double panel = 16;
  static const double pill = 999;

  static const BorderRadius br4 = BorderRadius.all(Radius.circular(checkbox));
  static const BorderRadius br8 = BorderRadius.all(Radius.circular(control));
  static const BorderRadius br12 = BorderRadius.all(Radius.circular(card));
  static const BorderRadius br16 = BorderRadius.all(Radius.circular(panel));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(pill));
}

/// 控件尺寸。
abstract final class AppSize {
  static const double buttonMd = 44;
  static const double buttonSm = 34;

  /// 输入框、下拉、分段控件。
  static const double control = 34;
  static const double controlSm = 30;

  static const double iconButton = 40;
  static const double iconButtonSm = 34;
  static const double tag = 22;

  static const double dialog = 420;
  static const double dialogWide = 560;
  static const double drawer = 420;
  static const double drawerWide = 560;

  /// iPad 横屏设计基准。
  static const double designWidth = 1180;
  static const double designHeight = 820;
}

/// 禁用态统一降到 40% 不透明度。
abstract final class AppOpacity {
  static const double disabled = 0.4;
}

/// 按钮尺寸：md 44 高（图标按钮 40），sm 34 高（图标按钮 34）。
enum AppButtonSize { md, sm }

/// 输入框、下拉、分段控件尺寸：md 34 高，sm 30 高。
enum AppControlSize { md, sm }
