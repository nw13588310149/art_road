import 'package:flutter/foundation.dart';

import '../../../core/network/snowflake_id.dart';
import '../data/quiz_html.dart';
import 'quiz_practice_state.dart';

/// 三级页路由参数：从二级页携带的 practice 信息。
@immutable
class QuizSessionPageArgs {
  const QuizSessionPageArgs({
    required this.practiceType,
    this.practiceId,
    this.startIndex = 0,
    this.allCount = 0,
    this.schoolId = kPublicQuizSchoolId,
    this.openCompletionDialog = false,
  });

  final QuizPracticeType practiceType;
  final int? practiceId;
  final int startIndex;
  final int allCount;

  /// 首页刷题固定 `'0'`；校园课件刷题传真实 schoolId（String）。
  final String schoolId;

  /// 进入页面后立刻弹出完成弹窗（对应 1.0 的 camp_over 路由）。
  final bool openCompletionDialog;

  factory QuizSessionPageArgs.fromRaw(dynamic raw) {
    if (raw is QuizSessionPageArgs) return raw;
    if (raw is Map) {
      final type =
          quizPracticeTypeFromKey(raw['practiceType']?.toString()) ??
          QuizPracticeType.sequence;
      return QuizSessionPageArgs(
        practiceType: type,
        practiceId: _toInt(raw['practiceId']),
        startIndex: _toInt(raw['startIndex']) ?? 0,
        allCount: _toInt(raw['allCount']) ?? 0,
        schoolId:
            readSnowflakeId(raw['schoolId']) ?? kPublicQuizSchoolId,
        openCompletionDialog: raw['openCompletionDialog'] == true,
      );
    }
    return const QuizSessionPageArgs(practiceType: QuizPracticeType.sequence);
  }

  @override
  bool operator ==(Object other) {
    return other is QuizSessionPageArgs &&
        other.practiceType == practiceType &&
        other.practiceId == practiceId &&
        other.startIndex == startIndex &&
        other.allCount == allCount &&
        other.schoolId == schoolId &&
        other.openCompletionDialog == openCompletionDialog;
  }

  @override
  int get hashCode => Object.hash(
    practiceType,
    practiceId,
    startIndex,
    allCount,
    schoolId,
    openCompletionDialog,
  );

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

/// 单道题目数据。
///
/// 富文本字段（`*Html`）来自后端，渲染层用；对应的纯文本
/// （`*Stripped`）+ HTML 形态布尔（`*HasMedia` / `*HasInlineRich`）
/// 在构造时算一次，之后跨 build / 跨题切换都不再重新 strip，
/// 既省 CPU 也避免"字符串还没更新到新题"的中间帧。
@immutable
class QuizQuestion {
  QuizQuestion({
    required this.itemId,
    required this.questionHtml,
    required List<String> options,
    required this.correctAnswer,
    required this.parseHtml,
    required this.userAnswer,
    required this.status,
  }) : options = List<String>.unmodifiable(options),
       questionStripped = stripHtmlToText(questionHtml),
       parseStripped = stripHtmlToText(parseHtml),
       optionsStripped = List<String>.unmodifiable(
         options.map(stripHtmlToText),
       ),
       questionHasMedia = htmlHasMedia(questionHtml),
       questionHasInlineRich = htmlHasInlineRich(questionHtml),
       parseHasMedia = htmlHasMedia(parseHtml),
       parseHasInlineRich = htmlHasInlineRich(parseHtml),
       optionsHasMedia = List<bool>.unmodifiable(
         options.map(htmlHasMedia),
       ),
       optionsHasInlineRich = List<bool>.unmodifiable(
         options.map(htmlHasInlineRich),
       );

  /// 由后台 isolate 预计算字段后构造，主线程不再重复 strip HTML。
  factory QuizQuestion.fromPayload(Map<String, dynamic> payload) {
    final rawOptions = payload['options'];
    final options = rawOptions is List
        ? rawOptions.map((e) => e?.toString() ?? '').toList(growable: false)
        : const <String>[];
    final rawOptionsStripped = payload['optionsStripped'];
    final optionsStripped = rawOptionsStripped is List
        ? rawOptionsStripped
              .map((e) => e?.toString() ?? '')
              .toList(growable: false)
        : const <String>[];
    final rawOptionsHasMedia = payload['optionsHasMedia'];
    final optionsHasMedia = rawOptionsHasMedia is List
        ? rawOptionsHasMedia.map((e) => e == true).toList(growable: false)
        : List<bool>.filled(options.length, false, growable: false);
    final rawOptionsHasInlineRich = payload['optionsHasInlineRich'];
    final optionsHasInlineRich = rawOptionsHasInlineRich is List
        ? rawOptionsHasInlineRich
              .map((e) => e == true)
              .toList(growable: false)
        : List<bool>.filled(options.length, false, growable: false);

    return QuizQuestion._precomputed(
      itemId: payload['itemId'] as int,
      questionHtml: payload['questionHtml']?.toString() ?? '',
      options: options,
      correctAnswer: payload['correctAnswer'] as int? ?? 0,
      parseHtml: payload['parseHtml']?.toString() ?? '',
      userAnswer: payload['userAnswer'] as int?,
      status: payload['status'] as int? ?? 0,
      questionStripped: payload['questionStripped']?.toString() ?? '',
      parseStripped: payload['parseStripped']?.toString() ?? '',
      optionsStripped: optionsStripped,
      questionHasMedia: payload['questionHasMedia'] == true,
      questionHasInlineRich: payload['questionHasInlineRich'] == true,
      parseHasMedia: payload['parseHasMedia'] == true,
      parseHasInlineRich: payload['parseHasInlineRich'] == true,
      optionsHasMedia: optionsHasMedia,
      optionsHasInlineRich: optionsHasInlineRich,
    );
  }

  QuizQuestion._precomputed({
    required this.itemId,
    required this.questionHtml,
    required List<String> options,
    required this.correctAnswer,
    required this.parseHtml,
    required this.userAnswer,
    required this.status,
    required this.questionStripped,
    required this.parseStripped,
    required List<String> optionsStripped,
    required this.questionHasMedia,
    required this.questionHasInlineRich,
    required this.parseHasMedia,
    required this.parseHasInlineRich,
    required List<bool> optionsHasMedia,
    required List<bool> optionsHasInlineRich,
  }) : options = List<String>.unmodifiable(options),
       optionsStripped = List<String>.unmodifiable(optionsStripped),
       optionsHasMedia = List<bool>.unmodifiable(optionsHasMedia),
       optionsHasInlineRich = List<bool>.unmodifiable(optionsHasInlineRich);

  final int itemId;

  /// 题干 HTML。
  final String questionHtml;

  /// A/B/C/D 四个选项的 HTML。
  final List<String> options;

  /// 正确答案：0=A, 1=B, 2=C, 3=D。
  final int correctAnswer;
  final String parseHtml;

  /// 用户已选答案：0/1/2/3，未答时为 null。
  final int? userAnswer;

  /// 0=未做, 1=做对, 2=做错。
  final int status;

  // ── 预计算字段（构造时一次性求值，跨题切换永远是新对象）────────
  final String questionStripped;
  final String parseStripped;
  final List<String> optionsStripped;
  final bool questionHasMedia;
  final bool questionHasInlineRich;
  final bool parseHasMedia;
  final bool parseHasInlineRich;
  final List<bool> optionsHasMedia;
  final List<bool> optionsHasInlineRich;

  bool get answered => status != 0;

  QuizQuestion copyWith({int? userAnswer, int? status}) {
    return QuizQuestion._precomputed(
      itemId: itemId,
      questionHtml: questionHtml,
      options: options,
      correctAnswer: correctAnswer,
      parseHtml: parseHtml,
      userAnswer: userAnswer ?? this.userAnswer,
      status: status ?? this.status,
      questionStripped: questionStripped,
      parseStripped: parseStripped,
      optionsStripped: optionsStripped,
      questionHasMedia: questionHasMedia,
      questionHasInlineRich: questionHasInlineRich,
      parseHasMedia: parseHasMedia,
      parseHasInlineRich: parseHasInlineRich,
      optionsHasMedia: optionsHasMedia,
      optionsHasInlineRich: optionsHasInlineRich,
    );
  }
}

@immutable
class QuizSessionState {
  const QuizSessionState({
    required this.args,
    required this.loading,
    required this.questions,
    required this.currentIndex,
    required this.autoNext,
    required this.errorMessage,
    required this.summaryAfter,
    required this.completionDialogVisible,
  });

  final QuizSessionPageArgs args;
  final bool loading;
  final List<QuizQuestion> questions;
  final int currentIndex;

  /// 自动刷题：答完自动跳下一题。
  final bool autoNext;

  final String errorMessage;

  /// 完成时弹窗用的最新 summary（4 类全量），用于"切换到考前密卷/随机练习"。
  final List<QuizPracticeSummary> summaryAfter;

  final bool completionDialogVisible;

  QuizQuestion? get currentQuestion {
    if (questions.isEmpty) return null;
    final i = currentIndex.clamp(0, questions.length - 1);
    return questions[i];
  }

  int get answeredCount => questions.where((q) => q.status != 0).length;

  int get errorCount => questions.where((q) => q.status == 2).length;

  int get notDoneCount => questions.where((q) => q.status == 0).length;

  int get accuracyPercent {
    final done = answeredCount;
    if (done <= 0) return 0;
    return (((done - errorCount) / done) * 100).round();
  }

  QuizSessionState copyWith({
    QuizSessionPageArgs? args,
    bool? loading,
    List<QuizQuestion>? questions,
    int? currentIndex,
    bool? autoNext,
    String? errorMessage,
    bool clearErrorMessage = false,
    List<QuizPracticeSummary>? summaryAfter,
    bool? completionDialogVisible,
  }) {
    return QuizSessionState(
      args: args ?? this.args,
      loading: loading ?? this.loading,
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      autoNext: autoNext ?? this.autoNext,
      errorMessage: clearErrorMessage
          ? ''
          : (errorMessage ?? this.errorMessage),
      summaryAfter: summaryAfter ?? this.summaryAfter,
      completionDialogVisible:
          completionDialogVisible ?? this.completionDialogVisible,
    );
  }

  static QuizSessionState fromArgs(QuizSessionPageArgs args) =>
      QuizSessionState(
        args: args,
        loading: true,
        questions: const <QuizQuestion>[],
        currentIndex: args.startIndex,
        autoNext: false,
        errorMessage: '',
        summaryAfter: const <QuizPracticeSummary>[],
        completionDialogVisible: false,
      );
}
