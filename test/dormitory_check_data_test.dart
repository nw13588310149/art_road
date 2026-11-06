import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_music_flutter/features/smart_campus/data/dormitory_check_data.dart';

void main() {
  test('parses documented dormitory index field names', () {
    final result = parseDormitoryIndexOverview({
      'managedBuildingCount': 2,
      'totalBedCount': 60,
      'todayNormalCount': 55,
      'todayLateCount': 3,
      'todayAbsentCount': 2,
      'pendingMakeupCount': 4,
      'unhandledExceptionCount': 5,
    });

    expect(result.managedBuildingCount, 2);
    expect(result.bedCount, 60);
    expect(result.todayNormalCount, 55);
    expect(result.todayLateCount, 3);
    expect(result.todayAbsentCount, 2);
    expect(result.pendingMakeupCount, 4);
    expect(result.unclosedExceptionCount, 5);
  });

  test('parses room student realname and bed name', () {
    final rooms = parseDormitoryCheckRoomList([
      {
        'roomId': '2060000000000000001',
        'roomName': 'A-901',
        'buildingName': '女生公寓A座',
        'floorName': '9层',
        'allChecked': false,
        'userList': [
          {
            'userId': '2060000000000000002',
            'realname': '测试学生',
            'studentNo': 'S001',
            'bedName': '1号床',
            'headUrl': 'https://example.com/avatar.png',
            'status': '晚归',
          },
        ],
      },
    ]);

    expect(rooms, hasLength(1));
    expect(rooms.single.students.single.name, '测试学生');
    expect(rooms.single.students.single.bedName, '1号床');
    expect(
      rooms.single.students.single.status,
      DormitoryStudentCheckStatus.lateReturn,
    );
  });

  test('parses history records with nested user info', () {
    final items = parseDormitoryCheckHistoryList({
      'records': [
        {
          'id': '13',
          'userId': '2066817059806724098',
          'studentName': null,
          'studentNo': null,
          'checkDate': '2026-06-18',
          'status': '正常',
          'checkTime': '2026-06-18 22:01:06',
          'buildingName': '宿舍1号楼',
          'floorName': '1层',
          'roomName': '101',
          'bedName': '2',
          'handleStatus': null,
          'user': {
            'id': '2066817059806724098',
            'mobile': '173******91',
            'headUrl':
                'app/upload/2066817059806724098/2026-06-16/2066889412830023682.jpg',
            'nickname': '宁为学生',
            'gender': '男',
            'realname': null,
          },
        },
        {
          'id': '10',
          'userId': '2066715685123211265',
          'studentName': null,
          'studentNo': null,
          'checkDate': '2026-06-18',
          'status': '正常',
          'checkTime': '2026-06-18 21:56:59',
          'buildingName': '宿舍1号楼',
          'floorName': '1层',
          'roomName': '101',
          'bedName': '1号床',
          'user': {
            'nickname': '安同学',
            'headUrl':
                'app/upload/2066715685123211265/2026-06-16/2066716284145319937.jpeg',
            'gender': '男',
          },
        },
      ],
    });

    expect(items, hasLength(2));
    expect(items[0].studentName, '宁为学生');
    expect(items[0].studentSubtitle, '173******91');
    expect(items[0].dormName, '宿舍1号楼 · 1层 · 101');
    expect(items[0].bedLabel, '2床');
    expect(items[0].avatarUrl, contains('2066889412830023682.jpg'));
    expect(items[1].studentName, '安同学');
    expect(items[1].bedLabel, '1号床');
  });

  test('parses check detail fields from nested user info', () {
    final fields = parseDormitoryCheckDetailFields({
      'studentName': null,
      'studentNo': null,
      'checkDate': '2026-06-18',
      'status': '正常',
      'buildingName': '宿舍1号楼',
      'floorName': '1层',
      'roomName': '101',
      'bedName': '2',
      'checkTime': '2026-06-18 22:01:06',
      'user': {
        'nickname': '宁为学生',
        'mobile': '173******91',
        'realname': null,
      },
    });
    final fieldMap = {for (final field in fields) field.label: field.value};
    expect(fieldMap['学生姓名'], '宁为学生');
    expect(fieldMap['手机号'], '173******91');
    expect(fieldMap['所在宿舍'], '宿舍1号楼 · 1层 · 101');
    expect(fieldMap['所在床位'], '2床');
  });

  test('calculates selected history result statistics', () {
    final items = parseDormitoryCheckHistoryList({
      'records': [
        {'id': '1', 'userId': '11', 'status': '正常'},
        {'id': '2', 'userId': '12', 'status': '晚归'},
        {'id': '3', 'userId': '13', 'status': '未打卡'},
      ],
    });

    final stat = calculateDormitoryHistoryStat(items);
    expect(stat.bedCount, 3);
    expect(stat.normalCount, 1);
    expect(stat.lateCount, 1);
    expect(stat.notCheckedCount, 1);
  });

  test('calculates filtered room result statistics', () {
    final rooms = parseDormitoryCheckRoomList([
      {
        'roomId': '1',
        'userList': [
          {'userId': '11', 'status': '正常'},
          {'userId': '12', 'status': '晚归'},
          {'userId': '13', 'status': '未打卡'},
        ],
      },
    ]);

    final stat = calculateDormitoryRoomStat(rooms);
    expect(stat.bedCount, 3);
    expect(stat.normalCount, 1);
    expect(stat.lateCount, 1);
    expect(stat.notCheckedCount, 1);
  });

  test('parses documented detail approval and anomaly fields', () {
    final checkFields = parseDormitoryCheckDetailFields({
      'studentName': '测试学生',
      'status': '晚归',
      'anomalyReason': '排练晚归',
      'handleStatus': 1,
      'handleRemark': '已联系班主任',
    });
    final checkMap = {
      for (final field in checkFields) field.label: field.value,
    };
    expect(checkMap['查寝备注'], '排练晚归');
    expect(checkMap['处理状态'], '已处理');

    final makeupFields = parseDormitoryMakeupDetailFields({
      'studentName': '测试学生',
      'status': 2,
      'approverName': '宿管老师',
      'approveRemark': '材料不足',
      'approveTime': '2026-06-14 12:00:00',
    });
    final makeupMap = {
      for (final field in makeupFields) field.label: field.value,
    };
    expect(makeupMap['审批人'], '宿管老师');
    expect(makeupMap['审批意见'], '材料不足');
    expect(makeupMap['审批时间'], '2026-06-14 12:00:00');
  });
}
