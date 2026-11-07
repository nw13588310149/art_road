import 'package:flutter/material.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';

import '../../../../core/art/art_subject.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../shell/ui/shell_layout.dart';
import '../../data/schedule_color_palette.dart';
import '../../data/schedule_course_card_builder.dart';

/// 课表课程卡高度（课程名 + 老师或班级 + 教室 + 大课 / 小课标签）。
const double kScheduleCourseCardHeight = 100;

/// 课程卡的科目色：素描 / 色彩 / 速写取科目色，其他课程用品牌紫。
Color scheduleSubjectAccent(String courseName) {
  for (final subject in ArtSubject.values) {
    if (courseName.contains(subject.label)) {
      return subject.accent;
    }
  }
  return AppColors.brand;
}

/// 课表网格课程卡：宽度随列宽，左侧科目色条；已结束的课只把底色和标签转灰，
/// 文字对比度不变。
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
    final ui = DashboardScaleScope.of(context).ui;
    final accent = scheduleSubjectAccent(data.name);
    final isSmall = scheduleIsSmallKind(scheduleCourseCardThemeKind(data.kind));
    final capacity = data.capacity;
    return SizedBox(
      height: ui(kScheduleCourseCardHeight),
      child: ClipRRect(
        borderRadius: AppRadius.br8,
        child: ColoredBox(
          color: isPast ? AppColors.surfaceSubtle : AppColors.tint(accent, 0.08),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                color: isPast ? AppColors.textPlaceholder : accent,
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(ui(8), ui(6), ui(6), ui(6)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              data.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body14Strong,
                            ),
                          ),
                          ?topRightBadge,
                        ],
                      ),
                      if (data.subline.isNotEmpty)
                        Text(
                          data.subline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption12.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (data.location.isNotEmpty)
                        Text(
                          data.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption12,
                        ),
                      const Spacer(),
                      Row(
                        children: [
                          ScheduleClassKindTag(
                            isSmall: isSmall,
                            outlined: false,
                            muted: isPast,
                          ),
                          if (capacity != null) ...[
                            const SizedBox(width: AppSpace.s4),
                            Flexible(
                              child: Text(
                                capacity,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.caption12,
                              ),
                            ),
                          ],
                        ],
                      ),
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
