import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

final quizPracticeRepositoryProvider = Provider<QuizPracticeRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return QuizPracticeRepository(client: client);
});

class QuizPracticeRepository {
  QuizPracticeRepository({required this.client});

  final ApiClient client;

  /// 刷题数据汇总：返回顺序练习/随机练习/考前密卷/错题集 4 类的统计数据。
  ///
  /// [schoolId]：首页公开刷题固定传 `0`；校园课件刷题传真实学校 id。
  Future<ApiResponse> getSummary({required String schoolId}) {
    return client.post(
      '/app/user/questionPracticeSummary',
      data: <String, dynamic>{'schoolId': schoolId},
    );
  }

  /// 创建一组练习（status==null 时初始化）。size 默认 25。
  Future<ApiResponse> createPractice({
    required String schoolId,
    required String practiceType,
    int size = 25,
  }) {
    return client.post(
      '/app/user/questionPracticeCreate',
      data: <String, dynamic>{
        'schoolId': schoolId,
        'practiceType': practiceType,
        'size': size.toString(),
      },
    );
  }

  /// 根据 practiceId 拉取该轮练习的全部题目。
  Future<ApiResponse> getItemList({
    required String schoolId,
    required int practiceId,
  }) {
    return client.post(
      '/app/user/questionPracticeItemList',
      data: <String, dynamic>{
        'schoolId': schoolId,
        'practiceId': practiceId,
      },
      lightweightJson: true,
    );
  }

  /// 上报答题结果。status: 1=正确, 2=错误。
  Future<ApiResponse> reportAnswer({
    required String schoolId,
    required int questionPracticeItemId,
    required int answer,
    required int status,
  }) {
    return client.post(
      '/app/user/questionPracticeItemReport',
      data: <String, dynamic>{
        'schoolId': schoolId,
        'answer': answer,
        'questionPracticeItemId': questionPracticeItemId,
        'status': status,
      },
    );
  }
}
