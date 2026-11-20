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
  int _listGeneration = 0;

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
      final id = row['id']?.toString() ?? row['classId']?.toString() ?? '';
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
    final generation = ++_listGeneration;
    if (!silent) {
      state = state.copyWith(loading: true, error: '');
    }
    final response = await _repository.examList(
      classId: classId,
      includeStat: true,
    );
    if (!mounted || generation != _listGeneration) return;
    if (!response.isSuccess) {
      state = state.copyWith(
        loading: false,
        loadingDetail: false,
        error: response.displayMsg,
        exams: const [],
        overviewStats: const TeacherExamOverviewStats(),
      );
      return;
    }

    final rows = parseTeacherExamListRows(response.data);
    final exams = rows.map(buildTeacherExamItemFromListRow).toList();
    final overviewStats = await _overviewStats(rows, classId);
    if (!mounted || generation != _listGeneration) return;

    state = state.copyWith(
      loading: false,
      exams: exams,
      loadingDetail: false,
      overviewStats: overviewStats,
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

  Future<TeacherExamOverviewStats> _overviewStats(
    List<Map<String, dynamic>> rows,
    String? classId,
  ) async {
    final stats = <TeacherExamOverviewStats>[];
    final missingStats = <TeacherExamItem>[];
    for (final row in rows) {
      final stat = row['stat'];
      if (stat is Map) {
        stats.add(TeacherExamOverviewStats.fromApi(stat));
      } else {
        missingStats.add(buildTeacherExamItemFromListRow(row));
      }
    }
    // 旧服务器未返回列表统计时，继续读取原有统计接口。
    await Future.wait([
      for (final exam in missingStats) _loadStatOnly(exam, classId, stats),
    ]);
    return TeacherExamOverviewStats.merge(stats);
  }

  Future<void> _loadStatOnly(
    TeacherExamItem exam,
    String? classId,
    List<TeacherExamOverviewStats> sink,
  ) async {
    if (exam.id.isEmpty || exam.subjectId == 0) return;
    final response = await _repository.examStudentStat(
      examId: exam.id,
      subjectId: exam.subjectId,
      classId: classId,
    );
    if (response.isSuccess) {
      sink.add(TeacherExamOverviewStats.fromApi(response.data));
    }
  }

  Future<void> selectClass(String label) async {
    if (!state.classIdByLabel.containsKey(label)) return;
    state = state.copyWith(classFilter: label, activeIdx: 0);
    await loadExamList(classId: state.classIdByLabel[label], silent: true);
  }

  void selectStatusTab(int index) {
    state = state.copyWith(statusTab: index, activeIdx: 0);
    final active = state.activeExam;
    if (active != null && !active.detailLoaded) {
      unawaited(loadExamDetail(active.id, active.subjectId, silent: true));
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
    final classId = _activeClassId;
    final generation = _listGeneration;
    final listResponse = await _repository.examStudentList(
      examId: examId,
      subjectId: subjectId,
      classId: classId,
    );
    if (!mounted || generation != _listGeneration) return;
    final statResponse = await _repository.examStudentStat(
      examId: examId,
      subjectId: subjectId,
      classId: classId,
    );
    if (!mounted || generation != _listGeneration) return;
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
    if (!mounted) return response;
    if (response.isSuccess) {
      final classId = _activeClassId;
      final generation = _listGeneration;
      await loadExamDetail(examId, subjectId, force: true);
      if (!mounted) return response;
      if (generation == _listGeneration) {
        final list = await _repository.examList(
          classId: classId,
          includeStat: true,
        );
        if (list.isSuccess && mounted && generation == _listGeneration) {
          final stats = await _overviewStats(
            parseTeacherExamListRows(list.data),
            classId,
          );
          if (mounted && generation == _listGeneration) {
            state = state.copyWith(overviewStats: stats);
          }
        }
      }
    }
    if (mounted) state = state.copyWith(submittingScore: false);
    return response;
  }

  Future<void> refreshActiveExam() async {
    final active = state.activeExam;
    if (active == null) return;
    await loadExamDetail(active.id, active.subjectId);
  }
}
