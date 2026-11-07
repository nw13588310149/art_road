// 校圈与校圈治理：举报数据与管理员工作台同源、处理结果落盘、治理页签与操作、
// 普通校圈不出现治理入口、操作图标颜色。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_backend.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_store.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/campus/campus_b_registry.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/interaction_circle.dart';
import 'package:the_road_of_art_flutter/core/providers/app_providers.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';
import 'package:the_road_of_art_flutter/core/theme/app_theme.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:the_road_of_art_flutter/features/circle/state/circle_governance_state.dart';
import 'package:the_road_of_art_flutter/features/circle/state/circle_permissions_provider.dart';
import 'package:the_road_of_art_flutter/features/circle/state/circle_state.dart';
import 'package:the_road_of_art_flutter/features/circle/ui/circle_page.dart';
import 'package:the_road_of_art_flutter/features/circle/ui/widgets/circle_action_buttons.dart';
import 'package:the_road_of_art_flutter/features/circle/ui/widgets/circle_governance_view.dart';
import 'package:the_road_of_art_flutter/features/circle/ui/widgets/circle_post_card.dart';

const _ghostDrawing = '接速写、色彩作业代画，晚自习前交稿，需要的同学私信我。';
const _examRumor = '听说这次月考色彩考风景、速写考场景，已经有人拿到题了，想要的私聊。';
const _studioWall = '画室日常｜作品墙又更新了';
const _milkTea = '校门口新开的奶茶店第二杯半价，报我名字还送小料，晚自习下课一起去。';
const _davidCritique = '本周素描范画讲评：大卫石膏像';
const _ownSketchDiary = '写生日记｜周末跟着刘芳老师去城郊画白杨和土坯房';
const _sketchClassVideo = '晚自习速写课 40 分钟限时';

late SharedPreferences _prefs;

/// 直接调用演示接口（同步处理函数，不经过网络层的模拟延迟）。
Object? _call(
  String path,
  DemoAccount account, [
  Map<String, dynamic> body = const <String, dynamic>{},
]) {
  final match = DemoBackend.platform.match('POST', path);
  expect(match, isNotNull, reason: path);
  final result = match!.handler(
    DemoRequest(
      method: 'POST',
      path: path,
      query: const <String, dynamic>{},
      body: body,
      headers: <String, dynamic>{'app-token': account.token},
      pathParams: match.params,
    ),
  );
  expect(result, isNot(isA<Future<Object?>>()), reason: path);
  return result;
}

int _workbenchCount() =>
    (_call('/app/school/v2/manager/indexSum', DemoAccounts.admin)
            as Map)['postStatus0Count']
        as int;

Map _reportPage([int? status]) =>
    _call('/app/school/v2/manager/postsReportList', DemoAccounts.admin, {
          'size': 50,
          'status': ?status,
        })
        as Map;

List<Map> _records(Map page) => (page['records'] as List).cast<Map>();

List<Map> _circlePosts([DemoAccount account = DemoAccounts.student]) =>
    _records(
      _call('/app/school/v2/posts/postsList', account, {'size': 50}) as Map,
    );

String _postIdOf(String contentPrefix) => _circlePosts()
    .firstWhere((p) => '${p['content']}'.startsWith(contentPrefix))['id']
    .toString();

Map _pendingRecordOf(String contentPrefix) => _records(_reportPage(0))
    .firstWhere((r) => '${r['post']['content']}'.startsWith(contentPrefix));

Matcher _demoError(String message) => throwsA(
  isA<DemoApiException>().having((e) => e.message, 'message', message),
);

bool _ignorable(FlutterErrorDetails details) {
  final text = details.exceptionAsString();
  return details.exception is NetworkImageLoadException ||
      text.contains('HTTP request failed') ||
      text.contains('Unable to load asset') ||
      text.contains('Invalid image data') ||
      text.contains('MissingPluginException') ||
      details.library == 'image resource service';
}

Future<void> _settle(WidgetTester tester, {int steps = 10}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// 以 [account] 身份打开校圈页（1180×820 外壳内容区约 950 宽）。图片在测试
/// 环境加载失败属正常，忽略。
Future<void> _withCirclePage(
  WidgetTester tester,
  DemoAccount account,
  Future<void> Function() body, {
  bool governance = false,
}) async {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (_ignorable(details)) return;
    original?.call(details);
  };
  await _prefs.setString('token', account.token);
  final container = ProviderContainer(
    overrides: [
      appStorageProvider.overrideWithValue(AppStorage(_prefs)),
      circlePermissionsProvider.overrideWithValue(
        CirclePermissions(
          currentUserId: account.userId,
          isAdmin: account.role == DemoRole.admin,
        ),
      ),
    ],
  );
  tester.view.physicalSize = const Size(950, 780);
  tester.view.devicePixelRatio = 1;
  try {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            backgroundColor: AppColors.page,
            body: CirclePage(governance: governance, onBack: () {}),
          ),
        ),
      ),
    );
    await _settle(tester);
    await body();
    // 等轻提示消失、演示接口的模拟延迟走完，再卸载页面。
    await _settle(tester, steps: 15);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await _settle(tester, steps: 5);
  } finally {
    FlutterError.onError = original;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }
}

Finder get _governanceTabs => find.byType(AppTabs<CircleGovernanceTab>);

Finder _tab(String label) =>
    find.descendant(of: _governanceTabs, matching: find.text(label));

Finder _caseCardOf(String text) => find.ancestor(
  of: find.textContaining(text),
  matching: find.byType(CircleReportCaseCard),
);

Finder _inDialog(Finder finder) =>
    find.descendant(of: find.byType(AppDialog), matching: finder);

Finder get _moreButtons => find.byWidgetPredicate(
  (w) => w is AppIconButton && w.semanticLabel == '更多操作',
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _prefs = await SharedPreferences.getInstance();
    await DemoStore.init();
    registerCircleFixtures(DemoBackend.platform);
    registerCampusFixturesPartB(DemoBackend.platform);
  });

  setUp(() async {
    await DemoStore.reset();
  });

  group('report data', () {
    test('the workbench count and 待处理 come from the same reports', () {
      final pending = _reportPage(0);
      expect(_workbenchCount(), 3);
      expect(pending['total'], _workbenchCount());
      expect(circlePendingReportCount(), _workbenchCount());

      final records = _records(pending);
      expect(records.map((r) => r['post']['content']).toList(), [
        _ghostDrawing,
        _examRumor,
        startsWith(_studioWall),
      ]);
      final first = records.first;
      expect(first['reportCount'], 3);
      expect(first['reasons'], [
        {'reason': '代画作业', 'count': 2},
        {'reason': '广告营销', 'count': 1},
      ]);
      expect(first['lastReportTime'], isNotEmpty);
      expect(first['postDeleted'], 0);

      final handled = _records(_reportPage(1));
      expect(handled, hasLength(2));
      final deleted = handled.firstWhere((r) => r['result'] == 2);
      expect(deleted['post']['content'], _milkTea);
      expect(deleted['postDeleted'], 1);
      expect(deleted['handleReason'], '广告营销');
      expect(deleted['handlerName'], '王敏');
      final kept = handled.firstWhere((r) => r['result'] == 1);
      expect('${kept['post']['content']}', startsWith(_sketchClassVideo));
      expect(kept['handleReason'], '举报不成立');
    });

    test('deleting needs a reason, removes the post and survives a reload', () async {
      final record = _pendingRecordOf(_ghostDrawing);
      const handle = '/app/school/v2/manager/postsReportHandle';
      expect(
        () => _call(handle, DemoAccounts.admin, {
          'id': record['id'],
          'result': 2,
        }),
        _demoError('请选择删除原因'),
      );
      expect(
        () => _call(handle, DemoAccounts.admin, {
          'id': record['id'],
          'result': 2,
          'reason': '其他',
        }),
        _demoError('选择「其他」时请写明原因'),
      );

      final result =
          _call(handle, DemoAccounts.admin, {
                'id': record['id'],
                'result': 2,
                'reason': '代画作业',
                'remark': '已请班主任提醒',
              })
              as Map;
      expect(result['status'], 1);
      expect(result['result'], 2);
      expect(result['handleReason'], '代画作业');
      expect(result['handleRemark'], '已请班主任提醒');
      expect(result['post']['content'], _ghostDrawing);
      expect(
        _circlePosts().where((p) => p['content'] == _ghostDrawing),
        isEmpty,
      );
      expect(_workbenchCount(), 2);
      expect(
        () => _call(handle, DemoAccounts.admin, {
          'id': record['id'],
          'result': 1,
        }),
        _demoError('这条举报已经处理过了'),
      );

      // 模拟重启：内存清空，只剩本机落盘的数据。
      final saved = {
        for (final key in [
          'demo_store:circle:reports',
          'demo_store:circle:posts',
          'demo_store:circle:comments',
        ])
          key: _prefs.getString(key),
      };
      expect(saved.values, everyElement(isNotNull));
      await DemoStore.reset();
      for (final entry in saved.entries) {
        await _prefs.setString(entry.key, entry.value!);
      }
      expect(_workbenchCount(), 2);
      final handled = _records(_reportPage(1));
      final restored = handled.firstWhere((r) => r['id'] == record['id']);
      expect(restored['result'], 2);
      expect(restored['handleReason'], '代画作业');
      expect(
        _circlePosts().where((p) => p['content'] == _ghostDrawing),
        isEmpty,
      );
    });

    test('keeping closes the report and leaves the post in the circle', () {
      final record = _pendingRecordOf(_studioWall);
      final result =
          _call('/app/school/v2/manager/postsReportHandle', DemoAccounts.admin, {
                'id': record['id'],
                'result': 1,
              })
              as Map;
      expect(result['result'], 1);
      expect(result['handleReason'], '举报不成立');
      expect(_workbenchCount(), 2);
      expect(
        _circlePosts().where((p) => '${p['content']}'.startsWith(_studioWall)),
        hasLength(1),
      );
      final persisted =
          jsonDecode(_prefs.getString('demo_store:circle:reports')!) as List;
      expect(
        persisted.firstWhere((r) => r['id'] == record['id'])['status'],
        1,
      );
    });

    test('only admins can list or handle reports', () {
      expect(
        () => _call(
          '/app/school/v2/manager/postsReportList',
          DemoAccounts.student,
        ),
        _demoError('只有管理员可以处理校圈举报'),
      );
      expect(
        () => _call(
          '/app/school/v2/manager/postsReportHandle',
          DemoAccounts.teacher,
          {'id': _pendingRecordOf(_examRumor)['id'], 'result': 1},
        ),
        _demoError('只有管理员可以处理校圈举报'),
      );
    });

    test('a report lands in 待处理 and raises the workbench count', () {
      const report = '/app/school/v2/posts/postsReport';
      final davidId = _postIdOf(_davidCritique);
      expect(
        () => _call(report, DemoAccounts.student, {
          'postsId': davidId,
          'reason': '其他',
        }),
        _demoError('选择「其他」时请写明原因'),
      );
      expect(
        _call(report, DemoAccounts.student, {
          'postsId': davidId,
          'reason': '与画室学习无关',
        }),
        isTrue,
      );
      expect(_workbenchCount(), 4);
      expect(
        _records(_reportPage(0)).map((r) => r['postsId']),
        contains(davidId),
      );
      expect(
        () => _call(report, DemoAccounts.student, {
          'postsId': davidId,
          'reason': '广告营销',
        }),
        _demoError('你已经举报过这条动态，请等待管理员处理'),
      );
      expect(
        () => _call(report, DemoAccounts.student, {
          'postsId': _postIdOf(_ownSketchDiary),
          'reason': '广告营销',
        }),
        _demoError('不能举报自己发布的动态'),
      );
    });

    test('an author deleting a reported post closes the report', () {
      final videoId = _postIdOf(_sketchClassVideo);
      _call('/app/school/v2/posts/postsReport', DemoAccounts.student, {
        'postsId': videoId,
        'reason': '与画室学习无关',
      });
      expect(_workbenchCount(), 4);
      _call('/app/school/v2/posts/postsDelete', DemoAccounts.headTeacher, {
        'id': videoId,
      });
      expect(_workbenchCount(), 3);
      final closed = _records(_reportPage(1)).firstWhere(
        (r) => r['postsId'] == videoId && r['result'] == 2,
      );
      expect(closed['handleReason'], '作者已自行删除');
    });

    test('deleting an unreported post from 全部动态 is recorded too', () {
      final davidId = _postIdOf(_davidCritique);
      const path = '/app/school/v2/manager/postsDelete';
      expect(
        () => _call(path, DemoAccounts.admin, {'id': davidId}),
        _demoError('请选择删除原因'),
      );
      final record =
          _call(path, DemoAccounts.admin, {
                'id': davidId,
                'reason': '其他',
                'remark': '范画版权待确认',
              })
              as Map;
      expect(record['result'], 2);
      expect(record['reportCount'], 0);
      expect(_circlePosts().map((p) => p['id']), isNot(contains(davidId)));
      expect(_workbenchCount(), 3);
      expect(_reportPage(1)['total'], 3);
    });

    test('赵雪 shows her main role: 班主任 · 速写', () {
      final post = _circlePosts().firstWhere(
        (p) => p['user']['realname'] == '赵雪',
      );
      expect('${post['user']['identity']}', startsWith('班主任 · 速写'));
    });
  });

  group('governance page', () {
    testWidgets('tabs show the same pending count as the workbench, no posting', (
      tester,
    ) async {
      final expected = _workbenchCount();
      await _withCirclePage(tester, DemoAccounts.admin, governance: true, () async {
        expect(find.text('校圈治理'), findsOneWidget);
        expect(find.text('发布动态'), findsNothing);
        expect(_tab('待处理'), findsOneWidget);
        expect(_tab('$expected'), findsOneWidget);
        expect(_tab('已处理'), findsOneWidget);
        expect(_tab('全部动态'), findsOneWidget);
        expect(find.byType(AppSegmented<CircleMode>), findsNothing);

        final first = _caseCardOf(_ghostDrawing);
        expect(first, findsOneWidget);
        expect(
          find.descendant(of: first, matching: find.text('3 人举报')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: first, matching: find.text('代画作业 2')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: first, matching: find.textContaining('最近举报')),
          findsOneWidget,
        );

        await tester.tap(_tab('已处理'));
        await tester.pump();
        expect(find.textContaining(_milkTea), findsOneWidget);
        expect(find.text('删除原因：广告营销'), findsOneWidget);
        expect(find.text('处理结果：举报不成立'), findsOneWidget);

        await tester.tap(_tab('全部动态'));
        await _settle(tester, steps: 3);
        expect(find.byType(CirclePostCard), findsWidgets);
        expect(find.byType(AppSegmented<CircleMode>), findsOneWidget);
        expect(find.text('发布动态'), findsNothing);
        expect(
          _moreButtons.evaluate().length,
          find.byType(CirclePostCard).evaluate().length,
        );
      });
    });

    testWidgets('删除 needs a reason and a danger confirm, then moves to 已处理', (
      tester,
    ) async {
      final before = _workbenchCount();
      await _withCirclePage(tester, DemoAccounts.admin, governance: true, () async {
        await tester.tap(
          find.descendant(
            of: _caseCardOf(_ghostDrawing),
            matching: find.widgetWithText(AppButton, '删除'),
          ),
        );
        await _settle(tester, steps: 2);
        expect(_inDialog(find.text('删除动态')), findsOneWidget);

        await tester.tap(_inDialog(find.widgetWithText(AppButton, '下一步')));
        await tester.pump();
        expect(find.text('请选择删除原因'), findsOneWidget);
        expect(find.text('确定删除这条动态？'), findsNothing);

        await tester.tap(_inDialog(find.widgetWithText(AppChip, '代画作业')));
        await tester.pump();
        await tester.tap(_inDialog(find.widgetWithText(AppButton, '下一步')));
        await _settle(tester, steps: 2);
        expect(find.text('确定删除这条动态？'), findsOneWidget);
        expect(find.textContaining('删除原因：代画作业'), findsOneWidget);
        final confirm = _inDialog(find.widgetWithText(AppButton, '删除'));
        expect(
          tester.widget<AppButton>(confirm).variant,
          AppButtonVariant.danger,
        );

        await tester.tap(confirm);
        await _settle(tester, steps: 4);
        expect(_workbenchCount(), before - 1);
        expect(_tab('${before - 1}'), findsOneWidget);
        expect(find.textContaining(_ghostDrawing), findsNothing);

        await tester.tap(_tab('已处理'));
        await tester.pump();
        final handled = _caseCardOf(_ghostDrawing);
        expect(handled, findsOneWidget);
        expect(
          find.descendant(of: handled, matching: find.text('已删除')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: handled, matching: find.text('删除原因：代画作业')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: handled, matching: find.textContaining('王敏')),
          findsOneWidget,
        );
      });
    });

    testWidgets('保留 asks once, then moves the report to 已处理', (tester) async {
      final before = _workbenchCount();
      await _withCirclePage(tester, DemoAccounts.admin, governance: true, () async {
        await tester.tap(
          find.descendant(
            of: _caseCardOf(_examRumor),
            matching: find.widgetWithText(AppButton, '保留'),
          ),
        );
        await _settle(tester, steps: 2);
        expect(find.text('保留这条动态？'), findsOneWidget);
        final confirm = _inDialog(find.widgetWithText(AppButton, '保留'));
        expect(
          tester.widget<AppButton>(confirm).variant,
          AppButtonVariant.primary,
        );

        await tester.tap(confirm);
        await _settle(tester, steps: 4);
        expect(_workbenchCount(), before - 1);
        expect(_tab('${before - 1}'), findsOneWidget);
        expect(find.textContaining(_examRumor), findsNothing);

        await tester.tap(_tab('已处理'));
        await tester.pump();
        final handled = _caseCardOf(_examRumor);
        expect(
          find.descendant(of: handled, matching: find.text('已保留')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: handled, matching: find.text('处理结果：举报不成立')),
          findsOneWidget,
        );
        expect(
          _circlePosts().where((p) => p['content'] == _examRumor),
          hasLength(1),
        );
      });
    });
  });

  group('normal circle', () {
    testWidgets('no governance UI; 发布动态 stays; ··· offers 删除 or 举报', (
      tester,
    ) async {
      final before = _workbenchCount();
      await _withCirclePage(tester, DemoAccounts.student, () async {
        expect(find.text('校圈'), findsOneWidget);
        expect(find.text('发布动态'), findsOneWidget);
        expect(find.text('校圈治理'), findsNothing);
        expect(_governanceTabs, findsNothing);
        expect(find.text('待处理'), findsNothing);
        expect(find.byType(CircleReportCaseCard), findsNothing);

        final semantics = tester.ensureSemantics();
        expect(find.bySemanticsLabel('更多操作'), findsWidgets);
        semantics.dispose();

        Finder moreOf(String text) => find.descendant(
          of: find.ancestor(
            of: find.textContaining(text),
            matching: find.byType(CirclePostCard),
          ),
          matching: _moreButtons,
        );

        await tester.ensureVisible(moreOf(_ownSketchDiary));
        await tester.tap(moreOf(_ownSketchDiary));
        await _settle(tester, steps: 2);
        expect(find.text('删除动态'), findsOneWidget);
        expect(find.text('举报'), findsNothing);
        await tester.tapAt(const Offset(4, 4));
        await _settle(tester, steps: 2);

        await tester.ensureVisible(moreOf(_davidCritique));
        await tester.tap(moreOf(_davidCritique));
        await _settle(tester, steps: 2);
        expect(find.text('删除动态'), findsNothing);
        await tester.tap(find.text('举报'));
        await _settle(tester, steps: 2);
        expect(_inDialog(find.text('举报动态')), findsOneWidget);
        await tester.tap(_inDialog(find.widgetWithText(AppChip, '与画室学习无关')));
        await tester.pump();
        await tester.tap(_inDialog(find.widgetWithText(AppButton, '提交举报')));
        await _settle(tester, steps: 4);
        expect(find.byType(AppDialog), findsNothing);
        expect(_workbenchCount(), before + 1);
      });
    });

    testWidgets('an admin outside 校圈治理 can post and only manage own posts', (
      tester,
    ) async {
      final own = _circlePosts()
          .where((p) => p['userId'] == DemoAccounts.admin.userId)
          .length;
      expect(own, greaterThan(0));
      await _withCirclePage(tester, DemoAccounts.admin, () async {
        expect(find.text('发布动态'), findsOneWidget);
        expect(_governanceTabs, findsNothing);
        expect(_moreButtons, findsNWidgets(own));
      });
    });
  });

  group('action icons', () {
    CirclePost post({bool liked = false, bool favorited = false}) => CirclePost(
      id: 'p1',
      author: const CircleAuthor(id: 'u1', name: '林小雨', role: '', avatarUrl: ''),
      badges: const [],
      text: '作品分享',
      timeLabel: '今天 10:20',
      imageUrl: '',
      imageAspectRatio: 1,
      likeCount: 12,
      commentCount: 3,
      favoriteCount: 4,
      liked: liked,
      favorited: favorited,
      comments: const [],
    );

    Color iconColor(WidgetTester tester, IconData icon) =>
        tester.widget<Icon>(find.byIcon(icon)).color!;

    testWidgets('idle icons are tertiary grey, 已点赞 / 已收藏 are brand purple', (
      tester,
    ) async {
      Future<void> pumpRow(CirclePost value) => tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CircleActionRow(
              post: value,
              onLike: () {},
              onComment: () {},
              onFavorite: () {},
            ),
          ),
        ),
      );

      await pumpRow(post());
      expect(
        iconColor(tester, Icons.favorite_border_rounded),
        AppColors.textTertiary,
      );
      expect(
        iconColor(tester, Icons.chat_bubble_outline_rounded),
        AppColors.textTertiary,
      );
      expect(
        iconColor(tester, Icons.bookmark_border_rounded),
        AppColors.textTertiary,
      );
      expect(
        iconColor(tester, Icons.favorite_border_rounded),
        isNot(const Color(0xFFE6E9F1)),
      );

      await pumpRow(post(liked: true, favorited: true));
      expect(iconColor(tester, Icons.favorite_rounded), AppColors.brand);
      expect(iconColor(tester, Icons.bookmark_rounded), AppColors.brand);
      expect(
        iconColor(tester, Icons.chat_bubble_outline_rounded),
        AppColors.textTertiary,
      );
    });

    testWidgets('大图模式 icons are white with a shadow, active stays purple', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            color: AppColors.ink,
            child: Column(
              children: [
                CircleActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '评论',
                  count: 3,
                  onTap: () {},
                  dark: true,
                ),
                CircleActionButton(
                  icon: Icons.favorite_border_rounded,
                  activeIcon: Icons.favorite_rounded,
                  label: '取消点赞',
                  count: 12,
                  active: true,
                  onTap: () {},
                  dark: true,
                ),
              ],
            ),
          ),
        ),
      );
      final idle = tester.widget<Icon>(
        find.byIcon(Icons.chat_bubble_outline_rounded),
      );
      expect(idle.color, AppColors.onBrand);
      expect(idle.shadows, isNotEmpty);
      expect(iconColor(tester, Icons.favorite_rounded), AppColors.brand);
    });
  });
}
