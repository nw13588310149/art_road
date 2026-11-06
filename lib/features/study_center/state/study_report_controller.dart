import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/study_center_repository.dart';
import '../data/study_models.dart';

class StudyReportKey {
  const StudyReportKey({required this.examId, this.archiveId = ''});

  final String examId;

  /// 空串：学生本人（`/app/study`）；否则为教职查看的学生档案 id。
  final String archiveId;

  bool get isStaff => archiveId.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudyReportKey &&
          examId == other.examId &&
          archiveId == other.archiveId;

  @override
  int get hashCode => Object.hash(examId, archiveId);
}

class StudyReportState {
  const StudyReportState({
    this.loading = true,
    this.failed = false,
    this.errorMessage = '',
    this.report,
  });

  final bool loading;

  /// 首次加载失败（没有可展示的数据）。
  final bool failed;
  final String errorMessage;
  final StudyExamReport? report;

  StudyReportState copyWith({
    bool? loading,
    bool? failed,
    String? errorMessage,
    StudyExamReport? report,
  }) {
    return StudyReportState(
      loading: loading ?? this.loading,
      failed: failed ?? this.failed,
      errorMessage: errorMessage ?? this.errorMessage,
      report: report ?? this.report,
    );
  }
}

final studyReportControllerProvider = StateNotifierProvider.autoDispose
    .family<StudyReportController, StudyReportState, StudyReportKey>((
      ref,
      key,
    ) {
      final repository = ref.watch(studyCenterRepositoryProvider);
      return StudyReportController(repository: repository, reportKey: key);
    });

class StudyReportController extends StateNotifier<StudyReportState> {
  StudyReportController({
    required StudyCenterRepository repository,
    required StudyReportKey reportKey,
  }) : _repository = repository,
       _key = reportKey,
       super(const StudyReportState()) {
    unawaited(load());
  }

  final StudyCenterRepository _repository;
  final StudyReportKey _key;

  Future<void> load() async {
    state = state.copyWith(loading: true, failed: false, errorMessage: '');
    final response = _key.isStaff
        ? await _repository.studentReport(
            archiveId: _key.archiveId,
            examId: _key.examId,
          )
        : await _repository.examReport(_key.examId);
    if (!mounted) return;
    if (!response.isSuccess) {
      state = state.copyWith(
        loading: false,
        failed: state.report == null,
        errorMessage: studyResponseMessage(response, '成绩报告加载失败'),
      );
      return;
    }
    state = StudyReportState(
      loading: false,
      report: StudyExamReport.fromJson(response.data),
    );
  }

  void clearError() {
    state = state.copyWith(errorMessage: '');
  }
}
