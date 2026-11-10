import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_font.dart';
import '../ui/app_colors.dart';
import '../ui/app_spacing.dart';
import '../ui/app_text.dart';
import '../widgets/app_loading_indicator.dart';

class AppTheme {
  static const _primaryColor = brandColor;

  /// 业务视觉主题色（艺考网紫 #715EFE），与阅卷系统各端色板一致。
  static const Color brandColor = AppColors.brand;

  // 全局默认字族与音乐之路页面参数一致：中文用 pubspec 里打包的
  // PingFang SC OTF（w100–w600）。未写字族的 TextStyle 以前会落到 Harmony，
  // 和原页面显式的 PingFang SC 不是同一套字面。Harmony 只作缺字回退。
  static const List<String> _fontFamilyFallback = <String>['Harmony'];

  /// 透明叠色：用于去除 Material 按钮按压 / 悬停 / 聚焦时的高亮叠色。
  static const WidgetStateProperty<Color?> _kNoOverlay =
      WidgetStatePropertyAll<Color?>(Colors.transparent);

  /// 仅去除「点击效果」的按钮样式片段：透明叠色 + 无水波纹。
  /// 不设置底色 / 形状 / 字体等，避免影响各按钮已有的基础样式（与控件自身或
  /// 调用点 `styleFrom` 的设置合并，仅覆盖交互反馈相关字段）。
  static final ButtonStyle _noEffectButtonStyle = ButtonStyle(
    overlayColor: _kNoOverlay,
    splashFactory: NoSplash.splashFactory,
  );

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'PingFang SC',
      fontFamilyFallback: _fontFamilyFallback,
      scaffoldBackgroundColor: Colors.white,
      // 全局去除「点击效果」：水波纹（splash）、按压高亮（highlight）、悬停
      // （hover）、聚焦（focus）。所有 InkWell / InkResponse 及未单独覆盖的
      // Material 控件都不再出现点击/悬停反馈。Material 按钮的反馈另见各
      // ButtonTheme 的 overlayColor。
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        primary: _primaryColor,
        error: AppColors.danger,
        surfaceTint: Colors.transparent,
      ),
      // iOS 文本选区把手、放大镜描边、未覆盖的 EditableText 光标等走 Cupertino
      // primaryColor；须与品牌紫一致。
      cupertinoOverrideTheme: const CupertinoThemeData(
        primaryColor: brandColor,
        selectionHandleColor: brandColor,
      ).noDefault(),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF171A20),
        centerTitle: true,
        // 字重过 [AppFont.weight] 走一遍：iOS 上自动 +1 档抵消 Skia/Impeller
        // 渲染中文偏细的视觉差。
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: AppFont.w500,
          color: const Color(0xFF171A20),
        ),
      ),
      // 全局页面 loading / 下拉刷新统一为 assets/images/home/loading.gif
      // （见 AppLoadingIndicator / AppRefreshIndicator）。此处主题仍作用于
      // 未迁移的 CircularProgressIndicator / LinearProgressIndicator（如上传进度）。
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: brandColor,
        strokeWidth: kAppLoadingIndicatorStrokeWidth,
        circularTrackColor: Color(0x1A715EFE),
        linearTrackColor: Color(0x1A715EFE),
      ),
      // 下拉刷新请使用 AppRefreshIndicator（GIF），勿直接用 Material RefreshIndicator。
      // 全局输入框光标 / 文本选区配色：所有未显式指定 cursorColor 的
      // TextField / TextFormField 都会走品牌紫；选区色与选区把手保持同色系。
      // 备注：cursorHeight 不在 ThemeData 暴露，需要在调用点单独设置。
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: brandColor,
        selectionColor: brandColor.withValues(alpha: 0.22),
        selectionHandleColor: brandColor,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(45)),
          backgroundColor: const WidgetStatePropertyAll(_primaryColor),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          // 去除按钮按压 / 悬停的叠色与水波纹。
          overlayColor: _kNoOverlay,
          splashFactory: NoSplash.splashFactory,
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontSize: 16,
              fontWeight: AppFont.w500,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
      // 其余 Material 按钮同样去除点击叠色与水波纹（不改变底色/形状等基础样式）。
      elevatedButtonTheme: ElevatedButtonThemeData(style: _noEffectButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: _noEffectButtonStyle),
      textButtonTheme: TextButtonThemeData(style: _noEffectButtonStyle),
      iconButtonTheme: IconButtonThemeData(style: _noEffectButtonStyle),
      menuButtonTheme: MenuButtonThemeData(style: _noEffectButtonStyle),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: _noEffectButtonStyle,
      ),
      // 以下 Material 控件只作兜底：去掉按压光圈 / 水波纹并换成令牌色。页面里
      // 优先使用 lib/core/ui 的 AppSwitch / AppCheckbox / AppTabs 等，它们切换时
      // 没有任何动画。
      switchTheme: SwitchThemeData(
        overlayColor: _kNoOverlay,
        splashRadius: 0,
        thumbColor: const WidgetStatePropertyAll(AppColors.surface),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.brand
              : AppColors.line,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        overlayColor: _kNoOverlay,
        splashRadius: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.br4),
        side: const BorderSide(color: AppColors.textPlaceholder, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.brand
              : AppColors.surface,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.onBrand),
      ),
      radioTheme: RadioThemeData(
        overlayColor: _kNoOverlay,
        splashRadius: 0,
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.brand
              : AppColors.textPlaceholder,
        ),
      ),
      sliderTheme: SliderThemeData(
        overlayColor: Colors.transparent,
        overlayShape: SliderComponentShape.noOverlay,
        activeTrackColor: AppColors.brand,
        inactiveTrackColor: AppColors.line,
        thumbColor: AppColors.brand,
      ),
      chipTheme: ChipThemeData(
        elevation: 0,
        pressElevation: 0,
        showCheckmark: false,
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.brandWash,
        disabledColor: AppColors.surfaceSubtle,
        side: const BorderSide(color: AppColors.line),
        shape: const StadiumBorder(),
        labelStyle: AppText.body13.copyWith(color: AppColors.ink),
      ),
      listTileTheme: const ListTileThemeData(
        selectedColor: AppColors.brand,
        iconColor: AppColors.textSecondary,
        textColor: AppColors.ink,
      ),
      tabBarTheme: TabBarThemeData(
        overlayColor: _kNoOverlay,
        splashFactory: NoSplash.splashFactory,
        indicatorColor: AppColors.brand,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelColor: AppColors.ink,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: AppText.body16.copyWith(fontWeight: AppFont.w600),
        unselectedLabelStyle: AppText.body16,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shadowColor: const Color(0x33000000),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.br12,
          side: BorderSide(color: AppColors.lineSoft),
        ),
        textStyle: AppText.body14,
        menuPadding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.br12),
        barrierColor: AppColors.scrim,
        titleTextStyle: AppText.title20,
        contentTextStyle: AppText.body14.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        modalBarrierColor: AppColors.scrim,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.panel),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(
          color: AppColors.ink,
          borderRadius: AppRadius.br8,
        ),
        textStyle: AppText.caption12.copyWith(color: AppColors.onBrand),
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: AppSpace.s4,
        ),
        waitDuration: const Duration(milliseconds: 400),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line),
    );

    // 让 Theme.of(context).textTheme 走一次字重补偿。注意：业务里直接
    // `TextStyle(...)` 创建的样式不会被这里覆盖，需要在调用点把
    // `FontWeight.wXXX` 改成 `AppFont.wXXX`。
    return base.copyWith(
      textTheme: bumpTextThemeWeights(base.textTheme),
      primaryTextTheme: bumpTextThemeWeights(base.primaryTextTheme),
    );
  }
}
