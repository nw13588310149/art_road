import 'package:flutter/material.dart';
import 'package:the_road_of_art_flutter/core/theme/app_font.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../shell/ui/shell_layout.dart';
import '../../data/schedule_color_palette.dart';
import '../../data/schedule_course_card_builder.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/art/art_subject.dart';

const double kScheduleCourseCardWidth = 176;
const double kScheduleCourseCardHeight = 96;
const double kScheduleCourseCellInset = 12;
const double kScheduleCourseCardGap = 6;

/// 一个格子里放下 [cards] 需要的高度：卡片依次叠放，至少一张卡片高。
double scheduleCourseCellHeight(Iterable<ScheduleCourseCardData> cards) {
  var height = 2 * kScheduleCourseCellInset;
  for (final _ in cards) {
    if (height > 2 * kScheduleCourseCellInset) height += kScheduleCourseCardGap;
    height += kScheduleCourseCardHeight;
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

const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kPastBg = Color(0xFFE6E9F1);
const Color _kPastText = Color(0xFFB6B5BB);
const Color _kPastInnerBg = Colors.white;

class _ResolvedCardTheme {
  const _ResolvedCardTheme({
    required this.bg,
    required this.titleColor,
    required this.nameColor,
    required this.sublineColor,
    required this.innerBg,
  });

  final Color bg;
  final Color titleColor;
  final Color nameColor;
  final Color sublineColor;
  final Color innerBg;
}

_ResolvedCardTheme _themeFor(
  ScheduleCourseCardData data, {
  required bool isPast,
}) {
  if (isPast) {
    return const _ResolvedCardTheme(
      bg: _kPastBg,
      titleColor: _kPastText,
      nameColor: _kPastText,
      sublineColor: _kPastText,
      innerBg: _kPastInnerBg,
    );
  }
  final bg = data.bgColor ?? scheduleDefaultPickerColor;
  return _ResolvedCardTheme(
    bg: bg,
    titleColor: scheduleTitleColorForBackground(bg),
    nameColor: _kTextDark,
    sublineColor: _kTextSecondary,
    innerBg: Colors.white,
  );
}

/// 课表网格课程卡（176×96），管理员、老师、学生的课表共用。
class ScheduleCourseCard extends StatelessWidget {
  const ScheduleCourseCard({
    super.key,
    required this.data,
    this.isPast = false,
  });

  final ScheduleCourseCardData data;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final theme = _themeFor(data, isPast: isPast);
    return SizedBox(
      width: ui(176),
      height: ui(kScheduleCourseCardHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.bg,
          borderRadius: BorderRadius.circular(ui(8)),
        ),
        child: Stack(
          children: [
            Positioned(
              left: ui(16),
              top: ui(8),
              child: SizedBox(
                width: ui(144),
                child: Text(
                  data.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: theme.titleColor,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                    height: 16 / 12,
                  ),
                ),
              ),
            ),
            Positioned(
              left: ui(4),
              top: ui(32),
              child: Container(
                width: ui(168),
                height: ui(60),
                decoration: BoxDecoration(
                  color: theme.innerBg,
                  borderRadius: BorderRadius.circular(ui(6)),
                ),
              ),
            ),
            Positioned(
              left: ui(16),
              top: ui(44),
              child: SizedBox(
                width: ui(140),
                child: Text(
                  data.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: theme.nameColor,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 16 / 14,
                  ),
                ),
              ),
            ),
            Positioned(
              left: ui(16),
              top: ui(64),
              child: SizedBox(
                width: ui(140),
                child: Text(
                  data.subline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: theme.sublineColor,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 16 / 12,
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

/// 176×48 的格内编辑入口：管理员排课时在格子里加课。
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

/// 左滑卡片露出右侧删除入口（课表编辑、作品列表等 iPad 触控场景）。
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
