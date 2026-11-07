import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/core/network/api_client.dart';
import 'package:the_road_of_art_flutter/core/network/api_response.dart';
import 'package:the_road_of_art_flutter/features/ebooks/data/ebook_models.dart';
import 'package:the_road_of_art_flutter/features/ebooks/data/ebook_repository.dart';
import 'package:the_road_of_art_flutter/features/ebooks/ui/ebooks_page.dart';
import 'package:the_road_of_art_flutter/features/ebooks/ui/home_ebook_shelf_section.dart';

Map<String, dynamic> _book(
  String id,
  String title, {
  String category = 'sketch',
  String categoryLabel = '素描教程',
  List<String> subjects = const ['素描'],
  String stage = '基础',
  int? progress,
  bool favorite = false,
  String featuredIntro = '',
}) => <String, dynamic>{
  'id': id,
  'title': title,
  'subtitle': '构图 · 明暗',
  'editor': '李静',
  'publisher': '示范画室教研组（示例）',
  'category': category,
  'categoryLabel': categoryLabel,
  'subjects': subjects,
  'stage': stage,
  'tags': const ['静物'],
  'pageCount': 10,
  'coverUrl': '',
  'intro': '一句话简介。',
  'featuredIntro': featuredIntro,
  'publishDate': '2026-10-01',
  'readers': 1200,
  'favorite': favorite,
  'progress': progress == null
      ? null
      : {'page': progress, 'updatedAt': '2026-11-0$progress 20:00:00'},
};

/// 立即应答的假仓库：书架 = 收藏 + 读过，收藏开关会改变书架与详情。
class _FakeRepository implements EbookRepository {
  bool shelfUnavailable = false;

  final Map<String, Map<String, dynamic>> books = {
    for (final book in [
      _book('b1', '素描静物解析（示例）', progress: 4, featuredIntro: '编辑推荐一'),
      _book(
        'b2',
        '色彩冷暖关系（示例）',
        category: 'color',
        categoryLabel: '色彩教程',
        subjects: const ['色彩'],
        favorite: true,
        featuredIntro: '编辑推荐二',
      ),
      _book(
        'b3',
        '速写动态（示例）',
        category: 'speed',
        categoryLabel: '速写教程',
        subjects: const ['速写'],
        featuredIntro: '编辑推荐三',
      ),
      _book(
        'b4',
        '美院校考作品集（示例）',
        category: 'academy',
        categoryLabel: '美院校考',
        subjects: const ['素描', '色彩', '速写'],
        stage: '冲刺',
      ),
      _book('b5', '石膏头像入门（示例）', progress: 10),
    ])
      book['id'] as String: book,
  };

  @override
  ApiClient get client => throw UnimplementedError();

  Future<ApiResponse> _ok(Object? data) =>
      Future<ApiResponse>.value(ApiResponse(code: 0, msg: 'ok', data: data));

  @override
  Future<ApiResponse> getCategories() => _ok([
    {'key': 'all', 'label': '全部', 'count': books.length},
    {'key': 'sketch', 'label': '素描教程', 'count': 2},
    {'key': 'color', 'label': '色彩教程', 'count': 1},
    {'key': 'speed', 'label': '速写教程', 'count': 1},
    {'key': 'academy', 'label': '美院校考', 'count': 1},
  ]);

  @override
  Future<ApiResponse> getBooks({
    String category = '',
    String keyword = '',
    EbookSort sort = EbookSort.recommend,
    bool featured = false,
    int current = 1,
    int size = 12,
  }) {
    final list = books.values
        .where((b) => category.isEmpty || category == 'all' || b['category'] == category)
        .where((b) => keyword.isEmpty || (b['title'] as String).contains(keyword))
        .where((b) => !featured || (b['featuredIntro'] as String).isNotEmpty)
        .toList();
    return _ok({'records': list, 'total': list.length});
  }

  @override
  Future<ApiResponse> searchBooks(String keyword, {int size = 30}) =>
      getBooks(keyword: keyword, size: size);

  @override
  Future<ApiResponse> getDetail(String id) => _ok({
    ...books[id]!,
    'description': '这是一段示例简介。',
    'toc': [
      {'title': '构图', 'page': 3},
      {'title': '明暗', 'page': 5},
    ],
    'related': [for (final b in books.values) if (b['id'] != id) b].take(3).toList(),
  });

  @override
  Future<ApiResponse> getShelf() => shelfUnavailable
      ? Future.value(ApiResponse(code: 500, msg: '暂时无法加载书架'))
      : _ok({
          'records': [
            for (final b in books.values)
              if (b['favorite'] == true || b['progress'] != null) b,
          ],
        });

  @override
  Future<ApiResponse> setFavorite(String id, {required bool favorite}) {
    books[id]!['favorite'] = favorite;
    return _ok({'favorite': favorite});
  }

  @override
  Future<ApiResponse> getPages(String id) => _ok({'pages': const <dynamic>[]});

  @override
  Future<ApiResponse> getProgress(String id) => _ok(const <String, dynamic>{});

  @override
  Future<ApiResponse> saveProgress(String id, int page) =>
      _ok({'page': page, 'updatedAt': '2026-11-07 09:00:00'});

  @override
  Future<ApiResponse> setBookmark(String id, int page, {required bool bookmarked}) =>
      _ok({'bookmarks': const <int>[]});
}

Future<void> _pumpInShell(WidgetTester tester, Widget child, _FakeRepository repository) async {
  tester.view.physicalSize = const Size(1180, 820);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [ebookRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            // 外壳内容区约 950 × 740。
            child: SizedBox(width: 950, height: 740, child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('ebooks page browses, opens a detail, toggles the shelf and filters', (
    tester,
  ) async {
    final repository = _FakeRepository();
    await _pumpInShell(tester, const EbooksPage(args: <String, dynamic>{}), repository);

    expect(find.text('美术书刊'), findsNothing);
    expect(find.text('精选美术教辅与期刊（示例内容）'), findsNothing);
    expect(find.text('编辑推荐'), findsOneWidget);
    expect(find.text('编辑推荐二'), findsOneWidget);
    expect(find.text('读到第 4 / 10 页'), findsWidgets);
    expect(find.text('已读完'), findsWidgets);

    // 打开详情：基本信息、目录、相关书刊，加入书架后按钮立即变化。
    await tester.tap(find.text('美院校考作品集（示例）').first);
    await tester.pump();
    await tester.pump();
    expect(find.text('内容简介'), findsOneWidget);
    expect(find.text('相关书刊'), findsOneWidget);
    expect(find.text('第 5 页'), findsOneWidget);
    expect(find.text('开始阅读'), findsOneWidget);
    await tester.tap(find.text('加入书架'));
    await tester.pump();
    expect(find.text('已在书架'), findsOneWidget);
    expect(repository.books['b4']!['favorite'], isTrue);

    await tester.tap(find.byTooltip('返回'));
    await tester.pump();
    expect(find.text('内容简介'), findsNothing);

    // 我的书架：收藏与读过的书刊，带阅读按钮。
    await tester.tap(find.text('我的书架'));
    await tester.pump();
    await tester.pump();
    expect(find.text('全部 4'), findsOneWidget);
    expect(find.text('在读 1'), findsOneWidget);
    expect(find.text('继续阅读'), findsOneWidget);
    expect(find.text('重新阅读'), findsOneWidget);

    // 回到书库按分类筛选。
    await tester.tap(find.text('书库'));
    await tester.pump();
    await tester.tap(find.text('色彩教程').first);
    await tester.pump();
    await tester.pump();
    expect(find.text('编辑推荐'), findsNothing);
    expect(find.text('色彩冷暖关系（示例）'), findsOneWidget);
    expect(find.text('速写动态（示例）'), findsNothing);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('shelf failure offers retry and recovers', (tester) async {
    final repository = _FakeRepository()..shelfUnavailable = true;
    await _pumpInShell(tester, const EbooksPage(), repository);

    await tester.tap(find.text('我的书架'));
    await tester.pump();
    await tester.pump();
    expect(find.text('书架加载失败'), findsOneWidget);
    expect(find.text('书架还是空的'), findsNothing);

    repository.shelfUnavailable = false;
    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump();
    expect(find.text('书架加载失败'), findsNothing);
    expect(find.text('全部 3'), findsOneWidget);
  });

  testWidgets('home section shows continue reading and picks', (tester) async {
    final repository = _FakeRepository();
    await _pumpInShell(
      tester,
      const SingleChildScrollView(child: HomeEbookShelfSection()),
      repository,
    );

    expect(find.text('精选书刊'), findsOneWidget);
    expect(find.text('继续阅读'), findsWidgets);
    expect(find.text('素描静物解析（示例）'), findsWidgets);
    expect(find.text('速写动态（示例）'), findsOneWidget);
    expect(find.text('读到第 4 / 10 页'), findsOneWidget);
  });
}
