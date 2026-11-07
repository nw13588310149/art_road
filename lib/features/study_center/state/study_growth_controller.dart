import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/study_center_repository.dart';
import '../data/study_logic.dart';
import '../data/study_models.dart';

class StudyGrowthState {
  const StudyGrowthState({
    this.loading = true,
    this.failed = false,
    this.errorMessage = '',
    this.subjectName = '',
    this.metric = GrowthMetric.score,
    this.result,
    this.resultSubjectName = '',
    this.resultMetric = GrowthMetric.score,
  });

  final bool loading;
  final bool failed;
  final String errorMessage;

  /// 当前选中的科目（空串表示总分）与指标。
  final String subjectName;
  final GrowthMetric metric;
  final GrowthResult? result;

  /// [result] 对应的科目与指标：切换后新数据返回前仍按旧口径渲染。
  final String resultSubjectName;
  final GrowthMetric resultMetric;

  StudyGrowthState copyWith({
    bool? loading,
    bool? failed,
    String? errorMessage,
    String? subjectName,
    GrowthMetric? metric,
    GrowthResult? result,
    String? resultSubjectName,
    GrowthMetric? resultMetric,
  }) {
    return StudyGrowthState(
      loading: loading ?? this.loading,
      failed: failed ?? this.failed,
      errorMessage: errorMessage ?? this.errorMessage,
      subjectName: subjectName ?? this.subjectName,
      metric: metric ?? this.metric,
      result: result ?? this.result,
      resultSubjectName: resultSubjectName ?? this.resultSubjectName,
      resultMetric: resultMetric ?? this.resultMetric,
    );
  }
}

/// 参数为学生档案 id：空串表示学生本人（`/app/study/growth`），
/// 否则为教职查看的学生（`/school/teacher/students/{id}/curve`）。
final studyGrowthControllerProvider = StateNotifierProvider.autoDispose
    .family<StudyGrowthController, StudyGrowthState, String>((ref, archiveId) {
      final repository = ref.watch(studyCenterRepositoryProvider);
      return StudyGrowthController(
        repository: repository,
        archiveId: archiveId,
      );
    });

class StudyGrowthController extends StateNotifier<StudyGrowthState> {
  StudyGrowthController({
    required StudyCenterRepository repository,
    required String archiveId,
  }) : _repository = repository,
       _archiveId = archiveId,
       super(const StudyGrowthState()) {
    unawaited(load());
  }

  static const _limit = 7;

  final StudyCenterRepository _repository;
  final String _archiveId;
  final Map<String, StudentCurve> _curves = <String, StudentCurve>{};
  int _serial = 0;

  Future<void> load() async {
    final serial = ++_serial;
    final subjectName = state.subjectName;
    final metric = state.metric;
    state = state.copyWith(loading: true, failed: false, errorMessage: '');

    GrowthResult? result;
    var error = '';
    if (_archiveId.isEmpty) {
      final response = await _repository.growth(
        subjectName: subjectName,
        metric: metric.code,
        limit: _limit,
      );
      if (response.isSuccess) {
        result = GrowthResult.fromJson(response.data);
      } else {
        error = studyResponseMessage(response, '成长曲线加载失败');
      }
    } else {
      var curve = _curves[subjectName];
      if (curve == null) {
        final response = await _repository.studentCurve(
          archiveId: _archiveId,
          subject: subjectName.isEmpty ? 'TOTAL' : subjectName,
        );
        if (response.isSuccess) {
          curve = StudentCurve.fromJson(response.data);
          _curves[subjectName] = curve;
        } else {
          error = studyResponseMessage(response, '成绩曲线加载失败');
        }
      }
      if (curve != null) {
        final full = growthFromCurve(curve, metric);
        final points = full.points.length > _limit
            ? full.points.sublist(full.points.length - _limit)
            : full.points;
        result = GrowthResult(
          tabs: full.tabs,
          points: points,
          statistics: growthStatisticsOf(points, metric),
        );
      }
    }

    if (!mounted || serial != _serial) return;
    if (result == null) {
      state = state.copyWith(
        loading: false,
        failed: state.result == null,
        errorMessage: error,
        subjectName: state.result == null ? null : state.resultSubjectName,
        metric: state.result == null ? null : state.resultMetric,
      );
      return;
    }
    state = state.copyWith(
      loading: false,
      failed: false,
      result: result,
      resultSubjectName: subjectName,
      resultMetric: metric,
    );
  }

  void selectSubject(String subjectName) {
    if (subjectName == state.subjectName) return;
    state = state.copyWith(subjectName: subjectName);
    unawaited(load());
  }

  void selectMetric(GrowthMetric metric) {
    if (metric == state.metric) return;
    state = state.copyWith(metric: metric);
    unawaited(load());
  }

  void clearError() {
    state = state.copyWith(errorMessage: '');
  }
}
