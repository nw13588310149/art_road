import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/artwork_models.dart';
import '../data/artwork_repository.dart';

@immutable
class ArtworkLeadReviewState {
  const ArtworkLeadReviewState({
    this.loading = true,
    this.detail,
    this.saving = false,
    this.errorMessage = '',
  });

  final bool loading;
  final ArtworkDetail? detail;
  final bool saving;
  final String errorMessage;

  ArtworkLeadReviewState copyWith({
    bool? loading,
    ArtworkDetail? detail,
    bool? saving,
    String? errorMessage,
  }) {
    return ArtworkLeadReviewState(
      loading: loading ?? this.loading,
      detail: detail ?? this.detail,
      saving: saving ?? this.saving,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 科目组长的复核工作台（按作品 id）：作品、老师点评与复核保存。
final artworkLeadReviewControllerProvider = StateNotifierProvider.autoDispose
    .family<ArtworkLeadReviewController, ArtworkLeadReviewState, String>((
      ref,
      artworkId,
    ) {
      final repository = ref.watch(artworkRepositoryProvider);
      return ArtworkLeadReviewController(
        repository: repository,
        artworkId: artworkId,
      );
    });

class ArtworkLeadReviewController
    extends StateNotifier<ArtworkLeadReviewState> {
  ArtworkLeadReviewController({
    required ArtworkRepository repository,
    required this.artworkId,
  }) : _repository = repository,
       super(const ArtworkLeadReviewState()) {
    unawaited(load());
  }

  final ArtworkRepository _repository;
  final String artworkId;

  Future<void> load() async {
    state = state.copyWith(loading: true, errorMessage: '');
    final response = await _repository.getLeadArtwork(artworkId);
    if (!mounted) {
      return;
    }
    if (!response.isSuccess) {
      state = state.copyWith(
        loading: false,
        errorMessage: response.errorOr('作品加载失败，请稍后重试'),
      );
      return;
    }
    state = state.copyWith(
      loading: false,
      detail: ArtworkDetail.fromJson(response.data),
    );
  }

  /// 保存复核；失败返回 null，错误写入 [ArtworkLeadReviewState.errorMessage]。
  Future<ReviewSaveResult?> save({
    required bool approve,
    required String content,
    required double? score,
    required bool exemplar,
    required bool attention,
    required bool next,
  }) async {
    if (state.saving) {
      return null;
    }
    state = state.copyWith(saving: true, errorMessage: '');
    final response = await _repository.saveLeadReview(
      artworkId: artworkId,
      approve: approve,
      content: content,
      score: score,
      exemplar: exemplar,
      attention: attention,
      next: next,
    );
    if (!mounted) {
      return null;
    }
    if (!response.isSuccess) {
      state = state.copyWith(
        saving: false,
        errorMessage: response.errorOr('复核保存失败，请稍后重试'),
      );
      return null;
    }
    final result = ReviewSaveResult.fromJson(response.data, artworkId);
    if (!next || result.nextArtworkId == null) {
      final refreshed = await _repository.getLeadArtwork(artworkId);
      if (!mounted) {
        return result;
      }
      if (refreshed.isSuccess) {
        state = state.copyWith(detail: ArtworkDetail.fromJson(refreshed.data));
      }
    }
    state = state.copyWith(saving: false);
    return result;
  }

  void clearError() {
    state = state.copyWith(errorMessage: '');
  }
}
