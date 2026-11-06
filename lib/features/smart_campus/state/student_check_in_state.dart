import 'package:flutter/foundation.dart';

import '../data/student_check_in_data.dart';

@immutable
class StudentCheckInState {
  const StudentCheckInState({
    this.loading = true,
    this.submitting = false,
    this.loadingDetailCourseId = '',
    this.loadingHistory = false,
    this.todayCourses = const <StudentTodayCourse>[],
    this.selectedCourseId,
    this.todayTitle = '',
    this.stats = const StudentCheckInStat(),
    this.recentRecords = const <StudentSignRecordItem>[],
    this.historyRecords = const <StudentSignRecordItem>[],
    this.makeupRecords = const <StudentCourseSignMakeupItem>[],
    this.error = '',
    this.historyError = '',
    this.makeupError = '',
    this.loadingMakeup = false,
  });

  final bool loading;
  final bool submitting;
  final String loadingDetailCourseId;
  final bool loadingHistory;
  final List<StudentTodayCourse> todayCourses;
  final String? selectedCourseId;
  final String todayTitle;
  final StudentCheckInStat stats;
  final List<StudentSignRecordItem> recentRecords;
  final List<StudentSignRecordItem> historyRecords;
  final List<StudentCourseSignMakeupItem> makeupRecords;
  final String error;
  final String historyError;
  final String makeupError;
  final bool loadingMakeup;

  StudentTodayCourse? get selectedCourse {
    final id = selectedCourseId;
    if (id == null) return null;
    for (final course in todayCourses) {
      if (course.courseId == id) return course;
    }
    return null;
  }

  StudentCheckInState copyWith({
    bool? loading,
    bool? submitting,
    String? loadingDetailCourseId,
    bool? loadingHistory,
    List<StudentTodayCourse>? todayCourses,
    String? selectedCourseId,
    String? todayTitle,
    StudentCheckInStat? stats,
    List<StudentSignRecordItem>? recentRecords,
    List<StudentSignRecordItem>? historyRecords,
    List<StudentCourseSignMakeupItem>? makeupRecords,
    String? error,
    String? historyError,
    String? makeupError,
    bool? loadingMakeup,
    bool clearSelectedCourseId = false,
  }) {
    return StudentCheckInState(
      loading: loading ?? this.loading,
      submitting: submitting ?? this.submitting,
      loadingDetailCourseId:
          loadingDetailCourseId ?? this.loadingDetailCourseId,
      loadingHistory: loadingHistory ?? this.loadingHistory,
      todayCourses: todayCourses ?? this.todayCourses,
      selectedCourseId: clearSelectedCourseId
          ? null
          : (selectedCourseId ?? this.selectedCourseId),
      todayTitle: todayTitle ?? this.todayTitle,
      stats: stats ?? this.stats,
      recentRecords: recentRecords ?? this.recentRecords,
      historyRecords: historyRecords ?? this.historyRecords,
      makeupRecords: makeupRecords ?? this.makeupRecords,
      error: error ?? this.error,
      historyError: historyError ?? this.historyError,
      makeupError: makeupError ?? this.makeupError,
      loadingMakeup: loadingMakeup ?? this.loadingMakeup,
    );
  }
}
