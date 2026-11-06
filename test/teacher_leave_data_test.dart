import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_music_flutter/features/smart_campus/data/teacher_leave_data.dart';

void main() {
  test('counts pending teacher leave from paginated total string', () {
    const response = {
      'code': 0,
      'msg': 'ok',
      'data': {
        'records': [
          {
            'id': '28',
            'type': 0,
            'startTime': '2026-06-29 22:19:00',
            'endTime': '2026-06-30 22:19:00',
            'leaveReason': '11',
            'leaveDuration': '1',
            'shiftHandover': '11',
            'status': 0,
            'createTime': '2026-06-29 22:19:50',
            'teacherId': '2066705433485066242',
            'schoolId': '2066563244679475201',
          },
          {
            'id': '27',
            'type': 0,
            'startTime': '2026-06-29 19:31:00',
            'endTime': '2026-06-30 19:31:00',
            'leaveReason': '有事回家',
            'leaveDuration': '1',
            'shiftHandover': '张老师顶班',
            'status': 0,
            'createTime': '2026-06-29 19:32:11',
            'teacherId': '2066705433485066242',
            'schoolId': '2066563244679475201',
          },
        ],
        'total': '2',
        'pages': '1',
      },
    };

    expect(parseTeacherLeavePendingCount(response), 2);
    expect(parseTeacherLeaveList(response), hasLength(2));
  });
}
