import '../data/student_dormitory_data.dart';

enum StudentDormitoryListSection { checkRecords, makeupApplications }

class StudentDormitoryState {
  const StudentDormitoryState({
    this.loading = false,
    this.submittingMakeup = false,
    this.cancellingMakeupId = '',
    this.error = '',
    this.listSection = StudentDormitoryListSection.checkRecords,
    this.dormInfo = const StudentDormitoryInfo(),
    this.stat = StudentDormitoryStat.zero,
    this.records = const [],
    this.makeupItems = const [],
    this.pendingMakeupCount = 0,
  });

  final bool loading;
  final bool submittingMakeup;
  final String cancellingMakeupId;
  final String error;
  final StudentDormitoryListSection listSection;
  final StudentDormitoryInfo dormInfo;
  final StudentDormitoryStat stat;
  final List<StudentDormitoryCheckItem> records;
  final List<StudentDormitoryMakeupItem> makeupItems;
  final int pendingMakeupCount;

  StudentDormitoryState copyWith({
    bool? loading,
    bool? submittingMakeup,
    String? cancellingMakeupId,
    String? error,
    StudentDormitoryListSection? listSection,
    StudentDormitoryInfo? dormInfo,
    StudentDormitoryStat? stat,
    List<StudentDormitoryCheckItem>? records,
    List<StudentDormitoryMakeupItem>? makeupItems,
    int? pendingMakeupCount,
  }) {
    return StudentDormitoryState(
      loading: loading ?? this.loading,
      submittingMakeup: submittingMakeup ?? this.submittingMakeup,
      cancellingMakeupId: cancellingMakeupId ?? this.cancellingMakeupId,
      error: error ?? this.error,
      listSection: listSection ?? this.listSection,
      dormInfo: dormInfo ?? this.dormInfo,
      stat: stat ?? this.stat,
      records: records ?? this.records,
      makeupItems: makeupItems ?? this.makeupItems,
      pendingMakeupCount: pendingMakeupCount ?? this.pendingMakeupCount,
    );
  }
}
