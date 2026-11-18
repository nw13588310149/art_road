import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/core/network/api_client.dart';
import 'package:the_road_of_art_flutter/core/network/api_response.dart';
import 'package:the_road_of_art_flutter/features/ebooks/data/ebook_models.dart';
import 'package:the_road_of_art_flutter/features/ebooks/data/ebook_repository.dart';
import 'package:the_road_of_art_flutter/features/ebooks/navigation/ebook_navigation.dart';
import 'package:the_road_of_art_flutter/features/ebooks/state/ebook_spread.dart';
import 'package:the_road_of_art_flutter/features/ebooks/ui/ebook_reader_page.dart';

/// 立即应答的假仓库：内页没有图片地址，测试不触发网络。
class _FakeRepository implements EbookRepository {
  _FakeRepository({this.savedPage});

  static const pageCount = 10;
  int? savedPage;
  final List<int> saves = <int>[];

  @override
  ApiClient get client => throw UnimplementedError();

  Future<ApiResponse> _ok(Object? data) =>
      Future<ApiResponse>.value(ApiResponse(code: 0, msg: 'ok', data: data));

  @override
  Future<ApiResponse> getDetail(String id) => _ok(<String, dynamic>{
    'id': id,
    'title': '测试书刊（示例）',
    'pageCount': pageCount,
    'toc': [
      {'title': '第一章', 'page': 3},
    ],
    'related': const <dynamic>[],
  });

  @override
  Future<ApiResponse> getPages(String id) => _ok(<String, dynamic>{
    'pages': [
      for (var page = 1; page <= pageCount; page++)
        {'page': page, 'imageUrl': '', 'width': 720, 'height': 960},
    ],
  });

  @override
  Future<ApiResponse> getProgress(String id) => _ok(<String, dynamic>{
    'page': savedPage,
    'updatedAt': savedPage == null ? null : '2026-11-07 08:00:00',
    'bookmarks': const <int>[],
  });

  @override
  Future<ApiResponse> saveProgress(String id, int page) {
    saves.add(page);
    savedPage = page;
    return _ok(<String, dynamic>{'page': page, 'updatedAt': '2026-11-07 08:30:00'});
  }

  @override
  Future<ApiResponse> setBookmark(String id, int page, {required bool bookmarked}) =>
      _ok(<String, dynamic>{'bookmarks': bookmarked ? [page] : const <int>[]});

  @override
  Future<ApiResponse> setFavorite(String id, {required bool favorite}) =>
      _ok(<String, dynamic>{'favorite': favorite});

  @override
  Future<ApiResponse> getBooks({
    String category = '',
    String keyword = '',
    EbookSort sort = EbookSort.recommend,
    bool featured = false,
    int current = 1,
    int size = 12,
  }) => _ok(<String, dynamic>{'records': const <dynamic>[], 'total': 0});

  @override
  Future<ApiResponse> searchBooks(String keyword, {int size = 30}) =>
      getBooks(keyword: keyword, size: size);

  @override
  Future<ApiResponse> getCategories() => _ok(const <dynamic>[]);

  @override
  Future<ApiResponse> getShelf() => _ok(<String, dynamic>{'records': const <dynamic>[]});
}

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pumpReader(WidgetTester tester, _FakeRepository repository) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [ebookRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: EbookReaderPage(bookId: 'eb-test')),
    ),
  );
  await tester.pump();
  await tester.pump();
}

String _label(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(EbookReaderPage.pageLabelKey)).data ?? '';

void main() {
  group('EbookSpread', () {
    test('two-page spreads start on odd pages and step by two', () {
      const spread = EbookSpread(pageCount: 9, twoPage: true);
      expect(spread.pagesAt(4), [3, 4]);
      expect(spread.pagesAt(9), [9]);
      expect(spread.next(1), 3);
      expect(spread.next(9), isNull);
      expect(spread.previous(4), 1);
      expect(spread.previous(2), isNull);
      expect(spread.label(5), '5–6 / 9');
      expect(spread.lastVisible(7), 8);
    });

    test('single pages step by one', () {
      const spread = EbookSpread(pageCount: 9);
      expect(spread.pagesAt(4), [4]);
      expect(spread.next(4), 5);
      expect(spread.previous(1), isNull);
      expect(spread.label(4), '4 / 9');
    });
  });

  testWidgets('landscape shows one page at a time', (tester) async {
    await _setSize(tester, const Size(1180, 820));
    final repository = _FakeRepository();
    await _pumpReader(tester, repository);

    expect(_label(tester), '1 / 10');
    expect(find.text('测试书刊（示例）'), findsOneWidget);
    Finder onStage(String label) => find.descendant(
      of: find.byKey(EbookReaderPage.stageKey),
      matching: find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == label,
      ),
    );
    expect(onStage('第 1 页'), findsOneWidget);
    expect(onStage('第 2 页'), findsNothing);

    await tester.tap(find.byKey(EbookReaderPage.nextKey));
    await tester.pump();
    expect(_label(tester), '2 / 10');

    // 点右半屏翻到下一页，点左半屏回到上一页。
    final stage = tester.getRect(find.byKey(EbookReaderPage.stageKey));
    await tester.tapAt(Offset(stage.left + stage.width * 0.75, stage.center.dy));
    await tester.pump();
    expect(_label(tester), '3 / 10');
    await tester.tapAt(Offset(stage.left + stage.width * 0.25, stage.center.dy));
    await tester.pump();
    expect(_label(tester), '2 / 10');

    await tester.tap(find.byKey(EbookReaderPage.previousKey));
    await tester.pump();
    expect(_label(tester), '1 / 10');

    await tester.pump(const Duration(seconds: 1));
    expect(repository.saves.first, 1);
    expect(repository.saves.last, 1);
  });

  testWidgets('narrow layout shows one page and turns one page at a time', (
    tester,
  ) async {
    await _setSize(tester, const Size(700, 1000));
    final repository = _FakeRepository();
    await _pumpReader(tester, repository);

    expect(_label(tester), '1 / 10');

    await tester.tap(find.byKey(EbookReaderPage.nextKey));
    await tester.pump();
    expect(_label(tester), '2 / 10');

    final stage = tester.getRect(find.byKey(EbookReaderPage.stageKey));
    await tester.tapAt(Offset(stage.left + stage.width * 0.75, stage.center.dy));
    await tester.pump();
    expect(_label(tester), '3 / 10');
    await tester.tapAt(Offset(stage.left + stage.width * 0.25, stage.center.dy));
    await tester.pump();
    expect(_label(tester), '2 / 10');

    await tester.pump(const Duration(seconds: 1));
    expect(repository.saves.last, 2);
  });

  testWidgets('bookmark toggles in the top bar and the toc jumps to a chapter', (
    tester,
  ) async {
    await _setSize(tester, const Size(1180, 820));
    final repository = _FakeRepository();
    await _pumpReader(tester, repository);

    await tester.tap(find.text('加书签'));
    await tester.pump();
    await tester.pump();
    expect(find.text('已加书签'), findsOneWidget);

    await tester.tap(find.text('目录'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('目录与书签'), findsOneWidget);
    expect(find.text('1 个'), findsOneWidget);

    await tester.tap(find.text('第一章'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('目录与书签'), findsNothing);
    expect(_label(tester), '3 / 10');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('resumes from the saved page and returns progress when closed', (
    tester,
  ) async {
    await _setSize(tester, const Size(1180, 820));
    final repository = _FakeRepository(savedPage: 5);
    EbookProgress? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [ebookRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  result = await EbookNavigation.openReader(context, bookId: 'eb-test');
                },
                child: const Text('打开阅读器'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开阅读器'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(_label(tester), '5 / 10');
    expect(repository.saves, isEmpty);

    await tester.tap(find.byKey(EbookReaderPage.nextKey));
    await tester.pump();
    expect(_label(tester), '6 / 10');

    // 立即返回：未到延迟保存的时间也会先落盘，再把进度带回来源页。
    // 阅读器顶栏返回沿用资料预览的 chevron_left 图标按钮。
    await tester.tap(find.byTooltip('返回'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(EbookReaderPage), findsNothing);
    expect(result?.page, 6);
    expect(repository.saves, [6]);
  });
}
