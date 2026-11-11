import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/toolbox_dock_preferences.dart';

/// 小墨：一团颜料、一撮笔锋。所有尺寸与表情由矢量绘制，可复用于引导和空状态。
class ArtCompanionPortrait extends StatelessWidget {
  const ArtCompanionPortrait({
    this.size = 64,
    this.edge = ToolboxDockEdge.right,
    this.conceal = 0,
    this.blink = 0,
    this.glance = 0,
    this.happy = false,
    this.carried = false,
    super.key,
  });

  final double size;
  final ToolboxDockEdge edge;
  final double conceal;
  final double blink;
  final double glance;
  final bool happy;
  final bool carried;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: ArtCompanionPainter(
        edge: edge,
        conceal: conceal,
        blink: blink,
        glance: glance,
        happy: happy,
        carried: carried,
      ),
    ),
  );
}

class ArtCompanionPainter extends CustomPainter {
  const ArtCompanionPainter({
    required this.edge,
    required this.conceal,
    required this.blink,
    required this.glance,
    required this.happy,
    required this.carried,
  });

  final ToolboxDockEdge edge;
  final double conceal;
  final double blink;
  final double glance;
  final bool happy;
  final bool carried;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 64);
    // 不完全对称的圆团与向上挑起的笔锋，共同构成角色轮廓。
    final body = Path()
      ..moveTo(29, 8)
      ..cubicTo(32, 5, 39, 7, 42, 2)
      ..cubicTo(45, 8, 41, 11, 41, 11)
      ..cubicTo(56, 14, 62, 26, 60, 39)
      ..cubicTo(58, 54, 48, 62, 32, 61)
      ..cubicTo(14, 63, 3, 52, 3, 36)
      ..cubicTo(2, 21, 12, 9, 29, 8)
      ..close();
    canvas.drawShadow(body, AppColors.ink.withValues(alpha: 0.20), 3, false);
    canvas.drawPath(body, Paint()..color = AppColors.brand);
    canvas.save();
    canvas.clipPath(body);
    // 同一颜料的深浅面，不用发光或模糊包裹角色。
    final shade = Path()
      ..moveTo(3, 44)
      ..cubicTo(20, 59, 49, 60, 61, 36)
      ..lineTo(64, 64)
      ..lineTo(0, 64)
      ..close();
    canvas.drawPath(shade, Paint()..color = AppColors.brandDeep);
    canvas.drawOval(
      const Rect.fromLTWH(13, 13, 16, 7),
      Paint()..color = AppColors.brandTint.withValues(alpha: 0.48),
    );
    canvas.restore();
    canvas.drawPath(
      body,
      Paint()
        ..color = AppColors.onBrand.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // 贴边时把五官挪到露出的部分；四边均保持脸朝向画布内部。
    final inward = switch (edge) {
      ToolboxDockEdge.left => const Offset(1, 0),
      ToolboxDockEdge.right => const Offset(-1, 0),
      ToolboxDockEdge.top => const Offset(0, 1),
      ToolboxDockEdge.bottom => const Offset(0, -1),
    };
    final face = const Offset(32, 34) + inward * (conceal * 30);
    final compact = 1 - conceal * 0.6;
    canvas.save();
    canvas.translate(face.dx, face.dy);
    canvas.scale(compact);
    final eyePaint = Paint()..color = AppColors.onBrand;
    final ink = Paint()..color = AppColors.ink;
    final close = blink.clamp(0.0, 1.0);
    for (final x in [-8.0, 8.0]) {
      if (close > 0.88) {
        final lid = Path()
          ..moveTo(x - 4, -3)
          ..quadraticBezierTo(x, happy ? -6 : -1, x + 4, -3);
        canvas.drawPath(
          lid,
          Paint()
            ..color = AppColors.onBrand
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 2.5,
        );
      } else {
        canvas.save();
        canvas.translate(x, -3);
        canvas.scale(1, math.max(0.12, 1 - close));
        canvas.drawOval(const Rect.fromLTWH(-5.5, -7, 11, 14), eyePaint);
        final pupil = Offset(
          inward.dx * (1.2 + glance) + (carried ? 1 : 0),
          -0.5 + inward.dy * glance,
        );
        canvas.drawOval(
          Rect.fromCenter(center: pupil, width: 4.8, height: 7.2),
          ink,
        );
        canvas.drawCircle(pupil + const Offset(-0.8, -1.8), 0.9, eyePaint);
        canvas.restore();
      }
    }
    if (carried) {
      canvas.drawOval(const Rect.fromLTWH(-2.6, 7, 5.2, 6), ink);
    } else {
      final smile = Path()
        ..moveTo(-4, 7)
        ..quadraticBezierTo(0, happy ? 14 : 10, 4, 7);
      canvas.drawPath(
        smile,
        Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2,
      );
    }
    if (happy) {
      final cheek = Paint()..color = AppColors.brandTint;
      canvas.drawOval(const Rect.fromLTWH(-18, 4, 6, 3), cheek);
      canvas.drawOval(const Rect.fromLTWH(12, 4, 6, 3), cheek);
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(ArtCompanionPainter old) =>
      edge != old.edge ||
      conceal != old.conceal ||
      blink != old.blink ||
      glance != old.glance ||
      happy != old.happy ||
      carried != old.carried;
}
