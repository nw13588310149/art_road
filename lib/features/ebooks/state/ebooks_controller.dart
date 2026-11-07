import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ebook_models.dart';
import '../data/ebook_repository.dart';
import 'ebooks_state.dart';

final ebooksControllerProvider = StateNotifierProvider.autoDispose
    .family<EbooksController, EbooksState, EbooksQuery>((ref, query) {
      final repository = ref.watch(ebookRepositoryProvider);
      return EbooksController(repository: repository, query: query);
    });

class EbooksController extends StateNotifier<EbooksState> {
  EbooksController({
    required EbookRepository repository,
    required EbooksQuery query,
  }) : _repository = repository,
       super(EbooksState.fromQuery(query)) {
    unawaited(_bootstrap(query.bookId));
  }

  static const pageSize = 12;

  final EbookRepository _repository;

  /// 筛选条件变化时递增，丢弃过期的列表 / 书架响应。
  int _listToken = 0;
  int _shelfToken = 0;

  Future<void> _bootstrap(String bookId) async {
    await Future.wait<void>([
      _loadCategories(),
      _loadFeatured(),
      _loadPage(reset: true),
      _loadShelf(),
      if (bookId.isNotEmpty) _loadDetail(bookId),
    ]);
  }

  Future<void> refresh() async {
    await Future.wait<void>([
      _loadCategories(),
      _loadFeatured(),
      _loadPage(reset: true),
      _loadShelf(),
    ]);
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) {
      return;
    }
    await _loadPage(reset: false);
  }

  void setCategory(String key) {
    if (key == state.category) {
      return;
    }
    state = state.copyWith(category: key);
    unawaited(_loadPage(reset: true));
  }

  void setSort(EbookSort sort) {
    if (sort == state.sort) {
      return;
    }
    state = state.copyWith(sort: sort);
    unawaited(_loadPage(reset: true));
  }

  void setKeyword(String keyword) {
    final value = keyword.trim();
    if (value == state.keyword) {
      return;
    }
    state = state.copyWith(keyword: value);
    unawaited(_loadPage(reset: true));
  }

  void resetFilters() {
    if (!state.hasFilters) {
      return;
    }
    state = state.copyWith(category: EbookCategory.allKey, keyword: '');
    unawaited(_loadPage(reset: true));
  }

  void setView(EbooksView view) {
    if (view == state.view) {
      return;
    }
    state = state.copyWith(view: view);
    if (view == EbooksView.shelf) {
      unawaited(_loadShelf());
    }
  }

  void setShelfFilter(EbookShelfFilter filter) {
    if (filter != state.shelfFilter) {
      state = state.copyWith(shelfFilter: filter);
    }
  }

  void clearError() {
    if (state.errorMessage.isNotEmpty) {
      state = state.copyWith(errorMessage: '');
    }
  }

  Future<void> _loadCategories() async {
    final response = await _repository.getCategories();
    if (!mounted || !response.isSuccess) {
      return;
    }
    final categories = EbookCategory.listFrom(response.data);
    EbookCategory? match;
    for (final c in categories) {
      if (c.key == state.category || c.label == state.category) {
        match = c;
        break;
      }
    }
    final unknown = match == null && state.category != EbookCategory.allKey;
    state = state.copyWith(
      categories: categories,
      category: match?.key ?? EbookCategory.allKey,
    );
    if (unknown) {
      unawaited(_loadPage(reset: true));
    }
  }

  Future<void> _loadFeatured() async {
    final response = await _repository.getBooks(featured: true, size: 3);
    if (!mounted || !response.isSuccess) {
      return;
    }
    state = state.copyWith(
      featured: EbookListPage.fromJson(response.data).records,
    );
  }

  Future<void> _loadPage({required bool reset}) async {
    final token = reset ? ++_listToken : _listToken;
    final page = reset ? 1 : state.currentPage + 1;
    state = state.copyWith(
      loading: reset,
      loadingMore: !reset,
      errorMessage: '',
    );
    final response = await _repository.getBooks(
      category: state.category,
      keyword: state.keyword,
      sort: state.sort,
      current: page,
      size: pageSize,
    );
    if (!mounted || token != _listToken) {
      return;
    }
    if (!response.isSuccess) {
      state = state.copyWith(
        loading: false,
        loadingMore: false,
        errorMessage: response.displayMsg.isEmpty
            ? '书刊加载失败，请稍后重试'
            : response.displayMsg,
      );
      return;
    }
    final result = EbookListPage.fromJson(response.data);
    final books = reset
        ? result.records
        : <EbookSummary>[
            ...state.books,
            for (final book in result.records)
              if (!state.books.any((b) => b.id == book.id)) book,
          ];
    state = state.copyWith(
      loading: false,
      loadingMore: false,
      books: books,
      total: result.total,
      currentPage: page,
      hasMore: result.records.isNotEmpty && books.length < result.total,
    );
  }

  Future<void> _loadShelf() async {
    final token = ++_shelfToken;
    state = state.copyWith(shelfLoading: true);
    final response = await _repository.getShelf();
    if (!mounted || token != _shelfToken) {
      return;
    }
    state = state.copyWith(
      shelfLoading: false,
      shelf: response.isSuccess ? EbookShelf.fromJson(response.data) : null,
    );
  }

  // ── 详情 ──────────────────────────────────────────────────────────────

  void openDetail(String id) {
    if (id.isEmpty || state.openBookId == id) {
      return;
    }
    state = state.copyWith(detailStack: [...state.detailStack, id]);
    if (!state.details.containsKey(id)) {
      unawaited(_loadDetail(id));
    }
  }

  void closeDetail() {
    if (state.detailStack.isEmpty) {
      return;
    }
    state = state.copyWith(
      detailStack: state.detailStack.sublist(0, state.detailStack.length - 1),
    );
  }

  void closeAllDetails() {
    if (state.detailStack.isNotEmpty) {
      state = state.copyWith(detailStack: const <String>[]);
    }
  }

  Future<void> retryDetail() async {
    final id = state.openBookId;
    if (id != null) {
      await _loadDetail(id);
    }
  }

  /// [silent] 时保留当前详情、不显示加载态（阅读后刷新进度用）。
  Future<void> _loadDetail(String id, {bool silent = false}) async {
    if (!silent && state.detailLoading.contains(id)) {
      return;
    }
    if (!silent) {
      state = state.copyWith(
        detailLoading: {...state.detailLoading, id},
        detailErrors: {...state.detailErrors}..remove(id),
      );
    }
    final response = await _repository.getDetail(id);
    if (!mounted) {
      return;
    }
    final loading = {...state.detailLoading}..remove(id);
    final data = response.data;
    if (!response.isSuccess || data is! Map) {
      if (silent) {
        return;
      }
      state = state.copyWith(
        detailLoading: loading,
        detailErrors: {
          ...state.detailErrors,
          id: response.displayMsg.isEmpty ? '书刊加载失败' : response.displayMsg,
        },
      );
      return;
    }
    final detail = EbookDetail.fromJson(data);
    final book = detail.book;
    state = state.copyWith(
      detailLoading: loading,
      details: {...state.details, id: detail},
      books: [
        for (final b in state.books)
          b.id == id ? b.copyWith(favorite: book.favorite, progress: book.progress) : b,
      ],
    );
  }

  /// 收藏 / 取消收藏（先乐观更新，失败回滚）；返回是否成功。
  Future<bool> toggleFavorite(EbookSummary book) async {
    final target = !book.favorite;
    _applyFavorite(book, target);
    final response = await _repository.setFavorite(book.id, favorite: target);
    if (!mounted) {
      return false;
    }
    if (!response.isSuccess) {
      _applyFavorite(book, !target);
      return false;
    }
    return true;
  }

  void _applyFavorite(EbookSummary book, bool favorite) {
    EbookSummary apply(EbookSummary b) =>
        b.id == book.id ? b.copyWith(favorite: favorite) : b;
    state = state.copyWith(
      books: [for (final b in state.books) apply(b)],
      featured: [for (final b in state.featured) apply(b)],
      shelf: state.shelf.withFavorite(book, favorite),
      details: {
        for (final entry in state.details.entries)
          entry.key: entry.value.withFavorite(book.id, favorite),
      },
    );
  }

  /// 阅读器关闭后：先用带回的进度即时更新，再从后端刷新书架与详情。
  Future<void> applyReading(String bookId, EbookProgress? progress) async {
    if (progress != null) {
      EbookSummary apply(EbookSummary b) =>
          b.id == bookId ? b.copyWith(progress: progress) : b;
      state = state.copyWith(
        books: [for (final b in state.books) apply(b)],
        featured: [for (final b in state.featured) apply(b)],
        shelf: state.shelf.withProgress(bookId, progress),
        details: {
          for (final entry in state.details.entries)
            entry.key: entry.value.withProgress(bookId, progress),
        },
      );
    }
    await Future.wait<void>([
      _loadShelf(),
      if (state.details.containsKey(bookId)) _loadDetail(bookId, silent: true),
    ]);
  }
}
