import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/network/media_url.dart';
import '../../../../core/theme/app_font.dart';
import '../../../../core/widgets/app_asset_graphic.dart';
import '../../state/shell_state.dart';
import '../shell_layout.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 动画常量
// ─────────────────────────────────────────────────────────────────────────────
const _kDuration = Duration(milliseconds: 280);
const _kCurve = Curves.easeInOutCubic;

// ─────────────────────────────────────────────────────────────────────────────
// ShellLeftNav — 持有 AnimationController 以驱动所有子动画
// ─────────────────────────────────────────────────────────────────────────────
class ShellLeftNav extends StatefulWidget {
  const ShellLeftNav({
    required this.state,
    required this.currentRoute,
    required this.onToggleCollapse,
    required this.onNavigate,
    super.key,
  });

  final ShellState state;
  final String currentRoute;
  final VoidCallback onToggleCollapse;
  final ValueChanged<String> onNavigate;

  @override
  State<ShellLeftNav> createState() => _ShellLeftNavState();
}

class _ShellLeftNavState extends State<ShellLeftNav>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // 0.0 = 展开, 1.0 = 折叠
  late final Animation<double> _progress;

  // Logo: 前 40% 完成淡出
  late final Animation<double> _logoOpacity;

  // 文字: 前 55% 完成淡出, 0→100% 完成宽度收缩
  late final Animation<double> _labelOpacity;
  late final Animation<double> _labelWidth; // 1→0

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: _kDuration,
      value: widget.state.collapsed ? 1.0 : 0.0,
    );
    _progress = CurvedAnimation(parent: _ctrl, curve: _kCurve);

    _logoOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, 0.4, curve: Curves.easeIn),
      ),
    );
    _labelOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, 0.55, curve: Curves.easeIn),
      ),
    );
    _labelWidth = Tween<double>(begin: 1, end: 0).animate(_progress);
  }

  @override
  void didUpdateWidget(ShellLeftNav old) {
    super.didUpdateWidget(old);
    if (old.state.collapsed != widget.state.collapsed) {
      widget.state.collapsed ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool _isActive(String navRoute) {
    final current = widget.currentRoute;
    if (navRoute == '/') return current == '/';
    if (current == navRoute) return true;
    return current.startsWith('$navRoute/');
  }

  /// 当前路由对应的侧栏索引；不在侧栏内的二级页（听写、试题等）返回 -1，
  /// 避免误把「首页」标为选中。
  int _activeNavIndex() {
    for (var i = 0; i < widget.state.navItems.length; i++) {
      if (_isActive(widget.state.navItems[i].route)) {
        return i;
      }
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final scale = DashboardScaleScope.of(context);
        final ui = scale.ui;
        final t = _progress.value; // 0=展开, 1=折叠

        // 列表两侧内边距: 展开时 16, 折叠时 8（使 icon 精确居中于 40px 内容宽度）
        final hPad = ui(16.0 - 8.0 * t); // lerp(16, 8, t)

        // 按钮内左边距: 展开 16 → 折叠 0
        final tilePadLeft = ui(16.0 * (1.0 - t));
        // 按钮内右边距: 展开 10 → 折叠 0
        final tilePadRight = ui(10.0 * (1.0 - t));

        return ColoredBox(
          color: Colors.white,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── 主体列（logo + 导航列表）──────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: ui(31.5)),

                  // Logo：schoolList 返回的 logo；无则回退默认资源
                  Transform.translate(
                    offset: Offset(0, -ui(4)),
                    child: Opacity(
                      opacity: _logoOpacity.value,
                      child: _ShellSidebarLogo(
                        logoUrl: widget.state.logoUrl,
                        width: ui(132),
                        height: ui(36),
                      ),
                    ),
                  ),

                  SizedBox(height: ui(18)),

                  // 常规导航列表（可滚动）；底部留白给贴底的意见反馈
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: _NavListWithSlider(
                        navItems: widget.state.navItems,
                        activeIndex: _activeNavIndex(),
                        progress: t,
                        labelOpacity: _labelOpacity.value,
                        labelWidthFactor: _labelWidth.value,
                        tilePadLeft: tilePadLeft,
                        tilePadRight: tilePadRight,
                        bottomPadding: widget.state.footerNavItem != null
                            ? ui(54)
                            : 0,
                        onNavigate: widget.onNavigate,
                      ),
                    ),
                  ),
                ],
              ),

              // 需求反馈：贴侧栏最底，50px 全宽，内容居中
              if (widget.state.footerNavItem != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: _FooterFeedbackLink(
                    item: widget.state.footerNavItem!,
                    collapsed: t > 0.5,
                    labelOpacity: _labelOpacity.value,
                    onTap: () =>
                        widget.onNavigate(widget.state.footerNavItem!.route),
                  ),
                ),

              // ── 缩放切换按钮（右下角）─────────────────────────────────────
              Positioned(
                right: 0,
                bottom: ui(40),
                child: GestureDetector(
                  onTap: widget.onToggleCollapse,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: ui(27),
                    height: ui(36),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F6FA),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(ui(12)),
                        bottomLeft: Radius.circular(ui(12)),
                      ),
                    ),
                    child: Center(
                      child: Transform.rotate(
                        // 展开=0°, 折叠=180°（指向右侧，表示"展开"方向）
                        angle: t * math.pi,
                        child: AppAssetGraphic(
                          AppAssets.leftNavScale,
                          width: ui(21),
                          height: ui(13),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NavListWithSlider — 共享选中背景 + 列表项
// ─────────────────────────────────────────────────────────────────────────────
class _NavListWithSlider extends StatelessWidget {
  const _NavListWithSlider({
    required this.navItems,
    required this.activeIndex,
    required this.progress,
    required this.labelOpacity,
    required this.labelWidthFactor,
    required this.tilePadLeft,
    required this.tilePadRight,
    required this.bottomPadding,
    required this.onNavigate,
  });

  final List<ShellNavItem> navItems;
  final int activeIndex;
  final double progress;
  final double labelOpacity;
  final double labelWidthFactor;
  final double tilePadLeft;
  final double tilePadRight;
  final double bottomPadding;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final tileHeight = ui(48);
    final separator = ui(4);
    final stride = tileHeight + separator;
    final listHeight = navItems.isEmpty
        ? 0.0
        : navItems.length * stride - separator;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final collapsedIndicatorSize = ui(40);
        final indicatorWidth =
            collapsedIndicatorSize +
            (maxWidth - collapsedIndicatorSize) * (1 - progress);
        final indicatorHeight =
            collapsedIndicatorSize +
            (tileHeight - collapsedIndicatorSize) * (1 - progress);
        final indicatorLeft = (maxWidth - indicatorWidth) / 2 * progress;
        final indicatorTopInset =
            (tileHeight - collapsedIndicatorSize) / 2 * progress;

        return SingleChildScrollView(
          padding: EdgeInsets.only(bottom: bottomPadding),
          physics: const ClampingScrollPhysics(),
          child: SizedBox(
            width: maxWidth,
            height: listHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (navItems.isNotEmpty && activeIndex >= 0)
                  Positioned(
                    left: indicatorLeft,
                    top: activeIndex * stride + indicatorTopInset,
                    width: indicatorWidth,
                    height: indicatorHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(ui(12)),
                        image: const DecorationImage(
                          image: AssetImage(AppAssets.leftNavActiveBg),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                Column(
                  children: [
                    for (var i = 0; i < navItems.length; i++) ...[
                      SizedBox(
                        height: tileHeight,
                        child: _NavTile(
                          item: navItems[i],
                          progress: progress,
                          labelOpacity: labelOpacity,
                          labelWidthFactor: labelWidthFactor,
                          tilePadLeft: tilePadLeft,
                          tilePadRight: tilePadRight,
                          active: i == activeIndex,
                          onTap: () => onNavigate(navItems[i].route),
                        ),
                      ),
                      if (i < navItems.length - 1) SizedBox(height: separator),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FooterFeedbackLink — 侧栏底部弱样式入口（50px 全宽居中，无点击水波纹）
// ─────────────────────────────────────────────────────────────────────────────
class _FooterFeedbackLink extends StatelessWidget {
  const _FooterFeedbackLink({
    required this.item,
    required this.collapsed,
    required this.labelOpacity,
    required this.onTap,
  });

  final ShellNavItem item;
  final bool collapsed;
  final double labelOpacity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    const labelColor = Color(0xFFD1D1D1);
    final iconSize = ui(14);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: ui(50),
        width: double.infinity,
        child: Center(
          child: collapsed
              ? AppAssetGraphic(
                  item.icon,
                  width: iconSize,
                  height: iconSize,
                  fit: BoxFit.contain,
                )
              : Opacity(
                  opacity: labelOpacity,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppAssetGraphic(
                        item.icon,
                        width: iconSize,
                        height: iconSize,
                        fit: BoxFit.contain,
                      ),
                      SizedBox(width: ui(4)),
                      Text(
                        item.label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          fontSize: ui(12),
                          height: 1,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w400,
                          color: labelColor,
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

// ─────────────────────────────────────────────────────────────────────────────
// _NavTile — 单个导航项，接收插值后的动画参数
// ─────────────────────────────────────────────────────────────────────────────
class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.progress,
    required this.labelOpacity,
    required this.labelWidthFactor,
    required this.tilePadLeft,
    required this.tilePadRight,
    required this.active,
    required this.onTap,
  });

  final ShellNavItem item;
  final double progress; // 0=展开, 1=折叠
  final double labelOpacity;
  final double labelWidthFactor; // 1→0
  final double tilePadLeft;
  final double tilePadRight;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;

    // 选中背景由 [_NavListWithSlider] 统一绘制；此处 tile 背景保持透明。
    const inactiveTextColor = Color(0xFF0B081A);
    final collapsed = progress > 0.5;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: BoxConstraints(minHeight: ui(48)),
        alignment: collapsed ? Alignment.center : Alignment.centerLeft,
        child: collapsed
            // 折叠态：40×40 命中区包住 icon；背景由滑动指示器承担。
            ? SizedBox(
                width: ui(40),
                height: ui(40),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    _buildIcon(context),
                    if (item.badge > 0)
                      Positioned(
                        right: ui(-2),
                        top: ui(1),
                        child: const _BadgeDot(),
                      ),
                  ],
                ),
              )
            // 展开态：左 16 / 右 10 / 上下 12 内边距。
            : Padding(
                padding: EdgeInsets.only(
                  left: tilePadLeft,
                  right: tilePadRight,
                  top: ui(12),
                  bottom: ui(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildIcon(context),
                    Expanded(
                      child: ClipRect(
                        child: Align(
                          widthFactor: labelWidthFactor,
                          alignment: Alignment.centerLeft,
                          child: Opacity(
                            opacity: labelOpacity,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(width: ui(8)),
                                Flexible(
                                  child: Text(
                                    item.label,
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.clip,
                                    style: TextStyle(
                                      fontSize: ui(15),
                                      height: 1,
                                      fontFamily: 'PingFang SC',
                                      fontWeight: AppFont.w500,
                                      color: active
                                          ? Colors.white
                                          : inactiveTextColor.withValues(
                                              alpha: 0.7,
                                            ),
                                    ),
                                  ),
                                ),
                                if (item.badge > 0) ...[
                                  SizedBox(width: ui(4)),
                                  _NavUnreadCapsule(count: item.badge),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    final size = item.iconSize ?? 24;
    return AppAssetGraphic(
      active ? item.activeIcon : item.icon,
      width: ui(size),
      height: ui(size),
      fit: BoxFit.contain,
      colorFilter: active
          ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge（智慧校园未读等）：设计稿 #F04545 胶囊 + Manrope 800 数字
// ─────────────────────────────────────────────────────────────────────────────

/// 折叠态：角标圆点（#F04545）
class _BadgeDot extends StatelessWidget {
  const _BadgeDot();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(8),
      height: ui(8),
      decoration: const BoxDecoration(
        color: Color(0xFFF04545),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// 展开态：圆角胶囊，宽度按数字内容自适应（"9"/"10+"/"99+" 各不相同）
/// 设计稿"10+"≈22×15：文字 17w + 左右各 2.5px padding 自然撑出
class _NavUnreadCapsule extends StatelessWidget {
  const _NavUnreadCapsule({required this.count});

  final int count;

  String get _label => count > 99 ? '99+' : (count > 9 ? '$count+' : '$count');

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(15),
      padding: EdgeInsets.symmetric(horizontal: ui(2.5)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF04545),
        borderRadius: BorderRadius.circular(ui(20)),
      ),
      child: Text(
        _label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: ui(10),
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}

/// 侧栏顶部 Logo：`/app/school/v2/user/schoolList` 的 `logo` 字段，空则默认图。
class _ShellSidebarLogo extends StatelessWidget {
  const _ShellSidebarLogo({
    required this.logoUrl,
    required this.width,
    required this.height,
  });

  final String logoUrl;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final resolved = MediaUrl.resolve(logoUrl.trim());
    return SizedBox(
      height: height,
      child: Center(
        child: resolved.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: resolved,
                width: width,
                height: height,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                placeholder: (context, url) => _fallback(),
                errorWidget: (context, url, error) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Image.asset(
      AppAssets.shellLogo,
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
