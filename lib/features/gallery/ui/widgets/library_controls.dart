import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_font.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/widgets/anchored_popup_menu.dart';
import '../../../../core/widgets/app_asset_graphic.dart';
import '../../../../core/widgets/app_text_field.dart';

/// 范画库与美术书刊共用的页面控件。
///
/// 这两个模块在参照工程（80e9dd3c）里没有同名页面，控件的尺寸、圆角、字号和
/// 颜色取自其中最接近的页面：视频中心的分类与搜索、云盘的工具栏按钮与资料预览、
/// 收藏页的分段工具栏、学习目录的课程卡。参照工程的紫色统一换成品牌紫。

/// 参照工程里没有对应色板令牌的色值。
abstract final class LibraryPalette {
  /// 资源卡、相关内容卡的浅紫底。
  static const lilac = Color(0xFFF4F4FF);

  /// 资料预览画布。
  static const canvas = Color(0xFFFAFAFD);

  /// 搜索框的提示文字、聚焦描边与清空图标。
  static const searchHint = Color(0xFFD1D1D1);
  static const searchFocus = Color(0xFFE3E3E3);
  static const searchClear = Color(0xFFC6C6C6);

  /// 工具栏按钮文字。
  static const toolbarText = Color(0xFF1A1A1A);

  /// 预览页图标按钮的箭头。
  static const backArrow = Color(0xFF1C274C);

  /// 课程卡右下角的深色按钮。
  static const darkAction = Color(0xFF292151);

  /// 进度轨道与进度渐变的起点。
  static const track = Color(0xFFE1E2E5);
  static const trackStart = Color(0xFFE2D0FF);

  /// 预览缩略图当前页的徽标底与蒙版。
  static const activeBadge = Color(0xFFEAE5FF);
  static const activeScrim = Color(0x1C0B081A);

  /// 列表分组标题。
  static const groupTitle = Color(0xFF171A20);

  /// 封面加载前的占位底。
  static const coverFallback = Color(0xFFEDEDF2);

  /// 弹出菜单的行间细线。
  static const menuDivider = Color(0xFFF3F4F6);

  /// 类型徽标的绿、蓝两组配色。
  static const badgeGreen = Color(0xFF0CAC40);
  static const badgeGreenBg = Color(0xFFDFFCF0);
  static const badgeBlue = Color(0xFF1E73FF);
  static const badgeBlueBg = Color(0xFFE6F2FF);
}

/// 参照工程的页面直接写字号与行高，这里沿用同样的写法。
TextStyle libraryText({
  required double size,
  required Color color,
  FontWeight? weight,
  double? height,
}) {
  return TextStyle(
    fontFamily: 'PingFang SC',
    fontSize: size,
    fontWeight: weight ?? AppFont.w400,
    color: color,
    height: height,
  );
}

/// 预览页的方形图标按钮：32 见方、白底、圆角 8、1px 浅描边、18 号箭头。
class LibraryIconButton extends StatelessWidget {
  const LibraryIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.iconSize = 18,
    this.color = LibraryPalette.backArrow,
    super.key,
  });

  const LibraryIconButton.back({required this.onTap, super.key})
    : icon = Icons.chevron_left_rounded,
      semanticLabel = '返回',
      iconSize = 18,
      color = LibraryPalette.backArrow;

  static const double extent = 32;

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;
  final double iconSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: semanticLabel,
      excludeFromSemantics: true,
      child: AppPressable(
        onTap: onTap,
        enabled: onTap != null,
        semanticLabel: semanticLabel,
        child: Container(
          width: extent,
          height: extent,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.br8,
            border: Border.all(color: AppColors.lineSoft),
          ),
          child: Icon(icon, size: iconSize, color: color),
        ),
      ),
    );
  }
}

/// 预览页工具栏的操作胶囊：32 高、白底、圆角 8、1px 浅描边，20 图标 + 12 号粗体字。
///
/// [primary] 为页面唯一的主操作（品牌紫渐变）；[active] 表示已收藏、已加书签等
/// 已生效的状态；[compact] 在窄工具栏里只留图标。
class LibraryActionPill extends StatelessWidget {
  const LibraryActionPill({
    required this.label,
    required this.onTap,
    this.iconAsset,
    this.icon,
    this.iconSize = 20,
    this.primary = false,
    this.active = false,
    this.compact = false,
    this.semanticLabel,
    super.key,
  }) : assert(iconAsset == null || icon == null);

  static const double height = 32;

  final String label;
  final VoidCallback? onTap;
  final String? iconAsset;
  final IconData? icon;
  final double iconSize;
  final bool primary;
  final bool active;
  final bool compact;

  /// 与可见文字不同的读屏名称（如「目录」按钮读作「目录与书签」）。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final foreground = primary
        ? AppColors.onBrand
        : (active ? AppColors.brand : AppColors.ink);
    final asset = iconAsset;
    final Widget? leading = asset != null
        ? AppAssetGraphic(asset, width: iconSize, height: iconSize)
        : (icon == null ? null : Icon(icon, size: iconSize, color: foreground));
    final showLabel = !compact || leading == null;
    Widget content = Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: showLabel ? 12 : 5),
      decoration: BoxDecoration(
        color: primary ? null : AppColors.surface,
        gradient: primary
            ? const LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [AppColors.brandSoft, AppColors.brand],
              )
            : null,
        borderRadius: AppRadius.br8,
        border: primary ? null : Border.all(color: AppColors.lineSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null)
            SizedBox(width: 20, height: 20, child: Center(child: leading)),
          if (leading != null && showLabel) const SizedBox(width: 4),
          if (showLabel)
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: libraryText(
                size: 12,
                weight: AppFont.w600,
                color: foreground,
              ),
            ),
        ],
      ),
    );
    final spoken = semanticLabel ?? (showLabel ? null : label);
    if (spoken != null) {
      content = ExcludeSemantics(child: content);
    }
    final button = AppPressable(
      onTap: onTap,
      enabled: onTap != null,
      semanticLabel: spoken,
      child: content,
    );
    if (showLabel) {
      return button;
    }
    return Tooltip(message: label, excludeFromSemantics: true, child: button);
  }
}

/// 资料预览页的顶部工具栏：56 高、左右 12、底部 1px 分隔线；左侧返回，
/// 标题在剩余空间里居中（15 号中等字重），右侧是操作。
class LibraryPreviewHeader extends StatelessWidget {
  const LibraryPreviewHeader({
    required this.title,
    this.onBack,
    this.actions = const <Widget>[],
    super.key,
  });

  static const double height = 56;

  final String title;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            LibraryIconButton.back(onTap: onBack),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Center(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: libraryText(
                    size: 15,
                    weight: AppFont.w500,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
          ),
          for (var i = 0; i < actions.length; i++) ...[
            SizedBox(width: i == 0 ? 12 : 8),
            actions[i],
          ],
        ],
      ),
    );
  }
}

/// 资料预览的画布：四周留 16，圆角 7，浅色底。
class LibraryCanvas extends StatelessWidget {
  const LibraryCanvas({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  static const BorderRadius radius = BorderRadius.all(Radius.circular(7));

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(color: LibraryPalette.canvas, child: child),
      ),
    );
  }
}

/// 搜索框：白底、圆角 12、1px 浅描边，左侧放大镜，14 号字。
///
/// [height] 为 36 时用视频中心的数值（图标 14.43、间距 6），40 时用云盘的数值
/// （图标 18、间距 10）。有内容时右侧出现清空按钮。
class LibrarySearchField extends StatefulWidget {
  const LibrarySearchField({
    required this.controller,
    required this.hint,
    this.height = 36,
    this.onChanged,
    this.onSubmitted,
    this.onCleared,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final double height;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onCleared;

  @override
  State<LibrarySearchField> createState() => _LibrarySearchFieldState();
}

class _LibrarySearchFieldState extends State<LibrarySearchField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    _focusNode.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant LibrarySearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _focusNode
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged?.call('');
    widget.onCleared?.call();
  }

  @override
  Widget build(BuildContext context) {
    final tall = widget.height >= 40;
    final iconSize = tall ? 18.0 : 14.43;
    final showClear = widget.controller.text.isNotEmpty;
    final textStyle = libraryText(size: 14, color: AppColors.ink, height: 1);
    return Container(
      height: widget.height,
      padding: EdgeInsets.only(left: 16, right: showClear ? 4 : 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.br12,
        border: Border.all(
          color: _focusNode.hasFocus
              ? LibraryPalette.searchFocus
              : AppColors.lineSoft,
        ),
      ),
      child: Row(
        children: [
          AppAssetGraphic(
            AppAssets.shellV2Search,
            width: iconSize,
            height: iconSize,
          ),
          SizedBox(width: tall ? 10 : 6),
          Expanded(
            child: AppTextField(
              controller: widget.controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              maxLines: 1,
              cursorColor: AppColors.brand,
              cursorWidth: 1.5,
              cursorHeight: tall ? 15 : 14,
              style: textStyle,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                hintText: widget.hint,
                hintStyle: textStyle.copyWith(
                  color: LibraryPalette.searchHint,
                ),
                hintFadeDuration: Duration.zero,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (showClear)
            AppPressable(
              onTap: _clear,
              semanticLabel: '清空',
              child: const SizedBox(
                width: 28,
                height: 28,
                child: Icon(
                  Icons.cancel,
                  size: 15,
                  color: LibraryPalette.searchClear,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 工具栏按钮（排序等）：白底、圆角 12、1px 浅描边，16 图标 + 12 号字。
/// 云盘里高 40；和 36 高的搜索框同排时取 36。
class LibraryToolbarButton extends StatelessWidget {
  const LibraryToolbarButton({
    required this.label,
    required this.onTap,
    this.iconAsset = AppAssets.coursewareSort,
    this.height = 40,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final String iconAsset;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.br12,
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppAssetGraphic(iconAsset, width: 16, height: 16),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: libraryText(
              size: 12,
              weight: AppFont.w500,
              color: LibraryPalette.toolbarText,
            ),
          ),
        ],
      ),
    );
    if (semanticLabel != null) {
      content = ExcludeSemantics(child: content);
    }
    return AppPressable(
      onTap: onTap,
      enabled: onTap != null,
      semanticLabel: semanticLabel,
      child: content,
    );
  }
}

/// 一个带名称的取值，用于分段、筛选条和弹出菜单。
class LibraryOption<T> {
  const LibraryOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// 排序按钮：显示当前排序方式，点开后在弹出菜单里换一种。
class LibrarySortButton<T> extends StatefulWidget {
  const LibrarySortButton({
    required this.options,
    required this.value,
    required this.onChanged,
    this.height = 40,
    super.key,
  });

  final List<LibraryOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  State<LibrarySortButton<T>> createState() => _LibrarySortButtonState<T>();
}

class _LibrarySortButtonState<T> extends State<LibrarySortButton<T>> {
  final GlobalKey _anchor = GlobalKey();

  Future<void> _open() async {
    final picked = await showLibraryMenu<T>(
      context: context,
      triggerKey: _anchor,
      items: widget.options,
      selected: widget.value,
    );
    if (picked != null && mounted && picked != widget.value) {
      widget.onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    var label = '排序';
    for (final option in widget.options) {
      if (option.value == widget.value) {
        label = option.label;
      }
    }
    return LibraryToolbarButton(
      key: _anchor,
      label: label,
      height: widget.height,
      semanticLabel: '排序：$label',
      onTap: _open,
    );
  }
}

/// 弹出菜单：142 宽白色面板、圆角 12、浅描边与三层投影，行高 36、13 号字。
/// 选中项用品牌紫并带对勾。点遮罩关闭返回 null。
Future<T?> showLibraryMenu<T>({
  required BuildContext context,
  required GlobalKey triggerKey,
  required List<LibraryOption<T>> items,
  T? selected,
}) {
  if (items.isEmpty) {
    return Future<T?>.value();
  }
  return showAnchoredPopupMenu<T>(
    context: context,
    triggerKey: triggerKey,
    menuWidth: _LibraryMenuPanel.width,
    approxMenuHeight: 16 + items.length * 36 + (items.length - 1) * 2,
    builder: (dialogContext, _) => _LibraryMenuPanel<T>(
      items: items,
      selected: selected,
      onSelected: (value) => Navigator.of(dialogContext).pop(value),
    ),
  );
}

class _LibraryMenuPanel<T> extends StatelessWidget {
  const _LibraryMenuPanel({
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  static const double width = 142;

  final List<LibraryOption<T>> items;
  final T? selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.br12,
        border: Border.all(color: AppColors.lineSoft, width: 1.11),
        boxShadow: const [
          BoxShadow(color: Color(0x050B081A), blurRadius: 1),
          BoxShadow(
            color: Color(0x0F0B081A),
            blurRadius: 40,
            offset: Offset(0, 12),
          ),
          BoxShadow(
            color: Color(0x050B081A),
            blurRadius: 24,
            offset: Offset(0, 12),
            spreadRadius: -16,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 2),
            _row(items[i]),
          ],
        ],
      ),
    );
  }

  Widget _row(LibraryOption<T> item) {
    final active = item.value == selected;
    final color = active ? AppColors.brand : AppColors.ink;
    return AppPressable(
      onTap: () => onSelected(item.value),
      selected: active,
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: libraryText(
                  size: 13,
                  weight: active ? AppFont.w500 : AppFont.w400,
                  color: color,
                  height: 20 / 13,
                ),
              ),
            ),
            if (active)
              const Icon(Icons.check_rounded, size: 16, color: AppColors.brand),
            const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }
}

/// 筛选胶囊：31 高、左右 12、圆角 8；选中墨蓝底白字，未选浅灰底墨色字，14 号字。
class LibraryChip extends StatelessWidget {
  const LibraryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  static const double height = 31;

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      selected: selected,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.navSelection : AppColors.surfaceSubtle,
          borderRadius: AppRadius.br8,
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: libraryText(
              size: 14,
              color: selected ? AppColors.onBrand : AppColors.ink,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// 横向滚动的筛选条：胶囊之间 12。
class LibraryChipBar<T> extends StatelessWidget {
  const LibraryChipBar({
    required this.items,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<LibraryOption<T>> items;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: LibraryChip.height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return LibraryChip(
            label: item.label,
            selected: item.value == value,
            onTap: () => onChanged(item.value),
          );
        },
      ),
    );
  }
}

/// 收藏页的分段工具栏：浅灰轨道（内距 4、圆角 8、1px 浅描边），选项左右 16、
/// 上下 8、间距 16，选中为白底圆角 6 加柔和投影，14 号中等字重。
class LibrarySegmented<T> extends StatelessWidget {
  const LibrarySegmented({
    required this.items,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<LibraryOption<T>> items;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: AppRadius.br8,
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            _item(items[i]),
          ],
        ],
      ),
    );
  }

  Widget _item(LibraryOption<T> item) {
    final active = item.value == value;
    return AppPressable(
      onTap: () => onChanged(item.value),
      selected: active,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: active
            ? const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.all(Radius.circular(6)),
                boxShadow: [
                  BoxShadow(color: Color(0x59B5B5B5), blurRadius: 20),
                ],
              )
            : null,
        child: Text(
          item.label,
          maxLines: 1,
          softWrap: false,
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          style: TextStyle(
            fontFamily: 'PingFang SC',
            fontSize: 14,
            fontWeight: AppFont.w500,
            height: 1.25,
            leadingDistribution: TextLeadingDistribution.even,
            color: active ? AppColors.ink : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// 分区标题：16 号粗体，右侧一条 1px 细线撑满；[trailing] 放在细线之后。
class LibrarySectionTitle extends StatelessWidget {
  const LibrarySectionTitle(
    this.title, {
    this.trailing,
    this.rule = true,
    super.key,
  });

  final String title;
  final Widget? trailing;
  final bool rule;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: libraryText(
              size: 16,
              weight: AppFont.w600,
              color: AppColors.ink,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: rule
              ? const SizedBox(
                  height: 1,
                  child: ColoredBox(color: AppColors.lineSoft),
                )
              : const SizedBox.shrink(),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

/// 列表分组标题：14 号粗体，可带「共 N 本」这类计数。
class LibraryGroupTitle extends StatelessWidget {
  const LibraryGroupTitle(
    this.title, {
    this.count,
    this.unit = '',
    super.key,
  });

  final String title;
  final int? count;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final total = count;
    final muted = libraryText(
      size: 12,
      weight: AppFont.w500,
      color: AppColors.textPlaceholder,
    );
    return Row(
      children: [
        Text(
          title,
          style: libraryText(
            size: 14,
            weight: AppFont.w600,
            color: LibraryPalette.groupTitle,
          ),
        ),
        if (total != null) ...[
          const SizedBox(width: 8),
          Text('共', style: muted),
          const SizedBox(width: 6),
          Text(
            '$total',
            style: const TextStyle(
              fontFamily: 'Barlow',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(width: 6),
          Text(unit, style: muted),
        ],
      ],
    );
  }
}

/// 方角标签：17 高、左右 6、圆角 4、12 号字；[dense] 为图片上的类型徽标
/// （上下 3、10 号中等字重）。
class LibraryTag extends StatelessWidget {
  const LibraryTag(
    this.label, {
    this.foreground = AppColors.textSecondary,
    this.background = AppColors.surfaceSubtle,
    this.dense = false,
    super.key,
  });

  /// 品牌紫：浅紫底。
  LibraryTag.brand(String label, {bool dense = false, Key? key})
    : this(
        label,
        foreground: AppColors.brand,
        background: AppColors.tint(AppColors.brand, 0.1),
        dense: dense,
        key: key,
      );

  const LibraryTag.green(String label, {bool dense = false, Key? key})
    : this(
        label,
        foreground: LibraryPalette.badgeGreen,
        background: LibraryPalette.badgeGreenBg,
        dense: dense,
        key: key,
      );

  const LibraryTag.blue(String label, {bool dense = false, Key? key})
    : this(
        label,
        foreground: LibraryPalette.badgeBlue,
        background: LibraryPalette.badgeBlueBg,
        dense: dense,
        key: key,
      );

  final String label;
  final Color foreground;
  final Color background;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: background,
      borderRadius: AppRadius.br4,
    );
    if (dense) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: decoration,
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: libraryText(
            size: 10,
            weight: AppFont.w500,
            color: foreground,
            height: 11.43 / 9.52,
          ),
        ),
      );
    }
    return Container(
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: decoration,
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: libraryText(size: 12, color: foreground, height: 15.24 / 12),
        ),
      ),
    );
  }
}

/// 计数徽标：24 高、左右 8、圆角 6、浅灰底、12 号中等字重（预览页的页码）。
class LibraryCounter extends StatelessWidget {
  const LibraryCounter(this.label, {this.textKey, super.key});

  final String label;

  /// 挂在文字上的 key，便于测试直接读取显示的内容。
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: AppColors.lineSoft,
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          key: textKey,
          maxLines: 1,
          softWrap: false,
          style: libraryText(
            size: 12,
            weight: AppFont.w500,
            color: AppColors.ink,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// 进度条：4 高圆头轨道，已完成部分为浅紫到品牌紫的渐变。
class LibraryProgressTrack extends StatelessWidget {
  const LibraryProgressTrack({required this.value, super.key});

  /// 0–1。
  final double value;

  @override
  Widget build(BuildContext context) {
    final fraction = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(23)),
      child: SizedBox(
        height: 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: LibraryPalette.track),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [LibraryPalette.trackStart, AppColors.brand],
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(23)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 空状态：通用插图（最大 200 见方）+ 14 号说明，在父级内居中；
/// 可带一行补充说明和一个操作。父级较矮时插图按高度缩小。
class LibraryEmptyState extends StatelessWidget {
  const LibraryEmptyState({
    required this.message,
    this.description,
    this.imageAsset = AppAssets.emptyCoursePlaceholder,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final String? description;
  final String imageAsset;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final note = description;
    final label = actionLabel;
    final action = label == null || onAction == null
        ? null
        : LibraryActionPill(label: label, onTap: onAction);
    return LayoutBuilder(
      builder: (context, constraints) {
        final reserved =
            56.0 +
            (note == null ? 0 : 24) +
            (action == null ? 0 : LibraryActionPill.height + 12);
        final imageSize = constraints.maxHeight.isFinite
            ? (constraints.maxHeight - reserved).clamp(72.0, 200.0)
            : 200.0;
        // 插图四周自带留白，文字上移压进插图底部的留白里。
        final overlap = 18 * imageSize / 200;
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: imageSize,
                  height: imageSize - overlap,
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: imageSize,
                    maxHeight: imageSize,
                    child: Image.asset(
                      imageAsset,
                      width: imageSize,
                      height: imageSize,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: libraryText(
                    size: 14,
                    color: AppColors.ink,
                    height: 1.25,
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    note,
                    textAlign: TextAlign.center,
                    style: libraryText(
                      size: 12,
                      color: AppColors.textPlaceholder,
                      height: 1.5,
                    ),
                  ),
                ],
                if (action != null) ...[const SizedBox(height: 12), action],
                SizedBox(height: overlap),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 右侧抽屉：白底整高面板、内距 20，标题为紫色竖条 + 16 号粗体，下方一条细线。
/// 用 [showLibraryDrawer] 打开，点遮罩关闭。
class LibraryDrawer extends StatelessWidget {
  const LibraryDrawer({
    required this.title,
    required this.child,
    this.width = 344,
    super.key,
  });

  final String title;
  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: SizedBox(
        width: width,
        height: double.infinity,
        child: SafeArea(
          left: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Row(
                  children: [
                    Container(
                      width: 3.25,
                      height: 14.85,
                      decoration: const BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.all(Radius.circular(6)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: libraryText(
                            size: 16,
                            weight: AppFont.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  height: 1,
                  child: ColoredBox(color: AppColors.lineSoft),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 从右侧滑入抽屉：20% 黑色遮罩，滑入不超过 200ms。
Future<T?> showLibraryDrawer<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: const Color(0x33000000),
    transitionDuration: AppMotion.overlayMax,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerRight,
        child: Builder(builder: builder),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: AppMotion.overlayCurve),
            ),
        child: child,
      );
    },
  );
}
