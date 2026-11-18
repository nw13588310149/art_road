import 'package:flutter/widgets.dart';

import 'app_colors.dart';
import 'app_pressable.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// [AppFilterBar] 的一项。
class AppFilterItem<T> {
  const AppFilterItem({required this.value, required this.label});

  final T value;
  final String label;
}

/// 新页面的筛选条：一行文字，选中的那个垫一块浅灰的胶囊。
///
/// 用来按分类、科目、状态筛选同一个列表。放不下时可以左右滑动。
/// 看得见的胶囊高 36，能点的范围高 44。选中不用品牌紫。
class AppFilterBar<T> extends StatelessWidget {
  const AppFilterBar({
    required this.items,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<AppFilterItem<T>> items;
  final T value;
  final ValueChanged<T> onChanged;

  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final item in items)
              AppPressable(
                onTap: () => onChanged(item.value),
                selected: item.value == value,
                child: Container(
                  height: height,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.only(right: AppSpace.s4),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s12,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: item.value == value
                          ? AppColors.surfaceSubtle
                          : null,
                      borderRadius: AppRadius.brPill,
                    ),
                    child: Text(
                      item.label,
                      style: item.value == value
                          ? AppText.body14Strong
                          : AppText.body14.copyWith(
                              color: AppColors.textSecondary,
                            ),
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
