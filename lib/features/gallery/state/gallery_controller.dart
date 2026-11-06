import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gallery_models.dart';
import '../data/gallery_repository.dart';
import 'gallery_state.dart';

final galleryControllerProvider = StateNotifierProvider.autoDispose
    .family<GalleryController, GalleryState, GalleryQuery>((ref, query) {
      final repository = ref.watch(galleryRepositoryProvider);
      return GalleryController(repository: repository, query: query);
    });

class GalleryController extends StateNotifier<GalleryState> {
  GalleryController({
    required GalleryRepository repository,
    required GalleryQuery query,
  }) : _repository = repository,
       super(GalleryState.fromQuery(query)) {
    unawaited(_bootstrap(query.workId));
  }

  static const pageSize = 12;

  final GalleryRepository _repository;

  /// 筛选条件变化时递增，丢弃过期的列表 / 分类响应。
  int _listToken = 0;
  int _categoryToken = 0;

  Future<void> _bootstrap(String workId) async {
    await Future.wait<void>([
      _loadCategories(),
      _loadPage(reset: true),
      if (workId.isNotEmpty) _loadDetail(workId),
    ]);
  }

  Future<void> refresh() async {
    await Future.wait<void>([_loadCategories(), _loadPage(reset: true)]);
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) {
      return;
    }
    await _loadPage(reset: false);
  }

  void setSubject(String subject) {
    if (subject == state.subject) {
      return;
    }
    final current = state.categoryByKey(state.category);
    final keepCategory =
        current == null ||
        current.subject == null ||
        current.subject == subject;
    state = state.copyWith(
      subject: subject,
      category: keepCategory ? state.category : GalleryCategory.allKey,
    );
    unawaited(_loadCategories());
    unawaited(_loadPage(reset: true));
  }

  /// 选中某科目的分类时同步切换科目页签。
  void setCategory(String key) {
    if (key == state.category) {
      return;
    }
    final subject = state.categoryByKey(key)?.subject ?? state.subject;
    final subjectChanged = subject != state.subject;
    state = state.copyWith(category: key, subject: subject);
    if (subjectChanged) {
      unawaited(_loadCategories());
    }
    unawaited(_loadPage(reset: true));
  }

  void setSort(GallerySort sort) {
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
    final subjectChanged = state.subject.isNotEmpty;
    state = state.copyWith(
      subject: '',
      category: GalleryCategory.allKey,
      keyword: '',
    );
    if (subjectChanged) {
      unawaited(_loadCategories());
    }
    unawaited(_loadPage(reset: true));
  }

  void clearError() {
    if (state.errorMessage.isNotEmpty) {
      state = state.copyWith(errorMessage: '');
    }
  }

  Future<void> _loadCategories() async {
    final token = ++_categoryToken;
    final response = await _repository.getCategories(subject: state.subject);
    if (!mounted || token != _categoryToken || !response.isSuccess) {
      return;
    }
    final raw = response.data;
    final categories = raw is List
        ? [
            for (final item in raw)
              if (item is Map) GalleryCategory.fromJson(item),
          ]
        : const <GalleryCategory>[];
    var category = state.category;
    var subject = state.subject;
    GalleryCategory? match;
    for (final c in categories) {
      if (c.key == category || c.label == category) {
        match = c;
        break;
      }
    }
    if (match == null) {
      category = GalleryCategory.allKey;
    } else {
      category = match.key;
      subject = match.subject ?? subject;
    }
    final subjectChanged = subject != state.subject;
    state = state.copyWith(
      categories: categories,
      category: category,
      subject: subject,
    );
    if (subjectChanged) {
      unawaited(_loadCategories());
    }
  }

  Future<void> _loadPage({required bool reset}) async {
    final token = reset ? ++_listToken : _listToken;
    final page = reset ? 1 : state.currentPage + 1;
    state = state.copyWith(
      loading: reset,
      loadingMore: !reset,
      errorMessage: '',
    );
    final response = await _repository.getWorks(
      category: state.category,
      subject: state.subject,
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
            ? '范画加载失败，请稍后重试'
            : response.displayMsg,
      );
      return;
    }
    final result = GalleryWorksPage.fromJson(response.data);
    final works = reset
        ? result.records
        : <GalleryWork>[
            ...state.works,
            for (final work in result.records)
              if (!state.works.any((w) => w.id == work.id)) work,
          ];
    state = state.copyWith(
      loading: false,
      loadingMore: false,
      works: works,
      total: result.total,
      currentPage: page,
      hasMore: result.records.isNotEmpty && works.length < result.total,
    );
  }

  // ── 详情 ──────────────────────────────────────────────────────────────

  void openDetail(String id) {
    if (id.isEmpty || state.openWorkId == id) {
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
    final id = state.openWorkId;
    if (id != null) {
      await _loadDetail(id);
    }
  }

  Future<void> _loadDetail(String id) async {
    if (state.detailLoading.contains(id)) {
      return;
    }
    state = state.copyWith(
      detailLoading: {...state.detailLoading, id},
      detailErrors: {...state.detailErrors}..remove(id),
    );
    final response = await _repository.getWorkDetail(id);
    if (!mounted) {
      return;
    }
    final loading = {...state.detailLoading}..remove(id);
    final data = response.data;
    if (!response.isSuccess || data is! Map) {
      state = state.copyWith(
        detailLoading: loading,
        detailErrors: {
          ...state.detailErrors,
          id: response.displayMsg.isEmpty ? '作品加载失败' : response.displayMsg,
        },
      );
      return;
    }
    final detail = GalleryWorkDetail.fromJson(data);
    state = state.copyWith(
      detailLoading: loading,
      details: {...state.details, id: detail},
      works: [
        for (final w in state.works)
          w.id == id
              ? w.copyWith(
                  views: detail.work.views,
                  favorite: detail.work.favorite,
                )
              : w,
      ],
    );
  }

  /// 收藏 / 取消收藏（先乐观更新，失败回滚）；返回是否成功。
  Future<bool> toggleFavorite(GalleryWork work) async {
    final target = !work.favorite;
    _applyFavorite(work.id, target);
    final response = await _repository.setFavorite(work.id, favorite: target);
    if (!mounted) {
      return false;
    }
    if (!response.isSuccess) {
      _applyFavorite(work.id, !target);
      return false;
    }
    final data = response.data;
    final confirmed = data is Map && data['favorite'] is bool
        ? data['favorite'] as bool
        : target;
    if (confirmed != target) {
      _applyFavorite(work.id, confirmed);
    }
    return true;
  }

  void _applyFavorite(String id, bool favorite) {
    state = state.copyWith(
      works: [
        for (final w in state.works)
          w.id == id ? w.copyWith(favorite: favorite) : w,
      ],
      details: {
        for (final entry in state.details.entries)
          entry.key: entry.value.withFavorite(id, favorite),
      },
    );
  }
}
