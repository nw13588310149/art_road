import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../data/teacher_exam_data.dart';
import '../data/teacher_repository.dart';
import 'teacher_exam_state.dart';

final teacherExamControllerProvider =
    StateNotifierProvider.autoDispose<TeacherExamController, TeacherExamState>((
      ref,
    ) {
      return TeacherExamController(
        repository: ref.watch(teacherRepositoryProvider),
      );
    });

class TeacherExamController extends StateNotifier<TeacherExamState> {
  TeacherExamController({required TeacherRepository repository})
    : _repository = repository,
      super(const TeacherExamState());

  final TeacherRepository _repository;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await loadClassOptions();
    await loadExamList(classId: _activeClassId);
  }

  String? get _activeClassId {
    final id = state.classIdByLabel[state.classFilter];
    if (id == null || id.isEmpty) return null;
    return id;
  }

  Future<void> loadClassOptions() async {
    final response = await _repository.classList(isClassTeacher: 1);
    if (!response.isSuccess) return;
    final labels = <String>[];
    final ids = <String, String>{};
    for (final row in parseTeacherExamListRows(response.data)) {
      final id =
          row['id']?.toString() ?? row['classId']?.toString() ?? '';
      final name = row['name']?.toString() ?? '';
      if (id.isEmpty || name.isEmpty || ids.containsKey(name)) continue;
      labels.add(name);
      ids[name] = id;
    }
    state = state.copyWith(
      classOptions: labels,
      classIdByLabel: ids,
      classFilter: labels.isEmpty ? '' : labels.first,
    );
  }

  Future<void> loadExamList({String? classId, bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(loading: true, error: '');
    }
    final response = await _repository.examList(classId: classId);
    if (!response.isSuccess) {
      state = state.copyWith(
        loading: false,
        error: response.displayMsg,
        exams: const [],
        overviewStats: const TeacherExamOverviewStats(),
      );
      return;
    }

    final exams = <TeacherExamItem>[];
    for (final row in parseTeacherExamListRows(response.data)) {
      exams.addAll(buildTeacherExamItemsFromListRow(row));
    }

    final stats = <TeacherExamOverviewStats>[];
    await Future.wait([
      for (final exam in exams) _loadStatOnly(exam, stats),
    ]);

    state = state.copyWith(
      loading: false,
      exams: exams,
      overviewStats: TeacherExamOverviewStats.merge(stats),
      activeIdx: 0,
      error: '',
    );

    final active = state.activeExam;
    if (active != null) {
      await loadExamDetail(
        active.id,
        active.subjectId,
        silent: silent,
        force: silent,
      );
    }
  }

  Future<void> _loadStatOnly(
    TeacherExamItem exam,
    List<TeacherExamOverviewStats> sink,
  ) async {
    if (exam.id.isEmpty || exam.subjectId == 0) return;
    final response = await _repository.examStudentStat(
      examId: exam.id,
      subjectId: exam.subjectId,
    );
    if (response.isSuccess) {
      sink.add(TeacherExamOverviewStats.fromApi(response.data));
    }
  }

  Future<void> selectClass(String label) async {
    if (!state.classIdByLabel.containsKey(label)) return;
    state = state.copyWith(classFilter: label, activeIdx: 0);
    await loadExamList(
      classId: state.classIdByLabel[label],
      silent: true,
    );
  }

  void selectStatusTab(int index) {
    state = state.copyWith(statusTab: index, activeIdx: 0);
    final active = state.activeExam;
    if (active != null && !active.detailLoaded) {
      unawaited(
        loadExamDetail(active.id, active.subjectId, silent: true),
      );
    }
  }

  Future<void> selectExam(int visibleIndex) async {
    final visible = state.visibleExams;
    if (visible.isEmpty) return;
    final idx = visibleIndex.clamp(0, visible.length - 1);
    final exam = visible[idx];
    state = state.copyWith(activeIdx: idx);
    await loadExamDetail(exam.id, exam.subjectId, force: true);
  }

  Future<void> loadExamDetail(
    String examId,
    int subjectId, {
    bool force = false,
    bool silent = false,
  }) async {
    if (examId.isEmpty || subjectId == 0) return;
    if (!silent && state.loadingDetail) return;
    final cached = state.exams.where(
      (item) => item.id == examId && item.subjectId == subjectId,
    );
    if (!force && cached.any((item) => item.detailLoaded)) return;
    if (!silent) {
      state = state.copyWith(loadingDetail: true);
    }
    final listResponse = await _repository.examStudentList(
      examId: examId,
      subjectId: subjectId,
    );
    final statResponse = await _repository.examStudentStat(
      examId: examId,
      subjectId: subjectId,
    );
    final subjectName = state.exams
        .firstWhere(
          (item) => item.id == examId && item.subjectId == subjectId,
          orElse: () => state.exams.firstWhere(
            (item) => item.id == examId,
            orElse: () => const TeacherExamItem(
              id: '',
              subjectId: 0,
              title: '',
              subject: '科目',
              examLabel: '',
              classLabel: '',
              deadline: '',
              syncNote: '',
              officialDesc: '',
              cornerLabel: '',
              cornerKind: TeacherExamCornerKind.unpublished,
              attended: 0,
              unsubmitted: 0,
              pendingReview: 0,
              reviewed: 0,
              submissions: [],
              publishedRatio: (submitted: 0, total: 0),
            ),
          ),
        )
        .subject;
    final submissions = listResponse.isSuccess
        ? parseTeacherExamSubmissionList(
            listResponse.data,
            subjectName: subjectName,
          )
        : const <TeacherExamSubmission>[];
    final metrics = statResponse.isSuccess
        ? TeacherExamDetailMetrics.fromApi(
            statResponse.data,
            submissions: submissions,
          )
        : TeacherExamDetailMetrics.fromApi(null, submissions: submissions);

    state = state.copyWith(
      loadingDetail: false,
      exams: [
        for (final exam in state.exams)
          if (exam.id == examId && exam.subjectId == subjectId)
            applyTeacherExamDetail(
              item: exam,
              submissions: submissions,
              metrics: metrics,
            )
          else
            exam,
      ],
    );
  }

  Future<ApiResponse> remindStudent({
    required String examId,
    required int subjectId,
    required String studentId,
  }) async {
    if (studentId.isEmpty || state.remindingStudentId == studentId) {
      return ApiResponse.failure('正在发送催交提醒');
    }
    state = state.copyWith(remindingStudentId: studentId);
    final response = await _repository.examStudentRemind(
      examId: examId,
      subjectId: subjectId,
      studentIds: [studentId],
    );
    state = state.copyWith(remindingStudentId: '');
    return response;
  }

  Future<ApiResponse> submitScore({
    required String examId,
    required int subjectId,
    required String studentId,
    required num score,
    required String comment,
    required String path,
  }) async {
    if (state.submittingScore) {
      return ApiResponse.failure('正在提交评分');
    }
    state = state.copyWith(submittingScore: true);
    final response = await _repository.examStudentScore(
      examId: examId,
      subjectId: subjectId,
      studentId: studentId,
      score: score,
      comment: comment,
      path: path,
    );
    if (response.isSuccess) {
      await loadExamDetail(examId, subjectId);
      final stats = <TeacherExamOverviewStats>[];
      await Future.wait([
        for (final exam in state.exams) _loadStatOnly(exam, stats),
      ]);
      state = state.copyWith(
        overviewStats: TeacherExamOverviewStats.merge(stats),
      );
    }
    state = state.copyWith(submittingScore: false);
    return response;
  }

  Future<void> refreshActiveExam() async {
    final active = state.activeExam;
    if (active == null) return;
    await loadExamDetail(active.id, active.subjectId);
  }
}
