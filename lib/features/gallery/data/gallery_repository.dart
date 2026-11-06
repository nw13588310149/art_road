import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';
import 'gallery_models.dart';

final galleryRepositoryProvider = Provider<GalleryRepository>((ref) {
  return GalleryRepository(client: ref.watch(markingApiClientProvider));
});

class GalleryRepository {
  GalleryRepository({required this.client});

  final ApiClient client;

  /// 分类及作品数；传 [subject] 时数量只统计该科目。
  Future<ApiResponse> getCategories({String subject = ''}) {
    return client.get(
      '/app/gallery/categories',
      queryParameters: <String, dynamic>{
        if (subject.isNotEmpty) 'subject': subject,
      },
    );
  }

  Future<ApiResponse> getWorks({
    String category = '',
    String subject = '',
    String keyword = '',
    GallerySort sort = GallerySort.latest,
    int current = 1,
    int size = 12,
  }) {
    return client.get(
      '/app/gallery/works',
      queryParameters: <String, dynamic>{
        if (category.isNotEmpty) 'category': category,
        if (subject.isNotEmpty) 'subject': subject,
        if (keyword.isNotEmpty) 'keyword': keyword,
        'sort': sort.key,
        'current': current,
        'size': size,
      },
    );
  }

  Future<ApiResponse> getWorkDetail(String id) {
    return client.get('/app/gallery/works/${Uri.encodeComponent(id)}');
  }

  Future<ApiResponse> setFavorite(String id, {required bool favorite}) {
    return client.post(
      '/app/gallery/works/${Uri.encodeComponent(id)}/favorite',
      data: <String, dynamic>{'favorite': favorite},
    );
  }

  /// 本人最近一份同科原卷：学情概览按考试从新到旧排列，取第一份可查看的原卷。
  Future<GalleryMyPaper?> findLatestPaper(String subjectName) async {
    final overview = await client.get('/app/study/overview');
    if (!overview.isSuccess) {
      return null;
    }
    final data = overview.data;
    final exams = data is Map ? data['exams'] : data;
    if (exams is! List) {
      return null;
    }
    var attempts = 0;
    for (final exam in exams) {
      if (exam is! Map || exam['subjects'] is! List) {
        continue;
      }
      for (final subject in exam['subjects'] as List) {
        if (subject is! Map ||
            subject['subjectName']?.toString() != subjectName ||
            !_isTrue(subject['paperAvailable'])) {
          continue;
        }
        final examId = exam['examId']?.toString() ?? '';
        final subjectId = subject['subjectId']?.toString() ?? '';
        if (examId.isEmpty || subjectId.isEmpty) {
          continue;
        }
        final paper = await client.get(
          '/app/study/exams/${Uri.encodeComponent(examId)}'
          '/papers/${Uri.encodeComponent(subjectId)}',
        );
        final paperData = paper.data;
        if (paper.isSuccess &&
            paperData is Map &&
            paperData['paperAvailable'] != false) {
          final imageUrl = paperData['imageUrl']?.toString().trim() ?? '';
          if (imageUrl.isNotEmpty) {
            return GalleryMyPaper(
              imageUrl: imageUrl,
              examName:
                  (exam['examName'] ?? paperData['examName'])?.toString() ?? '',
            );
          }
        }
        attempts++;
        if (attempts >= 3) {
          return null;
        }
      }
    }
    return null;
  }

  static bool _isTrue(Object? value) =>
      value == true || value == 1 || value == 'true' || value == '1';
}
