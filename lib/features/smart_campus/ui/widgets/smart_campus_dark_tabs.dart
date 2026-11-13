import 'package:flutter/material.dart';

import '../../../../core/theme/app_font.dart';
import '../../../../core/ui/app_badge.dart';
import '../../../../core/ui/app_pressable.dart';
import '../../../../core/ui/app_segmented.dart';
import '../../../shell/ui/shell_layout.dart';

/// 原版黑底状态页签：白底容器高 44、内距 4、圆角 8（[bordered] 时 1px
/// `#F3F2F3` 描边）；选项高 36、左右 16、圆角 6、14/500，选中 `#0B081A`
/// 底白字，未选 `#6D6B75`。点了立即切换。
///
/// 对应 R `features/smart_campus/ui/admin_student_management_view.dart`
/// 927–946（容器）与 1091–1130（`_StatusPill`）；无描边版本对应
/// `teacher_homework_review_view.dart` 1140–1220。选项多于可视宽度时横向滚动。
///
/// 选项沿用 [AppSegment]（`value` / `label` / `badge` / `enabled`），
/// `T` 可为可空类型（如用 `null` 表示「全部」）。
class SmartCampusDarkTabs<T> extends StatelessWidget {
  const SmartCampusDarkTabs({
    required this.segments,
    required this.value,
    required this.onChanged,
    this.bordered = true,
    super.key,
  });

  final List<AppSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  /// 容器是否带 1px `#F3F2F3` 描边（学生管理有，作业页没有）。
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(44),
      padding: EdgeInsets.all(ui(4)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        border: bordered
            ? Border.all(color: const Color(0xFFF3F2F3), width: 1)
            : null,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final segment in segments)
              _DarkTabPill(
                segment: segment,
                active: segment.value == value,
                onTap: () => onChanged(segment.value),
              ),
          ],
        ),
      ),
    );
  }
}

class _DarkTabPill<T> extends StatelessWidget {
  const _DarkTabPill({
    required this.segment,
    required this.active,
    required this.onTap,
  });

  final AppSegment<T> segment;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final badge = segment.badge;
    return AppPressable(
      onTap: segment.enabled ? onTap : null,
      enabled: segment.enabled,
      selected: active,
      child: Container(
        height: ui(36),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        margin: EdgeInsets.symmetric(horizontal: ui(2)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0B081A) : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              segment.label,
              style: TextStyle(
                fontSize: ui(14),
                height: 1,
                fontWeight: AppFont.w500,
                color: active ? Colors.white : const Color(0xFF6D6B75),
                fontFamily: 'PingFang SC',
              ),
            ),
            if (badge != null && badge.isNotEmpty) ...[
              SizedBox(width: ui(4)),
              AppBadge(label: badge),
            ],
          ],
        ),
      ),
    );
  }
}
