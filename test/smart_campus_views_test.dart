// 智慧校园各角色页面按 1180×820、1024×768 横屏的内容区宽度渲染：
// 不允许出现溢出黄黑条或其他渲染异常。网络图片在测试环境加载失败属正常，忽略。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_backend.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/campus/campus_a_registry.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/campus/campus_b_registry.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/platform_core_fixtures.dart';
import 'package:the_road_of_art_flutter/core/providers/app_providers.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';
import 'package:the_road_of_art_flutter/core/theme/app_theme.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/state/smart_campus_controller.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/ui/smart_campus_page.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/ui/widgets/smart_campus_notice_card.dart';

bool _ignorable(FlutterErrorDetails details) {
  final text = details.exceptionAsString();
  return details.exception is NetworkImageLoadException ||
      text.contains('HTTP request failed') ||
      text.contains('Unable to load asset') ||
      text.contains('Invalid image data') ||
      details.library == 'image resource service';
}

Future<void> _settle(WidgetTester tester, {int steps = 20}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

typedef _Open = void Function(SmartCampusController controller);

Future<void> _visitAll(
  WidgetTester tester,
  DemoAccount account,
  Map<String, _Open> views, {
  required Size viewport,
  Map<String, Future<void> Function(WidgetTester)> interactions = const {},
}) async {
  final errors = <String>[];
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (_ignorable(details)) {
      return;
    }
    final text = details.toString();
    if (text.contains('was not laid out') ||
        text.contains('Failed assertion: line 5994') ||
        text.contains('Failed assertion: line 5705') ||
        text.contains('_debugDoingThisLayout')) {
      return;
    }
    final where = RegExp(
      r'(lib/features/smart_campus/[\w/]+\.dart:\d+)',
    ).allMatches(text).map((m) => m.group(1)).toSet().take(3).join(' ');
    errors.add('${details.exceptionAsString().split('\n').first} @ $where');
  };
  SharedPreferences.setMockInitialValues(<String, Object>{
    'token': account.token,
    'schoolId': '1',
    'mobile': account.mobile,
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [appStorageProvider.overrideWithValue(AppStorage(prefs))],
  );
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  try {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            backgroundColor: AppColors.page,
            body: SmartCampusPage(),
          ),
        ),
      ),
    );
    await _settle(tester, steps: 30);
    final dashboardErrors = errors.length;
    if (dashboardErrors > 0) {
      errors.insert(0, '[${account.role.name} 工作台]');
    }
    final controller = container.read(smartCampusControllerProvider.notifier);
    for (final entry in views.entries) {
      final before = errors.length;
      entry.value(controller);
      await _settle(tester);
      await interactions[entry.key]?.call(tester);
      if (errors.length > before) {
        errors.insert(before, '[${account.role.name} ${entry.key}]');
      }
      controller.backToDashboard();
      await _settle(tester, steps: 5);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await _settle(tester, steps: 5);
  } finally {
    FlutterError.onError = original;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }
  expect(errors, isEmpty, reason: errors.join('\n'));
}

Future<void> _checkRosterMenu(WidgetTester tester) async {
  await tester.tap(find.text('全部班级'));
  await _settle(tester, steps: 4);
  final option = find.descendant(
    of: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
    matching: find.text('联考冲刺1班'),
  );
  expect(option, findsOneWidget);
  await tester.tap(option);
  await _settle(tester);
  expect(option, findsNothing);
  expect(find.text('全部班级'), findsNothing);
  expect(find.text('联考冲刺1班'), findsWidgets);
}

Future<void> _checkClassNotices(WidgetTester tester) async {
  final notices = find.byType(SmartCampusNoticeCard);
  expect(notices, findsNWidgets(3));
  expect(
    tester.getTopLeft(notices.at(0)).dy,
    tester.getTopLeft(notices.at(1)).dy,
  );
}

Future<void> _checkExamContentCard(WidgetTester tester) async {
  final ratio = find.text('/14');
  expect(ratio, findsOneWidget);
  final card = find
      .ancestor(of: ratio, matching: find.byType(AppPressable))
      .first;
  final title = find.descendant(of: card, matching: find.text('2026 年 10 月月考'));
  expect(title, findsOneWidget);
  expect(tester.getTopLeft(ratio).dy, lessThan(tester.getTopLeft(title).dy));
  expect(
    find.descendant(of: card, matching: find.textContaining('待评 ')),
    findsOneWidget,
  );
}

Future<void> _checkMailboxPrivacy(WidgetTester tester) async {
  final anonymous = find.byType(AppSwitch);
  expect(tester.widget<AppSwitch>(anonymous).value, isFalse);
  await tester.tap(find.text('举报'));
  await _settle(tester, steps: 3);
  expect(tester.widget<AppSwitch>(anonymous).value, isTrue);
  expect(find.text('举报内容只有校长能看到，默认匿名提交'), findsOneWidget);
}

void main() {
  setUpAll(() {
    registerPlatformCoreFixtures(DemoBackend.platform);
    registerCampusFixturesPartA(DemoBackend.platform);
    registerCampusFixturesPartB(DemoBackend.platform);
  });

  for (final viewport in [const Size(950, 780), const Size(814, 700)]) {
    testWidgets(
      'teacher campus pages render without overflow at ${viewport.width}',
      (tester) async {
        await _visitAll(
          tester,
          DemoAccounts.teacher,
          {
            '授课课表': (c) => c.openMySchedule(),
            '签课管理': (c) => c.openClassAttendance(),
            '学生名册': (c) => c.openStudentRoster(),
            '作业批改': (c) => c.openHomeworkReview(),
            '考评管理': (c) => c.openExamReview(),
            '我的请假': (c) => c.openMyTeacherLeave(),
            '群聊': (c) => c.openGroupChat(),
            '校长信箱': (c) => c.openPrincipalMailbox(),
          },
          viewport: viewport,
          interactions: {
            '学生名册': _checkRosterMenu,
            '考评管理': _checkExamContentCard,
          },
        );
      },
    );

    testWidgets(
      'head teacher campus pages render without overflow at ${viewport.width}',
      (tester) async {
        await _visitAll(tester, DemoAccounts.headTeacher, {
          '班级工作台': (c) => c.openClassWorkbench(),
          '请假审批': (c) => c.openLeaveApproval(),
          '家校沟通': (c) => c.openHomeSchoolCommunication(),
          '查寝历史': (c) => c.openDormHistory(),
        }, viewport: viewport);
      },
    );

    testWidgets(
      'student campus pages render without overflow at ${viewport.width}',
      (tester) async {
        await _visitAll(
          tester,
          DemoAccounts.student,
          {
            '我的课表': (c) => c.openMySchedule(),
            '我的班级': (c) => c.openMyClass(),
            '课堂签到': (c) => c.openCheckIn(),
            '我的作业': (c) => c.openMyHomework(),
            '我的考试': (c) => c.openMyGrades(),
            '我的请假': (c) => c.openLeaveManagement(),
            '我的查寝': (c) => c.openDormCheck(),
            '校长信箱': (c) => c.openPrincipalMailbox(),
            '群聊': (c) => c.openGroupChat(),
          },
          viewport: viewport,
          interactions: {
            '我的班级': _checkClassNotices,
            '校长信箱': _checkMailboxPrivacy,
          },
        );
      },
    );

    testWidgets(
      'dorm manager campus pages render without overflow at ${viewport.width}',
      (tester) async {
        await _visitAll(tester, DemoAccounts.dormManager, {
          '按宿舍查寝': (c) => c.openDormCheckByRoom(),
          '查寝动态': (c) => c.openDormDynamic(),
          '查寝历史': (c) => c.openDormHistory(),
          '到岗打卡': (c) => c.openDormCheckInManagement(),
          '宿管请假': (c) => c.openMyTeacherLeave(),
        }, viewport: viewport);
      },
    );

    testWidgets(
      'admin campus pages render without overflow at ${viewport.width}',
      (tester) async {
        await _visitAll(tester, DemoAccounts.admin, {
          '学生管理': (c) => c.openStudentManagement(),
          '教师管理': (c) => c.openTeacherManagement(),
          '班级管理': (c) => c.openClassManagement(),
          '排课与课表': (c) => c.openScheduleManagement(),
          '签课管理': (c) => c.openSignManagement(),
          '教职工请假审批': (c) => c.openDormLeaveApproval(),
          '人脸库': (c) => c.openFaceLibrary(),
          '通知管理': (c) => c.openNotificationManagement(),
        }, viewport: viewport);
      },
    );
  }
}
