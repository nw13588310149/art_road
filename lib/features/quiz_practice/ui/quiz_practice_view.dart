import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/ui/ui.dart';
import '../state/quiz_practice_controller.dart';
import '../state/quiz_practice_state.dart';
import 'quiz_stats.dart';

/// 题库首页（公开题库与画室题库共用）：统计 + 四种练习方式。
class QuizPracticeView extends ConsumerWidget {
  const QuizPracticeView({
    required this.schoolId,
    required this.subtitle,
    this.title = '题库',
    this.showPictureQuiz = false,
    super.key,
  });

  final String schoolId;
  final String title;
  final String subtitle;

  /// 公开题库展示「看图识画」（暂未开放）说明卡。
  final bool showPictureQuiz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = quizPracticeControllerProvider(schoolId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final navigator = Navigator.of(context);

    ref.listen<QuizPracticeState>(provider, (previous, next) {
      final msg = next.errorMessage;
      if (msg.isEmpty || msg == previous?.errorMessage) return;
      if (_isEmpty(next)) return;
      AppToast.showError(context, msg);
    });

    final Widget body;
    if (state.summaries.isEmpty && state.loading) {
      body = const _QuizSkeleton();
    } else if (_isEmpty(state) && state.errorMessage.isNotEmpty) {
      body = AppErrorState(
        title: '题库加载失败',
        description: state.errorMessage,
        onRetry: controller.refresh,
      );
    } else {
      body = _QuizContent(
        summaries: state.summaries,
        showPictureQuiz: showPictureQuiz,
        onSelect: (summary) => _openSession(context, controller, summary),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      bordered: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPageHeader(
            title: title,
            subtitle: subtitle,
            onBack: navigator.canPop() ? navigator.pop : null,
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  /// 接口失败时控制器会回填全 0 的占位统计，此时整页显示出错状态而不是一排 0。
  static bool _isEmpty(QuizPracticeState state) =>
      state.summaries.every((s) => s.allCount == 0);

  Future<void> _openSession(
    BuildContext context,
    QuizPracticeController controller,
    QuizPracticeSummary summary,
  ) async {
    final args = await controller.buildSessionArgs(summary);
    if (!context.mounted) return;
    if (args == null) {
      AppToast.showInfo(
        context,
        summary.type == QuizPracticeType.error ? '错题本还是空的' : '暂无可练习的题目',
      );
      return;
    }
    await Navigator.pushNamed(context, RoutePaths.campAnswer, arguments: args);
    if (!context.mounted) return;
    await controller.refresh();
  }
}

class _QuizContent extends StatelessWidget {
  const _QuizContent({
    required this.summaries,
    required this.showPictureQuiz,
    required this.onSelect,
  });

  final List<QuizPracticeSummary> summaries;
  final bool showPictureQuiz;
  final ValueChanged<QuizPracticeSummary> onSelect;

  QuizPracticeSummary _summaryOf(QuizPracticeType type) {
    for (final s in summaries) {
      if (s.type == type) return s;
    }
    return QuizPracticeSummary.empty(type);
  }

  @override
  Widget build(BuildContext context) {
    final overall = _summaryOf(QuizPracticeType.sequence);
    final wrong = _summaryOf(QuizPracticeType.error);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s24,
        AppSpace.s4,
        AppSpace.s24,
        AppSpace.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(
            title: '美术常识',
            subtitle: '美术史、名作鉴赏与联考常识，共 ${overall.allCount} 题',
          ),
          const SizedBox(height: AppSpace.s12),
          QuizStats(
            notDone: overall.notDoneCount,
            done: overall.doneCount,
            wrong: wrong.allCount,
            accuracyPercent: overall.accuracyPercent,
          ),
          const SizedBox(height: AppSpace.s24),
          const AppSectionHeader(title: '练习方式'),
          const SizedBox(height: AppSpace.s12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 720 ? 4 : 2;
              final width =
                  (constraints.maxWidth - AppSpace.s16 * (columns - 1)) /
                  columns;
              return Wrap(
                spacing: AppSpace.s16,
                runSpacing: AppSpace.s16,
                children: [
                  for (final type in QuizPracticeType.values)
                    SizedBox(
                      width: width,
                      child: _PracticeModeCard(
                        summary: _summaryOf(type),
                        onTap: () => onSelect(_summaryOf(type)),
                      ),
                    ),
                ],
              );
            },
          ),
          if (showPictureQuiz) ...[
            const SizedBox(height: AppSpace.s24),
            AppCard(
              title: '看图识画',
              trailing: const AppTag(label: '暂未开放'),
              child: Text(
                '根据名作图片辨认作者、年代与流派。题目正在整理，开放后会在这里显示。',
                style: AppText.body13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PracticeModeCard extends StatelessWidget {
  const _PracticeModeCard({required this.summary, required this.onTap});

  final QuizPracticeSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = summary.type;
    final isError = type == QuizPracticeType.error;
    final caption = AppText.caption12;
    final descriptionHeight =
        MediaQuery.textScalerOf(context).scale(caption.fontSize!) *
        caption.height! *
        2;
    return AppPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.s16),
        decoration: BoxDecoration(
          borderRadius: AppRadius.br12,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.surfaceSubtle,
              Color.alphaBlend(
                type.accentColor.withValues(alpha: 0.12),
                AppColors.surface,
              ),
            ],
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: CustomPaint(
                painter: _RingPainter(
                  progress: summary.progress,
                  color: type.accentColor,
                ),
                child: Center(
                  child: Container(
                    width: 98,
                    height: 98,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isError
                              ? '${summary.allCount}'
                              : '${summary.progressPercent}%',
                          style: AppText.displayNumber(size: 24),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isError ? '道错题' : '学习进度',
                          style: AppText.caption12,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s12),
            Text(type.label, style: AppText.title16),
            const SizedBox(height: AppSpace.s4),
            SizedBox(
              height: descriptionHeight,
              child: Text(
                type.description,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: caption,
              ),
            ),
            const SizedBox(height: AppSpace.s8),
            Text(
              isError
                  ? '已复习 ${summary.doneCount} / ${summary.allCount}'
                  : '已做 ${summary.doneCount} / ${summary.allCount}',
              style: AppText.number(size: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizSkeleton extends StatelessWidget {
  const _QuizSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.page,
        AppSpace.s4,
        AppSpace.page,
        AppSpace.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(child: AppSkeletonText(lines: 3)),
          SizedBox(height: AppSpace.s24),
          Row(
            children: [
              Expanded(child: AppCard(child: AppSkeletonText(lines: 5))),
              SizedBox(width: AppSpace.s16),
              Expanded(child: AppCard(child: AppSkeletonText(lines: 5))),
              SizedBox(width: AppSpace.s16),
              Expanded(child: AppCard(child: AppSkeletonText(lines: 5))),
              SizedBox(width: AppSpace.s16),
              Expanded(child: AppCard(child: AppSkeletonText(lines: 5))),
            ],
          ),
        ],
      ),
    );
  }
}

/// 进度环：浅灰底环 + 从顶部顺时针的进度弧。
class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static const double _stroke = 8;
  static const double _startAngle = 3 * math.pi / 4;
  static const double _sweepAngle = 3 * math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final rect =
        const Offset(_stroke / 2, _stroke / 2) &
        Size(size.width - _stroke, size.height - _stroke);
    final track = Paint()
      ..color = AppColors.surface
      ..strokeWidth = _stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, _sweepAngle, false, track);
    if (progress <= 0) return;
    final fg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [color, color.withValues(alpha: 0.48)],
      ).createShader(rect)
      ..strokeWidth = _stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      _startAngle,
      _sweepAngle * progress.clamp(0.0, 1.0),
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}
