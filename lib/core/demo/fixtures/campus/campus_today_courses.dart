/// 首页「课程」卡与智慧校园共用的当天课表。
library;

import '../../data/demo_campus_data.dart';
import '../../demo_accounts.dart';
import 'campus_a_common.dart';
import 'campus_a_courses.dart';
import 'campus_a_sign.dart';
import 'campus_b_common.dart';
import 'campus_b_courses.dart';

/// 当前账号今天的全部课程（含已结束），按开始时间排序。
///
/// 每行与 `/app/school/v2/student|teacher/courseList` 的条目同构（学生取学生端
/// 字段，任课老师 / 班主任取老师端字段），另附首页 `nextSchoolCourse` 解析用的
/// `subject` / `teacher` / `schoolClass` 嵌套对象，可直接作为该接口的返回值。
/// 宿管、管理员没有课表，返回空列表。
List<Map<String, dynamic>> demoTodayCoursesFor(
  DemoAccount account, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final today = cbDay(at);
  if (account.role == DemoRole.student) {
    final index = CampusA.personIndexOf(account);
    return [
      for (final course in CampusACourses.forStudent(index, today, at))
        _withNested(CampusASign.courseRow(account, course, at)),
    ];
  }
  if (account.role != DemoRole.teacher &&
      account.role != DemoRole.headTeacher) {
    return const <Map<String, dynamic>>[];
  }
  final staff =
      DemoCampusData.staffByUserId(account.userId) ??
      (account.teacherId == null
          ? null
          : DemoCampusData.staffById(account.teacherId!));
  if (staff == null) {
    return const <Map<String, dynamic>>[];
  }
  return [
    for (final c in cbCoursesOn(today))
      if (c.teacherUserId == staff.userId) _withNested(cbCourseRow(c)),
  ];
}

Map<String, dynamic> _withNested(Map<String, dynamic> row) =>
    <String, dynamic>{
      ...row,
      'room': row['classroomName'],
      'subject': <String, dynamic>{
        'id': row['subjectId'],
        'name': row['subjectName'],
      },
      'teacher': <String, dynamic>{
        'id': row['teacherId'],
        'realname': row['teacherRealname'] ?? row['teacherName'],
        'headUrl': row['teacherHeadUrl'] ?? '',
      },
      'schoolClass': <String, dynamic>{
        'id': row['classId'],
        'name': row['className'],
      },
    };
