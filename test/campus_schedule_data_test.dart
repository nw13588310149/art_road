import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_campus_data.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_marking_data.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_clock.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/campus/campus_a_courses.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/campus/campus_b_courses.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/campus/campus_today_courses.dart';

void main() {
  final daySlots = {for (final s in DemoClock.daySlots) '${s.$1}-${s.$2}'};
  final monday = DateTime(2026, 11, 2);
  final week = [for (var d = 0; d < 7; d++) monday.add(Duration(days: d))];

  test('every course sits on one of the fixed daytime slots', () {
    final templates = [
      for (final list in DemoCampusData.classTimetables.values) ...list,
      ...DemoCampusData.demoStudentSmallCourses,
    ];
    for (final s in templates) {
      expect(daySlots, contains('${s.start}-${s.end}'), reason: s.courseName);
    }
    for (final day in week) {
      for (final c in cbCoursesOn(day)) {
        expect(daySlots, contains('${c.start}-${c.end}'), reason: c.id);
      }
    }
  });

  test('no teacher has two courses at the same time', () {
    for (final day in week) {
      final busy = <String>{};
      for (final c in cbCoursesOn(day)) {
        expect(
          busy.add('${c.teacherUserId}|${c.start}'),
          isTrue,
          reason: '${c.date} ${c.start} ${c.subjectName}',
        );
      }
    }
  });

  test('no student has two courses at the same time', () {
    for (final p in DemoMarkingData.instance.persons) {
      for (final day in week) {
        final starts = <String>{};
        for (final c in CampusACourses.forStudent(p.index, day, day)) {
          expect(
            starts.add(c.start),
            isTrue,
            reason: '${p.name} ${c.id} ${c.start}',
          );
        }
      }
    }
  });

  test('the timetable does not move with the current minute', () {
    final day = DateTime(2026, 11, 7);
    List<String> at(DateTime now) => [
      for (final c in CampusACourses.forStudent(1, day, now))
        '${c.id} ${c.start}-${c.end}',
    ];
    expect(at(DateTime(2026, 11, 7, 6, 24)), at(DateTime(2026, 11, 7, 15, 47)));
  });

  test('student and teacher views read the same Saturday courses', () {
    final saturday = DateTime(2026, 11, 7);
    final student = CampusACourses.forStudent(1, saturday, saturday);
    expect(
      [for (final c in student) '${c.start} ${c.subjectName}'],
      ['08:30 模拟考试', '14:00 色彩写生', '19:00 速写改画小课'],
    );
    final teacherSide = {for (final c in cbCoursesOn(saturday)) c.id};
    for (final c in student) {
      expect(teacherSide, contains(c.id));
    }
  });

  test('home today courses match the courseList of the same account', () {
    final now = DateTime(2026, 11, 7, 7, 30);
    final today = DateTime(2026, 11, 7);
    final studentRows = demoTodayCoursesFor(DemoAccounts.student, now: now);
    expect(
      studentRows.length,
      CampusACourses.forStudent(1, today, now).length,
    );
    expect((studentRows.first['subject'] as Map)['name'], '模拟考试');
    expect((studentRows.first['teacher'] as Map)['realname'], '李静');

    final teacherRows = demoTodayCoursesFor(DemoAccounts.teacher, now: now);
    expect([for (final r in teacherRows) r['subjectName']], ['模拟考试']);

    expect(demoTodayCoursesFor(DemoAccounts.admin, now: now), isEmpty);
    expect(demoTodayCoursesFor(DemoAccounts.dormManager, now: now), isEmpty);
  });
}
