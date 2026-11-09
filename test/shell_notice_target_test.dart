import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/app/router/route_paths.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_artwork_data.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_backend.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_clock.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_store.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/content_ebooks.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/marking_artwork_fixtures.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/platform_core_fixtures.dart';
import 'package:the_road_of_art_flutter/core/network/api_response.dart';
import 'package:the_road_of_art_flutter/core/providers/app_providers.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:the_road_of_art_flutter/features/shell/data/shell_repository.dart';
import 'package:the_road_of_art_flutter/features/shell/navigation/shell_notice_routes.dart';
import 'package:the_road_of_art_flutter/features/shell/state/shell_controller.dart';
import 'package:the_road_of_art_flutter/features/shell/state/shell_state.dart';
import 'package:the_road_of_art_flutter/features/shell/ui/widgets/shell_notice_drawer.dart';
import 'package:the_road_of_art_flutter/features/shell/ui/widgets/shell_top_bar.dart';

ShellNoticeItem _item(int type, [String targetId = '']) => ShellNoticeItem(
  id: 1,
  targetType: type,
  targetId: targetId,
  content: '',
  createTime: '',
);

class _FakeShellRepository implements ShellRepository {
  final marked = <List<int>>[];

  @override
  Future<ApiResponse> getMyInfo() async => const ApiResponse(
    code: 0,
    msg: 'ok',
    data: {
      'user': {'id': '1', 'role': 'student', 'vipExpireDate': '2099-01-01'},
    },
  );

  @override
  Future<ApiResponse> getSchoolInfo() async =>
      const ApiResponse(code: 0, msg: 'ok', data: <Object>[]);

  @override
  Future<ApiResponse> getUnreadCount() async =>
      const ApiResponse(code: 0, msg: 'ok', data: {'unReadMsgCount': 2});

  @override
  Future<ApiResponse> getMessageList() async => const ApiResponse(
    code: 0,
    msg: 'ok',
    data: {
      'records': [
        {
          'id': 11,
          'targetType': 2,
          'targetId': 'aw-1006',
          'content': '【作品】点评完成',
          'createTime': '2026-11-06 09:12:00',
          'read': false,
        },
        {
          'id': 12,
          'targetType': 1,
          'targetId': '26',
          'content': '【学情】原卷上线',
          'createTime': '2026-11-06 08:40:00',
          'readStatus': 0,
        },
        {
          'id': 13,
          'targetType': 4,
          'targetId': 'eb-monthly-202611',
          'content': '【书刊】上新',
          'createTime': '2026-11-01 10:02:00',
          'readStatus': 1,
        },
      ],
    },
  );

  @override
  Future<ApiResponse> markRead(List<int> ids) async {
    marked.add(ids);
    return const ApiResponse(code: 0, msg: 'ok', data: true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('notice target mapping', () {
    void expectTarget(
      ShellNoticeItem item,
      String route, [
      Map<String, dynamic>? arguments,
    ]) {
      final destination = shellNoticeDestination(item);
      expect(destination, isNotNull);
      expect(destination!.route, route);
      expect(destination.arguments, arguments);
    }

    test('each target type opens its page with the right argument', () {
      expectTarget(
        _item(ShellNoticeTargetType.study, '26'),
        RoutePaths.studyCenter,
        {'examId': '26'},
      );
      expectTarget(
        _item(ShellNoticeTargetType.artwork, 'aw-1006'),
        RoutePaths.artworks,
        {'artworkId': 'aw-1006'},
      );
      expectTarget(
        _item(ShellNoticeTargetType.ebook, 'eb-monthly-202611'),
        RoutePaths.ebooks,
        {'bookId': 'eb-monthly-202611'},
      );
      expectTarget(_item(ShellNoticeTargetType.campus), RoutePaths.smartCampus);
      expectTarget(
        _item(ShellNoticeTargetType.toolbox, 'score'),
        RoutePaths.artToolbox,
        {'tool': 'score'},
      );
    });

    test(
      'an empty target id opens the module itself; system notices go nowhere',
      () {
        expectTarget(
          _item(ShellNoticeTargetType.study),
          RoutePaths.studyCenter,
        );
        expect(
          shellNoticeDestination(_item(ShellNoticeTargetType.system)),
          isNull,
        );
        expect(shellNoticeDestination(_item(99, 'x')), isNull);
      },
    );

    test('category falls back to the target type', () {
      expect(parseShellNotice(_item(ShellNoticeTargetType.ebook)).kind, '书刊');
      expect(parseShellNotice(_item(ShellNoticeTargetType.campus)).kind, '校园');
      expect(parseShellNotice(_item(ShellNoticeTargetType.system)).kind, '通知');
    });
  });

  group('demo notices', () {
    late DemoRouter platform;
    late DemoRouter marking;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await DemoStore.init();
      await DemoStore.reset();
      platform = DemoRouter('notice-test-platform');
      marking = DemoRouter('notice-test-marking');
      registerPlatformCoreFixtures(platform);
      registerEbookFixtures(platform);
      registerMarkingArtworkFixtures(marking);
    });

    Future<Object?> call(
      DemoRouter router,
      String method,
      String path,
      DemoAccount account, {
      Object? body,
      Map<String, dynamic> query = const <String, dynamic>{},
    }) async {
      final match = router.match(method, path);
      expect(match, isNotNull, reason: path);
      return match!.handler(
        DemoRequest(
          method: method,
          path: path,
          query: query,
          body: body,
          headers: <String, dynamic>{'app-token': account.token},
          pathParams: match.params,
        ),
      );
    }

    Future<List<Map>> notices(DemoAccount account) async =>
        (await call(platform, 'POST', '/app/msg/list', account) as List)
            .cast<Map>();

    Map? byType(List<Map> list, int type) =>
        list.where((n) => n['targetType'] == type).firstOrNull;

    test(
      'student notices point at the same artwork, exam and book as the demo data',
      () async {
        final list = await notices(DemoAccounts.student);
        final artwork = byType(list, ShellNoticeTargetType.artwork)!;
        final work = DemoArtworkData.seedWorks().firstWhere(
          (w) => w['personIndex'] == 1 && w['title'] == '石膏头像结构练习',
        );
        expect(artwork['targetId'], work['id']);
        expect(artwork['content'], contains('《石膏头像结构练习》'));
        expect(artwork['content'], contains('李静老师'));
        // 消息在最后一位老师点评（11-06 09:10）之后。
        expect(artwork['createTime'], '2026-11-06 09:12:00');

        expect(byType(list, ShellNoticeTargetType.study)!['targetId'], '26');

        final books =
            await call(
                  platform,
                  'GET',
                  '/app/ebooks',
                  DemoAccounts.student,
                  query: {'sort': 'latest', 'size': 1},
                )
                as Map;
        final newest = (books['records'] as List).first as Map;
        final ebook = byType(list, ShellNoticeTargetType.ebook)!;
        expect(ebook['targetId'], newest['id']);
        expect(ebook['content'], contains('${newest['title']}'));

        expect(byType(list, ShellNoticeTargetType.campus), isNotNull);
        expect(
          byType(list, ShellNoticeTargetType.toolbox)!['targetId'],
          'score',
        );
        for (final notice in list) {
          final shown = parseShellNotice(
            ShellNoticeItem(
              id: notice['id'] as int,
              targetType: notice['targetType'] as int,
              targetId: '${notice['targetId']}',
              content: '${notice['content']}',
              createTime: '${notice['createTime']}',
            ),
          );
          expect(shown.body, isNot(contains('！')));
          expect(shown.body, isNot(contains('!')));
          final time = DateTime.parse(
            '${notice['createTime']}'.replaceFirst(' ', 'T'),
          );
          expect(
            time.isAfter(DemoClock.now()),
            isFalse,
            reason: '${notice['content']}',
          );
        }
        final times = [for (final n in list) '${n['createTime']}'];
        expect(times, [...times]..sort((a, b) => b.compareTo(a)));
      },
    );

    test(
      'teacher notice names the newest pending work and the real queue size',
      () async {
        final list = await notices(DemoAccounts.teacher);
        final artwork = byType(list, ShellNoticeTargetType.artwork)!;
        final stats =
            await call(
                  marking,
                  'GET',
                  '/school/teacher/artworks/statistics',
                  DemoAccounts.teacher,
                )
                as Map;
        expect(artwork['content'], contains('你还有 ${stats['pending']} 件作品待点评'));
        final work = DemoArtworkData.seedWorks().firstWhere(
          (w) => w['id'] == artwork['targetId'],
        );
        expect(DemoArtworkData.teacherIdsOf(work), contains('t-1'));
        expect(DemoArtworkData.reviewOf(work, 't-1'), isNull);
        expect(artwork['content'], contains('《${work['title']}》'));
      },
    );

    test(
      'dorm managers get campus and book notices only, with the configured check time',
      () async {
        final list = await notices(DemoAccounts.dormManager);
        expect(byType(list, ShellNoticeTargetType.study), isNull);
        expect(byType(list, ShellNoticeTargetType.artwork), isNull);
        final config =
            await call(
                  platform,
                  'POST',
                  '/app/school/v2/user/schoolConfigList',
                  DemoAccounts.dormManager,
                )
                as List;
        final evening = config.cast<Map>().firstWhere(
          (c) => c['configKey'] == 'dormitoryNightCheckTime',
        )['configValue'];
        expect(
          byType(list, ShellNoticeTargetType.campus)!['content'],
          contains('$evening 截止'),
        );
      },
    );

    test('every role gets targeted, compliant notices', () async {
      final banned = RegExp(
        r'最好|最佳|最大|唯一|首选|保证|绝对|永久|保过|提分|涨分|上岸|\bAI\b|人工智能|[!！]',
      );
      for (final account in DemoAccounts.all) {
        final list = await notices(account);
        expect(list, isNotEmpty, reason: account.name);
        for (final notice in list) {
          expect(
            banned.hasMatch('${notice['content']}'),
            isFalse,
            reason: '${notice['content']}',
          );
          final item = ShellNoticeItem(
            id: notice['id'] as int,
            targetType: notice['targetType'] as int,
            targetId: '${notice['targetId']}',
            content: '${notice['content']}',
            createTime: '${notice['createTime']}',
          );
          expect(shellNoticeDestination(item), isNotNull, reason: item.content);
        }
      }
    });

    test('updateRead marks only the given ids', () async {
      const account = DemoAccounts.student;
      Future<int> unread() async =>
          ((await call(platform, 'POST', '/app/msg/getUnReadMsgCount', account)
                  as Map)['unReadMsgCount']
              as int);
      final before = await unread();
      expect(before, greaterThan(1));
      final first = (await notices(
        account,
      )).firstWhere((n) => n['read'] != true);
      await call(
        platform,
        'POST',
        '/app/msg/updateRead',
        account,
        body: {
          'ids': [first['id']],
        },
      );
      expect(await unread(), before - 1);
      final again = (await notices(
        account,
      )).firstWhere((n) => n['id'] == first['id']);
      expect(again['read'], isTrue);

      await call(
        platform,
        'POST',
        '/app/msg/updateRead',
        account,
        body: {'ids': <int>[]},
      );
      expect(await unread(), 0);
    });
  });

  group('ShellController', () {
    test('parses targets and read state, marks one notice read', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'token': DemoAccounts.student.token,
      });
      final prefs = await SharedPreferences.getInstance();
      final repository = _FakeShellRepository();
      final container = ProviderContainer(
        overrides: [
          appStorageProvider.overrideWithValue(AppStorage(prefs)),
          shellRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(shellControllerProvider.notifier);
      // 等构造时的首轮拉取（资料 + 消息）结束，避免与下面的操作交错。
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await controller.refreshNoticeData();

      var state = container.read(shellControllerProvider);
      expect(state.unreadCount, 2);
      expect(state.noticeItems.map((n) => n.targetId), [
        'aw-1006',
        '26',
        'eb-monthly-202611',
      ]);
      expect(state.noticeItems.map((n) => n.read), [false, false, true]);

      await controller.markNoticeRead(11);
      state = container.read(shellControllerProvider);
      expect(state.unreadCount, 1);
      expect(state.noticeItems.first.read, isTrue);
      expect(repository.marked.last, [11]);

      await controller.markNoticeRead(11);
      expect(repository.marked.where((ids) => ids.contains(11)), hasLength(1));

      await controller.markAllNoticeRead();
      state = container.read(shellControllerProvider);
      expect(state.unreadCount, 0);
      expect(state.noticeItems, hasLength(3));
      expect(state.noticeItems.every((n) => n.read), isTrue);
      expect(repository.marked.last, [12]);
    });
  });

  group('notice drawer', () {
    testWidgets('tapping a notice closes the drawer and opens it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1180, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      ShellNoticeItem? opened;
      const items = [
        ShellNoticeItem(
          id: 1,
          targetType: ShellNoticeTargetType.artwork,
          targetId: 'aw-1006',
          content: '【作品】李静老师点评了你的《石膏头像结构练习》',
          createTime: '2026-11-06 09:12:00',
        ),
        ShellNoticeItem(
          id: 2,
          targetType: ShellNoticeTargetType.ebook,
          targetId: 'eb-monthly-202611',
          content: '【书刊】画室月刊上新',
          createTime: '2026-11-01 10:02:00',
          read: true,
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => AppButton(
                label: '打开通知',
                onTap: () => showShellNoticeDrawer(
                  context,
                  items: items,
                  unreadCount: 1,
                  onMarkAllRead: () async {},
                  onOpen: (item) => opened = item,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开通知'));
      await tester.pumpAndSettle();
      expect(find.text('通知(2)'), findsOneWidget);
      expect(find.text('批量已读'), findsOneWidget);

      await tester.tap(find.textContaining('石膏头像结构练习'));
      await tester.pumpAndSettle();
      expect(opened?.targetId, 'aw-1006');
      expect(find.byType(AppDrawer), findsNothing);
    });

    testWidgets('top bar keeps the reference controls without extra labels', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1180, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 950,
                  child: ShellTopBar(
                    state: ShellState(
                      navItems: buildDefaultNavItems(
                        schoolCoursewareEnabled: false,
                      ),
                    ),
                    onNavigate: (_) {},
                    onLogout: () async {},
                    onMarkAllRead: () async {},
                    onLoadProvinces: () async =>
                        (provinces: const <String>[], error: null),
                    onUpdateProvince: (_) async => null,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('演示版'), findsNothing);
      for (final label in ['帮助', '通知', '设置']) {
        final button = find.byWidgetPredicate(
          (w) => w is AppIconButton && w.semanticLabel == label,
        );
        expect(
          tester.getSize(button).width,
          greaterThanOrEqualTo(40),
          reason: label,
        );
        expect(
          tester.getSize(button).height,
          greaterThanOrEqualTo(40),
          reason: label,
        );
      }
    });
  });
}
