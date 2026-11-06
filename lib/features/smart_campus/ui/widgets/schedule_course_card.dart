import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../shell/ui/shell_layout.dart';
import '../../data/schedule_color_palette.dart';
import '../../data/schedule_course_card_builder.dart';

const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextSecondary = Color(0xFF6D6B75);
const Color _kTextDivider = Color(0xFFCECED1);
const Color _kStatusGreen = Color(0xFF0CAC40);
const Color _kStatusPurple = Color(0xFFA773FF);
const Color _kPastBg = Color(0xFFE6E9F1);
const Color _kPastText = Color(0xFFB6B5BB);
const Color _kPastInnerBg = Colors.white;

class _ResolvedCardTheme {
  const _ResolvedCardTheme({
    required this.bg,
    required this.titleColor,
    required this.isSmall,
    required this.nameColor,
    required this.sublineColor,
    required this.capacityColor,
    required this.innerBg,
    required this.mutedTag,
  });

  final Color bg;
  final Color titleColor;
  final bool isSmall;
  final Color nameColor;
  final Color sublineColor;
  final Color capacityColor;
  final Color innerBg;
  final bool mutedTag;
}

_ResolvedCardTheme _themeFor(ScheduleCourseCardData data, {required bool isPast}) {
  if (isPast) {
    final isSmall = scheduleIsSmallKind(
      scheduleCourseCardThemeKind(data.kind),
    );
    return _ResolvedCardTheme(
      bg: _kPastBg,
      titleColor: _kPastText,
      isSmall: isSmall,
      nameColor: _kPastText,
      sublineColor: _kPastText,
      capacityColor: _kPastText,
      innerBg: _kPastInnerBg,
      mutedTag: true,
    );
  }
  final themeKind = scheduleCourseCardThemeKind(data.kind);
  final bg = data.bgColor ?? scheduleDefaultBg(themeKind);
  return _ResolvedCardTheme(
    bg: bg,
    titleColor: scheduleTitleColorForBackground(bg),
    isSmall: scheduleIsSmallKind(themeKind),
    nameColor: _kTextDark,
    sublineColor: _kTextSecondary,
    capacityColor: _kTextDivider,
    innerBg: Colors.white,
    mutedTag: false,
  );
}

/// 课表网格课程卡（176×96 / 176×120），样式与管理员排课页一致。
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
    final theme = _themeFor(data, isPast: isPast);
    final cardHeight =
        data.kind == ScheduleCourseCardKind.bigExtended ? 120.0 : 96.0;
    return SizedBox(
      width: ui(176),
      height: ui(cardHeight),
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
                width: ui(108),
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
            if (data.kind != ScheduleCourseCardKind.bigExtended)
              Positioned(
                left: ui(126),
                top: ui(6),
                child: topRightBadge ??
                    ScheduleClassKindTag(
                      isSmall: theme.isSmall,
                      outlined: false,
                      muted: theme.mutedTag,
                    ),
              ),
            Positioned(
              left: ui(4),
              top: ui(32),
              child: Container(
                width: ui(168),
                height: ui(
                  data.kind == ScheduleCourseCardKind.bigExtended ? 84 : 60,
                ),
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
            if (data.kind == ScheduleCourseCardKind.bigExtended) ...[
              Positioned(
                left: ui(16),
                top: ui(64),
                child: Text(
                  data.subline,
                  style: TextStyle(
                    fontSize: ui(12),
                    color: theme.sublineColor,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 16 / 12,
                  ),
                ),
              ),
              Positioned(
                left: ui(16),
                top: ui(86),
                child: ScheduleClassKindTag(
                  isSmall: false,
                  outlined: true,
                  muted: theme.mutedTag,
                ),
              ),
            ] else ...[
              Positioned(
                left: ui(16),
                top: ui(64),
                child: SizedBox(
                  width: ui(theme.isSmall && data.capacity != null ? 100 : 140),
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
              if (theme.isSmall && data.capacity != null)
                Positioned(
                  right: ui(16),
                  top: ui(64),
                  child: Text(
                    data.capacity!,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: theme.capacityColor,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 16 / 12,
                    ),
                  ),
                ),
            ],
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
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onDelete,
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
            ),
            Transform.translate(
              offset: Offset(_offset, 0),
              child: GestureDetector(
                onTap: isOpen ? _close : null,
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _offset = (_offset + details.delta.dx)
                        .clamp(-actionWidth, 0.0);
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

class ScheduleClassKindTag extends StatelessWidget {
  const ScheduleClassKindTag({
    super.key,
    required this.isSmall,
    required this.outlined,
    this.muted = false,
  });

  final bool isSmall;
  final bool outlined;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final dotColor = muted
        ? _kPastText
        : (isSmall ? _kStatusGreen : _kStatusPurple);
    final label = isSmall ? '小课' : '大课';
    final textColor = muted ? _kPastText : _kTextDark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(4), vertical: ui(2)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(4)),
        border: outlined ? Border.all(color: _kBorderSoft, width: 1.4) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ui(6),
            height: ui(6),
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          SizedBox(width: ui(4)),
          Text(
            label,
            style: TextStyle(
              fontSize: ui(12),
              color: textColor,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 15.24 / 12,
            ),
          ),
        ],
      ),
    );
  }
}
