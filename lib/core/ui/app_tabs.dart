import 'package:flutter/material.dart';

import '../theme/app_font.dart';
import 'app_colors.dart';
import 'app_pressable.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// [AppTabs] 的单个页签。
class AppTab<T> {
  const AppTab({required this.value, required this.label, this.count});

  final T value;
  final String label;

  /// 页签后的数量（如「待点评 12」），null 不显示。
  final int? count;
}

/// 文字页签：使用短圆角指示条，视频分类可用无指示条的大字样式。
class AppTabs<T> extends StatelessWidget {
  const AppTabs({
    required this.tabs,
    required this.value,
    required this.onChanged,
    this.gap = 24,
    this.textOnly = false,
    super.key,
  });

  final List<AppTab<T>> tabs;
  final T value;
  final ValueChanged<T> onChanged;

  /// 页签之间的间距。
  final double gap;
  final bool textOnly;

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
            textOnly: textOnly,
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
    required this.textOnly,
    required this.onTap,
  });

  final AppTab<T> tab;
  final bool selected;
  final bool textOnly;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = tab.count;
    final label = count == null ? tab.label : '${tab.label}($count)';
    final color = selected
        ? (textOnly ? AppColors.ink : AppColors.brand)
        : AppColors.textSecondary;
    final style = AppText.body13.copyWith(
      color: color,
      fontWeight: selected || textOnly ? AppFont.w500 : AppFont.w400,
      fontSize: textOnly ? (selected ? 18 : 14) : 13,
    );
    return AppPressable(
      onTap: onTap,
      selected: selected,
      child: SizedBox(
        height: textOnly ? 36 : 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (textOnly)
              ExcludeSemantics(
                child: RichText(
                  text: TextSpan(
                    text: label,
                    style: style.copyWith(
                      fontSize: 18,
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tab.label, maxLines: 1, softWrap: false, style: style),
                if (count != null) Text('($count)', style: style),
              ],
            ),
            if (selected && !textOnly)
              const Positioned(
                bottom: 0,
                child: SizedBox(
                  width: 28,
                  height: 3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: AppRadius.brPill,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
