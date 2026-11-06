import 'dart:math' as math;
import 'dart:ui';

// ── 比例测量 ─────────────────────────────────────────────────────────────

double segmentLength(Offset a, Offset b) => (b - a).distance;

/// 线段与水平线的夹角 0–90°，与两点先后无关。
double angleToHorizontal(Offset a, Offset b) {
  final dx = (b.dx - a.dx).abs();
  final dy = (b.dy - a.dy).abs();
  if (dx == 0 && dy == 0) {
    return 0;
  }
  return math.atan2(dy, dx) * 180 / math.pi;
}

/// 线段与铅垂线的夹角 0–90°。
double angleToVertical(Offset a, Offset b) => 90 - angleToHorizontal(a, b);

enum LineSlope {
  level('水平'),
  plumb('垂直'),
  risingRight('右高左低'),
  fallingRight('左高右低');

  const LineSlope(this.label);

  final String label;
}

/// 屏幕坐标（y 向下）中线段的走向，与水平或垂直相差不超过 [tolerance] 度时视为水平或垂直。
LineSlope slopeOf(Offset a, Offset b, {double tolerance = 0.5}) {
  final angle = angleToHorizontal(a, b);
  if (angle <= tolerance) {
    return LineSlope.level;
  }
  if (angle >= 90 - tolerance) {
    return LineSlope.plumb;
  }
  final dx = b.dx - a.dx;
  final dy = b.dy - a.dy;
  return dx * dy < 0 ? LineSlope.risingRight : LineSlope.fallingRight;
}

/// 依次每两个点组成一段：第 1、2 点为 A 段，第 3、4 点为 B 段……落单的点不成段。
List<(Offset, Offset)> segmentsOf(List<Offset> points) => [
  for (var i = 0; i + 1 < points.length; i += 2) (points[i], points[i + 1]),
];

/// 以 [unit] 为 1 时 [length] 的倍数；单位长度为 0 时返回 null。
double? ratioTo(double unit, double length) => unit <= 0 ? null : length / unit;

/// 比值接近的简单整数比（两项都不超过 [maxTerm]，相对误差在 [tolerance] 以内），
/// 返回如 `2 : 3`；都不接近时返回 null。比值按「第二段 ÷ 第一段」计。
String? simpleRatioLabel(
  double ratio, {
  int maxTerm = 5,
  double tolerance = 0.03,
}) {
  if (ratio <= 0 || !ratio.isFinite) {
    return null;
  }
  String? best;
  var bestError = double.infinity;
  for (var q = 1; q <= maxTerm; q++) {
    for (var p = 1; p <= maxTerm; p++) {
      if (_gcd(p, q) != 1) {
        continue;
      }
      final error = ((p / q) - ratio).abs() / ratio;
      if (error <= tolerance && error < bestError) {
        bestError = error;
        best = '$q : $p';
      }
    }
  }
  return best;
}

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

// ── 构图网格 ─────────────────────────────────────────────────────────────

/// 黄金分割点：0.382 与 0.618（短段 : 长段 = 长段 : 全长）。
const double kGoldenMinor = 0.3819660112501051;
const double kGoldenMajor = 0.6180339887498949;

/// 均分 [divisions] 份时内部分割线的位置（0–1）。
List<double> evenFractions(int divisions) => [
  for (var i = 1; i < divisions; i++) i / divisions,
];

/// 正方形网格：格子边长为长边 ÷ [cellsOnLongSide]，从左上角起排，短边末尾可能留半格。
/// 返回内部竖线与横线的位置（像素）。
({List<double> xs, List<double> ys, double cell}) squareGridLines(
  Size size,
  int cellsOnLongSide,
) {
  final n = math.max(1, cellsOnLongSide);
  final cell = math.max(size.width, size.height) / n;
  List<double> linesFor(double extent) => [
    for (var v = cell; v < extent - cell * 0.02; v += cell) v,
  ];
  return (xs: linesFor(size.width), ys: linesFor(size.height), cell: cell);
}

enum ExamPaper {
  quarter('四开', 545, 395),
  eighth('八开', 390, 270),
  sixteenth('十六开', 270, 195);

  const ExamPaper(this.label, this.longMm, this.shortMm);

  final String label;
  final double longMm;
  final double shortMm;

  /// 宽 ÷ 高。
  double aspect({required bool landscape}) =>
      landscape ? longMm / shortMm : shortMm / longMm;

  String sizeText({required bool landscape}) => landscape
      ? '${longMm.round()}×${shortMm.round()}mm'
      : '${shortMm.round()}×${longMm.round()}mm';
}

/// 在 [size] 内放下宽高比为 [aspect] 的最大矩形；[shift] 0–1 决定在多余方向上的位置（0.5 居中）。
Rect fitAspectRect(Size size, double aspect, {double shift = 0.5}) {
  if (size.isEmpty || aspect <= 0) {
    return Offset.zero & size;
  }
  final t = shift.clamp(0.0, 1.0);
  if (size.width / size.height > aspect) {
    final width = size.height * aspect;
    return Rect.fromLTWH((size.width - width) * t, 0, width, size.height);
  }
  final height = size.width / aspect;
  return Rect.fromLTWH(0, (size.height - height) * t, size.width, height);
}

/// 网格放大法：画纸上每格的实际尺寸（毫米）。
({double width, double height}) paperCellMm(
  ExamPaper paper, {
  required bool landscape,
  required int rows,
  required int cols,
}) {
  final width = landscape ? paper.longMm : paper.shortMm;
  final height = landscape ? paper.shortMm : paper.longMm;
  return (
    width: width / math.max(1, cols),
    height: height / math.max(1, rows),
  );
}

// ── 透视辅助 ─────────────────────────────────────────────────────────────

/// 从 [origin] 沿 [direction] 的射线被 [clip] 裁剪后的线段（Liang–Barsky）；不相交返回 null。
(Offset, Offset)? clipRay(Offset origin, Offset direction, Rect clip) {
  final dx = direction.dx;
  final dy = direction.dy;
  if (dx == 0 && dy == 0) {
    return null;
  }
  var t0 = 0.0;
  var t1 = double.infinity;
  final checks = <(double, double)>[
    (-dx, origin.dx - clip.left),
    (dx, clip.right - origin.dx),
    (-dy, origin.dy - clip.top),
    (dy, clip.bottom - origin.dy),
  ];
  for (final (p, q) in checks) {
    if (p == 0) {
      if (q < 0) {
        return null;
      }
      continue;
    }
    final r = q / p;
    if (p < 0) {
      t0 = math.max(t0, r);
    } else {
      t1 = math.min(t1, r);
    }
  }
  if (t0 > t1 || !t1.isFinite) {
    return null;
  }
  return (origin + direction * t0, origin + direction * t1);
}

/// 从灭点 [vp] 发出、穿过 [target] 的放射线方向（单位向量），按角度均匀分布：
/// 灭点在区域内时铺满一周，在区域外时只覆盖区域所张的角度。
List<Offset> fanDirections(Offset vp, Rect target, int count) {
  if (count <= 0 || target.isEmpty) {
    return const <Offset>[];
  }
  Offset unit(double angle) => Offset(math.cos(angle), math.sin(angle));
  if (target.contains(vp)) {
    return [for (var i = 0; i < count; i++) unit(math.pi * 2 * i / count)];
  }
  final center = target.center;
  final reference = math.atan2(center.dy - vp.dy, center.dx - vp.dx);
  var minOffset = double.infinity;
  var maxOffset = double.negativeInfinity;
  for (final corner in [
    target.topLeft,
    target.topRight,
    target.bottomLeft,
    target.bottomRight,
  ]) {
    var offset = math.atan2(corner.dy - vp.dy, corner.dx - vp.dx) - reference;
    while (offset > math.pi) {
      offset -= math.pi * 2;
    }
    while (offset <= -math.pi) {
      offset += math.pi * 2;
    }
    minOffset = math.min(minOffset, offset);
    maxOffset = math.max(maxOffset, offset);
  }
  return [
    for (var i = 0; i < count; i++)
      unit(reference + minOffset + (maxOffset - minOffset) * (i + 0.5) / count),
  ];
}

// ── 头像比例 ─────────────────────────────────────────────────────────────

/// 三庭比例，以上庭为 1：[1, 中庭 ÷ 上庭, 下庭 ÷ 上庭]。
/// 参数为发际线、眉线、鼻底线、下巴的纵坐标（自上而下递增）；上庭长度为 0 时返回 null。
List<double>? facialThirds(
  double hairline,
  double brow,
  double noseBase,
  double chin,
) {
  final upper = brow - hairline;
  if (upper <= 0) {
    return null;
  }
  return [1, (noseBase - brow) / upper, (chin - noseBase) / upper];
}

/// 五眼：把脸宽等分五份的六条竖线位置。
List<double> fiveEyeLines(double left, double right) => [
  for (var i = 0; i <= 5; i++) left + (right - left) * i / 5,
];
