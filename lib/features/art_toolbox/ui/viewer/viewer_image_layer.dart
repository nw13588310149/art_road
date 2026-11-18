import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../../../core/widgets/image_viewer_tools.dart';
import '../../logic/geometry.dart';
import '../../logic/image_ops.dart';
import 'viewer_tools_controller.dart';

/// 和工具箱「明度检查」同样的感知亮度权重（Rec.601）。
const _grayMatrix = <double>[
  0.299, 0.587, 0.114, 0, 0, //
  0.299, 0.587, 0.114, 0, 0, //
  0.299, 0.587, 0.114, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// 测量线的颜色与工具箱「比例测量」一致：A 段品牌紫，B 段琥珀。
const _segmentColors = <Color>[AppColors.brand, AppColors.warning];

/// 看图页里一张图的画面：处理后的像素、灰度、镜像，再叠上构图线、取色点和测量线。
/// 坐标系就是这张图，随看图页的缩放、平移、旋转一起走。
class ViewerImageLayer extends StatelessWidget {
  const ViewerImageLayer({
    required this.controller,
    required this.item,
    required this.image,
    required this.scale,
    super.key,
  });

  final ViewerToolsController controller;
  final ImageViewerItem item;
  final ui.Image image;
  final ValueListenable<double> scale;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final current = c.item?.index == item.index;
    Widget picture = RawImage(
      image: c.resultFor(item) ?? image,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
    );
    if (c.filter == ViewerFilter.gray) {
      picture = ColorFiltered(
        colorFilter: const ColorFilter.matrix(_grayMatrix),
        child: picture,
      );
    }
    if (c.mirrorX || c.mirrorY) {
      picture = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(
          c.mirrorX ? -1 : 1,
          c.mirrorY ? -1 : 1,
          1,
        ),
        child: picture,
      );
    }
    final marks = current && (c.pickAt != null || c.measurePoints.isNotEmpty);
    return Stack(
      fit: StackFit.expand,
      children: [
        picture,
        if (c.grid.isNotEmpty)
          CustomPaint(
            painter: _GridPainter(lines: c.grid.toSet(), scale: scale),
          ),
        if (marks)
          CustomPaint(
            painter: _MarksPainter(
              pick: c.pickAt == null ? null : c.visible(c.pickAt!),
              color: c.picked,
              points: [for (final p in c.measurePoints) c.visible(p)],
              scale: scale,
            ),
          ),
      ],
    );
  }
}

/// 白线加一圈半透明的深色边，白纸素描和深色画面上都看得清。
class _GridPainter extends CustomPainter {
  _GridPainter({required this.lines, required this.scale})
    : super(repaint: scale);

  final Set<ViewerGridLine> lines;
  final ValueListenable<double> scale;

  @override
  void paint(Canvas canvas, Size size) {
    final s = scale.value <= 0 ? 1.0 : scale.value;
    final halo = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.28)
      ..strokeWidth = 3 / s;
    final line = Paint()
      ..color = AppColors.surface.withValues(alpha: 0.9)
      ..strokeWidth = 1.2 / s;
    void draw(Offset a, Offset b) {
      canvas
        ..drawLine(a, b, halo)
        ..drawLine(a, b, line);
    }

    void split(List<double> fractions) {
      for (final t in fractions) {
        draw(Offset(size.width * t, 0), Offset(size.width * t, size.height));
        draw(Offset(0, size.height * t), Offset(size.width, size.height * t));
      }
    }

    if (lines.contains(ViewerGridLine.nine)) {
      split(evenFractions(3));
    }
    if (lines.contains(ViewerGridLine.quarters)) {
      split(evenFractions(2));
    }
    if (lines.contains(ViewerGridLine.diagonal)) {
      draw(Offset.zero, Offset(size.width, size.height));
      draw(Offset(size.width, 0), Offset(0, size.height));
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      !setEquals(old.lines, lines) || old.scale != scale;
}

class _MarksPainter extends CustomPainter {
  _MarksPainter({
    required this.pick,
    required this.color,
    required this.points,
    required this.scale,
  }) : super(repaint: scale);

  /// 相对图片 0–1 的位置。
  final Offset? pick;
  final RgbColor? color;
  final List<Offset> points;
  final ValueListenable<double> scale;

  @override
  void paint(Canvas canvas, Size size) {
    final s = scale.value <= 0 ? 1.0 : scale.value;
    Offset at(Offset p) => Offset(p.dx * size.width, p.dy * size.height);

    final box = [for (final p in points) at(p)];
    final segments = segmentsOf(box);
    for (var i = 0; i < segments.length; i++) {
      final (a, b) = segments[i];
      canvas
        ..drawLine(
          a,
          b,
          Paint()
            ..color = AppColors.surface
            ..strokeWidth = 5 / s
            ..strokeCap = StrokeCap.round,
        )
        ..drawLine(
          a,
          b,
          Paint()
            ..color = _segmentColors[i % _segmentColors.length]
            ..strokeWidth = 2.5 / s
            ..strokeCap = StrokeCap.round,
        );
      _label(canvas, String.fromCharCode(65 + i), (a + b) / 2, i, s);
    }
    for (var i = 0; i < box.length; i++) {
      canvas
        ..drawCircle(box[i], 8 / s, Paint()..color = AppColors.surface)
        ..drawCircle(
          box[i],
          6 / s,
          Paint()..color = _segmentColors[(i ~/ 2) % _segmentColors.length],
        );
    }

    final p = pick;
    if (p != null) {
      final center = at(p);
      final fill = color;
      canvas
        ..drawCircle(
          center,
          13 / s,
          Paint()..color = AppColors.ink.withValues(alpha: 0.35),
        )
        ..drawCircle(center, 11 / s, Paint()..color = AppColors.surface);
      if (fill != null) {
        canvas.drawCircle(center, 8 / s, Paint()..color = Color(fill.argb));
      }
    }
  }

  void _label(Canvas canvas, String text, Offset at, int index, double s) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: AppText.caption12Strong.copyWith(
          color: AppColors.onBrand,
          fontSize: 12 / s,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final bubble = Rect.fromCenter(
      center: at + Offset(0, -18 / s),
      width: painter.width + 12 / s,
      height: painter.height + 8 / s,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bubble, Radius.circular(4 / s)),
      Paint()..color = _segmentColors[index % _segmentColors.length],
    );
    painter
      ..paint(
        canvas,
        bubble.center - Offset(painter.width / 2, painter.height / 2),
      )
      ..dispose();
  }

  @override
  bool shouldRepaint(covariant _MarksPainter old) => true;
}
