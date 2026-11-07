import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../shell/ui/shell_layout.dart';

/// 原版冻结节次列与日期列尺寸。
const double kScheduleGridTimeColWidth = 120;

/// 日期列最小宽度；可用宽度足够时 7 列等分，一屏放下整周。
const double kScheduleGridDayColWidth = 200;
const double kScheduleGridHeaderHeight = 60;

/// 学生课表使用合并控件，教务课表使用独立白底箭头。
class ScheduleGridWeekSwitcher extends StatelessWidget {
  const ScheduleGridWeekSwitcher({
    required this.onPrev,
    required this.onCurrent,
    required this.onNext,
    this.grouped = true,
    super.key,
  });

  final VoidCallback onPrev;
  final VoidCallback? onCurrent;
  final VoidCallback onNext;
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(AppSpace.s4),
      decoration: grouped
          ? BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.br8,
              border: Border.all(color: AppColors.lineSoft),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _weekArrow(
            icon: Icons.chevron_left_rounded,
            label: '上一周',
            onTap: onPrev,
          ),
          AppPressable(
            onTap: onCurrent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
              child: Center(
                child: Text(
                  '本周',
                  style: AppText.body14Strong.copyWith(color: AppColors.ink),
                ),
              ),
            ),
          ),
          _weekArrow(
            icon: Icons.chevron_right_rounded,
            label: '下一周',
            onTap: onNext,
          ),
        ],
      ),
    );
  }

  Widget _weekArrow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return AppPressable(
      semanticLabel: label,
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: grouped ? null : AppColors.surface,
          borderRadius: AppRadius.br8,
        ),
        child: Icon(icon, size: 18, color: AppColors.ink),
      ),
    );
  }
}

class ScheduleGridDateButton extends StatelessWidget {
  const ScheduleGridDateButton({
    required this.label,
    required this.onTap,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.br8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label.replaceAll('-', '/'), style: AppText.body14Strong),
            const SizedBox(width: AppSpace.s8),
            Image.asset(
              AppAssets.iconScheduleCalendar,
              width: 18,
              height: 18,
              excludeFromSemantics: true,
            ),
          ],
        ),
      ),
    );
  }
}

class ScheduleGridTimeSlot {
  const ScheduleGridTimeSlot({
    required this.start,
    required this.end,
    required this.height,
    this.label = '',
  });

  final String start;
  final String end;
  final double height;

  /// 节次名称（上午 / 下午 / 晚上）。
  final String label;
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

/// 课表网格的实际列宽，供日期区单元格读取（7 列等分后的宽度）。
class ScheduleGridScope extends InheritedWidget {
  const ScheduleGridScope({
    required this.dayWidth,
    required super.child,
    super.key,
  });

  final double dayWidth;

  static double dayWidthOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ScheduleGridScope>();
    return scope?.dayWidth ??
        DashboardScaleScope.of(context).ui(kScheduleGridDayColWidth);
  }

  @override
  bool updateShouldNotify(ScheduleGridScope oldWidget) =>
      oldWidget.dayWidth != dayWidth;
}

/// 课表网格壳层：左侧节次列 + 右侧日期区。
///
/// 可用宽度够时 7 列等分、不横向滚动；不够时按最小列宽横向滚动，表头跟随偏移。
class ScheduleGridShell extends StatefulWidget {
  const ScheduleGridShell({
    super.key,
    required this.slots,
    required this.days,
    required this.body,
  });

  final List<ScheduleGridTimeSlot> slots;
  final List<ScheduleGridDayHeader> days;

  /// 已按 7 列 × N 行拼好的日期区主体；单元格宽度用 [ScheduleGridScope.dayWidthOf]。
  final Widget body;

  @override
  State<ScheduleGridShell> createState() => ScheduleGridShellState();
}

class ScheduleGridShellState extends State<ScheduleGridShell> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  double _dayWidth = 0;

  /// 将指定日期列与节次滚动到可视区域（教师端「申请记录」跳转使用）。
  bool scrollToDaySlot({required int dayIdx, required int slotIdx}) {
    if (!_verticalController.hasClients) {
      return false;
    }
    final ui = DashboardScaleScope.of(context).ui;
    var verticalOffset = 0.0;
    for (var i = 0; i < slotIdx && i < widget.slots.length; i++) {
      verticalOffset += ui(widget.slots[i].height);
    }
    final maxVertical = _verticalController.position.maxScrollExtent;
    _verticalController.jumpTo(verticalOffset.clamp(0.0, maxVertical));
    if (_horizontalController.hasClients) {
      final position = _horizontalController.position;
      final centered =
          _dayWidth * dayIdx - (position.viewportDimension - _dayWidth) / 2;
      _horizontalController.jumpTo(
        centered.clamp(0.0, position.maxScrollExtent),
      );
    }
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final timeWidth = ui(kScheduleGridTimeColWidth);
        final count = math.max(1, widget.days.length);
        final available = constraints.maxWidth - timeWidth - 2;
        _dayWidth = math.max(ui(kScheduleGridDayColWidth), available / count);
        final daysWidth = _dayWidth * widget.days.length;
        final scrolls = daysWidth > available + 0.5;
        Widget daysHeader = SizedBox(
          width: daysWidth,
          height: ui(kScheduleGridHeaderHeight),
          child: ScheduleGridDaysHeaderRow(days: widget.days),
        );
        if (scrolls) {
          daysHeader = ClipRect(
            child: UnconstrainedBox(
              alignment: Alignment.centerLeft,
              constrainedAxis: Axis.vertical,
              clipBehavior: Clip.hardEdge,
              child: AnimatedBuilder(
                animation: _horizontalController,
                builder: (context, child) => Transform.translate(
                  offset: Offset(
                    _horizontalController.hasClients
                        ? -_horizontalController.offset
                        : 0,
                    0,
                  ),
                  child: child,
                ),
                child: daysHeader,
              ),
            ),
          );
        }
        final body = SizedBox(width: daysWidth, child: widget.body);
        return ScheduleGridScope(
          dayWidth: _dayWidth,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.br12,
              border: Border.all(color: AppColors.lineSoft),
            ),
            child: ClipRRect(
              borderRadius: AppRadius.br12,
              child: Column(
                children: [
                  SizedBox(
                    height: ui(kScheduleGridHeaderHeight),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: timeWidth,
                          child: const ScheduleGridTimeHeader(),
                        ),
                        Expanded(child: daysHeader),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _verticalController,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ScheduleGridTimeColumn(slots: widget.slots),
                          Expanded(
                            child: scrolls
                                ? SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    controller: _horizontalController,
                                    child: body,
                                  )
                                : body,
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
      },
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
                  right: BorderSide(color: AppColors.lineSoft),
                  bottom: BorderSide(color: AppColors.lineSoft),
                ),
              ),
              alignment: Alignment.center,
              child: ScheduleGridTimeRange(
                label: slot.label,
                start: slot.start,
                end: slot.end,
              ),
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
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceSubtle,
        border: Border(
          right: BorderSide(color: AppColors.lineSoft),
          bottom: BorderSide(color: AppColors.lineSoft),
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _ScheduleGridDiagonalLinePainter()),
          ),
          Positioned(
            right: 20,
            top: 10,
            child: Text('日期', style: AppText.caption12Strong),
          ),
          Positioned(
            left: 20,
            bottom: 12,
            child: Text('节次', style: AppText.caption12Strong),
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
    final width = ScheduleGridScope.dayWidthOf(context);
    return Row(
      children: [
        for (var i = 0; i < days.length; i++)
          Container(
            width: width,
            decoration: BoxDecoration(
              color: days[i].today
                  ? AppColors.brandWash
                  : AppColors.surfaceSubtle,
              border: Border(
                bottom: const BorderSide(color: AppColors.lineSoft),
                left: i == 0
                    ? BorderSide.none
                    : const BorderSide(color: AppColors.lineSoft),
              ),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  days[i].weekdayLabel,
                  maxLines: 1,
                  style: AppText.body14Strong.copyWith(
                    color: days[i].today ? AppColors.brand : AppColors.ink,
                  ),
                ),
                const SizedBox(height: AppSpace.s4),
                Text(
                  days[i].today ? '${days[i].dateLabel} 今天' : days[i].dateLabel,
                  maxLines: 1,
                  style: AppText.caption12.copyWith(
                    color: days[i].today
                        ? AppColors.brand
                        : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class ScheduleGridTimeRange extends StatelessWidget {
  const ScheduleGridTimeRange({
    super.key,
    required this.start,
    required this.end,
    this.label = '',
  });

  final String start;
  final String end;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty) ...[
          Text(label, style: AppText.caption12Strong, maxLines: 1),
          const SizedBox(height: AppSpace.s4),
        ],
        Text(start, style: AppText.body14),
        const SizedBox(height: AppSpace.s8),
        const SizedBox(
          width: AppSpace.s12,
          height: 1,
          child: ColoredBox(color: AppColors.line),
        ),
        const SizedBox(height: AppSpace.s8),
        Text(end, style: AppText.body14),
      ],
    );
  }
}

class _ScheduleGridDiagonalLinePainter extends CustomPainter {
  const _ScheduleGridDiagonalLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset.zero,
      Offset(size.width, size.height),
      Paint()..color = AppColors.line,
    );
  }

  @override
  bool shouldRepaint(_ScheduleGridDiagonalLinePainter oldDelegate) => false;
}
