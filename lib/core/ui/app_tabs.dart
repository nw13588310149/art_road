import 'package:flutter/material.dart';

import '../theme/app_font.dart';
import 'app_colors.dart';
import 'app_pressable.dart';
import 'app_text.dart';

/// [AppTabs] 的单个页签。
class AppTab<T> {
  const AppTab({required this.value, required this.label, this.count});

  final T value;
  final String label;

  /// 页签后的数量（如「待点评 12」），null 不显示。
  final int? count;
}

/// 页面级文字页签：选中为墨色加粗 + 2px 品牌紫下划线，切换立即生效。
class AppTabs<T> extends StatelessWidget {
  const AppTabs({
    required this.tabs,
    required this.value,
    required this.onChanged,
    this.gap = 24,
    super.key,
  });

  final List<AppTab<T>> tabs;
  final T value;
  final ValueChanged<T> onChanged;

  /// 页签之间的间距。
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < tabs.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          _TabItem<T>(
            tab: tabs[i],
            selected: tabs[i].value == value,
            onTap: () => onChanged(tabs[i].value),
          ),
        ],
      ],
    );
  }
}

class _TabItem<T> extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final AppTab<T> tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.ink : AppColors.textSecondary;
    final count = tab.count;
    return AppPressable(
      onTap: onTap,
      selected: selected,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.brand : const Color(0x00000000),
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              tab.label,
              maxLines: 1,
              softWrap: false,
              style: AppText.body16.copyWith(
                color: color,
                fontWeight: selected ? AppFont.w600 : AppFont.w400,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: AppText.number(
                  size: 13,
                  color: selected ? AppColors.ink : AppColors.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
