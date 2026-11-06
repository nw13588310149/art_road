import 'package:flutter/painting.dart';

import '../theme/app_font.dart';
import 'app_colors.dart';

/// 字阶：12 / 13 / 14 / 16 / 20 / 24 / 32，不小于 12。
///
/// 中文样式不指定字族，跟随主题默认字体；字重走 [AppFont] 做 iOS 补偿。
/// 数字用 [number]（Manrope 等宽数字），大号展示数字用 [displayNumber]（Barlow）。
abstract final class AppText {
  static const _tabularFigures = <FontFeature>[FontFeature.tabularFigures()];

  static TextStyle get display32 => _cjk(32, 40, AppFont.w600);
  static TextStyle get title24 => _cjk(24, 32, AppFont.w600);
  static TextStyle get title20 => _cjk(20, 28, AppFont.w600);
  static TextStyle get title16 => _cjk(16, 24, AppFont.w600);
  static TextStyle get body16 => _cjk(16, 24, AppFont.w400);
  static TextStyle get body14 => _cjk(14, 22, AppFont.w400);
  static TextStyle get body14Strong => _cjk(14, 22, AppFont.w500);

  /// 默认二级文字色，用于说明与副标题。
  static TextStyle get body13 =>
      _cjk(13, 20, AppFont.w400, AppColors.textSecondary);

  /// 默认三级文字色，用于辅助信息、时间、计数。
  static TextStyle get caption12 =>
      _cjk(12, 18, AppFont.w400, AppColors.textTertiary);
  static TextStyle get caption12Strong =>
      _cjk(12, 18, AppFont.w500, AppColors.textSecondary);

  /// 数字：Manrope Medium + 等宽数字（字体只打包了 500 字重）。
  static TextStyle number({double size = 16, Color color = AppColors.ink}) =>
      TextStyle(
        fontFamily: 'Manrope',
        fontSize: size,
        height: 1.25,
        fontWeight: FontWeight.w500,
        color: color,
        fontFeatures: _tabularFigures,
        leadingDistribution: TextLeadingDistribution.even,
      );

  /// 大号展示数字（时间、总分、倒计时）：Barlow SemiBold。
  static TextStyle displayNumber({
    double size = 32,
    Color color = AppColors.ink,
  }) => TextStyle(
    fontFamily: 'Barlow',
    fontSize: size,
    height: 1.1,
    fontWeight: FontWeight.w600,
    color: color,
    fontFeatures: _tabularFigures,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static TextStyle _cjk(
    double size,
    double lineHeight,
    FontWeight weight, [
    Color color = AppColors.ink,
  ]) => TextStyle(
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    color: color,
    leadingDistribution: TextLeadingDistribution.even,
  );
}
