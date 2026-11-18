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

  testWidgets('title bar keeps actions on the right edge with or without a caption', (
    tester,
  ) async {
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
  });

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

  testWidgets('tile grid lays out equal columns and tiles keep the whole title', (
    tester,
  ) async {
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
  });
}
