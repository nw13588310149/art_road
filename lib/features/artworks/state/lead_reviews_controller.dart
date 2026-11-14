import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../data/artwork_models.dart';
import '../data/artwork_repository.dart';

const _pageSize = 24;

/// 待复核一次取完再按进入时间排序，这是单次请求的条数上限。
const _pendingPageSize = 100;

/// 最多连续翻这么多页（搜索要覆盖整个列表时用）。
const _maxPages = 10;

/// 复核池的状态页签；[code] 是接口的 `status` 参数。
enum LeadPoolStatus {
  pending('PENDING', '待复核'),
  done('DONE', '已复核'),
  all('ALL', '全部');

  const LeadPoolStatus(this.code, this.label);

  final String code;
  final String label;
}

@immutable
class LeadReviewStats {
  const LeadReviewStats({
    this.total = 0,
    this.pending = 0,
    this.overdue = 0,
    this.done = 0,
    this.adjustedThisWeek = 0,
  });

  factory LeadReviewStats.fromJson(Object? raw) {
    int read(String key) {
      final value = raw is Map ? raw[key] : null;
      return value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;
    }

    return LeadReviewStats(
      total: read('total'),
      pending: read('pending'),
      overdue: read('overdue'),
      done: read('done'),
      adjustedThisWeek: read('adjustedThisWeek'),
    );
  }

  final int total;
  final int pending;
  final int overdue;
  final int done;
  final int adjustedThisWeek;
}

/// 筛选下拉里的一位老师。
typedef ArtworkTeacherOption = ({String id, String name});

@immutable
class LeadReviewsState {
  const LeadReviewsState({
    this.loading = true,
    this.loaded = false,
    this.loadingList = false,
    this.loadingMore = false,
    this.listFailed = false,
    this.status = LeadPoolStatus.pending,
    this.reason = '',
    this.teacherId = '',
    this.keyword = '',
    this.items = const <ArtworkSummary>[],
    this.stats = const LeadReviewStats(),
    this.teachers = const <ArtworkTeacherOption>[],
    this.page = 0,
    this.total = 0,
    this.hasMore = false,
    this.errorMessage = '',
  });

  final bool loading;
  final bool loaded;
  final bool loadingList;
  final bool loadingMore;

  /// 列表首屏加载失败（没有可展示的旧数据），页面显示错误状态。
  final bool listFailed;
  final LeadPoolStatus status;

  /// 进入复核的原因筛选（`REQUESTED / SCORE_ANOMALY / BRIEF / SPOT_CHECK`），空为全部。
  final String reason;
  final String teacherId;

  /// 搜索词。复核池接口不支持关键字，在已取到的列表里筛选。
  final String keyword;
  final List<ArtworkSummary> items;
  final LeadReviewStats stats;

  /// 本组出现过的责任老师，供「老师」下拉使用。
  final List<ArtworkTeacherOption> teachers;
  final int page;
  final int total;
  final bool hasMore;
  final String errorMessage;

  bool get filtered =>
      reason.isNotEmpty || teacherId.isNotEmpty || keyword.isNotEmpty;

  /// 按搜索词筛选后的列表：匹配学生、学号、作品名称与责任老师。
  List<ArtworkSummary> get visibleItems {
    final word = keyword.trim().toLowerCase();
    if (word.isEmpty) {
      return items;
    }
    return <ArtworkSummary>[
      for (final item in items)
        if (<String>[
          item.studentName,
          item.studentNo,
          item.title,
          item.teacherName,
          item.organizationName,
        ].any((field) => field.toLowerCase().contains(word)))
          item,
    ];
  }

  LeadReviewsState copyWith({
    bool? loading,
    bool? loaded,
    bool? loadingList,
    bool? loadingMore,
    bool? listFailed,
    LeadPoolStatus? status,
    String? reason,
    String? teacherId,
    String? keyword,
    List<ArtworkSummary>? items,
    LeadReviewStats? stats,
    List<ArtworkTeacherOption>? teachers,
    int? page,
    int? total,
    bool? hasMore,
    String? errorMessage,
  }) {
    return LeadReviewsState(
      loading: loading ?? this.loading,
      loaded: loaded ?? this.loaded,
      loadingList: loadingList ?? this.loadingList,
      loadingMore: loadingMore ?? this.loadingMore,
      listFailed: listFailed ?? this.listFailed,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      teacherId: teacherId ?? this.teacherId,
      keyword: keyword ?? this.keyword,
      items: items ?? this.items,
      stats: stats ?? this.stats,
      teachers: teachers ?? this.teachers,
      page: page ?? this.page,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final leadReviewsControllerProvider =
    StateNotifierProvider.autoDispose<LeadReviewsController, LeadReviewsState>((
      ref,
    ) {
      return LeadReviewsController(
        repository: ref.watch(artworkRepositoryProvider),
      );
    });

/// 组长复核池：统计、状态页签、按老师和原因筛选、搜索，以及「下一份待复核」。
class LeadReviewsController extends StateNotifier<LeadReviewsState> {
  LeadReviewsController({required ArtworkRepository repository})
    : _repository = repository,
      super(const LeadReviewsState()) {
    unawaited(refresh());
  }

  final ArtworkRepository _repository;
  int _generation = 0;

  Future<void> refresh() async {
    final generation = ++_generation;
    state = state.copyWith(loading: true, errorMessage: '');
    final needTeachers = state.teachers.isEmpty;
    final results = await Future.wait(<Future<ApiResponse>>[
      _repository.getLeadReviewStatistics(),
      _fetchPage(1),
      // 「老师」下拉的选项：复核池没有单独的老师名单接口，从全部记录里归纳。
      if (needTeachers)
        _repository.getLeadReviews(
          status: LeadPoolStatus.all.code,
          page: 1,
          size: _pendingPageSize,
        ),
    ]);
    if (!mounted) {
      return;
    }
    final stats = results[0];
    final list = results[1];
    final current = generation == _generation;
    final page = current && list.isSuccess
        ? ArtworkPage.fromJson(list.data)
        : null;
    var teachers = state.teachers;
    if (needTeachers && results.length > 2 && results[2].isSuccess) {
      teachers = _mergeTeachers(
        teachers,
        ArtworkPage.fromJson(results[2].data).records,
      );
    }
    if (page != null) {
      teachers = _mergeTeachers(teachers, page.records);
    }
    final failed = <ApiResponse>[stats, list].where((r) => !r.isSuccess);
    state = state.copyWith(
      loading: false,
      loaded: true,
      stats: stats.isSuccess ? LeadReviewStats.fromJson(stats.data) : null,
      items: page == null ? null : _ordered(page.records),
      page: page?.current,
      total: page?.total,
      hasMore: page?.hasMore,
      teachers: teachers,
      listFailed: current ? (!list.isSuccess && state.items.isEmpty) : null,
      errorMessage: failed.isEmpty ? '' : failed.first.errorOr('复核池加载失败，请稍后重试'),
    );
    if (current && page != null) {
      await _loadRemainingIfNeeded(generation);
    }
  }

  Future<void> setStatus(LeadPoolStatus status) async {
    if (status == state.status) {
      return;
    }
    state = state.copyWith(status: status);
    await _loadList(reset: true);
  }

  Future<void> setReason(String reason) async {
    final value = reason.trim().toUpperCase();
    if (value == state.reason) {
      return;
    }
    state = state.copyWith(reason: value);
    await _loadList(reset: true);
  }

  Future<void> setTeacher(String teacherId) async {
    final value = teacherId.trim();
    if (value == state.teacherId) {
      return;
    }
    state = state.copyWith(teacherId: value);
    await _loadList(reset: true);
  }

  /// 搜索在已取到的列表里筛选；还有没取完的页时先取完，搜索才覆盖整个列表。
  Future<void> setKeyword(String keyword) async {
    final value = keyword.trim();
    if (value == state.keyword) {
      return;
    }
    state = state.copyWith(keyword: value);
    await _loadRemainingIfNeeded(_generation);
  }

  Future<void> clearFilters() async {
    if (!state.filtered) {
      return;
    }
    state = state.copyWith(reason: '', teacherId: '', keyword: '');
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

  /// 提交复核后要打开的下一份：按复核池现在的顺序，取排在 [currentId] 后面的
  /// 那份待复核；后面没有了就回到最前面的一份。没有待复核时返回 null。
  Future<String?> nextPendingId(String currentId) async {
    final before = <String>[
      for (final item in state.items)
        if (item.leadStatus == ArtworkLeadStatus.inReview) item.id,
    ];
    final response = await _repository.getLeadReviews(
      status: LeadPoolStatus.pending.code,
      reason: state.reason,
      teacherId: state.teacherId,
      page: 1,
      size: _pendingPageSize,
    );
    if (!response.isSuccess) {
      return null;
    }
    final pending = <String>[
      for (final item in _ordered(
        ArtworkPage.fromJson(response.data).records,
        status: LeadPoolStatus.pending,
      ))
        if (item.id != currentId) item.id,
    ];
    if (pending.isEmpty) {
      return null;
    }
    final index = before.indexOf(currentId);
    if (index >= 0) {
      for (final id in before.skip(index + 1)) {
        if (pending.contains(id)) {
          return id;
        }
      }
    }
    return pending.first;
  }

  void clearError() {
    state = state.copyWith(errorMessage: '');
  }

  Future<ApiResponse> _fetchPage(int page) => _repository.getLeadReviews(
    status: state.status.code,
    reason: state.reason,
    teacherId: state.teacherId,
    page: page,
    size: state.status == LeadPoolStatus.pending ? _pendingPageSize : _pageSize,
  );

  /// 待复核按进入复核池的时间从早到晚排（剩余时间少的在前，超时的排在最前面）；
  /// 其余页签保持接口的顺序（新的在前）。
  List<ArtworkSummary> _ordered(
    List<ArtworkSummary> records, {
    LeadPoolStatus? status,
  }) {
    if ((status ?? state.status) != LeadPoolStatus.pending) {
      return records;
    }
    final indexed = <(int, ArtworkSummary)>[
      for (var i = 0; i < records.length; i++) (i, records[i]),
    ];
    indexed.sort((a, b) {
      final byTime = a.$2.leadEnteredTime.compareTo(b.$2.leadEnteredTime);
      return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
    });
    return <ArtworkSummary>[for (final item in indexed) item.$2];
  }

  List<ArtworkTeacherOption> _mergeTeachers(
    List<ArtworkTeacherOption> known,
    List<ArtworkSummary> records,
  ) {
    final byId = <String, String>{for (final item in known) item.id: item.name};
    var changed = false;
    for (final record in records) {
      if (record.teacherId.isEmpty || byId.containsKey(record.teacherId)) {
        continue;
      }
      byId[record.teacherId] = record.teacherName;
      changed = true;
    }
    if (!changed) {
      return known;
    }
    final ids = byId.keys.toList()..sort();
    return <ArtworkTeacherOption>[
      for (final id in ids) (id: id, name: byId[id]!),
    ];
  }

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
        errorMessage: response.errorOr('复核池加载失败，请稍后重试'),
      );
      return;
    }
    _applyPage(ArtworkPage.fromJson(response.data), reset: reset);
    if (reset) {
      await _loadRemainingIfNeeded(generation);
    }
  }

  void _applyPage(ArtworkPage result, {required bool reset}) {
    final known = reset ? <String>{} : state.items.map((e) => e.id).toSet();
    state = state.copyWith(
      loadingList: false,
      loadingMore: false,
      listFailed: false,
      items: _ordered(<ArtworkSummary>[
        if (!reset) ...state.items,
        ...result.records.where((e) => known.add(e.id)),
      ]),
      teachers: _mergeTeachers(state.teachers, result.records),
      page: result.current,
      total: result.total,
      hasMore: result.hasMore,
    );
  }

  /// 待复核要整体排序、搜索要覆盖整个列表：这两种情况把剩下的页取完。
  Future<void> _loadRemainingIfNeeded(int generation) async {
    final wanted =
        state.status == LeadPoolStatus.pending || state.keyword.isNotEmpty;
    if (!wanted) {
      return;
    }
    var guard = 0;
    while (mounted &&
        generation == _generation &&
        state.hasMore &&
        guard < _maxPages) {
      guard++;
      state = state.copyWith(loadingMore: true);
      final response = await _fetchPage(state.page + 1);
      if (!mounted || generation != _generation) {
        return;
      }
      if (!response.isSuccess) {
        state = state.copyWith(
          loadingMore: false,
          errorMessage: response.errorOr('复核池加载失败，请稍后重试'),
        );
        return;
      }
      _applyPage(ArtworkPage.fromJson(response.data), reset: false);
    }
  }
}
