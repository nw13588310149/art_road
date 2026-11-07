import 'package:flutter/foundation.dart';

import '../data/ebook_models.dart';

/// 书刊页路由参数：`{'bookId', 'category'}`，均可选。
@immutable
class EbooksQuery {
  const EbooksQuery({this.bookId = '', this.category = ''});

  /// 直接打开的书刊详情。
  final String bookId;

  /// 分类 key 或中文名称（如 `magazine` / 「期刊」）。
  final String category;

  factory EbooksQuery.fromArgs(Object? raw) {
    if (raw is! Map) {
      return const EbooksQuery();
    }
    String read(String key) {
      final value = raw[key]?.toString().trim() ?? '';
      return value == 'null' ? '' : value;
    }

    final bookId = read('bookId');
    return EbooksQuery(
      bookId: bookId.isNotEmpty ? bookId : read('id'),
      category: read('category'),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EbooksQuery &&
          bookId == other.bookId &&
          category == other.category;

  @override
  int get hashCode => Object.hash(bookId, category);
}

enum EbooksView { browse, shelf }

enum EbookShelfFilter {
  all('全部'),
  reading('在读'),
  favorite('收藏');

  const EbookShelfFilter(this.label);

  final String label;
}

@immutable
class EbooksState {
  const EbooksState({
    required this.categories,
    required this.category,
    required this.keyword,
    required this.sort,
    required this.books,
    required this.total,
    required this.currentPage,
    required this.hasMore,
    required this.loading,
    required this.loadingMore,
    required this.errorMessage,
    required this.featured,
    required this.view,
    required this.shelf,
    required this.shelfLoading,
    required this.shelfFilter,
    required this.detailStack,
    required this.details,
    required this.detailLoading,
    required this.detailErrors,
  });

  factory EbooksState.fromQuery(EbooksQuery query) {
    return EbooksState(
      categories: const <EbookCategory>[],
      category: query.category.isEmpty ? EbookCategory.allKey : query.category,
      keyword: '',
      sort: EbookSort.recommend,
      books: const <EbookSummary>[],
      total: 0,
      currentPage: 0,
      hasMore: true,
      loading: true,
      loadingMore: false,
      errorMessage: '',
      featured: const <EbookSummary>[],
      view: EbooksView.browse,
      shelf: EbookShelf.empty,
      shelfLoading: false,
      shelfFilter: EbookShelfFilter.all,
      detailStack: query.bookId.isEmpty
          ? const <String>[]
          : <String>[query.bookId],
      details: const <String, EbookDetail>{},
      detailLoading: const <String>{},
      detailErrors: const <String, String>{},
    );
  }

  final List<EbookCategory> categories;
  final String category;
  final String keyword;
  final EbookSort sort;
  final List<EbookSummary> books;
  final int total;
  final int currentPage;
  final bool hasMore;
  final bool loading;
  final bool loadingMore;
  final String errorMessage;

  /// 编辑推荐。
  final List<EbookSummary> featured;
  final EbooksView view;
  final EbookShelf shelf;
  final bool shelfLoading;
  final EbookShelfFilter shelfFilter;

  /// 详情页栈：从相关书刊继续打开时逐层返回。
  final List<String> detailStack;
  final Map<String, EbookDetail> details;
  final Set<String> detailLoading;
  final Map<String, String> detailErrors;

  String? get openBookId => detailStack.isEmpty ? null : detailStack.last;

  bool get hasFilters =>
      keyword.isNotEmpty || category != EbookCategory.allKey;

  List<EbookSummary> get shelfItems => switch (shelfFilter) {
    EbookShelfFilter.all => shelf.records,
    EbookShelfFilter.reading => shelf.reading,
    EbookShelfFilter.favorite => shelf.favorites,
  };

  String categoryLabelOf(String key) {
    for (final c in categories) {
      if (c.key == key) {
        return c.label;
      }
    }
    return '';
  }

  EbooksState copyWith({
    List<EbookCategory>? categories,
    String? category,
    String? keyword,
    EbookSort? sort,
    List<EbookSummary>? books,
    int? total,
    int? currentPage,
    bool? hasMore,
    bool? loading,
    bool? loadingMore,
    String? errorMessage,
    List<EbookSummary>? featured,
    EbooksView? view,
    EbookShelf? shelf,
    bool? shelfLoading,
    EbookShelfFilter? shelfFilter,
    List<String>? detailStack,
    Map<String, EbookDetail>? details,
    Set<String>? detailLoading,
    Map<String, String>? detailErrors,
  }) {
    return EbooksState(
      categories: categories ?? this.categories,
      category: category ?? this.category,
      keyword: keyword ?? this.keyword,
      sort: sort ?? this.sort,
      books: books ?? this.books,
      total: total ?? this.total,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      errorMessage: errorMessage ?? this.errorMessage,
      featured: featured ?? this.featured,
      view: view ?? this.view,
      shelf: shelf ?? this.shelf,
      shelfLoading: shelfLoading ?? this.shelfLoading,
      shelfFilter: shelfFilter ?? this.shelfFilter,
      detailStack: detailStack ?? this.detailStack,
      details: details ?? this.details,
      detailLoading: detailLoading ?? this.detailLoading,
      detailErrors: detailErrors ?? this.detailErrors,
    );
  }
}
