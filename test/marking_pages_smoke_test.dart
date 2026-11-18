import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_artwork_store.dart';
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

/// 外壳内容区 950 / 814 对应常规与窄横屏；760 宽用来检查堆叠布局。
const _sizes = <Size>[Size(950, 740), Size(814, 680), Size(760, 720)];
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
  DemoArtworkStore.clearCache();
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
  testWidgets('学情总览：学号、超过百分比、各科成绩与评分标准', (tester) async {
    await _pump(
      tester,
      const StudentStudyView(args: StudyCenterArgs()),
      account: DemoAccounts.student,
    );
    expect(find.text('我的学情'), findsNothing);
    expect(find.text('学情'), findsOneWidget);
    expect(find.textContaining('学号 2027001'), findsOneWidget);
    expect(find.text('超过全画室 82% 的考生'), findsOneWidget);
    expect(find.text('各科成绩'), findsOneWidget);
    expect(find.text('查看完整报告'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('全画室排名')).dy,
      tester.getTopLeft(find.text('城东校区排名')).dy,
    );
    await tester.ensureVisible(find.text('评分标准'));
    await _settle(tester);
    await tester.tap(find.text('评分标准'));
    await _settle(tester);
    expect(find.text('素描 · 评分标准'), findsOneWidget);
    await tester.tap(
      find.descendant(of: find.byType(AppDialog), matching: find.text('色彩')),
    );
    await _settle(tester);
    expect(find.text('色彩 · 评分标准'), findsOneWidget);
    await tester.tapAt(const Offset(8, 8));
    await _settle(tester);

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -900),
    );
    await _settle(tester);
    expect(find.text('考试记录'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('成绩报告：点一科打开原卷，再看成长曲线', (tester) async {
    await _pump(
      tester,
      const StudentStudyView(args: StudyCenterArgs(examId: '26')),
      account: DemoAccounts.student,
    );
    expect(find.textContaining(RegExp(r'^各科成绩')), findsOneWidget);
    await tester.tap(find.text('色彩'));
    await _settle(tester);
    expect(find.text('色彩 · 我的成绩'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭原卷'));
    await _settle(tester);

    await tester.tap(find.text('成长曲线'));
    await _settle(tester);
    expect(find.textContaining('分数走势'), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -600),
    );
    await _settle(tester);
    expect(find.textContaining('历次成绩'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('返回'));
    await _settle(tester);
    await tester.tap(find.byTooltip('返回'));
    await _settle(tester);
    expect(find.textContaining(RegExp(r'^各科成绩')), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('班级学情：考试选择与指标', (tester) async {
    await _pump(
      tester,
      const StaffStudyView(args: StudyCenterArgs()),
      account: DemoAccounts.teacher,
    );
    expect(find.text('班级学情'), findsNothing);
    expect(find.text('参考人数'), findsOneWidget);
    expect(find.textContaining('更多考试'), findsOneWidget);
    if (_contentSize.width >= 814) {
      expect(
        tester.getTopLeft(find.text('参考人数')).dy,
        tester.getTopLeft(find.text('满分')).dy,
      );
    }
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -700),
    );
    await _settle(tester);
    expect(find.text('总分排名'), findsOneWidget);
    final search = find.descendant(
      of: find.byType(AppSearchField),
      matching: find.byType(EditableText),
    );
    await tester.enterText(search, '林小雨');
    await _settle(tester);
    final rowName = find.byWidgetPredicate(
      (widget) => widget is Text && widget.data == '林小雨',
    );
    await tester.ensureVisible(rowName);
    await _settle(tester);
    await tester.tap(rowName);
    await _settle(tester);
    expect(find.textContaining('林小雨 · 2026-09-20'), findsOneWidget);
    await tester.tap(find.text('成绩曲线'));
    await _settle(tester);
    expect(find.textContaining('林小雨 · 近'), findsOneWidget);
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
    expect(find.text('看范画'), findsNothing);
    await tester.tap(find.text('查看练习建议'));
    await _settle(tester);
    expect(find.text('看范画'), findsWidgets);
    await tester.tap(find.text('收起练习建议'));
    await _settle(tester);

    await tester.tap(find.text('上传作品').first);
    await _settle(tester);
    expect(find.text('提交作品'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await _settle(tester);
    expect(find.text('提交作品'), findsNothing);

    expect(find.text('2026 年 11 月'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('石膏头像结构练习'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await _settle(tester);
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
    expect(find.text('作品点评'), findsNothing);
    expect(find.text('待点评'), findsWidgets);

    await tester.tap(find.text('点评标签'));
    await _settle(tester);
    expect(find.textContaining('最多 50 个'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭'));
    await _settle(tester);

    await tester.tap(find.text('开始点评'));
    await _settle(tester);
    expect(find.textContaining('学号 '), findsOneWidget);
    expect(find.textContaining('已选'), findsOneWidget);
    expect(find.text('请组长复核'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('素材中心列表与详情', (tester) async {
    await _pump(tester, const GalleryPage(), account: DemoAccounts.student);
    expect(find.text('范画库'), findsNothing);
    expect(find.byTooltip('返回'), findsNothing);
    expect(find.text('素材中心'), findsOneWidget);
    expect(find.text('全部题材'), findsOneWidget);
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
    await tester.tap(find.text('对比我的原卷'));
    await _settle(tester);
    final divider = find.bySemanticsLabel('对比分隔线');
    expect(divider, findsOneWidget);
    expect(
      ModalRoute.of(tester.element(find.byType(AppCompareView)))?.settings.name,
      imageCompareRouteName,
    );
    // 并排时分隔条起始放在让两幅画都尽量大的位置，不一定在正中。
    final initial = tester.getSemantics(divider).getSemanticsData().value;
    expect(initial, endsWith('%'));
    await tester.drag(divider, const Offset(120, 0));
    await tester.pump();
    expect(
      tester.getSemantics(divider).getSemanticsData().value,
      isNot(initial),
    );
    await tester.tap(find.text('滑动'));
    await tester.pump();
    expect(divider, findsOneWidget);

    // 默认锁定；锁定是开关，提示跟着变。
    final lock = find.bySemanticsLabel('锁定两侧');
    expect(lock, findsOneWidget);
    expect(find.textContaining('两张图一起缩放'), findsOneWidget);
    await tester.tap(find.text('并排'));
    await tester.pump();
    expect(find.textContaining('已锁定'), findsOneWidget);
    await tester.tap(lock);
    await tester.pump();
    expect(find.textContaining('未锁定'), findsOneWidget);
    expect(
      tester.getSemantics(lock),
      isSemantics(hasToggledState: true, isToggled: false),
    );

    await tester.tap(find.text('叠加'));
    await tester.pump();
    expect(find.bySemanticsLabel('上层不透明度'), findsOneWidget);
    expect(find.textContaining('上层'), findsWidgets);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('原卷对照样图：同高并排、锁定缩放与复位', (tester) async {
    await _pump(
      tester,
      const StudentStudyView(args: StudyCenterArgs(examId: '26')),
      account: DemoAccounts.student,
    );
    await tester.tap(find.text('素描'));
    await _settle(tester);
    await tester.tap(find.text('对照样图'));
    await _settle(tester);
    expect(find.text('我的原卷'), findsOneWidget);
    expect(find.textContaining('档样图'), findsOneWidget);
    expect(find.bySemanticsLabel('对比分隔线'), findsOneWidget);
    expect(find.bySemanticsLabel('锁定两侧'), findsOneWidget);
    // 原卷对照只有并排，不显示并排 / 滑动 / 叠加的切换。
    expect(find.text('叠加'), findsNothing);
    final boxes = find.byType(AppCompareZoomBox);
    expect(boxes, findsNWidgets(2));
    expect(
      tester.getSize(boxes.first).height,
      moreOrLessEquals(tester.getSize(boxes.last).height),
    );

    final mine = tester.getCenter(boxes.first);
    await tester.tapAt(mine);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(mine);
    await _settle(tester);
    // 锁定时放大一张，样图跟着放大。
    final transforms = find.descendant(
      of: find.byType(AppCompareView),
      matching: find.byType(InteractiveViewer),
    );
    for (final element in transforms.evaluate()) {
      final viewer = element.widget as InteractiveViewer;
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        moreOrLessEquals(AppCompareController.doubleTapScale),
      );
    }
    await tester.tap(find.bySemanticsLabel('复位缩放和摆放'));
    await _settle(tester);
    for (final element in transforms.evaluate()) {
      final viewer = element.widget as InteractiveViewer;
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        moreOrLessEquals(1),
      );
    }
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('关闭原卷'));
    await _settle(tester);
    await _unmount(tester);
  });

  testWidgets('作品对比范画：页头、名称在画上方、换范画', (tester) async {
    await _pump(
      tester,
      const StudentArtworksView(),
      account: DemoAccounts.student,
    );
    await tester.scrollUntilVisible(
      find.text('石膏头像结构练习'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await _settle(tester);
    await tester.tap(find.text('石膏头像结构练习'));
    await _settle(tester);
    await tester.tap(find.text('对比范画'));
    await _settle(tester);
    expect(
      find.descendant(
        of: find.byType(AppTitleBar),
        matching: find.text('对比范画'),
      ),
      findsOneWidget,
    );
    expect(find.text('我的作品'), findsOneWidget);
    expect(
      ModalRoute.of(tester.element(find.byType(AppCompareView)))?.settings.name,
      imageCompareRouteName,
    );
    expect(find.text('范画 · 素描'), findsOneWidget);
    expect(find.text('换一张范画'), findsOneWidget);
    expect(find.text('叠加'), findsOneWidget);
    expect(find.bySemanticsLabel('锁定两侧'), findsOneWidget);
    final boxes = find.byType(AppCompareZoomBox);
    expect(boxes, findsNWidgets(2));
    expect(
      tester.getBottomLeft(find.text('我的作品')).dy,
      lessThanOrEqualTo(tester.getTopLeft(boxes.first).dy),
    );
    await tester.tap(find.bySemanticsLabel('换一张范画第 2 张'));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('关闭对比'));
    await _settle(tester);
    expect(find.text('对比范画'), findsOneWidget);
    await _unmount(tester);
  });
}
