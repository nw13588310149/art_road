import 'package:flutter/painting.dart';

/// 美术之路统一色板，与艺考网机构端 `tokens.css` 对齐。
///
/// 品牌紫只用于主操作、选中态、关键数字和链接；其余界面走墨色与中性灰。
abstract final class AppColors {
  static const brand = Color(0xFF715EFE);
  static const brandDeep = Color(0xFF5D45ED);
  static const brandSoft = Color(0xFF9585FF);
  static const brandTint = Color(0xFFE3DFFF);
  static const brandWash = Color(0xFFF5F3FF);

  /// 一级文字、图标。
  static const ink = Color(0xFF0B081A);
  static const textSecondary = Color(0xFF6D6B75);
  static const textTertiary = Color(0xFF8B8993);

  /// 占位文字与禁用文字。
  static const textPlaceholder = Color(0xFFB6B5BB);

  /// 品牌紫、语义色实底上的文字。
  static const onBrand = Color(0xFFFFFFFF);

  static const page = Color(0xFFEFF3FC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSubtle = Color(0xFFF5F6FA);

  /// 输入框、次按钮描边与分隔线。
  static const line = Color(0xFFEAEAEA);

  /// 卡片描边与卡内细分隔。
  static const lineSoft = Color(0xFFF3F2F3);

  static const success = Color(0xFF16A37A);
  static const successSoft = Color(0xFFE6F8F1);
  static const warning = Color(0xFFB56B09);
  static const warningSoft = Color(0xFFFFF5DB);
  static const danger = Color(0xFFE5323B);
  static const dangerSoft = Color(0xFFFFEDED);
  static const info = brand;
  static const infoSoft = brandWash;

  /// 弹窗、抽屉的遮罩。
  static const scrim = Color(0x4D0B081A);

  /// 自定义色（科目色、课程色）在白底上的浅底。
  static Color tint(Color color, [double alpha = 0.12]) =>
      Color.alphaBlend(color.withValues(alpha: alpha), surface);
}

/// 语义色调：标签、状态、提示统一按「浅底深字」取色。
enum AppTone {
  neutral(AppColors.textSecondary, AppColors.surfaceSubtle),
  brand(AppColors.brandDeep, AppColors.brandTint),
  success(AppColors.success, AppColors.successSoft),
  warning(AppColors.warning, AppColors.warningSoft),
  danger(AppColors.danger, AppColors.dangerSoft),
  info(AppColors.info, AppColors.infoSoft);

  const AppTone(this.foreground, this.background);

  final Color foreground;
  final Color background;
}
