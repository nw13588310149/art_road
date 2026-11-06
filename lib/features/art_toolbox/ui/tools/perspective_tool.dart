import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/toolbox_catalog.dart';
import '../../data/toolbox_image_source.dart';
import '../../logic/geometry.dart';
import '../widgets/image_tool_frame.dart';
import '../widgets/tool_panel.dart';

/// 透视辅助：可拖动的视平线与一至三个灭点，从灭点放射出辅助线，检查透视是否统一。
class PerspectiveTool extends StatelessWidget {
  const PerspectiveTool({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ImageToolScaffold(
      tool: ArtTool.perspective,
      onBack: onBack,
      builder: (context, image) =>
          _PerspectiveBody(key: ValueKey(image.version), image: image),
    );
  }
}

enum _PerspectiveMode {
  one(1, '一点透视'),
  two(2, '两点透视'),
  three(3, '三点透视');

  const _PerspectiveMode(this.points, this.label);

  final int points;
  final String label;
}

/// 灭点配色：灭点 1、2、3。
const _vpColors = <Color>[AppColors.danger, AppColors.success, AppColors.warning];

/// 画面在舞台里的位置：灭点等坐标以图片宽高为 1 存储，可以超出图片。
class _StageMapping {
  _StageMapping(Size stage, Size image, double viewScale)
    : stageRect = Offset.zero & stage {
    final fitted = applyBoxFit(
      BoxFit.contain,
      image,
      Size(
        math.max(1, stage.width * viewScale - 24),
        math.max(1, stage.height * viewScale - 24),
      ),
    ).destination;
    imageRect = Rect.fromCenter(
      center: stageRect.center,
      width: fitted.width,
      height: fitted.height,
    );
  }

  final Rect stageRect;
  late final Rect imageRect;

  Offset toStage(Offset normalized) =>
      imageRect.topLeft +
      Offset(normalized.dx * imageRect.width, normalized.dy * imageRect.height);

  /// 显示位置：超出舞台的灭点贴着舞台边缘显示，始终能拖到。
  Offset place(Offset normalized) {
    final p = toStage(normalized);
    final inner = stageRect.deflate(14);
    return Offset(
      p.dx.clamp(inner.left, inner.right),
      p.dy.clamp(inner.top, inner.bottom),
    );
  }

  Offset toNormalized(Offset stage) {
    final clamped = Offset(
      stage.dx.clamp(stageRect.left + 4, stageRect.right - 4),
      stage.dy.clamp(stageRect.top + 4, stageRect.bottom - 4),
    );
    return Offset(
      (clamped.dx - imageRect.left) / imageRect.width,
      (clamped.dy - imageRect.top) / imageRect.height,
    );
  }
}

class _PerspectiveBody extends StatefulWidget {
  const _PerspectiveBody({required this.image, super.key});

  final ToolboxImage image;

  @override
  State<_PerspectiveBody> createState() => _PerspectiveBodyState();
}

class _PerspectiveBodyState extends State<_PerspectiveBody> {
  static const _hitRadius = 26.0;

  _PerspectiveMode _mode = _PerspectiveMode.one;
  double _horizon = 0.45;
  double _vp1x = 0.5;
  double _vp2x = 1.3;
  Offset _vp3 = const Offset(0.5, 1.25);
  int _density = 12;
  double _opacity = 0.8;
  bool _zoomOut = false;

  /// 拖动目标：0–2 为灭点，3 为视平线。
  int? _dragging;

  List<Offset> get _vanishingPoints => [
    Offset(_vp1x, _horizon),
    if (_mode.points >= 2) Offset(_vp2x, _horizon),
    if (_mode.points == 3) _vp3,
  ];

  void _setMode(_PerspectiveMode mode) {
    setState(() {
      _mode = mode;
      _zoomOut = mode != _PerspectiveMode.one;
      if (mode == _PerspectiveMode.one) {
        _vp1x = 0.5;
      } else {
        _vp1x = -0.3;
        _vp2x = 1.3;
      }
      _vp3 = Offset(0.5, _horizon < 0.5 ? 1.25 : -0.25);
    });
  }

  void _reset() {
    _horizon = 0.45;
    _density = 12;
    _opacity = 0.8;
    _setMode(_mode);
  }

  int? _hit(Offset local, _StageMapping mapping) {
    final points = _vanishingPoints;
    for (var i = 0; i < points.length; i++) {
      if ((mapping.place(points[i]) - local).distance <= _hitRadius) {
        return i;
      }
    }
    final horizonY = mapping.place(Offset(0.5, _horizon)).dy;
    if ((local.dy - horizonY).abs() <= 20) {
      return 3;
    }
    return null;
  }

  void _drag(Offset local, _StageMapping mapping) {
    final target = _dragging;
    if (target == null) {
      return;
    }
    final p = mapping.toNormalized(local);
    setState(() {
      switch (target) {
        case 0:
          _vp1x = p.dx;
          _horizon = p.dy;
        case 1:
          _vp2x = p.dx;
          _horizon = p.dy;
        case 2:
          _vp3 = p;
        default:
          _horizon = p.dy;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ImageToolLayout(stage: _buildStage, panel: _buildPanel);
  }

  Widget _buildStage(BuildContext context, bool wide) {
    final image = widget.image;
    return ToolStage(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mapping = _StageMapping(
            constraints.biggest,
            Size(image.width.toDouble(), image.height.toDouble()),
            _zoomOut ? 0.6 : 1,
          );
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) =>
                _dragging = _hit(details.localPosition, mapping),
            onPanUpdate: (details) => _drag(details.localPosition, mapping),
            onPanEnd: (_) => setState(() => _dragging = null),
            child: Stack(
              children: [
                Positioned.fromRect(
                  rect: mapping.imageRect,
                  child: RawImage(
                    image: image.image,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PerspectivePainter(
                      mapping: mapping,
                      horizon: _horizon,
                      points: _vanishingPoints,
                      density: _density,
                      opacity: _opacity,
                      active: _dragging,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPanel(BuildContext context, bool wide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToolPanelSection(
          title: '透视类型',
          child: ToolSegmented<_PerspectiveMode>(
            values: _PerspectiveMode.values,
            value: _mode,
            labelOf: (m) => m.label,
            onChanged: _setMode,
          ),
        ),
        ToolPanelSection(
          title: '灭点',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _mode.points; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.s4),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _vpColors[i],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpace.s8),
                      Text('灭点 ${i + 1}', style: AppText.body14Strong),
                      const SizedBox(width: AppSpace.s8),
                      Expanded(
                        child: Text(
                          i < 2 ? '在视平线上，可左右拖动' : '控制竖线的汇聚，仰视在上、俯视在下',
                          maxLines: 2,
                          style: AppText.caption12,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpace.s4),
              Text('拖动灭点或视平线调整位置，让辅助线贴合画中物体的边线', style: AppText.caption12),
            ],
          ),
        ),
        ToolSwitchRow(
          label: '缩小画面',
          hint: '给画面外的灭点留出位置',
          value: _zoomOut,
          onChanged: (v) => setState(() => _zoomOut = v),
        ),
        ToolSliderRow(
          label: '辅助线数量',
          value: _density.toDouble(),
          min: 6,
          max: 24,
          divisions: 18,
          valueLabel: '$_density',
          onChanged: (v) => setState(() => _density = v.round()),
        ),
        ToolSliderRow(
          label: '不透明度',
          value: _opacity,
          min: 0.3,
          max: 1,
          valueLabel: '${(_opacity * 100).round()}%',
          onChanged: (v) => setState(() => _opacity = v),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            label: '恢复默认位置',
            icon: Icons.restart_alt_rounded,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.sm,
            onTap: _reset,
          ),
        ),
        const SizedBox(height: AppSpace.s20),
        const ToolTipCard(
          title: '透视的三条规律',
          text:
              '视平线就是眼睛的高度，所有水平面的灭点都在视平线上。一点透视时物体一个面正对画面，纵深的边线汇聚到一个灭点；'
              '两点透视时物体成角，两组水平边线分别汇聚到左右两个灭点，竖线保持垂直；仰视或俯视明显时竖线也会汇聚，形成三点透视。',
        ),
      ],
    );
  }
}

class _PerspectivePainter extends CustomPainter {
  _PerspectivePainter({
    required this.mapping,
    required this.horizon,
    required this.points,
    required this.density,
    required this.opacity,
    required this.active,
  });

  final _StageMapping mapping;
  final double horizon;
  final List<Offset> points;
  final int density;
  final double opacity;
  final int? active;

  @override
  void paint(Canvas canvas, Size size) {
    final stage = mapping.stageRect;
    final halo = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.25 * opacity)
      ..strokeWidth = 2.6;
    for (var i = 0; i < points.length; i++) {
      final vp = mapping.place(points[i]);
      final line = Paint()
        ..color = _vpColors[i].withValues(alpha: opacity)
        ..strokeWidth = 1.2;
      for (final direction in fanDirections(vp, mapping.imageRect, density)) {
        final segment = clipRay(vp, direction, stage);
        if (segment == null) {
          continue;
        }
        canvas
          ..drawLine(segment.$1, segment.$2, halo)
          ..drawLine(segment.$1, segment.$2, line);
      }
    }

    final y = mapping.place(Offset(0.5, horizon)).dy;
    final horizonPaint = Paint()
      ..color = AppColors.surface.withValues(alpha: opacity)
      ..strokeWidth = active == 3 ? 3 : 2;
    canvas
      ..drawLine(
        Offset(stage.left, y),
        Offset(stage.right, y),
        Paint()
          ..color = AppColors.ink.withValues(alpha: 0.4 * opacity)
          ..strokeWidth = 4,
      )
      ..drawLine(Offset(stage.left, y), Offset(stage.right, y), horizonPaint);
    _label(canvas, '视平线', Offset(stage.right - 8, y - 6), alignRight: true);

    for (var i = 0; i < points.length; i++) {
      final vp = mapping.place(points[i]);
      final radius = active == i ? 12.0 : 10.0;
      canvas
        ..drawCircle(vp, radius + 2, Paint()..color = AppColors.surface)
        ..drawCircle(vp, radius, Paint()..color = _vpColors[i])
        ..drawCircle(vp, 3, Paint()..color = AppColors.surface);
      _label(canvas, '灭点 ${i + 1}', vp + Offset(0, radius + 6), center: true);
    }
  }

  void _label(
    Canvas canvas,
    String text,
    Offset anchor, {
    bool alignRight = false,
    bool center = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: AppText.caption12Strong.copyWith(color: AppColors.onBrand),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final width = painter.width + 12;
    final height = painter.height + 4;
    final left = alignRight
        ? anchor.dx - width
        : (center ? anchor.dx - width / 2 : anchor.dx);
    final top = alignRight ? anchor.dy - height : anchor.dy;
    final rect = Rect.fromLTWH(left, top, width, height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(AppRadius.checkbox)),
      Paint()..color = AppColors.ink.withValues(alpha: 0.6),
    );
    painter.paint(canvas, rect.topLeft + const Offset(6, 2));
    painter.dispose();
  }

  @override
  bool shouldRepaint(covariant _PerspectivePainter oldDelegate) => true;
}
