import 'package:flutter/material.dart';

import '../../../../core/theme/app_font.dart';
import '../../../../core/ui/app_colors.dart';
import '../../../../core/ui/app_image.dart';
import '../../../shell/ui/shell_layout.dart';

/// 原版方头像：圆角 8；空图或失败时浅紫底 + 品牌紫首字。
///
/// 对应 R `admin_teacher_management_view.dart` 1182–1230（`_Avatar`）与
/// `admin_student_management_view.dart` 1319–1368。圆形 [AppAvatar] 不要用于此场景。
class SmartCampusSquareAvatar extends StatelessWidget {
  const SmartCampusSquareAvatar({
    required this.name,
    this.url = '',
    this.size = 40,
    super.key,
  });

  final String name;

  /// 已解析的完整地址；空串走首字占位。
  final String url;

  /// 设计稿逻辑像素；内部再经 [DashboardScaleScope] 缩放。
  final double size;

  static const Color _placeholderBg = Color(0xFFDAD2FF);

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final side = ui(size);
    final initial = name.trim().isEmpty ? '·' : name.trim().characters.first;
    final placeholder = Container(
      width: side,
      height: side,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _placeholderBg,
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: ui(size * 0.4),
          height: 1.0,
          fontWeight: AppFont.w600,
          color: AppColors.brand,
          fontFamily: 'PingFang SC',
        ),
      ),
    );
    final trimmed = url.trim();
    if (trimmed.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(8)),
      child: AppImage(
        src: trimmed,
        width: side,
        height: side,
        fit: BoxFit.cover,
        placeholder: placeholder,
        error: placeholder,
      ),
    );
  }
}
