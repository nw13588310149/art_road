import '../data/head_teacher_index_data.dart';
import '../data/teacher_dormitory_data.dart';

class TeacherDormitoryState {
  const TeacherDormitoryState({
    this.classes = const [],
    this.selectedClassId = '',
    this.selectedDate = '',
    this.overview = const TeacherDormitoryOverview(),
    this.stat = const TeacherDormitoryStat(),
    this.dynamicItems = const [],
    this.historyItems = const [],
    this.makeupItems = const [],
    this.submittingMakeupIds = const {},
    this.loading = false,
    this.loadingHistory = false,
    this.error = '',
  });

  final List<HeadTeacherClassItem> classes;
  final String selectedClassId;
  final String selectedDate;
  final TeacherDormitoryOverview overview;
  final TeacherDormitoryStat stat;
  final List<TeacherDormitoryDynamicItem> dynamicItems;
  final List<TeacherDormitoryHistoryItem> historyItems;
  final List<TeacherDormitoryMakeupItem> makeupItems;
  final Set<String> submittingMakeupIds;
  final bool loading;
  final bool loadingHistory;
  final String error;

  TeacherDormitoryState copyWith({
    List<HeadTeacherClassItem>? classes,
    String? selectedClassId,
    String? selectedDate,
    TeacherDormitoryOverview? overview,
    TeacherDormitoryStat? stat,
    List<TeacherDormitoryDynamicItem>? dynamicItems,
    List<TeacherDormitoryHistoryItem>? historyItems,
    List<TeacherDormitoryMakeupItem>? makeupItems,
    Set<String>? submittingMakeupIds,
    bool? loading,
    bool? loadingHistory,
    String? error,
  }) {
    return TeacherDormitoryState(
      classes: classes ?? this.classes,
      selectedClassId: selectedClassId ?? this.selectedClassId,
      selectedDate: selectedDate ?? this.selectedDate,
      overview: overview ?? this.overview,
      stat: stat ?? this.stat,
      dynamicItems: dynamicItems ?? this.dynamicItems,
      historyItems: historyItems ?? this.historyItems,
      makeupItems: makeupItems ?? this.makeupItems,
      submittingMakeupIds: submittingMakeupIds ?? this.submittingMakeupIds,
      loading: loading ?? this.loading,
      loadingHistory: loadingHistory ?? this.loadingHistory,
      error: error ?? this.error,
    );
  }
}
