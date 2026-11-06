import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../../school/data/school_repository.dart';
import '../../shell/state/shell_controller.dart';
import '../data/course_sign_data.dart';
import '../data/teacher_attendance_data.dart';
import '../data/teacher_repository.dart';
import 'teacher_attendance_state.dart';

final teacherAttendanceControllerProvider =
    StateNotifierProvider.autoDispose<
      TeacherAttendanceController,
      TeacherAttendanceState
    >((ref) {
      final controller = TeacherAttendanceController(
        repository: ref.watch(teacherRepositoryProvider),
        schoolRepository: ref.watch(schoolRepositoryProvider),
        currentTeacherId: ref.watch(shellControllerProvider).user.id,
      );
      ref.onDispose(controller.stopLiveSync);
      return controller;
    });

class TeacherAttendanceController
    extends StateNotifier<TeacherAttendanceState> {
  TeacherAttendanceController({
    required TeacherRepository repository,
    required SchoolRepository schoolRepository,
    required String currentTeacherId,
  }) : _repository = repository,
       _schoolRepository = schoolRepository,
       _currentTeacherId = currentTeacherId,
       super(const TeacherAttendanceState());

  final TeacherRepository _repository;
  final SchoolRepository _schoolRepository;
  final String _currentTeacherId;
  bool _initialized = false;
  Timer? _liveSyncTimer;
  bool _liveSyncActive = false;

  static const _liveSyncInterval = Duration(seconds: 5);

  void startLiveSync() {
    if (_liveSyncActive) return;
    _liveSyncActive = true;
    _liveSyncTimer?.cancel();
    _liveSyncTimer = Timer.periodic(_liveSyncInterval, (_) {
      unawaited(pollActiveCourseDetail());
    });
  }

  void stopLiveSync() {
    _liveSyncActive = false;
    _liveSyncTimer?.cancel();
    _liveSyncTimer = null;
  }

  Future<void> resumeSync() async {
    await pollActiveCourseDetail(force: true);
  }

  Future<void> pollActiveCourseDetail({bool force = false}) async {
    if (!_liveSyncActive && !force) return;
    if (state.loadingOverview) return;
    final courseId = state.selectedCourseId;
    if (courseId == null || courseId.isEmpty) return;
    if (state.submittingCourseIds.contains(courseId)) return;
    final course = _courseById(courseId);
    if (!_shouldKeepLiveSync(course)) return;
    await loadCourseDetail(courseId, silent: true);
  }

  bool _shouldKeepLiveSync(CourseSignSession? course) {
    if (course == null) return true;
    if (course.signStatus >= CourseSignFlowStatus.studentEval.code) {
      return false;
    }
    return true;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _loadOverview();
  }

  Future<void> refresh() => _loadOverview();

  Future<void> selectRange(TeacherAttendanceRange range) async {
    if (state.range == range && !state.loadingOverview) return;
    state = state.copyWith(range: range);
    await _loadSummary();
  }

  Future<void> _loadOverview() async {
    state = state.copyWith(loadingOverview: true, error: '');
    final today = todayIsoDate();
    final dates = state.range.dates(DateTime.now());
    final timeConfigsFuture = _loadTimeConfigs();
    final responses = await Future.wait([
      _repository.courseList(beginDate: today, endDate: today),
      _repository.courseAttendanceStat(
        beginDate: dates.beginDate,
        endDate: dates.endDate,
      ),
      _repository.courseTeacherSignHistory(current: 1, size: 3),
    ]);
    final courseResponse = responses[0];
    final summaryResponse = responses[1];
    final recentResponse = responses[2];
    final timeConfigs = await timeConfigsFuture;
    final errors = [
      if (!courseResponse.isSuccess) courseResponse.displayMsg,
      if (!summaryResponse.isSuccess) summaryResponse.displayMsg,
      if (!recentResponse.isSuccess) recentResponse.displayMsg,
    ].where((item) => item.isNotEmpty).toList();
    final parsedCourses = courseResponse.isSuccess
        ? parseCourseSignSessionList(courseResponse.data)
        : state.todayCourses;
    final courses = sortCourseSignSessions(
      enrichCourseSignSessions(parsedCourses, timeConfigs: timeConfigs),
    );
    final selectedId =
        state.selectedCourseId ??
        pickDefaultCourseSignSessionId(courses, timeConfigs: timeConfigs);
    state = state.copyWith(
      loadingOverview: false,
      todayCourses: courses,
      selectedCourseId: selectedId,
      summary: summaryResponse.isSuccess
          ? TeacherAttendanceSummary.fromJson(summaryResponse.data)
          : state.summary,
      recentRecords: recentResponse.isSuccess
          ? _filterSignHistory(parseTeacherSignHistoryList(recentResponse.data))
          : state.recentRecords,
      error: errors.join('；'),
    );
    if (selectedId != null && selectedId.isNotEmpty) {
      await loadCourseDetail(selectedId);
    }
  }

  Future<List<CourseLineTimeConfig>> _loadTimeConfigs() async {
    var configs = kDefaultCourseLineTimeConfigs;
    final classResp = await _repository.classList(isClassTeacher: 1);
    if (!classResp.isSuccess) return configs;

    final classes = parseCourseSignClassList(classResp.data);
    final classId = classes.isNotEmpty ? classes.first.id : null;
    if (classId == null || classId.isEmpty) return configs;

    final tcResp = await _schoolRepository.schoolTimeConfigList(classId: classId);
    if (!tcResp.isSuccess) return configs;

    final parsed = parseCourseLineTimeConfigs(tcResp.data);
    return parsed.isNotEmpty ? parsed : configs;
  }

  Future<void> selectCourse(String courseId) async {
    if (courseId.isEmpty) return;
    state = state.copyWith(selectedCourseId: courseId);
    await loadCourseDetail(courseId);
  }

  Future<void> _loadSummary({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(loadingOverview: true, error: '');
    }
    final dates = state.range.dates(DateTime.now());
    final response = await _repository.courseAttendanceStat(
      beginDate: dates.beginDate,
      endDate: dates.endDate,
    );
    state = state.copyWith(
      loadingOverview: false,
      summary: response.isSuccess
          ? TeacherAttendanceSummary.fromJson(response.data)
          : state.summary,
      error: response.isSuccess ? '' : response.displayMsg,
    );
  }

  Future<void> loadHistory() async {
    if (state.loadingHistory) return;
    state = state.copyWith(loadingHistory: true, historyError: '');
    final response = await _repository.courseTeacherSignHistory(
      current: 1,
      size: 200,
    );
    state = state.copyWith(
      loadingHistory: false,
      historyRecords: response.isSuccess
          ? _filterSignHistory(parseTeacherSignHistoryList(response.data))
          : state.historyRecords,
      historyError: response.isSuccess ? '' : response.displayMsg,
    );
  }

  Future<void> loadCourseDetail(String courseId, {bool silent = false}) async {
    if (courseId.isEmpty) return;
    if (state.loadingCourseIds.contains(courseId)) return;
    if (!silent) {
      state = state.copyWith(
        loadingCourseIds: {...state.loadingCourseIds, courseId},
      );
    }
    final response = await _repository.courseClassSignDetail(
      courseId: courseId,
    );
    if (response.isSuccess) {
      final detail = TeacherClassSignDetail.fromJson(response.data);
      state = state.copyWith(
        todayCourses: [
          for (final course in state.todayCourses)
            if (course.courseId == courseId)
              course.copyWith(
                students: detail.students,
                signStep: detail.courseSignStatus,
                signStatus: detail.courseSignStatus,
                teacherCheckInTime: detail.teacherSignInTime,
                teacherCheckOutTime: detail.teacherSignOutTime,
                colorHex: detail.colorHex.isNotEmpty
                    ? detail.colorHex
                    : course.colorHex,
                className: detail.className.isNotEmpty
                    ? detail.className
                    : course.className,
                logoUrl: detail.logoUrl.isNotEmpty
                    ? detail.logoUrl
                    : course.logoUrl,
              )
            else
              course,
        ],
      );
    }
    if (!silent) {
      state = state.copyWith(
        loadingCourseIds: {...state.loadingCourseIds}..remove(courseId),
      );
    }
  }

  Future<ApiResponse> updateStudentStatus({
    required String courseId,
    required String studentId,
    required CourseSignStatus status,
  }) async {
    final course = _courseById(courseId);
    if (course == null) return ApiResponse.failure('当前课程不存在');
    final student = course.students
        .where((item) => item.studentId == studentId)
        .firstOrNull;
    if (student == null || student.studentId.isEmpty) {
      return ApiResponse.failure('学生 ID 无效');
    }
    final response = await _repository.courseClassStudentSignUpdate(
      courseId: courseId,
      studentId: studentId,
      signStatus: status.code,
      remark: student.remark,
    );
    if (response.isSuccess) {
      _replaceStudent(
        courseId,
        studentId,
        student.copyWith(status: status),
      );
      await _loadSummary();
    }
    return response;
  }

  Future<ApiResponse> teacherSignIn(String courseId) async {
    if (state.submittingCourseIds.contains(courseId)) {
      return ApiResponse.failure('正在提交签到，请稍候');
    }
    final course = _courseById(courseId);
    if (course == null || course.courseId.isEmpty) {
      return ApiResponse.failure('当前课程缺少课表记录');
    }
    if (course.signStatus >= CourseSignFlowStatus.teacherStart.code) {
      return ApiResponse.failure('已完成上课签到');
    }
    state = state.copyWith(
      submittingCourseIds: {...state.submittingCourseIds, courseId},
    );
    final response = await _repository.courseTeacherSignIn(courseId: courseId);
    if (response.isSuccess) {
      await loadCourseDetail(courseId, silent: true);
      await _loadSummary(silent: true);
      await _loadRecent();
    }
    state = state.copyWith(
      submittingCourseIds: {...state.submittingCourseIds}..remove(courseId),
    );
    return response;
  }

  Future<ApiResponse> teacherSignOut(String courseId) async {
    if (state.submittingCourseIds.contains(courseId)) {
      return ApiResponse.failure('正在提交签到，请稍候');
    }
    final course = _courseById(courseId);
    if (course == null || course.courseId.isEmpty) {
      return ApiResponse.failure('当前课程缺少课表记录');
    }
    if (course.signStatus < CourseSignFlowStatus.studentStart.code) {
      return ApiResponse.failure('请等待学生完成上课签到');
    }
    if (course.signStatus >= CourseSignFlowStatus.teacherEnd.code) {
      return ApiResponse.failure('已完成下课签到');
    }
    state = state.copyWith(
      submittingCourseIds: {...state.submittingCourseIds, courseId},
    );
    final response = await _repository.courseTeacherSignOut(courseId: courseId);
    if (response.isSuccess) {
      await loadCourseDetail(courseId, silent: true);
      await _loadSummary(silent: true);
      await _loadRecent();
    }
    state = state.copyWith(
      submittingCourseIds: {...state.submittingCourseIds}..remove(courseId),
    );
    return response;
  }

  Future<ApiResponse> bulkSign(String courseId) async {
    if (state.submittingCourseIds.contains(courseId)) {
      return ApiResponse.failure('正在提交签到，请稍候');
    }
    final course = _courseById(courseId);
    if (course == null || course.courseId.isEmpty) {
      return ApiResponse.failure('当前课程缺少课表记录');
    }
    if (course.students.isEmpty) {
      return ApiResponse.failure('当前课程暂无学生名单');
    }
    if (isBigClassBulkSignCompleted(
      courseSignStatus: course.signStatus,
      students: course.students,
    )) {
      return ApiResponse.failure('该课程已完成签到');
    }
    state = state.copyWith(
      submittingCourseIds: {...state.submittingCourseIds, courseId},
    );
    final response = await _repository.courseClassSignAll(
      courseId: courseId,
      students: [
        for (final student in course.students)
          <String, dynamic>{
            'studentId': student.studentId,
            'signStatus': (student.status ?? CourseSignStatus.present).code,
            if (student.remark.isNotEmpty) 'remark': student.remark,
          },
      ],
    );
    if (response.isSuccess) {
      await loadCourseDetail(courseId);
      await _loadSummary();
      await _loadRecent();
    }
    state = state.copyWith(
      submittingCourseIds: {...state.submittingCourseIds}..remove(courseId),
    );
    return response;
  }

  Future<void> _loadRecent() async {
    final response = await _repository.courseTeacherSignHistory(
      current: 1,
      size: 3,
    );
    if (!response.isSuccess) return;
    state = state.copyWith(
      recentRecords: _filterSignHistory(
        parseTeacherSignHistoryList(response.data),
      ),
    );
  }

  List<TeacherSignHistoryItem> _filterSignHistory(
    List<TeacherSignHistoryItem> records,
  ) {
    return filterTeacherTaughtSignHistory(
      records,
      currentTeacherId: _currentTeacherId,
    );
  }

  CourseSignSession? _courseById(String courseId) {
    return state.todayCourses
        .where((course) => course.courseId == courseId)
        .firstOrNull;
  }

  void _replaceStudent(
    String courseId,
    String studentId,
    CourseSignStudent replacement,
  ) {
    state = state.copyWith(
      todayCourses: [
        for (final course in state.todayCourses)
          if (course.courseId == courseId)
            course.copyWith(
              students: [
                for (final student in course.students)
                  if (student.studentId == studentId) replacement else student,
              ],
            )
          else
            course,
      ],
    );
  }

}
