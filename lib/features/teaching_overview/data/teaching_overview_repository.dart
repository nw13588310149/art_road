import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

enum TeachingReport {
  overview('/school/principal/overview', '校长驾驶舱'),
  attendance('/school/principal/attendance', '今日到校与在岗'),
  trend('/school/principal/trend', '数据看板'),
  teachers('/school/principal/teachers', '老师履职'),
  teacher('/school/principal/teachers', '老师档案'),
  classes('/school/principal/classes', '全校学情'),
  attention('/school/principal/attention-students', '需要关注的学生'),
  reviewChain('/school/principal/review-chain', '作品点评链'),
  groupTeachers('/school/leader/teachers', '本组老师'),
  groupClasses('/school/leader/classes', '本组学情'),
  myStudents('/school/teacher/students', '我的学生'),
  myPerformance('/school/teacher/performance', '我的履职'),
  myAttention('/school/teacher/attention-students', '需要关注的学生');

  const TeachingReport(this.path, this.title);
  final String path;
  final String title;
}

typedef TeachingRequest = ({
  TeachingReport report,
  String campus,
  String parameter,
});
typedef TeachingRow = Map<String, dynamic>;

TeachingRow teachingRow(Object? raw) =>
    raw is Map<String, dynamic> ? raw : const {};
List<TeachingRow> teachingRows(Object? raw) => raw is List
    ? raw.whereType<TeachingRow>().toList(growable: false)
    : const [];
String teachingText(Object? value) => value?.toString() ?? '';

class TeachingOverviewRepository {
  TeachingOverviewRepository(this._client);

  final ApiClient _client;

  Future<ApiResponse> load(TeachingRequest request) {
    final report = request.report;
    final parameter = request.parameter;
    return _client.get(
      report == TeachingReport.teacher
          ? '${report.path}/${Uri.encodeComponent(parameter)}'
          : report.path,
      queryParameters: {
        if (request.campus.isNotEmpty) 'campusId': request.campus,
        if (report == TeachingReport.trend) 'metric': parameter,
        if (report == TeachingReport.reviewChain && parameter.isNotEmpty)
          ...Uri.splitQueryString(parameter),
      },
    );
  }
}

final teachingOverviewRepositoryProvider = Provider<TeachingOverviewRepository>(
  (ref) => TeachingOverviewRepository(ref.watch(markingApiClientProvider)),
);
