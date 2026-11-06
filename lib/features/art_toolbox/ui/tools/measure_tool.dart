import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/ui.dart';
import '../../data/toolbox_catalog.dart';
import '../../data/toolbox_image_source.dart';
import '../../logic/geometry.dart';
import '../widgets/contain_mapping.dart';
import '../widgets/image_tool_frame.dart';
import '../widgets/tool_panel.dart';

/// 比例测量：点两点成一段，后面的线段都和 A 段比较；显示倾斜角度、铅垂线与水平线。
class MeasureTool extends StatelessWidget {
  const MeasureTool({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ImageToolScaffold(
      tool: ArtTool.measure,
      onBack: onBack,
      builder: (context, image) =>
          _MeasureBody(key: ValueKey(image.version), image: image),
    );
  }
}

/// 线段配色，按 A、B、C… 循环使用。
const _segmentColors = <Color>[
  AppColors.brand,
  AppColors.warning,
  AppColors.success,
  AppColors.danger,
];

String _segmentName(int index) => String.fromCharCode(65 + index);

Color _segmentColor(int index) => _segmentColors[index % _segmentColors.length];

String _fixed(double value, [int digits = 2]) => value.toStringAsFixed(digits);

class _MeasureBody extends StatefulWidget {
  const _MeasureBody({required this.image, super.key});

  final ToolboxImage image;

  @override
  State<_MeasureBody> createState() => _MeasureBodyState();
}

class _MeasureBodyState extends State<_MeasureBody> {
  static const _maxPoints = 12;
  static const _hitRadius = 24.0;

  final List<Offset> _points = <Offset>[];
  bool _plumb = true;
  bool _level = false;
  int? _dragging;

  int? _nearest(Offset local, ContainMapping mapping) {
    int? best;
    var bestDistance = _hitRadius;
    for (var i = 0; i < _points.length; i++) {
      final d = (mapping.toBox(_points[i]) - local).distance;
      if (d <= bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    return best;
  }

  void _tap(Offset local, ContainMapping mapping) {
    if (!mapping.imageRect.inflate(4).contains(local) ||
        _nearest(local, mapping) != null) {
      return;
    }
    if (_points.length >= _maxPoints) {
      AppToast.showInfo(context, '已量满 6 段，可先撤销或清空');
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _points.add(mapping.toImage(local)));
  }

  @override
  Widget build(BuildContext context) {
    return ImageToolLayout(stage: _buildStage, panel: _buildPanel);
  }

  Widget _buildStage(BuildContext context, bool wide) {
    final image = widget.image;
    return ToolStage(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mapping = ContainMapping(
              constraints.biggest,
              image.width,
              image.height,
            );
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _tap(details.localPosition, mapping),
              onPanStart: (details) =>
                  _dragging = _nearest(details.localPosition, mapping),
              onPanUpdate: (details) {
                final index = _dragging;
                if (index != null) {
                  setState(
                    () => _points[index] = mapping.toImage(
                      details.localPosition,
                    ),
                  );
                }
              },
              onPanEnd: (_) => _dragging = null,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RawImage(
                      image: image.image,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _MeasurePainter(
                        points: List<Offset>.of(_points),
                        mapping: mapping,
                        plumb: _plumb,
                        level: _level,
                        active: _dragging,
                      ),
                    ),
                  ),
                  if (_points.isEmpty)
                    const Positioned(
                      left: 0,
                      top: 0,
                      child: StageLabel('依次点两个点量出 A 段，再点两个点量出 B 段'),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPanel(BuildContext context, bool wide) {
    final segments = segmentsOf(_points);
    final unit = segments.isEmpty
        ? 0.0
        : segmentLength(segments.first.$1, segments.first.$2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToolPanelSection(
          title: '比例',
          child: _RatioSummary(segments: segments, pending: _points.length.isOdd),
        ),
        if (segments.isNotEmpty)
          ToolPanelSection(
            title: '线段',
            trailing: const Text('以 A 段为 1'),
            child: Column(
              children: [
                for (var i = 0; i < segments.length; i++)
                  _SegmentRow(
                    index: i,
                    segment: segments[i],
                    unit: unit,
                    divider: i < segments.length - 1,
                  ),
              ],
            ),
          ),
        ToolSwitchRow(
          label: '铅垂线',
          hint: '过每个点画竖线，检查上下是否对齐',
          value: _plumb,
          onChanged: (v) => setState(() => _plumb = v),
        ),
        ToolSwitchRow(
          label: '水平线',
          hint: '过每个点画横线，检查左右是否等高',
          value: _level,
          onChanged: (v) => setState(() => _level = v),
        ),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: '撤销一点',
                icon: Icons.undo_rounded,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                onTap: _points.isEmpty
                    ? null
                    : () => setState(() => _points.removeLast()),
              ),
            ),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: AppButton(
                label: '清空',
                icon: Icons.delete_sweep_outlined,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                onTap: _points.isEmpty
                    ? null
                    : () => setState(_points.clear),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s20),
        const ToolTipCard(
          title: '怎么量',
          text:
              '和写生时伸直手臂用铅笔比量一样：先量一个基准长度（如头长）作为 A 段，再量身高、肩宽等与它比较。'
              '拖动已有的点可以微调位置。铅垂线和水平线用来检查对齐关系，如内眼角与鼻翼、肩与胯是否在一条线上。',
        ),
      ],
    );
  }
}

class _RatioSummary extends StatelessWidget {
  const _RatioSummary({required this.segments, required this.pending});

  final List<(Offset, Offset)> segments;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    if (segments.length < 2) {
      final hint = segments.isEmpty
          ? (pending ? '再点一个点完成 A 段' : '在画面上点两个点量出 A 段')
          : (pending ? '再点一个点完成 B 段' : '再点两个点量出 B 段，显示两段之比');
      return Container(
        padding: const EdgeInsets.all(AppSpace.s12),
        decoration: const BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: AppRadius.br8,
        ),
        child: Text(hint, style: AppText.body13),
      );
    }
    final a = segmentLength(segments[0].$1, segments[0].$2);
    final b = segmentLength(segments[1].$1, segments[1].$2);
    final ratio = ratioTo(a, b);
    final String note;
    if (ratio == null) {
      note = 'A 段长度为 0，请重新取点';
    } else {
      final simple = simpleRatioLabel(ratio);
      note = simple == null
          ? 'B 段约为 A 段的 ${_fixed(ratio)} 倍'
          : 'B 段约为 A 段的 ${_fixed(ratio)} 倍，接近 $simple';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'A : B = ', style: AppText.body14),
              TextSpan(
                text: ratio == null ? '—' : '1 : ${_fixed(ratio)}',
                style: AppText.displayNumber(size: 24, color: AppColors.brand),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s4),
        Text(note, style: AppText.body13),
      ],
    );
  }
}

class _SegmentRow extends StatelessWidget {
  const _SegmentRow({
    required this.index,
    required this.segment,
    required this.unit,
    required this.divider,
  });

  final int index;
  final (Offset, Offset) segment;
  final double unit;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final (a, b) = segment;
    final ratio = ratioTo(unit, segmentLength(a, b));
    final horizontal = angleToHorizontal(a, b);
    final slope = slopeOf(a, b);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
      decoration: BoxDecoration(
        border: divider
            ? const Border(bottom: BorderSide(color: AppColors.lineSoft))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _segmentColor(index),
              borderRadius: AppRadius.br4,
            ),
            child: Text(
              _segmentName(index),
              style: AppText.caption12Strong.copyWith(color: AppColors.onBrand),
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ratio == null ? '长度 —' : '${_fixed(ratio)} A',
                  style: AppText.number(size: 14),
                ),
                Text(
                  '与水平 ${_fixed(horizontal, 1)}° · 与垂直 ${_fixed(90 - horizontal, 1)}° · ${slope.label}',
                  maxLines: 2,
                  style: AppText.caption12,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MeasurePainter extends CustomPainter {
  _MeasurePainter({
    required this.points,
    required this.mapping,
    required this.plumb,
    required this.level,
    required this.active,
  });

  final List<Offset> points;
  final ContainMapping mapping;
  final bool plumb;
  final bool level;
  final int? active;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = mapping.imageRect;
    final box = [for (final p in points) mapping.toBox(p)];
    final halo = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.35)
      ..strokeWidth = 3;
    final guide = Paint()
      ..color = AppColors.surface.withValues(alpha: 0.9)
      ..strokeWidth = 1;
    void dashed(Offset from, Offset to) {
      final total = (to - from).distance;
      if (total <= 0) {
        return;
      }
      final direction = (to - from) / total;
      for (var t = 0.0; t < total; t += 10) {
        final a = from + direction * t;
        final b = from + direction * math.min(total, t + 6);
        canvas
          ..drawLine(a, b, halo)
          ..drawLine(a, b, guide);
      }
    }

    for (final p in box) {
      if (plumb) {
        dashed(Offset(p.dx, rect.top), Offset(p.dx, rect.bottom));
      }
      if (level) {
        dashed(Offset(rect.left, p.dy), Offset(rect.right, p.dy));
      }
    }

    final segments = segmentsOf(box);
    for (var i = 0; i < segments.length; i++) {
      final (a, b) = segments[i];
      final color = _segmentColor(i);
      canvas
        ..drawLine(
          a,
          b,
          Paint()
            ..color = AppColors.surface
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round,
        )
        ..drawLine(
          a,
          b,
          Paint()
            ..color = color
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round,
        );
      _label(canvas, _segmentName(i), (a + b) / 2, color);
    }
    for (var i = 0; i < box.length; i++) {
      final color = _segmentColor(i ~/ 2);
      final radius = i == active ? 9.0 : 7.0;
      canvas
        ..drawCircle(box[i], radius + 2, Paint()..color = AppColors.surface)
        ..drawCircle(box[i], radius, Paint()..color = color);
    }
  }

  void _label(Canvas canvas, String text, Offset at, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: AppText.caption12Strong.copyWith(color: AppColors.onBrand),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final bubble = Rect.fromCenter(
      center: at + const Offset(0, -16),
      width: painter.width + 12,
      height: painter.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bubble, const Radius.circular(AppRadius.checkbox)),
      Paint()..color = color,
    );
    painter.paint(
      canvas,
      bubble.center - Offset(painter.width / 2, painter.height / 2),
    );
    painter.dispose();
  }

  @override
  bool shouldRepaint(covariant _MeasurePainter oldDelegate) => true;
}
