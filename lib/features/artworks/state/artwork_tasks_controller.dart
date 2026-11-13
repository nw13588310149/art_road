import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/artwork_models.dart';
import '../data/artwork_repository.dart';

@immutable
class ArtworkTasksState {
  const ArtworkTasksState({
    this.loading = true,
    this.items = const <ArtworkTask>[],
    this.errorMessage = '',
  });

  final bool loading;
  final List<ArtworkTask> items;
  final String errorMessage;

  ArtworkTasksState copyWith({
    bool? loading,
    List<ArtworkTask>? items,
    String? errorMessage,
  }) {
    return ArtworkTasksState(
      loading: loading ?? this.loading,
      items: items ?? this.items,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final artworkTasksControllerProvider =
    StateNotifierProvider.autoDispose<
      ArtworkTasksController,
      ArtworkTasksState
    >((ref) {
      return ArtworkTasksController(
        repository: ref.watch(artworkRepositoryProvider),
      );
    });

class ArtworkTasksController extends StateNotifier<ArtworkTasksState> {
  ArtworkTasksController({required ArtworkRepository repository})
    : _repository = repository,
      super(const ArtworkTasksState()) {
    unawaited(refresh());
  }

  final ArtworkRepository _repository;

  Future<void> refresh() async {
    state = state.copyWith(loading: true, errorMessage: '');
    final response = await _repository.getTasks();
    if (!mounted) {
      return;
    }
    if (!response.isSuccess) {
      state = state.copyWith(
        loading: false,
        errorMessage: response.errorOr('作业列表加载失败，请稍后重试'),
      );
      return;
    }
    final raw = response.data;
    final items = raw is List
        ? <ArtworkTask>[
            for (final item in raw) ArtworkTask.fromJson(item),
          ]
        : const <ArtworkTask>[];
    state = state.copyWith(loading: false, items: items);
  }
}
