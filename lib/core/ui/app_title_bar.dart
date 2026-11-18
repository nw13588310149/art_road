import 'package:flutter/widgets.dart';

import 'app_spacing.dart';
import 'app_text.dart';

/// 新页面的页头：页面名称看得见，位置和字号在所有新页面里相同。
///
/// 从左到右是名称、视图切换（[tabs]）、一行说明（[caption]），操作（[actions]）
/// 靠右。高 44。名称和导航或入口上的叫法一致。
///
/// 和 `AppPageHeader` 的区别：那个只把标题交给读屏，不画出来，保留页面在用。
class AppTitleBar extends StatelessWidget {
  const AppTitleBar({
    required this.title,
    this.caption = '',
    this.tabs,
    this.actions = const <Widget>[],
    super.key,
  });

  final String title;
  final String caption;

  /// 视图切换，通常是 `AppViewTabs`。
  final Widget? tabs;

  /// 靠右的操作：最多一个主按钮，其余用 `AppPlainButton`。
  final List<Widget> actions;

  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Semantics(
            header: true,
            child: Text(title, style: AppText.title20),
          ),
          if (tabs != null) ...[const SizedBox(width: AppSpace.s32), tabs!],
          if (caption.isNotEmpty) ...[
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body13,
              ),
            ),
          ] else
            const Spacer(),
          ...actions,
        ],
      ),
    );
  }
}
