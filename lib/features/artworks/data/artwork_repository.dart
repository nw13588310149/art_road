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

/// 艺考网阅卷系统「作品档案（学生）/ 作品点评（教职）」接口。
class ArtworkRepository {
  ArtworkRepository({required this.client});

  final ApiClient client;

  static String _id(String id) => Uri.encodeComponent(id);

  // ── 学生 ──────────────────────────────────────────────────────────────

  Future<ApiResponse> getStatistics() {
    return client.get('/app/artworks/statistics');
  }

  /// 高频问题与练习建议（演示接口，后续由后端提供）。
  Future<ApiResponse> getInsights() {
    return client.get('/app/artworks/insights');
  }

  Future<ApiResponse> getArtworks({
    required ArtworkStatusFilter status,
    required int page,
    required int size,
  }) {
    return client.get(
      '/app/artworks',
      queryParameters: <String, dynamic>{
        'status': status.code,
        'current': page,
        'size': size,
      },
    );
  }

  Future<ApiResponse> getArtwork(String id) {
    return client.get('/app/artworks/${_id(id)}');
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
  }) {
    return client.post(
      '/app/artworks',
      data: <String, dynamic>{
        'title': title,
        'subject': subject,
        'drawingDate': drawingDate,
        'description': description.isEmpty ? null : description,
        'imageIds': imageIds,
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
  }) {
    return client.get(
      '/school/teacher/artworks',
      queryParameters: <String, dynamic>{
        'status': status.code,
        'current': page,
        'size': size,
        if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
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
  }) {
    return client.post(
      '/school/teacher/artworks/review?next=$next',
      data: <String, dynamic>{
        'artworkId': artworkId,
        'score': score,
        'maxScore': maxScore,
        'content': content.isEmpty ? null : content,
        'tagIds': tagIds,
      },
    );
  }

  /// 我的批注（演示接口，后续由后端提供）。
  Future<ApiResponse> getAnnotations(String artworkId) {
    return client.get('/school/teacher/artworks/${_id(artworkId)}/annotations');
  }

  /// 覆盖保存我在第 [imageIndex] 张图上的批注。
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

  // ── 科目组长：组内复核（演示接口，后续由后端提供） ────────────────────

  /// 返回 `isLead`（当前账号是否为科目组长）、`groupName` 与待复核 / 已复核数量。
  Future<ApiResponse> getLeadStatistics() {
    return client.get('/school/lead/artworks/statistics');
  }

  /// [status]：`PENDING` 待复核 / `REVIEWED` 已复核 / `ALL`。
  Future<ApiResponse> getLeadArtworks({
    required ArtworkStatusFilter status,
    required int page,
    required int size,
    String keyword = '',
  }) {
    return client.get(
      '/school/lead/artworks',
      queryParameters: <String, dynamic>{
        'status': status.code,
        'current': page,
        'size': size,
        if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
      },
    );
  }

  Future<ApiResponse> getLeadArtwork(String id) {
    return client.get('/school/lead/artworks/${_id(id)}');
  }

  /// [approve] 为 false 时退回老师重评，[content] 必填（退回原因）。
  /// [next] 为 true 时返回队列里的下一份待复核作品 id。
  Future<ApiResponse> saveLeadReview({
    required String artworkId,
    required bool approve,
    required String content,
    required double? score,
    required bool exemplar,
    required bool attention,
    required bool next,
  }) {
    return client.post(
      '/school/lead/artworks/review?next=$next',
      data: <String, dynamic>{
        'artworkId': artworkId,
        'action': approve ? 'APPROVE' : 'RETURN',
        'content': content.isEmpty ? null : content,
        'score': score,
        'exemplar': exemplar,
        'attention': attention,
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
  }) {
    return client.post(
      '/school/teacher/tags',
      data: <String, dynamic>{
        'name': name,
        'explanation': explanation.isEmpty ? null : explanation,
        'color': color,
      },
    );
  }

  Future<ApiResponse> updateTag({
    required String id,
    required String name,
    required String explanation,
    required String color,
  }) {
    return client.post(
      '/school/teacher/tags/update',
      data: <String, dynamic>{
        'id': id,
        'name': name,
        'explanation': explanation.isEmpty ? null : explanation,
        'color': color,
      },
    );
  }

  Future<ApiResponse> deleteTag(String id) {
    return client.post(
      '/school/teacher/tags/delete?id=${Uri.encodeQueryComponent(id)}',
    );
  }
}

extension ArtworkApiMessage on ApiResponse {
  /// 接口失败提示：优先使用后端 msg，没有时用 [fallback]。
  String errorOr(String fallback) => displayMsg.isEmpty ? fallback : displayMsg;
}
