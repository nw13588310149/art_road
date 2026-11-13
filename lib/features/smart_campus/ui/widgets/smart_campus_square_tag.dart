import 'package:flutter/material.dart';

import '../../../../core/theme/app_font.dart';
import '../../../shell/ui/shell_layout.dart';

/// 原版方角标签：内距约 4×2 / 高 17、圆角 4、12 号字。
///
/// 对应 R `admin_teacher_management_view.dart` 1149–1179（`_RoleTagChip`）；
/// 复核池原因标签同形（规格表「方角标签」）。胶囊形 [AppTag] 不要用于此场景。
class SmartCampusSquareTag extends StatelessWidget {
  const SmartCampusSquareTag({
    required this.label,
    required this.background,
    required this.foreground,
    this.height = 17,
    this.horizontalPadding = 6,
    this.fontWeight,
    super.key,
  });

  final String label;
  final Color background;
  final Color foreground;
  final double height;
  final double horizontalPadding;
  final FontWeight? fontWeight;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(height),
      padding: EdgeInsets.symmetric(horizontal: ui(horizontalPadding)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: ui(12),
          height: 15.24 / 12,
          color: foreground,
          fontFamily: 'PingFang SC',
          fontWeight: fontWeight ?? AppFont.w400,
        ),
      ),
    );
  }
}
