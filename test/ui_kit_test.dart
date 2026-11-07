import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/core/constants/app_assets.dart';
import 'package:the_road_of_art_flutter/core/theme/app_font.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:the_road_of_art_flutter/core/widgets/app_asset_graphic.dart';
import 'package:the_road_of_art_flutter/core/widgets/art_widgets.dart';
import 'package:the_road_of_art_flutter/core/widgets/dashboard_course_notice_card.dart';
import 'package:the_road_of_art_flutter/core/widgets/segment_toggle.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

FontWeight? _weightOf(WidgetTester tester, String text) {
  return tester.widget<Text>(find.text(text)).style?.fontWeight;
}

void _expectFullyLaidOut(WidgetTester tester, String text, Rect bounds) {
  final finder = find.text(text);
  expect(finder, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  expect(paragraph.didExceedMaxLines, isFalse);
  expect(
    paragraph.size.width,
    greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity) - 0.5),
  );
  final rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(bounds.left));
  expect(rect.right, lessThanOrEqualTo(bounds.right));
}

void main() {
  testWidgets('single-line controls keep hints and edits centered', (
    tester,
  ) async {
    const search = ValueKey('search');
    const input = ValueKey('input');
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 250,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSearchField(key: search, hint: '搜索范画', toolbar: true),
              SizedBox(height: 16),
              AppInputField(key: input, hint: '请输入标题'),
            ],
          ),
        ),
      ),
    );

    for (final (key, hint, height) in [
      (search, '搜索范画', 40.0),
      (input, '请输入标题', 34.0),
    ]) {
      final field = find.byKey(key);
      final editor = find.descendant(
        of: field,
        matching: find.byType(EditableText),
      );
      final center = tester.getCenter(field).dy;
      expect(tester.getSize(field).height, height);
      expect(tester.getCenter(find.text(hint)).dy, closeTo(center, 1));
      await tester.enterText(editor, '石膏');
      await tester.pump();
      expect(tester.getCenter(editor).dy, closeTo(center, 1));
    }
  });

  testWidgets('asset graphics keep the original format on a decode error', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Row(
          children: [
            AppAssetGraphic(AppAssets.shellV2Notice, width: 20, height: 20),
            AppAssetGraphic(AppAssets.shellV2MoreArrow, width: 10, height: 10),
          ],
        ),
      ),
    );
    final raster = find.byType(Image);
    expect(raster, findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
    final fallback = tester.widget<Image>(raster).errorBuilder!(
      tester.element(raster),
      StateError('asset decode failed'),
      null,
    );
    expect(fallback, isA<SizedBox>());
  });

  testWidgets('shared controls respond to keyboard and skip disabled items', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _host(
        Row(
          children: [
            AppButton(label: '不可用', enabled: false, onTap: () => calls += 10),
            AppButton(label: '查看', onTap: () => calls++),
          ],
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);

    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  group('AppSegmented', () {
    testWidgets('changes selection on the same frame without animating', (
      tester,
    ) async {
      var value = 'all';
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) => AppSegmented<String>(
              segments: const [
                AppSegment(value: 'all', label: '全部'),
                AppSegment(value: 'pending', label: '待点评'),
              ],
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      );
      expect(_weightOf(tester, '全部'), AppFont.w500);
      expect(_weightOf(tester, '待点评'), AppFont.w400);

      await tester.tap(find.text('待点评'));
      await tester.pump();

      expect(value, 'pending');
      expect(_weightOf(tester, '待点评'), AppFont.w500);
      expect(_weightOf(tester, '全部'), AppFont.w400);
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('disabled segment ignores taps', (tester) async {
      var value = 'week';
      await tester.pumpWidget(
        _host(
          AppSegmented<String>(
            segments: const [
              AppSegment(value: 'week', label: '本周'),
              AppSegment(value: 'year', label: '全年', enabled: false),
            ],
            value: value,
            onChanged: (next) => value = next,
          ),
        ),
      );
      await tester.tap(find.text('全年'), warnIfMissed: false);
      await tester.pump();
      expect(value, 'week');
    });
  });

  group('legacy wrappers', () {
    testWidgets('SegmentToggle switches instantly without DashboardScaleScope', (
      tester,
    ) async {
      var index = 0;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) => SegmentToggle(
              selectedIndex: index,
              options: const [
                SegmentToggleOption(label: '查看'),
                SegmentToggleOption(label: '编辑'),
              ],
              onChanged: (next) => setState(() => index = next),
            ),
          ),
        ),
      );
      await tester.tap(find.text('编辑'));
      await tester.pump();
      expect(index, 1);
      expect(_weightOf(tester, '编辑'), AppFont.w500);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('ArtSegmentTabs no longer animates a pill', (tester) async {
      var value = 'a';
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) => ArtSegmentTabs<String>(
              items: const ['a', 'b'],
              value: value,
              labelOf: (item) => item == 'a' ? '全部科目' : '素描',
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      );
      expect(find.byType(AnimatedContainer), findsNothing);
      await tester.tap(find.text('素描'));
      await tester.pump();
      expect(value, 'b');
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('AppButton', () {
    testWidgets('disabled button ignores taps and fades to 40%', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(AppButton(label: '提交', enabled: false, onTap: () => taps++)),
      );
      await tester.tap(find.text('提交'), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);
      final opacity = tester.widget<Opacity>(
        find.ancestor(of: find.text('提交'), matching: find.byType(Opacity)),
      );
      expect(opacity.opacity, AppOpacity.disabled);
    });

    testWidgets('null onTap is disabled, enabled button taps once', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppButton(label: '不可用', onTap: null),
              AppButton(label: '保存', onTap: () => taps++),
            ],
          ),
        ),
      );
      await tester.tap(find.text('不可用'), warnIfMissed: false);
      await tester.tap(find.text('保存'));
      await tester.pump();
      expect(taps, 1);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('AppCourseCard', () {
    Future<Rect> pumpCard(WidgetTester tester, double width, Widget card) async {
      await tester.pumpWidget(_host(SizedBox(width: width, child: card)));
      expect(tester.takeException(), isNull);
      return tester.getRect(find.byType(AppCourseCard));
    }

    testWidgets('lays out both tags without overflow in a 300px box', (
      tester,
    ) async {
      final bounds = await pumpCard(
        tester,
        300,
        const AppCourseCard(
          startTime: '08:30',
          endTime: '11:30',
          subject: '模拟考试',
          teacherName: '王建国',
          subtitle: '180分钟 · 联考冲刺1班 · 301教室',
          status: AppCourseStatus.inProgress,
        ),
      );
      expect(bounds.width, 300);
      _expectFullyLaidOut(tester, '模拟考试', bounds);
      _expectFullyLaidOut(tester, '大课', bounds);
      _expectFullyLaidOut(tester, '进行中', bounds);
      expect(find.text('王'), findsOneWidget);
    });

    testWidgets('wraps long tags instead of clipping in a narrow box', (
      tester,
    ) async {
      final bounds = await pumpCard(
        tester,
        220,
        const AppCourseCard(
          startTime: '21:10',
          endTime: '22:00',
          subject: '素描头像精讲（一对一）',
          teacherName: '周敏',
          isSmallCourse: true,
          status: AppCourseStatus.ended,
        ),
      );
      _expectFullyLaidOut(tester, '素描头像精讲（一对一）', bounds);
      _expectFullyLaidOut(tester, '小课', bounds);
      expect(
        tester.getTopLeft(find.text('小课')).dy,
        greaterThan(tester.getTopLeft(find.text('素描头像精讲（一对一）')).dy),
      );
    });

    testWidgets('DashboardCourseNoticeCard renders it with a custom status', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 300,
            child: DashboardCourseNoticeCard(
              startTime: '08:00',
              endTime: '11:30',
              subjectName: '素描',
              isSmallCourse: false,
              displayName: '王建国',
              subtitle: '210分钟 · 301教室',
              avatar: const AppAvatar(name: '王建国', size: 36),
              runState: DashboardCourseRunState.ended,
              statusBadgeLabel: '缺勤',
              statusBadgeBackground: AppColors.dangerSoft,
              statusBadgeTextColor: AppColors.danger,
              onTap: () => taps++,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(AppCourseCard), findsOneWidget);
      expect(find.text('缺勤'), findsOneWidget);
      expect(find.text('已结束'), findsNothing);
      await tester.tap(find.text('素描'));
      expect(taps, 1);
    });
  });

  group('overlays', () {
    testWidgets('showAppConfirm works without DashboardScaleScope', (
      tester,
    ) async {
      final results = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: AppButton(
                  label: '删除作品',
                  onTap: () async {
                    results.add(
                      await showAppConfirm(
                        context: context,
                        title: '删除这件作品',
                        message: '删除后无法恢复。',
                        confirmLabel: '删除',
                        danger: true,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('删除作品'));
      await tester.pumpAndSettle();
      expect(find.text('删除这件作品'), findsOneWidget);
      await tester.tap(
        find.descendant(of: find.byType(AppDialog), matching: find.text('删除')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('删除作品'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(AppDialog), matching: find.text('取消')),
      );
      await tester.pumpAndSettle();

      expect(results, [true, false]);
      expect(find.byType(AppDialog), findsNothing);
    });

    testWidgets('AppToast keeps the legacy show API', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: AppButton(
                  label: '保存',
                  onTap: () => AppToast.show(context, '保存成功'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('保存'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('保存成功'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('保存成功'), findsNothing);
    });
  });

  group('controls', () {
    testWidgets('AppSwitch toggles instantly and respects null onChanged', (
      tester,
    ) async {
      var on = false;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppSwitch(
                  key: const ValueKey('live'),
                  value: on,
                  onChanged: (next) => setState(() => on = next),
                ),
                const AppSwitch(
                  key: ValueKey('off'),
                  value: false,
                  onChanged: null,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('live')));
      await tester.pump();
      expect(on, isTrue);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.tap(find.byKey(const ValueKey('off')), warnIfMissed: false);
      await tester.pump();
      expect(on, isTrue);
    });

    testWidgets('AppCheckbox label toggles the value', (tester) async {
      var checked = false;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) => AppCheckbox(
              value: checked,
              label: '记住账号',
              onChanged: (next) => setState(() => checked = next),
            ),
          ),
        ),
      );
      await tester.tap(find.text('记住账号'));
      await tester.pump();
      expect(checked, isTrue);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });

  test('AppAvatar initials use the surname', () {
    expect(AppAvatar.initialOf('王建国'), '王');
    expect(AppAvatar.initialOf(' lucy '), 'L');
    expect(AppAvatar.initialOf(''), '?');
    expect(AppAvatar.colorOf('王建国'), AppAvatar.colorOf('王建国'));
  });
}
