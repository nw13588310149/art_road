import 'package:flutter/painting.dart';

/// 阴影只给浮起的东西：浮层、下拉、分段选中块与开关圆钮。卡片静止时不叠阴影。
abstract final class AppShadow {
  /// 弹窗、抽屉、轻提示。
  static const overlay = <BoxShadow>[
    BoxShadow(color: Color(0x291B2664), blurRadius: 40, offset: Offset(0, 16)),
    BoxShadow(color: Color(0x0F1B2664), blurRadius: 6, offset: Offset(0, 2)),
  ];

  /// 下拉菜单、气泡。
  static const popover = <BoxShadow>[
    BoxShadow(color: Color(0x1F000000), blurRadius: 32, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  /// 分段控件选中块。
  static const thumb = <BoxShadow>[
    BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x0A000000), blurRadius: 1, offset: Offset(0, 1)),
  ];

  /// 开关圆钮。
  static const knob = <BoxShadow>[
    BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 3)),
    BoxShadow(color: Color(0x0F000000), blurRadius: 1, offset: Offset(0, 3)),
  ];
}
