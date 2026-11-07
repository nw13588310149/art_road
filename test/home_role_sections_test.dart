import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/app/router/route_paths.dart';
import 'package:the_road_of_art_flutter/core/network/api_response.dart';
import 'package:the_road_of_art_flutter/core/providers/app_providers.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:the_road_of_art_flutter/core/widgets/art_subject_card.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/data/toolbox_catalog.dart';
import 'package:the_road_of_art_flutter/features/artworks/data/artwork_models.dart';
import 'package:the_road_of_art_flutter/features/ebooks/state/home_ebook_shelf.dart';
import 'package:the_road_of_art_flutter/features/home/data/home_repository.dart';
import 'package:the_road_of_art_flutter/features/home/state/home_sections.dart';
import 'package:the_road_of_art_flutter/features/home/state/home_staff_cards.dart';
import 'package:the_road_of_art_flutter/features/home/state/home_student_cards.dart';
import 'package:the_road_of_art_flutter/features/home/ui/home_page.dart';
import 'package:the_road_of_art_flutter/features/home/ui/widgets/home_latest_review_card.dart';
import 'package:the_road_of_art_flutter/features/home/ui/widgets/home_practice_card.dart';
import 'package:the_road_of_art_flutter/features/home/ui/widgets/home_review_queue_card.dart';
import 'package:the_road_of_art_flutter/features/home/ui/widgets/home_study_snapshot.dart';
import 'package:the_road_of_art_flutter/features/home/ui/widgets/home_todo_card.dart';
import 'package:the_road_of_art_flutter/features/school/data/school_config_data.dart';
import 'package:the_road_of_art_flutter/features/school/state/school_config_controller.dart';

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _RoleHomeRepository implements HomeRepository {
  _RoleHomeRepository(this.role);

  final String role;

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

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _studentSnapshot = HomeStudySnapshot(
  staff: false,
  examName: '2026 年 9 月月考',
  examDate: '2026-09-20',
  totalScore: 265.5,
  maxScore: 300,
  ranking: 7,
  participants: 38,
  subjects: [
    (name: '素描', score: 92.5, grade: 'A'),
    (name: '色彩', score: 85, grade: 'B'),
    (name: '速写', score: 88, grade: 'B'),
  ],
);

const _staffSnapshot = HomeStudySnapshot(
  staff: true,
  examName: '2026 年 9 月月考',
  examDate: '2026-09-20',
  totalScore: 251.3,
  maxScore: 300,
  topScore: 272.5,
  participants: 38,
  subjects: [
    (name: '素描', score: 84.6, grade: ''),
    (name: '色彩', score: 82.1, grade: ''),
    (name: '速写', score: 84.6, grade: ''),
  ],
);

/// 与演示数据林小雨的点评小结一致：结构错误 3 次（镜像）、线条生硬 2 次（速写计时）。
const _insights = ArtworkInsights(
  reviewedCount: 6,
  weakestSubject: '色彩',
  suggestions: [
    ArtworkSuggestion(
      tag: '结构错误',
      text: '起形时用辅助线核对比例和骨点，完成后镜像翻转检查形准。',
      count: 3,
      gallerySubject: '素描',
      galleryKeyword: '结构',
      tool: '镜像',
    ),
    ArtworkSuggestion(
      tag: '线条生硬',
      text: '多练长线条的轻重虚实，衣纹注意疏密与节奏。',
      count: 2,
      gallerySubject: '速写',
      galleryKeyword: '线条',
      tool: '速写计时',
    ),
    ArtworkSuggestion(
      tag: '明暗层次弱',
      text: '眯眼概括黑白灰三大关系。',
      count: 1,
      gallerySubject: '素描',
      galleryKeyword: '明暗',
      tool: '明度检查',
    ),
  ],
);

Future<void> _pumpHome(WidgetTester tester, String role) async {
  tester.view.physicalSize = const Size(1180, 820);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final storage = AppStorage(await SharedPreferences.getInstance());
  final staff = role != 'student';
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appStorageProvider.overrideWithValue(storage),
        homeRepositoryProvider.overrideWithValue(_RoleHomeRepository(role)),
        homeStudySnapshotProvider.overrideWith(
          (ref) async => staff ? _staffSnapshot : _studentSnapshot,
        ),
        homePracticeProvider.overrideWith(
          (ref) async => buildHomePractices(
            insights: _insights,
            snapshot: _studentSnapshot,
          ),
        ),
        homeLatestReviewProvider.overrideWith(
          (ref) async => const HomeLatestReview(
            artworkId: 'aw-1006',
            title: '石膏头像结构练习',
            subject: '素描',
            drawingDate: '2026-11-04',
            score: 87,
            teacherName: '李静',
            comment: '结构交代清楚，暗部再整体一些',
          ),
        ),
        homeReviewStatsProvider.overrideWith(
          (ref) async => const ArtworkStats(total: 25, reviewed: 18, pending: 7),
        ),
        homeAdminTodoProvider.overrideWith(
          (ref) async => (leaves: 3, signs: 2),
        ),
        schoolDormitoryCheckConfigProvider.overrideWith(
          (ref) async => const SchoolDormitoryCheckConfig(
            eveningDeadline: '22:10前',
            morningDeadline: '07:10前',
          ),
        ),
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
}

void main() {
  group('homeSectionsFor', () {
    test('each role only gets the cards that apply', () {
      final student = homeSectionsFor('student');
      expect(student.practice && student.studySnapshot && student.courses, isTrue);
      expect(student.reviewQueue || student.todo || student.sideTodo, isFalse);

      final teacher = homeSectionsFor('teacher');
      expect(teacher.studySnapshot && teacher.reviewQueue, isTrue);
      expect(teacher.practice || teacher.todo, isFalse);

      final head = homeSectionsFor('headTeacher');
      expect(head.studySnapshot && head.todo && head.courses, isTrue);

      final admin = homeSectionsFor('admin');
      expect(admin.sideTodo && admin.studySnapshot, isTrue);
      expect(admin.courses, isFalse);

      final dorm = homeSectionsFor('dormManager');
      expect(dorm.sideTodo, isTrue);
      expect(dorm.studySnapshot || dorm.courses || dorm.subjects, isFalse);

      final unknown = homeSectionsFor('');
      expect(unknown.practice || unknown.studySnapshot || unknown.sideTodo, isFalse);
    });

    test('role falls back to the demo token before /myInfo returns', () {
      expect(resolveHomeRole('teacher', token: ''), 'teacher');
      expect(
        resolveHomeRole('', token: 'demo.dormManager.13809310004', demoMode: true),
        'dormManager',
      );
      expect(resolveHomeRole('', token: '', demoMode: true), '');
      expect(resolveHomeRole('', token: 'real-token', demoMode: false), '');
    });
  });

  group('buildHomePractices', () {
    test('two frequent problems open their tools, the weak subject opens the gallery', () {
      final items = buildHomePractices(
        insights: _insights,
        snapshot: _studentSnapshot,
      );
      expect(items, hasLength(3));
      expect(items[0].route, RoutePaths.artToolbox);
      expect(items[0].arguments, {'tool': ArtTool.mirror.key});
      expect(items[0].tag, '结构错误');
      expect(items[0].reason, startsWith('老师点评中出现 3 次'));
      expect(items[1].arguments, {'tool': ArtTool.quickSketch.key});
      expect(items[2].source, HomePracticeSource.weakSubject);
      expect(items[2].route, RoutePaths.gallery);
      expect(items[2].arguments, {'subject': '色彩'});
      expect(items[2].reason, contains('色彩 85 分（B 档）'));
      for (final item in items.where((i) => i.route == RoutePaths.artToolbox)) {
        expect(ArtTool.tryParse('${item.arguments['tool']}')?.key, item.arguments['tool']);
      }
    });

    test('without exam data the weak subject comes from daily artworks', () {
      final items = buildHomePractices(
        insights: const ArtworkInsights(weakestSubject: '色彩'),
      );
      expect(items.single.arguments, {'subject': '色彩'});
      expect(items.single.reason, contains('日常作品'));
    });

    test('with no data at all it suggests two basics', () {
      final items = buildHomePractices();
      expect(items.map((i) => i.arguments['tool']), [
        ArtTool.valueOrder.key,
        ArtTool.figure.key,
      ]);
      expect(items.every((i) => i.source == HomePracticeSource.basics), isTrue);
    });

    test('suggestions without a tool open the gallery with a keyword', () {
      final items = buildHomePractices(
        insights: const ArtworkInsights(
          suggestions: [
            ArtworkSuggestion(
              tag: '空间感弱',
              text: '拉开前后虚实。',
              gallerySubject: '色彩',
              galleryKeyword: '空间',
            ),
          ],
        ),
        snapshot: _studentSnapshot,
      );
      expect(items.first.arguments, {'subject': '色彩', 'keyword': '空间'});
      // 弱项科目与上一条同为色彩范画，不重复推荐。
      expect(items, hasLength(1));
    });
  });

  group('HomeLatestReview', () {
    test('keeps the latest teacher comment and only its first sentence', () {
      final review = HomeLatestReview.from(
        const ArtworkSummary(
          id: 'aw-1006',
          title: '石膏头像结构练习',
          subject: '素描',
          finalScore: 87,
        ),
        const ArtworkDetail(
          work: ArtworkSummary(id: 'aw-1006', title: '石膏头像结构练习'),
          reviews: [
            ArtworkReview(
              teacherId: 't-2',
              teacherName: '张明远',
              reviewed: true,
              score: 86,
              content: '暗部笔触偏平，反光和投影的层次可以再拉开。',
              reviewedTime: '2026-11-05 20:51:00',
            ),
            ArtworkReview(
              teacherId: 't-1',
              teacherName: '李静',
              reviewed: true,
              score: 88,
              content: '结构交代清楚，暗部再整体一些；五官位置略有偏差。',
              reviewedTime: '2026-11-06 09:10:00',
            ),
          ],
        ),
      );
      expect(review.teacherName, '李静');
      expect(review.comment, '结构交代清楚，暗部再整体一些');
      expect(review.score, 87);
      expect(homeCommentLine('只有一句'), '只有一句');
    });
  });

  group('buildHomeTodos', () {
    test('head teacher, dorm manager and admin get their own rows', () {
      final head = buildHomeTodos(
        'headTeacher',
        const HomeTodoInput(pendingReviews: 7, unreadNotices: 2),
      );
      expect(head.map((i) => i.title), ['待点评作品', '班级工作台', '未读消息']);
      expect(head.first.value, '7');
      expect(head.first.attention, isTrue);

      final dorm = buildHomeTodos(
        'dormManager',
        const HomeTodoInput(eveningCheck: '22:10前', morningCheck: '07:10前'),
      );
      expect(dorm.first.value, '22:10');
      expect(dorm[1].value, '07:10');
      expect(dorm.map((i) => i.action), contains(HomeTodoAction.dormCheckIn));
      expect(dorm.last.attention, isFalse);

      final admin = buildHomeTodos(
        'admin',
        const HomeTodoInput(leaveApprovals: 3, signConfirmations: 0),
      );
      expect(admin.first.title, '教师请假审批');
      expect(admin.first.value, '3');
      expect(admin[1].attention, isFalse);

      expect(buildHomeTodos('student', const HomeTodoInput()), isEmpty);
    });
  });

  group('HomePage by role at 1180 × 820', () {
    // 内容区 950 宽：左栏 627（轮播按 647:190）+ 间距 16 + 功能入口 313。
    const leftColumnHeight = 627 * 190 / 647 + 16 + 313;

    void expectSameHeight(WidgetTester tester, Type left, Type right) {
      expect(
        tester.getSize(find.byType(left)).height,
        closeTo(tester.getSize(find.byType(right)).height, 0.5),
        reason: '$left / $right',
      );
    }

    testWidgets('student sees today practice, latest review and study snapshot', (
      tester,
    ) async {
      await _pumpHome(tester, 'student');
      expect(tester.takeException(), isNull);
      expectSameHeight(tester, HomePracticeCard, HomeLatestReviewCard);
      expect(find.textContaining('今日练习'), findsOneWidget);
      expect(find.text('镜像翻转'), findsOneWidget);
      expect(find.text('色彩范画对照'), findsOneWidget);
      expect(find.textContaining('最近点评'), findsOneWidget);
      expect(find.text('石膏头像结构练习'), findsOneWidget);
      expect(find.textContaining('结构交代清楚'), findsOneWidget);
      expect(find.textContaining('学情速览'), findsOneWidget);
      expect(find.text('今日课程'), findsOneWidget);
      expect(find.textContaining('今日待办'), findsNothing);
      expect(find.byType(ArtSubjectCard), findsNWidgets(3));
    });

    testWidgets('teacher sees the review queue next to the studio snapshot', (
      tester,
    ) async {
      await _pumpHome(tester, 'teacher');
      expect(tester.takeException(), isNull);
      expectSameHeight(tester, HomeStudySnapshotCard, HomeReviewQueueCard);
      expect(find.textContaining('画室学情速览'), findsOneWidget);
      expect(find.textContaining('作品点评'), findsWidgets);
      expect(find.text('开始点评'), findsOneWidget);
      expect(find.textContaining('已点评 18 件'), findsOneWidget);
      expect(find.textContaining('今日练习'), findsNothing);
      expect(find.text('今日课程'), findsOneWidget);
    });

    testWidgets('head teacher sees today todos beside the snapshot', (tester) async {
      await _pumpHome(tester, 'headTeacher');
      expect(tester.takeException(), isNull);
      expectSameHeight(tester, HomeStudySnapshotCard, HomeTodoCard);
      expect(find.text('今日待办'), findsOneWidget);
      expect(find.text('待点评作品'), findsOneWidget);
      expect(find.text('班级工作台'), findsOneWidget);
      expect(find.text('今日课程'), findsOneWidget);
    });

    testWidgets('dorm manager has no study cards, courses or subject entries', (
      tester,
    ) async {
      await _pumpHome(tester, 'dormManager');
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(HomeTodoCard)).height,
        closeTo(leftColumnHeight, 0.5),
      );
      expect(find.text('今日待办'), findsOneWidget);
      expect(find.text('晚查寝'), findsOneWidget);
      expect(find.text('22:10'), findsOneWidget);
      expect(find.text('按宿舍查寝'), findsWidgets);
      expect(find.textContaining('学情速览'), findsNothing);
      expect(find.text('今日课程'), findsNothing);
      expect(find.byType(ArtSubjectCard), findsNothing);
    });

    testWidgets('admin swaps the empty course panel for today todos', (tester) async {
      await _pumpHome(tester, 'admin');
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(HomeTodoCard)).height,
        closeTo(leftColumnHeight, 0.5),
      );
      expect(find.text('今日待办'), findsOneWidget);
      expect(find.text('教师请假审批'), findsWidgets);
      expect(find.text('进入智慧校园'), findsOneWidget);
      expect(find.textContaining('画室学情速览'), findsOneWidget);
      expect(find.text('今日课程'), findsNothing);
    });
  });
}
