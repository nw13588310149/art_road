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
  });

  final String id;
  final String name;
  final String organizationName;
  final String headTeacherId;

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

  /// 角色标识：teacher / headTeacher / dormManager / admin。
  final List<String> roles;
  final String organizationName;

  /// 任教班级 id。
  final List<String> classIds;
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
      classIds: ['501', '502', '503'],
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
      classIds: ['503'],
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
  ];

  /// 每个班级同一套周课表模板（教室按校区区分）。
  static const timetableTemplate = <DemoTimetableSlot>[
    DemoTimetableSlot(weekday: 1, start: '08:00', end: '11:30', courseName: '素描', teacherId: 't-1', room: '素描教室 A'),
    DemoTimetableSlot(weekday: 1, start: '14:00', end: '17:30', courseName: '色彩', teacherId: 't-3', room: '色彩教室 B'),
    DemoTimetableSlot(weekday: 1, start: '19:00', end: '21:00', courseName: '速写', teacherId: 't-4', room: '速写教室 C'),
    DemoTimetableSlot(weekday: 2, start: '08:00', end: '11:30', courseName: '色彩', teacherId: 't-3', room: '色彩教室 B'),
    DemoTimetableSlot(weekday: 2, start: '14:00', end: '17:30', courseName: '素描', teacherId: 't-1', room: '素描教室 A'),
    DemoTimetableSlot(weekday: 2, start: '19:00', end: '21:00', courseName: '美术常识', teacherId: 't-7', room: '多媒体教室'),
    DemoTimetableSlot(weekday: 3, start: '08:00', end: '11:30', courseName: '速写', teacherId: 't-4', room: '速写教室 C'),
    DemoTimetableSlot(weekday: 3, start: '14:00', end: '17:30', courseName: '色彩', teacherId: 't-3', room: '色彩教室 B'),
    DemoTimetableSlot(weekday: 3, start: '19:00', end: '21:00', courseName: '文化课', teacherId: 't-8', room: '多媒体教室'),
    DemoTimetableSlot(weekday: 4, start: '08:00', end: '11:30', courseName: '素描', teacherId: 't-1', room: '素描教室 A'),
    DemoTimetableSlot(weekday: 4, start: '14:00', end: '17:30', courseName: '速写', teacherId: 't-4', room: '速写教室 C'),
    DemoTimetableSlot(weekday: 4, start: '19:00', end: '21:00', courseName: '色彩', teacherId: 't-3', room: '色彩教室 B'),
    DemoTimetableSlot(weekday: 5, start: '08:00', end: '11:30', courseName: '色彩', teacherId: 't-3', room: '色彩教室 B'),
    DemoTimetableSlot(weekday: 5, start: '14:00', end: '17:30', courseName: '素描', teacherId: 't-1', room: '素描教室 A'),
    DemoTimetableSlot(weekday: 5, start: '19:00', end: '21:00', courseName: '文化课', teacherId: 't-8', room: '多媒体教室'),
    DemoTimetableSlot(weekday: 6, start: '08:30', end: '11:30', courseName: '模拟考试', teacherId: 't-1', room: '考试大厅'),
    DemoTimetableSlot(weekday: 6, start: '14:00', end: '17:00', courseName: '色彩写生', teacherId: 't-3', room: '室外写生'),
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
