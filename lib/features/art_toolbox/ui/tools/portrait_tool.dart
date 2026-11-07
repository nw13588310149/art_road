import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/toolbox_catalog.dart';
import '../../data/toolbox_image_source.dart';
import '../../logic/geometry.dart';
import '../widgets/contain_mapping.dart';
import '../widgets/image_tool_frame.dart';
import '../widgets/tool_panel.dart';

/// 头像比例：可拖动、缩放的三庭五眼框；眉线与鼻底线可拖动，量出实际的三庭比例。
class PortraitTool extends StatelessWidget {
  const PortraitTool({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ImageToolScaffold(
      tool: ArtTool.portrait,
      onBack: onBack,
      builder: (context, image) =>
          _PortraitBody(key: ValueKey(image.version), image: image),
    );
  }
}

enum _Handle { topLeft, topRight, bottomLeft, bottomRight, brow, nose, body }

class _PortraitBody extends StatefulWidget {
  const _PortraitBody({required this.image, super.key});

  final ToolboxImage image;

  @override
  State<_PortraitBody> createState() => _PortraitBodyState();
}

class _PortraitBodyState extends State<_PortraitBody> {
  static const _cornerHit = 28.0;
  static const _lineHit = 16.0;

  late Rect _frame = _defaultFrame();
  double _brow = 1 / 3;
  double _nose = 2 / 3;
  bool _eyes = true;
  bool _axis = true;
  _Handle? _handle;
  Offset? _lastUnit;

  /// 默认框：高为图片的 60%，宽高比约 0.72，水平居中。
  Rect _defaultFrame() {
    final aspect = widget.image.width / widget.image.height;
    const height = 0.6;
    final width = math.min(0.9, 0.72 * height / aspect);
    return Rect.fromLTWH(0.5 - width / 2, 0.2, width, height);
  }

  double get _browY => _frame.top + _frame.height * _brow;
  double get _noseY => _frame.top + _frame.height * _nose;

  _Handle? _hit(Offset local, ContainMapping mapping) {
    final corners = <_Handle, Offset>{
      _Handle.topLeft: _frame.topLeft,
      _Handle.topRight: _frame.topRight,
      _Handle.bottomLeft: _frame.bottomLeft,
      _Handle.bottomRight: _frame.bottomRight,
    };
    for (final entry in corners.entries) {
      if ((mapping.fromUnit(entry.value) - local).distance <= _cornerHit) {
        return entry.key;
      }
    }
    final box = Rect.fromPoints(
      mapping.fromUnit(_frame.topLeft),
      mapping.fromUnit(_frame.bottomRight),
    );
    final insideX = local.dx >= box.left - 8 && local.dx <= box.right + 24;
    if (insideX) {
      if ((mapping.fromUnit(Offset(0, _browY)).dy - local.dy).abs() <= _lineHit) {
        return _Handle.brow;
      }
      if ((mapping.fromUnit(Offset(0, _noseY)).dy - local.dy).abs() <= _lineHit) {
        return _Handle.nose;
      }
    }
    return box.contains(local) ? _Handle.body : null;
  }

  void _drag(Offset local, ContainMapping mapping) {
    final handle = _handle;
    final last = _lastUnit;
    final unit = mapping.toUnit(local);
    _lastUnit = unit;
    if (handle == null || last == null) {
      return;
    }
    const minW = 0.06;
    const minH = 0.08;
    setState(() {
      final f = _frame;
      switch (handle) {
        case _Handle.topLeft:
          _frame = Rect.fromLTRB(
            math.min(unit.dx, f.right - minW),
            math.min(unit.dy, f.bottom - minH),
            f.right,
            f.bottom,
          );
        case _Handle.topRight:
          _frame = Rect.fromLTRB(
            f.left,
            math.min(unit.dy, f.bottom - minH),
            math.max(unit.dx, f.left + minW),
            f.bottom,
          );
        case _Handle.bottomLeft:
          _frame = Rect.fromLTRB(
            math.min(unit.dx, f.right - minW),
            f.top,
            f.right,
            math.max(unit.dy, f.top + minH),
          );
        case _Handle.bottomRight:
          _frame = Rect.fromLTRB(
            f.left,
            f.top,
            math.max(unit.dx, f.left + minW),
            math.max(unit.dy, f.top + minH),
          );
        case _Handle.brow:
          _brow = ((unit.dy - f.top) / f.height).clamp(0.05, _nose - 0.05);
        case _Handle.nose:
          _nose = ((unit.dy - f.top) / f.height).clamp(_brow + 0.05, 0.95);
        case _Handle.body:
          final moved = f.shift(unit - last);
          final dx = moved.center.dx.clamp(0.0, 1.0) - moved.center.dx;
          final dy = moved.center.dy.clamp(0.0, 1.0) - moved.center.dy;
          _frame = moved.shift(Offset(dx, dy));
      }
    });
  }

  String _verdict(List<double> ratios) {
    final mean = ratios.reduce((a, b) => a + b) / 3;
    const names = ['上庭', '中庭', '下庭'];
    final notes = <String>[
      for (var i = 0; i < 3; i++)
        if (ratios[i] / mean > 1.08)
          '${names[i]}偏长'
        else if (ratios[i] / mean < 0.92)
          '${names[i]}偏短',
    ];
    return notes.isEmpty
        ? '三庭接近相等，符合常见比例'
        : '${notes.join('、')}，对照五官位置看看是否需要调整';
  }

  @override
  Widget build(BuildContext context) {
    return ImageToolLayout(stage: _buildStage, panel: _buildPanel);
  }

  Widget _buildStage(BuildContext context) {
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
              onPanStart: (details) {
                _handle = _hit(details.localPosition, mapping);
                _lastUnit = mapping.toUnit(details.localPosition);
              },
              onPanUpdate: (details) => _drag(details.localPosition, mapping),
              onPanEnd: (_) => setState(() => _handle = null),
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
                      painter: _PortraitPainter(
                        mapping: mapping,
                        frame: _frame,
                        brow: _brow,
                        nose: _nose,
                        eyes: _eyes,
                        axis: _axis,
                        active: _handle,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final ratios = facialThirds(_frame.top, _browY, _noseY, _frame.bottom);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToolPanelSection(
          title: '三庭比例',
          trailing: const Text('以上庭为 1'),
          child: ratios == null
              ? Text('拖动眉线与鼻底线后显示比例', style: AppText.body13)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('上庭 : 中庭 : 下庭', style: AppText.caption12),
                    const SizedBox(height: 2),
                    Text(
                      ratios.map((r) => r.toStringAsFixed(2)).join(' : '),
                      style: AppText.displayNumber(
                        size: 24,
                        color: AppColors.brand,
                      ),
                    ),
                    const SizedBox(height: AppSpace.s4),
                    Text(_verdict(ratios), style: AppText.body13),
                  ],
                ),
        ),
        Text(
          '先拖动方框四角，让上边对齐发际线、下边对齐下巴，左右贴住脸的两侧；再上下拖动眉线和鼻底线到实际位置。',
          style: AppText.caption12,
        ),
        const SizedBox(height: AppSpace.s16),
        ToolSwitchRow(
          label: '五眼竖线',
          hint: '把脸宽五等分，每份约一只眼宽',
          value: _eyes,
          onChanged: (v) => setState(() => _eyes = v),
        ),
        ToolSwitchRow(
          label: '中线',
          hint: '检查五官是否左右对称',
          value: _axis,
          onChanged: (v) => setState(() => _axis = v),
        ),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: '恢复三等分',
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                onTap: _brow == 1 / 3 && _nose == 2 / 3
                    ? null
                    : () => setState(() {
                        _brow = 1 / 3;
                        _nose = 2 / 3;
                      }),
              ),
            ),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: AppButton(
                label: '重置方框',
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                onTap: () => setState(() {
                  _frame = _defaultFrame();
                  _brow = 1 / 3;
                  _nose = 2 / 3;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s20),
        const ToolTipCard(
          title: '三庭五眼',
          text:
              '三庭：发际线到眉线、眉线到鼻底、鼻底到下巴，三段大致相等。'
              '五眼：脸宽约为五只眼睛的宽度，两眼之间约一只眼宽，外眼角到脸侧各约一只眼宽。'
              '另外，鼻翼宽约等于两内眼角的距离，嘴角大致落在两眼瞳孔的垂线上，耳朵上缘约齐眉、下缘约齐鼻底。',
        ),
        const SizedBox(height: AppSpace.s8),
        Text('常用参考比例，个体差异明显，写生时以对象为准', style: AppText.caption12),
      ],
    );
  }
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter({
    required this.mapping,
    required this.frame,
    required this.brow,
    required this.nose,
    required this.eyes,
    required this.axis,
    required this.active,
  });

  final ContainMapping mapping;
  final Rect frame;
  final double brow;
  final double nose;
  final bool eyes;
  final bool axis;
  final _Handle? active;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Rect.fromPoints(
      mapping.fromUnit(frame.topLeft),
      mapping.fromUnit(frame.bottomRight),
    );
    final browY = box.top + box.height * brow;
    final noseY = box.top + box.height * nose;
    final eyeY = browY + (noseY - browY) * 0.3;

    final halo = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.4)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    final line = Paint()
      ..color = AppColors.surface
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final thin = Paint()
      ..color = AppColors.surface.withValues(alpha: 0.85)
      ..strokeWidth = 1;
    final thinHalo = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.3)
      ..strokeWidth = 2.5;

    void dashed(Offset from, Offset to) {
      final total = (to - from).distance;
      if (total <= 0) {
        return;
      }
      final direction = (to - from) / total;
      for (var t = 0.0; t < total; t += 9) {
        final a = from + direction * t;
        final b = from + direction * math.min(total, t + 5);
        canvas
          ..drawLine(a, b, thinHalo)
          ..drawLine(a, b, thin);
      }
    }

    if (eyes) {
      for (final x in fiveEyeLines(box.left, box.right).skip(1).take(4)) {
        dashed(Offset(x, box.top), Offset(x, box.bottom));
      }
      final eyeWidth = box.width / 5;
      for (final column in const [1, 3]) {
        _label(
          canvas,
          '眼',
          Offset(box.left + eyeWidth * (column + 0.5), eyeY),
          center: true,
        );
      }
    }
    if (axis) {
      dashed(Offset(box.center.dx, box.top), Offset(box.center.dx, box.bottom));
    }
    dashed(Offset(box.left, eyeY), Offset(box.right, eyeY));

    canvas
      ..drawRect(box, halo)
      ..drawRect(box, line);
    for (final y in [browY, noseY]) {
      final strong = Paint()
        ..color = AppColors.brand
        ..strokeWidth = 2.5;
      canvas
        ..drawLine(Offset(box.left, y), Offset(box.right + 16, y), halo)
        ..drawLine(Offset(box.left, y), Offset(box.right + 16, y), strong)
        ..drawCircle(
          Offset(box.right + 16, y),
          7,
          Paint()..color = AppColors.surface,
        )
        ..drawCircle(Offset(box.right + 16, y), 5, Paint()..color = AppColors.brand);
    }
    final tick = Paint()
      ..color = AppColors.surface
      ..strokeWidth = 2;
    for (final t in const [1 / 3, 2 / 3]) {
      final y = box.top + box.height * t;
      canvas
        ..drawLine(Offset(box.left - 8, y), Offset(box.left, y), tick)
        ..drawLine(Offset(box.right, y), Offset(box.right + 6, y), tick);
    }

    for (final corner in [
      box.topLeft,
      box.topRight,
      box.bottomLeft,
      box.bottomRight,
    ]) {
      canvas
        ..drawCircle(corner, 8, Paint()..color = AppColors.ink.withValues(alpha: 0.4))
        ..drawCircle(corner, 6, Paint()..color = AppColors.surface);
    }

    _label(canvas, '上庭', Offset(box.left - 10, (box.top + browY) / 2), right: true);
    _label(canvas, '中庭', Offset(box.left - 10, (browY + noseY) / 2), right: true);
    _label(canvas, '下庭', Offset(box.left - 10, (noseY + box.bottom) / 2), right: true);
    _label(canvas, '发际线', Offset(box.right + 28, box.top));
    _label(canvas, '眉线', Offset(box.right + 28, browY));
    _label(canvas, '鼻底线', Offset(box.right + 28, noseY));
    _label(canvas, '下巴', Offset(box.right + 28, box.bottom));
  }

  void _label(
    Canvas canvas,
    String text,
    Offset anchor, {
    bool right = false,
    bool center = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: AppText.caption12Strong.copyWith(color: AppColors.onBrand),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final width = painter.width + 10;
    final height = painter.height + 4;
    final left = right
        ? anchor.dx - width
        : (center ? anchor.dx - width / 2 : anchor.dx);
    final rect = Rect.fromLTWH(left, anchor.dy - height / 2, width, height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(AppRadius.checkbox)),
      Paint()..color = AppColors.ink.withValues(alpha: 0.6),
    );
    painter.paint(canvas, rect.topLeft + const Offset(5, 2));
    painter.dispose();
  }

  @override
  bool shouldRepaint(covariant _PortraitPainter oldDelegate) => true;
}
