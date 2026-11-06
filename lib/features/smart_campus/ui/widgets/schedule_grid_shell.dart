import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

import '../../../shell/ui/shell_layout.dart';

const Color _kInnerGray = Color(0xFFF5F6FA);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kTextDivider = Color(0xFFCECED1);

const double kScheduleGridTimeColWidth = 120;
const double kScheduleGridDayColWidth = 200;
const double kScheduleGridHeaderHeight = 60;

class ScheduleGridTimeSlot {
  const ScheduleGridTimeSlot({
    required this.start,
    required this.end,
    required this.height,
  });

  final String start;
  final String end;
  final double height;
}

class ScheduleGridDayHeader {
  const ScheduleGridDayHeader({
    required this.weekdayLabel,
    required this.dateLabel,
    required this.date,
    this.today = false,
  });

  final String weekdayLabel;
  final String dateLabel;
  final DateTime date;
  final bool today;
}

/// 课表网格壳层：左侧冻结时间列 + 右侧横/纵滚动日期区。
///
/// 横向滚动只保留一个 [ScrollController]（绑在内容区）。
/// 表头通过 [Transform.translate] 跟随偏移；[UnconstrainedBox] 允许表头按全宽
/// 布局后再裁剪，避免 [Expanded] 内直接放超宽 child 触发 overflow。
class ScheduleGridShell extends StatefulWidget {
  const ScheduleGridShell({
    super.key,
    required this.slots,
    required this.days,
    required this.body,
  });

  final List<ScheduleGridTimeSlot> slots;
  final List<ScheduleGridDayHeader> days;

  /// 已按 7 列 × N 行拼好的日期区主体（宽度由壳层约束为 daysWidth）。
  final Widget body;

  @override
  State<ScheduleGridShell> createState() => ScheduleGridShellState();
}

class ScheduleGridShellState extends State<ScheduleGridShell> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  /// 将指定日期列与节次滚动到可视区域（教师端「申请记录」跳转使用）。
  bool scrollToDaySlot({
    required int dayIdx,
    required int slotIdx,
  }) {
    if (!_verticalController.hasClients || !_horizontalController.hasClients) {
      return false;
    }
    final ui = DashboardScaleScope.of(context).ui;

    var verticalOffset = 0.0;
    for (var i = 0; i < slotIdx && i < widget.slots.length; i++) {
      verticalOffset += ui(widget.slots[i].height);
    }
    final maxVertical = _verticalController.position.maxScrollExtent;
    _verticalController.jumpTo(verticalOffset.clamp(0.0, maxVertical));

    final dayOffset = ui(kScheduleGridDayColWidth) * dayIdx;
    final viewportWidth = _horizontalController.position.viewportDimension;
    final maxHorizontal = _horizontalController.position.maxScrollExtent;
    final centered = dayOffset - (viewportWidth - ui(kScheduleGridDayColWidth)) / 2;
    _horizontalController.jumpTo(centered.clamp(0.0, maxHorizontal));
    return true;
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final daysWidth = ui(kScheduleGridDayColWidth) * widget.days.length;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ui(12)),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            SizedBox(
              height: ui(kScheduleGridHeaderHeight),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: ui(kScheduleGridTimeColWidth),
                    child: const ScheduleGridTimeHeader(),
                  ),
                  Expanded(
                    child: ClipRect(
                      child: UnconstrainedBox(
                        alignment: Alignment.centerLeft,
                        constrainedAxis: Axis.vertical,
                        clipBehavior: Clip.hardEdge,
                        child: AnimatedBuilder(
                          animation: _horizontalController,
                          builder: (context, child) {
                            final offset = _horizontalController.hasClients
                                ? _horizontalController.offset
                                : 0.0;
                            return Transform.translate(
                              offset: Offset(-offset, 0),
                              child: child,
                            );
                          },
                          child: SizedBox(
                            width: daysWidth,
                            height: ui(kScheduleGridHeaderHeight),
                            child: ScheduleGridDaysHeaderRow(
                              days: widget.days,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _verticalController,
                clipBehavior: Clip.hardEdge,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ScheduleGridTimeColumn(slots: widget.slots),
                    Expanded(
                      child: RepaintBoundary(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          controller: _horizontalController,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: daysWidth,
                            child: widget.body,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScheduleGridTimeColumn extends StatelessWidget {
  const ScheduleGridTimeColumn({super.key, required this.slots});

  final List<ScheduleGridTimeSlot> slots;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      width: ui(kScheduleGridTimeColWidth),
      child: Column(
        children: [
          for (final slot in slots)
            Container(
              width: double.infinity,
              height: ui(slot.height),
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: _kBorderSoft),
                  bottom: BorderSide(color: _kBorderSoft),
                ),
              ),
              alignment: Alignment.center,
              child: ScheduleGridTimeRange(start: slot.start, end: slot.end),
            ),
        ],
      ),
    );
  }
}

class ScheduleGridTimeHeader extends StatelessWidget {
  const ScheduleGridTimeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: double.infinity,
      height: ui(kScheduleGridHeaderHeight),
      decoration: const BoxDecoration(
        color: _kInnerGray,
        border: Border(
          right: BorderSide(color: _kBorderSoft),
          bottom: BorderSide(color: _kBorderSoft),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _ScheduleGridDiagonalLinePainter()),
          ),
          Positioned(
            right: ui(20),
            top: ui(10),
            child: Text(
              '日期',
              style: TextStyle(
                fontSize: ui(12),
                color: Colors.black,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1,
              ),
            ),
          ),
          Positioned(
            left: ui(20),
            bottom: ui(12),
            child: Text(
              '节次',
              style: TextStyle(
                fontSize: ui(12),
                color: Colors.black,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScheduleGridDaysHeaderRow extends StatelessWidget {
  const ScheduleGridDaysHeaderRow({super.key, required this.days});

  final List<ScheduleGridDayHeader> days;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return SizedBox(
      height: ui(kScheduleGridHeaderHeight),
      child: Row(
        children: [
          for (var i = 0; i < days.length; i++)
            Container(
              width: ui(kScheduleGridDayColWidth),
              height: ui(kScheduleGridHeaderHeight),
              decoration: BoxDecoration(
                color: days[i].today ? Colors.white : _kInnerGray,
                border: Border(
                  bottom: const BorderSide(color: _kBorderSoft),
                  left: i == 0
                      ? BorderSide.none
                      : const BorderSide(color: _kBorderSoft),
                ),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    days[i].weekdayLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(14),
                      color: _kTextDark,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: ui(4)),
                  Text(
                    days[i].dateLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kTextHint,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w400,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ScheduleGridTimeRange extends StatelessWidget {
  const ScheduleGridTimeRange({
    super.key,
    required this.start,
    required this.end,
  });

  final String start;
  final String end;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          start,
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 16 / 14,
          ),
        ),
        SizedBox(height: ui(8)),
        Container(width: ui(12), height: 1, color: _kTextDivider),
        SizedBox(height: ui(8)),
        Text(
          end,
          style: TextStyle(
            fontSize: ui(14),
            color: _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 16 / 14,
          ),
        ),
      ],
    );
  }
}

class _ScheduleGridDiagonalLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kBorderSoft
      ..strokeWidth = 1;
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_ScheduleGridDiagonalLinePainter oldDelegate) => false;
}
