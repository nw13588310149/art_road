import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/study_center_repository.dart';
import '../data/study_models.dart';
import 'study_center_args.dart';

/// 「我的学情」页内视图：总览 / 成绩报告 / 成长曲线。
enum StudentStudySection { overview, report, growth }

enum StudyExamFilter {
  all('ALL', '全部'),
  published('PUBLISHED', '已出分'),
  marking('MARKING', '阅卷中');

  const StudyExamFilter(this.code, this.label);

  final String code;
  final String label;
}

class StudentStudyState {
  const StudentStudyState({
    this.loading = true,
    this.loadFailed = false,
    this.errorMessage = '',
    this.overview,
    this.filter = StudyExamFilter.all,
    this.exams = const <StudyExamRecord>[],
    this.examsLoading = false,
    this.examsLoadingMore = false,
    this.examsFailed = false,
    this.examsPage = 0,
    this.examsTotal = 0,
    this.examsHasMore = false,
    this.section = StudentStudySection.overview,
    this.reportExamId = '',
    this.growthFromReport = false,
    this.pendingAction,
    this.pendingSubjectId = '',
  });

  final bool loading;
  final bool loadFailed;
  final String errorMessage;
  final StudyOverview? overview;

  final StudyExamFilter filter;
  final List<StudyExamRecord> exams;
  final bool examsLoading;
  final bool examsLoadingMore;
  final bool examsFailed;
  final int examsPage;
  final int examsTotal;
  final bool examsHasMore;

  final StudentStudySection section;
  final String reportExamId;

  /// 成长曲线从成绩报告进入时，返回回到报告。
  final bool growthFromReport;

  /// 路由直达：报告加载后自动打开原卷 / 评分标准（仅一次）。
  final StudyCenterInitialView? pendingAction;
  final String pendingSubjectId;

  StudentStudyState copyWith({
    bool? loading,
    bool? loadFailed,
    String? errorMessage,
    StudyOverview? overview,
    StudyExamFilter? filter,
    List<StudyExamRecord>? exams,
    bool? examsLoading,
    bool? examsLoadingMore,
    bool? examsFailed,
    int? examsPage,
    int? examsTotal,
    bool? examsHasMore,
    StudentStudySection? section,
    String? reportExamId,
    bool? growthFromReport,
    StudyCenterInitialView? pendingAction,
    String? pendingSubjectId,
    bool clearPendingAction = false,
  }) {
    return StudentStudyState(
      loading: loading ?? this.loading,
      loadFailed: loadFailed ?? this.loadFailed,
      errorMessage: errorMessage ?? this.errorMessage,
      overview: overview ?? this.overview,
      filter: filter ?? this.filter,
      exams: exams ?? this.exams,
      examsLoading: examsLoading ?? this.examsLoading,
      examsLoadingMore: examsLoadingMore ?? this.examsLoadingMore,
      examsFailed: examsFailed ?? this.examsFailed,
      examsPage: examsPage ?? this.examsPage,
      examsTotal: examsTotal ?? this.examsTotal,
      examsHasMore: examsHasMore ?? this.examsHasMore,
      section: section ?? this.section,
      reportExamId: reportExamId ?? this.reportExamId,
      growthFromReport: growthFromReport ?? this.growthFromReport,
      pendingAction: clearPendingAction
          ? null
          : (pendingAction ?? this.pendingAction),
      pendingSubjectId: clearPendingAction
          ? ''
          : (pendingSubjectId ?? this.pendingSubjectId),
    );
  }
}

final studentStudyControllerProvider = StateNotifierProvider.autoDispose
    .family<StudentStudyController, StudentStudyState, StudyCenterArgs>((
      ref,
      args,
    ) {
      final repository = ref.watch(studyCenterRepositoryProvider);
      return StudentStudyController(repository: repository, args: args);
    });

class StudentStudyController extends StateNotifier<StudentStudyState> {
  StudentStudyController({
    required StudyCenterRepository repository,
    required StudyCenterArgs args,
  }) : _repository = repository,
       _pendingArgs = args,
       super(_initialState(args)) {
    unawaited(refresh());
  }

  static const _pageSize = 10;

  final StudyCenterRepository _repository;

  /// 未指定 examId 的直达参数，等总览返回最近一场已出分考试后再落地。
  StudyCenterArgs? _pendingArgs;
  int _examsSerial = 0;

  static StudyCenterInitialView? _detailAction(StudyCenterArgs args) =>
      args.view == StudyCenterInitialView.paper ||
          args.view == StudyCenterInitialView.standard
      ? args.view
      : null;

  static StudentStudyState _initialState(StudyCenterArgs args) {
    if (args.view == StudyCenterInitialView.trend) {
      return const StudentStudyState(section: StudentStudySection.growth);
    }
    if (args.examId.isNotEmpty) {
      return StudentStudyState(
        section: StudentStudySection.report,
        reportExamId: args.examId,
        pendingAction: _detailAction(args),
        pendingSubjectId: args.subjectId,
      );
    }
    return const StudentStudyState();
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, loadFailed: false);
    final response = await _repository.overview();
    if (!mounted) return;
    if (!response.isSuccess) {
      state = state.copyWith(
        loading: false,
        loadFailed: state.overview == null,
        errorMessage: studyResponseMessage(response, '学情数据加载失败'),
      );
      return;
    }
    final overview = StudyOverview.fromJson(response.data);
    state = state.copyWith(loading: false, overview: overview);
    _applyPendingArgs(overview);
    await loadExams(reset: true);
  }

  void _applyPendingArgs(StudyOverview overview) {
    final args = _pendingArgs;
    _pendingArgs = null;
    if (args == null || args.examId.isNotEmpty) return;
    final view = args.view;
    final recentId = overview.recentStage?.exam.examId ?? '';
    if (recentId.isEmpty ||
        view == null ||
        view == StudyCenterInitialView.trend) {
      return;
    }
    state = state.copyWith(
      section: StudentStudySection.report,
      reportExamId: recentId,
      pendingAction: _detailAction(args),
      pendingSubjectId: args.subjectId,
    );
  }

  void consumePendingAction() {
    if (state.pendingAction == null) return;
    state = state.copyWith(clearPendingAction: true);
  }

  Future<void> loadExams({bool reset = false}) async {
    if (!reset &&
        (state.examsLoading || state.examsLoadingMore || !state.examsHasMore)) {
      return;
    }
    final serial = ++_examsSerial;
    final page = reset ? 1 : state.examsPage + 1;
    state = state.copyWith(
      examsLoading: reset,
      examsLoadingMore: !reset,
      examsFailed: false,
    );
    final response = await _repository.exams(
      status: state.filter.code,
      current: page,
      size: _pageSize,
    );
    if (!mounted || serial != _examsSerial) return;
    if (!response.isSuccess) {
      state = state.copyWith(
        examsLoading: false,
        examsLoadingMore: false,
        examsFailed: state.exams.isEmpty,
        errorMessage: studyResponseMessage(response, '考试记录加载失败'),
      );
      return;
    }
    final result = StudyPage<StudyExamRecord>.fromJson(
      response.data,
      StudyExamRecord.fromJson,
    );
    state = state.copyWith(
      examsLoading: false,
      examsLoadingMore: false,
      exams: reset ? result.records : [...state.exams, ...result.records],
      examsPage: page,
      examsTotal: result.total,
      examsHasMore: result.hasMore,
    );
  }

  void setFilter(StudyExamFilter filter) {
    if (filter == state.filter) return;
    state = state.copyWith(
      filter: filter,
      exams: const <StudyExamRecord>[],
      examsTotal: 0,
      examsHasMore: false,
    );
    unawaited(loadExams(reset: true));
  }

  void openReport(String examId) {
    if (examId.isEmpty) return;
    state = state.copyWith(
      section: StudentStudySection.report,
      reportExamId: examId,
      growthFromReport: false,
      clearPendingAction: true,
    );
  }

  void openGrowth() {
    state = state.copyWith(
      section: StudentStudySection.growth,
      growthFromReport: state.section == StudentStudySection.report,
    );
  }

  void back() {
    final toReport =
        state.section == StudentStudySection.growth &&
        state.growthFromReport &&
        state.reportExamId.isNotEmpty;
    state = state.copyWith(
      section: toReport
          ? StudentStudySection.report
          : StudentStudySection.overview,
      growthFromReport: false,
      clearPendingAction: true,
    );
  }

  void clearError() {
    state = state.copyWith(errorMessage: '');
  }
}
