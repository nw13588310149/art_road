// 首页对所有身份是同一套版式：轮播、九宫格、三科入口、右栏课表与最新资讯。
// 各身份当天要处理的事在「今日」页（见 today_board_test.dart）。
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/network/api_response.dart';
import 'package:the_road_of_art_flutter/core/providers/app_providers.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:the_road_of_art_flutter/core/widgets/art_subject_card.dart';
import 'package:the_road_of_art_flutter/features/home/data/home_repository.dart';
import 'package:the_road_of_art_flutter/features/home/ui/home_page.dart';
import 'package:the_road_of_art_flutter/features/home/ui/widgets/home_course_notice_card.dart';
import 'package:the_road_of_art_flutter/features/school/data/school_config_data.dart';
import 'package:the_road_of_art_flutter/features/school/state/school_config_controller.dart';

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _RoleHomeRepository implements HomeRepository {
  _RoleHomeRepository(this.role);

  final String role;
  int schoolCourseRequests = 0;

  @override
  Future<ApiResponse> getMyInfo() async => ApiResponse(
    code: 0,
    msg: 'ok',
    data: {
      'user': {'role': role},
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
        'shortText2': '联考政策',
        'createTime': '2026-11-01 10:00:00',
      },
    ],
  );

  @override
  Future<ApiResponse> getNextSchoolCourse() async {
    final now = DateTime.now();
    return ApiResponse(
      code: 0,
      msg: 'ok',
      data: [
        {
          'date': _date(now),
          'timeBegin': '14:00:00',
          'timeEnd': '17:00:00',
          'room': '301 画室',
          'type': 0,
          'subject': {'name': '色彩写生'},
          'teacher': {'realname': '李静'},
          'schoolClass': {'name': '联考冲刺1班'},
        },
      ],
    );
  }

  @override
  Future<ApiResponse> getStudentCourseList({
    required String beginDate,
    required String endDate,
  }) async => const ApiResponse(code: 0, msg: 'ok', data: <String, Object>{});

  @override
  Future<ApiResponse> getTeacherCourseList({
    required String beginDate,
    required String endDate,
  }) async => const ApiResponse(code: 0, msg: 'ok', data: <String, Object>{});

  /// 管理端课表：按日期分组，行是扁平字段。
  @override
  Future<ApiResponse> getSchoolCourseList({
    required String beginDate,
    required String endDate,
  }) async {
    schoolCourseRequests++;
    final today = _date(DateTime.now());
    Map<String, Object> row(String begin, String end, String subject) => {
      'date': today,
      'timeBegin': '$begin:00',
      'timeEnd': '$end:00',
      'type': 0,
      'subjectName': subject,
      'teacherRealname': '王海波',
      'className': '联考冲刺2班',
      'classroomName': '302 画室',
    };
    return ApiResponse(
      code: 0,
      msg: 'ok',
      data: {
        today: [
          row('08:30', '11:30', '素描'),
          row('14:00', '17:00', '色彩'),
          row('19:00', '21:00', '速写'),
        ],
      },
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_RoleHomeRepository> _pumpHome(WidgetTester tester, String role) async {
  tester.view.physicalSize = const Size(1180, 820);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final storage = AppStorage(await SharedPreferences.getInstance());
  final repository = _RoleHomeRepository(role);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appStorageProvider.overrideWithValue(storage),
        homeRepositoryProvider.overrideWithValue(repository),
        schoolDormitoryCheckConfigProvider.overrideWith(
          (ref) async => const SchoolDormitoryCheckConfig(
            eveningDeadline: '22:30前',
            morningDeadline: '07:20前',
          ),
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
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 350));
  return repository;
}

/// 以前按身份放在首页的卡片，现在都不在首页。
const _movedCards = [
  '今日任务',
  '今日待办',
  '最近点评',
  '我的短板',
  '作品点评',
  '组长复核',
  '精选书刊',
  '今日新交作品',
];

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

  group('HomePage is the same portal for every role at 1180 × 820', () {
    void expectPortal(WidgetTester tester, {required List<String> entries}) {
      expect(tester.takeException(), isNull);
      for (final name in entries) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(find.byType(ArtSubjectCard), findsNWidgets(3));
      for (final title in _movedCards) {
        expect(find.text(title), findsNothing, reason: title);
      }
      expect(find.textContaining('学情速览'), findsNothing);
    }

    const common = ['工具', '题库', '作品墙', '集市', '群聊', '资讯', '校圈'];

    for (final role in ['student', 'teacher', 'headTeacher']) {
      testWidgets('$role sees the nine entries and the personal timetable', (
        tester,
      ) async {
        final repository = await _pumpHome(tester, role);
        expectPortal(tester, entries: ['学情', '作业', ...common]);
        expect(find.text('课表'), findsOneWidget);
        expect(find.text('课程'), findsOneWidget);
        expect(find.byType(HomeCourseNoticeCard), findsOneWidget);
        expect(repository.schoolCourseRequests, 0);
      });
    }

    for (final role in ['admin', 'principal']) {
      testWidgets('$role sees the same entries and the school timetable', (
        tester,
      ) async {
        final repository = await _pumpHome(tester, role);
        expectPortal(tester, entries: ['学情', '作业', ...common]);
        expect(find.text('课表'), findsOneWidget);
        expect(find.text('课程'), findsOneWidget);
        expect(repository.schoolCourseRequests, 1);
        // 今天全校三节课：周条与课程列表同一个数。
        expect(find.text('3节'), findsOneWidget);
        expect(find.text('王海波'), findsWidgets);
        expect(find.textContaining('联考冲刺2班'), findsWidgets);
      });
    }

    testWidgets('dorm manager keeps the layout with duty times on the right', (
      tester,
    ) async {
      await _pumpHome(tester, 'dormManager');
      expectPortal(tester, entries: ['校长信箱', '查寝', ...common]);
      expect(find.text('学情'), findsNothing);
      expect(find.text('作业'), findsNothing);
      expect(find.text('值班'), findsOneWidget);
      expect(find.text('早查寝'), findsOneWidget);
      expect(find.text('07:20'), findsOneWidget);
      expect(find.text('晚查寝'), findsOneWidget);
      expect(find.text('22:30'), findsOneWidget);
      expect(find.text('查看今日工作'), findsOneWidget);
      expect(find.text('课表'), findsNothing);
    });

    testWidgets('the right column is as tall as the banner plus the entries', (
      tester,
    ) async {
      await _pumpHome(tester, 'student');
      // 内容区 950 宽：左栏 627（轮播按 647:190）+ 间距 16 + 功能入口 313。
      const leftColumnHeight = 627 * 190 / 647 + 16 + 313;
      final card = find.ancestor(
        of: find.text('课表'),
        matching: find.byType(AppCard),
      );
      expect(tester.getSize(card).height, closeTo(leftColumnHeight, 0.5));
    });
  });
}
