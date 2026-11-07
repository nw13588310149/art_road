import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';
import 'ebook_models.dart';

final ebookRepositoryProvider = Provider<EbookRepository>((ref) {
  return EbookRepository(client: ref.watch(apiClientProvider));
});

class EbookRepository {
  EbookRepository({required this.client});

  final ApiClient client;

  /// 分类及书刊数。
  Future<ApiResponse> getCategories() {
    return client.get('/app/ebooks/categories');
  }

  /// 书刊列表（标准分页）；[featured] 只返回「编辑推荐」。
  Future<ApiResponse> getBooks({
    String category = '',
    String keyword = '',
    EbookSort sort = EbookSort.recommend,
    bool featured = false,
    int current = 1,
    int size = 12,
  }) {
    return client.get(
      '/app/ebooks',
      queryParameters: <String, dynamic>{
        if (category.isNotEmpty && category != EbookCategory.allKey)
          'category': category,
        if (keyword.isNotEmpty) 'keyword': keyword,
        'sort': sort.key,
        if (featured) 'featured': true,
        'current': current,
        'size': size,
      },
    );
  }

  /// 顶部全局搜索：返回标准分页 `{records: [{id, title, …}]}`，
  /// 点击结果以 `{'bookId': id}` 打开书刊页。
  Future<ApiResponse> searchBooks(String keyword, {int size = 30}) {
    return getBooks(keyword: keyword.trim(), size: size);
  }

  /// 详情：目录、相关书刊、页数、个人进度与收藏状态。
  Future<ApiResponse> getDetail(String id) {
    return client.get('/app/ebooks/${Uri.encodeComponent(id)}');
  }

  Future<ApiResponse> getPages(String id) {
    return client.get('/app/ebooks/${Uri.encodeComponent(id)}/pages');
  }

  /// 阅读进度 `{page, updatedAt, bookmarks}`。
  Future<ApiResponse> getProgress(String id) {
    return client.get('/app/ebooks/${Uri.encodeComponent(id)}/progress');
  }

  Future<ApiResponse> saveProgress(String id, int page) {
    return client.post(
      '/app/ebooks/${Uri.encodeComponent(id)}/progress',
      data: <String, dynamic>{'page': page},
    );
  }

  Future<ApiResponse> setFavorite(String id, {required bool favorite}) {
    return client.post(
      '/app/ebooks/${Uri.encodeComponent(id)}/favorite',
      data: <String, dynamic>{'favorite': favorite},
    );
  }

  /// 书签开关，返回 `{bookmarks: [页码…]}`。
  Future<ApiResponse> setBookmark(
    String id,
    int page, {
    required bool bookmarked,
  }) {
    return client.post(
      '/app/ebooks/${Uri.encodeComponent(id)}/bookmarks',
      data: <String, dynamic>{'page': page, 'bookmarked': bookmarked},
    );
  }

  /// 我的书架：收藏与读过的书刊。
  Future<ApiResponse> getShelf() {
    return client.get('/app/ebooks/shelf');
  }
}
