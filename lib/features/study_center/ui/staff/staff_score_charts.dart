import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/art/art_subject.dart';
import '../../../../core/art/art_tokens.dart';
import '../../../../core/theme/app_font.dart';
import '../../../../core/widgets/art_widgets.dart';
import '../../data/study_logic.dart';
import '../../data/study_models.dart';
import '../widgets/study_common.dart';

/// 班级成绩指标：参考人数 / 平均分 / 最高分 / 最低分 / 中位数 / 满分。
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
      StudyStatTile(label: '参考人数', value: '${summary.count}', unit: '人'),
      StudyStatTile(
        label: '平均分',
        value: formatScore(summary.average),
        unit: '分',
        color: ArtColors.brandDeep,
      ),
      StudyStatTile(
        label: '最高分',
        value: formatScore(summary.max),
        unit: '分',
        color: ArtColors.up,
      ),
      StudyStatTile(
        label: '最低分',
        value: formatScore(summary.min),
        unit: '分',
        color: ArtColors.down,
      ),
      StudyStatTile(
        label: '中位数',
        value: formatScore(summary.median),
        unit: '分',
      ),
      StudyStatTile(
        label: '满分',
        value: formatScore(fullScore),
        unit: '分',
        color: ArtColors.ink2,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 6
            : (constraints.maxWidth >= 460 ? 3 : 2);
        const gap = 12.0;
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

/// 分数段柱状图：按档位着色，柱顶标注人数。
class ScoreDistributionChart extends StatelessWidget {
  const ScoreDistributionChart({
    required this.buckets,
    this.color = ArtColors.brand,
    super.key,
  });

  final List<ScoreBucket> buckets;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty || buckets.every((bucket) => bucket.count == 0)) {
      return const ArtEmptyState(
        message: '暂无分数数据',
        icon: Icons.bar_chart_rounded,
      );
    }
    final signature = buckets.map((b) => '${b.label}:${b.count}').join(',');
    return TweenAnimationBuilder<double>(
      key: ValueKey<String>(signature),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) => CustomPaint(
        size: Size.infinite,
        painter: _DistributionPainter(
          buckets: buckets,
          color: color,
          progress: progress,
        ),
      ),
    );
  }
}

class _DistributionPainter extends CustomPainter {
  _DistributionPainter({
    required this.buckets,
    required this.color,
    required this.progress,
  });

  final List<ScoreBucket> buckets;
  final Color color;
  final double progress;

  static const _padLeft = 30.0;
  static const _padRight = 6.0;
  static const _padTop = 24.0;
  static const _padBottom = 42.0;

  static const _axisStyle = TextStyle(
    fontSize: 11,
    height: 1.2,
    color: ArtColors.ink3,
    fontFamily: 'Manrope',
  );
  static const _rangeStyle = TextStyle(
    fontSize: 10,
    height: 1.2,
    color: ArtColors.ink4,
    fontFamily: 'Manrope',
  );

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      _padLeft,
      _padTop,
      size.width - _padRight,
      size.height - _padBottom,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    final maxCount = buckets.fold<int>(0, (m, b) => math.max(m, b.count));
    final axis = niceAxis(
      0,
      math.max(1, maxCount).toDouble(),
      integer: true,
      floor: 0,
    );
    final grid = Paint()
      ..color = ArtColors.line
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
    final barWidth = math.min(46.0, slot * 0.58);
    final radius = Radius.circular(math.min(7.0, barWidth / 3));
    for (var i = 0; i < buckets.length; i++) {
      final bucket = buckets[i];
      final centerX = plot.left + slot * (i + 0.5);
      final height =
          plot.height * axis.fraction(bucket.count.toDouble()) * progress;
      final barColor = bucket.grade.isEmpty
          ? color
          : ArtColors.grade(bucket.grade);
      if (height > 0) {
        final rect = Rect.fromLTWH(
          centerX - barWidth / 2,
          plot.bottom - height,
          barWidth,
          height,
        );
        canvas.drawRRect(
          RRect.fromRectAndCorners(rect, topLeft: radius, topRight: radius),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [barColor, barColor.withValues(alpha: 0.55)],
            ).createShader(rect),
        );
      }
      _paintText(
        canvas,
        TextSpan(
          children: [
            TextSpan(
              text: '${bucket.count}',
              style: TextStyle(
                fontSize: 12,
                height: 1.2,
                color: bucket.count == 0 ? ArtColors.ink4 : ArtColors.ink,
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: '人',
              style: ArtText.caption(size: 10, color: ArtColors.ink3),
            ),
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
              ? _axisStyle.copyWith(color: ArtColors.ink2)
              : TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  color: barColor,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w600,
                ),
        ),
        Offset(centerX, plot.bottom + 8),
        const Alignment(0, -1),
      );
      if (bucket.grade.isNotEmpty && bucket.rangeLabel.isNotEmpty) {
        _paintText(
          canvas,
          TextSpan(text: bucket.rangeLabel, style: _rangeStyle),
          Offset(centerX, plot.bottom + 25),
          const Alignment(0, -1),
        );
      }
    }
    canvas.drawLine(
      Offset(plot.left, plot.bottom),
      Offset(plot.right, plot.bottom),
      Paint()
        ..color = ArtColors.ink4
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
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      !identical(oldDelegate.buckets, buckets);
}

/// 校区对比：各校区平均分（含与全体均分的差值）。
class StaffCampusCard extends StatelessWidget {
  const StaffCampusCard({
    required this.groups,
    required this.overallAverage,
    required this.fullScore,
    required this.subjectLabel,
    super.key,
  });

  final List<GroupStat> groups;
  final double? overallAverage;
  final double? fullScore;
  final String subjectLabel;

  static const _palette = <Color>[
    ArtColors.brand,
    Color(0xFF4A74D6),
    Color(0xFF3B9A6E),
    Color(0xFFDE7A34),
    Color(0xFF1F8FA8),
  ];

  @override
  Widget build(BuildContext context) {
    return StudyCard(
      title: '校区对比',
      subtitle: '$subjectLabel平均分 · 与全体均分对比',
      child: groups.isEmpty
          ? const ArtEmptyState(
              message: '暂无校区数据',
              icon: Icons.apartment_rounded,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < groups.length; i++) ...[
                  if (i > 0) const SizedBox(height: 18),
                  _CampusRow(
                    rank: i + 1,
                    group: groups[i],
                    color: _palette[i % _palette.length],
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
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$rank',
                style: ArtText.number(size: 12, color: color),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                group.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ArtText.body(size: 14, weight: AppFont.w500),
              ),
            ),
            StudyNumberText(
              formatScore(average),
              unit: ' 分',
              size: 18,
              color: color,
            ),
          ],
        ),
        const SizedBox(height: 8),
        StudyProgressBar(
          value: average == null || full == null || full <= 0
              ? null
              : average / full,
          color: color,
          height: 8,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                '${group.count} 人 · 最高 ${formatScore(group.max)} 分',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ArtText.caption(size: 11),
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
    return StudyCard(
      title: '各科平均分',
      subtitle: '点击科目查看分布与排名',
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 640) {
            return Column(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  tiles[i],
                ],
              ],
            );
          }
          return Row(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
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
    final accent = artSubjectColor(name);
    final average = summary.average;
    final full = subject.fullScore;
    final rate = average == null || full == null || full <= 0
        ? null
        : average / full;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: selected ? artSubjectSoftColor(name) : ArtColors.subtle,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.45)
                : Colors.transparent,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StudySubjectIcon(subjectName: name, size: 30),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: ArtText.body(size: 15, weight: AppFont.w500),
                      ),
                    ),
                    Text(
                      studyPercentText(rate),
                      style: ArtText.number(size: 13, color: accent),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StudyNumberText(
                  formatScore(average),
                  unit: ' / ${formatScore(full)}',
                  size: 22,
                  color: accent,
                ),
                const SizedBox(height: 8),
                StudyProgressBar(value: rate, color: accent),
                const SizedBox(height: 8),
                Text(
                  '最高 ${formatScore(summary.max)} · 最低 ${formatScore(summary.min)} · A 档 $topCount 人',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ArtText.caption(size: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
