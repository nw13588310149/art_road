import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/widgets/app_asset_graphic.dart';
import '../../navigation/shell_nav_routes.dart';
import '../../state/shell_state.dart';

/// 侧栏：艺考网标识 + 导航项 + 底部「意见反馈」与收起按钮。
///
/// 当前路由按 [shellActiveNavIndex] 对应到唯一的导航项（墨蓝实底 + 白字），
/// 不属于任何导航项的页面不高亮。收起 / 展开、选中都立即切换，没有过渡动画。
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

class _ShellLeftNavState extends State<ShellLeftNav> {
  static const double _tileHeight = 48;
  static const double _tileGap = 4;
  final _scroll = ScrollController();
  (int, double, double)? _revealed;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _revealActive(int index, double tileHeight, double viewport) {
    final target = (index, tileHeight, viewport);
    if (_revealed == target) return;
    _revealed = target;
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || _revealed != target) return;
      final start = index * (tileHeight + _tileGap);
      final end = start + tileHeight;
      final offset = _scroll.offset;
      if (start < offset || end > offset + viewport) {
        final next = start < offset ? start : end - viewport;
        _scroll.jumpTo(next.clamp(0.0, _scroll.position.maxScrollExtent));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final currentRoute = widget.currentRoute;
    final collapsed = state.collapsed;
    final items = state.navItems;
    final activeIndex = shellActiveNavIndex([
      for (final item in items) item.route,
    ], currentRoute);
    final footer = state.footerNavItem;
    final horizontal = collapsed ? AppSpace.s8 : AppSpace.s16;

    return ColoredBox(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 28),
          SizedBox(
            height: 36,
            child: Center(
              child: collapsed
                  ? const AppAssetGraphic(
                      AppAssets.brandMark,
                      width: 28,
                      height: 28,
                    )
                  : const AppAssetGraphic(
                      AppAssets.shellLogo,
                      width: 132,
                      height: 36,
                    ),
            ),
          ),
          const SizedBox(height: 22),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tileHeight = collapsed || items.isEmpty
                    ? 40.0
                    : ((constraints.maxHeight + _tileGap) / items.length -
                              _tileGap)
                          .floorToDouble()
                          .clamp(44.0, _tileHeight);
                _revealActive(activeIndex, tileHeight, constraints.maxHeight);
                return ListView.separated(
                  controller: _scroll,
                  padding: EdgeInsets.symmetric(horizontal: horizontal),
                  physics: const ClampingScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: _tileGap),
                  itemBuilder: (context, index) => _NavTile(
                    item: items[index],
                    active: index == activeIndex,
                    collapsed: collapsed,
                    height: tileHeight,
                    onTap: () => widget.onNavigate(items[index].route),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              AppSpace.s8,
              horizontal,
              AppSpace.s12,
            ),
            child: _NavFooter(
              feedback: footer,
              feedbackActive:
                  footer != null &&
                  shellNavOwnerOf(currentRoute) == footer.route,
              collapsed: collapsed,
              onNavigate: widget.onNavigate,
              onToggleCollapse: widget.onToggleCollapse,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.active,
    required this.collapsed,
    required this.height,
    required this.onTap,
  });

  final ShellNavItem item;
  final bool active;
  final bool collapsed;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.onBrand : AppColors.textSecondary;
    final icon = _NavIcon(item: item, active: active, color: color);
    final Widget content;
    if (collapsed) {
      content = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          icon,
          if (item.badge > 0)
            const Positioned(top: 8, right: 8, child: AppBadge.dot()),
        ],
      );
    } else {
      content = Row(
        children: [
          icon,
          const SizedBox(width: AppSpace.s8),
          Expanded(
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (active ? AppText.body14Strong : AppText.body14).copyWith(
                color: color,
              ),
            ),
          ),
          if (item.badge > 0) ...[
            const SizedBox(width: AppSpace.s4),
            AppBadge(count: item.badge),
          ],
        ],
      );
    }
    return AppPressable(
      onTap: onTap,
      selected: active,
      semanticLabel: collapsed ? item.label : null,
      child: Container(
        height: height,
        padding: collapsed
            ? EdgeInsets.zero
            : const EdgeInsets.only(left: AppSpace.s16, right: 10),
        alignment: collapsed ? Alignment.center : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: active ? AppColors.navSelection : null,
          borderRadius: AppRadius.br12,
        ),
        child: content,
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.item,
    required this.active,
    required this.color,
  });

  final ShellNavItem item;
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final size = item.iconSize ?? 24;
    final data = item.iconData;
    if (data != null) {
      return Icon(data, size: size, color: color);
    }
    return AppAssetGraphic(
      active ? item.activeIcon : item.icon,
      width: size,
      height: size,
      colorFilter: active
          ? const ColorFilter.mode(AppColors.onBrand, BlendMode.srcIn)
          : null,
    );
  }
}

/// 侧栏底部：「意见反馈」入口 + 收起 / 展开按钮（收起后上下排列）。
class _NavFooter extends StatelessWidget {
  const _NavFooter({
    required this.feedback,
    required this.feedbackActive,
    required this.collapsed,
    required this.onNavigate,
    required this.onToggleCollapse,
  });

  final ShellNavItem? feedback;
  final bool feedbackActive;
  final bool collapsed;
  final ValueChanged<String> onNavigate;
  final VoidCallback onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    final toggle = AppIconButton(
      icon: collapsed
          ? Icons.keyboard_double_arrow_right_rounded
          : Icons.keyboard_double_arrow_left_rounded,
      semanticLabel: collapsed ? '展开导航' : '收起导航',
      filled: false,
      color: AppColors.textTertiary,
      onTap: onToggleCollapse,
    );
    final item = feedback;
    if (item == null) {
      return Align(alignment: Alignment.centerRight, child: toggle);
    }
    final color = feedbackActive ? AppColors.brand : AppColors.textTertiary;
    final link = AppPressable(
      onTap: () => onNavigate(item.route),
      selected: feedbackActive,
      semanticLabel: collapsed ? item.label : null,
      child: SizedBox(
        height: AppSize.iconButton,
        width: collapsed ? AppSize.iconButton : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppAssetGraphic(
              item.icon,
              width: 16,
              height: 16,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
            if (!collapsed) ...[
              const SizedBox(width: 6),
              Text(item.label, style: AppText.body13.copyWith(color: color)),
            ],
          ],
        ),
      ),
    );
    if (collapsed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          link,
          const SizedBox(height: AppSpace.s4),
          toggle,
        ],
      );
    }
    return Row(
      children: [
        const SizedBox(width: AppSpace.s12),
        link,
        const Spacer(),
        toggle,
      ],
    );
  }
}
