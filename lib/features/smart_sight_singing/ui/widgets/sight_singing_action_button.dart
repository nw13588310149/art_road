import 'package:flutter/material.dart';

import 'package:the_road_of_music_flutter/core/theme/app_font.dart';
import '../../../shell/ui/shell_layout.dart';

/// 智能视唱底部操作条整图按钮（试听 / 开始跟唱 / 停止 / 取消）。
///
/// 高度固定 36（随 [DashboardScaleScope] 缩放），宽度按切图宽高比自适应。
class SightSingingImageActionButton extends StatelessWidget {
  const SightSingingImageActionButton({
    required this.asset,
    required this.onTap,
    super.key,
  });

  final String asset;
  final VoidCallback? onTap;

  /// 与 `assets/images/sightsing/3.png`（开始跟唱）一致的设计稿高度。
  static const double designHeight = 36;

  /// 与 `assets/images/sightsing/3.png` 一致的设计稿宽高比（276×108）。
  static const double designAspectRatio = 276 / 108;

  /// 就绪态双按钮（试听 + 开始跟唱）之间的设计稿间距。
  static const double readyControlsGap = 12;

  /// 就绪态右侧按钮区固定宽度，避免切到「取消/停止」单按钮时挤压进度条。
  static double readyControlsSlotWidth(double Function(double) ui) {
    final buttonWidth = ui(designHeight * designAspectRatio);
    // 略留余量，避免切图实际宽高比与设计稿 276×108 偏差导致 Row 溢出。
    return buttonWidth * 2 + ui(readyControlsGap) + ui(4);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final disabled = onTap == null;
    final height = ui(designHeight);
    return GestureDetector(
      onTap: disabled ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: SizedBox(
          height: height,
          child: Image.asset(
            asset,
            height: height,
            fit: BoxFit.fitHeight,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}

/// 双态整图按钮：播放/暂停等同尺寸切图叠放，避免首次切图时整按钮闪烁。
class SightSingingToggleImageActionButton extends StatelessWidget {
  const SightSingingToggleImageActionButton({
    required this.primaryAsset,
    required this.alternateAsset,
    required this.showAlternate,
    required this.onTap,
    super.key,
  });

  final String primaryAsset;
  final String alternateAsset;
  final bool showAlternate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final disabled = onTap == null;
    final height = ui(SightSingingImageActionButton.designHeight);
    return GestureDetector(
      onTap: disabled ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: SizedBox(
          height: height,
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.passthrough,
            children: [
              Opacity(
                opacity: showAlternate ? 0 : 1,
                child: Image.asset(
                  primaryAsset,
                  height: height,
                  fit: BoxFit.fitHeight,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                ),
              ),
              Opacity(
                opacity: showAlternate ? 1 : 0,
                child: Image.asset(
                  alternateAsset,
                  height: height,
                  fit: BoxFit.fitHeight,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 与 [SightSingingImageActionButton] 同尺寸、同渐变胶囊风格的文字按钮。
class SightSingingGradientActionButton extends StatelessWidget {
  const SightSingingGradientActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final disabled = onTap == null;
    final height = ui(SightSingingImageActionButton.designHeight);
    final width = ui(
      SightSingingImageActionButton.designHeight *
          SightSingingImageActionButton.designAspectRatio,
    );
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: disabled ? 0.45 : 1,
        child: SizedBox(
          width: width,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: <Color>[Color(0xFFB68EFF), Color(0xFF8640FF)],
              ),
              borderRadius: BorderRadius.circular(height / 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: ui(19)),
                SizedBox(width: ui(4)),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: ui(12),
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
