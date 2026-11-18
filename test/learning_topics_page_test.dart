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
import 'package:the_road_of_art_flutter/features/creative_hub/ui/learning_topics_page.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> mountTopics(WidgetTester tester, DemoAccount account) async {
  SharedPreferences.setMockInitialValues({'token': account.token});
  final prefs = await SharedPreferences.getInstance();
  await DemoStore.init();
  await DemoStore.reset();
  tester.view.physicalSize = const Size(950, 680);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appStorageProvider.overrideWithValue(AppStorage(prefs))],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: LearningTopicsPage()),
      ),
    ),
  );
  await settle(tester);
}

Finder primaryButton(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(AppButton));

void main() {
  setUpAll(registerDemoFixtures);

  testWidgets('students read first: adding courseware is a secondary action', (
    tester,
  ) async {
    await mountTopics(tester, DemoAccounts.student);
    expect(find.text('优秀课件'), findsOneWidget);
    expect(find.text('新增课件'), findsOneWidget);
    expect(primaryButton('新增课件'), findsNothing);
    expect(find.textContaining('小课件'), findsNothing);
    expect(find.textContaining('专题'), findsNothing);
  });

  testWidgets('staff get 新增课件 as the one primary action', (tester) async {
    await mountTopics(tester, DemoAccounts.teacher);
    expect(primaryButton('新增课件'), findsOneWidget);
    expect(find.byType(AppButton), findsOneWidget);
  });

  testWidgets('subject filter, saved view and favorite from the detail', (
    tester,
  ) async {
    await mountTopics(tester, DemoAccounts.student);
    await tester.tap(find.text('色彩').first);
    await settle(tester);
    expect(find.text('一组静物，建立统一的色调'), findsOneWidget);
    expect(find.text('把明暗交界线画进体积里'), findsNothing);

    await tester.tap(find.text('我的收藏'));
    await settle(tester);
    expect(find.text('还没有收藏的课件'), findsOneWidget);

    await tester.tap(find.text('去看全部课件'));
    await settle(tester);
    await tester.tap(find.text('一组静物，建立统一的色调'));
    await settle(tester);
    expect(find.text('阅读资料'), findsOneWidget);
    expect(find.text('开始阅读'), findsOneWidget);
    await tester.tap(find.text('收藏'));
    await settle(tester);
    expect(find.text('已收藏'), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await settle(tester);
    await tester.tap(find.text('我的收藏'));
    await settle(tester);
    expect(find.text('一组静物，建立统一的色调'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('form marks each problem and publishes into 我的发布', (
    tester,
  ) async {
    await mountTopics(tester, DemoAccounts.student);
    await tester.tap(find.text('新增课件'));
    await settle(tester);
    await tester.tap(find.text('发布课件'));
    await settle(tester);
    expect(find.text('课件名称须为 2 至 40 个字'), findsOneWidget);
    expect(find.text('学习说明须为 10 至 600 个字'), findsOneWidget);
    expect(find.text('请至少选择 1 份阅读资料'), findsOneWidget);
    expect(find.text('还有 3 处需要填写，已在下方标出'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).at(0), '明暗关系阅读练习');
    await tester.enterText(
      find.byType(EditableText).at(2),
      '通过图文对照观察明暗关系与形体转折。',
    );
    await settle(tester);
    expect(find.textContaining('课件名称须为'), findsNothing);
    expect(find.text('还有 1 处需要填写，已在下方标出'), findsOneWidget);

    final pick = find.bySemanticsLabel('选择联考素描静物高分解析（示例） · PDF');
    await tester.ensureVisible(pick);
    await tester.tap(pick);
    await settle(tester);
    expect(find.textContaining('第 1 份，作为封面'), findsOneWidget);

    await tester.tap(find.text('发布课件'));
    await settle(tester);
    expect(find.text('明暗关系阅读练习'), findsOneWidget);
    expect(find.text('课件内容'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving a filled form asks first', (tester) async {
    await mountTopics(tester, DemoAccounts.student);
    await tester.tap(find.text('新增课件'));
    await settle(tester);
    await tester.enterText(find.byType(EditableText).first, '冷暖对比');
    await tester.tap(find.byTooltip('返回'));
    await settle(tester);
    expect(find.text('放弃这份课件？'), findsOneWidget);
    await tester.tap(find.text('继续编辑'));
    await settle(tester);
    expect(find.text('课件内容'), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await settle(tester);
    await tester.tap(find.text('放弃'));
    await settle(tester);
    expect(find.text('全部课件'), findsOneWidget);
  });
}
