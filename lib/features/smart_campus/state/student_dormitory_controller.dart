import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../data/student_dormitory_data.dart';
import '../data/student_repository.dart';
import 'student_dormitory_state.dart';

final studentDormitoryControllerProvider =
    StateNotifierProvider.autoDispose<
      StudentDormitoryController,
      StudentDormitoryState
    >((ref) {
      return StudentDormitoryController(
        repository: ref.watch(studentRepositoryProvider),
      );
    });

class StudentDormitoryController extends StateNotifier<StudentDormitoryState> {
  StudentDormitoryController({required StudentRepository repository})
    : _repository = repository,
      super(const StudentDormitoryState());

  final StudentRepository _repository;
  bool _initialized = false;

  void selectListSection(StudentDormitoryListSection section) {
    if (section == state.listSection) return;
    state = state.copyWith(listSection: section);
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: '');
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final beginDate = studentDormitoryIsoDate(monthStart);
    final endDate = studentDormitoryIsoDate(now);
    final responses = await Future.wait([
      _repository.myDormitoryInfo(),
      _repository.dormitoryCheckStat(beginDate: beginDate, endDate: endDate),
      _repository.dormitoryCheckHistory(beginDate: beginDate, endDate: endDate),
      _repository.dormitoryMakeupList(),
    ]);
    final errors = responses
        .where((response) => !response.isSuccess)
        .map((response) => response.displayMsg)
        .where((message) => message.isNotEmpty)
        .toSet()
        .join('；');
    final makeupItems = responses[3].isSuccess
        ? parseStudentDormitoryMakeupList(responses[3].data)
        : const <StudentDormitoryMakeupItem>[];
    state = state.copyWith(
      loading: false,
      dormInfo: responses[0].isSuccess
          ? StudentDormitoryInfo.fromJson(responses[0].data)
          : state.dormInfo,
      stat: responses[1].isSuccess
          ? StudentDormitoryStat.fromJson(responses[1].data)
          : state.stat,
      records: responses[2].isSuccess
          ? parseStudentDormitoryCheckHistory(responses[2].data)
          : state.records,
      makeupItems: makeupItems,
      pendingMakeupCount: makeupItems.where((item) => item.status == 0).length,
      error: errors,
    );
  }

  Future<List<DormitoryDetailField>> loadCheckDetail(String id) async {
    if (id.isEmpty) return const [];
    final response = await _repository.dormitoryCheckDetail(id: id);
    if (!response.isSuccess) return const [];
    return parseStudentDormitoryCheckDetailFields(response.data);
  }

  Future<List<DormitoryDetailField>> loadMakeupDetail(String id) async {
    if (id.isEmpty) return const [];
    final response = await _repository.dormitoryMakeupDetail(id: id);
    if (!response.isSuccess) return const [];
    return parseStudentDormitoryMakeupDetailFields(response.data);
  }

  Future<ApiResponse> submitMakeup({
    required DateTime date,
    required String sceneLabel,
    required String reason,
  }) async {
    if (state.submittingMakeup) {
      return ApiResponse.failure('补卡申请提交中');
    }
    state = state.copyWith(submittingMakeup: true, error: '');
    final response = await _repository.dormitoryMakeupSave(
      date: studentDormitoryIsoDate(date),
      checkType: studentDormitoryMakeupSceneApi(sceneLabel),
      reason: reason,
    );
    if (response.isSuccess) {
      await refresh();
    }
    state = state.copyWith(submittingMakeup: false);
    return response;
  }

  Future<ApiResponse> cancelMakeup(String id) async {
    if (id.isEmpty || state.cancellingMakeupId == id) {
      return ApiResponse.failure('补卡申请正在撤销');
    }
    state = state.copyWith(cancellingMakeupId: id);
    final response = await _repository.dormitoryMakeupCancel(id: id);
    if (response.isSuccess) {
      await refresh();
    }
    state = state.copyWith(cancellingMakeupId: '');
    return response;
  }
}
