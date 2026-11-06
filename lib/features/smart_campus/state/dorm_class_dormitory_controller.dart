import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../data/admin_repository.dart';
import '../data/dormitory_repository.dart';
import '../data/head_teacher_index_data.dart';
import '../data/student_dormitory_data.dart' show DormitoryDetailField;
import '../data/teacher_dormitory_data.dart';
import '../data/teacher_repository.dart';
import 'teacher_dormitory_state.dart';

final dormClassDormitoryControllerProvider =
    StateNotifierProvider.autoDispose<
      DormClassDormitoryController,
      TeacherDormitoryState
    >((ref) {
      return DormClassDormitoryController(
        repository: ref.watch(dormitoryRepositoryProvider),
        adminRepository: ref.watch(adminRepositoryProvider),
        teacherRepository: ref.watch(teacherRepositoryProvider),
      );
    });

class DormClassDormitoryController extends StateNotifier<TeacherDormitoryState> {
  DormClassDormitoryController({
    required DormitoryRepository repository,
    required AdminRepository adminRepository,
    required TeacherRepository teacherRepository,
  }) : _repository = repository,
       _adminRepository = adminRepository,
       _teacherRepository = teacherRepository,
       super(
         TeacherDormitoryState(
           selectedDate: teacherDormitoryIsoDate(DateTime.now()),
         ),
       );

  final DormitoryRepository _repository;
  final AdminRepository _adminRepository;
  final TeacherRepository _teacherRepository;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    state = state.copyWith(loading: true, error: '');
    final classes = await _loadClasses();
    if (classes.isEmpty) {
      state = state.copyWith(
        loading: false,
        classes: classes,
        error: '当前账号暂无可用班级',
      );
      return;
    }
    state = state.copyWith(
      classes: classes,
      selectedClassId: classes.first.classId,
    );
    await refresh();
  }

  Future<List<HeadTeacherClassItem>> _loadClasses() async {
    final adminResponse = await _adminRepository.classList();
    if (adminResponse.isSuccess) {
      final classes = parseClassListItems(adminResponse.data);
      if (classes.isNotEmpty) return classes;
    }
    final teacherResponse = await _teacherRepository.classList();
    if (teacherResponse.isSuccess) {
      return parseClassListItems(teacherResponse.data);
    }
    return const [];
  }

  Future<void> selectClass(String classId) async {
    if (classId.isEmpty || classId == state.selectedClassId) return;
    state = state.copyWith(selectedClassId: classId);
    await refresh();
  }

  Future<void> refresh() async {
    final classId = state.selectedClassId;
    if (classId.isEmpty) return;
    state = state.copyWith(loading: true, error: '');
    final date = state.selectedDate;
    final responses = await Future.wait([
      _repository.classDormitoryDynamicList(classId: classId),
      _repository.classDormitoryMakeupList(classId: classId),
      _repository.classDormitoryCheckStat(
        classId: classId,
        beginDate: date,
        endDate: date,
      ),
      _repository.classDormitoryCheckHistory(
        classId: classId,
        beginDate: date,
        endDate: date,
      ),
    ]);
    final errors = responses
        .where((response) => !response.isSuccess)
        .map((response) => response.displayMsg)
        .where((message) => message.isNotEmpty)
        .toSet()
        .join('；');
    final stat = responses[2].isSuccess
        ? TeacherDormitoryStat.fromJson(responses[2].data)
        : state.stat;
    final makeupItems = responses[1].isSuccess
        ? parseTeacherDormitoryMakeupList(responses[1].data)
        : state.makeupItems;
    final pendingMakeupCount = makeupItems
        .where((item) => item.status == 0)
        .length;
    state = state.copyWith(
      loading: false,
      overview: TeacherDormitoryOverview(
        classId: classId,
        enrolledDormCount: stat.studentCount,
        pendingMakeupCount: pendingMakeupCount,
        todayAbsentCount: stat.absentCount,
        todayLateCount: stat.lateCount,
        todayNormalCount: stat.normalCount,
      ),
      dynamicItems: responses[0].isSuccess
          ? parseTeacherDormitoryDynamicList(responses[0].data)
          : state.dynamicItems,
      makeupItems: makeupItems,
      stat: stat,
      historyItems: responses[3].isSuccess
          ? parseTeacherDormitoryHistoryList(responses[3].data)
          : state.historyItems,
      error: errors,
    );
  }

  Future<void> selectHistoryDate(DateTime date) async {
    final value = teacherDormitoryIsoDate(date);
    if (value == state.selectedDate || state.selectedClassId.isEmpty) return;
    state = state.copyWith(
      selectedDate: value,
      loadingHistory: true,
      error: '',
    );
    final responses = await Future.wait([
      _repository.classDormitoryCheckStat(
        classId: state.selectedClassId,
        beginDate: value,
        endDate: value,
      ),
      _repository.classDormitoryCheckHistory(
        classId: state.selectedClassId,
        beginDate: value,
        endDate: value,
      ),
    ]);
    state = state.copyWith(
      loadingHistory: false,
      stat: responses[0].isSuccess
          ? TeacherDormitoryStat.fromJson(responses[0].data)
          : state.stat,
      historyItems: responses[1].isSuccess
          ? parseTeacherDormitoryHistoryList(responses[1].data)
          : state.historyItems,
      error: {
        for (final response in responses)
          if (!response.isSuccess && response.displayMsg.isNotEmpty)
            response.displayMsg,
      }.join('；'),
    );
  }

  Future<ApiResponse> auditMakeup({
    required String id,
    required bool approve,
  }) async {
    if (id.isEmpty || state.submittingMakeupIds.contains(id)) {
      return ApiResponse.failure('补卡申请正在处理中');
    }
    state = state.copyWith(
      submittingMakeupIds: {...state.submittingMakeupIds, id},
    );
    final response = await _repository.classDormitoryMakeupAudit(
      id: id,
      status: approve ? 1 : 2,
    );
    if (response.isSuccess) {
      await _reloadMakeups();
    }
    state = state.copyWith(
      submittingMakeupIds: {...state.submittingMakeupIds}..remove(id),
    );
    return response;
  }

  Future<List<DormitoryDetailField>> loadCheckDetail(String id) async {
    if (id.isEmpty) return const [];
    final response = await _repository.classDormitoryCheckDetail(id: id);
    if (!response.isSuccess) return const [];
    return parseTeacherDormitoryCheckDetailFields(response.data);
  }

  Future<List<DormitoryDetailField>> loadMakeupDetail(String id) async {
    if (id.isEmpty) return const [];
    final response = await _repository.classDormitoryMakeupDetail(id: id);
    if (!response.isSuccess) return const [];
    return parseTeacherDormitoryMakeupDetailFields(response.data);
  }

  Future<void> _reloadMakeups() async {
    final classId = state.selectedClassId;
    if (classId.isEmpty) return;
    final response = await _repository.classDormitoryMakeupList(classId: classId);
    if (!response.isSuccess) return;
    final makeupItems = parseTeacherDormitoryMakeupList(response.data);
    final pendingMakeupCount = makeupItems
        .where((item) => item.status == 0)
        .length;
    state = state.copyWith(
      makeupItems: makeupItems,
      overview: state.overview.copyWith(
        pendingMakeupCount: pendingMakeupCount,
      ),
    );
  }
}

extension on TeacherDormitoryOverview {
  TeacherDormitoryOverview copyWith({
    String? classId,
    String? className,
    int? enrolledDormCount,
    int? pendingMakeupCount,
    int? todayAbsentCount,
    int? todayLateCount,
    int? todayNormalCount,
  }) {
    return TeacherDormitoryOverview(
      classId: classId ?? this.classId,
      className: className ?? this.className,
      enrolledDormCount: enrolledDormCount ?? this.enrolledDormCount,
      pendingMakeupCount: pendingMakeupCount ?? this.pendingMakeupCount,
      todayAbsentCount: todayAbsentCount ?? this.todayAbsentCount,
      todayLateCount: todayLateCount ?? this.todayLateCount,
      todayNormalCount: todayNormalCount ?? this.todayNormalCount,
    );
  }
}
