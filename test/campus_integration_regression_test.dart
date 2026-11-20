import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_backend.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_store.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/campus/campus_b_admin.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/campus/campus_b_common.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/campus/campus_b_courses.dart';
import 'package:the_road_of_art_flutter/core/network/api_client.dart';
import 'package:the_road_of_art_flutter/core/providers/app_providers.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/data/admin_repository.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/data/teacher_repository.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/state/teacher_exam_controller.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/ui/teacher_leave_approval_view.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/ui/widgets/smart_campus_dark_tabs.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/ui/widgets/smart_campus_stat_card.dart';

void main() {
  late AppStorage storage;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = AppStorage(await SharedPreferences.getInstance());
  });

  test('移动课次冲突保留旧课，重试成功后得到新课次', () async {
    await DemoStore.init();
    await DemoStore.reset();
    addTearDown(DemoStore.reset);
    final router = DemoRouter('course-move');
    registerCampusBAdmin(router);
    final repo = AdminRepository(
      client: ApiClient(storage: storage, demoRouter: router),
    );
    final sourceDay = cbAddDays(cbToday(), 14);
    final source = cbCoursesOn(sourceDay).first;
    final targetDay = cbAddDays(sourceDay, 1);
    final busy = cbCoursesOn(targetDay).first;
    final denied = await repo.moveCourse(
      courseId: source.id,
      classId: busy.classId,
      date: busy.date,
      lineNum: busy.lineNum,
    );
    expect(denied.isSuccess, isFalse);
    expect(cbCourseById(source.id), isNotNull);

    final occupied = cbCoursesOn(targetDay).map((c) => c.lineNum).toSet();
    final slot = [1, 2, 3, 4, 5].firstWhere((n) => !occupied.contains(n));
    final saved = await repo.moveCourse(
      courseId: source.id,
      classId: source.classId,
      date: cbDate(targetDay),
      lineNum: slot,
    );
    expect(saved.isSuccess, isTrue, reason: saved.msg);
    expect(cbCourseById(source.id), isNull);
    final replacement = cbCoursesOn(
      targetDay,
    ).singleWhere((c) => c.lineNum == slot);
    expect(replacement.id, isNot(source.id));
    expect(replacement.subjectId, source.subjectId);
    expect(replacement.teacherUserId, source.teacherUserId);
    expect(replacement.classroomId, source.classroomId);
    expect(replacement.color, source.color);
  });

  testWidgets('待我审批统计与页签都包括状态 0 和 1', (tester) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final listFilters = <List<int>>[];
    final router = DemoRouter('leave-filters')
      ..post('/app/school/v2/teacher/headTeacherStudentLeaveList', (req) {
        final statuses = req
            .listOf('statusList')
            .map((value) => int.parse('$value'))
            .toList();
        final size = req.intOf('size');
        if (size > 1) listFilters.add(statuses);
        final records = [
          for (final status in [0, 1, 3])
            if (statuses.isEmpty || statuses.contains(status))
              {
                'id': '$status',
                'status': status,
                'student': {'realname': '请假学生$status'},
              },
        ];
        return {
          'total': records.length,
          'records': records.take(size).toList(),
        };
      });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStorageProvider.overrideWithValue(storage),
          apiClientProvider.overrideWithValue(
            ApiClient(storage: storage, demoRouter: router),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: TeacherLeaveApprovalView(onBack: () {})),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    final card = tester.widget<SmartCampusStatCard>(
      find.byWidgetPredicate(
        (widget) => widget is SmartCampusStatCard && widget.label == '待我审批',
      ),
    );
    expect(card.value, 2);
    await tester.tap(
      find.descendant(
        of: find.byWidgetPredicate((widget) => widget is SmartCampusDarkTabs),
        matching: find.text('待我审批'),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(listFilters.last, [0, 1]);
    expect(find.text('请假学生0'), findsOneWidget);
    expect(find.text('请假学生1'), findsOneWidget);
    expect(find.text('请假学生3'), findsNothing);
  });

  for (final listHasStats in [true, false]) {
    test('考评列表携带统计时只请求当前详情，旧服务器继续回退 · $listHasStats', () async {
      final statRequests = <String>[];
      final router = DemoRouter('exam-stats')
        ..post('/app/school/v2/teacher/examList', (req) {
          expect(req.value('includeStat'), isTrue);
          return [
            for (final id in ['27', '28'])
              {
                'id': id,
                'subjectId': 38,
                'name': '联考',
                if (listHasStats) 'stat': {'scoreCount': 4, 'unscoredCount': 2},
              },
          ];
        })
        ..post('/app/school/v2/teacher/examStudentList', (_) => [])
        ..post('/app/school/v2/teacher/examStudentStat', (req) {
          statRequests.add(req.str('examId'));
          return {'scoreCount': 4, 'unscoredCount': 2};
        });
      final controller = TeacherExamController(
        repository: TeacherRepository(
          client: ApiClient(storage: storage, demoRouter: router),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          teacherExamControllerProvider.overrideWith((ref) => controller),
        ],
      );
      final subscription = container.listen(
        teacherExamControllerProvider,
        (_, _) {},
      );
      addTearDown(() {
        subscription.close();
        container.dispose();
      });
      await controller.loadExamList();
      expect(
        container.read(teacherExamControllerProvider).overviewStats.reviewed,
        8,
      );
      expect(
        container.read(teacherExamControllerProvider).overviewStats.pending,
        4,
      );
      expect(
        statRequests,
        listHasStats ? ['27'] : unorderedEquals(['27', '28', '27']),
      );
    });
  }
}
