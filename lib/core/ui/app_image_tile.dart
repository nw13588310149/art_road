import 'package:flutter/widgets.dart';

import 'app_colors.dart';
import 'app_pressable.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// 新页面里的一张图和它的说明：图在上，名称和一行说明在下，没有卡片底。
///
/// 封面、作品、范画的网格都用它。图上不压任何标签，状态和类型写在说明那一行；
/// 名称给两行，不截成一行。整块可点。
class AppImageTile extends StatelessWidget {
  const AppImageTile({
    required this.image,
    required this.title,
    this.meta = '',
    this.metaColor = AppColors.textTertiary,
    this.onTap,
    this.action,
    super.key,
  });

  /// 图片本身，由调用方决定比例和圆角（见 [frame]）。
  final Widget image;
  final String title;
  final String meta;

  /// 说明的颜色：默认三级文字色；需要提示进行中的状态时用 `AppColors.brandDeep`。
  final Color metaColor;
  final VoidCallback? onTap;

  /// 每一格都有的一个小操作（例如收藏），放在名称右边，不压在图上。
  /// 通常是 `AppIconAction`。它自己响应点击，不会打开这一格。
  final Widget? action;

  /// 图下说明区的大致高度（名称两行加说明一行），瀑布流估算列高时用。
  static const double captionExtent = 12 + 44 + 2 + 18;

  /// 图片的圆角。
  static const BorderRadius radius = BorderRadius.all(Radius.circular(6));

  /// 给图片加上统一的圆角和一圈细描边。白纸上的素描放在白色底板上，
  /// 靠这圈描边才看得出边界。
  static Widget frame({required Widget child, double? aspectRatio}) {
    final framed = ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.fromBorderSide(
                    BorderSide(color: AppColors.lineSoft),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return aspectRatio == null
        ? framed
        : AspectRatio(aspectRatio: aspectRatio, child: framed);
  }

  @override
  Widget build(BuildContext context) {
    final caption = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppText.body14Strong,
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption12.copyWith(color: metaColor),
          ),
        ],
      ],
    );
    Widget open(Widget child) => onTap == null
        ? child
        : AppPressable(onTap: onTap, semanticLabel: title, child: child);
    final extra = action;
    if (extra == null) {
      return open(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            image,
            const SizedBox(height: AppSpace.s12),
            caption,
          ],
        ),
      );
    }
    // 有操作时，图和名称各自是打开这一格的入口，操作单独响应。读屏只读图那一个
    // 入口（带上说明），名称那一块不重复。
    final spoken = meta.isEmpty ? title : '$title，$meta';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onTap == null)
          image
        else
          AppPressable(onTap: onTap, semanticLabel: spoken, child: image),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ExcludeSemantics(
                child: open(
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.s12),
                    child: caption,
                  ),
                ),
              ),
            ),
            // 操作的点击区域 44 见方，向上和图的下沿留出 2。
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Transform.translate(
                offset: const Offset(12, 0),
                child: extra,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 瀑布流：图按原比例显示，每一格放到当前最短的一列，列宽相等。
///
/// 素材中心、作品墙这类比例不一的画用它；比例统一的封面用 [AppTileGrid]。
/// [aspectRatioOf] 给出第 i 张图的宽高比（宽 / 高），用来在图片加载前就排好位置，
/// 加载后不跳动。列数和间距同 [AppTileGrid]：横竖混排的画宽屏 4 列、窄屏 3 列。
/// 它按可用宽度算列宽，不能放进 `IntrinsicHeight` / `IntrinsicWidth` 里。
class AppMasonryGrid extends StatelessWidget {
  const AppMasonryGrid({
    required this.itemCount,
    required this.itemBuilder,
    required this.aspectRatioOf,
    required this.columns,
    this.gap = 28,
    this.captionExtent = AppImageTile.captionExtent,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double Function(int index) aspectRatioOf;
  final int columns;
  final double gap;

  /// 图下说明区的估算高度，只用来分列。
  final double captionExtent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = ((box.maxWidth - gap * (columns - 1)) / columns)
            .floorToDouble();
        final buckets = List.generate(columns, (_) => <int>[]);
        final heights = List<double>.filled(columns, 0);
        for (var i = 0; i < itemCount; i++) {
          var target = 0;
          for (var c = 1; c < columns; c++) {
            if (heights[c] < heights[target] - 0.5) target = c;
          }
          buckets[target].add(i);
          final ratio = aspectRatioOf(i);
          heights[target] +=
              width / (ratio > 0 ? ratio : 1) + captionExtent + gap;
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var c = 0; c < columns; c++) ...[
              if (c > 0) SizedBox(width: gap),
              SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (n, i) in buckets[c].indexed) ...[
                      if (n > 0) SizedBox(height: gap),
                      itemBuilder(context, i),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// 等宽的网格：按 [columns] 列排开，每格一样宽，高度随内容。
///
/// 宽屏 5 列、窄屏 4 列是封面这类竖图的默认值；间距宽屏 28、窄屏 24。
/// 它按可用宽度算格宽，所以不能放进 `IntrinsicHeight` / `IntrinsicWidth` 里。
class AppTileGrid extends StatelessWidget {
  const AppTileGrid({
    required this.children,
    required this.columns,
    this.gap = 28,
    super.key,
  });

  final List<Widget> children;
  final int columns;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = ((box.maxWidth - gap * (columns - 1)) / columns)
            .floorToDouble();
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}
