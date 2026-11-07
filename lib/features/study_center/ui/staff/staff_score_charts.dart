import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/ui/ui.dart';
import '../../data/study_logic.dart';
import '../../data/study_models.dart';
import '../widgets/study_common.dart';

/// 班级成绩指标：参考人数 / 平均分 / 最高分 / 最低分 / 中位数 / 满分，数字统一墨色。
class StaffStatTiles extends StatelessWidget {
  const StaffStatTiles({
    required this.summary,
    required this.fullScore,
    super.key,
  });

  final ScoreSummary summary;
  final double? fullScore;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      AppStatTile(
        label: '参考人数',
        value: '${summary.count}',
        unit: '人',
        boxed: true,
      ),
      AppStatTile(
        label: '平均分',
        value: formatScore(summary.average),
        unit: '分',
        boxed: true,
      ),
      AppStatTile(
        label: '最高分',
        value: formatScore(summary.max),
        unit: '分',
        boxed: true,
      ),
      AppStatTile(
        label: '最低分',
        value: formatScore(summary.min),
        unit: '分',
        boxed: true,
      ),
      AppStatTile(
        label: '中位数',
        value: formatScore(summary.median),
        unit: '分',
        boxed: true,
      ),
      AppStatTile(
        label: '满分',
        value: formatScore(fullScore),
        unit: '分',
        boxed: true,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 6
            : (constraints.maxWidth >= 460 ? 3 : 2);
        const gap = AppSpace.s12;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

/// 分数段柱状图：柱顶标注人数，静态绘制。
class ScoreDistributionChart extends StatelessWidget {
  const ScoreDistributionChart({
    required this.buckets,
    this.color = AppColors.brand,
    super.key,
  });

  final List<ScoreBucket> buckets;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty || buckets.every((bucket) => bucket.count == 0)) {
      return const AppEmptyState(
        icon: Icons.bar_chart_rounded,
        title: '暂无分数数据',
        description: '本场考试出分后会按分数段统计人数',
      );
    }
    return CustomPaint(
      size: Size.infinite,
      painter: _DistributionPainter(buckets: buckets, color: color),
    );
  }
}

class _DistributionPainter extends CustomPainter {
  _DistributionPainter({required this.buckets, required this.color});

  final List<ScoreBucket> buckets;
  final Color color;

  static const _padLeft = 28.0;
  static const _padRight = 4.0;
  static const _padTop = 22.0;
  static const _labelGap = 6.0;
  static const _lineHeight = 16.0;

  static final _axisStyle = AppText.number(
    size: 12,
    color: AppColors.textTertiary,
  );

  bool get _withRanges => buckets.any(
    (bucket) => bucket.grade.isNotEmpty && bucket.rangeLabel.isNotEmpty,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final padBottom =
        _labelGap + _lineHeight + (_withRanges ? _lineHeight : 0) + 2;
    final plot = Rect.fromLTRB(
      _padLeft,
      _padTop,
      size.width - _padRight,
      size.height - padBottom,
    );
    if (plot.width <= 0 || plot.height <= 0) {
      return;
    }

    final maxCount = buckets.fold<int>(0, (m, b) => math.max(m, b.count));
    final axis = niceAxis(
      0,
      math.max(1, maxCount).toDouble(),
      integer: true,
      floor: 0,
    );
    final grid = Paint()
      ..color = AppColors.lineSoft
      ..strokeWidth = 1;
    for (final tick in axis.ticks) {
      final y = plot.bottom - axis.fraction(tick) * plot.height;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _paintText(
        canvas,
        TextSpan(text: formatScore(tick), style: _axisStyle),
        Offset(plot.left - 8, y),
        const Alignment(1, 0),
      );
    }

    final slot = plot.width / buckets.length;
    final barWidth = math.min(44.0, slot * 0.56);
    final radius = Radius.circular(math.min(4.0, barWidth / 4));
    final barPaint = Paint()..color = color;
    for (var i = 0; i < buckets.length; i++) {
      final bucket = buckets[i];
      final centerX = plot.left + slot * (i + 0.5);
      final height = plot.height * axis.fraction(bucket.count.toDouble());
      if (height > 0) {
        final rect = Rect.fromLTWH(
          centerX - barWidth / 2,
          plot.bottom - height,
          barWidth,
          height,
        );
        canvas.drawRRect(
          RRect.fromRectAndCorners(rect, topLeft: radius, topRight: radius),
          barPaint,
        );
      }
      _paintText(
        canvas,
        TextSpan(
          children: [
            TextSpan(
              text: '${bucket.count}',
              style: AppText.number(
                size: 12,
                color: bucket.count == 0
                    ? AppColors.textPlaceholder
                    : AppColors.ink,
              ),
            ),
            TextSpan(text: ' 人', style: AppText.caption12),
          ],
        ),
        Offset(centerX, plot.bottom - height - 4),
        const Alignment(0, 1),
      );
      _paintText(
        canvas,
        TextSpan(
          text: bucket.label,
          style: bucket.grade.isEmpty
              ? _axisStyle.copyWith(color: AppColors.textSecondary)
              : AppText.caption12Strong,
        ),
        Offset(centerX, plot.bottom + _labelGap),
        const Alignment(0, -1),
      );
      if (bucket.grade.isNotEmpty && bucket.rangeLabel.isNotEmpty) {
        _paintText(
          canvas,
          TextSpan(text: bucket.rangeLabel, style: _axisStyle),
          Offset(centerX, plot.bottom + _labelGap + _lineHeight),
          const Alignment(0, -1),
        );
      }
    }
    canvas.drawLine(
      Offset(plot.left, plot.bottom),
      Offset(plot.right, plot.bottom),
      Paint()
        ..color = AppColors.line
        ..strokeWidth = 1,
    );
  }

  void _paintText(
    Canvas canvas,
    InlineSpan span,
    Offset anchor,
    Alignment alignment,
  ) {
    final painter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        anchor.dx - painter.width * (alignment.x + 1) / 2,
        anchor.dy - painter.height * (alignment.y + 1) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_DistributionPainter oldDelegate) =>
      oldDelegate.color != color || !identical(oldDelegate.buckets, buckets);
}

/// 校区对比：各校区平均分与全体均分的差值。校区按平均分排序，颜色不随名次变化。
class StaffCampusCard extends StatelessWidget {
  const StaffCampusCard({
    required this.groups,
    required this.overallAverage,
    required this.fullScore,
    required this.subjectLabel,
    this.color = AppColors.brand,
    super.key,
  });

  final List<GroupStat> groups;
  final double? overallAverage;
  final double? fullScore;
  final String subjectLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: '校区对比',
      subtitle: '$subjectLabel平均分 · 与全体均分对比',
      child: groups.isEmpty
          ? const SizedBox(
              height: 160,
              child: AppEmptyState(
                icon: Icons.apartment_rounded,
                title: '暂无校区数据',
                description: '学生档案填写所属校区后会按校区统计',
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < groups.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpace.s16),
                  _CampusRow(
                    rank: i + 1,
                    group: groups[i],
                    color: color,
                    fullScore: fullScore,
                    overallAverage: overallAverage,
                  ),
                ],
              ],
            ),
    );
  }
}

class _CampusRow extends StatelessWidget {
  const _CampusRow({
    required this.rank,
    required this.group,
    required this.color,
    required this.fullScore,
    required this.overallAverage,
  });

  final int rank;
  final GroupStat group;
  final Color color;
  final double? fullScore;
  final double? overallAverage;

  @override
  Widget build(BuildContext context) {
    final average = group.average;
    final full = fullScore;
    final overall = overallAverage;
    final delta = average == null || overall == null
        ? null
        : roundTo(average - overall, 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: AppRadius.br4,
              ),
              child: Text(
                '$rank',
                style: AppText.number(
                  size: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            Expanded(
              child: Text(
                group.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body14Strong,
              ),
            ),
            StudyNumberText(formatScore(average), unit: ' 分', size: 20),
          ],
        ),
        const SizedBox(height: AppSpace.s8),
        AppProgressBar(
          value: average == null || full == null || full <= 0
              ? 0
              : average / full,
          color: color,
          height: 6,
        ),
        const SizedBox(height: AppSpace.s8),
        Row(
          children: [
            Expanded(
              child: Text(
                '${group.count} 人参考 · 最高 ${formatScore(group.max)} 分',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption12,
              ),
            ),
            if (delta != null) StudyDeltaTag(value: delta),
          ],
        ),
      ],
    );
  }
}

/// 各科平均分：点击切换到该科（再次点击回到总分）。
class StaffSubjectAverages extends StatelessWidget {
  const StaffSubjectAverages({
    required this.exam,
    required this.rows,
    required this.selectedSubject,
    required this.onSelect,
    super.key,
  });

  final TeacherExam exam;
  final List<ScoreQueryRow> rows;
  final String selectedSubject;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      for (final subject in exam.subjects)
        _SubjectAverageTile(
          subject: subject,
          summary: summarizeScores(
            rows
                .map((row) => row.subjectNamed(subject.subjectName)?.score)
                .whereType<double>(),
          ),
          topCount: rows
              .where(
                (row) => row.subjectNamed(subject.subjectName)?.grade == 'A',
              )
              .length,
          selected: subject.subjectName == selectedSubject,
          onTap: () => onSelect(
            subject.subjectName == selectedSubject ? '' : subject.subjectName,
          ),
        ),
    ];
    return AppCard(
      title: '各科平均分',
      subtitle: '点击科目查看分布与排名，再次点击回到总分',
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 640) {
            return Column(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpace.s12),
                  tiles[i],
                ],
              ],
            );
          }
          return Row(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpace.s12),
                Expanded(child: tiles[i]),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SubjectAverageTile extends StatelessWidget {
  const _SubjectAverageTile({
    required this.subject,
    required this.summary,
    required this.topCount,
    required this.selected,
    required this.onTap,
  });

  final TeacherExamSubject subject;
  final ScoreSummary summary;
  final int topCount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = subject.subjectName;
    final accent = studySubjectColor(name);
    final average = summary.average;
    final full = subject.fullScore;
    final rate = average == null || full == null || full <= 0
        ? null
        : average / full;
    return AppPressable(
      onTap: onTap,
      selected: selected,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.s12),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandWash : AppColors.surfaceSubtle,
          borderRadius: AppRadius.br12,
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.surfaceSubtle,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StudySubjectIcon(subjectName: name, size: 30),
                const SizedBox(width: AppSpace.s8),
                Expanded(child: Text(name, style: AppText.body14Strong)),
                Text(
                  '得分率 ${studyPercentText(rate)}',
                  style: AppText.caption12,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s12),
            StudyNumberText(
              formatScore(average),
              unit: ' / ${formatScore(full)} 分',
              size: 24,
            ),
            const SizedBox(height: AppSpace.s8),
            AppProgressBar(value: rate ?? 0, color: accent, height: 6),
            const SizedBox(height: AppSpace.s8),
            Text(
              '最高 ${formatScore(summary.max)} · 最低 ${formatScore(summary.min)} · A 档 $topCount 人',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption12,
            ),
          ],
        ),
      ),
    );
  }
}
