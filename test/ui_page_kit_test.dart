// 新页面的组件（docs/新页面设计语言.md）：页头、视图切换、筛选条、次要按钮、
// 数字行、进度环和图片网格的尺寸与行为。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/core/theme/app_font.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';

Widget _host(Widget child, {double width = 600}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('page body uses wide gutters from 900 and narrow ones below', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final (width, wide, gutter) in [
      (970.0, true, 32.0),
      (814.0, false, 24.0),
    ]) {
      bool? seen;
      await tester.pumpWidget(
        _host(
          SizedBox(
            height: 300,
            child: AppPageBody(
              builder: (context, isWide) {
                seen = isWide;
                return const SizedBox(key: ValueKey('content'), height: 40);
              },
            ),
          ),
          width: width,
        ),
      );
      expect(seen, wide);
      final content = tester.getRect(find.byKey(const ValueKey('content')));
      expect(content.left, gutter);
      expect(content.top, AppPageBody.top);
      expect(content.width, width - gutter * 2);
    }
    expect(AppPageBody.sideWidth(true), 280);
    expect(AppPageBody.sideWidth(false), 232);
    expect(AppPageBody.columnGap(true), 48);
    expect(AppPageBody.columnGap(false), 32);
  });

  testWidgets(
    'title bar keeps actions on the right edge with or without a caption',
    (tester) async {
      for (final caption in ['', '11月18日 周三 · 早上好']) {
        await tester.pumpWidget(
          _host(
            AppTitleBar(
              title: '今日学习',
              caption: caption,
              actions: const [
                SizedBox(key: ValueKey('action'), width: 80, height: 44),
              ],
            ),
          ),
        );
        expect(tester.getSize(find.byType(AppTitleBar)).height, 44);
        expect(tester.getRect(find.byKey(const ValueKey('action'))).right, 600);
        expect(find.text('今日学习'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('view tabs report the tapped value and embolden the selection', (
    tester,
  ) async {
    var value = 'library';
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => AppViewTabs<String>(
            items: const [
              AppViewTab(value: 'library', label: '书库'),
              AppViewTab(value: 'shelf', label: '我的书架'),
            ],
            value: value,
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    );
    FontWeight? weightOf(String text) =>
        tester.widget<Text>(find.text(text)).textSpan?.style?.fontWeight ??
        tester.widget<Text>(find.text(text)).style?.fontWeight;
    expect(weightOf('书库'), AppFont.w600);
    expect(weightOf('我的书架'), AppFont.w400);
    expect(
      tester
          .getSize(
            find
                .ancestor(
                  of: find.text('我的书架'),
                  matching: find.byType(AppPressable),
                )
                .first,
          )
          .height,
      44,
    );

    await tester.tap(find.text('我的书架'));
    await tester.pump();
    expect(value, 'shelf');
    expect(weightOf('我的书架'), AppFont.w600);
    expect(weightOf('书库'), AppFont.w400);
  });

  testWidgets('filter bar gives every item a 44 high tap target', (
    tester,
  ) async {
    var value = 'all';
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => AppFilterBar<String>(
            items: const [
              AppFilterItem(value: 'all', label: '全部'),
              AppFilterItem(value: 'sketch', label: '素描教程'),
              AppFilterItem(value: 'color', label: '色彩教程'),
            ],
            value: value,
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    );
    for (final label in ['全部', '素描教程', '色彩教程']) {
      final target = find
          .ancestor(of: find.text(label), matching: find.byType(AppPressable))
          .first;
      expect(tester.getSize(target).height, 44, reason: label);
    }
    await tester.tap(find.text('色彩教程'));
    await tester.pump();
    expect(value, 'color');
  });

  testWidgets('filter bar scrolls sideways instead of overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AppFilterBar<int>(
          items: [
            for (var i = 0; i < 12; i++)
              AppFilterItem(value: i, label: '联考真题解析 $i'),
          ],
          value: 0,
          onChanged: (_) {},
        ),
        width: 320,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AppFilterBar<int>)).width, 320);
  });

  testWidgets('plain button is 44 high and ignores taps when disabled', (
    tester,
  ) async {
    var taps = 0;
    Future<void> pump({required bool enabled}) => tester.pumpWidget(
      _host(
        Row(
          children: [
            AppPlainButton(
              label: '添加安排',
              icon: Icons.add_rounded,
              enabled: enabled,
              onTap: () => taps++,
            ),
          ],
        ),
      ),
    );

    await pump(enabled: true);
    expect(tester.getSize(find.byType(AppPlainButton)).height, 44);
    await tester.tap(find.text('添加安排'));
    expect(taps, 1);

    await pump(enabled: false);
    await tester.tap(find.text('添加安排'), warnIfMissed: false);
    expect(taps, 1);
  });

  testWidgets('new-page options keep control states ink and labels complete', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPlainButton(
              label: '目录',
              semanticLabel: '目录与书签',
              onTap: () {},
            ),
            AppIconAction(
              icon: Icons.bookmark_border_rounded,
              activeIcon: Icons.bookmark_rounded,
              active: true,
              activeColor: AppColors.ink,
              semanticLabel: '取消收藏',
              onTap: () {},
            ),
            AppSwitch(
              value: true,
              onChanged: (_) {},
              activeColor: AppColors.ink,
            ),
            AppTag.subject('美术常识', otherNeutral: true),
            AppTag.subject('美术常识'),
          ],
        ),
      ),
    );

    // 宽松约束下按内容取宽，不再撑满整行。
    expect(tester.getSize(find.byType(AppPlainButton)).width, lessThan(120));
    expect(find.bySemanticsLabel('目录与书签'), findsOneWidget);

    final icon = tester.widget<Icon>(find.byIcon(Icons.bookmark_rounded));
    expect(icon.color, AppColors.ink);

    final track = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(AppSwitch),
            matching: find.byType(Container),
          ),
        )
        .first;
    expect((track.decoration! as BoxDecoration).color, AppColors.ink);

    final tags = tester.widgetList<AppTag>(find.byType(AppTag)).toList();
    expect(tags[0].color, isNull, reason: '其他科目转中性灰');
    expect(tags[1].color, AppColors.brandDeep, reason: '保留页面的默认不变');
    handle.dispose();
  });

  testWidgets('stat row keeps a long caption inside a narrow side column', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const AppStatRow(
          label: '今日练习',
          caption: '目标 60 分钟，还差 60 分钟',
          value: '0',
          unit: '分钟',
        ),
        width: 232,
      ),
    );
    expect(tester.takeException(), isNull);
    final caption = tester.renderObject<RenderParagraph>(
      find.text('目标 60 分钟，还差 60 分钟'),
    );
    expect(caption.didExceedMaxLines, isFalse);
    expect(find.text('今日练习'), findsOneWidget);
    expect(
      tester.getSize(find.byType(AppStatRow)).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('progress ring tells screen readers what it measures', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const Row(
          children: [AppProgressRing(value: 0.3, semanticLabel: '今日进度')],
        ),
      ),
    );
    expect(tester.getSize(find.byType(AppProgressRing)), const Size(56, 56));
    final node = tester.getSemantics(find.bySemanticsLabel('今日进度'));
    expect(node.label, '今日进度');
    expect(node.value, '30%');
    handle.dispose();
  });

  testWidgets(
    'detail title bar has a 44 back button and shortens a long name',
    (tester) async {
      var backs = 0;
      await tester.pumpWidget(
        _host(
          AppTitleBar(
            title: '2026 年 9 月月考 · 素描高分卷 · 城东校区 · 林小雨 · 第一名',
            onBack: () => backs++,
            actions: const [SizedBox(width: 300, height: 44)],
          ),
          width: 520,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(AppBackButton)), const Size(44, 44));
      expect(find.byTooltip('返回'), findsOneWidget);
      await tester.tap(find.byType(AppBackButton));
      expect(backs, 1);
    },
  );

  testWidgets(
    'every view tab is at least 44 wide and the first stays flush left',
    (tester) async {
      await tester.pumpWidget(
        _host(
          Row(
            children: [
              AppViewTabs<int>(
                dense: true,
                items: const [
                  AppViewTab(value: 0, label: '全部'),
                  AppViewTab(value: 1, label: '石膏'),
                  AppViewTab(value: 2, label: '联考高分卷'),
                ],
                value: 0,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      );
      for (final label in ['全部', '石膏', '联考高分卷']) {
        final target = find
            .ancestor(of: find.text(label), matching: find.byType(AppPressable))
            .first;
        expect(tester.getSize(target).width, greaterThanOrEqualTo(44));
      }
      expect(tester.getTopLeft(find.text('全部')).dx, 0);
    },
  );

  testWidgets('icon action is a 44 target with a tooltip and a toggled state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      _host(
        Row(
          children: [
            AppIconAction(
              icon: Icons.star_border_rounded,
              activeIcon: Icons.star_rounded,
              active: true,
              semanticLabel: '取消收藏',
              onTap: () => taps++,
            ),
          ],
        ),
      ),
    );
    expect(tester.getSize(find.byType(AppIconAction)), const Size(44, 44));
    expect(find.byTooltip('取消收藏'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('取消收藏'));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('masonry grid puts each picture in the shortest column', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // 第一张很高，第二、三张都应排到第二列，第四张回到第二列下面或第一列。
    const ratios = [0.5, 2.0, 2.0, 2.0];
    await tester.pumpWidget(
      _host(
        SingleChildScrollView(
          child: AppMasonryGrid(
            columns: 2,
            gap: 20,
            captionExtent: 0,
            itemCount: ratios.length,
            aspectRatioOf: (i) => ratios[i],
            itemBuilder: (context, i) => AspectRatio(
              key: ValueKey('w$i'),
              aspectRatio: ratios[i],
              child: const ColoredBox(color: AppColors.canvas),
            ),
          ),
        ),
        width: 420,
      ),
    );
    expect(tester.takeException(), isNull);
    final first = tester.getRect(find.byKey(const ValueKey('w0')));
    final second = tester.getRect(find.byKey(const ValueKey('w1')));
    final third = tester.getRect(find.byKey(const ValueKey('w2')));
    expect(first.width, 200);
    expect(second.left, first.right + 20);
    expect(third.left, second.left);
    expect(third.top, second.bottom + 20);
  });

  testWidgets('canvas layout keeps the panel width and fills the height', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1180, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        SizedBox(
          height: 500,
          child: AppCanvasLayout(
            wide: false,
            hint: '双指缩放 · 双击放大',
            canvas: const SizedBox.expand(key: ValueKey('canvas')),
            panel: Column(
              children: [for (var i = 0; i < 40; i++) Text('点评要点 $i')],
            ),
          ),
        ),
        width: 766,
      ),
    );
    expect(tester.takeException(), isNull);
    final canvas = tester.getRect(find.byKey(const ValueKey('canvas')));
    expect(canvas.width, 766 - 232 - 32);
    expect(canvas.height, 500 - 24 - AppCanvasLayout.footerHeight);
    expect(find.text('双指缩放 · 双击放大'), findsOneWidget);
  });

  testWidgets('data table right-aligns number columns', (tester) async {
    await tester.pumpWidget(
      _host(
        AppDataTable(
          columns: const [
            AppTableColumn('科目', flex: 2),
            AppTableColumn('得分', numeric: true),
          ],
          rows: [
            AppTableRow(const ['素描', '92.5'], onTap: () {}),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final score = tester.getRect(find.text('92.5'));
    final header = tester.getRect(find.text('得分'));
    expect((score.right - header.right).abs(), lessThan(1));
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(
      tester
          .getSize(
            find
                .ancestor(
                  of: find.text('素描'),
                  matching: find.byType(AppPressable),
                )
                .first,
          )
          .height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('a choice menu marks the current item with an ink check', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppMenu<String>(
                context: context,
                selected: 'new',
                items: const [
                  AppMenuItem(value: 'new', label: '最新'),
                  AppMenuItem(value: 'hot', label: '最热'),
                ],
              ),
              child: const Text('排序'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('排序'));
    await tester.pumpAndSettle();
    final check = tester.widget<Icon>(find.byIcon(Icons.check_rounded));
    expect(check.color, AppColors.ink);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets(
    'tile grid lays out equal columns and tiles keep the whole title',
    (tester) async {
      const title = '联考素描静物高分解析（示例）';
      tester.view.physicalSize = const Size(1180, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(
          AppTileGrid(
            columns: 5,
            gap: 28,
            children: [
              for (var i = 0; i < 6; i++)
                AppImageTile(
                  key: ValueKey('tile-$i'),
                  image: AppImageTile.frame(
                    aspectRatio: 3 / 4,
                    child: const ColoredBox(color: AppColors.surfaceSubtle),
                  ),
                  title: title,
                  meta: '基础 · 12 页',
                ),
            ],
          ),
          width: 906,
        ),
      );
      expect(tester.takeException(), isNull);
      final first = tester.getRect(find.byKey(const ValueKey('tile-0')));
      final second = tester.getRect(find.byKey(const ValueKey('tile-1')));
      final sixth = tester.getRect(find.byKey(const ValueKey('tile-5')));
      expect(first.width, 158);
      expect(second.width, first.width);
      expect(second.left - first.right, 28);
      expect(sixth.left, first.left);
      expect(sixth.top, first.bottom + 28);
      for (final paragraph in tester.renderObjectList<RenderParagraph>(
        find.text(title),
      )) {
        expect(paragraph.didExceedMaxLines, isFalse);
      }
    },
  );
}
