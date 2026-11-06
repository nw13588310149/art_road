import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_music_flutter/core/network/media_url.dart';
import 'package:the_road_of_music_flutter/features/smart_campus/data/course_sign_data.dart';
import 'package:the_road_of_music_flutter/features/smart_campus/data/schedule_course_card_builder.dart';

void main() {
  setUp(() {
    MediaUrl.setFileBaseUrl('https://files.example.com');
  });

  tearDown(() {
    MediaUrl.setFileBaseUrl('');
  });

  test('resolves top-level courseList logo', () {
    expect(
      resolveScheduleLogoUrl({'logo': 'app/upload/class.jpg'}),
      'https://files.example.com/app/upload/class.jpg',
    );
  });

  test('resolves nested class logo used by combined course responses', () {
    expect(
      resolveScheduleLogoUrl({
        'schoolClass': {'logo': '/app/upload/nested.jpg'},
      }),
      'https://files.example.com/app/upload/nested.jpg',
    );
  });

  test('schedule card carries logo and keeps empty fallback', () {
    final withLogo = buildScheduleCourseCard({
      'type': 0,
      'className': '音乐一班',
      'subjectName': '视唱',
      'logo': 'https://img.example.com/class.jpg',
    }, 0);
    final withoutLogo = buildScheduleCourseCard({
      'type': 0,
      'className': '音乐二班',
      'subjectName': '练耳',
    }, 0);

    expect(withLogo.logoUrl, 'https://img.example.com/class.jpg');
    expect(withoutLogo.logoUrl, isEmpty);
  });

  test('course sign session carries manager course logo', () {
    final session = CourseSignSession.fromJson({
      'id': '1',
      'subjectName': '视唱',
      'logo': 'app/upload/sign-class.jpg',
    });

    expect(
      session.logoUrl,
      'https://files.example.com/app/upload/sign-class.jpg',
    );
  });
}
