import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return HomeRepository(client: client);
});

class HomeRepository {
  HomeRepository({required this.client});

  final ApiClient client;

  Future<ApiResponse> getMyInfo() {
    return client.post('/app/user/myInfo');
  }

  /// 学生首页周课表统计：`/app/school/v2/student/courseList`（按 token 过滤）。
  Future<ApiResponse> getStudentCourseList({
    required String beginDate,
    required String endDate,
  }) {
    return client.post(
      '/app/school/v2/student/courseList',
      data: <String, dynamic>{
        'beginDate': beginDate,
        'endDate': endDate,
      },
    );
  }

  /// 教师首页周课表统计：`/app/school/v2/teacher/courseList`（按 token 过滤）。
  Future<ApiResponse> getTeacherCourseList({
    required String beginDate,
    required String endDate,
  }) {
    return client.post(
      '/app/school/v2/teacher/courseList',
      data: <String, dynamic>{
        'beginDate': beginDate,
        'endDate': endDate,
      },
    );
  }

  Future<ApiResponse> getBannerList() {
    return client.post(
      '/app/user/bannerList',
      data: const <String, dynamic>{'contentType': 0},
    );
  }

  Future<ApiResponse> getLatestInfo() {
    return client.post(
      '/app/user/homeLatestInfo',
      data: const <String, dynamic>{'province': '甘肃'},
    );
  }

  Future<ApiResponse> getLearningProgress() {
    return client.post(
      '/app/user/homeLearningProgress',
      data: const <String, dynamic>{'province': '甘肃'},
    );
  }

  Future<ApiResponse> getNextSchoolCourse() {
    return client.post('/app/user/nextSchoolCourse');
  }
}
