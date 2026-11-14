import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../../artworks/data/artwork_models.dart';
import '../../../artworks/state/student_artworks_controller.dart';
import '../widgets/study_common.dart';
import '../../data/study_models.dart';
import 'growth_line_chart.dart';

class StudentArtworkGrowthView extends ConsumerWidget {
  const StudentArtworkGrowthView({required this.onBack, super.key});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studentArtworksControllerProvider);
    final insights = state.insights;
    return StudyPageFrame(
      header: AppPageHeader(title: '作品成长', onBack: onBack),
      body: state.loading && !state.loaded
          ? const Center(child: AppLoadingIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpace.s16),
              children: [
                AppCard(
                  child: Wrap(
                    spacing: AppSpace.s16,
                    runSpacing: AppSpace.s8,
                    children: [
                      AppTag(label: '连续练习 ${insights.streakDays} 天'),
                      AppTag(label: '近 7 天提交 ${insights.recentSubmitCount} 份'),
                      AppTag(
                        label: insights.resolveRate == null
                            ? '问题解决率 —'
                            : '问题解决率 ${(insights.resolveRate! * 100).round()}%',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.s16),
                if (insights.dimensions.isEmpty)
                  const AppEmptyState(
                    icon: Icons.brush_outlined,
                    title: '暂无分项点评',
                    description: '老师填写分项评价后会显示在这里',
                  ),
                for (final subject in insights.dimensions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s12),
                    child: AppCard(
                      title: subject.subject,
                      subtitle: '按近 ${subject.sampleCount} 份已点评作品统计',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ArtworkDimensionChart(levels: subject),
                          if (subject.history.isNotEmpty)
                            _DimensionHistory(levels: subject),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _DimensionHistory extends StatefulWidget {
  const _DimensionHistory({required this.levels});
  final ArtworkDimensionLevels levels;

  @override
  State<_DimensionHistory> createState() => _DimensionHistoryState();
}

class _DimensionHistoryState extends State<_DimensionHistory> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final items = widget.levels.items;
    if (items.isEmpty) return const SizedBox.shrink();
    final key = items[_index.clamp(0, items.length - 1)].key;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpace.s8,
      children: [
        const SizedBox(height: AppSpace.s4),
        Text('分项趋势', style: AppText.title16),
        AppSegmented<int>(
          value: _index,
          segments: [
            for (var i = 0; i < items.length; i++)
              AppSegment(value: i, label: items[i].name),
          ],
          onChanged: (value) => setState(() => _index = value),
        ),
        SizedBox(
          height: 220,
          child: GrowthLineChart(
            metric: GrowthMetric.score,
            points: [
              for (final (i, point) in widget.levels.history.indexed)
                GrowthPoint(
                  examId: '$i',
                  examTime: point.date,
                  maxScore: 5,
                  value: point.levels[key],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class ArtworkDimensionChart extends StatelessWidget {
  const ArtworkDimensionChart({required this.levels, super.key});
  final ArtworkDimensionLevels levels;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox.square(
        dimension: 92,
        child: CustomPaint(
          painter: _DimensionPainter(
            levels.items.map((item) => item.level).toList(),
          ),
        ),
      ),
      const SizedBox(width: AppSpace.s12),
      Expanded(
        child: Wrap(
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s4,
          children: [
            for (final item in levels.items)
              AppTag(
                label: '${item.name} ${item.level?.toStringAsFixed(1) ?? '—'}',
              ),
          ],
        ),
      ),
    ],
  );
}

class _DimensionPainter extends CustomPainter {
  const _DimensionPainter(this.levels);
  final List<double?> levels;

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.length < 3) return;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.46;
    Path path(List<double> values) {
      final result = Path();
      for (var i = 0; i < values.length; i++) {
        final angle = 2 * math.pi * i / values.length - math.pi / 2;
        final point =
            center +
            Offset(math.cos(angle), math.sin(angle)) * (radius * values[i] / 5);
        if (i == 0) {
          result.moveTo(point.dx, point.dy);
        } else {
          result.lineTo(point.dx, point.dy);
        }
      }
      return result..close();
    }

    final outline = Paint()
      ..color = AppColors.line
      ..style = PaintingStyle.stroke;
    for (var i = 1; i <= 5; i++) {
      canvas.drawPath(path(List.filled(levels.length, i.toDouble())), outline);
    }
    if (levels.every((level) => level != null)) {
      final plot = path(levels.cast<double>());
      canvas.drawPath(plot, Paint()..color = AppColors.brandWash);
      canvas.drawPath(
        plot,
        Paint()
          ..color = AppColors.brand
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_DimensionPainter oldDelegate) =>
      oldDelegate.levels != levels;
}
