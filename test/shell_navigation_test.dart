import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/app/router/route_paths.dart';
import 'package:the_road_of_art_flutter/core/constants/app_assets.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:the_road_of_art_flutter/core/widgets/app_asset_graphic.dart';
import 'package:the_road_of_art_flutter/features/shell/navigation/shell_nav_routes.dart';
import 'package:the_road_of_art_flutter/features/shell/state/shell_state.dart';
import 'package:the_road_of_art_flutter/features/shell/ui/widgets/shell_left_nav.dart';
import 'package:the_road_of_art_flutter/features/shell/ui/widgets/shell_notice_drawer.dart';
import 'package:the_road_of_art_flutter/features/shell/ui/widgets/shell_top_bar.dart';

ShellState _state({bool collapsed = false, int unread = 0}) {
  return ShellState(
    navItems: buildDefaultNavItems(schoolCoursewareEnabled: true),
    footerNavItem: buildFeedbackFooterNavItem(),
    collapsed: collapsed,
    unreadCount: unread,
    user: const ShellUser(nickname: '林小雨', identity: '学生', province: '甘肃'),
    noticeItems: [
      if (unread > 0)
        const ShellNoticeItem(
          id: 1,
          targetType: 1,
          content: '【学情】9 月月考的原卷与评分标准已上线',
          createTime: '2026-11-06 18:20:00',
        ),
    ],
  );
}

void main() {
  group('shellActiveNavIndex', () {
    final routes = [
      for (final item in buildDefaultNavItems(schoolCoursewareEnabled: true))
        item.route,
    ];
    int indexOf(String route) => routes.indexOf(route);

    test('nav roots highlight themselves', () {
      expect(shellActiveNavIndex(routes, RoutePaths.home), 0);
      expect(
        shellActiveNavIndex(routes, RoutePaths.gallery),
        indexOf(RoutePaths.gallery),
      );
      expect(
        shellActiveNavIndex(routes, '/smart-campus/sign-records'),
        indexOf(RoutePaths.smartCampus),
      );
    });

    test('sub pages highlight the one nav item they belong to', () {
      expect(
        shellActiveNavIndex(routes, RoutePaths.circle),
        indexOf(RoutePaths.smartCampus),
      );
      expect(
        shellActiveNavIndex(routes, RoutePaths.info),
        indexOf(RoutePaths.personalCenter),
      );
      expect(
        shellActiveNavIndex(routes, RoutePaths.qrcode),
        indexOf(RoutePaths.personalCenter),
      );
      expect(
        shellActiveNavIndex(routes, RoutePaths.schoolWebsite),
        indexOf(RoutePaths.school),
      );
    });

    test('global pages highlight nothing', () {
      for (final route in [
        RoutePaths.helpGuide,
        RoutePaths.consultation,
        RoutePaths.consultationDetail,
        RoutePaths.camp,
        RoutePaths.designSystem,
        '/unknown-page',
      ]) {
        expect(shellActiveNavIndex(routes, route), -1, reason: route);
      }
    });

    test('school sub pages highlight nothing when the school nav is off', () {
      final withoutSchool = [
        for (final item in buildDefaultNavItems(schoolCoursewareEnabled: false))
          item.route,
      ];
      expect(shellActiveNavIndex(withoutSchool, RoutePaths.schoolWebsite), -1);
    });

    test('feedback pages belong to the footer link', () {
      expect(shellNavOwnerOf(RoutePaths.fankui), RoutePaths.helpFeedback);
      expect(shellNavOwnerOf(RoutePaths.helpFeedback), RoutePaths.helpFeedback);
    });
  });

  test('dorm managers do not get grade and artwork navigation', () {
    final routes = [
      for (final item in buildDefaultNavItems(
        schoolCoursewareEnabled: true,
        isStaff: true,
        role: 'dormManager',
      ))
        item.route,
    ];
    expect(routes, isNot(contains(RoutePaths.studyCenter)));
    expect(routes, isNot(contains(RoutePaths.artworks)));
    expect(routes, contains(RoutePaths.smartCampus));
    final teacher = buildDefaultNavItems(
      schoolCoursewareEnabled: true,
      isStaff: true,
      role: 'teacher',
    ).map((item) => item.label);
    expect(teacher, containsAll(['班级学情', '作品点评']));
  });

  test('小美同学 uses the original navigation icon', () {
    final ai = buildDefaultNavItems(
      schoolCoursewareEnabled: false,
    ).firstWhere((item) => item.route == RoutePaths.personalAi);
    expect(ai.label, '小美同学');
    expect(ai.icon, AppAssets.leftNavAi);
    expect(ai.iconData, isNull);
  });

  group('ShellLeftNav', () {
    Future<void> pumpNav(
      WidgetTester tester, {
      required String route,
      bool collapsed = false,
      double height = 820,
      VoidCallback? onToggle,
      ValueChanged<String>? onNavigate,
    }) async {
      tester.view.physicalSize = Size(1180, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: collapsed ? 56 : 178,
              height: height,
              child: ShellLeftNav(
                state: _state(collapsed: collapsed),
                currentRoute: route,
                onToggleCollapse: onToggle ?? () {},
                onNavigate: onNavigate ?? (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Color? tileColorOf(WidgetTester tester, String label) {
      final container = tester.widget<Container>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Container))
            .first,
      );
      return (container.decoration as BoxDecoration?)?.color;
    }

    testWidgets('only the current item uses the original navy fill', (
      tester,
    ) async {
      await pumpNav(tester, route: RoutePaths.gallery);
      expect(tileColorOf(tester, '范画库'), AppColors.navSelection);
      expect(tileColorOf(tester, '首页'), isNull);
      expect(tileColorOf(tester, '智慧校园'), isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('help page highlights nothing', (tester) async {
      await pumpNav(tester, route: RoutePaths.helpGuide);
      for (final item in _state().navItems) {
        expect(tileColorOf(tester, item.label), isNull, reason: item.label);
      }
    });

    testWidgets(
      'a lower navigation destination is revealed on narrow screens',
      (tester) async {
        await pumpNav(tester, route: RoutePaths.personalCenter, height: 650);
        expect(find.text('个人中心').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('feedback link and collapse button live in the footer', (
      tester,
    ) async {
      var toggles = 0;
      String? opened;
      await pumpNav(
        tester,
        route: RoutePaths.home,
        onToggle: () => toggles++,
        onNavigate: (route) => opened = route,
      );
      final feedback = tester.widget<Text>(find.text('意见反馈'));
      expect(feedback.style?.color, AppColors.textTertiary);
      await tester.tap(find.text('意见反馈'));
      expect(opened, RoutePaths.helpFeedback);
      await tester.tap(find.byIcon(Icons.keyboard_double_arrow_left_rounded));
      expect(toggles, 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('collapsed nav keeps labels for screen readers', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpNav(tester, route: RoutePaths.home, collapsed: true);
      expect(find.text('首页'), findsNothing);
      expect(find.bySemanticsLabel('首页'), findsOneWidget);
      expect(find.bySemanticsLabel('展开导航'), findsOneWidget);
      semantics.dispose();
      expect(tester.takeException(), isNull);
    });

    testWidgets('footer icon targets are at least 40 × 40', (tester) async {
      for (final collapsed in [false, true]) {
        await pumpNav(tester, route: RoutePaths.home, collapsed: collapsed);
        final toggle = tester.getSize(find.byType(AppIconButton));
        expect(toggle.width, greaterThanOrEqualTo(40));
        expect(toggle.height, greaterThanOrEqualTo(40));
        final feedback = tester.getSize(
          find
              .ancestor(
                of: find.byType(AppAssetGraphic).last,
                matching: find.byType(AppPressable),
              )
              .first,
        );
        expect(feedback.height, greaterThanOrEqualTo(40), reason: '$collapsed');
        expect(feedback.width, greaterThanOrEqualTo(40), reason: '$collapsed');
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('ShellTopBar', () {
    Future<void> pumpBar(WidgetTester tester, {int unread = 0}) async {
      tester.view.physicalSize = const Size(1180, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: 950,
                    child: ShellTopBar(
                      state: _state(unread: unread),
                      onNavigate: (_) {},
                      onLogout: () async {},
                      onMarkAllRead: () async {},
                      onLoadProvinces: () async =>
                          (provinces: const <String>['甘肃'], error: null),
                      onUpdateProvince: (_) async => null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('icon buttons have names for screen readers and QA', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpBar(tester, unread: 1);
      expect(find.bySemanticsLabel('帮助'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^通知')), findsOneWidget);
      expect(find.bySemanticsLabel('设置'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^账户菜单')), findsOneWidget);
      semantics.dispose();
      expect(find.text('搜索范画、书刊、资讯、视频、笔记'), findsOneWidget);
      expect(find.byType(AppBadge), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('bell opens the notice drawer with a category tag', (
      tester,
    ) async {
      await pumpBar(tester, unread: 1);
      await tester.tap(find.byTooltip('通知'));
      await tester.pumpAndSettle();
      expect(find.byType(AppDrawer), findsOneWidget);
      expect(find.text('1 条未读 · 学情、作品点评与系统消息'), findsOneWidget);
      expect(find.widgetWithText(AppTag, '学情'), findsOneWidget);
      expect(find.text('9 月月考的原卷与评分标准已上线'), findsOneWidget);
      expect(find.text('班级与学校通知请到「智慧校园」查看'), findsOneWidget);
    });

    testWidgets('account menu lists region, profile and logout', (
      tester,
    ) async {
      await pumpBar(tester);
      await tester.tap(find.text('林小雨'));
      await tester.pumpAndSettle();
      expect(find.text('所在地区'), findsOneWidget);
      expect(find.text('甘肃'), findsOneWidget);
      expect(find.text('个人信息'), findsOneWidget);
      expect(find.text('退出登录'), findsOneWidget);
    });
  });

  group('notice helpers', () {
    test('category comes from the 【】 prefix', () {
      final notice = parseShellNotice(
        const ShellNoticeItem(
          id: 1,
          targetType: 2,
          content: '【作品】李静老师点评了你的作品',
          createTime: '',
        ),
      );
      expect(notice.kind, '作品');
      expect(notice.body, '李静老师点评了你的作品');
      expect(
        parseShellNotice(
          const ShellNoticeItem(
            id: 2,
            targetType: 1,
            content: '月考成绩已发布',
            createTime: '',
          ),
        ).kind,
        '学情',
      );
    });

    test('times drop seconds and use today / yesterday', () {
      final now = DateTime(2026, 11, 7, 10);
      expect(formatShellNoticeTime('2026-11-07 07:20:45', now), '今天 07:20');
      expect(formatShellNoticeTime('2026-11-06 21:00:00', now), '昨天 21:00');
      expect(formatShellNoticeTime('2026-11-01 09:05:30', now), '11-01 09:05');
      expect(
        formatShellNoticeTime('2025-12-30 08:00:00', now),
        '2025-12-30 08:00',
      );
      expect(formatShellNoticeTime('刚刚', now), '刚刚');
    });
  });
}
