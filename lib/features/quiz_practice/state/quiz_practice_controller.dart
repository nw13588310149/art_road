import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/quiz_practice_repository.dart';
import '../data/quiz_question_parser.dart';
import 'quiz_practice_state.dart';
import 'quiz_session_state.dart';

final quizPracticeControllerProvider = StateNotifierProvider.autoDispose
    .family<QuizPracticeController, QuizPracticeState, String>((ref, schoolId) {
      final repo = ref.watch(quizPracticeRepositoryProvider);
      return QuizPracticeController(repository: repo, schoolId: schoolId);
    });

class QuizPracticeController extends StateNotifier<QuizPracticeState> {
  QuizPracticeController({
    required QuizPracticeRepository repository,
    required String schoolId,
  }) : _repository = repository,
       _schoolId = schoolId,
       super(QuizPracticeState.initial) {
    unawaited(refresh());
  }

  final QuizPracticeRepository _repository;
  final String _schoolId;

  String get schoolId => _schoolId;

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearErrorMessage: true);
    final response = await _repository.getSummary(schoolId: _schoolId);
    if (!mounted) return;
    if (!response.isSuccess) {
      state = state.copyWith(
        loading: false,
        summaries: _fallbackSummaries(),
        errorMessage: response.msg.isEmpty ? '加载刷题数据失败' : response.msg,
      );
      return;
    }

    final summaries = _parseSummaries(response.data);
    state = state.copyWith(loading: false, summaries: summaries);

    unawaited(compute(warmupQuizQuestionParser, null));

    // 1.0 行为：status==null 的练习立刻调用 create 初始化（只针对 sequence/random/exam）。
    final missing = summaries
        .where((s) => !s.statusInitialized && s.type != QuizPracticeType.error)
        .toList(growable: false);
    // 1.0 行为：随机练习做完一轮后重新 create 生成新题库。
    final randomDone = summaries
        .where((s) => s.type == QuizPracticeType.random && s.isRoundCompleted)
        .toList(growable: false);
    final toCreate = <QuizPracticeType>{
      ...missing.map((s) => s.type),
      ...randomDone.map((s) => s.type),
    };
    if (toCreate.isEmpty) return;
    await Future.wait(
      toCreate.map(_initializePractice),
      eagerError: false,
    );
  }

  /// 进入做题页前确保 summary 可用；随机练习已做完则先生成新题库。
  Future<QuizSessionPageArgs?> buildSessionArgs(QuizPracticeSummary summary) async {
    var fresh = summary;
    if (summary.type == QuizPracticeType.random && summary.isRoundCompleted) {
      final response = await _repository.createPractice(
        schoolId: _schoolId,
        practiceType: summary.type.apiKey,
      );
      if (!mounted) return null;
      if (!response.isSuccess) {
        state = state.copyWith(
          errorMessage: response.msg.isEmpty ? '生成新题库失败' : response.msg,
        );
        return null;
      }
      final updated = _parseSinglePractice(summary.type, response.data);
      if (updated == null) return null;
      final next = state.summaries
          .map((s) => s.type == summary.type ? updated : s)
          .toList(growable: false);
      state = state.copyWith(summaries: next, clearErrorMessage: true);
      fresh = updated;
    }

    if (fresh.allCount <= 0) return null;
    return QuizSessionPageArgs(
      practiceType: fresh.type,
      practiceId: fresh.practiceId,
      startIndex: fresh.doneCount,
      allCount: fresh.allCount,
      schoolId: _schoolId,
    );
  }

  Future<void> _initializePractice(QuizPracticeType type) async {
    final response = await _repository.createPractice(
      schoolId: _schoolId,
      practiceType: type.apiKey,
    );
    if (!mounted || !response.isSuccess) return;
    final updated = _parseSinglePractice(type, response.data);
    if (updated == null) return;

    final next = state.summaries
        .map((s) => s.type == type ? updated : s)
        .toList(growable: false);
    state = state.copyWith(summaries: next);
  }

  List<QuizPracticeSummary> _parseSummaries(dynamic data) {
    if (data is! Map) return _fallbackSummaries();

    QuizPracticeSummary parse(QuizPracticeType t) {
      final raw = data[t.apiKey];
      if (raw is! Map) return QuizPracticeSummary.empty(t);
      return QuizPracticeSummary(
        type: t,
        practiceId: _toInt(raw['practiceId']),
        allCount: _toInt(raw['allCount']) ?? 0,
        doneCount: _toInt(raw['doneCount']) ?? 0,
        errorCount: _toInt(raw['errorCount']) ?? 0,
        notDoneCount: _toInt(raw['notDoneCount']) ?? 0,
        statusInitialized: raw['status'] != null,
      );
    }

    return <QuizPracticeSummary>[
      parse(QuizPracticeType.sequence),
      parse(QuizPracticeType.random),
      parse(QuizPracticeType.exam),
      parse(QuizPracticeType.error),
    ];
  }

  QuizPracticeSummary? _parseSinglePractice(
    QuizPracticeType type,
    dynamic data,
  ) {
    if (data is! Map) return null;
    return QuizPracticeSummary(
      type: type,
      practiceId: _toInt(data['practiceId']),
      allCount: _toInt(data['allCount']) ?? 0,
      doneCount: _toInt(data['doneCount']) ?? 0,
      errorCount: _toInt(data['errorCount']) ?? 0,
      notDoneCount: _toInt(data['notDoneCount']) ?? 0,
      statusInitialized: true,
    );
  }

  List<QuizPracticeSummary> _fallbackSummaries() => <QuizPracticeSummary>[
    QuizPracticeSummary.empty(QuizPracticeType.sequence),
    QuizPracticeSummary.empty(QuizPracticeType.random),
    QuizPracticeSummary.empty(QuizPracticeType.exam),
    QuizPracticeSummary.empty(QuizPracticeType.error),
  ];

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
