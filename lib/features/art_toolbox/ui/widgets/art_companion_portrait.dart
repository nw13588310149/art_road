import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../data/toolbox_dock_preferences.dart';

/// 小画的形象：戴圆眼镜、穿西装、抱着笔记本的紫色猫头鹰。
///
/// 图片画布为 64 个设计单位见方，身体中线落在画布正中，头顶在 1、脚底在 63，
/// 伸出的那只手在左侧。更换形象时保持这套位置，贴边姿势就不用重调。
const companionAsset = 'assets/images/brand/xiaohua_owl.png';

/// 拖动小画时身后那一笔的颜色，取自它的羽冠。
const companionTrailColor = Color(0xFF7A5CF0);

/// 小画此刻的姿态。形象是一整张图，所有动作都是整体的位移、旋转和缩放。
@immutable
class CompanionPose {
  const CompanionPose({
    this.conceal = 0,
    this.peek = 0,
    this.nod = 0,
    this.sway = 0,
    this.squash = 0,
    this.tilt = 0,
    this.lift = 0,
    this.scale = 1,
    this.sparkle = 0,
  });

  /// 贴边收纳的程度：0 完整站立，0.5 露出一半，2/3 只留眼睛在外面。
  final double conceal;

  /// 收纳时朝画面里探出来的程度，0–1。
  final double peek;

  /// 点头：身体向下一沉再弹回，0–1。
  final double nod;

  /// 以脚为支点左右摇晃，-1–1。
  final double sway;

  /// 弹簧挤压，正值压扁、负值拉长。
  final double squash;

  /// 被拎着走时身体的倾斜，单位弧度。
  final double tilt;

  /// 跳起的高度，单位为设计单位（形象高 62）。
  final double lift;

  /// 出场时的整体缩放。
  final double scale;

  /// 星光的进度，0 和 1 都不画。
  final double sparkle;

  @override
  bool operator ==(Object other) =>
      other is CompanionPose &&
      other.conceal == conceal &&
      other.peek == peek &&
      other.nod == nod &&
      other.sway == sway &&
      other.squash == squash &&
      other.tilt == tilt &&
      other.lift == lift &&
      other.scale == scale &&
      other.sparkle == sparkle;

  @override
  int get hashCode =>
      Object.hash(conceal, peek, nod, sway, squash, tilt, lift, scale, sparkle);
}

/// 按停靠的边和姿态摆好的小画。
///
/// 站立时四条边都是同一个正面形象。收纳后：
/// - 左右两边朝画面里歪过身子，露出脸和伸出的手（贴左边时整体镜像）；
/// - 下沿往下沉，只露出头；
/// - 上沿翻个身，从上面倒着探头。
class ArtCompanionPortrait extends StatelessWidget {
  const ArtCompanionPortrait({
    this.size = 64,
    this.edge = ToolboxDockEdge.right,
    this.pose = const CompanionPose(),
    this.edgeInset = 0,
    super.key,
  });

  final double size;
  final ToolboxDockEdge edge;
  final CompanionPose pose;

  /// 方框到屏幕真实边缘的距离（逻辑像素）。收纳时多退这么远，
  /// 露在屏幕里的部分和方框紧贴屏幕边时一样多。
  final double edgeInset;

  @override
  Widget build(BuildContext context) {
    final rig = _Rig(edge, pose, edgeInset * _box / size);
    return ExcludeSemantics(
      child: CustomPaint(
        painter: _GroundPainter(rig.ground, rig.groundWidth, rig.groundAlpha),
        foregroundPainter: _SparklePainter(rig.heart, pose.sparkle),
        child: SizedBox.square(
          dimension: size,
          child: Transform(
            transform: rig.matrix(size / _box),
            child: Image.asset(
              companionAsset,
              width: size,
              height: size,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

const _box = 64.0;

/// 脚的位置：摇晃和侧边歪身都绕着这里转。
const _feet = Offset(33, 62);
const _chest = Offset(32, 38);

/// 贴在左右两边休息时，身子朝画面里歪过去的角度（约 27°）。
const _sideLean = 0.47;

const _ink = Color(0xFF221651);
const _sparkColors = [Color(0xFFFFBE2E), Color(0xFF8E7BFF), Color(0xFF4FB8F2)];

double _smooth(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

/// 只含平移、旋转、缩放的二维变换；调用顺序与画布相同，先写的在外层。
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

  _Frame rotateAbout(double r, Offset pivot) => r == 0
      ? this
      : translate(pivot.dx, pivot.dy).rotate(r).translate(-pivot.dx, -pivot.dy);

  _Frame scaleAbout(double sx, double sy, Offset pivot) => translate(
    pivot.dx,
    pivot.dy,
  ).scale(sx, sy).translate(-pivot.dx, -pivot.dy);

  Offset map(Offset p) =>
      Offset(a * p.dx + c * p.dy + e, b * p.dx + d * p.dy + f);

  Matrix4 get matrix => Matrix4.fromFloat64List(
    Float64List.fromList([a, b, 0, 0, c, d, 0, 0, 0, 0, 1, 0, e, f, 0, 1]),
  );
}

/// 一次摆放用到的数值，坐标都在 64 单位的方框里。
class _Rig {
  _Rig(ToolboxDockEdge edge, CompanionPose pose, double inset) {
    final conceal = pose.conceal.clamp(0.0, 1.0);
    // 露出一半时已经完全进入贴边姿势，再往后只是继续往外退。
    final rest = _smooth(conceal / 0.5);
    final deeper = ((conceal - 0.5) * 6).clamp(0.0, 1.0);
    // 露出一半、只留眼睛时各往屏幕外退多少。
    final (half, least) = switch (edge) {
      ToolboxDockEdge.top => (30.0, 39.0),
      ToolboxDockEdge.bottom => (31.0, 41.0),
      _ => (36.0, 46.0),
    };
    final push = math.max(
      0.0,
      (half + inset) * rest + (least - half) * deeper - pose.peek * 10,
    );

    final mirror = edge == ToolboxDockEdge.left;
    var frame = _Frame.identity;
    if (mirror) frame = frame.translate(_box, 0).scale(-1, 1);
    frame = switch (edge) {
      ToolboxDockEdge.top =>
        frame
            .translate(0, -push)
            .rotateAbout(math.pi * rest, const Offset(_box / 2, _box / 2)),
      ToolboxDockEdge.bottom => frame.translate(0, push),
      _ => frame.translate(push, 0).rotateAbout(-_sideLean * rest, _feet),
    };

    final squash = pose.squash + pose.nod * 0.12;
    _body = frame
        .translate(0, -pose.lift)
        // 镜像后倾斜方向也要反过来，才和手指拖动的方向一致。
        .rotateAbout(mirror ? -pose.tilt : pose.tilt, _chest)
        .rotateAbout(pose.sway * 0.14, _feet)
        .scaleAbout(
          (1 + squash * 0.35) * pose.scale,
          (1 - squash * 0.4) * pose.scale,
          const Offset(33, 63),
        );

    heart = _body.map(const Offset(32, 34));
    ground = Offset(mirror ? _box - _feet.dx : _feet.dx, 62.8);
    groundWidth = math.max(
      0.0,
      34 * pose.scale * (1 + squash * 0.3) - pose.lift,
    );
    // 影子只在站立时出现，跳起来变淡，贴边后收掉。
    groundAlpha = 0.16 * (1 - rest) * (1 - (pose.lift / 14).clamp(0.0, 0.7));
  }

  late final _Frame _body;

  /// 身体中心在方框里的位置，星光围着它散开。
  late final Offset heart;
  late final Offset ground;
  late final double groundWidth;
  late final double groundAlpha;

  /// 作用在整张图上的变换，[unit] 为每个设计单位的逻辑像素：旋转和缩放
  /// 与单位无关，只有位移要换算。
  Matrix4 matrix(double unit) => _Frame(
    _body.a,
    _body.b,
    _body.c,
    _body.d,
    _body.e * unit,
    _body.f * unit,
  ).matrix;
}

class _GroundPainter extends CustomPainter {
  const _GroundPainter(this.center, this.width, this.alpha);

  final Offset center;
  final double width;
  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    if (alpha <= 0.01 || width <= 0) return;
    canvas.save();
    canvas.scale(size.width / _box, size.height / _box);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: width, height: 4.6),
      Paint()
        ..color = _ink.withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GroundPainter old) =>
      center != old.center || width != old.width || alpha != old.alpha;
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter(this.center, this.progress);

  final Offset center;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress;
    if (t <= 0 || t >= 1) return;
    canvas.save();
    canvas.scale(size.width / _box, size.height / _box);
    final spread = Curves.easeOutCubic.transform(t);
    final scale = math.sin(math.pi * t);
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3 - math.pi / 2 + 0.35;
      final point =
          center +
          Offset(math.cos(angle), math.sin(angle)) * (22 + 13 * spread);
      _twinkle(
        canvas,
        point,
        (i.isEven ? 3.4 : 2.4) * scale,
        _sparkColors[i % _sparkColors.length],
      );
    }
    canvas.restore();
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

  @override
  bool shouldRepaint(_SparklePainter old) =>
      center != old.center || progress != old.progress;
}
