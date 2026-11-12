import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/toolbox_dock_preferences.dart';

/// 小画头顶调色盘上的三团颜料，也是笔尖、涂鸦和拖动笔触的颜色。
const companionPaints = <Color>[
  Color(0xFFFF6B5E),
  Color(0xFFFFBE2E),
  Color(0xFF2FB8F0),
];

enum CompanionMood { calm, happy, joy, surprised, focus }

enum CompanionDoodle { heart, star, swirl }

/// 小画某一帧的姿态。长度按 64 设计尺寸计，`look`、`tilt` 按屏幕方向给出。
@immutable
class CompanionPose {
  const CompanionPose({
    this.conceal = 0,
    this.peek = 0,
    this.blink = 0,
    this.look = Offset.zero,
    this.mood = CompanionMood.calm,
    this.squash = 0,
    this.tilt = 0,
    this.lift = 0,
    this.scale = 1,
    this.cheer = 0,
    this.wave = 0,
    this.swing = 0,
    this.dip = 0,
    this.dipPaint = 0,
    this.dabWobble = 0,
    this.doodle = CompanionDoodle.heart,
    this.brushOut = 0,
    this.stroke = 0,
    this.markFade = 0,
    this.sparkle = 0,
    this.paint = 0,
  });

  /// 0 完整露出，0.5 露出约一半，2/3 只在边缘探出脑袋。
  final double conceal;

  /// 贴边时额外探出身子的程度。
  final double peek;
  final double blink;
  final Offset look;
  final CompanionMood mood;

  /// 正值压扁，负值拉长。
  final double squash;
  final double tilt;
  final double lift;
  final double scale;

  /// 双手举起（展开面板、被拎起来）。
  final double cheer;

  /// 空着的手挥动，`swing` 为摆动相位。
  final double wave;
  final double swing;

  /// 握笔的手伸到帽子上蘸 `dipPaint` 号颜料。
  final double dip;
  final int dipPaint;
  final double dabWobble;

  /// 伸笔到画面里涂鸦：`brushOut` 伸出程度，`stroke` 已画比例。
  final CompanionDoodle doodle;
  final double brushOut;
  final double stroke;
  final double markFade;

  /// 一圈小星光的进度，0 表示没有。
  final double sparkle;

  /// 笔尖当前蘸着的颜料。
  final int paint;

  @override
  bool operator ==(Object other) =>
      other is CompanionPose &&
      other.conceal == conceal &&
      other.peek == peek &&
      other.blink == blink &&
      other.look == look &&
      other.mood == mood &&
      other.squash == squash &&
      other.tilt == tilt &&
      other.lift == lift &&
      other.scale == scale &&
      other.cheer == cheer &&
      other.wave == wave &&
      other.swing == swing &&
      other.dip == dip &&
      other.dipPaint == dipPaint &&
      other.dabWobble == dabWobble &&
      other.doodle == doodle &&
      other.brushOut == brushOut &&
      other.stroke == stroke &&
      other.markFade == markFade &&
      other.sparkle == sparkle &&
      other.paint == paint;

  @override
  int get hashCode => Object.hashAll([
    conceal,
    peek,
    blink,
    look,
    mood,
    squash,
    tilt,
    lift,
    scale,
    cheer,
    wave,
    swing,
    dip,
    dipPaint,
    dabWobble,
    doodle,
    brushOut,
    stroke,
    markFade,
    sparkle,
    paint,
  ]);
}

/// 小画：戴调色盘贝雷帽、握着水粉笔的软糯小画童。全部矢量绘制，可用于入口、面板和形象板。
class ArtCompanionPortrait extends StatelessWidget {
  const ArtCompanionPortrait({
    this.size = 64,
    this.edge = ToolboxDockEdge.right,
    this.pose = const CompanionPose(),
    super.key,
  });

  final double size;
  final ToolboxDockEdge edge;
  final CompanionPose pose;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: ArtCompanionPainter(edge: edge, pose: pose),
    ),
  );
}

class ArtCompanionPainter extends CustomPainter {
  const ArtCompanionPainter({required this.edge, required this.pose});

  final ToolboxDockEdge edge;
  final CompanionPose pose;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 64);
    // 贴右边时整体镜像，握笔的手始终朝向画面内侧。
    final mirror = edge == ToolboxDockEdge.right;
    if (mirror) {
      canvas.translate(64, 0);
      canvas.scale(-1, 1);
    }
    _Rig(edge, pose, mirror: mirror).paint(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(ArtCompanionPainter old) =>
      edge != old.edge || pose != old.pose;
}

const _lilac = Color(0xFFBDB0FF);
const _violet = Color(0xFF7F6CFF);
const _indigo = Color(0xFF5A42EC);
const _deep = Color(0xFF4129C4);
const _outline = Color(0xFF3A22B0);
const _arm = Color(0xFF8C7BFF);
const _bounce = Color(0xFFFFA6D2);
const _ink = Color(0xFF221651);
const _iris = Color(0xFF5B48B8);
const _mouth = Color(0xFF3B1C5E);
const _tongue = Color(0xFFFF7FA2);
const _blush = Color(0xFFFF8DB6);
const _paletteTop = Color(0xFFFFF4DC);
const _paletteSide = Color(0xFFF2D7A2);
const _paletteUnder = Color(0xFFD6A963);
const _paletteRim = Color(0xFFB4843F);
const _handle = Color(0xFF2B2366);
const _handleLight = Color(0xFF574DB0);
const _bristle = Color(0xFFF6E5C1);
const _white = Color(0xFFFFFFFF);

const _faceHome = Offset(30, 38.5);
const _hatHome = Offset(32, 16.4);
const _hatTilt = 0.2;
const _dabs = [Offset(-2.8, -1.3), Offset(4.3, 1.4), Offset(10.2, -1.5)];
const _dabRadius = [2.9, 2.7, 2.4];
const _brushReach = 16.8 * _brushScale;
const _brushScale = 0.95;

// 手臂是贴在身体两侧的短小圆手，举起时才伸出轮廓。
const _freeShoulder = Offset(9.8, 45.2);
const _freeShoulderUp = Offset(12.4, 38);
const _freeRest = Offset(7.2, 48.8);
const _freeUp = Offset(6.8, 29.4);
const _freeWave = Offset(5.2, 26.4);
const _brushShoulder = Offset(50.2, 45.2);
const _brushShoulderUp = Offset(47.6, 38);
const _brushRest = Offset(52.8, 48.8);
const _brushUp = Offset(53.2, 29.8);

final Path _body = Path()
  ..moveTo(30, 17.5)
  ..cubicTo(43.8, 17.5, 54, 27.6, 54, 40.6)
  ..cubicTo(54, 53.6, 45.2, 60, 30, 60)
  ..cubicTo(14.8, 60, 6, 53.6, 6, 40.6)
  ..cubicTo(6, 27.6, 16.2, 17.5, 30, 17.5)
  ..close();

final Path _palette = Path()
  ..moveTo(-15.6, 0.4)
  ..cubicTo(-15.6, -4.6, -7.8, -5.9, 0.4, -5.7)
  ..cubicTo(9.2, -5.5, 15.6, -3.5, 15.6, 0.4)
  ..cubicTo(15.6, 4.4, 8.6, 5.5, 1.2, 5.3)
  ..cubicTo(-3, 5.2, -5.4, 4.2, -7.4, 3.1)
  ..cubicTo(-9.4, 2.1, -10.6, 4.5, -12.6, 4.3)
  ..cubicTo(-14.7, 4.1, -15.6, 2.6, -15.6, 0.4)
  ..close();

final Path _tuft = Path()
  ..moveTo(8.8, -2.1)
  ..cubicTo(11.6, -3, 14.7, -1.6, 16.8, 0)
  ..cubicTo(14.7, 1.6, 11.6, 3, 8.8, 2.1)
  ..close();

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _smooth(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

double _lerpAngle(double a, double b, double t) {
  var d = (b - a) % (math.pi * 2);
  if (d > math.pi) d -= math.pi * 2;
  if (d < -math.pi) d += math.pi * 2;
  return a + d * t;
}

Offset _dir(double angle) => Offset(math.cos(angle), math.sin(angle));

Paint _line(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// 只含平移、旋转、缩放的二维变换，同时用于画布与关键点。
class _Frame {
  const _Frame(this.a, this.b, this.c, this.d, this.e, this.f);

  static const identity = _Frame(1, 0, 0, 1, 0, 0);

  final double a, b, c, d, e, f;

  _Frame translate(double x, double y) =>
      _Frame(a, b, c, d, a * x + c * y + e, b * x + d * y + f);

  _Frame scale(double sx, double sy) =>
      _Frame(a * sx, b * sx, c * sy, d * sy, e, f);

  _Frame rotate(double r) {
    final cs = math.cos(r);
    final sn = math.sin(r);
    return _Frame(
      a * cs + c * sn,
      b * cs + d * sn,
      c * cs - a * sn,
      d * cs - b * sn,
      e,
      f,
    );
  }

  Offset map(Offset p) =>
      Offset(a * p.dx + c * p.dy + e, b * p.dx + d * p.dy + f);

  Float64List get storage =>
      Float64List.fromList([a, b, 0, 0, c, d, 0, 0, 0, 0, 1, 0, e, f, 0, 1]);
}

/// 一次绘制用到的骨架：贴边推出量、转头、帽子和两只手的位置。
class _Rig {
  _Rig(this.edge, this.pose, {required bool mirror})
    : side = edge == ToolboxDockEdge.left || edge == ToolboxDockEdge.right,
      look = mirror ? Offset(-pose.look.dx, pose.look.dy) : pose.look,
      tilt = mirror ? -pose.tilt : pose.tilt {
    inward = switch (edge) {
      ToolboxDockEdge.top => const Offset(0, 1),
      ToolboxDockEdge.bottom => const Offset(0, -1),
      _ => const Offset(1, 0),
    };
    final extent = switch (edge) {
      ToolboxDockEdge.top => 60.0,
      ToolboxDockEdge.bottom => 58.0,
      _ => 54.0,
    };
    final allowance = edge == ToolboxDockEdge.bottom ? 10.0 : 0.0;
    final c = pose.conceal.clamp(0.0, 1.0);
    final visible = c <= 0.5
        ? _lerp(64, 30, c / 0.5)
        : _lerp(30, 21, ((c - 0.5) * 6).clamp(0.0, 1.0));
    final restingPush = math.max(0.0, extent - visible - allowance);
    push = math.max(0.0, restingPush - pose.peek * 10);
    grip = _smooth((push - 3) / 11);
    // 涂鸦固定在静止时身体之外，探身不会带着画好的笔迹移动。
    doodleDepth = math.min(50.0, extent - restingPush + 18);

    final maxTurn = side ? 14.0 : 10.0;
    final targetDepth = edge == ToolboxDockEdge.top ? 10.0 : 11.0;
    turn = (targetDepth + push - _depth(_faceHome)).clamp(0.0, maxTurn);
    final turnRatio = turn / maxTurn;
    faceCenter = _faceHome + inward * turn;
    faceCompress = 1 - 0.22 * turnRatio;
    hatCenter =
        _hatHome +
        inward *
            (turn *
                switch (edge) {
                  ToolboxDockEdge.top => 0.0,
                  ToolboxDockEdge.bottom => 0.4,
                  _ => 0.5,
                });
    hatAngle = _hatTilt + (side ? 0.16 * turnRatio : 0);

    final squash = pose.squash;
    // 侧边偷看时上半身朝画面里探一点。
    final lean = side ? 0.1 * grip : 0.0;
    body = _Frame.identity
        .translate(-inward.dx * push, -inward.dy * push - pose.lift)
        .translate(30, 40)
        .rotate(tilt + lean)
        .translate(-30, -40)
        .translate(30, 60)
        .scale((1 + squash * 0.6) * pose.scale, (1 - squash * 0.7) * pose.scale)
        .translate(-30, -60);
    hat = body.translate(hatCenter.dx, hatCenter.dy).rotate(hatAngle);
    faceAlong = _along(body.map(faceCenter));
  }

  final ToolboxDockEdge edge;
  final CompanionPose pose;
  final bool side;
  final Offset look;
  final double tilt;
  late final Offset inward;
  late final double push;
  late final double grip;
  late final double doodleDepth;
  late final double turn;
  late final Offset faceCenter;
  late final double faceCompress;
  late final Offset hatCenter;
  late final double hatAngle;
  late final _Frame body;
  late final _Frame hat;
  late final double faceAlong;

  Color get paintColor => companionPaints[pose.paint % companionPaints.length];

  /// 贴边坐标：`u` 沿着边，`v` 为离开屏幕边缘的深度。
  Offset _at(double u, double v) => switch (edge) {
    ToolboxDockEdge.top => Offset(u, v),
    ToolboxDockEdge.bottom => Offset(u, 64 - v),
    _ => Offset(v, u),
  };

  double _depth(Offset p) => switch (edge) {
    ToolboxDockEdge.top => p.dy,
    ToolboxDockEdge.bottom => 64 - p.dy,
    _ => p.dx,
  };

  double _along(Offset p) => side ? p.dy : p.dx;

  void paint(Canvas canvas) {
    _paintGroundShadow(canvas);
    _paintMark(canvas);
    canvas.save();
    canvas.transform(body.storage);
    _paintBody(canvas);
    _paintFace(canvas);
    canvas.restore();
    canvas.save();
    canvas.transform(hat.storage);
    _paintHat(canvas);
    canvas.restore();
    _paintFreeHand(canvas);
    _paintBrushHand(canvas);
    _paintSparkles(canvas);
  }

  void _paintGroundShadow(Canvas canvas) {
    final alpha = 0.16 * (1 - grip) * (1 - (pose.lift / 14).clamp(0.0, 0.7));
    if (alpha <= 0.01) return;
    final width = 36 * pose.scale * (1 + pose.squash * 0.5) - pose.lift;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(30 - inward.dx * push, 61.2),
        width: width,
        height: 4.6,
      ),
      Paint()
        ..color = _ink.withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
    );
  }

  void _paintBody(Canvas canvas) {
    canvas.drawShadow(_body, _ink.withValues(alpha: 0.35), 2.5, false);
    canvas.drawPath(
      _body,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(21, 27),
          40,
          const [_lilac, _violet, _indigo, _deep],
          const [0, 0.36, 0.78, 1],
        ),
    );
    canvas.save();
    canvas.clipPath(_body);
    // 地面反上来的暖光，让颜料团像软软的实物。
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(33, 63.5), width: 46, height: 14),
      Paint()
        ..color = _bounce.withValues(alpha: 0.42)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: hatCenter + const Offset(1.5, 6.2),
        width: 27,
        height: 6.5,
      ),
      Paint()
        ..color = _deep.withValues(alpha: 0.42)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
    );
    canvas.restore();
    canvas.save();
    canvas.translate(17.2, 28.4);
    canvas.rotate(-0.62);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 12, height: 6.4),
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, 6, [
          _white.withValues(alpha: 0.8),
          _white.withValues(alpha: 0),
        ]),
    );
    canvas.restore();
    canvas.drawCircle(
      const Offset(13.6, 34.2),
      1.1,
      Paint()..color = _white.withValues(alpha: 0.75),
    );
    canvas.drawPath(_body, _line(_outline.withValues(alpha: 0.55), 1.1));
  }

  void _paintFace(Canvas canvas) {
    canvas.save();
    canvas.translate(faceCenter.dx, faceCenter.dy);
    if (side) {
      canvas.scale(faceCompress, 1);
    } else {
      canvas.scale(1, faceCompress);
    }
    final shift = Offset(look.dx * 1.9, look.dy * 1.5);
    final mood = pose.mood;
    final blush = switch (mood) {
      CompanionMood.happy || CompanionMood.joy => 0.85,
      CompanionMood.focus => 0.7,
      _ => 0.58,
    };
    for (final s in [-1.0, 1.0]) {
      _paintCheek(canvas, Offset(s * 13.4, 5.4) + shift * 0.6, blush);
    }
    for (final s in [-1.0, 1.0]) {
      _paintEye(canvas, Offset(s * 8.4, -1) + shift);
    }
    _paintMouth(canvas, const Offset(0, 7.4) + shift * 0.6);
    canvas.restore();
  }

  void _paintCheek(Canvas canvas, Offset center, double strength) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1, 0.62);
    canvas.drawCircle(
      Offset.zero,
      4.8,
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, 4.8, [
          _blush.withValues(alpha: strength),
          _blush.withValues(alpha: 0),
        ]),
    );
    canvas.restore();
  }

  void _paintEye(Canvas canvas, Offset c) {
    final mood = pose.mood;
    if (mood == CompanionMood.joy) {
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - 3.8, c.dy + 1.4)
          ..quadraticBezierTo(c.dx, c.dy - 3.8, c.dx + 3.8, c.dy + 1.4),
        _line(_ink, 2.3),
      );
      return;
    }
    final big = mood == CompanionMood.surprised ? 1.12 : 1.0;
    final squint = mood == CompanionMood.focus ? 0.82 : 1.0;
    final height = 10.6 * big * squint * (1 - pose.blink.clamp(0.0, 1.0));
    if (height < 2.4) {
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - 3.6, c.dy)
          ..quadraticBezierTo(c.dx, c.dy + 2.8, c.dx + 3.6, c.dy),
        _line(_ink, 2.1),
      );
      return;
    }
    final width = 8.2 * big;
    final rect = Rect.fromCenter(center: c, width: width, height: height);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          const [_ink, _ink, _iris],
          const [0, 0.5, 1],
        ),
    );
    final k = height / 10.6;
    final glint = c - look * 0.5;
    canvas.drawCircle(
      glint + Offset(-1.5 * big, -2.5 * k),
      2.25 * big * math.min(1, k * 1.2),
      Paint()..color = _white,
    );
    canvas.drawCircle(
      glint + Offset(1.9 * big, 2.6 * k),
      1.0 * big * math.min(1, k * 1.4),
      Paint()..color = _white.withValues(alpha: 0.85),
    );
  }

  void _paintMouth(Canvas canvas, Offset c) {
    switch (pose.mood) {
      case CompanionMood.calm:
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - 3, c.dy - 0.4)
            ..quadraticBezierTo(c.dx, c.dy + 2.8, c.dx + 3, c.dy - 0.4),
          _line(_mouth, 1.8),
        );
      case CompanionMood.happy:
      case CompanionMood.joy:
        final joy = pose.mood == CompanionMood.joy;
        final half = joy ? 4.8 : 4.0;
        final depth = joy ? 6.2 : 5.0;
        final top = c.dy - 1.2;
        final mouth = Path()
          ..moveTo(c.dx - half, top)
          ..quadraticBezierTo(c.dx, top + 0.9, c.dx + half, top)
          ..cubicTo(
            c.dx + half,
            top + depth * 1.2,
            c.dx - half,
            top + depth * 1.2,
            c.dx - half,
            top,
          )
          ..close();
        canvas.drawPath(mouth, Paint()..color = _mouth);
        canvas.save();
        canvas.clipPath(mouth);
        canvas.drawCircle(
          Offset(c.dx, top + depth + 0.6),
          half * 0.7,
          Paint()..color = _tongue,
        );
        canvas.restore();
      case CompanionMood.surprised:
        final rect = Rect.fromCenter(
          center: c + const Offset(0, 1),
          width: 3.8,
          height: 4.8,
        );
        canvas.drawOval(rect, Paint()..color = _mouth);
        canvas.save();
        canvas.clipPath(Path()..addOval(rect));
        canvas.drawCircle(rect.bottomCenter, 1.6, Paint()..color = _tongue);
        canvas.restore();
      case CompanionMood.focus:
        canvas.drawOval(
          Rect.fromCenter(
            center: c + const Offset(1.7, 2.2),
            width: 2.8,
            height: 2.8,
          ),
          Paint()..color = _tongue,
        );
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - 2.6, c.dy + 0.2)
            ..quadraticBezierTo(c.dx, c.dy + 1.8, c.dx + 2.8, c.dy + 0.4),
          _line(_mouth, 1.7),
        );
    }
  }

  void _paintHat(Canvas canvas) {
    canvas.save();
    canvas.translate(0, 1.9);
    canvas.drawPath(_palette, Paint()..color = _paletteUnder);
    canvas.restore();
    canvas.drawPath(
      _palette,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(-8, -6),
          const Offset(6, 6),
          const [_paletteTop, _paletteSide],
        ),
    );
    canvas.drawPath(_palette, _line(_paletteRim.withValues(alpha: 0.7), 0.8));
    // 拇指孔里透出小画自己的颜色。
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-10, -0.4), width: 4.8, height: 2.7),
      Paint()..color = _indigo,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-10, -0.4), width: 4.8, height: 2.7),
      _line(_paletteRim.withValues(alpha: 0.8), 0.7),
    );
    final wobble = pose.dabWobble <= 0 || pose.dabWobble >= 1
        ? 0.0
        : math.sin(pose.dabWobble * math.pi * 3) * (1 - pose.dabWobble);
    for (var i = 0; i < _dabs.length; i++) {
      final w = i == pose.dipPaint ? wobble : 0.0;
      _paintDab(canvas, _dabs[i], _dabRadius[i], companionPaints[i], w);
    }
  }

  void _paintDab(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double wobble,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1 + wobble * 0.28, 1 - wobble * 0.22);
    final shade = Color.lerp(color, _ink, 0.28)!;
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, 0.55),
        width: radius * 2.3,
        height: radius * 1.7,
      ),
      Paint()..color = shade,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: radius * 2.3,
        height: radius * 1.65,
      ),
      Paint()..color = color,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-radius * 0.38, -radius * 0.3),
        width: radius * 0.8,
        height: radius * 0.48,
      ),
      Paint()..color = _white.withValues(alpha: 0.85),
    );
    canvas.restore();
  }

  Offset _dabTip(int index) {
    final dab = _dabs[index % _dabs.length];
    return hat.map(dab + const Offset(0, -0.4));
  }

  Offset get _across => Offset(inward.dy.abs(), inward.dx.abs());

  /// 身体在本地高度 [y] 处的半宽，按上下两段椭圆近似。
  static double _halfWidthAt(double y) {
    final k = ((y - 39.5) / (y < 39.5 ? 22 : 20.5)).clamp(-1.0, 1.0);
    return 24 * math.sqrt(1 - k * k);
  }

  /// 扒边时两只手的位置：侧边贴在脸的上下，上下边贴在身体两侧轮廓。
  (Offset, Offset) _gripSpots() {
    const depth = 3.4;
    switch (edge) {
      case ToolboxDockEdge.bottom:
        final w = _halfWidthAt(64 - depth - push) - 1.6;
        return (_at(30 - w, depth), _at(30 + w, depth));
      case ToolboxDockEdge.top:
        final w = _halfWidthAt(depth + push) - 1.6;
        return (_at(30 - w, depth), _at(30 + w, depth));
      default:
        return (_at(faceAlong - 12.5, depth), _at(faceAlong + 13.5, depth));
    }
  }

  void _paintFreeHand(Canvas canvas) {
    final cheer = pose.cheer.clamp(0.0, 1.0);
    final wave = pose.wave.clamp(0.0, 1.0);
    final swing = pose.swing;
    var held = Offset.lerp(_freeRest, _freeUp, cheer)!;
    held = Offset.lerp(
      held,
      _freeWave + Offset(swing * 2.4, -swing.abs() * 0.7),
      wave,
    )!;
    final shoulder = Offset.lerp(
      _freeShoulder,
      _freeShoulderUp,
      math.max(cheer, wave),
    )!;
    final lifted =
        _gripSpots().$1 +
        inward * (wave * 7) +
        _across * ((swing * 2.6 - 2) * wave);
    final hand = Offset.lerp(body.map(held), lifted, grip)!;
    _paintArm(
      canvas,
      Offset.lerp(body.map(shoulder), hand, grip)!,
      hand,
      mitten: grip * (1 - wave),
    );
  }

  void _paintBrushHand(Canvas canvas) {
    final cheer = pose.cheer.clamp(0.0, 1.0);
    final held = Offset.lerp(_brushRest, _brushUp, cheer)!;
    final heldAngle = _lerp(-1.3, -0.62, cheer) + tilt;
    final gripAngle = switch (edge) {
      ToolboxDockEdge.bottom => -math.pi / 2 + 0.55,
      ToolboxDockEdge.top => math.pi / 2 - 0.55,
      _ => 0.9,
    };
    var hand = Offset.lerp(body.map(held), _gripSpots().$2, grip)!;
    var angle = _lerpAngle(heldAngle, gripAngle, grip);

    if (pose.dip > 0) {
      const dipAngle = -1.92;
      final reach = _brushReach * pose.scale;
      final dipHand = _dabTip(pose.dipPaint) - _dir(dipAngle) * reach;
      final t = _smooth(pose.dip);
      hand = Offset.lerp(hand, dipHand, t)!;
      angle = _lerpAngle(angle, dipAngle, t);
    }
    if (pose.brushOut > 0) {
      final tip = _doodleTip();
      final doodleAngle = switch (edge) {
        ToolboxDockEdge.bottom => -math.pi / 2 + 0.45,
        ToolboxDockEdge.top => math.pi / 2 - 0.45,
        _ => 0.62,
      };
      final reach = _brushReach * pose.scale;
      final t = _smooth(pose.brushOut);
      hand = Offset.lerp(hand, tip - _dir(doodleAngle) * reach, t)!;
      angle = _lerpAngle(angle, doodleAngle, t);
    }
    _paintBrush(canvas, hand, angle);
    final shoulder = Offset.lerp(
      _brushShoulder,
      _brushShoulderUp,
      math.max(cheer, pose.dip),
    )!;
    _paintArm(
      canvas,
      Offset.lerp(body.map(shoulder), hand, grip)!,
      hand,
      mitten: grip * (1 - pose.brushOut) * (1 - pose.dip),
    );
  }

  /// [mitten] 越大，手越像扒在屏幕边上的小手套：沿边拉长、带指缝和投影。
  void _paintArm(
    Canvas canvas,
    Offset shoulder,
    Offset hand, {
    required double mitten,
  }) {
    final width = 6.2 * pose.scale;
    final reach = shoulder - hand;
    final length = reach.distance;
    final from = length > 8.5 ? hand + reach / length * 8.5 : shoulder;
    final outline = _outline.withValues(alpha: 0.7);
    if ((from - hand).distance > 0.3) {
      canvas.drawLine(from, hand, _line(outline, width + 1.5));
      canvas.drawLine(from, hand, _line(_arm, width));
    }
    final m = mitten.clamp(0.0, 1.0);
    final alongSize = _lerp(width, 8.8, m);
    final depthSize = _lerp(width, 6.6, m);
    final rect = Rect.fromCenter(
      center: hand,
      width: side ? depthSize : alongSize,
      height: side ? alongSize : depthSize,
    );
    if (m > 0.05) {
      canvas.drawOval(
        rect.shift(inward * 1.4),
        Paint()
          ..color = _ink.withValues(alpha: 0.28 * m)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
      );
    }
    canvas.drawOval(rect.inflate(0.75), Paint()..color = outline);
    canvas.drawOval(
      rect,
      Paint()..color = Color.lerp(_arm, const Color(0xFFA394FF), m)!,
    );
    canvas.drawCircle(
      hand + Offset(-1.1, -1.3) * pose.scale,
      1.05 * pose.scale,
      Paint()..color = _white.withValues(alpha: 0.5),
    );
    if (m > 0.05) {
      // 指尖勾住屏幕边缘。
      final paint = _line(_outline.withValues(alpha: 0.75 * m), 0.75);
      for (final s in [-1.7, 0.0, 1.7]) {
        final base = hand + _across * s;
        canvas.drawLine(base - inward * 3.1, base - inward * 1.4, paint);
      }
    }
  }

  void _paintBrush(Canvas canvas, Offset hand, double angle) {
    canvas.save();
    canvas.translate(hand.dx, hand.dy);
    canvas.rotate(angle);
    canvas.scale(_brushScale * pose.scale);
    canvas.drawRRect(
      RRect.fromLTRBR(-8.4, -1.3, 6.2, 1.3, const Radius.circular(1.3)),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, -1.3),
          const Offset(0, 1.3),
          const [_handleLight, _handle],
        ),
    );
    canvas.drawRect(
      const Rect.fromLTRB(5.6, -1.75, 9.2, 1.75),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, -1.75),
          const Offset(0, 1.75),
          const [Color(0xFFF7F8FC), Color(0xFFA6ADC4)],
        ),
    );
    canvas.drawPath(_tuft, Paint()..color = _bristle);
    canvas.save();
    canvas.clipPath(_tuft);
    canvas.drawPath(
      Path()
        ..moveTo(12.2, -3.2)
        ..quadraticBezierTo(11.2, 0, 12.6, 3.2)
        ..lineTo(18, 3.2)
        ..lineTo(18, -3.2)
        ..close(),
      Paint()..color = paintColor,
    );
    canvas.restore();
    canvas.drawLine(
      const Offset(12.9, -0.9),
      const Offset(15.4, -0.35),
      _line(_white.withValues(alpha: 0.6), 0.6),
    );
    canvas.restore();
  }

  Path _doodlePath() {
    final c = _at(faceAlong + 3, doodleDepth);
    switch (pose.doodle) {
      case CompanionDoodle.heart:
        return Path()
          ..moveTo(c.dx, c.dy + 5.6)
          ..cubicTo(c.dx - 3, c.dy + 3, c.dx - 6.6, c.dy, c.dx - 6, c.dy - 2.8)
          ..cubicTo(
            c.dx - 5.4,
            c.dy - 6.2,
            c.dx - 1.2,
            c.dy - 6.2,
            c.dx,
            c.dy - 2.6,
          )
          ..cubicTo(
            c.dx + 1.2,
            c.dy - 6.2,
            c.dx + 5.4,
            c.dy - 6.2,
            c.dx + 6,
            c.dy - 2.8,
          )
          ..cubicTo(c.dx + 6.6, c.dy, c.dx + 3, c.dy + 3, c.dx, c.dy + 5.6);
      case CompanionDoodle.star:
        final path = Path();
        for (var i = 0; i <= 10; i++) {
          final r = i.isEven ? 6.4 : 2.8;
          final a = -math.pi / 2 + i * math.pi / 5;
          final p = c + _dir(a) * r;
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        return path;
      case CompanionDoodle.swirl:
        final path = Path();
        for (var i = 0; i <= 36; i++) {
          final t = i / 36;
          final p =
              c + _dir(-math.pi / 2 + t * math.pi * 3.4) * (6.4 - t * 5.6);
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        return path;
    }
  }

  ui.PathMetric? _metricOf(Path path) {
    final metrics = path.computeMetrics().iterator;
    return metrics.moveNext() ? metrics.current : null;
  }

  Offset _doodleTip() {
    final metric = _metricOf(_doodlePath());
    if (metric == null) return _at(faceAlong, doodleDepth);
    return metric
            .getTangentForOffset(metric.length * pose.stroke.clamp(0.0, 1.0))
            ?.position ??
        _at(faceAlong, doodleDepth);
  }

  void _paintMark(Canvas canvas) {
    if (pose.stroke <= 0 || pose.markFade >= 1) return;
    final path = _doodlePath();
    final metric = _metricOf(path);
    if (metric == null) return;
    final drawn = metric.extractPath(
      0,
      metric.length * pose.stroke.clamp(0.0, 1.0),
    );
    final alpha = 1 - pose.markFade.clamp(0.0, 1.0);
    canvas.drawPath(drawn, _line(paintColor.withValues(alpha: alpha), 2.4));
    final fade = pose.markFade;
    if (fade > 0 && fade < 0.7) {
      final size = 2.4 * math.sin(math.pi * fade / 0.7);
      final center = path.getBounds().center;
      _twinkle(canvas, center + const Offset(7.6, -6.4), size, paintColor);
      _twinkle(canvas, center + const Offset(-7, 5.4), size * 0.7, _violet);
    }
  }

  void _paintSparkles(Canvas canvas) {
    final t = pose.sparkle;
    if (t <= 0 || t >= 1) return;
    final center = body.map(const Offset(30, 37));
    final spread = Curves.easeOutCubic.transform(t);
    final size = math.sin(math.pi * t);
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 - math.pi / 2 + 0.35;
      final p = center + _dir(a) * (20 + 13 * spread);
      final color = i.isEven ? companionPaints[(i ~/ 2) % 3] : _violet;
      _twinkle(canvas, p, (i.isEven ? 3.4 : 2.4) * size, color);
    }
  }

  void _twinkle(Canvas canvas, Offset c, double s, Color color) {
    if (s <= 0.1) return;
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - s)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + s, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - s, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s)
        ..close(),
      Paint()..color = color,
    );
  }
}
