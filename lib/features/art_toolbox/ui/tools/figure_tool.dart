import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/figure_proportions.dart';
import '../../data/toolbox_catalog.dart';
import '../widgets/image_tool_frame.dart';
import '../widgets/tool_panel.dart';

/// 人体比例参考：站七坐五蹲三半，以头长为单位的比例图示；点选姿态查看要点。
class FigureTool extends StatefulWidget {
  const FigureTool({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  State<FigureTool> createState() => _FigureToolState();
}

class _FigureToolState extends State<FigureTool> {
  FigurePose _pose = FigurePose.standing;

  @override
  Widget build(BuildContext context) {
    return ToolPageScaffold(
      tool: ArtTool.figure,
      onBack: widget.onBack,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          final diagram = AppCard(
            padding: const EdgeInsets.all(AppSpace.s12),
            child: _FigureDiagram(
              selected: _pose,
              onSelect: (pose) => setState(() => _pose = pose),
            ),
          );
          final panel = AppCard(
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.card),
              child: _buildPanel(),
            ),
          );
          const padding = EdgeInsets.fromLTRB(
            AppSpace.page,
            0,
            AppSpace.page,
            AppSpace.page,
          );
          if (wide) {
            return Padding(
              padding: padding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: diagram),
                  const SizedBox(width: AppSpace.s16),
                  SizedBox(width: 320, child: panel),
                ],
              ),
            );
          }
          return Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: diagram),
                const SizedBox(height: AppSpace.s12),
                SizedBox(
                  height: (constraints.maxHeight * 0.4).clamp(200.0, 320.0),
                  child: panel,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToolPanelSection(
          title: '姿态',
          child: ToolSegmented<FigurePose>(
            values: FigurePose.values,
            value: _pose,
            labelOf: (p) => p.label,
            onChanged: (p) => setState(() => _pose = p),
          ),
        ),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${_pose.rhyme}  ', style: AppText.title16),
              TextSpan(
                text: _formatHeads(_pose.heads),
                style: AppText.displayNumber(size: 24, color: AppColors.brand),
              ),
              TextSpan(text: ' 个头长', style: AppText.body14),
            ],
          ),
        ),
        Text('${_pose.view}图示，头顶到脚底', style: AppText.caption12),
        const SizedBox(height: AppSpace.s12),
        for (final note in _pose.notes) _Bullet(note),
        const SizedBox(height: AppSpace.s12),
        ToolPanelSection(
          title: '通用要点',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final note in kFigureCommonNotes) _Bullet(note)],
          ),
        ),
        const ToolNotice(kFigureFootnote, tone: AppTone.neutral),
      ],
    );
  }
}

String _formatHeads(double heads) =>
    heads == heads.roundToDouble() ? '${heads.round()}' : heads.toStringAsFixed(1);

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, right: AppSpace.s8),
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: AppColors.textTertiary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: Text(text, style: AppText.body14)),
        ],
      ),
    );
  }
}

/// 三个姿态并排站在同一条地面线上，左侧是头长尺。
class _FigureLayout {
  _FigureLayout(Size size) {
    const rulerWidth = 44.0;
    const topMargin = 16.0;
    const bottomMargin = 48.0;
    const gapUnits = 1.1;
    final widths = [
      for (final pose in FigurePose.values) pose.skeleton.bounds.width + 0.4,
    ];
    final totalUnits =
        widths.fold<double>(0, (a, b) => a + b) + gapUnits * (widths.length - 1);
    unit = math.max(
      4,
      math.min(
        (size.height - topMargin - bottomMargin) / 7.2,
        (size.width - rulerWidth - 12) / totalUnits,
      ),
    );
    groundY = size.height - bottomMargin;
    rulerX = rulerWidth - 12;
    final used = totalUnits * unit;
    var x = rulerWidth + math.max(0, (size.width - rulerWidth - 12 - used) / 2);
    for (var i = 0; i < widths.length; i++) {
      final w = widths[i] * unit;
      slots.add(Rect.fromLTWH(x, 0, w, size.height));
      x += w + gapUnits * unit;
    }
  }

  late final double unit;
  late final double groundY;
  late final double rulerX;
  final List<Rect> slots = <Rect>[];

  /// 姿态 [pose] 的骨架坐标 → 画布坐标。
  Offset place(FigurePose pose, Offset p) {
    final skeleton = pose.skeleton;
    final bounds = skeleton.bounds;
    final slot = slots[pose.index];
    final left = slot.center.dx - bounds.width * unit / 2;
    return Offset(
      left + (p.dx - bounds.left) * unit,
      groundY - (skeleton.height - p.dy) * unit,
    );
  }
}

class _FigureDiagram extends StatelessWidget {
  const _FigureDiagram({required this.selected, required this.onSelect});

  final FigurePose selected;
  final ValueChanged<FigurePose> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _FigureLayout(constraints.biggest);
        return Semantics(
          label: '人体比例图示，当前为${selected.label}',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              for (final pose in FigurePose.values) {
                if (layout.slots[pose.index].contains(details.localPosition)) {
                  onSelect(pose);
                  return;
                }
              }
            },
            child: CustomPaint(
              size: constraints.biggest,
              painter: _FigurePainter(layout: layout, selected: selected),
            ),
          ),
        );
      },
    );
  }
}

class _FigurePainter extends CustomPainter {
  _FigurePainter({required this.layout, required this.selected});

  final _FigureLayout layout;
  final FigurePose selected;

  @override
  void paint(Canvas canvas, Size size) {
    _paintRuler(canvas, size);
    for (final pose in FigurePose.values) {
      _paintFigure(canvas, pose, pose == selected);
    }
  }

  void _paintRuler(Canvas canvas, Size size) {
    final unit = layout.unit;
    final ground = layout.groundY;
    final guide = Paint()
      ..color = AppColors.lineSoft
      ..strokeWidth = 1;
    final half = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (var k = 1; k <= 7; k++) {
      final y = ground - k * unit;
      canvas.drawLine(Offset(layout.rulerX, y), Offset(size.width, y), guide);
      _text(canvas, '$k', Offset(layout.rulerX - 6, y), number: true, alignRight: true);
    }
    final y35 = ground - 3.5 * unit;
    for (var x = layout.rulerX; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, y35), Offset(x + 4, y35), half);
    }
    _text(canvas, '3.5', Offset(layout.rulerX - 6, y35), number: true, alignRight: true);
    final ruler = Paint()
      ..color = AppColors.textTertiary
      ..strokeWidth = 1.5;
    canvas
      ..drawLine(
        Offset(layout.rulerX, ground),
        Offset(layout.rulerX, ground - 7 * unit),
        ruler,
      )
      ..drawLine(
        Offset(layout.rulerX - 4, ground),
        Offset(size.width, ground),
        Paint()
          ..color = AppColors.textPlaceholder
          ..strokeWidth = 1.5,
      );
    for (var k = 0; k <= 7; k++) {
      final y = ground - k * unit;
      canvas.drawLine(Offset(layout.rulerX, y), Offset(layout.rulerX + 6, y), ruler);
    }
    _text(canvas, '头长', Offset(layout.rulerX - 6, ground + 14), alignRight: true);
  }

  void _paintFigure(Canvas canvas, FigurePose pose, bool active) {
    final skeleton = pose.skeleton;
    final unit = layout.unit;
    final stroke = active ? AppColors.brand : AppColors.textPlaceholder;
    final fill = active ? AppColors.brandTint : AppColors.surfaceSubtle;
    Offset at(Offset p) => layout.place(pose, p);

    for (final (a, b) in skeleton.props) {
      canvas.drawLine(
        at(a),
        at(b),
        Paint()
          ..color = AppColors.textTertiary
          ..strokeWidth = math.max(2, 0.1 * unit)
          ..strokeCap = StrokeCap.round,
      );
    }
    for (final shape in skeleton.shapes) {
      final path = Path()..addPolygon([for (final p in shape) at(p)], true);
      canvas
        ..drawPath(path, Paint()..color = fill)
        ..drawPath(
          path,
          Paint()
            ..color = stroke
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..strokeJoin = StrokeJoin.round,
        );
    }
    for (final bone in skeleton.bones) {
      final width = bone.width * unit;
      canvas
        ..drawLine(
          at(bone.from),
          at(bone.to),
          Paint()
            ..color = stroke
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round,
        )
        ..drawLine(
          at(bone.from),
          at(bone.to),
          Paint()
            ..color = fill
            ..strokeWidth = math.max(0, width - 3)
            ..strokeCap = StrokeCap.round,
        );
    }
    for (final bone in skeleton.bones) {
      canvas.drawCircle(
        at(bone.from),
        math.max(1.5, 0.05 * unit),
        Paint()..color = stroke,
      );
    }
    final head = at(skeleton.headCenter);
    canvas
      ..save()
      ..translate(head.dx, head.dy)
      ..rotate(skeleton.headAngle);
    final oval = Rect.fromCenter(
      center: Offset.zero,
      width: kHeadWidth * unit,
      height: unit,
    );
    canvas
      ..drawOval(oval, Paint()..color = fill)
      ..drawOval(
        oval,
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      )
      ..restore();

    final slot = layout.slots[pose.index];
    _text(
      canvas,
      '${pose.label} · ${pose.rhyme}',
      Offset(slot.center.dx, layout.groundY + 20),
      center: true,
      strong: active,
    );

    if (!active) {
      return;
    }
    final top = at(Offset(skeleton.headCenter.dx, skeleton.headCenter.dy - 0.5));
    final chin = at(Offset(skeleton.headCenter.dx, skeleton.headCenter.dy + 0.5));
    final bracketX = at(skeleton.bounds.topLeft).dx - 10;
    final bracket = Paint()
      ..color = AppColors.brand
      ..strokeWidth = 1.5;
    canvas
      ..drawLine(Offset(bracketX, top.dy), Offset(bracketX, chin.dy), bracket)
      ..drawLine(Offset(bracketX, top.dy), Offset(bracketX + 5, top.dy), bracket)
      ..drawLine(Offset(bracketX, chin.dy), Offset(bracketX + 5, chin.dy), bracket);
    _text(
      canvas,
      '1 头长',
      Offset(bracketX - 4, (top.dy + chin.dy) / 2),
      alignRight: true,
      color: AppColors.brand,
    );
    final rightX = at(skeleton.bounds.topRight).dx + 8;
    for (final (heads, name) in pose.landmarks) {
      final y = layout.groundY - (skeleton.height - heads) * layout.unit;
      canvas.drawLine(
        Offset(rightX - 4, y),
        Offset(rightX + 2, y),
        Paint()
          ..color = AppColors.brand
          ..strokeWidth = 1.5,
      );
      _text(canvas, name, Offset(rightX + 4, y), color: AppColors.brand);
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset anchor, {
    bool alignRight = false,
    bool center = false,
    bool number = false,
    bool strong = false,
    Color? color,
  }) {
    final base = number
        ? AppText.number(size: 12, color: AppColors.textTertiary)
        : (strong ? AppText.body14Strong : AppText.caption12);
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: color == null ? base : base.copyWith(color: color),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final dx = alignRight
        ? anchor.dx - painter.width
        : (center ? anchor.dx - painter.width / 2 : anchor.dx);
    painter.paint(canvas, Offset(dx, anchor.dy - painter.height / 2));
    painter.dispose();
  }

  @override
  bool shouldRepaint(covariant _FigurePainter oldDelegate) =>
      oldDelegate.selected != selected || oldDelegate.layout != layout;
}
