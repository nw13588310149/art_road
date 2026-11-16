import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';

final todayRepositoryProvider = Provider<TodayRepository>((ref) {
  return TodayRepository(client: ref.watch(apiClientProvider));
});

/// 今日看板接口。读和写都返回完整的看板，界面拿到就整份替换。
class TodayRepository {
  TodayRepository({required this.client});

  final ApiClient client;

  /// 当前身份当天的清单、进度、下一步与图表。
  Future<ApiResponse> board() => client.post('/app/today/board');

  /// 打勾 / 取消打勾（只对需要本人确认的事有效）。
  Future<ApiResponse> complete(String id) =>
      client.post('/app/today/step/complete', data: {'id': id});

  Future<ApiResponse> reopen(String id) =>
      client.post('/app/today/step/reopen', data: {'id': id});

  /// 今天不做 / 恢复（只对建议做的事有效）。
  Future<ApiResponse> skip(String id) =>
      client.post('/app/today/step/skip', data: {'id': id});

  Future<ApiResponse> restore(String id) =>
      client.post('/app/today/step/restore', data: {'id': id});

  /// 推迟到晚上 / 取消推迟。
  Future<ApiResponse> snooze(String id, {required bool on}) =>
      client.post('/app/today/step/snooze', data: {'id': id, 'on': on});

  /// 添加一件自己的安排。[slot]：morning / afternoon / evening / anytime。
  Future<ApiResponse> saveStep({
    required String title,
    required String slot,
    String detail = '',
  }) => client.post(
    '/app/today/step/save',
    data: {'title': title, 'slot': slot, 'detail': detail},
  );

  Future<ApiResponse> deleteStep(String id) =>
      client.post('/app/today/step/delete', data: {'id': id});

  /// 记录练习时长（分钟）。
  Future<ApiResponse> logPractice(int minutes) =>
      client.post('/app/today/practice/log', data: {'minutes': minutes});

  /// 标记一名学生或一件事已经跟进。
  Future<ApiResponse> follow(String id, {required bool followed}) => client
      .post('/app/today/people/follow', data: {'id': id, 'followed': followed});

  /// 不再显示用法提示。
  Future<ApiResponse> dismissTip() => client.post('/app/today/tip/dismiss');
}
