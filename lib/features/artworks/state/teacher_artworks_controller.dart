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
    this.listFailed = false,
    this.errorMessage = '',
  });

  final bool loading;
  final bool loaded;

  /// 列表首屏加载失败（没有可展示的旧数据），页面显示错误状态。
  final bool listFailed;
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
    bool? listFailed,
    String? errorMessage,
  }) {
    return TeacherArtworksState(
      listFailed: listFailed ?? this.listFailed,
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

/// 组内复核队列（科目组长）：与「我的点评」同一套列表状态，接口换成组长端。
final leadArtworksControllerProvider =
    StateNotifierProvider.autoDispose<
      TeacherArtworksController,
      TeacherArtworksState
    >((ref) {
      final repository = ref.watch(artworkRepositoryProvider);
      return TeacherArtworksController(repository: repository, lead: true);
    });

/// 当前账号的科目组长信息：是否为组长、科目组名称、待复核数量。
@immutable
class ArtworkLeadInfo {
  const ArtworkLeadInfo({
    this.isLead = false,
    this.groupName = '',
    this.pending = 0,
  });

  factory ArtworkLeadInfo.fromJson(Object? raw) {
    final json = raw is Map ? raw : const <Object?, Object?>{};
    final pending = json['pending'];
    return ArtworkLeadInfo(
      isLead: json['isLead'] == true,
      groupName: json['groupName']?.toString() ?? '',
      pending: pending is num ? pending.toInt() : 0,
    );
  }

  final bool isLead;
  final String groupName;
  final int pending;
}

/// 接口失败时按「不是组长」处理，不影响老师自己的点评队列。
final artworkLeadInfoProvider = FutureProvider.autoDispose<ArtworkLeadInfo>((
  ref,
) async {
  final response = await ref
      .watch(artworkRepositoryProvider)
      .getLeadStatistics();
  return response.isSuccess
      ? ArtworkLeadInfo.fromJson(response.data)
      : const ArtworkLeadInfo();
});

class TeacherArtworksController extends StateNotifier<TeacherArtworksState> {
  TeacherArtworksController({
    required ArtworkRepository repository,
    this.lead = false,
  }) : _repository = repository,
       super(const TeacherArtworksState()) {
    unawaited(refresh());
  }

  final ArtworkRepository _repository;

  /// true 时为组内复核队列：状态按「我是否已复核」筛选。
  final bool lead;
  int _generation = 0;

  Future<void> refresh() async {
    final generation = ++_generation;
    state = state.copyWith(loading: true, errorMessage: '');
    final results = await Future.wait(<Future<ApiResponse>>[
      lead
          ? _repository.getLeadStatistics()
          : _repository.getTeacherStatistics(),
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
      listFailed: listCurrent
          ? (!list.isSuccess && state.items.isEmpty)
          : null,
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

  /// 「开始点评 / 开始复核」：取第一份待我处理的作品。
  Future<({String? id, String error})> firstPendingId() async {
    final response = lead
        ? await _repository.getLeadArtworks(
            status: ArtworkStatusFilter.pending,
            page: 1,
            size: 1,
          )
        : await _repository.getTeacherArtworks(
            status: ArtworkStatusFilter.pending,
            page: 1,
            size: 1,
          );
    if (!response.isSuccess) {
      return (
        id: null,
        error: response.errorOr(lead ? '获取待复核作品失败，请稍后重试' : '获取待点评作品失败，请稍后重试'),
      );
    }
    final records = ArtworkPage.fromJson(response.data).records;
    return (id: records.isEmpty ? null : records.first.id, error: '');
  }

  Future<ApiResponse> _fetchPage(int page) => lead
      ? _repository.getLeadArtworks(
          status: state.filter,
          keyword: state.keyword,
          page: page,
          size: _pageSize,
        )
      : _repository.getTeacherArtworks(
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
        listFailed: reset && state.items.isEmpty,
        errorMessage: response.errorOr('作品加载失败，请稍后重试'),
      );
      return;
    }
    final result = ArtworkPage.fromJson(response.data);
    final known = reset ? <String>{} : state.items.map((e) => e.id).toSet();
    state = state.copyWith(
      loadingList: false,
      loadingMore: false,
      listFailed: false,
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
