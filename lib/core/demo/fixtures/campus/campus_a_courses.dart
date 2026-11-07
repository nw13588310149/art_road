import '../../data/demo_campus_data.dart';
import '../../demo_clock.dart';
import 'campus_a_common.dart';
import 'campus_b_common.dart';
import 'campus_b_courses.dart';

enum CampusCoursePhase { upcoming, inProgress, ended }

/// 学生视角的一节课。课程与老师端、管理端同源（[cbCoursesOn]：各班周课表、
/// 小班课、个人改画小课、管理员排课与已通过的小课申请），这里只换成学生端
/// 接口需要的字段。
class CampusCourse {
  const CampusCourse({
    required this.id,
    required this.day,
    required this.lineNum,
    required this.type,
    required this.start,
    required this.end,
    required this.subjectName,
    required this.teacher,
    required this.schoolClass,
    required this.room,
    this.className = '',
    this.studentCount = 0,
    this.color = '',
    this.autoComplete = true,
  });

  final String id;
  final DateTime day;

  /// 节次（对应 `schoolTimeConfigList`：1 上午 / 2 下午 / 3 晚上）。
  final int lineNum;

  /// 0 大课 / 1 小课。
  final int type;
  final String start;
  final String end;
  final String subjectName;
  final DemoCampusStaff teacher;

  /// 学生所在的行政班（围栏、补签记录用）。
  final DemoCampusClass schoolClass;
  final String room;

  /// 上课班级名：小班课为小班名，个人小课为「行政班 · 小课」。
  final String className;
  final int studentCount;
  final String color;

  /// 课程结束且学生未操作时，是否按「已完成签到」生成记录（否则记缺勤）。
  final bool autoComplete;

  bool get isSmall => type == 1;

  DateTime get startAt => CampusA.at(day, start);

  DateTime get endAt => CampusA.at(day, end);

  int get subjectId => CampusACourses.subjectIdOf(subjectName);

  CampusCoursePhase phaseAt(DateTime now) {
    if (now.isBefore(startAt)) {
      return CampusCoursePhase.upcoming;
    }
    if (now.isAfter(endAt)) {
      return CampusCoursePhase.ended;
    }
    return CampusCoursePhase.inProgress;
  }

  /// `courseList` 行（学生课表 / 首页 / 课堂签到共用）。
  Map<String, dynamic> row() {
    final date = CampusA.date(day);
    return <String, dynamic>{
      'id': id,
      'courseId': id,
      'date': date,
      'lineNum': lineNum,
      'type': type,
      'timeBegin': start,
      'timeEnd': end,
      'courseStartTime': '$date $start:00',
      'courseEndTime': '$date $end:00',
      'subjectId': subjectId,
      'subjectName': subjectName,
      'courseName': subjectName,
      'teacherId': teacher.userId,
      'teacherRealname': teacher.name,
      'teacherName': teacher.name,
      'teacherHeadUrl': '',
      'classId': schoolClass.id,
      'className': className.isNotEmpty
          ? className
          : (isSmall ? '${schoolClass.name} · 小课' : schoolClass.name),
      'classroomName': room,
      'color': color.isNotEmpty
          ? color
          : CampusACourses.colorOf(subjectName, isSmall: isSmall),
      'logo': '',
      'totalCount': studentCount,
    };
  }
}

abstract final class CampusACourses {
  /// 画室作息：上午 / 下午 / 晚上三个固定时段（[DemoClock.daySlots]）。
  static final slots = <({int lineNum, String start, String end, String name})>[
    for (var i = 0; i < DemoClock.daySlots.length; i++)
      (
        lineNum: i + 1,
        start: DemoClock.daySlots[i].$1,
        end: DemoClock.daySlots[i].$2,
        name: cbLineNames[i],
      ),
  ];

  static int subjectIdOf(String name) {
    if (name.contains('模拟')) return 43;
    if (name.contains('素描')) return 38;
    if (name.contains('色彩')) return 39;
    if (name.contains('速写')) return 40;
    if (name.contains('常识')) return 41;
    if (name.contains('文化')) return 42;
    return 43;
  }

  static String colorOf(String name, {bool isSmall = false}) =>
      cbCourseColor(name, small: isSmall);

  /// 学生是否上这节课：大课看行政班，小课看参与名单（没有名单时看小班成员）。
  static bool _attends(CbCourse c, String studentId, String homeClassId) {
    if (!c.isSmall) {
      return c.classId == homeClassId;
    }
    if (c.studentIds.isNotEmpty) {
      return c.studentIds.contains(studentId);
    }
    return cbClassStudentIds(c.classId).contains(studentId);
  }

  static CampusCourse _fromCb(CbCourse c, DemoCampusClass home) {
    final cls = cbClass(c.classId);
    final className = cls == null
        ? home.name
        : c.isSmall && !cbIsSmallClass(cls)
        ? '${cbStr(cls['name'])} · 小课'
        : cbStr(cls['name']);
    return CampusCourse(
      id: c.id,
      day: c.day,
      lineNum: c.lineNum,
      type: c.type,
      start: c.start,
      end: c.end,
      subjectName: c.subjectName,
      teacher: cbStaff(c.teacherUserId) ?? DemoCampusData.staff.first,
      schoolClass: home,
      room: cbClassroomName(c.classroomId),
      className: className,
      studentCount: cbCourseStudents(c).length,
      color: c.color,
    );
  }

  /// 学生某天的全部课程（按开始时间排序）。
  static List<CampusCourse> forStudent(
    int personIndex,
    DateTime day,
    DateTime now,
  ) {
    final person = CampusA.person(personIndex);
    final homeRow = cbHomeClassOf(person);
    final home = CampusA.classOf(personIndex);
    final homeId = homeRow == null ? home.id : cbStr(homeRow['id']);
    return [
      for (final c in cbCoursesOn(day))
        if (_attends(c, person.archiveId, homeId)) _fromCb(c, home),
    ]..sort((a, b) => a.start.compareTo(b.start));
  }

  static CampusCourse? findForStudent(
    String courseId,
    int personIndex,
    DateTime now,
  ) {
    final course = cbCourseById(courseId);
    if (course == null) {
      return null;
    }
    for (final c in forStudent(personIndex, course.day, now)) {
      if (c.id == courseId) {
        return c;
      }
    }
    return null;
  }
}
