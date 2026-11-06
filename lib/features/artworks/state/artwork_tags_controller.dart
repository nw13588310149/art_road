import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../data/artwork_models.dart';
import '../data/artwork_repository.dart';

@immutable
class ArtworkTagsState {
  const ArtworkTagsState({
    this.loading = true,
    this.tags = const <ArtworkTag>[],
    this.errorMessage = '',
  });

  final bool loading;
  final List<ArtworkTag> tags;
  final String errorMessage;

  ArtworkTagsState copyWith({
    bool? loading,
    List<ArtworkTag>? tags,
    String? errorMessage,
  }) {
    return ArtworkTagsState(
      loading: loading ?? this.loading,
      tags: tags ?? this.tags,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 老师私有的点评标签：点评工作台的标签选择与「点评标签」管理共用。
final artworkTagsControllerProvider =
    StateNotifierProvider.autoDispose<ArtworkTagsController, ArtworkTagsState>((
      ref,
    ) {
      final repository = ref.watch(artworkRepositoryProvider);
      return ArtworkTagsController(repository: repository);
    });

class ArtworkTagsController extends StateNotifier<ArtworkTagsState> {
  ArtworkTagsController({required ArtworkRepository repository})
    : _repository = repository,
      super(const ArtworkTagsState()) {
    unawaited(load());
  }

  final ArtworkRepository _repository;

  Future<void> load() async {
    state = state.copyWith(loading: true, errorMessage: '');
    final response = await _repository.getTags();
    if (!mounted) {
      return;
    }
    final data = response.data;
    state = response.isSuccess
        ? state.copyWith(
            loading: false,
            tags: <ArtworkTag>[
              if (data is List)
                for (final item in data) ArtworkTag.fromJson(item),
            ],
          )
        : state.copyWith(
            loading: false,
            errorMessage: response.errorOr('标签加载失败，请稍后重试'),
          );
  }

  /// 成功返回 null，失败返回提示文案。
  Future<String?> create({
    required String name,
    required String explanation,
    required String color,
  }) {
    return _mutate(
      _repository.createTag(
        name: name.trim(),
        explanation: explanation.trim(),
        color: color,
      ),
      '标签创建失败，请稍后重试',
    );
  }

  Future<String?> update(
    String id, {
    required String name,
    required String explanation,
    required String color,
  }) {
    return _mutate(
      _repository.updateTag(
        id: id,
        name: name.trim(),
        explanation: explanation.trim(),
        color: color,
      ),
      '标签保存失败，请稍后重试',
    );
  }

  Future<String?> delete(String id) {
    return _mutate(_repository.deleteTag(id), '标签删除失败，请稍后重试');
  }

  Future<String?> _mutate(Future<ApiResponse> request, String fallback) async {
    final response = await request;
    if (!response.isSuccess) {
      return response.errorOr(fallback);
    }
    if (mounted) {
      await load();
    }
    return null;
  }

  void clearError() {
    state = state.copyWith(errorMessage: '');
  }
}
