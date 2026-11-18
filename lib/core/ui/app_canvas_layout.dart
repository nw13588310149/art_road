import 'package:flutter/widgets.dart';

import 'app_colors.dart';
import 'app_page_body.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// 画布加面板：左边一块中性灰的画布放作品或工具画面，右边一栏放说明和设置。
///
/// 范画详情、作品详情、工具箱的各个工具、原卷查看都用这一种。画布占满首屏的
/// 高度，不随面板滚动；面板内容多时自己滚动。放在 `AppPageBody(scrollable: false)`
/// 里、页头下面，用 `Expanded` 撑满剩下的高度。
///
/// - [canvas]：画布里的内容，自己决定怎样完整显示（`BoxFit.contain`、缩放）。
///   不要在画上压文字和按钮。
/// - [canvasFooter]：画布下面一行，放操作提示和画布自己的小操作（全屏、复位），
///   左边是一句 12 号的提示（[hint]），右边是这些操作。
/// - [panel]：右栏，宽屏 280、窄屏 232（[panelWidth] 可以改，工具面板常用 320 / 280）。
class AppCanvasLayout extends StatelessWidget {
  const AppCanvasLayout({
    required this.wide,
    required this.canvas,
    required this.panel,
    this.hint = '',
    this.canvasActions = const <Widget>[],
    this.panelWidth,
    this.panelController,
    this.canvasColor = AppColors.canvas,
    super.key,
  });

  /// `AppPageBody` 给出的宽窄判断。
  final bool wide;
  final Widget canvas;
  final Widget panel;
  final String hint;
  final List<Widget> canvasActions;
  final double? panelWidth;
  final ScrollController? panelController;
  final Color canvasColor;

  /// 画布的圆角。
  static const BorderRadius radius = BorderRadius.all(Radius.circular(8));

  /// 画布下面那一行的高度。
  static const double footerHeight = 44;

  @override
  Widget build(BuildContext context) {
    final hasFooter = hint.isNotEmpty || canvasActions.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: radius,
                    child: ColoredBox(color: canvasColor, child: canvas),
                  ),
                ),
                if (hasFooter)
                  SizedBox(
                    height: footerHeight,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            hint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption12,
                          ),
                        ),
                        ...canvasActions,
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: AppPageBody.columnGap(wide)),
          SizedBox(
            width: panelWidth ?? AppPageBody.sideWidth(wide),
            child: SingleChildScrollView(
              controller: panelController,
              child: panel,
            ),
          ),
        ],
      ),
    );
  }
}
