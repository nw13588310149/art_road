import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/artwork_models.dart';
import '../data/artwork_repository.dart';

@immutable
class ArtworkDetailState {
  const ArtworkDetailState({
    this.loading = true,
    this.detail,
    this.errorMessage = '',
  });

  final bool loading;
  final ArtworkDetail? detail;
  final String errorMessage;

  ArtworkDetailState copyWith({
    bool? loading,
    ArtworkDetail? detail,
    String? errorMessage,
  }) {
    return ArtworkDetailState(
      loading: loading ?? this.loading,
      detail: detail ?? this.detail,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 学生端作品详情（按作品 id）。
final studentArtworkDetailProvider = StateNotifierProvider.autoDispose
    .family<StudentArtworkDetailController, ArtworkDetailState, String>((
      ref,
      artworkId,
    ) {
      final repository = ref.watch(artworkRepositoryProvider);
      return StudentArtworkDetailController(
        repository: repository,
        artworkId: artworkId,
      );
    });

class StudentArtworkDetailController extends StateNotifier<ArtworkDetailState> {
  StudentArtworkDetailController({
    required ArtworkRepository repository,
    required this.artworkId,
  }) : _repository = repository,
       super(const ArtworkDetailState()) {
    unawaited(load());
  }

  final ArtworkRepository _repository;
  final String artworkId;

  Future<void> load() async {
    state = state.copyWith(loading: true, errorMessage: '');
    final response = await _repository.getArtwork(artworkId);
    if (!mounted) {
      return;
    }
    if (!response.isSuccess) {
      state = state.copyWith(
        loading: false,
        errorMessage: response.errorOr('作品详情加载失败，请稍后重试'),
      );
      return;
    }
    state = state.copyWith(
      loading: false,
      detail: ArtworkDetail.fromJson(response.data),
    );
  }

  /// 作品主人对一处定点点评标「改了 / 没看懂」，[status] 为 null 时清除。先改界面，
  /// 接口失败时改回去并写入 [ArtworkDetailState.errorMessage]。成功返回 true。
  Future<bool> respondToMark(
    NumberedArtworkMark item,
    ArtworkMarkResponseStatus? status,
  ) async {
    final before = state.detail;
    if (before == null || item.mark.response?.status == status) {
      return before != null;
    }
    state = state.copyWith(
      detail: before.withMarkResponse(
        teacherId: item.teacherId,
        markId: item.mark.id,
        response: status == null ? null : ArtworkMarkResponse(status: status),
      ),
      errorMessage: '',
    );
    final response = await _repository.respondToMark(
      artworkId,
      teacherId: item.teacherId,
      markId: item.mark.id,
      status: status,
    );
    if (!mounted) {
      return false;
    }
    final current = state.detail;
    if (!response.isSuccess) {
      state = state.copyWith(
        detail: current?.withMarkResponse(
          teacherId: item.teacherId,
          markId: item.mark.id,
          response: item.mark.response,
        ),
        errorMessage: response.errorOr('没有标上，请稍后重试'),
      );
      return false;
    }
    final data = response.data;
    final saved = data is Map
        ? ArtworkMarkResponse.fromJson(data['response'])
        : null;
    if (saved != null && current != null) {
      state = state.copyWith(
        detail: current.withMarkResponse(
          teacherId: item.teacherId,
          markId: item.mark.id,
          response: saved,
        ),
      );
    }
    return true;
  }

  void clearError() {
    state = state.copyWith(errorMessage: '');
  }
}
