import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_store.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/demo_fixtures.dart';
import 'package:the_road_of_art_flutter/core/providers/app_providers.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';
import 'package:the_road_of_art_flutter/core/theme/app_theme.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:the_road_of_art_flutter/features/artworks/ui/student_artworks_view.dart';
import 'package:the_road_of_art_flutter/features/artworks/ui/teacher_artworks_view.dart';
import 'package:the_road_of_art_flutter/features/gallery/ui/gallery_page.dart';
import 'package:the_road_of_art_flutter/features/study_center/state/study_center_args.dart';
import 'package:the_road_of_art_flutter/features/study_center/ui/staff/staff_study_view.dart';
import 'package:the_road_of_art_flutter/features/study_center/ui/student/student_study_view.dart';

/// 外壳内容区约 950 × 740（iPad 1180 × 820 横屏去掉侧栏与顶栏）；760 宽用来检查窄布局。
const _sizes = <Size>[Size(950, 740), Size(760, 720)];
var _contentSize = _sizes.first;

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  required DemoAccount account,
  Object? arguments,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'token': account.token,
  });
  final prefs = await SharedPreferences.getInstance();
  await DemoStore.init();
  await DemoStore.reset();
  tester.view.physicalSize = _contentSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appStorageProvider.overrideWithValue(AppStorage(prefs))],
      child: MaterialApp(
        theme: AppTheme.light,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: RouteSettings(name: '/page', arguments: arguments),
          builder: (_) => Scaffold(backgroundColor: AppColors.page, body: page),
        ),
      ),
    ),
  );
  await _settle(tester);
}

/// 演示接口有 120–300ms 的模拟延迟；加载指示器会一直出帧，所以按固定时长推进。
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(registerDemoFixtures);

  for (final size in _sizes) {
    group('${size.width.round()} 宽', () {
      setUp(() => _contentSize = size);
      _pageTests();
    });
  }
}

void _pageTests() {
  testWidgets('我的学情总览：页头学号、超过百分比与各科卡片', (tester) async {
    await _pump(
      tester,
      const StudentStudyView(args: StudyCenterArgs()),
      account: DemoAccounts.student,
    );
    expect(find.text('我的学情'), findsOneWidget);
    expect(find.textContaining('学号 2027001'), findsOneWidget);
    expect(find.text('超过全画室 82% 的考生'), findsOneWidget);
    expect(find.text('各科表现'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await _settle(tester);
    await tester.tap(find.text('评分标准').first);
    await _settle(tester);
    expect(find.text('素描 · 评分标准'), findsOneWidget);
    await tester.tapAt(const Offset(8, 8));
    await _settle(tester);

    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await _settle(tester);
    expect(find.textContaining('考试记录'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('成绩报告与成长曲线', (tester) async {
    await _pump(
      tester,
      const StudentStudyView(args: StudyCenterArgs(examId: '26')),
      account: DemoAccounts.student,
    );
    expect(find.textContaining('各科成绩'), findsOneWidget);
    await tester.tap(find.text('成长曲线'));
    await _settle(tester);
    expect(find.textContaining('分数走势'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await _settle(tester);
    expect(find.textContaining('历次成绩'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('班级学情：考试选择与指标', (tester) async {
    await _pump(
      tester,
      const StaffStudyView(args: StudyCenterArgs()),
      account: DemoAccounts.teacher,
    );
    expect(find.text('班级学情'), findsOneWidget);
    expect(find.text('参考人数'), findsOneWidget);
    expect(find.textContaining('更多考试'), findsOneWidget);
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -700),
    );
    await _settle(tester);
    expect(find.text('总分排名'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('作品档案、作品详情与上传弹窗', (tester) async {
    await _pump(
      tester,
      const StudentArtworksView(),
      account: DemoAccounts.student,
    );
    expect(find.textContaining('点评小结'), findsOneWidget);
    expect(find.textContaining('得分最高科目'), findsOneWidget);
    expect(find.textContaining('最佳'), findsNothing);

    await tester.tap(find.text('上传作品').first);
    await _settle(tester);
    expect(find.text('提交作品'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await _settle(tester);
    expect(find.text('提交作品'), findsNothing);

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -400),
    );
    await _settle(tester);
    expect(find.text('2026 年 11 月'), findsOneWidget);
    await tester.tap(find.text('石膏头像结构练习'));
    await _settle(tester);
    expect(find.text('老师点评'), findsOneWidget);
    expect(find.text('最终得分'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('作品点评列表、工作台与点评标签', (tester) async {
    await _pump(
      tester,
      const TeacherArtworksView(),
      account: DemoAccounts.teacher,
    );
    expect(find.text('作品点评'), findsOneWidget);
    expect(find.text('待点评'), findsWidgets);

    await tester.tap(find.text('点评标签'));
    await _settle(tester);
    expect(find.textContaining('最多 50 个'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭'));
    await _settle(tester);

    await tester.tap(find.text('秋日静物色彩写生').first);
    await _settle(tester);
    expect(find.textContaining('点评 · '), findsOneWidget);
    expect(find.textContaining('学号 '), findsOneWidget);
    expect(find.textContaining('已选 0 个'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('范画库列表与详情', (tester) async {
    await _pump(tester, const GalleryPage(), account: DemoAccounts.student);
    expect(find.text('范画库'), findsOneWidget);
    expect(find.byTooltip('返回'), findsNothing);
    expect(find.text('全部科目'), findsOneWidget);
    await tester.tap(find.text('素描').first);
    await _settle(tester);
    expect(find.textContaining('石膏'), findsWidgets);
    await _unmount(tester);

    await _pump(
      tester,
      const GalleryPage(),
      account: DemoAccounts.student,
      arguments: <String, dynamic>{'workId': '7101'},
    );
    expect(find.text('大卫石膏像 · 侧转头像'), findsOneWidget);
    expect(find.text('点评要点'), findsOneWidget);
    await _unmount(tester);
  });
}
