import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/artwork_models.dart';
import '../data/artwork_repository.dart';

const _pageSize = 24;

@immutable
class ExcellentArtworksState {
  const ExcellentArtworksState({
    this.loading = true,
    this.loadingMore = false,
    this.subject = '',
    this.items = const <ArtworkSummary>[],
    this.page = 0,
    this.hasMore = false,
    this.errorMessage = '',
  });

  final bool loading;
  final bool loadingMore;
  final String subject;
  final List<ArtworkSummary> items;
  final int page;
  final bool hasMore;
  final String errorMessage;

  ExcellentArtworksState copyWith({
    bool? loading,
    bool? loadingMore,
    String? subject,
    List<ArtworkSummary>? items,
    int? page,
    bool? hasMore,
    String? errorMessage,
  }) {
    return ExcellentArtworksState(
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      subject: subject ?? this.subject,
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final excellentArtworksControllerProvider = StateNotifierProvider.autoDispose
    .family<ExcellentArtworksController, ExcellentArtworksState, String>((
      ref,
      campusId,
    ) {
      return ExcellentArtworksController(
        repository: ref.watch(artworkRepositoryProvider),
        campusId: campusId,
      );
    });

class ExcellentArtworksController
    extends StateNotifier<ExcellentArtworksState> {
  ExcellentArtworksController({
    required ArtworkRepository repository,
    this.campusId = '',
  }) : _repository = repository,
       super(const ExcellentArtworksState()) {
    unawaited(refresh());
  }

  final ArtworkRepository _repository;
  final String campusId;
  int _generation = 0;

  Future<void> refresh() async {
    final generation = ++_generation;
    state = state.copyWith(loading: true, loadingMore: false, errorMessage: '');
    final response = await _repository.getExcellentArtworks(
      subject: state.subject,
      campusId: campusId,
      page: 1,
      size: _pageSize,
    );
    if (!mounted || generation != _generation) {
      return;
    }
    if (!response.isSuccess) {
      state = state.copyWith(
        loading: false,
        errorMessage: response.errorOr('优秀作品墙加载失败，请稍后重试'),
      );
      return;
    }
    final page = ArtworkPage.fromJson(response.data);
    state = state.copyWith(
      loading: false,
      items: page.records,
      page: page.current,
      hasMore: page.hasMore,
    );
  }

  Future<void> setSubject(String subject) async {
    if (subject == state.subject) {
      return;
    }
    state = state.copyWith(subject: subject, items: const <ArtworkSummary>[]);
    await refresh();
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) {
      return;
    }
    final generation = _generation;
    state = state.copyWith(loadingMore: true);
    final response = await _repository.getExcellentArtworks(
      subject: state.subject,
      campusId: campusId,
      page: state.page + 1,
      size: _pageSize,
    );
    if (!mounted || generation != _generation) {
      return;
    }
    if (!response.isSuccess) {
      state = state.copyWith(
        loadingMore: false,
        errorMessage: response.errorOr('优秀作品墙加载失败，请稍后重试'),
      );
      return;
    }
    final page = ArtworkPage.fromJson(response.data);
    final known = state.items.map((e) => e.id).toSet();
    state = state.copyWith(
      loadingMore: false,
      items: <ArtworkSummary>[
        ...state.items,
        ...page.records.where((e) => known.add(e.id)),
      ],
      page: page.current,
      hasMore: page.hasMore,
    );
  }
}
