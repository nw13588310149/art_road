import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/ui/ui.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/quiz_practice_controller.dart';
import '../state/quiz_practice_state.dart';
import 'quiz_stats.dart';

const Color _kStatTextDefault = Color(0xFF0B081A);
const Color _kStatLabelDefault = Color(0xFF8B8B97);

const LinearGradient _kPurpleCardGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFF5F6FA), Color(0xFFF1EFFF)],
);
const LinearGradient _kRedCardGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFFAF5F5), Color(0xFFFFE2E2)],
);

/// 圆环渐变：品牌紫深 → 浅；错题本用红色。
const LinearGradient _kPurpleRingGradient = LinearGradient(
  begin: Alignment.bottomCenter,
  end: Alignment.topCenter,
  colors: [AppColors.brand, Color(0xFFA99BFF)],
);
const LinearGradient _kRedRingGradient = LinearGradient(
  begin: Alignment.bottomCenter,
  end: Alignment.topCenter,
  colors: [Color(0xFFFF8486), Color(0xFFFFC2C3)],
);

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

  /// 公开题库提供范画赏析入口。
  final bool showPictureQuiz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = quizPracticeControllerProvider(schoolId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final navigator = Navigator.of(context);
    final ui = DashboardScaleScope.of(context).ui;

    ref.listen<QuizPracticeState>(provider, (previous, next) {
      final msg = next.errorMessage;
      if (msg.isEmpty || msg == previous?.errorMessage) return;
      if (_isEmpty(next)) return;
      AppToast.showError(context, msg);
    });

    final Widget body;
    if (state.summaries.isEmpty && state.loading) {
      body = const Center(child: AppLoadingIndicator());
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
        onPictureQuizTap: () =>
            Navigator.of(context).pushNamed(RoutePaths.gallery),
      );
    }

    return ShellPageSurface(
      padding: EdgeInsets.fromLTRB(ui(24), ui(20), ui(24), ui(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (navigator.canPop()) ...[
                _BackButton(onTap: navigator.pop),
                SizedBox(width: ui(12)),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: _kStatTextDefault,
                        fontSize: ui(18),
                        fontWeight: AppFont.w600,
                        fontFamily: 'PingFang SC',
                        height: 1.2,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      SizedBox(height: ui(4)),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: _kStatLabelDefault,
                          fontSize: ui(12),
                          fontFamily: 'PingFang SC',
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: ui(16)),
          Expanded(child: body),
        ],
      ),
    );
  }

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

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: ui(32),
        height: ui(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3), width: 1),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.chevron_left,
          color: const Color(0xFF1C274C),
          size: ui(20),
        ),
      ),
    );
  }
}

class _QuizContent extends StatelessWidget {
  const _QuizContent({
    required this.summaries,
    required this.showPictureQuiz,
    required this.onSelect,
    required this.onPictureQuizTap,
  });

  final List<QuizPracticeSummary> summaries;
  final bool showPictureQuiz;
  final ValueChanged<QuizPracticeSummary> onSelect;
  final VoidCallback onPictureQuizTap;

  QuizPracticeSummary _summaryOf(QuizPracticeType type) {
    for (final s in summaries) {
      if (s.type == type) return s;
    }
    return QuizPracticeSummary.empty(type);
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final overall = _summaryOf(QuizPracticeType.sequence);
    final wrong = _summaryOf(QuizPracticeType.error);
    final cards = summaries.isEmpty
        ? QuizPracticeType.values
              .map(QuizPracticeSummary.empty)
              .toList(growable: false)
        : summaries;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle('美术常识'),
          SizedBox(height: ui(12)),
          QuizStats(
            notDone: overall.notDoneCount,
            done: overall.doneCount,
            wrong: wrong.allCount,
            accuracyPercent: overall.accuracyPercent,
          ),
          SizedBox(height: ui(20)),
          const _SectionTitle('练习方式'),
          SizedBox(height: ui(12)),
          _PracticeRingRow(
            summaries: cards,
            groupRingGradient: _kPurpleRingGradient,
            groupCardGradient: _kPurpleCardGradient,
            onSelect: onSelect,
          ),
          if (showPictureQuiz) ...[
            SizedBox(height: ui(28)),
            const _SectionTitle('看图赏析'),
            SizedBox(height: ui(12)),
            _PictureQuizCard(onTap: onPictureQuizTap),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Text(
      text,
      style: TextStyle(
        color: _kStatTextDefault,
        fontSize: ui(18),
        fontWeight: AppFont.w600,
        fontFamily: 'PingFang SC',
        height: 1.2,
      ),
    );
  }
}

class _PracticeRingRow extends StatelessWidget {
  const _PracticeRingRow({
    required this.summaries,
    required this.groupRingGradient,
    required this.groupCardGradient,
    required this.onSelect,
  });

  final List<QuizPracticeSummary> summaries;
  final LinearGradient groupRingGradient;
  final LinearGradient groupCardGradient;
  final ValueChanged<QuizPracticeSummary> onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < summaries.length; i++) ...[
          if (i > 0) SizedBox(width: ui(16)),
          Expanded(
            child: _PracticeRingCard(
              summary: summaries[i],
              ringGradient: summaries[i].type == QuizPracticeType.error
                  ? _kRedRingGradient
                  : groupRingGradient,
              cardGradient: summaries[i].type == QuizPracticeType.error
                  ? _kRedCardGradient
                  : groupCardGradient,
              onTap: () => onSelect(summaries[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _PracticeRingCard extends StatelessWidget {
  const _PracticeRingCard({
    required this.summary,
    required this.ringGradient,
    required this.cardGradient,
    required this.onTap,
  });

  final QuizPracticeSummary summary;
  final LinearGradient ringGradient;
  final LinearGradient cardGradient;
  final VoidCallback onTap;

  Color get _shadowColor => ringGradient.colors.first;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final ringSize = ui(140);
    final innerSize = ui(98);
    final pillWidth = ui(80);
    final pillHeight = ui(28);
    final innerTop = (ringSize - innerSize) / 2;
    final isError = summary.type == QuizPracticeType.error;

    return AppPressable(
      onTap: onTap,
      semanticLabel: summary.type.label,
      child: Container(
        height: ui(260),
        decoration: BoxDecoration(
          gradient: cardGradient,
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: ringSize,
              height: ringSize + pillHeight / 2,
              child: Stack(
                alignment: Alignment.topCenter,
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: ringSize,
                    height: ringSize,
                    child: CustomPaint(
                      painter: _RingPainter(
                        progress: summary.progress,
                        gradient: ringGradient,
                        trackColor: Colors.white,
                        strokeWidth: ui(8),
                      ),
                    ),
                  ),
                  Positioned(
                    top: innerTop,
                    child: Container(
                      width: innerSize,
                      height: innerSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: _shadowColor.withValues(alpha: 0.18),
                            blurRadius: ui(16),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isError
                                ? '${summary.allCount}'
                                : '${summary.progressPercent}%',
                            style: TextStyle(
                              color: _kStatTextDefault,
                              fontSize: ui(24),
                              fontFamily: 'Barlow',
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                            ),
                          ),
                          SizedBox(height: ui(4)),
                          Text(
                            isError ? '道错题' : '学习进度',
                            style: TextStyle(
                              color: _kStatLabelDefault,
                              fontSize: ui(12),
                              fontFamily: 'PingFang SC',
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    child: Container(
                      width: pillWidth,
                      height: pillHeight,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(pillHeight / 2),
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${summary.doneCount}',
                              style: TextStyle(
                                color: _kStatTextDefault,
                                fontSize: ui(13),
                                fontFamily: 'Barlow',
                                fontWeight: AppFont.w600,
                              ),
                            ),
                            TextSpan(
                              text: '/${summary.allCount}',
                              style: TextStyle(
                                color: _kStatLabelDefault,
                                fontSize: ui(13),
                                fontFamily: 'Barlow',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: ui(12)),
            Text(
              summary.type.label,
              style: TextStyle(
                color: _kStatTextDefault,
                fontSize: ui(16),
                fontWeight: AppFont.w600,
                fontFamily: 'PingFang SC',
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PictureQuizCard extends StatelessWidget {
  const _PictureQuizCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return AppPressable(
      onTap: onTap,
      semanticLabel: '查看范画',
      child: Container(
        height: ui(86),
        padding: EdgeInsets.symmetric(horizontal: ui(20)),
        decoration: BoxDecoration(
          gradient: _kPurpleCardGradient,
          borderRadius: BorderRadius.circular(ui(12)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '观察范画的构图、用色与表现方法',
                    style: TextStyle(
                      color: _kStatTextDefault,
                      fontSize: ui(14),
                      fontWeight: AppFont.w500,
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                  SizedBox(height: ui(4)),
                  Text(
                    '查看画面解析，收藏有启发的作品',
                    style: TextStyle(
                      color: _kStatLabelDefault,
                      fontSize: ui(12),
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ui(10),
                vertical: ui(4),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ui(6)),
              ),
              child: Text(
                '查看范画',
                style: TextStyle(
                  color: AppColors.brand,
                  fontSize: ui(12),
                  fontWeight: AppFont.w500,
                  fontFamily: 'PingFang SC',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 表盘式圆环 painter（底部开口）。
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.gradient,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Gradient gradient;
  final Color trackColor;
  final double strokeWidth;

  static const double _startAngle = 3 * math.pi / 4;
  static const double _sweepAngle = 3 * math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final rect =
        Offset(strokeWidth / 2, strokeWidth / 2) &
        Size(size.width - strokeWidth, size.height - strokeWidth);

    final track = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, _sweepAngle, false, track);

    if (progress <= 0) return;
    final fg = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = strokeWidth
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
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.gradient != gradient ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
