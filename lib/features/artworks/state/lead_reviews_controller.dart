import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/artwork_models.dart';
import '../data/artwork_repository.dart';
import '../data/artwork_rules.dart';

const _pageSize = 24;

@immutable
class LeadReviewsState {
  const LeadReviewsState({
    this.loading = true,
    this.loadingMore = false,
    this.saving = false,
    this.items = const <ArtworkSummary>[],
    this.pending = 0,
    this.overdue = 0,
    this.done = 0,
    this.page = 0,
    this.hasMore = false,
    this.errorMessage = '',
  });

  final bool loading;
  final bool loadingMore;
  final bool saving;
  final List<ArtworkSummary> items;
  final int pending;
  final int overdue;
  final int done;
  final int page;
  final bool hasMore;
  final String errorMessage;

  LeadReviewsState copyWith({
    bool? loading,
    bool? loadingMore,
    bool? saving,
    List<ArtworkSummary>? items,
    int? pending,
    int? overdue,
    int? done,
    int? page,
    bool? hasMore,
    String? errorMessage,
  }) {
    return LeadReviewsState(
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      saving: saving ?? this.saving,
      items: items ?? this.items,
      pending: pending ?? this.pending,
      overdue: overdue ?? this.overdue,
      done: done ?? this.done,
      page: page ?? this.page,
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

class LeadReviewsController extends StateNotifier<LeadReviewsState> {
  LeadReviewsController({required ArtworkRepository repository})
    : _repository = repository,
      super(const LeadReviewsState()) {
    unawaited(refresh());
  }

  final ArtworkRepository _repository;

  Future<void> refresh() async {
    state = state.copyWith(loading: true, errorMessage: '');
    final results = await Future.wait([
      _repository.getLeadReviewStatistics(),
      _repository.getLeadReviews(page: 1, size: _pageSize),
    ]);
    if (!mounted) {
      return;
    }
    final [stats, list] = results;
    if (!list.isSuccess) {
      state = state.copyWith(
        loading: false,
        errorMessage: list.errorOr('复核池加载失败，请稍后重试'),
      );
      return;
    }
    final page = ArtworkPage.fromJson(list.data);
    final statsMap = stats.isSuccess && stats.data is Map
        ? Map<String, dynamic>.from(stats.data as Map)
        : const <String, dynamic>{};
    state = state.copyWith(
      loading: false,
      items: page.records,
      page: page.current,
      hasMore: page.hasMore,
      pending: (statsMap['pending'] as num?)?.toInt() ?? 0,
      overdue: (statsMap['overdue'] as num?)?.toInt() ?? 0,
      done: (statsMap['done'] as num?)?.toInt() ?? 0,
    );
  }

  Future<String?> submit({
    required String artworkId,
    required String action,
    double? score,
    String reason = '',
    String content = '',
    required int qualityStars,
    String qualityNote = '',
    double maxScore = ArtworkRules.defaultFullScore,
  }) async {
    final error = ArtworkRules.validateLeadReview(
      action: action,
      qualityStars: qualityStars,
      reason: reason,
      content: content,
      score: score,
      maxScore: maxScore,
    );
    if (error != null) {
      return error;
    }
    if (state.saving) {
      return '正在提交，请稍候';
    }
    state = state.copyWith(saving: true, errorMessage: '');
    final response = await _repository.submitLeadReview(
      artworkId: artworkId,
      action: action,
      score: score,
      reason: reason,
      content: content,
      qualityStars: qualityStars,
      qualityNote: qualityNote,
    );
    if (!mounted) {
      return null;
    }
    state = state.copyWith(saving: false);
    if (!response.isSuccess) {
      return response.errorOr('复核提交失败，请稍后重试');
    }
    unawaited(refresh());
    return null;
  }
}
