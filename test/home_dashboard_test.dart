import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/network/api_response.dart';
import 'package:the_road_of_art_flutter/core/permissions/first_launch_permission_host.dart';
import 'package:the_road_of_art_flutter/core/providers/app_providers.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:the_road_of_art_flutter/features/ebooks/state/home_ebook_shelf.dart';
import 'package:the_road_of_art_flutter/features/home/data/home_repository.dart';
import 'package:the_road_of_art_flutter/features/home/state/home_dashboard_controller.dart';
import 'package:the_road_of_art_flutter/features/home/state/home_dashboard_state.dart';
import 'package:the_road_of_art_flutter/features/home/state/home_student_cards.dart';
import 'package:the_road_of_art_flutter/features/home/ui/home_page.dart';
import 'package:the_road_of_art_flutter/features/home/ui/widgets/home_course_notice_card.dart';
import 'package:the_road_of_art_flutter/features/home/ui/widgets/home_study_snapshot.dart';

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _dateTime(DateTime d) =>
    '${_date(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:00';

class _FakeHomeRepository implements HomeRepository {
  _FakeHomeRepository(this.now);

  final DateTime now;

  Map<String, dynamic> _course(String subject, String begin, String end) => {
    'date': _date(now),
    'timeBegin': '$begin:00',
    'timeEnd': '$end:00',
    'room': '301 画室',
    'type': 0,
    'subject': {'name': subject},
    'teacher': {'realname': '李静', 'headUrl': ''},
    'schoolClass': {'name': '联考冲刺1班'},
  };

  @override
  Future<ApiResponse> getMyInfo() async => const ApiResponse(
    code: 0,
    msg: 'ok',
    data: {
      'user': {'role': 'student'},
    },
  );

  @override
  Future<ApiResponse> getBannerList() async =>
      const ApiResponse(code: 0, msg: 'ok', data: <Object>[]);

  @override
  Future<ApiResponse> getLatestInfo() async => ApiResponse(
    code: 0,
    msg: 'ok',
    data: [
      {
        'id': 1,
        'title': '2027 届甘肃美术联考素描评分标准解读',
        'shortText1': '素描评分标准',
        'shortText2': '联考政策，甘肃',
        'createTime': _dateTime(now.subtract(const Duration(hours: 2))),
      },
      {
        'id': 2,
        'title': '色彩备考的时间安排',
        'shortText1': '色彩备考',
        'shortText2': '备考经验',
        'createTime': _dateTime(now.subtract(const Duration(days: 5))),
      },
    ],
  );

  @override
  Future<ApiResponse> getNextSchoolCourse() async => ApiResponse(
    code: 0,
    msg: 'ok',
    data: [
      _course('色彩写生', '14:00', '17:00'),
      _course('模拟考试', '08:30', '11:30'),
    ],
  );

  @override
  Future<ApiResponse> getStudentCourseList({
    required String beginDate,
    required String endDate,
  }) async => ApiResponse(
    code: 0,
    msg: 'ok',
    data: {
      _date(now): [1, 2, 3, 4, 5],
    },
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

HomeWeekDayItem _day(String date, int count, {bool today = false}) =>
    HomeWeekDayItem(
      weekText: '周六',
      dayText: date.substring(8),
      dateText: date,
      courseCount: count,
      isToday: today,
    );

HomeCourseNotice _notice(String date) => HomeCourseNotice(
  startTime: '08:30',
  endTime: '11:30',
  subjectName: '素描',
  teacherName: '李静',
  teacherAvatar: '',
  description: '',
  status: HomeCourseStatus.upcoming,
  date: date,
);

void main() {
  setUpAll(() async {
    for (final font in {
      'Barlow': 'assets/fonts/Barlow-SemiBold.ttf',
      'Manrope': 'assets/fonts/Manrope Medium.ttf',
      'PingFang SC': 'assets/fonts/ttf/PingFangSC-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });
  group('alignWeekWithCourses', () {
    test('the listed day shows the same count as the course list', () {
      final week = [_day('2026-11-06', 3), _day('2026-11-07', 5, today: true)];
      final aligned = alignWeekWithCourses(week, [
        _notice('2026-11-07'),
        _notice('2026-11-07'),
      ]);
      expect(aligned.map((d) => d.courseCount), [3, 2]);
      expect(aligned.last.isToday, isTrue);
    });

    test('leaves the week alone when courses span several days', () {
      final week = [_day('2026-11-07', 5), _day('2026-11-08', 1)];
      final aligned = alignWeekWithCourses(week, [
        _notice('2026-11-07'),
        _notice('2026-11-08'),
      ]);
      expect(aligned.map((d) => d.courseCount), [5, 1]);
    });
  });

  test('only students, teachers and head teachers have a timetable', () {
    expect(homeRoleHasTimetable('student'), isTrue);
    expect(homeRoleHasTimetable('teacher'), isTrue);
    expect(homeRoleHasTimetable('headTeacher'), isTrue);
    expect(homeRoleHasTimetable('dormManager'), isFalse);
    expect(homeRoleHasTimetable('admin'), isFalse);
  });

  test('quick actions use the same names as the navigation', () {
    final student = buildQuickActions().map((a) => a.name).toList();
    expect(student, containsAll(['我的学情', '作品档案', '范画库', '工具箱', '速写计时练习']));
    final staff = buildQuickActions(isStaff: true).map((a) => a.name).toList();
    expect(staff, containsAll(['班级学情', '作品点评']));
    expect(staff, isNot(contains('我的学情')));
  });

  test('dorm managers and admins get their own work entries', () {
    final dorm = buildQuickActions(isStaff: true, role: 'dormManager');
    expect(
      dorm.map((a) => a.name),
      containsAll(['按宿舍查寝', '查寝动态', '查寝历史', '到岗打卡', '宿管请假']),
    );
    expect(dorm.map((a) => a.name), isNot(contains('班级学情')));
    expect(dorm.every((a) => a.campus != null), isTrue);

    final admin = buildQuickActions(isStaff: true, role: 'admin');
    expect(
      admin.map((a) => a.name),
      containsAll(['学生管理', '教师管理', '排课与课表', '人脸库', '通知管理', '班级学情']),
    );
  });

  test('news time keeps a space between numbers and units', () {
    final now = DateTime(2026, 11, 7, 10);
    expect(
      formatHomeNewsTime(now.subtract(const Duration(minutes: 5)), now),
      '5 分钟前',
    );
    expect(
      formatHomeNewsTime(now.subtract(const Duration(hours: 3)), now),
      '3 小时前',
    );
    expect(
      formatHomeNewsTime(now.subtract(const Duration(days: 4)), now),
      '4 天前',
    );
    expect(formatHomeNewsTime(DateTime(2026, 8, 1), now), '2026-08-01');
    expect(formatHomeNewsTime(null, now), '');
  });

  test('staff snapshot title states its real scope', () {
    const snapshot = HomeStudySnapshot(
      staff: true,
      examName: '2026 年 9 月月考',
      examDate: '2026-09-20',
      participants: 38,
    );
    expect(snapshot.title, '画室学情速览');
    expect(snapshot.subtitle, '2026 年 9 月月考 · 2026-09-20 · 全画室 38 人');
  });

  test('first launch permission copy has no music wording', () {
    final text = [
      for (final item in firstLaunchPermissionItems) '${item.name}${item.use}',
    ].join();
    for (final word in ['录音', '调音', '跟唱', '音频', '乐']) {
      expect(text.contains(word), isFalse, reason: word);
    }
    expect(text, contains('拍摄作品'));
    expect(text, contains('语音消息'));
  });

  testWidgets('HomePage lays out at the shell content size', (tester) async {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final storage = AppStorage(await SharedPreferences.getInstance());
    final now = DateTime.now();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStorageProvider.overrideWithValue(storage),
          homeRepositoryProvider.overrideWithValue(_FakeHomeRepository(now)),
          homeStudySnapshotProvider.overrideWith(
            (ref) async => const HomeStudySnapshot(
              staff: false,
              examName: '2026 年 9 月月考',
              examDate: '2026-09-20',
              totalScore: 265.5,
              maxScore: 300,
              ranking: 7,
              participants: 38,
              scoreChange: 9,
              subjects: [
                (name: '素描', score: 92.5, grade: 'A'),
                (name: '色彩', score: 85, grade: 'B'),
                (name: '速写', score: 88, grade: 'B'),
              ],
            ),
          ),
          homePracticeProvider.overrideWith(
            (ref) async => buildHomePractices(),
          ),
          homeLatestReviewProvider.overrideWith((ref) async => null),
          homeEbookShelfProvider.overrideWith(
            (ref) async => const HomeEbookShelfData(picks: [], reading: []),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            backgroundColor: AppColors.page,
            body: Center(
              child: SizedBox(width: 950, height: 732, child: HomePage()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.text('课程'), findsOneWidget);
    // 周条里今天的节数与课程列表一致（接口给 5，列表 2 门）。
    expect(find.text('2节'), findsOneWidget);
    expect(find.text('5节'), findsNothing);
    expect(find.byType(HomeCourseNoticeCard), findsNWidgets(2));
    expect(find.text('我的学情'), findsOneWidget);
    expect(find.text('速写计时练习'), findsOneWidget);
    expect(find.textContaining('学情速览'), findsOneWidget);
    expect(find.text('↑9 分'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('最新'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('更多'), findsOneWidget);
    expect(find.text('NEW'), findsNWidgets(2));
    expect(find.text('5天前'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
