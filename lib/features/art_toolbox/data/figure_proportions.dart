import 'dart:math' as math;
import 'dart:ui';

/// 上臂、前臂、手的长度（头长）：合计三个头长，即「臂三」。
const double kUpperArmHeads = 4 / 3;
const double kForearmHeads = 1;
const double kHandHeads = 2 / 3;

/// 头部椭圆的宽度（头长）。
const double kHeadWidth = 0.72;

/// 图示下方的说明。
const kFigureFootnote = '常用参考比例，写生时以对象为准';

class FigureBone {
  const FigureBone(this.from, this.to, this.width, {this.isArm = false});

  final Offset from;
  final Offset to;

  /// 画成圆头粗线时的线宽（头长）。
  final double width;
  final bool isArm;

  double get length => (to - from).distance;
}

/// 简化的木偶人：单位为头长，头顶 y = 0，y 向下；正面图以身体中线为 x = 0，侧面图朝右。
class FigureSkeleton {
  const FigureSkeleton({
    required this.headCenter,
    required this.bones,
    required this.shapes,
    this.headAngle = 0,
    this.props = const <(Offset, Offset)>[],
  });

  final Offset headCenter;

  /// 头部倾斜（弧度）。
  final double headAngle;
  final List<FigureBone> bones;

  /// 躯干、骨盆等多边形。
  final List<List<Offset>> shapes;

  /// 凳子等道具线条。
  final List<(Offset, Offset)> props;

  Iterable<Offset> get _points sync* {
    for (final bone in bones) {
      yield bone.from;
      yield bone.to;
    }
    for (final shape in shapes) {
      yield* shape;
    }
    for (final (a, b) in props) {
      yield a;
      yield b;
    }
  }

  /// 头顶到脚底（地面）的高度，单位头长。
  double get height {
    var bottom = headCenter.dy + 0.5;
    for (final p in _points) {
      bottom = math.max(bottom, p.dy);
    }
    return bottom - (headCenter.dy - 0.5);
  }

  /// 外接矩形（不含线宽）。
  Rect get bounds {
    var left = headCenter.dx - kHeadWidth / 2;
    var right = headCenter.dx + kHeadWidth / 2;
    for (final p in _points) {
      left = math.min(left, p.dx);
      right = math.max(right, p.dx);
    }
    return Rect.fromLTRB(left, headCenter.dy - 0.5, right, headCenter.dy - 0.5 + height);
  }

  List<FigureBone> get armBones => [
    for (final bone in bones)
      if (bone.isArm) bone,
  ];
}

/// 从 [from] 出发画一段长 [length] 的肢体，[degrees] 为与正下方的夹角，正值偏向 +x。
Offset limbEnd(Offset from, double length, double degrees) {
  final radians = degrees * math.pi / 180;
  return from + Offset(math.sin(radians) * length, math.cos(radians) * length);
}

List<FigureBone> _arm(Offset shoulder, double upper, double fore, double hand) {
  final elbow = limbEnd(shoulder, kUpperArmHeads, upper);
  final wrist = limbEnd(elbow, kForearmHeads, fore);
  final tip = limbEnd(wrist, kHandHeads, hand);
  return [
    FigureBone(shoulder, elbow, 0.26, isArm: true),
    FigureBone(elbow, wrist, 0.21, isArm: true),
    FigureBone(wrist, tip, 0.17, isArm: true),
  ];
}

/// 侧面躯干：沿脊柱两端向前、向后各取厚度围成四边形。
List<Offset> _sideTorso(Offset shoulder, Offset hip) {
  final spine = hip - shoulder;
  final unit = spine / spine.distance;
  final front = Offset(-unit.dy, unit.dx).dx >= 0
      ? Offset(-unit.dy, unit.dx)
      : Offset(unit.dy, -unit.dx);
  return [
    shoulder - front * 0.32,
    shoulder + front * 0.42,
    hip + front * 0.36,
    hip - front * 0.44,
  ];
}

enum FigurePose {
  standing('站姿', '站七', 7, '正面'),
  sitting('坐姿', '坐五', 5, '侧面'),
  crouching('蹲姿', '蹲三半', 3.5, '侧面');

  const FigurePose(this.label, this.rhyme, this.heads, this.view);

  final String label;

  /// 口诀：站七坐五蹲三半。
  final String rhyme;

  /// 头顶到脚底的头长数。
  final double heads;
  final String view;

  FigureSkeleton get skeleton => switch (this) {
    FigurePose.standing => _standing,
    FigurePose.sitting => _sitting,
    FigurePose.crouching => _crouching,
  };

  /// 头长尺旁的标注：(高度, 名称)。
  List<(double, String)> get landmarks => switch (this) {
    FigurePose.standing => const [
      (1, '下巴'),
      (2, '乳头'),
      (3, '肚脐'),
      (3.5, '耻骨'),
      (5, '膝'),
      (7, '脚底'),
    ],
    FigurePose.sitting => const [(1, '下巴'), (3.5, '凳面'), (5, '脚底')],
    FigurePose.crouching => const [(1, '下巴'), (3.5, '地面')],
  };

  List<String> get notes => switch (this) {
    FigurePose.standing => const [
      '站七：成年人站立时全身约七个头长，青年模特常见七个到七个半头长',
      '臂三腿四：上肢约三个头长；下肢从髂前上棘量到脚跟约四个头长',
      '上臂约一又三分之一头长，前臂约一头长，手约三分之二头长',
      '男性肩宽约两个头长，女性肩略窄、骨盆相对更宽',
      '手臂自然下垂时，肘约齐腰，腕约齐耻骨，指尖约到大腿中部',
      '身体的中点约在耻骨附近，膝盖约在第五个头长处',
    ],
    FigurePose.sitting => const [
      '坐五：坐在凳子上时，头顶到脚底约五个头长',
      '坐下后上身长度基本不变，变短的是腿：大腿转成水平，正面看会明显缩短',
      '凳面高度与小腿长度相当，膝盖到脚底约两个头长',
      '先找准臀部与凳面的接触位置，再确定重心落在哪里',
    ],
    FigurePose.crouching => const [
      '蹲三半：蹲下时头顶到地面约三个半头长，盘腿坐在地上也约三个半头长',
      '大腿与小腿折叠，膝盖常高过臀部，注意大腿的透视缩短',
      '重心落在两脚之间，上身前倾来保持平衡',
      '手臂长度不变，常搭在膝盖上或垂在两腿之间',
    ],
  };
}

/// 三种姿态通用的要点。
const kFigureCommonNotes = <String>[
  '以头长为单位比较：先量头长，再用它去量身高、肩宽和四肢',
  '三庭五眼：发际线到眉、眉到鼻底、鼻底到下巴三段相等，脸宽约五只眼宽',
];

final FigureSkeleton _standing = () {
  const lShoulder = Offset(-1, 1.45);
  const rShoulder = Offset(1, 1.45);
  return FigureSkeleton(
    headCenter: const Offset(0, 0.5),
    shapes: const [
      [Offset(-1, 1.4), Offset(1, 1.4), Offset(0.66, 2.95), Offset(-0.66, 2.95)],
      [
        Offset(-0.66, 2.95),
        Offset(0.66, 2.95),
        Offset(0.8, 3.4),
        Offset(0, 3.6),
        Offset(-0.8, 3.4),
      ],
    ],
    bones: [
      const FigureBone(Offset(0, 0.95), Offset(0, 1.4), 0.3),
      ..._arm(lShoulder, -4, -6, -5),
      ..._arm(rShoulder, 4, 6, 5),
      const FigureBone(Offset(-0.45, 3.35), Offset(-0.42, 5.1), 0.4),
      const FigureBone(Offset(-0.42, 5.1), Offset(-0.4, 6.8), 0.28),
      const FigureBone(Offset(-0.4, 6.8), Offset(-0.56, 7), 0.2),
      const FigureBone(Offset(0.45, 3.35), Offset(0.42, 5.1), 0.4),
      const FigureBone(Offset(0.42, 5.1), Offset(0.4, 6.8), 0.28),
      const FigureBone(Offset(0.4, 6.8), Offset(0.56, 7), 0.2),
    ],
  );
}();

final FigureSkeleton _sitting = () {
  const shoulder = Offset(0, 1.4);
  const hip = Offset(0, 3.25);
  const knee = Offset(1.85, 3.2);
  const ankle = Offset(1.82, 4.82);
  return FigureSkeleton(
    headCenter: const Offset(0.12, 0.5),
    shapes: [_sideTorso(shoulder, hip)],
    bones: [
      const FigureBone(Offset(0.06, 0.95), Offset(0, 1.4), 0.3),
      const FigureBone(hip, knee, 0.42),
      const FigureBone(knee, ankle, 0.28),
      const FigureBone(ankle, Offset(2.4, 5), 0.18),
      ..._arm(const Offset(0.05, 1.5), 12, 78, 80),
    ],
    props: const [
      (Offset(-0.6, 3.52), Offset(1.05, 3.52)),
      (Offset(-0.48, 3.52), Offset(-0.52, 5)),
      (Offset(0.92, 3.52), Offset(0.96, 5)),
    ],
  );
}();

final FigureSkeleton _crouching = () {
  const shoulder = Offset(0.7, 1.4);
  const hip = Offset(0, 2.95);
  final knee = hip + const Offset(1.552, -1.008);
  const ankle = Offset(0.69, 3.35);
  return FigureSkeleton(
    headCenter: const Offset(1, 0.5),
    headAngle: 0.15,
    shapes: [_sideTorso(shoulder, hip)],
    bones: [
      const FigureBone(Offset(0.9, 0.95), Offset(0.72, 1.4), 0.3),
      FigureBone(hip, knee, 0.42),
      FigureBone(knee, ankle, 0.28),
      const FigureBone(ankle, Offset(1.3, 3.5), 0.18),
      ..._arm(const Offset(0.75, 1.45), 63.4, 45, 30),
    ],
  );
}();
