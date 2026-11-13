import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';
import 'artwork_models.dart';

final artworkRepositoryProvider = Provider<ArtworkRepository>((ref) {
  final client = ref.watch(markingApiClientProvider);
  return ArtworkRepository(client: client);
});

/// 艺考网阅卷系统「作品档案 / 作品点评 / 复核 / 优秀作品墙」接口。
class ArtworkRepository {
  ArtworkRepository({required this.client});

  final ApiClient client;

  static String _id(String id) => Uri.encodeComponent(id);

  // ── 学生 ──────────────────────────────────────────────────────────────

  Future<ApiResponse> getStatistics() {
    return client.get('/app/artworks/statistics');
  }

  /// 高频问题与练习建议（含分项水平、连续练习天数等）。
  Future<ApiResponse> getInsights() {
    return client.get('/app/artworks/insights');
  }

  Future<ApiResponse> getArtworks({
    required ArtworkStatusFilter status,
    required int page,
    required int size,
    bool revised = false,
  }) {
    return client.get(
      '/app/artworks',
      queryParameters: <String, dynamic>{
        'status': status.code,
        'current': page,
        'size': size,
        if (revised) 'revised': 1,
      },
    );
  }

  Future<ApiResponse> getArtwork(String id) {
    return client.get('/app/artworks/${_id(id)}');
  }

  Future<ApiResponse> getExcellentArtworks({
    String subject = '',
    required int page,
    required int size,
  }) {
    return client.get(
      '/app/artworks/excellent',
      queryParameters: <String, dynamic>{
        if (subject.trim().isNotEmpty) 'subject': subject.trim(),
        'current': page,
        'size': size,
      },
    );
  }

  Future<ApiResponse> getTasks({String status = ''}) {
    return client.get(
      '/app/tasks',
      queryParameters: <String, dynamic>{
        if (status.trim().isNotEmpty) 'status': status.trim(),
      },
    );
  }

  Future<ApiResponse> uploadImage(Uint8List bytes, String fileName) {
    return client.postFormData(
      '/app/artworks/images/upload',
      data: FormData.fromMap(<String, dynamic>{
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
      }),
    );
  }

  Future<ApiResponse> createArtwork({
    required String title,
    required String subject,
    required String drawingDate,
    required String description,
    required List<String> imageIds,
    String taskId = '',
    String parentId = '',
  }) {
    return client.post(
      '/app/artworks',
      data: <String, dynamic>{
        'title': title,
        'subject': subject,
        'drawingDate': drawingDate,
        'description': description.isEmpty ? null : description,
        'imageIds': imageIds,
        if (taskId.isNotEmpty) 'taskId': taskId,
        if (parentId.isNotEmpty) 'parentId': parentId,
      },
    );
  }

  // ── 教职 ──────────────────────────────────────────────────────────────

  Future<ApiResponse> getTeacherStatistics() {
    return client.get('/school/teacher/artworks/statistics');
  }

  Future<ApiResponse> getTeacherArtworks({
    required ArtworkStatusFilter status,
    required int page,
    required int size,
    String keyword = '',
    String subject = '',
    String teacherId = '',
  }) {
    return client.get(
      '/school/teacher/artworks',
      queryParameters: <String, dynamic>{
        'status': status.code,
        'current': page,
        'size': size,
        if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
        if (subject.trim().isNotEmpty) 'subject': subject.trim(),
        if (teacherId.trim().isNotEmpty) 'teacherId': teacherId.trim(),
      },
    );
  }

  Future<ApiResponse> getTeacherArtwork(String id) {
    return client.get('/school/teacher/artworks/${_id(id)}');
  }

  /// [next] 为 true 时返回队列里的下一份待点评作品 id。
  Future<ApiResponse> saveReview({
    required String artworkId,
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
  }) {
    return client.post(
      '/school/teacher/artworks/review?next=$next',
      data: <String, dynamic>{
        'artworkId': artworkId,
        'score': score,
        'maxScore': maxScore,
        'content': content.isEmpty ? null : content,
        'tagIds': tagIds,
        'dimensions': dimensions,
        'requestLeadReview': requestLeadReview,
        'tagResolutions': <Map<String, dynamic>>[
          for (final item in tagResolutions)
            <String, dynamic>{'tag': item.tag, 'resolved': item.resolved},
        ],
        if (voiceUrl.isNotEmpty) 'voiceUrl': voiceUrl,
        if (voiceSeconds > 0) 'voiceSeconds': voiceSeconds,
      },
    );
  }

  Future<ApiResponse> getAnnotations(String artworkId) {
    return client.get('/school/teacher/artworks/${_id(artworkId)}/annotations');
  }

  Future<ApiResponse> saveAnnotations(
    String artworkId, {
    required int imageIndex,
    required List<AnnotationStroke> strokes,
  }) {
    return client.post(
      '/school/teacher/artworks/${_id(artworkId)}/annotations',
      data: <String, dynamic>{
        'imageIndex': imageIndex,
        'strokes': <Map<String, dynamic>>[
          for (final stroke in strokes) stroke.toJson(),
        ],
      },
    );
  }

  Future<ApiResponse> getTags() {
    return client.get('/school/teacher/tags');
  }

  Future<ApiResponse> createTag({
    required String name,
    required String explanation,
    required String color,
    String dimension = '',
  }) {
    return client.post(
      '/school/teacher/tags',
      data: <String, dynamic>{
        'name': name,
        'explanation': explanation.isEmpty ? null : explanation,
        'color': color,
        if (dimension.isNotEmpty) 'dimension': dimension,
      },
    );
  }

  Future<ApiResponse> updateTag({
    required String id,
    required String name,
    required String explanation,
    required String color,
    String dimension = '',
  }) {
    return client.post(
      '/school/teacher/tags/update',
      data: <String, dynamic>{
        'id': id,
        'name': name,
        'explanation': explanation.isEmpty ? null : explanation,
        'color': color,
        if (dimension.isNotEmpty) 'dimension': dimension,
      },
    );
  }

  Future<ApiResponse> deleteTag(String id) {
    return client.post(
      '/school/teacher/tags/delete?id=${Uri.encodeQueryComponent(id)}',
    );
  }

  // ── 组长 / 校长 ──────────────────────────────────────────────────────

  Future<ApiResponse> getLeadReviews({
    String status = 'PENDING',
    String reason = '',
    String teacherId = '',
    required int page,
    required int size,
  }) {
    return client.get(
      '/school/leader/reviews',
      queryParameters: <String, dynamic>{
        'status': status,
        'current': page,
        'size': size,
        if (reason.isNotEmpty) 'reason': reason,
        if (teacherId.isNotEmpty) 'teacherId': teacherId,
      },
    );
  }

  Future<ApiResponse> getLeadReviewStatistics() {
    return client.get('/school/leader/reviews/statistics');
  }

  Future<ApiResponse> submitLeadReview({
    required String artworkId,
    required String action,
    double? score,
    String reason = '',
    String content = '',
    required int qualityStars,
    String qualityNote = '',
  }) {
    return client.post(
      '/school/leader/reviews/${_id(artworkId)}',
      data: <String, dynamic>{
        'action': action,
        'score': score,
        'reason': reason.isEmpty ? null : reason,
        'content': content.isEmpty ? null : content,
        'qualityStars': qualityStars,
        'qualityNote': qualityNote.isEmpty ? null : qualityNote,
      },
    );
  }

  Future<ApiResponse> principalComment({
    required String artworkId,
    required String content,
  }) {
    return client.post(
      '/school/principal/artworks/${_id(artworkId)}/comment',
      data: <String, dynamic>{'content': content},
    );
  }

  Future<ApiResponse> principalFeature({
    required String artworkId,
    required bool featured,
  }) {
    return client.post(
      '/school/principal/artworks/${_id(artworkId)}/feature',
      data: <String, dynamic>{'featured': featured},
    );
  }
}

extension ArtworkApiMessage on ApiResponse {
  /// 接口失败提示：优先使用后端 msg，没有时用 [fallback]。
  String errorOr(String fallback) => displayMsg.isEmpty ? fallback : displayMsg;
}
