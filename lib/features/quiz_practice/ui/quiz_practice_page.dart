import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/quiz_practice_controller.dart';
import '../state/quiz_practice_state.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

// ─────────────────────────────────────────────────────────────────────
// 视觉常量
//
// 乐理刷题：紫色为主，错题集红色。
// 听写刷题：绿色为主，错题集红色（暂未开放，所有数据 0）。
// ─────────────────────────────────────────────────────────────────────

/// 正确率过低时统计卡片整列变红高亮使用的颜色。
const Color _kAccuracyLowColor = Color(0xFFFF8486);
const Color _kStatCardBg = Color(0xFFF5F6FA);
const Color _kStatTextDefault = Color(0xFF0B081A);
const Color _kStatLabelDefault = Color(0xFF8B8B97);

const LinearGradient _kPurpleCardGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFF5F6FA), Color(0xFFF1EFFF)],
);
const LinearGradient _kGreenCardGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFF5F6FA), Color(0xFFE4FAF5)],
);
const LinearGradient _kRedCardGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFFAF5F5), Color(0xFFFFE2E2)],
);

/// 圆环渐变（自下而上：深 → 浅，与 SVG 设计稿一致）。
const LinearGradient _kPurpleRingGradient = LinearGradient(
  begin: Alignment.bottomCenter,
  end: Alignment.topCenter,
  colors: [Color(0xFF8640FF), Color(0xFFB68EFF)],
);
const LinearGradient _kGreenRingGradient = LinearGradient(
  begin: Alignment.bottomCenter,
  end: Alignment.topCenter,
  colors: [Color(0xFF10D0B6), Color(0xFF15EFC9)],
);
const LinearGradient _kRedRingGradient = LinearGradient(
  begin: Alignment.bottomCenter,
  end: Alignment.topCenter,
  colors: [Color(0xFFFF8486), Color(0xFFFFC2C3)],
);

class QuizPracticePage extends ConsumerWidget {
  const QuizPracticePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const schoolId = kPublicQuizSchoolId;
    final provider = quizPracticeControllerProvider(schoolId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final ui = DashboardScaleScope.of(context).ui;

    ref.listen<QuizPracticeState>(provider, (previous, next) {
      final msg = next.errorMessage;
      if (msg.isEmpty || msg == previous?.errorMessage) return;
      AppToast.show(context, msg);
    });

    return ShellPageSurface(
      padding: EdgeInsets.fromLTRB(ui(24), ui(20), ui(24), ui(8)),
      child: state.loading && state.summaries.isEmpty
          ? const Center(child: AppLoadingIndicator())
          : _QuizContent(
              summaries: state.summaries,
              onSelect: (summary) =>
                  _openSession(context, controller, summary),
              onDictationTap: () =>
                  showInfoDialog(context: context, title: '功能暂未开放'),
            ),
    );
  }

  Future<void> _openSession(
    BuildContext context,
    QuizPracticeController controller,
    QuizPracticeSummary summary,
  ) async {
    final args = await controller.buildSessionArgs(summary);
    if (!context.mounted) return;
    if (args == null) {
      AppToast.show(context, '暂无可练习题目');
      return;
    }
    await Navigator.pushNamed(context, RoutePaths.campAnswer, arguments: args);
    if (!context.mounted) {
      return;
    }
    await controller.refresh();
  }
}

// ─────────────────────────────────────────────────────────────────────
// 整页可滚动主体：乐理刷题区 + 听写刷题区
// ─────────────────────────────────────────────────────────────────────

class _QuizContent extends StatelessWidget {
  const _QuizContent({
    required this.summaries,
    required this.onSelect,
    required this.onDictationTap,
  });

  final List<QuizPracticeSummary> summaries;
  final ValueChanged<QuizPracticeSummary> onSelect;
  final VoidCallback onDictationTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final theorySequence = _summaryOf(QuizPracticeType.sequence);
    final dictationSummaries = QuizPracticeType.values
        .map(QuizPracticeSummary.empty)
        .toList(growable: false);

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle('乐理刷题'),
          SizedBox(height: ui(12)),
          _StatsRow(
            notDone: theorySequence.notDoneCount,
            done: theorySequence.doneCount,
            wrong: theorySequence.errorCount,
            accuracyPercent: theorySequence.accuracyPercent,
          ),
          SizedBox(height: ui(20)),
          _PracticeRingRow(
            summaries: summaries.isEmpty
                ? QuizPracticeType.values
                    .map(QuizPracticeSummary.empty)
                    .toList(growable: false)
                : summaries,
            groupRingGradient: _kPurpleRingGradient,
            groupCardGradient: _kPurpleCardGradient,
            onSelect: onSelect,
          ),
          SizedBox(height: ui(28)),
          const _SectionTitle('听写刷题'),
          SizedBox(height: ui(12)),
          const _StatsRow(notDone: 0, done: 0, wrong: 0, accuracyPercent: 0),
          SizedBox(height: ui(20)),
          _PracticeRingRow(
            summaries: dictationSummaries,
            groupRingGradient: _kGreenRingGradient,
            groupCardGradient: _kGreenCardGradient,
            onSelect: (_) => onDictationTap(),
          ),
        ],
      ),
    );
  }

  QuizPracticeSummary _summaryOf(QuizPracticeType type) {
    for (final s in summaries) {
      if (s.type == type) return s;
    }
    return QuizPracticeSummary.empty(type);
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

// ─────────────────────────────────────────────────────────────────────
// 4 个统计卡片：未做题 / 已做题 / 错题 / 正确率
// 正确率 < 60% 时整组红字高亮。
// ─────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.notDone,
    required this.done,
    required this.wrong,
    required this.accuracyPercent,
  });

  final int notDone;
  final int done;
  final int wrong;
  final int accuracyPercent;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final accuracyLow = accuracyPercent < 60;
    return Row(
      children: [
        Expanded(child: _StatCard(value: '$notDone', label: '未做题')),
        SizedBox(width: ui(16)),
        Expanded(child: _StatCard(value: '$done', label: '已做题')),
        SizedBox(width: ui(16)),
        Expanded(child: _StatCard(value: '$wrong', label: '错题')),
        SizedBox(width: ui(16)),
        Expanded(
          child: _StatCard(
            value: '$accuracyPercent%',
            label: '正确率',
            highlight: accuracyLow,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final highlightColor = _kAccuracyLowColor;
    return Container(
      height: ui(86),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _kStatCardBg,
        borderRadius: BorderRadius.circular(ui(10)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: highlight ? highlightColor : _kStatTextDefault,
              fontSize: ui(26),
              fontFamily: 'Barlow',
              fontWeight: AppFont.w600,
              height: 1.1,
            ),
          ),
          SizedBox(height: ui(4)),
          Text(
            label,
            style: TextStyle(
              color: highlight ? highlightColor : _kStatLabelDefault,
              fontSize: ui(12),
              fontFamily: 'PingFang SC',
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 4 个圆环卡片：顺序 / 随机 / 考前 / 错题
// 整行按"分组"统一主色（紫 / 绿），错题集独立用红色。
// ─────────────────────────────────────────────────────────────────────

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

  /// 内圆阴影色：取环渐变深色端，确保和环主色一致。
  Color get _shadowColor => ringGradient.colors.first;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final ringSize = ui(140);
    final innerSize = ui(98);
    final pillWidth = ui(80);
    final pillHeight = ui(28);
    // 内圆与外环几何中心对齐。
    final innerTop = (ringSize - innerSize) / 2;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
                              '${summary.progressPercent}%',
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
                              '学习进度',
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

// ─────────────────────────────────────────────────────────────────────
// 表盘式圆环 painter（底部开口，类似速度表盘）
// ─────────────────────────────────────────────────────────────────────

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

  /// 表盘起点 7:30 方向（左下），顺时针经过左侧 → 顶部 → 右侧，到 4:30 方向结束（右下）。
  /// 底部 90° 开口让数据标签胶囊位于两端之间，60% 进度末端正好停在约 1 点钟方向，
  /// 与设计稿截图一致（270° 总弧 + 90° 缺口）。
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
