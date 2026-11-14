import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../../../core/network/upload_result.dart';
import '../../smart_campus/data/teacher_repository.dart';
import '../data/artwork_models.dart';
import '../data/artwork_repository.dart';
import '../data/artwork_rules.dart';

/// 上传一段语音评语，返回可保存的文件路径；失败返回 null。
typedef ArtworkVoiceUploader =
    Future<String?> Function(Uint8List bytes, String filename);

/// 语音评语走平台的通用文件上传，与作业语音点评是同一个端点。
final artworkVoiceUploaderProvider = Provider<ArtworkVoiceUploader>((ref) {
  final repository = ref.watch(teacherRepositoryProvider);
  return (bytes, filename) async {
    final response = await repository.uploadHomeworkVoice(
      bytes: bytes,
      filename: filename,
    );
    if (!response.isSuccess) {
      return null;
    }
    final saved = parseUploadResult(response.data).savable;
    return saved.isEmpty ? null : saved;
  };
});

@immutable
class ArtworkReviewState {
  const ArtworkReviewState({
    this.loading = true,
    this.detail,
    this.previous,
    this.strokes = const <int, List<AnnotationStroke>>{},
    this.dirtyImages = const <int>{},
    this.saving = false,
    this.savingStrokes = false,
    this.errorMessage = '',
  });

  final bool loading;
  final ArtworkDetail? detail;

  /// 改画版本的上一版（图片、上次点评与批注）；第 1 版或读取失败时为空。
  final ArtworkDetail? previous;

  /// 责任老师的批注，按图片序号分组（责任老师本人可以改，其他人只读）。
  final Map<int, List<AnnotationStroke>> strokes;

  /// 批注有改动、尚未保存的图片序号。
  final Set<int> dirtyImages;

  /// 正在提交：保存点评、提交复核、补充点评、校长点评与推优共用。
  final bool saving;
  final bool savingStrokes;
  final String errorMessage;

  List<AnnotationStroke> strokesOf(int imageIndex) =>
      strokes[imageIndex] ?? const <AnnotationStroke>[];

  bool get hasUnsavedStrokes => dirtyImages.isNotEmpty;

  /// 上一版图片上的老师批注，按图片序号分组。
  List<AnnotationStroke> previousStrokesOf(int imageIndex) =>
      <AnnotationStroke>[
        for (final stroke
            in previous?.review?.annotations ?? const <AnnotationStroke>[])
          if (stroke.imageIndex == imageIndex) stroke,
      ];

  ArtworkReviewState copyWith({
    bool? loading,
    ArtworkDetail? detail,
    ArtworkDetail? previous,
    Map<int, List<AnnotationStroke>>? strokes,
    Set<int>? dirtyImages,
    bool? saving,
    bool? savingStrokes,
    String? errorMessage,
  }) {
    return ArtworkReviewState(
      loading: loading ?? this.loading,
      detail: detail ?? this.detail,
      previous: previous ?? this.previous,
      strokes: strokes ?? this.strokes,
      dirtyImages: dirtyImages ?? this.dirtyImages,
      saving: saving ?? this.saving,
      savingStrokes: savingStrokes ?? this.savingStrokes,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 点评工作台（按作品 id）：作品详情、批注，以及责任老师点评、组长复核、
/// 补充点评这几种提交。
final artworkReviewControllerProvider = StateNotifierProvider.autoDispose
    .family<ArtworkReviewController, ArtworkReviewState, String>((
      ref,
      artworkId,
    ) {
      return ArtworkReviewController(
        repository: ref.watch(artworkRepositoryProvider),
        voiceUploader: ref.watch(artworkVoiceUploaderProvider),
        artworkId: artworkId,
      );
    });

class ArtworkReviewController extends StateNotifier<ArtworkReviewState> {
  ArtworkReviewController({
    required ArtworkRepository repository,
    required this.artworkId,
    ArtworkVoiceUploader? voiceUploader,
  }) : _repository = repository,
       _voiceUploader = voiceUploader,
       super(const ArtworkReviewState()) {
    unawaited(load());
  }

  final ArtworkRepository _repository;
  final ArtworkVoiceUploader? _voiceUploader;
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
    final parsed = ArtworkDetail.fromJson(detail.data);
    state = state.copyWith(
      loading: false,
      detail: parsed,
      strokes: state.hasUnsavedStrokes ? null : strokes,
    );
    await _loadPrevious(parsed);
  }

  /// 改画版本：读取上一版的图片与点评，供对照。读不到时不提示，对照区不显示。
  Future<void> _loadPrevious(ArtworkDetail detail) async {
    final previousId = previousVersionId(detail);
    if (previousId == null || state.previous?.work.id == previousId) {
      return;
    }
    final response = await _repository.getTeacherArtwork(previousId);
    if (!mounted || !response.isSuccess) {
      return;
    }
    state = state.copyWith(previous: ArtworkDetail.fromJson(response.data));
  }

  /// 同一条改画链上，紧挨着这一版的上一版 id；第 1 版返回 null。
  static String? previousVersionId(ArtworkDetail detail) {
    final current = detail.work.version;
    if (current <= 1) {
      return null;
    }
    ArtworkSummary? best;
    for (final version in detail.versions) {
      if (version.id == detail.work.id || version.version >= current) {
        continue;
      }
      if (best == null || version.version > best.version) {
        best = version;
      }
    }
    return best?.id;
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

  /// 上传语音评语，返回可保存的路径；失败返回 null。
  Future<String?> uploadVoice(Uint8List bytes, String filename) async {
    final uploader = _voiceUploader;
    if (uploader == null) {
      return null;
    }
    try {
      return await uploader(bytes, filename);
    } catch (_) {
      return null;
    }
  }

  /// 保存点评（先保存未保存的批注）；失败返回 null，错误写入 [ArtworkReviewState.errorMessage]。
  Future<ReviewSaveResult?> save({
    required double? score,
    required double maxScore,
    required String content,
    required List<String> tagIds,
    required bool next,
    Map<String, int> dimensions = const <String, int>{},
    bool requestLeadReview = false,
    List<({String tag, bool resolved})> tagResolutions =
        const <({String tag, bool resolved})>[],
    String voiceUrl = '',
    int voiceSeconds = 0,
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
      dimensions: dimensions,
      requestLeadReview: requestLeadReview,
      tagResolutions: tagResolutions,
      voiceUrl: voiceUrl,
      voiceSeconds: voiceSeconds,
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
      await _reloadDetail();
      if (!mounted) {
        return result;
      }
    }
    state = state.copyWith(saving: false);
    return result;
  }

  /// 组长提交复核。成功返回 null，否则返回提示文案（校验不通过或接口失败）。
  Future<String?> submitLeadReview({
    required String action,
    required int qualityStars,
    double? score,
    String reason = '',
    String content = '',
    String qualityNote = '',
  }) async {
    final detail = state.detail;
    if (detail == null) {
      return '作品还没有加载完成';
    }
    final error = ArtworkRules.validateLeadReview(
      action: action,
      qualityStars: qualityStars,
      reason: reason,
      content: content,
      score: score,
      maxScore: detail.review?.maxScore ?? detail.work.maxScore,
    );
    if (error != null) {
      return error;
    }
    return _submit(
      () => _repository.submitLeadReview(
        artworkId: artworkId,
        action: action.trim().toUpperCase(),
        score: score,
        reason: reason.trim(),
        content: content.trim(),
        qualityStars: qualityStars,
        qualityNote: qualityNote.trim(),
      ),
      '复核提交失败，请稍后重试',
    );
  }

  /// 非责任老师补充点评（不计分）。成功返回 null。
  Future<String?> supplement(String content) async {
    final text = content.trim();
    if (ArtworkRules.lengthOf(text) < 5) {
      return '补充点评至少 5 个字';
    }
    if (ArtworkRules.lengthOf(text) > ArtworkRules.commentLimit) {
      return '补充点评最多 ${ArtworkRules.commentLimit} 个字';
    }
    return _submit(
      () => _repository.supplementReview(artworkId: artworkId, content: text),
      '补充点评提交失败，请稍后重试',
    );
  }

  /// 校长点评、推优等在别处提交后，重新读取作品详情。
  Future<void> reload() => _reloadDetail();

  Future<String?> _submit(
    Future<ApiResponse> Function() request,
    String fallback,
  ) async {
    if (state.saving) {
      return '正在提交，请稍候';
    }
    state = state.copyWith(saving: true, errorMessage: '');
    final response = await request();
    if (!mounted) {
      return null;
    }
    if (!response.isSuccess) {
      state = state.copyWith(saving: false);
      return response.errorOr(fallback);
    }
    await _reloadDetail();
    if (mounted) {
      state = state.copyWith(saving: false);
    }
    return null;
  }

  Future<void> _reloadDetail() async {
    final refreshed = await _repository.getTeacherArtwork(artworkId);
    if (!mounted || !refreshed.isSuccess) {
      return;
    }
    state = state.copyWith(detail: ArtworkDetail.fromJson(refreshed.data));
  }

  void clearError() {
    state = state.copyWith(errorMessage: '');
  }
}
