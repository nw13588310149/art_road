import '../data/teacher_exam_data.dart';

class TeacherExamState {
  const TeacherExamState({
    this.loading = true,
    this.loadingDetail = false,
    this.remindingStudentId = '',
    this.submittingScore = false,
    this.statusTab = 0,
    this.activeIdx = 0,
    this.classFilter = '',
    this.classOptions = const [],
    this.classIdByLabel = const {},
    this.exams = const [],
    this.overviewStats = const TeacherExamOverviewStats(),
    this.error = '',
  });

  final bool loading;
  final bool loadingDetail;
  final String remindingStudentId;
  final bool submittingScore;
  final int statusTab;
  final int activeIdx;
  final String classFilter;
  final List<String> classOptions;
  final Map<String, String> classIdByLabel;
  final List<TeacherExamItem> exams;
  final TeacherExamOverviewStats overviewStats;
  final String error;

  TeacherExamItem? get activeExam {
    final visible = visibleExams;
    if (visible.isEmpty) return null;
    final idx = activeIdx.clamp(0, visible.length - 1);
    return visible[idx];
  }

  List<TeacherExamItem> get visibleExams {
    return switch (statusTab) {
      1 => exams
          .where((item) => item.cornerKind == TeacherExamCornerKind.unpublished)
          .toList(growable: false),
      2 => exams
          .where((item) => item.cornerKind == TeacherExamCornerKind.published)
          .toList(growable: false),
      _ => exams,
    };
  }

  TeacherExamState copyWith({
    bool? loading,
    bool? loadingDetail,
    String? remindingStudentId,
    bool? submittingScore,
    int? statusTab,
    int? activeIdx,
    String? classFilter,
    List<String>? classOptions,
    Map<String, String>? classIdByLabel,
    List<TeacherExamItem>? exams,
    TeacherExamOverviewStats? overviewStats,
    String? error,
  }) {
    return TeacherExamState(
      loading: loading ?? this.loading,
      loadingDetail: loadingDetail ?? this.loadingDetail,
      remindingStudentId: remindingStudentId ?? this.remindingStudentId,
      submittingScore: submittingScore ?? this.submittingScore,
      statusTab: statusTab ?? this.statusTab,
      activeIdx: activeIdx ?? this.activeIdx,
      classFilter: classFilter ?? this.classFilter,
      classOptions: classOptions ?? this.classOptions,
      classIdByLabel: classIdByLabel ?? this.classIdByLabel,
      exams: exams ?? this.exams,
      overviewStats: overviewStats ?? this.overviewStats,
      error: error ?? this.error,
    );
  }
}
