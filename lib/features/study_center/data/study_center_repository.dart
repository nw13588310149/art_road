import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

final studyCenterRepositoryProvider = Provider<StudyCenterRepository>((ref) {
  final client = ref.watch(markingApiClientProvider);
  return StudyCenterRepository(client: client);
});

/// 接口失败时优先展示后端文案。
String studyResponseMessage(ApiResponse response, String fallback) {
  final message = response.displayMsg;
  return message.isEmpty ? fallback : message;
}

/// 学情中心接口（艺考网阅卷系统）：学生端 `/app/study/*` 认 app-token，
/// 教职端 `/school/*` 认 school-token。
class StudyCenterRepository {
  StudyCenterRepository({required this.client});

  final ApiClient client;

  static String _seg(String value) => Uri.encodeComponent(value);

  // ── 学生端 ───────────────────────────────────────────────────────────

  Future<ApiResponse> overview() => client.get('/app/study/overview');

  /// [status]：`ALL` / `PUBLISHED` / `MARKING`。
  Future<ApiResponse> exams({
    String status = 'ALL',
    int current = 1,
    int size = 10,
  }) {
    return client.get(
      '/app/study/exams',
      queryParameters: <String, dynamic>{
        'status': status,
        'current': current,
        'size': size,
      },
    );
  }

  Future<ApiResponse> examReport(String examId) =>
      client.get('/app/study/exams/${_seg(examId)}');

  Future<ApiResponse> paper(String examId, String subjectId) =>
      client.get('/app/study/exams/${_seg(examId)}/papers/${_seg(subjectId)}');

  Future<ApiResponse> gradeStandard(String examId, String subjectId) =>
      client.get(
        '/app/study/exams/${_seg(examId)}/subjects/${_seg(subjectId)}/standard',
      );

  /// [subjectName] 为空表示总分；[metric]：`SCORE` / `RANKING`。
  Future<ApiResponse> growth({
    String subjectName = '',
    String metric = 'SCORE',
    int limit = 7,
  }) {
    return client.get(
      '/app/study/growth',
      queryParameters: <String, dynamic>{
        if (subjectName.isNotEmpty) 'subjectName': subjectName,
        'metric': metric,
        'limit': limit,
      },
    );
  }

  // ── 教职端 ───────────────────────────────────────────────────────────

  Future<ApiResponse> teacherExams() => client.get('/school/teacher/exams');

  Future<ApiResponse> scoreQuery({
    required String examId,
    int current = 1,
    int size = 200,
    String studentName = '',
  }) {
    return client.post(
      '/school/score-query/page',
      data: <String, dynamic>{
        'examId': examId,
        'current': current,
        'size': size,
        if (studentName.isNotEmpty) 'studentName': studentName,
      },
    );
  }

  Future<ApiResponse> gradeRule({
    required String examId,
    required String subjectId,
  }) {
    return client.post(
      '/school/marking/gradeRule',
      data: <String, dynamic>{'examId': examId, 'subjectId': subjectId},
    );
  }

  Future<ApiResponse> studentReport({
    required String archiveId,
    required String examId,
  }) {
    return client.get(
      '/school/teacher/students/${_seg(archiveId)}/exams/${_seg(examId)}',
    );
  }

  Future<ApiResponse> studentMarking({
    required String archiveId,
    required String examId,
    required String subjectId,
  }) {
    return client.get(
      '/school/teacher/students/${_seg(archiveId)}/exams/${_seg(examId)}'
      '/subjects/${_seg(subjectId)}/marking',
    );
  }

  // ── 月考讲评 ─────────────────────────────────────────────────────────

  static String _critique(String prefix, String examId, String subjectId) =>
      '$prefix/exams/${_seg(examId)}/subjects/${_seg(subjectId)}/critique';

  /// 教职端：这一科的全部卷子、档位、已有的讲评和能不能修改。
  Future<ApiResponse> staffCritique(String examId, String subjectId) =>
      client.get(_critique('/school/teacher', examId, subjectId));

  /// 保存一张卷子的讲评（按 archiveId + shared 新增或覆盖），返回整份讲评。
  Future<ApiResponse> saveCritiquePaper(
    String examId,
    String subjectId,
    Map<String, dynamic> body,
  ) => client.post(
    '${_critique('/school/teacher', examId, subjectId)}/papers',
    data: body,
  );

  Future<ApiResponse> deleteCritiquePaper(
    String examId,
    String subjectId, {
    required String archiveId,
    required bool shared,
  }) => client.post(
    '${_critique('/school/teacher', examId, subjectId)}/papers/delete',
    data: <String, dynamic>{'archiveId': archiveId, 'shared': shared},
  );

  Future<ApiResponse> publishCritique(
    String examId,
    String subjectId, {
    required bool published,
    bool showNames = false,
  }) => client.post(
    '${_critique('/school/teacher', examId, subjectId)}/publish',
    data: <String, dynamic>{'published': published, 'showNames': showNames},
  );

  /// 学生端：已发布的讲评（代表卷 + 本人的个人点评）。
  Future<ApiResponse> studentCritique(String examId, String subjectId) =>
      client.get(_critique('/app/study', examId, subjectId));

  Future<ApiResponse> markCritiqueRead(String examId, String subjectId) =>
      client.post('${_critique('/app/study', examId, subjectId)}/read');

  /// [subject]：`TOTAL` 或科目名称。
  Future<ApiResponse> studentCurve({
    required String archiveId,
    String subject = 'TOTAL',
  }) {
    return client.get(
      '/school/teacher/students/${_seg(archiveId)}/curve',
      queryParameters: <String, dynamic>{'subject': subject},
    );
  }
}
