import 'package:flutter/widgets.dart';

import 'app_colors.dart';
import 'app_pressable.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// [AppViewTabs] 的一项。
class AppViewTab<T> {
  const AppViewTab({required this.value, required this.label, this.count});

  final T value;
  final String label;

  /// 不为空时跟在名称后面，用数字字体。
  final int? count;
}

/// 新页面的视图切换：一行文字，选中的那个是墨色粗体加一条下划线。
///
/// 用来在同一页的几个视图之间切换（书库 / 我的书架，全部 / 未完成 / 已完成）。
/// 它不产生结果，所以不用品牌紫，也不用主按钮。高 44，切换立即生效。
class AppViewTabs<T> extends StatelessWidget {
  const AppViewTabs({
    required this.items,
    required this.value,
    required this.onChanged,
    this.dense = false,
    super.key,
  });

  final List<AppViewTab<T>> items;
  final T value;
  final ValueChanged<T> onChanged;

  /// 分区里的小号切换：14 号字，没有下划线，靠粗细和颜色区分。
  final bool dense;

  static const double height = 44;

  /// 一项的点击区域最小宽度。
  static const double minTapWidth = 44;

  @override
  Widget build(BuildContext context) {
    // 项与项之间的空隙分给两边的点击区域，手指落在空隙里也能点中；第一项
    // 左边和最后一项右边不留，文字仍和外面的对齐线齐平。
    final half = (dense ? AppSpace.s16 : AppSpace.s24) / 2;
    final last = items.length - 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, item) in items.indexed)
          _tab(
            item,
            EdgeInsets.only(
              left: index == 0 ? 0 : half,
              right: index == last ? 0 : half,
            ),
            index == 0
                ? Alignment.centerLeft
                : (index == last ? Alignment.centerRight : Alignment.center),
          ),
      ],
    );
  }

  Widget _tab(AppViewTab<T> item, EdgeInsets padding, Alignment alignment) {
    final selected = item.value == value;
    final style = dense
        ? (selected
              ? AppText.body14Strong
              : AppText.body14.copyWith(color: AppColors.textTertiary))
        : (selected
              ? AppText.title16
              : AppText.body16.copyWith(color: AppColors.textTertiary));
    return AppPressable(
      onTap: () => onChanged(item.value),
      selected: selected,
      child: Container(
        height: height,
        constraints: const BoxConstraints(minWidth: minTapWidth),
        padding: padding,
        alignment: alignment,
        child: _label(item, selected, style),
      ),
    );
  }

  Widget _label(AppViewTab<T> item, bool selected, TextStyle style) {
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            width: 2,
            color: selected && !dense ? AppColors.ink : const Color(0x00000000),
          ),
        ),
      ),
      child: Text.rich(
        TextSpan(
          text: item.label,
          children: [
            if (item.count != null)
              TextSpan(
                text: ' ${item.count}',
                style: AppText.number(
                  size: dense ? 13 : 14,
                  color: selected ? AppColors.ink : AppColors.textTertiary,
                ),
              ),
          ],
        ),
        style: style,
      ),
    );
  }
}
