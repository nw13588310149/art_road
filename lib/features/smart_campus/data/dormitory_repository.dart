import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/snowflake_id.dart';
import '../../../core/providers/app_providers.dart';

/// 宿管端 `POST /app/school/v2/dormitory/*`。
final dormitoryRepositoryProvider = Provider<DormitoryRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return DormitoryRepository(client: client);
});

class DormitoryRepository {
  DormitoryRepository({required this.client});

  final ApiClient client;

  static const _base = '/app/school/v2/dormitory';

  Future<ApiResponse> _postEncoded(
    String path,
    Map<String, dynamic> body, {
    Set<String> numericIdKeys = const {},
    Set<String> numericIdArrayKeys = const {},
    String idErrorMessage = 'id 格式错误',
  }) {
    final encoded = encodeNumericIdRequestBody(
      body,
      numericIdKeys: numericIdKeys,
      numericIdArrayKeys: numericIdArrayKeys,
    );
    if (encoded == null) {
      return Future.value(ApiResponse.failure(idErrorMessage));
    }
    return client.post(path, data: encoded);
  }

  Future<ApiResponse> _postLongId(String path, String id) {
    return _postEncoded(
      path,
      <String, dynamic>{'id': id},
      numericIdKeys: const {'id'},
    );
  }

  /// 宿管首页通知列表。`AppSchoolNoticeListBO`：`current` / `size` 分页。
  Future<ApiResponse> noticeList({int current = 1, int size = 20}) {
    return client.post(
      '$_base/noticeList',
      data: <String, dynamic>{'current': current, 'size': size},
    );
  }

  /// 宿管端通知详情。`LongIdBO`：`id`(int64)。
  Future<ApiResponse> noticeDetail({required String id}) {
    return _postLongId('$_base/noticeDetail', id);
  }

  // ============== 按宿舍查寝 ==============

  /// 查寝顶部统计。无请求体。
  Future<ApiResponse> dormitoryCheckStat() {
    return client.post('$_base/dormitoryCheckStat');
  }

  /// 宿管管辖宿舍楼列表。无请求体。
  Future<ApiResponse> dormitoryManagedBuildingList() {
    return client.post('$_base/dormitoryManagedBuildingList');
  }

  /// 指定宿舍楼的楼层列表。`DormitoryFloorListReq`：`buildingId`(int64) 必填。
  Future<ApiResponse> dormitoryFloorList({required String buildingId}) {
    return _postEncoded(
      '$_base/dormitoryFloorList',
      <String, dynamic>{'buildingId': buildingId},
      numericIdKeys: const {'buildingId'},
      idErrorMessage: '宿舍楼 id 格式错误',
    );
  }

  /// 查寝寝室列表。`DormitoryRoomCheckListReq`：`date` / `buildingId` / `floorId`。
  Future<ApiResponse> dormitoryCheckRoomList({
    String? buildingId,
    String? floorId,
    String? date,
  }) {
    return _postEncoded(
      '$_base/dormitoryCheckRoomList',
      <String, dynamic>{
        if (date != null && date.isNotEmpty) 'date': date,
        if (buildingId != null && buildingId.isNotEmpty)
          'buildingId': buildingId,
        if (floorId != null && floorId.isNotEmpty) 'floorId': floorId,
      },
      numericIdKeys: const {'buildingId', 'floorId'},
      idErrorMessage: '宿舍楼或楼层 id 格式错误',
    );
  }

  /// 查寝房间一键打卡。`DormitoryRoomOneClickCheckInReq`：`roomId`(int64) 必填。
  Future<ApiResponse> dormitoryCheckRoomOneClick({
    required String roomId,
    String? date,
  }) {
    return _postEncoded(
      '$_base/dormitoryCheckRoomOneClick',
      <String, dynamic>{
        'roomId': roomId,
        if (date != null && date.isNotEmpty) 'date': date,
      },
      numericIdKeys: const {'roomId'},
      idErrorMessage: '宿舍 id 格式错误',
    );
  }

  /// 单个学生查寝状态修改。`DormitoryUserCheckInUpdateReq`。
  Future<ApiResponse> dormitoryCheckUserUpdate({
    required String userId,
    required String status,
    String? date,
  }) {
    return _postEncoded(
      '$_base/dormitoryCheckUserUpdate',
      <String, dynamic>{
        'userId': userId,
        'status': status,
        if (date != null && date.isNotEmpty) 'date': date,
      },
      numericIdKeys: const {'userId'},
      idErrorMessage: '学生 id 格式错误',
    );
  }

  // ============== 宿管首页 / 历史 / 异常 / 补卡 ==============

  /// 宿管首页工作台汇总。无请求体。
  Future<ApiResponse> index() {
    return client.post('$_base/index');
  }

  /// 查寝历史记录。`DormitoryCheckHistoryReq`：`beginDate`/`endDate`/`current`/`size` 必填。
  Future<ApiResponse> dormitoryCheckHistory({
    String? buildingId,
    String? floorId,
    String? roomId,
    required String beginDate,
    required String endDate,
    String? status,
    int current = 1,
    int size = 200,
  }) {
    return _postEncoded(
      '$_base/dormitoryCheckHistory',
      <String, dynamic>{
        'beginDate': beginDate,
        'endDate': endDate,
        'current': current,
        'size': size,
        if (buildingId != null && buildingId.isNotEmpty)
          'buildingId': buildingId,
        if (floorId != null && floorId.isNotEmpty) 'floorId': floorId,
        if (roomId != null && roomId.isNotEmpty) 'roomId': roomId,
        if (status != null && status.isNotEmpty) 'status': status,
      },
      numericIdKeys: const {'buildingId', 'floorId', 'roomId'},
      idErrorMessage: '查寝筛选 id 格式错误',
    );
  }

  /// 单次查寝详情。`LongIdBO`。
  Future<ApiResponse> dormitoryCheckDetail({required String id}) {
    return _postLongId('$_base/dormitoryCheckDetail', id);
  }

  /// 查寝异常处理。`DormitoryCheckExceptionHandleReq`。
  Future<ApiResponse> dormitoryCheckExceptionHandle({
    required String checkId,
    required String studentId,
    required int handleStatus,
    String remark = '',
  }) {
    return _postEncoded(
      '$_base/dormitoryCheckExceptionHandle',
      <String, dynamic>{
        'checkId': checkId,
        'studentId': studentId,
        'handleStatus': handleStatus,
        if (remark.isNotEmpty) 'remark': remark,
      },
      numericIdKeys: const {'checkId', 'studentId'},
      idErrorMessage: '查寝或学生 id 格式错误',
    );
  }

  /// 导出查寝记录。GET `dormitoryCheckExport`，`DormitoryCheckExportReq`。
  Future<Uint8List> dormitoryCheckExport({
    required String beginDate,
    required String endDate,
    String? buildingId,
    String? floorId,
    String? roomId,
    String? status,
  }) {
    final params = <String, dynamic>{
      'beginDate': beginDate,
      'endDate': endDate,
      if (buildingId != null && buildingId.isNotEmpty)
        'buildingId': readSnowflakeId(buildingId) ?? buildingId,
      if (floorId != null && floorId.isNotEmpty)
        'floorId': readSnowflakeId(floorId) ?? floorId,
      if (roomId != null && roomId.isNotEmpty)
        'roomId': readSnowflakeId(roomId) ?? roomId,
      if (status != null && status.isNotEmpty) 'status': status,
    };
    return client.getBytes(
      '$_base/dormitoryCheckExport',
      queryParameters: params,
      allowEmpty: true,
    );
  }

  /// 宿管端补卡申请列表。`DormitoryMakeupListReq`：`current`/`size` 必填。
  Future<ApiResponse> dormitoryMakeupList({
    String? buildingId,
    int? status,
    int current = 1,
    int size = 200,
  }) {
    return _postEncoded(
      '$_base/dormitoryMakeupList',
      <String, dynamic>{
        'current': current,
        'size': size,
        if (buildingId != null && buildingId.isNotEmpty)
          'buildingId': buildingId,
        'status': ?status,
      },
      numericIdKeys: const {'buildingId'},
      idErrorMessage: '宿舍楼 id 格式错误',
    );
  }

  /// 补卡申请详情。`LongIdBO`。
  Future<ApiResponse> dormitoryMakeupDetail({required String id}) {
    return _postLongId('$_base/dormitoryMakeupDetail', id);
  }

  /// 审批补卡申请。`DormitoryMakeupAuditReq`：`status` 1-通过 / 2-拒绝。
  Future<ApiResponse> dormitoryMakeupAudit({
    required String id,
    required int status,
    String auditReason = '',
  }) {
    return _postEncoded(
      '$_base/dormitoryMakeupAudit',
      <String, dynamic>{
        'id': id,
        'status': status,
        if (auditReason.isNotEmpty) 'auditReason': auditReason,
      },
      numericIdKeys: const {'id'},
      idErrorMessage: '补卡申请 id 格式错误',
    );
  }

  // ============== 班级查寝动态 / 历史（宿管端） ==============

  /// 班级学生最新查寝状态。
  Future<ApiResponse> classDormitoryDynamicList({
    required String classId,
    String? status,
    int current = 1,
    int size = 200,
  }) {
    return _postEncoded(
      '$_base/classDormitoryDynamicList',
      <String, dynamic>{
        'classId': classId,
        'current': current,
        'size': size,
        if (status != null && status.isNotEmpty) 'status': status,
      },
      numericIdKeys: const {'classId'},
      idErrorMessage: '班级 id 格式错误',
    );
  }

  /// 班级历史查寝记录。
  Future<ApiResponse> classDormitoryCheckHistory({
    required String classId,
    String? beginDate,
    String? endDate,
    String? status,
    String? studentId,
    int current = 1,
    int size = 200,
  }) {
    return _postEncoded(
      '$_base/classDormitoryCheckHistory',
      <String, dynamic>{
        'classId': classId,
        'current': current,
        'size': size,
        if (beginDate != null && beginDate.isNotEmpty) 'beginDate': beginDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
        if (status != null && status.isNotEmpty) 'status': status,
        if (studentId != null && studentId.isNotEmpty) 'studentId': studentId,
      },
      numericIdKeys: const {'classId', 'studentId'},
      idErrorMessage: '班级或学生 id 格式错误',
    );
  }

  /// 班级查寝统计。
  Future<ApiResponse> classDormitoryCheckStat({
    required String classId,
    String? beginDate,
    String? endDate,
  }) {
    return _postEncoded(
      '$_base/classDormitoryCheckStat',
      <String, dynamic>{
        'classId': classId,
        if (beginDate != null && beginDate.isNotEmpty) 'beginDate': beginDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
      },
      numericIdKeys: const {'classId'},
      idErrorMessage: '班级 id 格式错误',
    );
  }

  /// 单次查寝详情。
  Future<ApiResponse> classDormitoryCheckDetail({required String id}) {
    return _postLongId('$_base/classDormitoryCheckDetail', id);
  }

  /// 班级补卡申请列表。
  Future<ApiResponse> classDormitoryMakeupList({
    required String classId,
    int? status,
    int current = 1,
    int size = 200,
  }) {
    return _postEncoded(
      '$_base/classDormitoryMakeupList',
      <String, dynamic>{
        'classId': classId,
        'current': current,
        'size': size,
        'status': ?status,
      },
      numericIdKeys: const {'classId'},
      idErrorMessage: '班级 id 格式错误',
    );
  }

  /// 补卡申请详情。
  Future<ApiResponse> classDormitoryMakeupDetail({required String id}) {
    return _postLongId('$_base/classDormitoryMakeupDetail', id);
  }

  /// 审批补卡申请。`status`: 1-通过 / 2-拒绝。
  Future<ApiResponse> classDormitoryMakeupAudit({
    required String id,
    required int status,
    String auditReason = '',
  }) {
    return _postEncoded(
      '$_base/classDormitoryMakeupAudit',
      <String, dynamic>{
        'id': id,
        'status': status,
        if (auditReason.isNotEmpty) 'auditReason': auditReason,
      },
      numericIdKeys: const {'id'},
      idErrorMessage: '补卡申请 id 格式错误',
    );
  }
}
