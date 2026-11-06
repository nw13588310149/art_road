import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_music_flutter/features/smart_campus/data/head_teacher_class_score_data.dart';

void main() {
  test('parseHeadTeacherClassScoreOverview maps chart, tabs and student cards', () {
    final overview = HeadTeacherClassScoreOverview.fromData(<String, dynamic>{
      'examAxis': [
        {'examId': 1, 'name': '三月月考', 'examDate': '2026-03-18'},
        {'examId': 2, 'name': '四月月考', 'examDate': '2026-04-18'},
      ],
      'trendLines': [
        {
          'subjectId': 1,
          'subjectName': '视唱',
          'avgScores': [85.5, 88.2],
        },
      ],
      'examTabs': [
        {'examId': 1, 'name': '三月月考', 'examDate': '2026-03-18'},
      ],
      'currentExamId': 1,
      'studentScores': {
        'records': [
          {
            'studentId': 100,
            'realname': '李铮辉',
            'no': 'G3030201',
            'subjectName': '视唱',
            'score': 86,
            'teacherName': '李牧茵',
            'comment': '表现不错',
            'hasStudentAudio': true,
            'hasVideoComment': true,
          },
        ],
        'total': 45,
        'pageNum': 1,
        'pageSize': 10,
      },
    });

    expect(overview.examAxis, hasLength(2));
    expect(overview.examAxis.first.axisLabel, '3月18日');
    expect(overview.trendLines.first.subjectName, '视唱');
    expect(overview.trendLines.first.avgScores, [85.5, 88.2]);
    expect(overview.indexOfCurrentExam(), 0);
    expect(overview.hasChartData, isTrue);
    expect(overview.studentScores.records, hasLength(1));
    expect(overview.studentScores.records.first.realname, '李铮辉');
    expect(overview.studentScores.records.first.hasStudentAudio, isTrue);
    expect(overview.studentScores.hasMore, isTrue);
  });

  test('displayName falls back to nickname when realname is empty', () {
    final record = HeadTeacherStudentScoreRecord.fromJson(<String, dynamic>{
      'studentId': 100,
      'realname': '',
      'nickname': '小李',
      'no': 'G3030201',
    });
    expect(record.displayName, '小李');
  });
}
