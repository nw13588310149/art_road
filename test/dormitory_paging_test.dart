import 'package:the_road_of_art_flutter/core/network/api_response.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/data/dormitory_paging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('读取后续页，让历史统计和待审数计入全部记录', () async {
    final calls = <int>[];
    final result = await loadDormitoryPages((current) async {
      calls.add(current);
      return ApiResponse(
        code: 0,
        msg: 'ok',
        data: {
          'records': [current],
          'pages': 3,
        },
      );
    });
    expect(calls, [1, 2, 3]);
    expect(result.data, [1, 2, 3]);
  });

  test('后续页请求失败时不发布缺页数据', () async {
    final result = await loadDormitoryPages(
      (current) async => current == 1
          ? const ApiResponse(
              code: 0,
              msg: 'ok',
              data: {
                'records': [1],
                'pages': 2,
              },
            )
          : ApiResponse.failure('加载失败'),
    );
    expect(result.isSuccess, isFalse);
    expect(result.displayMsg, '加载失败');
  });
}
