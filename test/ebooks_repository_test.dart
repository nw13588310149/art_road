import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/demo/data/demo_favorites.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_backend.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_store.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/content_ebooks.dart';
import 'package:the_road_of_art_flutter/core/network/api_client.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';
import 'package:the_road_of_art_flutter/features/ebooks/data/ebook_collection.dart';
import 'package:the_road_of_art_flutter/features/ebooks/data/ebook_models.dart';
import 'package:the_road_of_art_flutter/features/ebooks/data/ebook_repository.dart';

void main() {
  late EbookRepository repository;
  late DemoRouter router;
  final userId = DemoAccounts.student.userId;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'token': DemoAccounts.student.token,
    });
    final prefs = await SharedPreferences.getInstance();
    await DemoStore.init();
    await DemoStore.reset();
    router = DemoRouter('ebooks-test');
    registerEbookFixtures(router);
    repository = EbookRepository(
      client: ApiClient(storage: AppStorage(prefs), demoRouter: router),
    );
  });

  /// 直接调用演示接口（不经过网络层的模拟延迟），用于逐本核对数据。
  Future<Object?> handle(String path) async {
    final match = router.match('GET', path)!;
    return match.handler(
      DemoRequest(
        method: 'GET',
        path: path,
        query: const <String, dynamic>{},
        body: null,
        headers: <String, dynamic>{'app-token': DemoAccounts.student.token},
        pathParams: match.params,
      ),
    );
  }

  Future<List<EbookSummary>> books({
    String category = '',
    String keyword = '',
    EbookSort sort = EbookSort.recommend,
    bool featured = false,
    int current = 1,
    int size = 20,
  }) async {
    final response = await repository.getBooks(
      category: category,
      keyword: keyword,
      sort: sort,
      featured: featured,
      current: current,
      size: size,
    );
    expect(response.isSuccess, isTrue, reason: response.msg);
    return EbookListPage.fromJson(response.data).records;
  }

  Future<EbookDetail> detail(String id) async {
    final response = await repository.getDetail(id);
    expect(response.isSuccess, isTrue, reason: response.msg);
    return EbookDetail.fromJson(response.data as Map);
  }

  Future<EbookShelf> shelf() async {
    final response = await repository.getShelf();
    expect(response.isSuccess, isTrue, reason: response.msg);
    return EbookShelf.fromJson(response.data);
  }

  test('categories cover all ten sample books', () async {
    final response = await repository.getCategories();
    final categories = EbookCategory.listFrom(response.data);
    expect(categories.first.key, EbookCategory.allKey);
    expect(categories.first.count, 10);
    expect(categories.map((c) => c.label), [
      '全部',
      '联考真题解析',
      '高分范画集',
      '素描教程',
      '色彩教程',
      '速写教程',
      '美院校考',
      '美术史与鉴赏',
      '期刊',
    ]);
    expect(categories.skip(1).every((c) => c.count >= 1), isTrue);
    expect(categories.skip(1).fold<int>(0, (sum, c) => sum + c.count), 10);
  });

  test('filters by category key or label and by keyword', () async {
    final magazines = await books(category: 'magazine');
    expect(magazines.map((b) => b.id), [
      'eb-monthly-202611',
      'eb-monthly-202610',
    ]);
    expect(
      (await books(category: '期刊')).map((b) => b.id),
      magazines.map((b) => b.id),
    );
    expect((await books(keyword: '石膏')).map((b) => b.id), ['eb-cast-head']);
    expect(
      (await books(category: 'color', keyword: '风景')).map((b) => b.id),
      ['eb-color-landscape'],
    );
    final speed = await books(keyword: '速写');
    expect(speed.every((b) => b.subjects.contains('速写') || b.title.contains('速写')), isTrue);
    expect(speed.map((b) => b.id), contains('eb-speed-figure'));
    expect(await books(keyword: '不存在的书名'), isEmpty);
    expect(await books(category: 'unknown'), hasLength(10));
  });

  test('every sample is labelled 示例 and carries cover, stage and subjects', () async {
    final all = await books();
    expect(all, hasLength(10));
    for (final book in all) {
      expect(book.title, endsWith('（示例）'));
      expect(book.coverUrl, contains('assets/demo/ebooks/${book.id}-cover.jpg'));
      expect(['基础', '提高', '冲刺'], contains(book.stage));
      expect(book.subjects, isNotEmpty);
      expect(book.pageCount, inInclusiveRange(8, 12));
    }
  });

  test('sorts by recommend, latest and popular; featured and paging', () async {
    expect((await books()).first.id, 'eb-sketch-still');
    expect((await books(sort: EbookSort.latest)).first.id, 'eb-monthly-202611');
    expect((await books(sort: EbookSort.popular)).first.id, 'eb-exam-sketch');
    final featured = await books(featured: true);
    expect(featured.map((b) => b.id), [
      'eb-sketch-still',
      'eb-color-warmcool',
      'eb-monthly-202611',
    ]);
    expect(featured.every((b) => b.featuredIntro.isNotEmpty), isTrue);
    final page3 = await repository.getBooks(current: 3, size: 4);
    final result = EbookListPage.fromJson(page3.data);
    expect(result.total, 10);
    expect(result.records, hasLength(2));
  });

  test('progress is saved, clamped and restored', () async {
    final initial = await repository.getProgress('eb-cast-head');
    expect(EbookReading.fromJson(initial.data).progress, isNull);

    final saved = await repository.saveProgress('eb-cast-head', 6);
    expect(EbookProgress.fromJson(saved.data)?.page, 6);
    final restored = EbookReading.fromJson(
      (await repository.getProgress('eb-cast-head')).data,
    );
    expect(restored.progress?.page, 6);
    expect(restored.progress?.updatedAt, isNotEmpty);
    expect((await detail('eb-cast-head')).book.progress?.page, 6);

    await repository.saveProgress('eb-cast-head', 99);
    final finished = (await detail('eb-cast-head')).book;
    expect(finished.progress?.page, 10);
    expect(finished.finished, isTrue);

    final invalid = await repository.saveProgress('eb-cast-head', 0);
    expect(invalid.isSuccess, isFalse);
  });

  test('favourite toggle is mirrored into 我的收藏', () async {
    expect((await detail('eb-cast-head')).book.favorite, isFalse);

    final on = await repository.setFavorite('eb-cast-head', favorite: true);
    expect((on.data as Map)['favorite'], isTrue);
    expect((await detail('eb-cast-head')).book.favorite, isTrue);
    expect(
      DemoFavorites.contains(userId, kDemoEbookFavoriteType, 'eb-cast-head'),
      isTrue,
    );
    final entry = DemoFavorites.of(userId).firstWhere(
      (f) => f['targetId'] == 'eb-cast-head',
    );
    expect(entry['title'], '石膏头像结构入门（示例）');
    expect(entry['subtitle'], '素描教程 · 王海波');
    expect(entry['cover'], 'asset:assets/demo/ebooks/eb-cast-head-cover.jpg');

    await repository.setFavorite('eb-cast-head', favorite: false);
    expect((await detail('eb-cast-head')).book.favorite, isFalse);
    expect(
      DemoFavorites.contains(userId, kDemoEbookFavoriteType, 'eb-cast-head'),
      isFalse,
    );
  });

  test('shelf lists favourites and books in progress', () async {
    final seeded = await shelf();
    expect(seeded.reading.map((b) => b.id), ['eb-sketch-still', 'eb-speed-figure']);
    expect(
      seeded.favorites.map((b) => b.id),
      containsAll(<String>['eb-monthly-202611', 'eb-color-warmcool']),
    );
    final finished = seeded.records.firstWhere((b) => b.id == 'eb-monthly-202610');
    expect(finished.finished, isTrue);
    expect(seeded.records.map((b) => b.id), isNot(contains('eb-cast-head')));

    await repository.saveProgress('eb-cast-head', 4);
    final reading = (await shelf()).reading;
    expect(reading.first.id, 'eb-cast-head');
    expect(reading.first.progressFraction, closeTo(0.4, 1e-9));

    await repository.setFavorite('eb-color-warmcool', favorite: false);
    expect(
      (await shelf()).records.map((b) => b.id),
      isNot(contains('eb-color-warmcool')),
    );
  });

  test('bookmarks toggle per page', () async {
    Future<List<int>> bookmarks() async => EbookReading.fromJson(
      (await repository.getProgress('eb-sketch-still')).data,
    ).bookmarks;

    expect(await bookmarks(), [5, 11]);
    await repository.setBookmark('eb-sketch-still', 7, bookmarked: true);
    expect(await bookmarks(), [5, 7, 11]);
    final off = await repository.setBookmark('eb-sketch-still', 5, bookmarked: false);
    expect(EbookReading.fromJson(off.data).bookmarks, [7, 11]);
    final invalid = await repository.setBookmark('eb-sketch-still', 13, bookmarked: true);
    expect(invalid.isSuccess, isFalse);
  });

  test('detail has toc, related books and a 404 for unknown ids', () async {
    final book = await detail('eb-color-landscape');
    expect(book.book.categoryLabel, '色彩教程');
    expect(book.description, isNotEmpty);
    expect(book.toc.first.page, 3);
    expect(book.related, hasLength(4));
    expect(book.related.first.id, 'eb-color-warmcool');
    expect(book.related.map((b) => b.id), isNot(contains('eb-color-landscape')));

    final missing = await repository.getDetail('eb-missing');
    expect(missing.isSuccess, isFalse);
    expect(missing.msg, '书刊不存在或已下架');
  });

  test('search returns records the top bar can route with bookId', () async {
    final response = await repository.searchBooks('  色彩 ');
    final records = (response.data as Map)['records'] as List;
    expect(records, isNotEmpty);
    for (final record in records.cast<Map>()) {
      expect(record['id'], startsWith('eb-'));
      expect(record['title'], isNotEmpty);
    }
  });

  test('collection helper maps 我的收藏 records to book cards', () {
    expect(EbookCollection.type, kDemoEbookFavoriteType);
    final item = EbookCollection.itemOf(<String, dynamic>{
      'id': 'fav100001',
      'type': 12,
      'targetId': 'eb-cast-head',
      'target': <String, dynamic>{
        'title': '石膏头像结构入门（示例）',
        'subtitle': '素描教程 · 王海波',
        'coverImg': 'http://127.0.0.1/a/assets/demo/ebooks/eb-cast-head-cover.jpg',
        'pageCount': 10,
      },
    });
    expect(item?.bookId, 'eb-cast-head');
    expect(item?.subtitle, '素描教程 · 王海波');
    expect(item?.pageCount, 10);
    expect(item?.routeArgs, {'bookId': 'eb-cast-head', 'fromMyCollection': true});
    expect(EbookCollection.itemOf(<String, dynamic>{'type': 11, 'targetId': 'g-1'}), isNull);
  });

  test('fixture matches the generated manifest and page images on disk', () async {
    final manifest =
        jsonDecode(File('tool/ebooks/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(manifest.keys, hasLength(10));
    var totalBytes = 0;
    for (final entry in manifest.entries) {
      final info = entry.value as Map<String, dynamic>;
      final book = EbookDetail.fromJson(
        await handle('/app/ebooks/${entry.key}') as Map,
      );
      expect(book.book.pageCount, info['pageCount'], reason: entry.key);
      expect(
        [for (final t in book.toc) '${t.page} ${t.title}'],
        [for (final t in (info['toc'] as List).cast<Map>()) '${t['page']} ${t['title']}'],
        reason: entry.key,
      );
      final pages = EbookPage.listFrom(
        await handle('/app/ebooks/${entry.key}/pages'),
      );
      expect(pages, hasLength(info['pageCount'] as int));
      final files = [
        'assets/demo/ebooks/${entry.key}-cover.jpg',
        for (final page in pages)
          'assets/demo/ebooks/${entry.key}-p${page.page.toString().padLeft(2, '0')}.jpg',
      ];
      for (final path in files) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: path);
        expect(file.lengthSync(), lessThanOrEqualTo(90 * 1024), reason: path);
        totalBytes += file.lengthSync();
      }
      expect(pages.last.imageUrl, endsWith('${entry.key}-p${pages.length.toString().padLeft(2, '0')}.jpg'));
    }
    expect(totalBytes, lessThanOrEqualTo(6 * 1024 * 1024));
  });
}
