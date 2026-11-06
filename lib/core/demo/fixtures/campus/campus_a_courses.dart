import '../../data/demo_campus_data.dart';
import 'campus_a_common.dart';

enum CampusCoursePhase { upcoming, inProgress, ended }

/// 一节课（大课按班级课表模板生成，小课为学生个人课程）。
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
    this.autoComplete = true,
  });

  final String id;
  final DateTime day;

  /// 节次（对应 `schoolTimeConfigList`）；今日临时小课为 0，按 [start] / [end] 展示。
  final int lineNum;

  /// 0 大课 / 1 小课。
  final int type;
  final String start;
  final String end;
  final String subjectName;
  final DemoCampusStaff teacher;
  final DemoCampusClass schoolClass;
  final String room;

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
      'className': isSmall ? '${schoolClass.name} · 小课' : schoolClass.name,
      'classroomName': room,
      'color': CampusACourses.colorOf(subjectName, isSmall: isSmall),
      'logo': '',
      'totalCount': isSmall ? 1 : schoolClass.students.length,
    };
  }
}

abstract final class CampusACourses {
  /// 画室作息：上午 / 下午 / 晚间三段大课 + 晚间小课。
  static const slots = <({int lineNum, String start, String end, String name})>[
    (lineNum: 1, start: '08:00', end: '11:30', name: '上午'),
    (lineNum: 2, start: '14:00', end: '17:30', name: '下午'),
    (lineNum: 3, start: '19:00', end: '21:00', name: '晚间'),
    (lineNum: 4, start: '21:10', end: '22:00', name: '晚间小课'),
  ];

  static int subjectIdOf(String name) {
    if (name.contains('素描')) return 38;
    if (name.contains('色彩')) return 39;
    if (name.contains('速写')) return 40;
    if (name.contains('常识')) return 41;
    if (name.contains('文化')) return 42;
    return 43;
  }

  static String colorOf(String name, {bool isSmall = false}) {
    if (isSmall) return '#A49AF4';
    if (name.contains('模拟')) return '#FE96EB';
    if (name.contains('写生')) return '#C5E53E';
    if (name.contains('素描')) return '#8C63FF';
    if (name.contains('色彩')) return '#F99C5D';
    if (name.contains('速写')) return '#71D4D0';
    if (name.contains('常识')) return '#A8C3FE';
    return '#FEEA98';
  }

  static DemoCampusStaff _teacherFor(DemoCampusClass c, DemoTimetableSlot slot) {
    final template = CampusA.staff(slot.teacherId);
    if (template.classIds.contains(c.id)) {
      return template;
    }
    for (final s in DemoCampusData.staff) {
      if (s.subject == template.subject && s.classIds.contains(c.id)) {
        return s;
      }
    }
    return template;
  }

  /// 班级某天的大课（周日休息）。
  static List<CampusCourse> bigCourses(DemoCampusClass c, DateTime day) {
    final template = [
      for (final s in DemoCampusData.timetableTemplate)
        if (s.weekday == day.weekday) s,
    ]..sort((a, b) => a.start.compareTo(b.start));
    return [
      for (var i = 0; i < template.length; i++)
        CampusCourse(
          id: '7${CampusA.compact(day)}${c.id}${i + 1}',
          day: day,
          lineNum: i + 1,
          type: 0,
          start: template[i].start,
          end: template[i].end,
          subjectName: template[i].courseName,
          teacher: _teacherFor(c, template[i]),
          schoolClass: c,
          room: '${c.organizationName} · ${template[i].room}',
        ),
    ];
  }

  static String _clock(int minutes) =>
      '${CampusA.two(minutes ~/ 60)}:${CampusA.two(minutes % 60)}';

  /// 学生个人小课：周二 / 周四晚间固定改画课；当天另有围绕「现在」安排的
  /// 一对一课程（已结束 / 进行中 / 即将开始各一节），保证任意时刻都能演示签到。
  static List<CampusCourse> smallCourses(
    int personIndex,
    DateTime day,
    DateTime now,
  ) {
    final c = CampusA.classOf(personIndex);
    final compact = CampusA.compact(day);
    final list = <CampusCourse>[];
    final weekly = switch (day.weekday) {
      DateTime.tuesday => ('素描改画小课', 't-1'),
      DateTime.thursday => ('色彩改画小课', 't-3'),
      _ => null,
    };
    if (weekly != null) {
      list.add(
        CampusCourse(
          id: '8${compact}4',
          day: day,
          lineNum: 4,
          type: 1,
          start: '21:10',
          end: '22:00',
          subjectName: weekly.$1,
          teacher: CampusA.staff(weekly.$2),
          schoolClass: c,
          room: '${c.organizationName} · 小课教室 2',
        ),
      );
    }
    if (CampusA.dayOf(now) != day) {
      return list;
    }
    final minutes = now.hour * 60 + now.minute;
    final base = minutes - minutes % 10;
    const lastMinute = 23 * 60 + 59;
    final specs = <({int seq, int start, int length, String name, String teacher, String room, bool auto})>[
      (seq: 1, start: base - 180, length: 50, name: '速写一对一改画', teacher: 't-4', room: '小课教室 1', auto: true),
      (seq: 2, start: base - 10 < 0 ? 0 : base - 10, length: 60, name: '素描头像精讲（一对一）', teacher: 't-1', room: '小课教室 3', auto: false),
      (seq: 3, start: base + 100, length: 50, name: '色彩静物小组课', teacher: 't-3', room: '色彩教室 B', auto: false),
    ];
    for (final s in specs) {
      final end = s.start + s.length;
      final clampedEnd = s.seq == 2 && end > lastMinute ? lastMinute : end;
      if (s.start < 0 || clampedEnd > lastMinute) {
        continue;
      }
      list.add(
        CampusCourse(
          id: '8$compact${s.seq}',
          day: day,
          lineNum: 0,
          type: 1,
          start: _clock(s.start),
          end: _clock(clampedEnd),
          subjectName: s.name,
          teacher: CampusA.staff(s.teacher),
          schoolClass: c,
          room: '${c.organizationName} · ${s.room}',
          autoComplete: s.auto,
        ),
      );
    }
    return list;
  }

  /// 学生某天的全部课程（按开始时间排序）。
  static List<CampusCourse> forStudent(
    int personIndex,
    DateTime day,
    DateTime now,
  ) {
    final list = [
      ...bigCourses(CampusA.classOf(personIndex), day),
      ...smallCourses(personIndex, day, now),
    ]..sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  /// 课程 id 中编码了日期（`7yyyyMMdd…` 大课 / `8yyyyMMdd…` 小课）。
  static DateTime? dayOfId(String courseId) {
    if (courseId.length < 10) {
      return null;
    }
    final y = int.tryParse(courseId.substring(1, 5));
    final m = int.tryParse(courseId.substring(5, 7));
    final d = int.tryParse(courseId.substring(7, 9));
    if (y == null || m == null || d == null) {
      return null;
    }
    return DateTime(y, m, d);
  }

  static CampusCourse? findForStudent(
    String courseId,
    int personIndex,
    DateTime now,
  ) {
    final day = dayOfId(courseId);
    if (day == null) {
      return null;
    }
    for (final course in forStudent(personIndex, day, now)) {
      if (course.id == courseId) {
        return course;
      }
    }
    return null;
  }

  /// 不晚于 [day] 的最近一个工作日（周一至周五）。
  static DateTime weekdayOnOrBefore(DateTime day) {
    var d = day;
    while (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
      d = d.subtract(const Duration(days: 1));
    }
    return d;
  }

  static String courseIdFor(DemoCampusClass c, DateTime day, int lineNum) =>
      '7${CampusA.compact(day)}${c.id}$lineNum';
}
