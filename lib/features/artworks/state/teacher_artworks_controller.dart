import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../data/artwork_models.dart';
import '../data/artwork_repository.dart';

const _pageSize = 20;

@immutable
class TeacherArtworksState {
  const TeacherArtworksState({
    this.loading = true,
    this.loaded = false,
    this.loadingList = false,
    this.loadingMore = false,
    this.stats = const ArtworkStats(),
    this.filter = ArtworkStatusFilter.pending,
    this.keyword = '',
    this.items = const <ArtworkSummary>[],
    this.page = 0,
    this.total = 0,
    this.hasMore = false,
    this.errorMessage = '',
  });

  final bool loading;
  final bool loaded;
  final bool loadingList;
  final bool loadingMore;

  /// 按「我的点评状态」统计。
  final ArtworkStats stats;
  final ArtworkStatusFilter filter;
  final String keyword;
  final List<ArtworkSummary> items;
  final int page;
  final int total;
  final bool hasMore;
  final String errorMessage;

  TeacherArtworksState copyWith({
    bool? loading,
    bool? loaded,
    bool? loadingList,
    bool? loadingMore,
    ArtworkStats? stats,
    ArtworkStatusFilter? filter,
    String? keyword,
    List<ArtworkSummary>? items,
    int? page,
    int? total,
    bool? hasMore,
    String? errorMessage,
  }) {
    return TeacherArtworksState(
      loading: loading ?? this.loading,
      loaded: loaded ?? this.loaded,
      loadingList: loadingList ?? this.loadingList,
      loadingMore: loadingMore ?? this.loadingMore,
      stats: stats ?? this.stats,
      filter: filter ?? this.filter,
      keyword: keyword ?? this.keyword,
      items: items ?? this.items,
      page: page ?? this.page,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final teacherArtworksControllerProvider =
    StateNotifierProvider.autoDispose<
      TeacherArtworksController,
      TeacherArtworksState
    >((ref) {
      final repository = ref.watch(artworkRepositoryProvider);
      return TeacherArtworksController(repository: repository);
    });

class TeacherArtworksController extends StateNotifier<TeacherArtworksState> {
  TeacherArtworksController({required ArtworkRepository repository})
    : _repository = repository,
      super(const TeacherArtworksState()) {
    unawaited(refresh());
  }

  final ArtworkRepository _repository;
  int _generation = 0;

  Future<void> refresh() async {
    final generation = ++_generation;
    state = state.copyWith(loading: true, errorMessage: '');
    final results = await Future.wait(<Future<ApiResponse>>[
      _repository.getTeacherStatistics(),
      _fetchPage(1),
    ]);
    if (!mounted) {
      return;
    }
    final [stats, list] = results;
    final listCurrent = generation == _generation;
    final failed = results.where((r) => !r.isSuccess).firstOrNull;
    final page = listCurrent && list.isSuccess
        ? ArtworkPage.fromJson(list.data)
        : null;
    state = state.copyWith(
      loading: false,
      loaded: true,
      stats: stats.isSuccess ? ArtworkStats.fromJson(stats.data) : null,
      items: page?.records,
      page: page?.current,
      total: page?.total,
      hasMore: page?.hasMore,
      errorMessage: failed?.errorOr('作品加载失败，请稍后重试') ?? '',
    );
  }

  Future<void> setFilter(ArtworkStatusFilter filter) async {
    if (filter == state.filter) {
      return;
    }
    state = state.copyWith(filter: filter);
    await _loadList(reset: true);
  }

  Future<void> setKeyword(String keyword) async {
    final value = keyword.trim();
    if (value == state.keyword) {
      return;
    }
    state = state.copyWith(keyword: value);
    await _loadList(reset: true);
  }

  Future<void> loadMore() async {
    if (state.loading ||
        state.loadingList ||
        state.loadingMore ||
        !state.hasMore) {
      return;
    }
    await _loadList(reset: false);
  }

  /// 「开始点评」：取第一份待我点评的作品。
  Future<({String? id, String error})> firstPendingId() async {
    final response = await _repository.getTeacherArtworks(
      status: ArtworkStatusFilter.pending,
      page: 1,
      size: 1,
    );
    if (!response.isSuccess) {
      return (id: null, error: response.errorOr('获取待点评作品失败，请稍后重试'));
    }
    final records = ArtworkPage.fromJson(response.data).records;
    return (id: records.isEmpty ? null : records.first.id, error: '');
  }

  Future<ApiResponse> _fetchPage(int page) => _repository.getTeacherArtworks(
    status: state.filter,
    keyword: state.keyword,
    page: page,
    size: _pageSize,
  );

  Future<void> _loadList({required bool reset}) async {
    final generation = reset ? ++_generation : _generation;
    final page = reset ? 1 : state.page + 1;
    state = state.copyWith(
      loadingList: reset,
      loadingMore: !reset,
      items: reset ? const <ArtworkSummary>[] : null,
      errorMessage: '',
    );
    final response = await _fetchPage(page);
    if (!mounted || generation != _generation) {
      return;
    }
    if (!response.isSuccess) {
      state = state.copyWith(
        loadingList: false,
        loadingMore: false,
        errorMessage: response.errorOr('作品加载失败，请稍后重试'),
      );
      return;
    }
    final result = ArtworkPage.fromJson(response.data);
    final known = reset ? <String>{} : state.items.map((e) => e.id).toSet();
    state = state.copyWith(
      loadingList: false,
      loadingMore: false,
      items: <ArtworkSummary>[
        if (!reset) ...state.items,
        ...result.records.where((e) => known.add(e.id)),
      ],
      page: result.current,
      total: result.total,
      hasMore: result.hasMore,
    );
  }

  void clearError() {
    state = state.copyWith(errorMessage: '');
  }
}
