import 'package:flutter/material.dart';

import '../../../core/ui/app_colors.dart';

/// 首页「题库」入口固定 schoolId；校园课件题库传真实 schoolId（String 避免 Web 大整数精度丢失）。
const kPublicQuizSchoolId = '0';

/// 1.0 中的 4 类练习：sequence/random/exam/error。
enum QuizPracticeType { sequence, random, exam, error }

extension QuizPracticeTypeX on QuizPracticeType {
  String get apiKey {
    switch (this) {
      case QuizPracticeType.sequence:
        return 'sequence';
      case QuizPracticeType.random:
        return 'random';
      case QuizPracticeType.exam:
        return 'exam';
      case QuizPracticeType.error:
        return 'error';
    }
  }

  String get label {
    switch (this) {
      case QuizPracticeType.sequence:
        return '顺序练习';
      case QuizPracticeType.random:
        return '随机练习';
      case QuizPracticeType.exam:
        return '高频考点';
      case QuizPracticeType.error:
        return '错题本';
    }
  }

  String get description {
    switch (this) {
      case QuizPracticeType.sequence:
        return '按题号依次作答，随时接着上次做';
      case QuizPracticeType.random:
        return '每轮随机抽题，做完自动换一组';
      case QuizPracticeType.exam:
        return '各分类常考知识点汇总';
      case QuizPracticeType.error:
        return '做错的题自动收进来，答对后移出';
    }
  }

  /// 进度环颜色：练习用品牌紫，错题本用红色。
  Color get accentColor => this == QuizPracticeType.error
      ? AppColors.danger
      : AppColors.brand;
}

QuizPracticeType? quizPracticeTypeFromKey(String? key) {
  switch (key) {
    case 'sequence':
      return QuizPracticeType.sequence;
    case 'random':
      return QuizPracticeType.random;
    case 'exam':
      return QuizPracticeType.exam;
    case 'error':
      return QuizPracticeType.error;
    default:
      return null;
  }
}

/// 单类练习的统计数据。
@immutable
class QuizPracticeSummary {
  const QuizPracticeSummary({
    required this.type,
    required this.practiceId,
    required this.allCount,
    required this.doneCount,
    required this.errorCount,
    required this.notDoneCount,
    required this.statusInitialized,
  });

  final QuizPracticeType type;
  final int? practiceId;
  final int allCount;
  final int doneCount;
  final int errorCount;
  final int notDoneCount;

  /// 1.0 用 status==null 判断是否需要 questionPracticeCreate 初始化。
  final bool statusInitialized;

  double get progress {
    if (allCount <= 0) return 0;
    return (doneCount / allCount).clamp(0.0, 1.0);
  }

  int get progressPercent => (progress * 100).round();

  /// 当前轮次已全部做完（随机练习完成后需重新 create 生成新题库）。
  bool get isRoundCompleted => allCount > 0 && doneCount >= allCount;

  double get accuracy {
    if (doneCount <= 0) return 0;
    return ((doneCount - errorCount) / doneCount).clamp(0.0, 1.0);
  }

  int get accuracyPercent => (accuracy * 100).round();

  QuizPracticeSummary copyWith({
    int? practiceId,
    int? allCount,
    int? doneCount,
    int? errorCount,
    int? notDoneCount,
    bool? statusInitialized,
  }) {
    return QuizPracticeSummary(
      type: type,
      practiceId: practiceId ?? this.practiceId,
      allCount: allCount ?? this.allCount,
      doneCount: doneCount ?? this.doneCount,
      errorCount: errorCount ?? this.errorCount,
      notDoneCount: notDoneCount ?? this.notDoneCount,
      statusInitialized: statusInitialized ?? this.statusInitialized,
    );
  }

  static QuizPracticeSummary empty(QuizPracticeType type) =>
      QuizPracticeSummary(
        type: type,
        practiceId: null,
        allCount: 0,
        doneCount: 0,
        errorCount: 0,
        notDoneCount: 0,
        statusInitialized: false,
      );
}

@immutable
class QuizPracticeState {
  const QuizPracticeState({
    required this.loading,
    required this.summaries,
    required this.errorMessage,
  });

  final bool loading;
  final List<QuizPracticeSummary> summaries;
  final String errorMessage;

  QuizPracticeSummary? summaryOf(QuizPracticeType type) {
    for (final s in summaries) {
      if (s.type == type) return s;
    }
    return null;
  }

  QuizPracticeState copyWith({
    bool? loading,
    List<QuizPracticeSummary>? summaries,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return QuizPracticeState(
      loading: loading ?? this.loading,
      summaries: summaries ?? this.summaries,
      errorMessage: clearErrorMessage
          ? ''
          : (errorMessage ?? this.errorMessage),
    );
  }

  static const QuizPracticeState initial = QuizPracticeState(
    loading: true,
    summaries: <QuizPracticeSummary>[],
    errorMessage: '',
  );
}
