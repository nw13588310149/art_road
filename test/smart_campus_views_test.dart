// 智慧校园各角色页面在 1180×820（外壳内容区约 950 宽）下用演示数据渲染一遍：
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
  Map<String, _Open> views,
) async {
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
    errors.add(
      '${details.exceptionAsString().split('\n').first} @ $where',
    );
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
  tester.view.physicalSize = const Size(950, 780);
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

void main() {
  setUpAll(() {
    registerPlatformCoreFixtures(DemoBackend.platform);
    registerCampusFixturesPartA(DemoBackend.platform);
    registerCampusFixturesPartB(DemoBackend.platform);
  });

  testWidgets('teacher campus pages render without overflow', (tester) async {
    await _visitAll(tester, DemoAccounts.teacher, {
      '授课课表': (c) => c.openMySchedule(),
      '签课管理': (c) => c.openClassAttendance(),
      '学生名册': (c) => c.openStudentRoster(),
      '作业批改': (c) => c.openHomeworkReview(),
      '考评管理': (c) => c.openExamReview(),
      '我的请假': (c) => c.openMyTeacherLeave(),
      '群聊': (c) => c.openGroupChat(),
      '校长信箱': (c) => c.openPrincipalMailbox(),
    });
  });

  testWidgets('head teacher campus pages render without overflow', (
    tester,
  ) async {
    await _visitAll(tester, DemoAccounts.headTeacher, {
      '班级工作台': (c) => c.openClassWorkbench(),
      '请假审批': (c) => c.openLeaveApproval(),
      '家校沟通': (c) => c.openHomeSchoolCommunication(),
      '查寝历史': (c) => c.openDormHistory(),
    });
  });

  testWidgets('student campus pages render without overflow', (tester) async {
    await _visitAll(tester, DemoAccounts.student, {
      '我的课表': (c) => c.openMySchedule(),
      '我的班级': (c) => c.openMyClass(),
      '课堂签到': (c) => c.openCheckIn(),
      '我的作业': (c) => c.openMyHomework(),
      '我的考试': (c) => c.openMyGrades(),
      '我的请假': (c) => c.openLeaveManagement(),
      '我的查寝': (c) => c.openDormCheck(),
      '校长信箱': (c) => c.openPrincipalMailbox(),
      '群聊': (c) => c.openGroupChat(),
    });
  });

  testWidgets('dorm manager campus pages render without overflow', (
    tester,
  ) async {
    await _visitAll(tester, DemoAccounts.dormManager, {
      '按宿舍查寝': (c) => c.openDormCheckByRoom(),
      '查寝动态': (c) => c.openDormDynamic(),
      '查寝历史': (c) => c.openDormHistory(),
      '到岗打卡': (c) => c.openDormCheckInManagement(),
      '宿管请假': (c) => c.openMyTeacherLeave(),
    });
  });

  testWidgets('admin campus pages render without overflow', (tester) async {
    await _visitAll(tester, DemoAccounts.admin, {
      '学生管理': (c) => c.openStudentManagement(),
      '教师管理': (c) => c.openTeacherManagement(),
      '班级管理': (c) => c.openClassManagement(),
      '排课与课表': (c) => c.openScheduleManagement(),
      '签课管理': (c) => c.openSignManagement(),
      '教职工请假审批': (c) => c.openDormLeaveApproval(),
      '人脸库': (c) => c.openFaceLibrary(),
      '通知管理': (c) => c.openNotificationManagement(),
    });
  });
}
