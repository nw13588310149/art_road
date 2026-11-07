import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/ui/ui.dart';
import '../data/quiz_html.dart';
import '../state/quiz_practice_state.dart';
import '../state/quiz_session_controller.dart';
import '../state/quiz_session_state.dart';

class QuizSessionPage extends ConsumerStatefulWidget {
  const QuizSessionPage({super.key, this.openCompletion = false});

  /// 来自 /camp_over 路由：进入即弹完成对话框。
  final bool openCompletion;

  @override
  ConsumerState<QuizSessionPage> createState() => _QuizSessionPageState();
}

class _QuizSessionPageState extends ConsumerState<QuizSessionPage> {
  QuizSessionPageArgs? _args;
  bool _dialogShowing = false;

  QuizSessionPageArgs _resolveArgs(BuildContext context) {
    if (_args != null) return _args!;
    final raw = ModalRoute.of(context)?.settings.arguments;
    final parsed = QuizSessionPageArgs.fromRaw(raw);
    _args = widget.openCompletion
        ? QuizSessionPageArgs(
            practiceType: parsed.practiceType,
            practiceId: parsed.practiceId,
            startIndex: parsed.startIndex,
            allCount: parsed.allCount,
            schoolId: parsed.schoolId,
            openCompletionDialog: true,
          )
        : parsed;
    return _args!;
  }

  @override
  Widget build(BuildContext context) {
    final args = _resolveArgs(context);
    final provider = quizSessionControllerProvider(args);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen<QuizSessionState>(provider, (previous, next) {
      final msg = next.errorMessage;
      if (msg.isNotEmpty && msg != previous?.errorMessage) {
        AppToast.show(context, msg);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) controller.clearError();
        });
      }

      if (next.completionDialogVisible && !_dialogShowing) {
        _dialogShowing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showCompletionDialog(context, controller);
        });
      }
    });

    final total = state.questions.length;
    final Widget body;
    if (state.loading) {
      body = const Center(child: AppLoadingIndicator());
    } else if (total == 0) {
      body = const AppEmptyState(
        icon: Icons.quiz_outlined,
        title: '这组练习还没有题目',
        description: '返回题库换一种练习方式试试',
      );
    } else {
      body = _SessionBody(
        state: state,
        onSelect: controller.selectAnswer,
        onPrevious: controller.previousQuestion,
        onNext: controller.nextQuestion,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(
          title: state.args.practiceType.label,
          subtitle: total == 0
              ? null
              : '第 ${state.currentIndex + 1} / $total 题 · 已做 ${state.answeredCount} 题',
          onBack: controller.openExitDialog,
          actions: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('自动下一题', style: AppText.body14),
                const SizedBox(width: AppSpace.s8),
                AppSwitch(
                  value: state.autoNext,
                  onChanged: controller.setAutoNext,
                  semanticLabel: '答完自动进入下一题',
                ),
              ],
            ),
          ],
        ),
        Expanded(child: body),
      ],
    );
  }

  Future<void> _showCompletionDialog(
    BuildContext context,
    QuizSessionController controller,
  ) async {
    if (!mounted) return;
    await showAppDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          _CompletionDialog(controller: controller, providerArgs: _args!),
    );
    _dialogShowing = false;
    if (mounted) controller.closeCompletionDialog();
  }
}

// ─────────────────────────────────────────────────────────────────────
// 主体：题型 / 题干 / 选项 / 解析 / 上下一题按钮
// ─────────────────────────────────────────────────────────────────────

class _SessionBody extends StatefulWidget {
  const _SessionBody({
    required this.state,
    required this.onSelect,
    required this.onPrevious,
    required this.onNext,
  });

  final QuizSessionState state;
  final ValueChanged<int> onSelect;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  State<_SessionBody> createState() => _SessionBodyState();
}

class _SessionBodyState extends State<_SessionBody> {
  final ScrollController _scrollController = ScrollController();
  int? _lastQuestionId;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 题目切换时把滚动条复位到顶部，否则新题仍停在上一题滚到的位置。
  void _maybeResetScrollOnQuestionChange(int? newQuestionId) {
    if (newQuestionId == _lastQuestionId) return;
    _lastQuestionId = newQuestionId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.state.currentQuestion;
    _maybeResetScrollOnQuestionChange(question?.itemId);

    if (question == null) {
      return const AppEmptyState(
        icon: Icons.quiz_outlined,
        title: '这组练习还没有题目',
      );
    }
    final isLast =
        widget.state.currentIndex >= widget.state.questions.length - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.page,
        0,
        AppSpace.page,
        AppSpace.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AppCard(
              padding: EdgeInsets.zero,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.all(AppSpace.s24),
                // ValueKey(itemId)：题目一变整棵子树重建，HtmlWidget / 图片
                // 等带内部状态的组件不会把上一题的内容留到这一题。
                child: _QuestionContent(
                  key: ValueKey<int>(question.itemId),
                  question: question,
                  questionNumber: widget.state.currentIndex + 1,
                  onSelect: widget.onSelect,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppButton(
                label: '上一题',
                variant: AppButtonVariant.secondary,
                enabled: widget.state.currentIndex > 0,
                onTap: widget.onPrevious,
              ),
              const SizedBox(width: AppSpace.s12),
              AppButton(
                label: isLast ? '完成练习' : '下一题',
                onTap: widget.onNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 题目主体（题型 + 题干 + 选项 + 解析），本身不持有状态，
/// 切题时由外层的 `ValueKey(question.itemId)` 触发整棵子树重建。
class _QuestionContent extends StatelessWidget {
  const _QuestionContent({
    super.key,
    required this.question,
    required this.questionNumber,
    required this.onSelect,
  });

  final QuizQuestion question;
  final int questionNumber;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final stemStyle = AppText.body16.copyWith(
      color: AppColors.ink,
      fontWeight: AppFont.w500,
      height: 1.6,
    );
    final parseStyle = AppText.body14.copyWith(
      color: AppColors.textSecondary,
      height: 1.7,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const AppTag(label: '单选题'),
            const SizedBox(width: AppSpace.s8),
            Text('第 $questionNumber 题', style: AppText.caption12),
          ],
        ),
        const SizedBox(height: AppSpace.s12),
        _QuizHtml(
          html: question.questionHtml,
          fallbackText: question.questionStripped,
          hasMedia: question.questionHasMedia,
          hasInlineRich: question.questionHasInlineRich,
          textStyle: stemStyle,
        ),
        const SizedBox(height: AppSpace.s20),
        _OptionsGrid(question: question, onSelect: onSelect),
        if (question.answered) ...[
          const SizedBox(height: AppSpace.s24),
          const Divider(height: 1, thickness: 1, color: AppColors.lineSoft),
          const SizedBox(height: AppSpace.s16),
          _AnswerRow(question: question),
          const SizedBox(height: AppSpace.s16),
          Text('题目解析', style: AppText.title16),
          const SizedBox(height: AppSpace.s8),
          if (question.parseStripped.isEmpty &&
              !question.parseHasMedia &&
              !question.parseHasInlineRich)
            Text('这道题暂未提供解析', style: parseStyle)
          else
            _QuizHtml(
              html: question.parseHtml,
              fallbackText: question.parseStripped,
              hasMedia: question.parseHasMedia,
              hasInlineRich: question.parseHasInlineRich,
              textStyle: parseStyle,
            ),
        ],
      ],
    );
  }
}

class _OptionsGrid extends StatelessWidget {
  const _OptionsGrid({required this.question, required this.onSelect});

  final QuizQuestion question;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget row(int first) => IntrinsicHeight(
      // stretch 让同一行两个选项等高（一边文字、一边图片时也一样）。
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Option(question: question, index: first, onSelect: onSelect),
          ),
          const SizedBox(width: AppSpace.s16),
          Expanded(
            child: _Option(
              question: question,
              index: first + 1,
              onSelect: onSelect,
            ),
          ),
        ],
      ),
    );
    return Column(
      children: [row(0), const SizedBox(height: AppSpace.s12), row(2)],
    );
  }
}

/// 单个选项（A/B/C/D）。key 带 itemId + index，切题时整块重建，
/// 不会复用上一题选项里的 HtmlWidget / 图片。
class _Option extends StatelessWidget {
  _Option({
    required this.question,
    required this.index,
    required this.onSelect,
  }) : super(key: ValueKey<String>('opt-${question.itemId}-$index'));

  final QuizQuestion question;
  final int index;
  final ValueChanged<int> onSelect;

  static const _letters = <String>['A', 'B', 'C', 'D'];

  @override
  Widget build(BuildContext context) {
    final letter = _letters[index];
    final rawHtml = index < question.options.length
        ? question.options[index]
        : '';
    final stripped = index < question.optionsStripped.length
        ? question.optionsStripped[index]
        : '';
    final hasMedia = index < question.optionsHasMedia.length
        ? question.optionsHasMedia[index]
        : false;
    final hasInlineRich = index < question.optionsHasInlineRich.length
        ? question.optionsHasInlineRich[index]
        : false;

    final answered = question.answered;
    final isCorrectOption = index == question.correctAnswer;
    final isUserPick = index == question.userAnswer;
    final showCorrect = answered && isCorrectOption;
    final showWrong = answered && isUserPick && !isCorrectOption;

    var background = AppColors.surfaceSubtle;
    var textColor = AppColors.ink;
    IconData? mark;
    if (showCorrect) {
      background = AppColors.successSoft;
      textColor = AppColors.success;
      mark = Icons.check_rounded;
    } else if (showWrong) {
      background = AppColors.dangerSoft;
      textColor = AppColors.danger;
      mark = Icons.close_rounded;
    }

    return AppPressable(
      onTap: answered ? null : () => onSelect(index),
      semanticLabel: '选项 $letter',
      checked: isUserPick,
      child: Container(
        // 最小 48，纯图片选项可以撑高。
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s16,
          vertical: AppSpace.s8,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadius.br8,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$letter.',
                style: AppText.body16.copyWith(
                  color: textColor,
                  fontWeight: AppFont.w600,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            Expanded(
              child: _QuizHtml(
                html: rawHtml,
                fallbackText: stripped,
                hasMedia: hasMedia,
                hasInlineRich: hasInlineRich,
                textStyle: AppText.body16.copyWith(color: textColor),
              ),
            ),
            if (mark != null) ...[
              const SizedBox(width: AppSpace.s8),
              Icon(mark, color: textColor, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({required this.question});

  final QuizQuestion question;

  @override
  Widget build(BuildContext context) {
    const letters = ['A', 'B', 'C', 'D'];
    final correctLetter = letters[question.correctAnswer.clamp(0, 3)];
    final pickIndex = question.userAnswer ?? -1;
    final pickLetter = (pickIndex >= 0 && pickIndex < 4)
        ? letters[pickIndex]
        : '-';
    final pickColor = question.status == 1
        ? AppColors.success
        : AppColors.danger;
    final labelStyle = AppText.body14.copyWith(color: AppColors.textSecondary);
    final valueStyle = AppText.body14Strong;

    return Row(
      children: [
        Text('正确答案：', style: labelStyle),
        Text(
          correctLetter,
          style: valueStyle.copyWith(color: AppColors.success),
        ),
        const SizedBox(width: AppSpace.s32),
        Text('你的答案：', style: labelStyle),
        Text(pickLetter, style: valueStyle.copyWith(color: pickColor)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 完成 / 退出弹窗
// ─────────────────────────────────────────────────────────────────────

class _CompletionDialog extends ConsumerWidget {
  const _CompletionDialog({
    required this.controller,
    required this.providerArgs,
  });

  final QuizSessionController controller;
  final QuizSessionPageArgs providerArgs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quizSessionControllerProvider(providerArgs));

    final summary = _summaryOf(state, providerArgs.practiceType);
    final notDone = summary?.notDoneCount ?? state.notDoneCount;
    final done = summary?.doneCount ?? state.answeredCount;
    final wrong = summary?.errorCount ?? state.errorCount;
    final accuracyPercent = summary?.accuracyPercent ?? state.accuracyPercent;

    final isExam = providerArgs.practiceType == QuizPracticeType.exam;
    final recommended = isExam
        ? QuizPracticeType.random
        : QuizPracticeType.exam;
    final showRecommended =
        providerArgs.practiceType != recommended &&
        providerArgs.practiceType != QuizPracticeType.error;

    return AppDialog(
      title: notDone == 0 ? '本轮练习完成' : '还有 $notDone 题未做',
      message: notDone == 0 ? '做错的题已收进错题本，可以随时回来复习。' : '进度已保存，下次会从未做的题继续。',
      actions: [
        AppButton(
          label: '退出练习',
          variant: AppButtonVariant.secondary,
          onTap: () {
            final navigator = Navigator.of(context);
            navigator.pop();
            navigator.pop(true);
          },
        ),
        AppButton(
          label: '继续练习',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AppStatTile(
                  label: '未做',
                  value: '$notDone',
                  boxed: true,
                ),
              ),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: AppStatTile(label: '已做', value: '$done', boxed: true),
              ),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: AppStatTile(label: '错题', value: '$wrong', boxed: true),
              ),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: AppStatTile(
                  label: '正确率',
                  value: done > 0 ? '$accuracyPercent' : '--',
                  unit: done > 0 ? '%' : null,
                  boxed: true,
                ),
              ),
            ],
          ),
          if (showRecommended) ...[
            const SizedBox(height: AppSpace.s16),
            AppCard(
              bordered: true,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s16,
                vertical: AppSpace.s12,
              ),
              onTap: () async {
                final next = await controller.switchToRecommended();
                if (!context.mounted) return;
                if (next == null) {
                  AppToast.showInfo(context, '暂无可切换的练习');
                  return;
                }
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.pushReplacementNamed(
                  RoutePaths.campAnswer,
                  arguments: next,
                );
              },
              child: Row(
                children: [
                  const Icon(
                    Icons.swap_horiz_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '换一种练习：${recommended.label}',
                          style: AppText.body14Strong,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          recommended.description,
                          style: AppText.caption12,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  QuizPracticeSummary? _summaryOf(
    QuizSessionState state,
    QuizPracticeType type,
  ) {
    for (final s in state.summaryAfter) {
      if (s.type == type) return s;
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────
// 富文本渲染：题干 / 选项 / 解析共用一套
// ─────────────────────────────────────────────────────────────────────
//
// 工具函数 stripHtmlToText / htmlHasMedia / htmlHasInlineRich 抽到
// `data/quiz_html.dart`，并在 QuizQuestion 构造时算一次，UI 层只
// 消费现成的 fallbackText / hasMedia / hasInlineRich 三个字段。

/// 题干、选项、解析的富文本渲染入口。
///
/// 后端字段是富文本编辑器吐出来的 HTML，常见结构有 `<p>`、`<br>`、
/// `<strong>`、`<em>`、`<sub>`、`<sup>`、`<img>`、`<div>` 等。这
/// 里按内容形态分发到三条最合适的渲染管线：
///
/// 1. **纯文本**（无 `<img>`/无 inline rich）→ `Text(fallbackText)`。
///    最便宜，绕开 HtmlWidget 对 `<p>` 块级 margin 带来的"看似
///    空白"问题。
/// 2. **图文混排**（只有 `<img>`，可能搭配文字）→ 自定义 inline
///    span 解析 → `Text.rich`，让"`[图]文字`"在同一行流动。
///    `HtmlWidget.customWidgetBuilder` 永远把返回的 widget 渲染
///    成块级，会把图片独占一行，所以这种情况必须自己解析。
/// 3. **真正的富文本**（含 `<sup>`/`<sub>`/`<strong>` 或 `<table>`/
///    `<svg>`/`<iframe>` 等复杂结构）→ `HtmlWidget`，并用
///    `customWidgetBuilder` 接管 `<img>` 渲染成响应式图片。
///
/// 题目切换时的"残留"问题统一由 `_SessionBody` 那边给本 widget
/// 的祖先 `_QuestionContent` 加的 `ValueKey(itemId)` 兜底——
/// itemId 一变整个子树 unmount，HtmlWidget 内部的 DOM 缓存 /
/// Image 的 ImageStream 都不会被复用。
class _QuizHtml extends StatelessWidget {
  const _QuizHtml({
    required this.html,
    required this.fallbackText,
    required this.hasMedia,
    required this.hasInlineRich,
    required this.textStyle,
  });

  /// 后端原始 HTML 字符串。
  final String html;

  /// 预 strip 出来的纯文本，HTML 走非 rich 分支 / 空判定时用。
  final String fallbackText;

  /// 是否含图片 / 表格 / 视频 / iframe 等媒体（构造 QuizQuestion
  /// 时就算好的）。
  final bool hasMedia;

  /// 是否含 inline 富文本（`<sup>`/`<sub>`/`<strong>`/`<br>` 等）。
  final bool hasInlineRich;

  /// 普通文本样式（颜色 / 字号 / 字体）。
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final trimmed = html.trim();
    if (trimmed.isEmpty) {
      return Text(fallbackText, style: textStyle);
    }

    // ① 纯文本快路径。
    if (!hasMedia && !hasInlineRich) {
      return Text(fallbackText, style: textStyle);
    }

    // ② 含 inline rich 或非 img 的复杂 media（table/svg/...）→
    //    走 HtmlWidget，customWidgetBuilder 接管 img。
    if (hasInlineRich || _hasNonImgMedia(trimmed)) {
      return _buildHtmlWidget(trimmed);
    }

    // ③ 只有 <img> + 文字 → 自定义 inline span 解析，让图文同行。
    final spans = _parseInlineSpans(trimmed, textStyle);
    if (spans.isEmpty) {
      return Text(fallbackText, style: textStyle);
    }
    return Text.rich(TextSpan(children: spans), style: textStyle);
  }

  Widget _buildHtmlWidget(String trimmed) {
    return HtmlWidget(
      trimmed,
      textStyle: textStyle,
      // 关闭默认 ext renderer，自己接管 <img>，避免 _core 包对
      // img 的占位 / 默认行为。
      customWidgetBuilder: (element) {
        if (element.localName != 'img') {
          return null;
        }
        final src = element.attributes['src']?.trim() ?? '';
        if (src.isEmpty) {
          return null;
        }
        final designW = double.tryParse(element.attributes['width'] ?? '');
        final designH = double.tryParse(element.attributes['height'] ?? '');
        return _ResponsiveNetworkImage(
          url: src,
          designWidth: designW,
          designHeight: designH,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// inline span 解析：把"<p><img/>文字</p>"这种简单图文混排 HTML
// 拆成 `List<InlineSpan>`，喂给 `Text.rich` 实现真正的图文同行。
//
// 不试图覆盖所有 HTML（那是 HtmlWidget 的事），只接管"纯文本 +
// `<p>` / `<div>` / `<br>` / `<img>`"这套最常见的形态——后端的
// 题目 / 选项 / 解析里 90%+ 都是这种结构。
// ─────────────────────────────────────────────────────────────────────

final RegExp _inlineImgRegExp = RegExp(
  r'<img\b[^>]*?/?>',
  caseSensitive: false,
);
final RegExp _inlineBrRegExp = RegExp(r'<br\s*/?>', caseSensitive: false);
final RegExp _inlineBlockEndRegExp = RegExp(
  r'</(p|div|li|tr|h[1-6])>',
  caseSensitive: false,
);
final RegExp _inlineBlockStartRegExp = RegExp(
  r'<(p|div|li|tr|h[1-6])\b[^>]*>',
  caseSensitive: false,
);
final RegExp _nonImgMediaRegExp = RegExp(
  r'<(svg|video|audio|iframe|table)\b',
  caseSensitive: false,
);
final RegExp _imgAttrSrcRegExp = RegExp(
  r'''src\s*=\s*(['"])(.*?)\1''',
  caseSensitive: false,
);
final RegExp _imgAttrWidthRegExp = RegExp(
  r'''width\s*=\s*(['"])([^'"]*)\1''',
  caseSensitive: false,
);
final RegExp _imgAttrHeightRegExp = RegExp(
  r'''height\s*=\s*(['"])([^'"]*)\1''',
  caseSensitive: false,
);

bool _hasNonImgMedia(String html) {
  return _nonImgMediaRegExp.hasMatch(html);
}

enum _InlineTokenKind { img, br, blockEnd, blockStart }

class _InlineToken {
  const _InlineToken(this.kind, this.start, this.end, this.match);
  final _InlineTokenKind kind;
  final int start;
  final int end;
  final String match;
}

List<InlineSpan> _parseInlineSpans(String html, TextStyle textStyle) {
  final tokens = <_InlineToken>[];
  for (final m in _inlineImgRegExp.allMatches(html)) {
    tokens.add(_InlineToken(_InlineTokenKind.img, m.start, m.end, m.group(0)!));
  }
  for (final m in _inlineBrRegExp.allMatches(html)) {
    tokens.add(_InlineToken(_InlineTokenKind.br, m.start, m.end, m.group(0)!));
  }
  for (final m in _inlineBlockEndRegExp.allMatches(html)) {
    tokens.add(
      _InlineToken(_InlineTokenKind.blockEnd, m.start, m.end, m.group(0)!),
    );
  }
  for (final m in _inlineBlockStartRegExp.allMatches(html)) {
    tokens.add(
      _InlineToken(_InlineTokenKind.blockStart, m.start, m.end, m.group(0)!),
    );
  }
  tokens.sort((a, b) => a.start.compareTo(b.start));

  final spans = <InlineSpan>[];
  final pendingText = StringBuffer();

  void flushText() {
    if (pendingText.isEmpty) return;
    final decoded = decodeHtmlEntities(pendingText.toString());
    pendingText.clear();
    if (decoded.isEmpty) return;
    spans.add(TextSpan(text: decoded, style: textStyle));
  }

  void appendNewline() {
    flushText();
    if (spans.isEmpty) return;
    final last = spans.last;
    if (last is TextSpan && (last.text ?? '').endsWith('\n')) return;
    spans.add(const TextSpan(text: '\n'));
  }

  var cursor = 0;
  for (final tok in tokens) {
    if (tok.start < cursor) continue; // 罕见的标签区间重叠，跳过
    if (tok.start > cursor) {
      pendingText.write(html.substring(cursor, tok.start));
    }
    cursor = tok.end;

    switch (tok.kind) {
      case _InlineTokenKind.img:
        flushText();
        final src = _imgAttrSrcRegExp.firstMatch(tok.match)?.group(2)?.trim();
        if (src != null && src.isNotEmpty) {
          final w = double.tryParse(
            _imgAttrWidthRegExp.firstMatch(tok.match)?.group(2) ?? '',
          );
          final h = double.tryParse(
            _imgAttrHeightRegExp.firstMatch(tok.match)?.group(2) ?? '',
          );
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: _InlineNetworkImage(
                url: src,
                designWidth: w,
                designHeight: h,
              ),
            ),
          );
        }
      case _InlineTokenKind.br:
      case _InlineTokenKind.blockEnd:
        appendNewline();
      case _InlineTokenKind.blockStart:
        // 开标签不引入分隔，纯粹忽略。
        break;
    }
  }
  if (cursor < html.length) {
    pendingText.write(html.substring(cursor));
  }
  flushText();

  // 去掉首尾的纯空白 TextSpan（包括首尾 "\n"）。
  bool isBlank(InlineSpan s) =>
      s is TextSpan && (s.text ?? '').trim().isEmpty;
  while (spans.isNotEmpty && isBlank(spans.first)) {
    spans.removeAt(0);
  }
  while (spans.isNotEmpty && isBlank(spans.last)) {
    spans.removeLast();
  }
  return spans;
}

/// 内联用的网络图片——专门给 `WidgetSpan` 当孩子用，不带 Align /
/// FittedBox，让它能跟周围文字一起按 baseline 走流式布局。
class _InlineNetworkImage extends StatelessWidget {
  const _InlineNetworkImage({
    required this.url,
    this.designWidth,
    this.designHeight,
  });

  final String url;
  final double? designWidth;
  final double? designHeight;

  @override
  Widget build(BuildContext context) {
    final w = designWidth;
    final h = designHeight;
    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: url,
      width: w,
      height: h,
      fit: BoxFit.contain,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (context, _) =>
          SizedBox(width: w ?? 40, height: h ?? 40),
      errorWidget: (context, _, _) => Container(
        width: w ?? 60,
        height: h ?? 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(
          Icons.broken_image_rounded,
          color: Color(0xFFC9C6D8),
        ),
      ),
    );
  }
}

/// 把后端给的 `<img src=".." width="W" height="H" />` 渲染成
/// 响应式网络图片：
/// - 设计尺寸 ≤ 容器最大宽度：按设计尺寸 1:1 渲染；
/// - 设计尺寸 > 容器最大宽度：`FittedBox(scaleDown)` 自动等比缩放；
/// - 走 [CachedNetworkImage]：磁盘缓存命中时秒出，同一 URL 同 cacheKey
///   避免 image stream 复用时出现"前一帧旧图"残影；
/// - 加载失败退化成灰色 broken image 占位，不会让整张题目崩掉。
///
/// ⚠️ 关键约束：本 widget 的祖先链上有 `IntrinsicHeight`（用于
/// 让 A/B/C/D 同一行两个卡片等高）。`IntrinsicHeight` 会向所有子
/// 孙查询 intrinsic 尺寸，**绝不能**在这里用 `LayoutBuilder`——
/// `LayoutBuilder` 不支持 intrinsic 查询，会直接抛断言导致整页
/// 白屏（典型表现：一行内一个文本一个图片选项时整页空白）。
/// 当前实现链：`Align → FittedBox(scaleDown) → SizedBox(w,h) → CachedNetworkImage`
/// 全部 intrinsic-friendly。
class _ResponsiveNetworkImage extends StatelessWidget {
  const _ResponsiveNetworkImage({
    required this.url,
    this.designWidth,
    this.designHeight,
  });

  final String url;
  final double? designWidth;
  final double? designHeight;

  @override
  Widget build(BuildContext context) {
    final w = designWidth;
    final h = designHeight;

    final image = CachedNetworkImage(
      imageUrl: url,
      cacheKey: url,
      width: w,
      height: h,
      fit: BoxFit.contain,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (context, _) => SizedBox(
        width: w ?? 40,
        height: h ?? 40,
      ),
      errorWidget: (context, _, _) => Container(
        width: w ?? 60,
        height: h ?? 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(
          Icons.broken_image_rounded,
          color: Color(0xFFC9C6D8),
        ),
      ),
    );

    // 没有设计尺寸：直接交给图片自身的 intrinsic 尺寸 + 父约束
    // 控制大小，左对齐避免被居中拉伸。
    if (w == null || h == null || w <= 0 || h <= 0) {
      return Align(alignment: Alignment.centerLeft, child: image);
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        // SizedBox 给 FittedBox 一个明确的"原始尺寸"，FittedBox
        // 才能在父容器变窄时按比例 scaleDown。
        child: SizedBox(width: w, height: h, child: image),
      ),
    );
  }
}
