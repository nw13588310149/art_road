import '../../../core/network/api_response.dart';

/// 读取所有记录，让列表、统计和角标使用相同的数据。
Future<ApiResponse> loadDormitoryPages(
  Future<ApiResponse> Function(int current) fetch,
) async {
  final first = await fetch(1);
  final data = first.data;
  if (!first.isSuccess || data is! Map || data['records'] is! List) {
    return first;
  }
  final pages = int.tryParse(data['pages'].toString()) ?? 1;
  if (pages <= 1) return first;
  final records = <dynamic>[...data['records'] as List];
  for (var current = 2; current <= pages; current++) {
    final next = await fetch(current);
    if (!next.isSuccess) return next;
    final page = next.data;
    if (page is! Map || page['records'] is! List) {
      return ApiResponse.failure('查寝列表加载失败');
    }
    final rows = page['records'] as List;
    if (rows.isEmpty) break;
    records.addAll(rows);
  }
  return ApiResponse(code: first.code, msg: first.msg, data: records);
}
