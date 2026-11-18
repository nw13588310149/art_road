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
    super.key,
  });

  /// 图片本身，由调用方决定比例和圆角（见 [frame]）。
  final Widget image;
  final String title;
  final String meta;

  /// 说明的颜色：默认三级文字色；需要提示进行中的状态时用 `AppColors.brandDeep`。
  final Color metaColor;
  final VoidCallback? onTap;

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
    final tile = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        image,
        const SizedBox(height: AppSpace.s12),
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
    return onTap == null
        ? tile
        : AppPressable(onTap: onTap, semanticLabel: title, child: tile);
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
