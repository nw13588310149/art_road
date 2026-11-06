import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../data/dormitory_check_data.dart';
import '../data/dormitory_repository.dart';
import '../data/student_dormitory_data.dart' show DormitoryDetailField;
import '../data/teacher_leave_data.dart';
import '../data/teacher_notice_data.dart';
import '../data/teacher_repository.dart';
import 'dormitory_manager_state.dart';

final dormitoryManagerControllerProvider =
    StateNotifierProvider<DormitoryManagerController, DormitoryManagerState>(
      (ref) {
        return DormitoryManagerController(
          repository: ref.watch(dormitoryRepositoryProvider),
          teacherRepository: ref.watch(teacherRepositoryProvider),
        );
      },
    );

class DormitoryManagerController extends StateNotifier<DormitoryManagerState> {
  DormitoryManagerController({
    required DormitoryRepository repository,
    required TeacherRepository teacherRepository,
  }) : _repository = repository,
       _teacherRepository = teacherRepository,
       super(const DormitoryManagerState());

  final DormitoryRepository _repository;
  final TeacherRepository _teacherRepository;
  int _roomLoadSerial = 0;
  int _historyLoadSerial = 0;

  Future<void> loadManagedBuildings() async {
    state = state.copyWith(loadingBuildings: true);
    final response = await _repository.dormitoryManagedBuildingList();
    final buildings = response.isSuccess
        ? parseDormitoryManagedBuildingList(response.data)
        : const [DormitoryBuildingOption.all];
    final areas = buildings
        .where((building) => building.id.isNotEmpty)
        .map((building) => building.label)
        .toList(growable: false);
    state = state.copyWith(
      loadingBuildings: false,
      managedBuildings: buildings,
      index: state.index.copyWith(managedAreas: areas),
      error: response.isSuccess ? state.error : response.displayMsg,
    );
  }

  Future<void> loadFloors(String buildingId) async {
    if (buildingId.isEmpty) {
      state = state.copyWith(
        loadingFloors: false,
        floorOptions: const [DormitoryFloorOption.all],
      );
      return;
    }
    state = state.copyWith(loadingFloors: true);
    final response = await _repository.dormitoryFloorList(
      buildingId: buildingId,
    );
    state = state.copyWith(
      loadingFloors: false,
      floorOptions: response.isSuccess
          ? parseDormitoryFloorList(response.data)
          : const [DormitoryFloorOption.all],
      roomCheckError: response.isSuccess ? '' : response.displayMsg,
    );
  }

  Future<void> loadRoomChecks({
    String? buildingId,
    String? floorId,
    required String date,
  }) async {
    final serial = ++_roomLoadSerial;
    state = state.copyWith(loadingRoomChecks: true, roomCheckError: '');
    final responses = await Future.wait([
      _repository.dormitoryCheckStat(),
      _repository.dormitoryCheckRoomList(
        buildingId: buildingId,
        floorId: floorId,
        date: date,
      ),
    ]);
    if (serial != _roomLoadSerial) return;
    final statResponse = responses[0];
    final roomResponse = responses[1];
    if (!statResponse.isSuccess || !roomResponse.isSuccess) {
      state = state.copyWith(
        loadingRoomChecks: false,
        roomCheckStat: DormitoryCheckStat.zero,
        roomChecks: const [],
        roomCheckError: !statResponse.isSuccess
            ? statResponse.displayMsg
            : roomResponse.displayMsg,
      );
      return;
    }
    final rooms = parseDormitoryCheckRoomList(roomResponse.data);
    final hasFilter = buildingId != null || floorId != null;
    state = state.copyWith(
      loadingRoomChecks: false,
      roomCheckStat: hasFilter
          ? calculateDormitoryRoomStat(rooms)
          : parseDormitoryCheckStat(statResponse.data),
      roomChecks: rooms,
      roomCheckError: '',
    );
  }

  Future<ApiResponse> checkInRoom({
    required DormitoryRoomCheck room,
    required String date,
    String? buildingId,
    String? floorId,
  }) async {
    if (room.roomId.isEmpty || state.submittingRoomIds.contains(room.roomId)) {
      return ApiResponse.failure('该宿舍正在打卡中');
    }
    state = state.copyWith(
      submittingRoomIds: {...state.submittingRoomIds, room.roomId},
    );
    final response = await _repository.dormitoryCheckRoomOneClick(
      roomId: room.roomId,
      date: date,
    );
    if (response.isSuccess) {
      await loadRoomChecks(
        buildingId: buildingId,
        floorId: floorId,
        date: date,
      );
    }
    state = state.copyWith(
      submittingRoomIds: {...state.submittingRoomIds}..remove(room.roomId),
    );
    return response;
  }

  Future<ApiResponse> updateStudentCheckStatus({
    required DormitoryRoomStudent student,
    required DormitoryStudentCheckStatus status,
    required String date,
    String? buildingId,
    String? floorId,
  }) async {
    if (student.userId.isEmpty ||
        state.submittingStudentIds.contains(student.userId)) {
      return ApiResponse.failure('该学生状态正在更新中');
    }
    state = state.copyWith(
      submittingStudentIds: {...state.submittingStudentIds, student.userId},
    );
    final response = await _repository.dormitoryCheckUserUpdate(
      userId: student.userId,
      status: status.apiValue,
      date: date,
    );
    if (response.isSuccess) {
      await loadRoomChecks(
        buildingId: buildingId,
        floorId: floorId,
        date: date,
      );
    }
    state = state.copyWith(
      submittingStudentIds: {...state.submittingStudentIds}
        ..remove(student.userId),
    );
    return response;
  }

  Future<void> loadNotices() async {
    state = state.copyWith(loadingNotices: true, noticeError: '');
    final response = await _repository.noticeList(size: 20);
    state = state.copyWith(
      loadingNotices: false,
      notices: response.isSuccess
          ? parseTeacherNoticeList(response.data)
          : const [],
      noticeError: response.isSuccess ? '' : response.displayMsg,
    );
  }

  Future<TeacherNoticeListItem?> loadNoticeDetail(String id) async {
    if (id.isEmpty) return null;
    final response = await _repository.noticeDetail(id: id);
    if (!response.isSuccess) {
      state = state.copyWith(noticeError: response.displayMsg);
      return null;
    }
    return parseTeacherNoticeDetail(response.data);
  }

  Future<void> loadHome({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(loadingHome: true, error: '');
    }
    try {
      final responses = await Future.wait([
        _repository.index(),
        _repository.dormitoryManagedBuildingList(),
        _teacherRepository.teacherLeaveList(current: 1, size: 200, status: 0),
      ]);
      final indexResponse = responses[0];
      final buildingResponse = responses[1];
      final myLeaveResponse = responses[2];
      final buildings = buildingResponse.isSuccess
          ? parseDormitoryManagedBuildingList(buildingResponse.data)
          : state.managedBuildings;
      final areas = buildings
          .where((building) => building.id.isNotEmpty)
          .map((building) => building.label)
          .toList(growable: false);
      final errors = responses
          .where((response) => !response.isSuccess)
          .map((response) => response.displayMsg)
          .where((message) => message.isNotEmpty)
          .toSet()
          .join('；');
      final teacherLeavePendingCount = myLeaveResponse.isSuccess
          ? parseTeacherLeavePendingCount(myLeaveResponse.data)
          : state.teacherLeavePendingCount;

      state = state.copyWith(
        loadingHome: false,
        index: indexResponse.isSuccess
            ? parseDormitoryIndexOverview(
                indexResponse.data,
              ).copyWith(managedAreas: areas)
            : state.index,
        managedBuildings: buildings,
        teacherLeavePendingCount: teacherLeavePendingCount,
        error: errors,
      );
    } catch (_) {
      state = state.copyWith(loadingHome: false);
    }
  }

  Future<void> loadHistory({
    String? buildingId,
    String? floorId,
    required String date,
  }) async {
    final serial = ++_historyLoadSerial;
    state = state.copyWith(loadingHistory: true, error: '');
    final response = await _repository.dormitoryCheckHistory(
      buildingId: buildingId,
      floorId: floorId,
      beginDate: date,
      endDate: date,
    );
    if (serial != _historyLoadSerial) return;
    final items = response.isSuccess
        ? parseDormitoryCheckHistoryList(response.data)
        : const <DormitoryCheckHistoryItem>[];
    state = state.copyWith(
      loadingHistory: false,
      historyStat: calculateDormitoryHistoryStat(items),
      historyItems: items,
      error: response.isSuccess ? '' : response.displayMsg,
    );
  }

  Future<Uint8List?> exportHistory({
    String? buildingId,
    String? floorId,
    required String date,
  }) async {
    if (state.exporting) return null;
    state = state.copyWith(exporting: true, error: '');
    try {
      final bytes = await _repository.dormitoryCheckExport(
        buildingId: buildingId,
        floorId: floorId,
        beginDate: date,
        endDate: date,
      );
      state = state.copyWith(exporting: false);
      return bytes;
    } catch (_) {
      state = state.copyWith(exporting: false, error: '导出失败，请稍后重试');
      return null;
    }
  }

  Future<ApiResponse> handleException({
    required DormitoryCheckHistoryItem item,
    required int handleStatus,
    String remark = '',
  }) async {
    final key = '${item.id}:${item.userId}';
    if (item.id.isEmpty ||
        item.userId.isEmpty ||
        state.submittingExceptionIds.contains(key)) {
      return ApiResponse.failure('异常记录正在处理中');
    }
    state = state.copyWith(
      submittingExceptionIds: {...state.submittingExceptionIds, key},
    );
    final response = await _repository.dormitoryCheckExceptionHandle(
      checkId: item.id,
      studentId: item.userId,
      handleStatus: handleStatus,
      remark: remark,
    );
    if (response.isSuccess) {
      final updated = [
        for (final record in state.historyItems)
          if (record.id == item.id && record.userId == item.userId)
            DormitoryCheckHistoryItem(
              id: record.id,
              userId: record.userId,
              studentName: record.studentName,
              studentNo: record.studentNo,
              dormName: record.dormName,
              bedName: record.bedName,
              checkDate: record.checkDate,
              checkType: record.checkType,
              deadline: record.deadline,
              checkTime: record.checkTime,
              status: record.status,
              statusLabel: record.statusLabel,
              remark: remark.isEmpty ? record.remark : remark,
              handleStatus: handleStatus,
              avatarUrl: record.avatarUrl,
              mobile: record.mobile,
              gender: record.gender,
            )
          else
            record,
      ];
      state = state.copyWith(historyItems: updated);
    }
    state = state.copyWith(
      submittingExceptionIds: {...state.submittingExceptionIds}..remove(key),
    );
    return response;
  }

  Future<void> loadMakeups({String? buildingId, int? status = 0}) async {
    state = state.copyWith(loadingMakeup: true, error: '');
    final response = await _repository.dormitoryMakeupList(
      buildingId: buildingId,
      status: status,
    );
    state = state.copyWith(
      loadingMakeup: false,
      makeupItems: response.isSuccess
          ? parseDormitoryMakeupList(response.data)
          : state.makeupItems,
      makeupBuildingId: buildingId,
      clearMakeupBuildingId: buildingId == null,
      makeupStatus: status,
      clearMakeupStatus: status == null,
      error: response.isSuccess ? '' : response.displayMsg,
    );
  }

  Future<ApiResponse> auditMakeup({
    required String id,
    required bool approve,
    String auditReason = '',
  }) async {
    if (id.isEmpty || state.submittingMakeupIds.contains(id)) {
      return ApiResponse.failure('补卡申请正在处理中');
    }
    state = state.copyWith(
      submittingMakeupIds: {...state.submittingMakeupIds, id},
    );
    final response = await _repository.dormitoryMakeupAudit(
      id: id,
      status: approve ? 1 : 2,
      auditReason: auditReason,
    );
    if (response.isSuccess) {
      await Future.wait([
        loadMakeups(
          buildingId: state.makeupBuildingId,
          status: state.makeupStatus,
        ),
        loadHome(),
      ]);
    }
    state = state.copyWith(
      submittingMakeupIds: {...state.submittingMakeupIds}..remove(id),
    );
    return response;
  }

  Future<List<DormitoryDetailField>> loadCheckDetail(String id) async {
    if (id.isEmpty) return const [];
    final response = await _repository.dormitoryCheckDetail(id: id);
    if (!response.isSuccess) return const [];
    return parseDormitoryCheckDetailFields(response.data);
  }

  Future<List<DormitoryDetailField>> loadMakeupDetail(String id) async {
    if (id.isEmpty) return const [];
    final response = await _repository.dormitoryMakeupDetail(id: id);
    if (!response.isSuccess) return const [];
    return parseDormitoryMakeupDetailFields(response.data);
  }
}
