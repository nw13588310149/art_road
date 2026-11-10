import 'package:flutter/material.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';

import '../../../../core/art/art_subject.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../shell/ui/shell_layout.dart';
import '../../data/schedule_color_palette.dart';
import '../../data/schedule_course_card_builder.dart';

const double kScheduleCourseCardWidth = 176;
const double kScheduleCourseCardHeight = 96;
const double kScheduleCourseCellInset = 12;
const double kScheduleCourseCardGap = 6;

double scheduleCourseCardHeight(ScheduleCourseCardKind kind) =>
    kind == ScheduleCourseCardKind.bigExtended
    ? 120
    : kScheduleCourseCardHeight;

double scheduleCourseCellHeight(Iterable<ScheduleCourseCardData> cards) {
  var height = 2 * kScheduleCourseCellInset;
  for (final card in cards) {
    if (height > 2 * kScheduleCourseCellInset) height += kScheduleCourseCardGap;
    height += scheduleCourseCardHeight(card.kind);
  }
  return height.clamp(
    kScheduleCourseCardHeight + 2 * kScheduleCourseCellInset,
    double.infinity,
  );
}

/// 课程卡的科目色：素描 / 色彩 / 速写取科目色，其他课程用品牌紫。
Color scheduleSubjectAccent(String courseName) {
  for (final subject in ArtSubject.values) {
    if (courseName.contains(subject.label)) {
      return subject.accent;
    }
  }
  return AppColors.brand;
}

/// 课表课程卡：上方展示教室和课型，下方用白底展示课程信息。
class ScheduleCourseCard extends StatelessWidget {
  const ScheduleCourseCard({
    super.key,
    required this.data,
    this.editable = false,
    this.isPast = false,
    this.topRightBadge,
  });

  final ScheduleCourseCardData data;
  final bool editable;
  final bool isPast;
  final Widget? topRightBadge;

  @override
  Widget build(BuildContext context) {
    final accent = scheduleSubjectAccent(data.name);
    final background = isPast
        ? AppColors.surfaceSubtle
        : data.bgColor ?? AppColors.tint(accent, 0.13);
    final locationColor = isPast
        ? AppColors.textSecondary
        : scheduleTitleColorForBackground(background);
    final isSmall = scheduleIsSmallKind(scheduleCourseCardThemeKind(data.kind));
    final extended = data.kind == ScheduleCourseCardKind.bigExtended;
    final capacity = isSmall ? data.capacity : null;
    final kindTag = ScheduleClassKindTag(
      isSmall: isSmall,
      outlined: extended,
      muted: isPast,
    );
    return SizedBox(
      width: kScheduleCourseCardWidth,
      height: scheduleCourseCardHeight(data.kind),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadius.br8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Column(
            children: [
              SizedBox(
                height: 28,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          data.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption12Strong.copyWith(
                            color: locationColor,
                          ),
                        ),
                      ),
                      if (!extended) ...[
                        const SizedBox(width: AppSpace.s4),
                        topRightBadge ?? kindTag,
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body14Strong.copyWith(height: 16 / 14),
                      ),
                      const SizedBox(height: AppSpace.s4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              data.subline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption12.copyWith(
                                color: AppColors.textSecondary,
                                height: 16 / 12,
                              ),
                            ),
                          ),
                          if (capacity != null) ...[
                            const SizedBox(width: AppSpace.s4),
                            Text(capacity, style: AppText.caption12),
                          ],
                        ],
                      ),
                      if (extended) ...[
                        const Spacer(),
                        topRightBadge ?? kindTag,
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 原版 176×48 的格内编辑入口，申请和排课使用相同图标与行高。
class ScheduleCourseCellAction extends StatelessWidget {
  const ScheduleCourseCellAction({
    required this.label,
    required this.onTap,
    super.key,
  });

  static const double height = 48;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      child: Container(
        width: kScheduleCourseCardWidth,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: AppRadius.br8,
          border: Border.all(color: AppColors.lineSoft),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/smartCampus/schedule_edit/apply_course.png',
              width: 14,
              height: 14,
              excludeFromSemantics: true,
            ),
            const SizedBox(width: kScheduleCourseCardGap),
            Text(label, style: AppText.caption12Strong),
          ],
        ),
      ),
    );
  }
}

/// 左滑卡片露出右侧删除入口（课表编辑、作业列表等 iPad 触控场景）。
class ScheduleCourseSwipeDelete extends StatefulWidget {
  const ScheduleCourseSwipeDelete({
    super.key,
    required this.child,
    required this.onDelete,
    this.cardHeight,
    this.widthDesign = 176,
    this.borderRadiusDesign = 8,
  });

  final Widget child;
  final VoidCallback onDelete;

  /// 设计稿高度；为 null 时随 [child] 自适应。
  final double? cardHeight;

  /// 设计稿宽度；为 null 时占满父级宽度。
  final double? widthDesign;
  final double borderRadiusDesign;

  @override
  State<ScheduleCourseSwipeDelete> createState() =>
      _ScheduleCourseSwipeDeleteState();
}

class _ScheduleCourseSwipeDeleteState extends State<ScheduleCourseSwipeDelete> {
  static const double _actionWidthDesign = 48;

  double _offset = 0;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final actionWidth = ui(_actionWidthDesign);
    final isOpen = _offset < 0;
    final width = widget.widthDesign == null
        ? double.infinity
        : ui(widget.widthDesign!);
    final borderRadius = BorderRadius.circular(ui(widget.borderRadiusDesign));

    final swipeBody = ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: actionWidth,
            child: AppPressable(
              onTap: widget.onDelete,
              semanticLabel: '删除',
              child: Center(
                child: Image.asset(
                  AppAssets.coursewareActionDelete,
                  width: ui(20),
                  height: ui(20),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_offset, 0),
            child: GestureDetector(
              onTap: isOpen ? _close : null,
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _offset = (_offset + details.delta.dx).clamp(
                    -actionWidth,
                    0.0,
                  );
                });
              },
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                final shouldOpen =
                    _offset < -actionWidth * 0.45 || velocity < -180;
                setState(() {
                  _offset = shouldOpen ? -actionWidth : 0;
                });
              },
              child: widget.child,
            ),
          ),
        ],
      ),
    );

    if (widget.cardHeight == null) {
      return SizedBox(width: width, child: swipeBody);
    }
    return SizedBox(
      width: width,
      height: ui(widget.cardHeight!),
      child: swipeBody,
    );
  }

  void _close() => setState(() => _offset = 0);
}

/// 大课 / 小课标签：圆点区分课型，已结束时转灰。
class ScheduleClassKindTag extends StatelessWidget {
  const ScheduleClassKindTag({
    super.key,
    required this.isSmall,
    required this.outlined,
    this.muted = false,
  });

  final bool isSmall;

  /// 旧参数，组件库标签统一无描边。
  final bool outlined;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return AppTag(
      label: isSmall ? '小课' : '大课',
      background: AppColors.surface,
      color: muted ? AppColors.textTertiary : AppColors.textSecondary,
      dotColor: muted
          ? AppColors.textPlaceholder
          : (isSmall ? AppColors.success : AppColors.brandSoft),
    );
  }
}
