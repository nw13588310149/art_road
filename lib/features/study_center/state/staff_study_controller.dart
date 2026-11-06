import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../data/study_center_repository.dart';
import '../data/study_models.dart';

/// 「班级学情」页内视图：班级总览 / 学生成绩报告 / 学生成绩曲线。
enum StaffStudySection { overview, report, trend }

class StaffStudyState {
  const StaffStudyState({
    this.loading = true,
    this.loadFailed = false,
    this.errorMessage = '',
    this.exams = const <TeacherExam>[],
    this.examId = '',
    this.subjectName = '',
    this.rowsLoading = false,
    this.rowsFailed = false,
    this.rows = const <ScoreQueryRow>[],
    this.rowsTotal = 0,
    this.gradeRules = const <String, GradeStandard>{},
    this.keyword = '',
    this.section = StaffStudySection.overview,
    this.student,
  });

  final bool loading;
  final bool loadFailed;
  final String errorMessage;

  /// 新 → 旧。
  final List<TeacherExam> exams;
  final String examId;

  /// 空串表示总分。
  final String subjectName;
  final bool rowsLoading;
  final bool rowsFailed;
  final List<ScoreQueryRow> rows;
  final int rowsTotal;

  /// 当前考试各科打分规则，按 subjectId 索引。
  final Map<String, GradeStandard> gradeRules;
  final String keyword;
  final StaffStudySection section;
  final ScoreQueryRow? student;

  TeacherExam? get exam {
    for (final item in exams) {
      if (item.examId == examId) return item;
    }
    return null;
  }

  TeacherExamSubject? get subject =>
      subjectName.isEmpty ? null : exam?.subjectNamed(subjectName);

  GradeStandard? get gradeRule {
    final current = subject;
    return current == null ? null : gradeRules[current.subjectId];
  }

  bool get hasPublishedExam => exams.any((item) => item.isPublished);

  StaffStudyState copyWith({
    bool? loading,
    bool? loadFailed,
    String? errorMessage,
    List<TeacherExam>? exams,
    String? examId,
    String? subjectName,
    bool? rowsLoading,
    bool? rowsFailed,
    List<ScoreQueryRow>? rows,
    int? rowsTotal,
    Map<String, GradeStandard>? gradeRules,
    String? keyword,
    StaffStudySection? section,
    ScoreQueryRow? student,
  }) {
    return StaffStudyState(
      loading: loading ?? this.loading,
      loadFailed: loadFailed ?? this.loadFailed,
      errorMessage: errorMessage ?? this.errorMessage,
      exams: exams ?? this.exams,
      examId: examId ?? this.examId,
      subjectName: subjectName ?? this.subjectName,
      rowsLoading: rowsLoading ?? this.rowsLoading,
      rowsFailed: rowsFailed ?? this.rowsFailed,
      rows: rows ?? this.rows,
      rowsTotal: rowsTotal ?? this.rowsTotal,
      gradeRules: gradeRules ?? this.gradeRules,
      keyword: keyword ?? this.keyword,
      section: section ?? this.section,
      student: student ?? this.student,
    );
  }
}

/// 参数为路由预选的 examId（可为空串）。
final staffStudyControllerProvider = StateNotifierProvider.autoDispose
    .family<StaffStudyController, StaffStudyState, String>((
      ref,
      initialExamId,
    ) {
      final repository = ref.watch(studyCenterRepositoryProvider);
      return StaffStudyController(
        repository: repository,
        initialExamId: initialExamId,
      );
    });

class StaffStudyController extends StateNotifier<StaffStudyState> {
  StaffStudyController({
    required StudyCenterRepository repository,
    required String initialExamId,
  }) : _repository = repository,
       _initialExamId = initialExamId,
       super(const StaffStudyState()) {
    unawaited(refresh());
  }

  /// 统计口径：单次最多取前 200 名。
  static const _rowLimit = 200;

  final StudyCenterRepository _repository;
  final String _initialExamId;
  int _rowsSerial = 0;

  Future<void> refresh() async {
    state = state.copyWith(loading: true, loadFailed: false);
    final response = await _repository.teacherExams();
    if (!mounted) return;
    if (!response.isSuccess) {
      state = state.copyWith(
        loading: false,
        loadFailed: state.exams.isEmpty,
        errorMessage: studyResponseMessage(response, '考试列表加载失败'),
      );
      return;
    }
    final raw = response.data;
    final exams = raw is List
        ? raw
              .map(TeacherExam.fromJson)
              .where((exam) => exam.examId.isNotEmpty)
              .toList()
        : StudyPage<TeacherExam>.fromJson(raw, TeacherExam.fromJson).records;
    exams.sort((a, b) => b.examTime.compareTo(a.examTime));
    bool selectable(String id) =>
        id.isNotEmpty && exams.any((e) => e.examId == id && e.isPublished);
    final selected = selectable(state.examId)
        ? state.examId
        : selectable(_initialExamId)
        ? _initialExamId
        : (exams.where((e) => e.isPublished).firstOrNull?.examId ?? '');
    state = state.copyWith(loading: false, exams: exams, examId: selected);
    if (selected.isNotEmpty) {
      await _loadExamData(selected);
    }
  }

  Future<void> selectExam(String examId) async {
    final exam = state.exams.where((e) => e.examId == examId).firstOrNull;
    if (exam == null || !exam.isPublished || examId == state.examId) return;
    final keepSubject =
        state.subjectName.isEmpty ||
        exam.subjectNamed(state.subjectName) != null;
    state = state.copyWith(
      examId: examId,
      subjectName: keepSubject ? state.subjectName : '',
      rows: const <ScoreQueryRow>[],
      rowsTotal: 0,
      gradeRules: const <String, GradeStandard>{},
    );
    await _loadExamData(examId);
  }

  Future<void> reloadRows() async {
    if (state.examId.isEmpty) return;
    await _loadExamData(state.examId);
  }

  Future<void> _loadExamData(String examId) async {
    final serial = ++_rowsSerial;
    state = state.copyWith(rowsLoading: true, rowsFailed: false);
    final subjects = state.exam?.subjects ?? const <TeacherExamSubject>[];
    final rulesFuture = Future.wait<ApiResponse>([
      for (final subject in subjects)
        _repository.gradeRule(examId: examId, subjectId: subject.subjectId),
    ]);
    final response = await _repository.scoreQuery(
      examId: examId,
      size: _rowLimit,
    );
    final rules = await rulesFuture;
    if (!mounted || serial != _rowsSerial) return;

    final gradeRules = <String, GradeStandard>{};
    for (var i = 0; i < subjects.length && i < rules.length; i++) {
      if (rules[i].isSuccess) {
        gradeRules[subjects[i].subjectId] = GradeStandard.fromJson(
          rules[i].data,
          subjectId: subjects[i].subjectId,
          subjectName: subjects[i].subjectName,
        );
      }
    }
    if (!response.isSuccess) {
      state = state.copyWith(
        rowsLoading: false,
        rowsFailed: state.rows.isEmpty,
        gradeRules: gradeRules,
        errorMessage: studyResponseMessage(response, '成绩数据加载失败'),
      );
      return;
    }
    final page = StudyPage<ScoreQueryRow>.fromJson(
      response.data,
      ScoreQueryRow.fromJson,
    );
    state = state.copyWith(
      rowsLoading: false,
      rowsFailed: false,
      rows: page.records,
      rowsTotal: page.total,
      gradeRules: gradeRules,
    );
  }

  void selectSubject(String subjectName) {
    if (subjectName == state.subjectName) return;
    state = state.copyWith(subjectName: subjectName);
  }

  void setKeyword(String keyword) {
    state = state.copyWith(keyword: keyword);
  }

  void openStudent(ScoreQueryRow row) {
    if (row.archiveId.isEmpty) return;
    state = state.copyWith(section: StaffStudySection.report, student: row);
  }

  void openTrend() {
    if (state.student == null) return;
    state = state.copyWith(section: StaffStudySection.trend);
  }

  void back() {
    state = state.copyWith(
      section: state.section == StaffStudySection.trend
          ? StaffStudySection.report
          : StaffStudySection.overview,
    );
  }

  void clearError() {
    state = state.copyWith(errorMessage: '');
  }
}
