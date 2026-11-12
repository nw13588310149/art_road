/// 智慧校园演示数据：班级、教职工、课表与宿舍分配。
///
/// 学生沿用 [DemoMarkingData.persons]（同一 index、同一校区），保证学情中心、
/// 作品点评、智慧校园各视角看到的是同一批学生。
library;

import 'demo_marking_data.dart';

class DemoCampusClass {
  const DemoCampusClass({
    required this.id,
    required this.name,
    required this.organizationName,
    required this.headTeacherId,
    required this.grade,
    this.principalId,
  });

  final String id;
  final String name;
  final String organizationName;
  final String headTeacherId;

  /// 单独为本班指定的分管校长；为空时取所在校区的分管校长。
  final String? principalId;

  /// 届别，例如「2027 届」。
  final String grade;

  /// 班级学生：与阅卷演示数据同校区的学生。
  List<DemoPerson> get students => DemoMarkingData.instance.persons
      .where((p) => p.organizationName == organizationName)
      .toList();
}

class DemoCampusStaff {
  const DemoCampusStaff({
    required this.id,
    required this.userId,
    required this.name,
    required this.gender,
    required this.phone,
    required this.subject,
    required this.roles,
    required this.organizationName,
    this.classIds = const <String>[],
  });

  /// 教职工 id（与作品点评老师 id 一致，如 t-1）。
  final String id;

  /// 平台用户 id（字符串）。
  final String userId;
  final String name;
  final String gender;
  final String phone;

  /// 任教科目；管理人员为空串。
  final String subject;

  /// 角色标识：teacher / headTeacher / dormManager / admin / principal。
  /// 科目组长不写在这里，由 [DemoCampusData.subjectGroups] 决定。
  final List<String> roles;
  final String organizationName;

  /// 任教班级 id。
  final List<String> classIds;
}

/// 科目组：按科目划分的教研组，组长逐份复核本组老师的点评。
class DemoSubjectGroup {
  const DemoSubjectGroup({
    required this.id,
    required this.subject,
    required this.leadId,
  });

  final String id;

  /// 科目名称：素描 / 色彩 / 速写。
  final String subject;

  /// 组长的教职工 id。
  final String leadId;

  String get name => '$subject组';

  /// 本组老师：任教该科目的全部教职工（含组长）。
  List<DemoCampusStaff> get members => [
    for (final s in DemoCampusData.staff)
      if (s.subject == subject) s,
  ];
}

class DemoTimetableSlot {
  const DemoTimetableSlot({
    required this.weekday,
    required this.start,
    required this.end,
    required this.courseName,
    required this.teacherId,
    required this.room,
  });

  /// 上午 08:30–11:30。
  const DemoTimetableSlot.am(
    this.weekday,
    this.courseName,
    this.teacherId,
    this.room,
  ) : start = '08:30',
      end = '11:30';

  /// 下午 14:00–17:00。
  const DemoTimetableSlot.pm(
    this.weekday,
    this.courseName,
    this.teacherId,
    this.room,
  ) : start = '14:00',
      end = '17:00';

  /// 晚上 19:00–21:00。
  const DemoTimetableSlot.eve(
    this.weekday,
    this.courseName,
    this.teacherId,
    this.room,
  ) : start = '19:00',
      end = '21:00';

  /// 1 = 周一 … 7 = 周日。
  final int weekday;
  final String start;
  final String end;
  final String courseName;
  final String teacherId;
  final String room;
}

class DemoDormBed {
  const DemoDormBed({
    required this.building,
    required this.floor,
    required this.room,
    required this.bed,
    required this.personIndex,
  });

  final String building;
  final String floor;
  final String room;
  final int bed;
  final int personIndex;

  String get roomId => '$building-$room';
  String get display => '$building · $floor · $room';
}

abstract final class DemoCampusData {
  static const schoolId = DemoMarkingData.schoolId;
  static const schoolName = DemoMarkingData.schoolName;

  static const classes = <DemoCampusClass>[
    DemoCampusClass(
      id: '501',
      name: '联考冲刺1班',
      organizationName: '城东校区',
      headTeacherId: 't-4',
      grade: '2027 届',
    ),
    DemoCampusClass(
      id: '502',
      name: '联考冲刺2班',
      organizationName: '城西校区',
      headTeacherId: 't-5',
      grade: '2027 届',
    ),
    DemoCampusClass(
      id: '503',
      name: '校考提高班',
      organizationName: '安宁校区',
      headTeacherId: 't-6',
      grade: '2027 届',
      principalId: 'p-1',
    ),
  ];

  static const staff = <DemoCampusStaff>[
    DemoCampusStaff(
      id: 't-1',
      userId: '1880000000000000002',
      name: '李静',
      gender: '女',
      phone: '13809310002',
      subject: '素描',
      roles: ['teacher'],
      organizationName: '城东校区',
      classIds: ['501', '502'],
    ),
    DemoCampusStaff(
      id: 't-2',
      userId: '1880000000000000012',
      name: '张明远',
      gender: '男',
      phone: '13809310012',
      subject: '素描',
      roles: ['teacher'],
      organizationName: '城西校区',
      classIds: ['502', '503'],
    ),
    DemoCampusStaff(
      id: 't-3',
      userId: '1880000000000000013',
      name: '刘芳',
      gender: '女',
      phone: '13809310013',
      subject: '色彩',
      roles: ['teacher'],
      organizationName: '城东校区',
      classIds: ['501', '503'],
    ),
    DemoCampusStaff(
      id: 't-4',
      userId: '1880000000000000003',
      name: '赵雪',
      gender: '女',
      phone: '13809310003',
      subject: '速写',
      roles: ['teacher', 'headTeacher'],
      organizationName: '城东校区',
      classIds: ['501'],
    ),
    DemoCampusStaff(
      id: 't-5',
      userId: '1880000000000000015',
      name: '王海波',
      gender: '男',
      phone: '13809310015',
      subject: '色彩',
      roles: ['teacher', 'headTeacher'],
      organizationName: '城西校区',
      classIds: ['502'],
    ),
    DemoCampusStaff(
      id: 't-6',
      userId: '1880000000000000016',
      name: '周强',
      gender: '男',
      phone: '13809310016',
      subject: '速写',
      roles: ['teacher', 'headTeacher'],
      organizationName: '安宁校区',
      classIds: ['503', '502'],
    ),
    DemoCampusStaff(
      id: 't-7',
      userId: '1880000000000000017',
      name: '吴雨桐',
      gender: '女',
      phone: '13809310017',
      subject: '美术常识',
      roles: ['teacher'],
      organizationName: '城东校区',
      classIds: ['501', '502', '503'],
    ),
    DemoCampusStaff(
      id: 't-8',
      userId: '1880000000000000018',
      name: '孙磊',
      gender: '男',
      phone: '13809310018',
      subject: '文化课',
      roles: ['teacher'],
      organizationName: '城西校区',
      classIds: ['501', '502', '503'],
    ),
    DemoCampusStaff(
      id: 'd-1',
      userId: '1880000000000000004',
      name: '马红梅',
      gender: '女',
      phone: '13809310004',
      subject: '',
      roles: ['dormManager'],
      organizationName: '城东校区',
    ),
    DemoCampusStaff(
      id: 't-9',
      userId: '1880000000000000005',
      name: '王敏',
      gender: '女',
      phone: '13809310005',
      subject: '',
      roles: ['admin'],
      organizationName: '城东校区',
    ),
    DemoCampusStaff(
      id: 'p-1',
      userId: '1880000000000000006',
      name: '秦文博',
      gender: '男',
      phone: '13809310006',
      subject: '',
      roles: ['principal'],
      organizationName: '城东校区',
    ),
    DemoCampusStaff(
      id: 'p-2',
      userId: '1880000000000000019',
      name: '沈丹',
      gender: '女',
      phone: '13809310019',
      subject: '',
      roles: ['principal'],
      organizationName: '城西校区',
    ),
  ];

  /// 科目组：素描、色彩、速写各一个，组长从本组任课老师里指定。
  static const subjectGroups = <DemoSubjectGroup>[
    DemoSubjectGroup(id: 'g-sketch', subject: '素描', leadId: 't-2'),
    DemoSubjectGroup(id: 'g-color', subject: '色彩', leadId: 't-5'),
    DemoSubjectGroup(id: 'g-speed', subject: '速写', leadId: 't-6'),
  ];

  /// 各校区的分管校长（教职工 id）。个别班级可以用
  /// [DemoCampusClass.principalId] 另行指定，班级上的指定优先：安宁校区的
  /// 校考提高班单独指定给秦文博。
  static const campusPrincipals = <String, String>{
    '城东校区': 'p-1',
    '城西校区': 'p-2',
    '安宁校区': 'p-2',
  };

  /// 联考冲刺1班的周课表；首页等只需要一份课表的地方沿用它。
  static const timetableTemplate = _timetable501;

  /// 各班周课表：只用上午 08:30–11:30、下午 14:00–17:00、晚上 19:00–21:00
  /// 三个固定时段（与 `DemoClock.daySlots` 一致），每周循环，不随打开演示的时刻
  /// 变化。三个班错开科目，同一位老师不会同时出现在两个班；周二、周四、周六
  /// 晚上不排大课，留给小课和晚自习；周日休息（小班课除外）。
  static const classTimetables = <String, List<DemoTimetableSlot>>{
    '501': _timetable501,
    '502': _timetable502,
    '503': _timetable503,
  };

  static List<DemoTimetableSlot> timetableOf(String classId) =>
      classTimetables[classId] ?? const <DemoTimetableSlot>[];

  static const _timetable501 = <DemoTimetableSlot>[
    DemoTimetableSlot.am(1, '素描', 't-1', '素描教室 A'),
    DemoTimetableSlot.pm(1, '色彩', 't-3', '色彩教室 B'),
    DemoTimetableSlot.eve(1, '速写', 't-4', '速写教室 C'),
    DemoTimetableSlot.am(2, '色彩', 't-3', '色彩教室 B'),
    DemoTimetableSlot.pm(2, '素描', 't-1', '素描教室 A'),
    DemoTimetableSlot.am(3, '速写', 't-4', '速写教室 C'),
    DemoTimetableSlot.pm(3, '色彩', 't-3', '色彩教室 B'),
    DemoTimetableSlot.eve(3, '文化课', 't-8', '多媒体教室'),
    DemoTimetableSlot.am(4, '素描', 't-1', '素描教室 A'),
    DemoTimetableSlot.pm(4, '速写', 't-4', '速写教室 C'),
    DemoTimetableSlot.am(5, '色彩', 't-3', '色彩教室 B'),
    DemoTimetableSlot.pm(5, '素描', 't-1', '素描教室 A'),
    DemoTimetableSlot.eve(5, '美术常识', 't-7', '多媒体教室'),
    DemoTimetableSlot.am(6, '模拟考试', 't-1', '考试大厅'),
    DemoTimetableSlot.pm(6, '色彩写生', 't-3', '室外写生'),
  ];

  static const _timetable502 = <DemoTimetableSlot>[
    DemoTimetableSlot.am(1, '色彩', 't-5', '色彩教室 B'),
    DemoTimetableSlot.pm(1, '速写', 't-6', '速写教室 C'),
    DemoTimetableSlot.eve(1, '文化课', 't-8', '多媒体教室'),
    DemoTimetableSlot.am(2, '速写', 't-6', '速写教室 C'),
    DemoTimetableSlot.pm(2, '色彩', 't-5', '色彩教室 B'),
    DemoTimetableSlot.am(3, '素描', 't-1', '素描教室 A'),
    DemoTimetableSlot.pm(3, '速写', 't-6', '速写教室 C'),
    DemoTimetableSlot.eve(3, '美术常识', 't-7', '多媒体教室'),
    DemoTimetableSlot.am(4, '色彩', 't-5', '色彩教室 B'),
    DemoTimetableSlot.pm(4, '素描', 't-1', '素描教室 A'),
    DemoTimetableSlot.am(5, '速写', 't-6', '速写教室 C'),
    DemoTimetableSlot.pm(5, '色彩', 't-5', '色彩教室 B'),
    DemoTimetableSlot.eve(5, '素描', 't-1', '素描教室 A'),
    DemoTimetableSlot.am(6, '模拟考试', 't-2', '考试大厅'),
    DemoTimetableSlot.pm(6, '色彩写生', 't-5', '室外写生'),
  ];

  static const _timetable503 = <DemoTimetableSlot>[
    DemoTimetableSlot.am(1, '速写', 't-6', '速写教室 C'),
    DemoTimetableSlot.pm(1, '素描', 't-2', '素描教室 A'),
    DemoTimetableSlot.eve(1, '美术常识', 't-7', '多媒体教室'),
    DemoTimetableSlot.am(2, '素描', 't-2', '素描教室 A'),
    DemoTimetableSlot.pm(2, '速写', 't-6', '速写教室 C'),
    DemoTimetableSlot.am(3, '色彩', 't-3', '色彩教室 B'),
    DemoTimetableSlot.pm(3, '素描', 't-2', '素描教室 A'),
    DemoTimetableSlot.eve(3, '速写', 't-6', '速写教室 C'),
    DemoTimetableSlot.am(4, '速写', 't-6', '速写教室 C'),
    DemoTimetableSlot.pm(4, '色彩', 't-3', '色彩教室 B'),
    DemoTimetableSlot.am(5, '素描', 't-2', '素描教室 A'),
    DemoTimetableSlot.pm(5, '速写', 't-6', '速写教室 C'),
    DemoTimetableSlot.eve(5, '文化课', 't-8', '多媒体教室'),
    DemoTimetableSlot.am(6, '模拟考试', 't-6', '考试大厅'),
    DemoTimetableSlot.pm(6, '创作构图', 't-6', '速写教室 C'),
  ];

  /// 演示学生林小雨（联考冲刺1班）的个人改画小课：周二、周四、周六晚上。
  static const demoStudentSmallCourses = <DemoTimetableSlot>[
    DemoTimetableSlot.eve(2, '素描改画小课', 't-1', '小课教室 2'),
    DemoTimetableSlot.eve(4, '色彩改画小课', 't-3', '小课教室 2'),
    DemoTimetableSlot.eve(6, '速写改画小课', 't-4', '小课教室 2'),
  ];

  static DemoCampusClass classOfPerson(int personIndex) {
    final org = DemoMarkingData.instance.person(personIndex).organizationName;
    return classes.firstWhere((c) => c.organizationName == org);
  }

  static DemoCampusClass? classById(String id) {
    for (final c in classes) {
      if (c.id == id) {
        return c;
      }
    }
    return null;
  }

  static DemoCampusStaff? staffById(String id) {
    for (final s in staff) {
      if (s.id == id) {
        return s;
      }
    }
    return null;
  }

  static DemoCampusStaff? staffByUserId(String userId) {
    for (final s in staff) {
      if (s.userId == userId) {
        return s;
      }
    }
    return null;
  }

  // ── 科目组与分管校长 ─────────────────────────────────────────────────

  static DemoSubjectGroup? groupOfSubject(String subject) {
    for (final g in subjectGroups) {
      if (g.subject == subject) {
        return g;
      }
    }
    return null;
  }

  /// [staffId] 担任组长的科目组；不是组长时为 null。
  static DemoSubjectGroup? groupLedBy(String staffId) {
    for (final g in subjectGroups) {
      if (g.leadId == staffId) {
        return g;
      }
    }
    return null;
  }

  /// 某科目的组长。
  static DemoCampusStaff? leadOfSubject(String subject) {
    final group = groupOfSubject(subject);
    return group == null ? null : staffById(group.leadId);
  }

  /// 班级的分管校长：班级上单独指定的优先，否则取所在校区的分管校长。
  static DemoCampusStaff? principalOfClass(String classId) {
    final c = classById(classId);
    if (c == null) {
      return null;
    }
    final id = c.principalId ?? campusPrincipals[c.organizationName];
    return id == null ? null : staffById(id);
  }

  /// 某位校长分管的班级。
  static List<DemoCampusClass> classesOfPrincipal(String staffId) => [
    for (final c in classes)
      if (principalOfClass(c.id)?.id == staffId) c,
  ];

  /// 宿舍：女生住女生公寓 1 号楼，男生住男生公寓 2 号楼，每间 4 床。
  static final List<DemoDormBed> beds = _buildBeds();

  static List<DemoDormBed> _buildBeds() {
    final result = <DemoDormBed>[];
    for (final gender in const ['女', '男']) {
      final building = gender == '女' ? '女生公寓1号楼' : '男生公寓2号楼';
      final people = DemoMarkingData.instance.persons
          .where((p) => p.gender == gender)
          .toList();
      for (var i = 0; i < people.length; i++) {
        final roomIndex = i ~/ 4;
        final floorNo = roomIndex ~/ 5 + 1;
        final roomNo = '$floorNo${(roomIndex % 5 + 1).toString().padLeft(2, '0')}';
        result.add(
          DemoDormBed(
            building: building,
            floor: '$floorNo层',
            room: roomNo,
            bed: i % 4 + 1,
            personIndex: people[i].index,
          ),
        );
      }
    }
    return result;
  }

  static DemoDormBed? bedOf(int personIndex) {
    for (final bed in beds) {
      if (bed.personIndex == personIndex) {
        return bed;
      }
    }
    return null;
  }
}
