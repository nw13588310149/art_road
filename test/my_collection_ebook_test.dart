import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/core/network/api_client.dart';
import 'package:the_road_of_art_flutter/core/network/api_response.dart';
import 'package:the_road_of_art_flutter/features/ebooks/data/ebook_collection.dart';
import 'package:the_road_of_art_flutter/features/my_collection/data/my_collection_repository.dart';
import 'package:the_road_of_art_flutter/features/my_collection/state/my_collection_controller.dart';
import 'package:the_road_of_art_flutter/features/my_collection/state/my_collection_state.dart';

class _FakeRepository implements MyCollectionRepository {
  _FakeRepository(this.items);

  final List<Map<String, dynamic>> items;

  @override
  ApiClient get client => throw UnimplementedError();

  @override
  Future<ApiResponse> getCategories() async => const ApiResponse(
    code: 0,
    msg: '',
    data: <Map<String, dynamic>>[
      {'id': 0, 'name': '全部'},
      {'id': 11, 'name': '范画'},
      {'id': 6, 'name': '视频'},
      {'id': 9, 'name': '资讯'},
      {'id': 12, 'name': '书刊'},
    ],
  );

  @override
  Future<ApiResponse> getItems({required int type}) async =>
      ApiResponse(code: 0, msg: '', data: items);

  @override
  Future<ApiResponse> removeFavorite({
    required String targetId,
    required int type,
  }) async => const ApiResponse(code: 0, msg: '');

  @override
  Future<ApiResponse> getClassList() async =>
      const ApiResponse(code: 0, msg: '', data: <Object>[]);

  @override
  Future<ApiResponse> shareToClass({
    required String classId,
    required int type,
    required Map<String, dynamic> payload,
  }) async => const ApiResponse(code: 0, msg: '');
}

Map<String, dynamic> _ebookRecord({int type = 12}) => <String, dynamic>{
  'id': 'fav-1',
  'type': type,
  'targetId': 'eb-color-warmcool',
  'target': <String, dynamic>{
    'id': 'eb-color-warmcool',
    'bookId': 'eb-color-warmcool',
    'title': '冷暖色调入门',
    'subtitle': '色彩教程 · 刘芳',
    'coverImg': 'https://example.com/cover.jpg',
    'pageCount': 24,
  },
};

Future<MyCollectionState> _load(List<Map<String, dynamic>> items) async {
  final container = ProviderContainer(
    overrides: [
      myCollectionRepositoryProvider.overrideWithValue(
        _FakeRepository(items),
      ),
    ],
  );
  addTearDown(container.dispose);
  final sub = container.listen(myCollectionControllerProvider, (_, _) {});
  addTearDown(sub.close);
  await container.read(myCollectionControllerProvider.notifier).refresh();
  return container.read(myCollectionControllerProvider);
}

void main() {
  test('书刊收藏类型、页签与接口分类名一致', () {
    expect(CollectionType.ebook, EbookCollection.type);
    expect(kCollectionTypeByLabel['书刊'], 12);
    expect(CollectionType.labelOf(CollectionType.ebook), '书刊');
    expect(kCollectionDefaultTabs.map((tab) => tab.label), <String>[
      '全部',
      '范画',
      '视频',
      '资讯',
      '书刊',
    ]);
  });

  test('书刊收藏记录按 EbookCollection.itemOf 解析成卡片', () async {
    final state = await _load([_ebookRecord()]);

    expect(state.tabs.map((tab) => tab.type), contains(CollectionType.ebook));
    expect(state.items, hasLength(1));
    final entry = state.items.single;
    expect(entry.isEbook, isTrue);
    expect(entry.targetId, 'eb-color-warmcool');
    expect(entry.title, '冷暖色调入门');
    expect(entry.subtitle, '色彩教程 · 刘芳');
    expect(entry.coverUrl, 'https://example.com/cover.jpg');
    expect(entry.rawPayload['id'], 'eb-color-warmcool');
    expect(entry.rawPayload['pageCount'], 24);
    expect(EbookCollection.routeArgs(entry.targetId), <String, dynamic>{
      'bookId': 'eb-color-warmcool',
      'fromMyCollection': true,
    });
  });

  test('缺少书刊 id 的记录被跳过', () async {
    final record = _ebookRecord()
      ..['targetId'] = ''
      ..['target'] = <String, dynamic>{'title': '没有 id 的书刊'};
    final state = await _load([record]);

    expect(state.items, isEmpty);
  });
}
