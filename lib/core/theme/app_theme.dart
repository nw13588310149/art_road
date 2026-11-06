import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_font.dart';
import '../widgets/app_loading_indicator.dart';

class AppTheme {
  static const _primaryColor = Color(0xFF00C9A4);

  /// 业务视觉主题色（紫）。与设计稿一致，用于所有需要"主题色"的非 Material
  /// 控件（计时器、播放器、按钮等已分别硬编码同值）。这里作为公共常量统一
  /// 来源，方便后续整体调色。
  static const Color brandColor = Color(0xFF8741FF);

  // 全局默认字族回退链：iOS 上 Skia/Impeller 直接绘制 Apple 系统 "PingFang SC"
  // 时字面率偏细（CoreText 内置了视觉补偿，Flutter 没有），所以这里强制把
  // pubspec 中自带的 PingFang SC OTF 排在第一位 fallback——当主字族 Harmony
  // 没有相应字形（或上层显式指定了一个不存在的字族）时，先命中我们打包进来
  // 的 OTF 文件，避免落到系统 PingFang 上看起来"飘"。
  static const List<String> _fontFamilyFallback = <String>[
    'PingFang SC',
  ];

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
      fontFamily: 'Harmony',
      fontFamilyFallback: _fontFamilyFallback,
      scaffoldBackgroundColor: Colors.white,
      // 全局去除「点击效果」：水波纹（splash）、按压高亮（highlight）、悬停
      // （hover）。所有 InkWell / InkResponse 及未单独覆盖的 Material 控件都不再
      // 出现点击/悬停反馈。Material 按钮的反馈另见各 ButtonTheme 的 overlayColor。
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        primary: _primaryColor,
      ),
      // iOS 文本选区把手、放大镜描边、未覆盖的 EditableText 光标等走 Cupertino
      // primaryColor；须与品牌紫一致，否则会回退到 colorScheme.primary（绿色）。
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
        circularTrackColor: Color(0x1A8741FF),
        linearTrackColor: Color(0x1A8741FF),
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
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: _noEffectButtonStyle,
      ),
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
