import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/artwork_models.dart';
import '../data/artwork_repository.dart';

const _pageSize = 24;

@immutable
class StudentArtworksState {
  const StudentArtworksState({
    this.loading = true,
    this.loaded = false,
    this.loadingList = false,
    this.loadingMore = false,
    this.stats = const ArtworkStats(),
    this.insights = const ArtworkInsights(),
    this.filter = ArtworkStatusFilter.all,
    this.items = const <ArtworkSummary>[],
    this.page = 0,
    this.total = 0,
    this.hasMore = false,
    this.errorMessage = '',
  });

  /// 整页刷新中（统计、高频问题、列表）。
  final bool loading;

  /// 首次加载已完成（之后刷新不再展示整页 loading）。
  final bool loaded;

  /// 切换筛选后重新拉取列表。
  final bool loadingList;
  final bool loadingMore;
  final ArtworkStats stats;
  final ArtworkInsights insights;
  final ArtworkStatusFilter filter;
  final List<ArtworkSummary> items;
  final int page;
  final int total;
  final bool hasMore;
  final String errorMessage;

  StudentArtworksState copyWith({
    bool? loading,
    bool? loaded,
    bool? loadingList,
    bool? loadingMore,
    ArtworkStats? stats,
    ArtworkInsights? insights,
    ArtworkStatusFilter? filter,
    List<ArtworkSummary>? items,
    int? page,
    int? total,
    bool? hasMore,
    String? errorMessage,
  }) {
    return StudentArtworksState(
      loading: loading ?? this.loading,
      loaded: loaded ?? this.loaded,
      loadingList: loadingList ?? this.loadingList,
      loadingMore: loadingMore ?? this.loadingMore,
      stats: stats ?? this.stats,
      insights: insights ?? this.insights,
      filter: filter ?? this.filter,
      items: items ?? this.items,
      page: page ?? this.page,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final studentArtworksControllerProvider =
    StateNotifierProvider.autoDispose<
      StudentArtworksController,
      StudentArtworksState
    >((ref) {
      final repository = ref.watch(artworkRepositoryProvider);
      return StudentArtworksController(repository: repository);
    });

class StudentArtworksController extends StateNotifier<StudentArtworksState> {
  StudentArtworksController({required ArtworkRepository repository})
    : _repository = repository,
      super(const StudentArtworksState()) {
    unawaited(refresh());
  }

  final ArtworkRepository _repository;

  /// 丢弃过期响应：每次重新拉取列表都会递增。
  int _generation = 0;

  Future<void> refresh() async {
    final generation = ++_generation;
    state = state.copyWith(loading: true, errorMessage: '');
    final results = await Future.wait([
      _repository.getStatistics(),
      _repository.getInsights(),
      _repository.getArtworks(status: state.filter, page: 1, size: _pageSize),
    ]);
    if (!mounted) {
      return;
    }
    final [stats, insights, list] = results;
    // 期间切换了筛选：列表以新的请求为准，统计与高频问题照常更新。
    final listCurrent = generation == _generation;
    final failed = results.where((r) => !r.isSuccess).firstOrNull;
    final page = listCurrent && list.isSuccess
        ? ArtworkPage.fromJson(list.data)
        : null;
    state = state.copyWith(
      loading: false,
      loaded: true,
      stats: stats.isSuccess ? ArtworkStats.fromJson(stats.data) : null,
      insights: insights.isSuccess
          ? ArtworkInsights.fromJson(insights.data)
          : null,
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
    state = state.copyWith(
      filter: filter,
      items: const <ArtworkSummary>[],
      page: 0,
      total: 0,
      hasMore: false,
    );
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

  Future<void> _loadList({required bool reset}) async {
    final generation = reset ? ++_generation : _generation;
    final page = reset ? 1 : state.page + 1;
    state = state.copyWith(
      loadingList: reset,
      loadingMore: !reset,
      errorMessage: '',
    );
    final response = await _repository.getArtworks(
      status: state.filter,
      page: page,
      size: _pageSize,
    );
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

  /// 依次上传照片再提交作品；成功返回 null，失败返回提示文案。
  ///
  /// [uploaded] 记录已上传成功的照片，重试时跳过，避免重复上传。
  Future<String?> submit(
    ArtworkDraft draft, {
    required Map<ArtworkDraftImage, String> uploaded,
    void Function(int done, int total)? onProgress,
  }) async {
    final total = draft.images.length;
    final imageIds = <String>[];
    for (var i = 0; i < total; i++) {
      final image = draft.images[i];
      final cached = uploaded[image];
      if (cached != null) {
        imageIds.add(cached);
        continue;
      }
      onProgress?.call(i, total);
      final response = await _repository.uploadImage(image.bytes, image.name);
      final id = response.isSuccess ? artworkIdOf(response.data) : '';
      if (id.isEmpty) {
        return response.errorOr('第 ${i + 1} 张照片上传失败，请重试');
      }
      uploaded[image] = id;
      imageIds.add(id);
    }
    onProgress?.call(total, total);
    final response = await _repository.createArtwork(
      title: draft.title,
      subject: draft.subject,
      drawingDate: draft.drawingDate,
      description: draft.description,
      imageIds: imageIds,
    );
    if (!response.isSuccess) {
      return response.errorOr('作品提交失败，请稍后重试');
    }
    if (mounted) {
      unawaited(refresh());
    }
    return null;
  }

  void clearError() {
    state = state.copyWith(errorMessage: '');
  }
}
