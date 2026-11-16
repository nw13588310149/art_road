// 画室的课只有一种：按班上课，任课老师一键签课。演示数据和解析里都不再有
// 课型、班型，也没有只为另一种课存在的接口。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_backend.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_store.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/campus/campus_a_registry.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/campus/campus_b_common.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/campus/campus_b_courses.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/campus/campus_b_registry.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/platform_core_fixtures.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/data/course_sign_data.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/data/student_check_in_data.dart';

Future<Object?> _post(
  DemoAccount account,
  String path, [
  Map<String, dynamic> body = const {},
]) async {
  final match = DemoBackend.platform.match('POST', path)!;
  return match.handler(
    DemoRequest(
      method: 'POST',
      path: path,
      query: const <String, dynamic>{},
      body: body,
      headers: <String, dynamic>{'app-token': account.token},
      pathParams: match.params,
    ),
  );
}

String _date(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// 最近一个已经过完的工作日（周一到周六都有课）。
DateTime _lastSchoolDay() {
  final now = DateTime.now();
  var day = DateTime(now.year, now.month, now.day - 1);
  while (day.weekday == DateTime.sunday) {
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return day;
}

void main() {
  setUpAll(() {
    registerPlatformCoreFixtures(DemoBackend.platform);
    registerCampusFixturesPartA(DemoBackend.platform);
    registerCampusFixturesPartB(DemoBackend.platform);
  });

  setUp(DemoStore.reset);

  test('classes and courses carry no kind', () {
    final classes = cbClasses();
    expect([for (final c in classes) c['id']], ['501', '502', '503']);
    for (final c in classes) {
      expect(c.containsKey('type'), isFalse, reason: '${c['name']}');
      expect(cbClassJson(c).keys, isNot(contains('type')));
      expect(cbClassJson(c).keys, isNot(contains('classType')));
    }

    final monday = DateTime(2026, 11, 2);
    var count = 0;
    for (var d = 0; d < 7; d++) {
      for (final course in cbCoursesOn(monday.add(Duration(days: d)))) {
        count++;
        final row = cbCourseRow(course);
        expect(row.containsKey('type'), isFalse, reason: course.id);
        // 每节课都是整班上：名单就是班级的在籍学生。
        expect(cbCourseStudents(course), cbActiveStudents(course.classId));
        expect(row['className'], cbClassName(course.classId));
      }
    }
    expect(count, greaterThan(30));
  });

  test('no text about lesson kinds is left in the timetable payloads', () {
    final monday = DateTime(2026, 11, 2);
    final rows = [
      for (var d = 0; d < 7; d++)
        for (final course in cbCoursesOn(monday.add(Duration(days: d))))
          cbCourseRow(course),
    ];
    final text = jsonEncode([rows, cbClassroomList()]);
    for (final word in const ['大课', '小课', '大班', '小班']) {
      expect(text, isNot(contains(word)), reason: word);
    }
  });

  test('routes that only served the other kind of lesson are gone', () {
    for (final path in const [
      '/app/school/v2/teacher/schoolSmallCourseApplySave',
      '/app/school/v2/teacher/schoolSmallCourseApplyList',
      '/app/school/v2/teacher/courseTeacherSignIn',
      '/app/school/v2/teacher/courseTeacherSignOut',
      '/app/school/v2/manager/schoolSmallCourseApplyList',
      '/app/school/v2/manager/schoolSmallCourseApplyAudit',
      '/app/school/v2/manager/courseSignSum1',
      '/app/school/v2/manager/courseSignConfirm',
      '/app/school/v2/manager/courseCommentList',
      '/app/school/v2/student/courseStudentSignIn',
      '/app/school/v2/student/courseStudentSignOut',
      '/app/school/v2/student/courseStudentComment',
    ]) {
      expect(DemoBackend.platform.match('POST', path), isNull, reason: path);
    }
    // 签课、统计和补签审核还在。
    for (final path in const [
      '/app/school/v2/teacher/courseClassSignAll',
      '/app/school/v2/manager/courseSignManager',
      '/app/school/v2/manager/courseSignSum0',
      '/app/school/v2/manager/courseSignMakeupList',
      '/app/school/v2/student/courseSignStat',
    ]) {
      expect(DemoBackend.platform.match('POST', path), isNotNull, reason: path);
    }
  });

  test(
    'the admin summary counts sign makeups instead of confirmations',
    () async {
      final summary = await _post(
        DemoAccounts.admin,
        '/app/school/v2/manager/indexSum',
      );
      expect(summary, isA<Map>());
      final map = summary! as Map;
      expect(map.containsKey('smallCourseSignStatus5Count'), isFalse);
      expect(map['courseSignMakeupStatus0Count'], greaterThan(0));
      expect(map['classCount'], 3);

      final classSum = await _post(
        DemoAccounts.admin,
        '/app/school/v2/manager/classSum',
      );
      expect((classSum! as Map)['classCount'], 3);
      expect((classSum as Map).containsKey('smallClassCount'), isFalse);
    },
  );

  test('a finished lesson tells the student how they were marked', () async {
    final day = _lastSchoolDay();
    final raw = await _post(
      DemoAccounts.student,
      '/app/school/v2/student/courseList',
      {'beginDate': _date(day), 'endDate': _date(day)},
    );
    final rows = ((raw! as Map)[_date(day)] as List).cast<Map>();
    expect(rows, isNotEmpty);
    for (final row in rows) {
      expect(row.containsKey('type'), isFalse);
      expect(row['signStatus'], 2);
      expect(row['studentSignStatus'], isIn([0, 1, 2, 3]));
    }

    final courses = parseStudentTodayCourses(
      raw: raw,
      timeConfigs: const [],
      now: day.add(const Duration(hours: 23)),
      todayIso: _date(day),
    );
    expect(courses, hasLength(rows.length));
    for (final course in courses) {
      expect(course.signed, isTrue);
      expect(course.attendStatus, isNotNull);
      expect(
        studentAttendStatusLabel(course.attendStatus!),
        isIn(['正常', '缺勤', '迟到', '请假']),
      );
    }
  });

  test('a lesson that has not started has no result yet', () {
    final now = DateTime(2026, 11, 4, 7);
    final courses = parseStudentTodayCourses(
      raw: {
        '2026-11-04': [
          {
            'id': '72026110450101',
            'lineNum': 1,
            'timeBegin': '08:30',
            'timeEnd': '11:30',
            'subjectName': '素描',
            'teacherRealname': '李静',
            'classroomName': '城东校区 · 素描教室 A',
            'signStatus': 0,
          },
        ],
      },
      timeConfigs: const [],
      now: now,
      todayIso: '2026-11-04',
    );
    expect(courses.single.signed, isFalse);
    expect(courses.single.attendStatus, isNull);
    expect(courses.single.phase, StudentCourseSlotPhase.upcoming);
  });

  test('a sign status is either signed or not', () {
    expect(CourseSignFlowStatus.fromApi(0), CourseSignFlowStatus.notSigned);
    expect(CourseSignFlowStatus.fromApi(2), CourseSignFlowStatus.signed);
    expect(CourseSignFlowStatus.fromApi('6'), CourseSignFlowStatus.signed);
    expect(CourseSignFlowStatus.labelFor(null), '未签课');
    expect(CourseSignFlowStatus.labelFor(2), '已签课');
    expect(CourseSignFlowStatus.values, hasLength(2));
  });
}
