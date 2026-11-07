import 'package:flutter/material.dart';

import '../theme/app_font.dart';
import 'app_badge.dart';
import 'app_colors.dart';
import 'app_pressable.dart';
import 'app_shadows.dart';
import 'app_spacing.dart';

/// [AppSegmented] 的单个选项。
class AppSegment<T> {
  const AppSegment({
    required this.value,
    required this.label,
    this.enabled = true,
    this.badge,
  });

  final T value;
  final String label;
  final bool enabled;

  /// 红色角标文字（如待审核数「3」「10+」）。
  final String? badge;
}

/// 浅灰轨道 + 实底选中块，选中立即切换。
///
/// 用于卡片内或页头的 2–5 个互斥视图切换；页面级主导航用 [AppTabs]。
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    required this.segments,
    required this.value,
    required this.onChanged,
    this.size = AppControlSize.md,
    this.expand = false,
    this.enabled = true,
    this.trackColor = AppColors.segmentTrack,
    this.selectedColor = AppColors.brand,
    this.neutral = false,
    super.key,
  });

  final List<AppSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final AppControlSize size;

  /// 各段等分父级宽度（父级宽度必须有界）。
  final bool expand;
  final bool enabled;
  final Color trackColor;
  final Color selectedColor;
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    final md = size == AppControlSize.md;
    final children = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      if (i > 0) {
        children.add(SizedBox(width: neutral ? AppSpace.s16 : 2));
      }
      final item = _SegmentItem<T>(
        segment: segment,
        selected: segment.value == value,
        md: md,
        neutral: neutral,
        selectedColor: selectedColor,
        onTap: enabled ? () => onChanged(segment.value) : null,
      );
      children.add(expand ? Expanded(child: item) : item);
    }
    final track = Container(
      height: neutral ? 46 : (md ? 32 : AppSize.controlSm),
      padding: EdgeInsets.all(neutral ? 5 : 2),
      decoration: BoxDecoration(
        color: neutral ? AppColors.surfaceSubtle : trackColor,
        borderRadius: AppRadius.br8,
        border: neutral ? Border.all(color: AppColors.lineSoft) : null,
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
    return enabled
        ? track
        : Opacity(opacity: AppOpacity.disabled, child: track);
  }
}

class _SegmentItem<T> extends StatelessWidget {
  const _SegmentItem({
    required this.segment,
    required this.selected,
    required this.md,
    required this.neutral,
    required this.selectedColor,
    required this.onTap,
  });

  final AppSegment<T> segment;
  final bool selected;
  final bool md;
  final bool neutral;
  final Color selectedColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final badge = segment.badge;
    return AppPressable(
      onTap: onTap,
      enabled: segment.enabled,
      selected: selected,
      child: Container(
        constraints: BoxConstraints(minWidth: md ? 44 : 36),
        padding: EdgeInsets.symmetric(
          horizontal: neutral ? 16 : (md ? 14 : 10),
        ),
        alignment: Alignment.center,
        decoration: selected
            ? BoxDecoration(
                color: neutral ? AppColors.surface : selectedColor,
                borderRadius: const BorderRadius.all(Radius.circular(6)),
                boxShadow: neutral ? AppShadow.thumb : null,
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                segment.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: neutral ? 14 : 13,
                  height: 1.2,
                  fontWeight: selected || neutral ? AppFont.w500 : AppFont.w400,
                  color: selected
                      ? (neutral ? AppColors.ink : AppColors.onBrand)
                      : (neutral ? AppColors.textSecondary : AppColors.ink),
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
            ),
            if (badge != null && badge.isNotEmpty) ...[
              const SizedBox(width: 4),
              AppBadge(label: badge),
            ],
          ],
        ),
      ),
    );
  }
}
