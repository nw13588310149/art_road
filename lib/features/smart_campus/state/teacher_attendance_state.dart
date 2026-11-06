import '../data/course_sign_data.dart';
import '../data/teacher_attendance_data.dart';

class TeacherAttendanceState {
  const TeacherAttendanceState({
    this.range = TeacherAttendanceRange.total,
    this.summary = const TeacherAttendanceSummary(),
    this.todayCourses = const [],
    this.selectedCourseId,
    this.recentRecords = const [],
    this.historyRecords = const [],
    this.loadingOverview = false,
    this.loadingHistory = false,
    this.loadingCourseIds = const {},
    this.submittingCourseIds = const {},
    this.error = '',
    this.historyError = '',
  });

  final TeacherAttendanceRange range;
  final TeacherAttendanceSummary summary;
  final List<CourseSignSession> todayCourses;
  final String? selectedCourseId;
  final List<TeacherSignHistoryItem> recentRecords;
  final List<TeacherSignHistoryItem> historyRecords;
  final bool loadingOverview;
  final bool loadingHistory;
  final Set<String> loadingCourseIds;
  final Set<String> submittingCourseIds;
  final String error;
  final String historyError;

  TeacherAttendanceState copyWith({
    TeacherAttendanceRange? range,
    TeacherAttendanceSummary? summary,
    List<CourseSignSession>? todayCourses,
    String? selectedCourseId,
    List<TeacherSignHistoryItem>? recentRecords,
    List<TeacherSignHistoryItem>? historyRecords,
    bool? loadingOverview,
    bool? loadingHistory,
    Set<String>? loadingCourseIds,
    Set<String>? submittingCourseIds,
    String? error,
    String? historyError,
  }) {
    return TeacherAttendanceState(
      range: range ?? this.range,
      summary: summary ?? this.summary,
      todayCourses: todayCourses ?? this.todayCourses,
      selectedCourseId: selectedCourseId ?? this.selectedCourseId,
      recentRecords: recentRecords ?? this.recentRecords,
      historyRecords: historyRecords ?? this.historyRecords,
      loadingOverview: loadingOverview ?? this.loadingOverview,
      loadingHistory: loadingHistory ?? this.loadingHistory,
      loadingCourseIds: loadingCourseIds ?? this.loadingCourseIds,
      submittingCourseIds: submittingCourseIds ?? this.submittingCourseIds,
      error: error ?? this.error,
      historyError: historyError ?? this.historyError,
    );
  }
}
