import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_music_flutter/features/smart_campus/data/admin_home_data.dart';

void main() {
  test('parseAdminHomeLoginChart fills missing dates with zero', () {
    final chart = parseAdminHomeLoginChart(
      [
        {'loginDate': '2026-06-16', 'count': 24},
        {'loginDate': '2026-06-17', 'count': 22},
        {'loginDate': '2026-06-18', 'count': 19},
      ],
      startDate: '2026-06-12',
      endDate: '2026-06-18',
    );

    expect(chart.points, hasLength(7));
    expect(chart.points.first.loginDate, '2026-06-12');
    expect(chart.points.first.count, 0);
    expect(chart.points[4].loginDate, '2026-06-16');
    expect(chart.points[4].count, 24);
    expect(chart.points.last.count, 19);
    expect(chart.values, [0, 0, 0, 0, 24, 22, 19]);
    expect(chart.xLabels.first, '周五');
    expect(chart.xLabels.last, '周四');
  });

  test('parseAdminHomeWorkReminders reads list and nested data', () {
    final reminders = parseAdminHomeWorkReminders([
      {
        'tag': '预警',
        'title': '高三音乐实验班·昨晚查寝1人未打卡未闭环',
        'subtitle': '宿管端已登记，待确认是否转晚归备案。',
      },
      {
        'type': '提醒',
        'title': '校园通知草稿超 7 日未发布',
        'content': '通知管理后台累计 12 条草稿，请及时审核或归档。',
      },
    ]);

    expect(reminders, hasLength(2));
    expect(reminders.first.tag, '预警');
    expect(reminders.first.title, contains('查寝'));
    expect(reminders.last.tag, '提醒');
    expect(reminders.last.subtitle, contains('12 条草稿'));
  });

  test('parseAdminHomeWorkReminders skips rows without title', () {
    final reminders = parseAdminHomeWorkReminders({
      'data': [
        {'title': '有效提醒', 'subtitle': '副标题'},
        {'subtitle': '只有副标题'},
      ],
    });

    expect(reminders, hasLength(1));
    expect(reminders.single.title, '有效提醒');
  });

  test('AdminHomeSummary unwraps nested indexSum data', () {
    final summary = AdminHomeSummary.fromJson({
      'data': {
        'studentCount': 10,
        'leaveStatus0Count': 3,
        'postStatus0Count': 5,
        'smallCourseSignStatus5Count': 2,
      },
    });

    expect(summary.studentCount, 10);
    expect(summary.leaveStatus0Count, 3);
    expect(summary.postStatus0Count, 5);
    expect(summary.smallCourseSignStatus5Count, 2);
  });

  test('AdminHomeActionBadgeCounts maps labels to badge text', () {
    const counts = AdminHomeActionBadgeCounts(
      scheduleApply: 4,
      teacherLeave: 3,
      signReview: 2,
      faceAudit: 1,
      postReview: 6,
    );

    expect(counts.badgeLabelFor('排课与课表'), '4');
    expect(counts.badgeLabelFor('教师请假审批'), '3');
    expect(counts.badgeLabelFor('签课管理'), '2');
    expect(counts.badgeLabelFor('人脸库'), '1');
    expect(counts.badgeLabelFor('校圈治理'), '6');
    expect(counts.badgeLabelFor('群聊'), isNull);
  });

  test('admin action badges hide zero and cap large counts at 9+', () {
    const empty = AdminHomeActionBadgeCounts(scheduleApply: 0);
    const ten = AdminHomeActionBadgeCounts(scheduleApply: 10);
    const many = AdminHomeActionBadgeCounts(scheduleApply: 11);

    expect(empty.badgeLabelFor('排课与课表'), isNull);
    expect(ten.badgeLabelFor('排课与课表'), '10');
    expect(many.badgeLabelFor('排课与课表'), '9+');
  });

  test('AdminHomeActionBadgeCounts.fromSummary mirrors top stats fields', () {
    const summary = AdminHomeSummary(
      leaveStatus0Count: 7,
      smallCourseSignStatus5Count: 8,
      postStatus0Count: 9,
    );
    final counts = AdminHomeActionBadgeCounts.fromSummary(
      summary: summary,
      scheduleApply: 1,
      faceAudit: 2,
    );

    expect(counts.teacherLeave, 7);
    expect(counts.signReview, 8);
    expect(counts.postReview, 9);
    expect(counts.badgeLabelFor('教师请假审批'), '7');
    expect(counts.badgeLabelFor('校圈治理'), '9');
  });

  test('admin badge parsers support nested API payloads', () {
    expect(
      parseAdminPageTotal({
        'data': {
          'data': {'records': const [], 'total': '12'},
        },
      }),
      12,
    );
    expect(
      parseAdminFaceSumPendingCount({
        'data': {
          'data': {'status0Count': '4'},
        },
      }),
      4,
    );
  });

  test('pending list count falls back to returned records', () {
    expect(
      parseAdminListPendingTotal({
        'data': {
          'records': [
            {'id': '1'},
          ],
        },
      }),
      1,
    );
  });
}
