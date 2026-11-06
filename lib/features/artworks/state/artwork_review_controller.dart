import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../data/artwork_models.dart';
import '../data/artwork_repository.dart';

@immutable
class ArtworkReviewState {
  const ArtworkReviewState({
    this.loading = true,
    this.detail,
    this.strokes = const <int, List<AnnotationStroke>>{},
    this.dirtyImages = const <int>{},
    this.saving = false,
    this.savingStrokes = false,
    this.errorMessage = '',
  });

  final bool loading;
  final ArtworkDetail? detail;

  /// 我的批注，按图片序号分组。
  final Map<int, List<AnnotationStroke>> strokes;

  /// 批注有改动、尚未保存的图片序号。
  final Set<int> dirtyImages;
  final bool saving;
  final bool savingStrokes;
  final String errorMessage;

  List<AnnotationStroke> strokesOf(int imageIndex) =>
      strokes[imageIndex] ?? const <AnnotationStroke>[];

  bool get hasUnsavedStrokes => dirtyImages.isNotEmpty;

  ArtworkReviewState copyWith({
    bool? loading,
    ArtworkDetail? detail,
    Map<int, List<AnnotationStroke>>? strokes,
    Set<int>? dirtyImages,
    bool? saving,
    bool? savingStrokes,
    String? errorMessage,
  }) {
    return ArtworkReviewState(
      loading: loading ?? this.loading,
      detail: detail ?? this.detail,
      strokes: strokes ?? this.strokes,
      dirtyImages: dirtyImages ?? this.dirtyImages,
      saving: saving ?? this.saving,
      savingStrokes: savingStrokes ?? this.savingStrokes,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 教师端点评工作台（按作品 id）：作品详情、我的批注与点评保存。
final artworkReviewControllerProvider = StateNotifierProvider.autoDispose
    .family<ArtworkReviewController, ArtworkReviewState, String>((
      ref,
      artworkId,
    ) {
      final repository = ref.watch(artworkRepositoryProvider);
      return ArtworkReviewController(
        repository: repository,
        artworkId: artworkId,
      );
    });

class ArtworkReviewController extends StateNotifier<ArtworkReviewState> {
  ArtworkReviewController({
    required ArtworkRepository repository,
    required this.artworkId,
  }) : _repository = repository,
       super(const ArtworkReviewState()) {
    unawaited(load());
  }

  final ArtworkRepository _repository;
  final String artworkId;

  Future<void> load() async {
    state = state.copyWith(loading: true, errorMessage: '');
    final results = await Future.wait(<Future<ApiResponse>>[
      _repository.getTeacherArtwork(artworkId),
      _repository.getAnnotations(artworkId),
    ]);
    if (!mounted) {
      return;
    }
    final [detail, annotations] = results;
    if (!detail.isSuccess) {
      state = state.copyWith(
        loading: false,
        errorMessage: detail.errorOr('作品加载失败，请稍后重试'),
      );
      return;
    }
    final strokes = <int, List<AnnotationStroke>>{};
    final data = annotations.data;
    final raw = annotations.isSuccess && data is Map ? data['strokes'] : null;
    for (final item in raw is List ? raw : const <dynamic>[]) {
      final stroke = AnnotationStroke.fromJson(item);
      if (stroke.points.isNotEmpty) {
        strokes
            .putIfAbsent(stroke.imageIndex, () => <AnnotationStroke>[])
            .add(stroke);
      }
    }
    state = state.copyWith(
      loading: false,
      detail: ArtworkDetail.fromJson(detail.data),
      strokes: state.hasUnsavedStrokes ? null : strokes,
    );
  }

  void addStroke(AnnotationStroke stroke) {
    final index = stroke.imageIndex;
    _replaceStrokes(index, <AnnotationStroke>[
      ...state.strokesOf(index),
      stroke,
    ]);
  }

  void undo(int imageIndex) {
    final current = state.strokesOf(imageIndex);
    if (current.isNotEmpty) {
      _replaceStrokes(imageIndex, current.sublist(0, current.length - 1));
    }
  }

  void clear(int imageIndex) {
    if (state.strokesOf(imageIndex).isNotEmpty) {
      _replaceStrokes(imageIndex, const <AnnotationStroke>[]);
    }
  }

  void _replaceStrokes(int imageIndex, List<AnnotationStroke> strokes) {
    state = state.copyWith(
      strokes: <int, List<AnnotationStroke>>{
        ...state.strokes,
        imageIndex: strokes,
      },
      dirtyImages: <int>{...state.dirtyImages, imageIndex},
    );
  }

  /// 保存所有改动过的图片批注；全部成功返回 true。
  Future<bool> saveAnnotations() async {
    if (!state.hasUnsavedStrokes) {
      return true;
    }
    if (state.savingStrokes) {
      return false;
    }
    state = state.copyWith(savingStrokes: true, errorMessage: '');
    final pending = state.dirtyImages.toList()..sort();
    for (final index in pending) {
      final strokes = state.strokesOf(index);
      final response = await _repository.saveAnnotations(
        artworkId,
        imageIndex: index,
        strokes: strokes,
      );
      if (!mounted) {
        return false;
      }
      if (!response.isSuccess) {
        state = state.copyWith(
          savingStrokes: false,
          errorMessage: response.errorOr('批注保存失败，请稍后重试'),
        );
        return false;
      }
      // 保存期间又画了新的一笔时保留未保存标记。
      if (identical(state.strokesOf(index), strokes)) {
        state = state.copyWith(
          dirtyImages: <int>{...state.dirtyImages}..remove(index),
        );
      }
    }
    state = state.copyWith(savingStrokes: false);
    return true;
  }

  /// 保存点评（先保存未保存的批注）；失败返回 null，错误写入 [ArtworkReviewState.errorMessage]。
  Future<ReviewSaveResult?> save({
    required double? score,
    required double maxScore,
    required String content,
    required List<String> tagIds,
    required bool next,
  }) async {
    if (state.saving) {
      return null;
    }
    state = state.copyWith(saving: true, errorMessage: '');
    if (state.hasUnsavedStrokes && !await saveAnnotations()) {
      if (mounted) {
        state = state.copyWith(saving: false);
      }
      return null;
    }
    final response = await _repository.saveReview(
      artworkId: artworkId,
      score: score,
      maxScore: maxScore,
      content: content,
      tagIds: tagIds,
      next: next,
    );
    if (!mounted) {
      return null;
    }
    if (!response.isSuccess) {
      state = state.copyWith(
        saving: false,
        errorMessage: response.errorOr('点评保存失败，请稍后重试'),
      );
      return null;
    }
    final result = ReviewSaveResult.fromJson(response.data, artworkId);
    if (!next || result.nextArtworkId == null) {
      final refreshed = await _repository.getTeacherArtwork(artworkId);
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
