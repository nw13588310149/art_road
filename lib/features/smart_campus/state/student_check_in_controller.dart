import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../../school/data/school_repository.dart';
import '../data/student_check_in_data.dart';
import '../data/student_repository.dart';
import 'student_check_in_state.dart';

final studentCheckInControllerProvider =
    StateNotifierProvider.autoDispose<
      StudentCheckInController,
      StudentCheckInState
    >((ref) {
      final controller = StudentCheckInController(
        studentRepository: ref.watch(studentRepositoryProvider),
        schoolRepository: ref.watch(schoolRepositoryProvider),
      );
      ref.onDispose(controller.stopLiveSync);
      return controller;
    });

/// 学生「课堂考勤」：今天的课和本人的到课情况、考勤统计、最近记录、历史与补签。
///
/// 上课由任课老师签课，学生端只读；页面可见时定时刷新今天的课，老师签完课
/// 这里就能看到结果。
class StudentCheckInController extends StateNotifier<StudentCheckInState> {
  StudentCheckInController({
    required StudentRepository studentRepository,
    required SchoolRepository schoolRepository,
  }) : _studentRepository = studentRepository,
       _schoolRepository = schoolRepository,
       super(const StudentCheckInState());

  final StudentRepository _studentRepository;
  final SchoolRepository _schoolRepository;
  bool _initialized = false;
  Timer? _liveSyncTimer;
  bool _liveSyncActive = false;
  bool _syncingCourses = false;
  List<StudentTimeConfig> _timeConfigs = kDefaultStudentTimeConfigs;

  static const _liveSyncInterval = Duration(seconds: 30);

  /// 页面可见时启动：定时刷新今天的课，老师签课后到课情况跟着更新。
  void startLiveSync() {
    if (_liveSyncActive) return;
    _liveSyncActive = true;
    _liveSyncTimer?.cancel();
    _liveSyncTimer = Timer.periodic(_liveSyncInterval, (_) {
      unawaited(_syncTodayCourses());
    });
  }

  void stopLiveSync() {
    _liveSyncActive = false;
    _liveSyncTimer?.cancel();
    _liveSyncTimer = null;
  }

  /// App 回到前台时立即同步一次。
  Future<void> resumeSync() => _syncTodayCourses();

  /// 重新拉今天的 `courseList` 和最近记录，尽量保持当前选中的课。
  Future<void> _syncTodayCourses() async {
    if (_syncingCourses || state.submitting || state.loading) return;
    _syncingCourses = true;
    try {
      final today = DateTime.now();
      final todayIso = todayIsoDate();
      final responses = await Future.wait([
        _studentRepository.courseList(beginDate: todayIso, endDate: todayIso),
        _studentRepository.courseSignRecentList(size: 6),
      ]);
      final courseResp = responses[0];
      final recentResp = responses[1];
      if (!mounted || !courseResp.isSuccess) return;

      final courses = parseStudentTodayCourses(
        raw: courseResp.data,
        timeConfigs: _timeConfigs,
        now: today,
        todayIso: todayIso,
      );
      final hasSelected =
          state.selectedCourseId != null &&
          courses.any((c) => c.courseId == state.selectedCourseId);
      state = state.copyWith(
        todayCourses: courses,
        recentRecords: recentResp.isSuccess
            ? parseStudentSignRecordList(recentResp.data)
            : state.recentRecords,
        selectedCourseId: hasSelected
            ? state.selectedCourseId
            : pickActiveStudentCourse(courses)?.courseId,
      );
    } finally {
      _syncingCourses = false;
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await refresh();
  }

  Future<void> refresh({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(loading: true, error: '');
    }
    final today = DateTime.now();
    final todayIso = todayIsoDate();
    final semester = studentCheckInSemesterDates(today);

    var timeConfigs = kDefaultStudentTimeConfigs;
    String? classId;

    final classResp = await _studentRepository.mySchoolClass();
    if (classResp.isSuccess) {
      final map = classResp.data;
      if (map is Map) {
        final schoolClass = map['schoolClass'];
        if (schoolClass is Map) {
          classId =
              schoolClass['id']?.toString() ??
              schoolClass['classId']?.toString();
        }
      }
    }

    if (classId != null && classId.isNotEmpty) {
      final tcResp = await _schoolRepository.schoolTimeConfigList(
        classId: classId,
      );
      if (tcResp.isSuccess) {
        final parsed = parseStudentTimeConfigs(tcResp.data);
        if (parsed.isNotEmpty) timeConfigs = parsed;
      }
    }
    // 缓存节次时间表，定时刷新时不用重复拉。
    _timeConfigs = timeConfigs;

    final responses = await Future.wait([
      _studentRepository.courseList(beginDate: todayIso, endDate: todayIso),
      _studentRepository.courseSignStat(
        beginDate: semester.beginDate,
        endDate: semester.endDate,
      ),
      _studentRepository.courseSignRecentList(size: 6),
    ]);
    if (!mounted) return;

    final courseResp = responses[0];
    final statResp = responses[1];
    final recentResp = responses[2];

    final courses = courseResp.isSuccess
        ? parseStudentTodayCourses(
            raw: courseResp.data,
            timeConfigs: timeConfigs,
            now: today,
            todayIso: todayIso,
          )
        : state.todayCourses;

    state = state.copyWith(
      loading: false,
      todayCourses: courses,
      selectedCourseId:
          state.selectedCourseId ?? pickActiveStudentCourse(courses)?.courseId,
      todayTitle: formatChineseDateTitle(today),
      stats: statResp.isSuccess
          ? StudentCheckInStat.fromJson(statResp.data)
          : state.stats,
      recentRecords: recentResp.isSuccess
          ? parseStudentSignRecordList(recentResp.data)
          : state.recentRecords,
      error: courseResp.isSuccess ? '' : courseResp.displayMsg,
    );
  }

  void selectCourse(String courseId) {
    if (state.selectedCourseId == courseId) return;
    state = state.copyWith(selectedCourseId: courseId);
  }

  Future<void> loadHistory({
    required StudentCheckInHistoryRange range,
    int? status,
    String? date,
  }) async {
    if (state.loadingHistory) return;
    state = state.copyWith(loadingHistory: true, historyError: '');
    final trimmedDate = date?.trim() ?? '';
    final ({String beginDate, String endDate}) dates;
    if (trimmedDate.isNotEmpty) {
      dates = (beginDate: trimmedDate, endDate: trimmedDate);
    } else {
      dates = range.dates(DateTime.now());
    }
    final response = await _studentRepository.courseSignHistory(
      beginDate: dates.beginDate,
      endDate: dates.endDate,
      status: status,
      current: 1,
      size: 200,
    );
    if (!mounted) return;
    state = state.copyWith(
      loadingHistory: false,
      historyRecords: response.isSuccess
          ? parseStudentSignRecordList(response.data)
          : state.historyRecords,
      historyError: response.isSuccess ? '' : response.displayMsg,
    );
  }

  Future<ApiResponse> submitMakeup({
    required String courseId,
    required String reason,
  }) async {
    if (state.submitting) {
      return ApiResponse.failure('正在提交，请稍候');
    }
    state = state.copyWith(submitting: true);
    final response = await _studentRepository.courseSignMakeupSave(
      courseId: courseId,
      reason: reason,
    );
    if (response.isSuccess) {
      await refresh();
      await loadMakeupList();
    }
    if (mounted) state = state.copyWith(submitting: false);
    return response;
  }

  Future<void> loadMakeupList({int? status}) async {
    if (state.loadingMakeup) return;
    state = state.copyWith(loadingMakeup: true, makeupError: '');
    final response = await _studentRepository.courseSignMakeupList(
      status: status,
      current: 1,
      size: 200,
    );
    if (!mounted) return;
    state = state.copyWith(
      loadingMakeup: false,
      makeupRecords: response.isSuccess
          ? parseStudentCourseSignMakeupList(response.data)
          : state.makeupRecords,
      makeupError: response.isSuccess ? '' : response.displayMsg,
    );
  }

  Future<List<({String label, String value})>> loadMakeupDetail(
    String id,
  ) async {
    if (id.isEmpty) return const [];
    final response = await _studentRepository.courseSignMakeupDetail(id: id);
    if (!response.isSuccess) return const [];
    return parseStudentCourseSignMakeupDetailRows(response.data);
  }
}
