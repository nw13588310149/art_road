import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/data/schedule_course_card_builder.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/ui/widgets/schedule_course_card.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/ui/widgets/schedule_grid_shell.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/ui/widgets/schedule_idle_slot.dart';

void main() {
  const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  for (final width in [950.0, 814.0]) {
    testWidgets('课表固定节次列，日期表头和内容同步滚动 · $width', (tester) async {
      tester.view.physicalSize = Size(width, 620);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final gridKey = GlobalKey<ScheduleGridShellState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScheduleGridShell(
              key: gridKey,
              slots: const [
                ScheduleGridTimeSlot(
                  label: '上午',
                  start: '08:30',
                  end: '11:30',
                  height: ScheduleIdleSlot.designSlotHeight,
                ),
              ],
              days: [
                for (var i = 0; i < weekdays.length; i++)
                  ScheduleGridDayHeader(
                    weekdayLabel: weekdays[i],
                    dateLabel: '11-0${i + 1}',
                    date: DateTime(2026, 11, i + 1),
                  ),
              ],
              body: const SizedBox(
                height: ScheduleIdleSlot.designSlotHeight,
                child: ScheduleIdleSlot(),
              ),
            ),
          ),
        ),
      );
      final timeHeader = find.byType(ScheduleGridTimeHeader);
      final timeHeaderPosition = tester.getTopLeft(timeHeader);
      expect(tester.getSize(timeHeader), const Size(120, 60));
      expect(find.text('节次'), findsOneWidget);
      expect(find.text('日期'), findsOneWidget);
      expect(find.text('空闲'), findsOneWidget);
      final dayHeaders = find.descendant(
        of: find.byType(ScheduleGridDaysHeaderRow),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container && widget.constraints?.maxWidth == 200,
        ),
      );
      expect(dayHeaders, findsNWidgets(7));
      expect(tester.getSize(dayHeaders.first).width, 200);

      final sunday = find.text('周日');
      expect(tester.getCenter(sunday).dx, greaterThan(width));
      expect(
        gridKey.currentState!.scrollToDaySlot(dayIdx: 6, slotIdx: 0),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(tester.getCenter(sunday).dx, lessThan(width));
      expect(tester.getTopLeft(timeHeader), timeHeaderPosition);
    });
  }

  testWidgets('标准课卡与扩展课卡沿用原版尺寸', (tester) async {
    const standard = ScheduleCourseCardData(
      kind: ScheduleCourseCardKind.bigStandard,
      location: '素描教室 A',
      name: '素描',
      subline: '李静',
      bgColor: Color(0xFFE7DFFF),
    );
    const extended = ScheduleCourseCardData(
      kind: ScheduleCourseCardKind.bigExtended,
      location: '素描教室 B',
      name: '素描',
      subline: '张老师',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ScheduleCourseCard(data: standard),
              ScheduleCourseCard(data: extended),
            ],
          ),
        ),
      ),
    );
    final cards = find.byType(ScheduleCourseCard);
    expect(tester.getSize(cards.first), const Size(176, 96));
    expect(tester.getSize(cards.last), const Size(176, 120));
    expect(scheduleCourseCellHeight([standard, extended]), 246);
    expect(tester.takeException(), isNull);
  });
}
