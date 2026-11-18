import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 一个点。拉正时四个角用归一化坐标（0–1，相对于转正后的照片），
/// 求单应矩阵时用像素坐标。
typedef PhotoPoint = ({double x, double y});

/// 四个角的默认位置：从照片四边各向里收 [inset]，顺序是左上、右上、右下、左下。
List<PhotoPoint> defaultPhotoCorners({double inset = 0.04}) => [
  (x: inset, y: inset),
  (x: 1 - inset, y: inset),
  (x: 1 - inset, y: 1 - inset),
  (x: inset, y: 1 - inset),
];

/// 照片顺时针转 90° 后，四个角在新照片里的位置。列表仍从屏幕上的左上角开始。
List<PhotoPoint> rotatePhotoCornersClockwise(List<PhotoPoint> corners) {
  final turned = [for (final p in corners) (x: 1 - p.y, y: p.x)];
  return [turned[3], turned[0], turned[1], turned[2]];
}

/// 四边形是否是严格凸的（四个角按顺序排列，不交叉、不凹进去、面积不为零）。
bool isConvexQuad(List<PhotoPoint> quad, {double minArea = 1e-6}) {
  if (quad.length != 4) return false;
  var sign = 0;
  for (var i = 0; i < 4; i++) {
    final a = quad[i];
    final b = quad[(i + 1) % 4];
    final c = quad[(i + 2) % 4];
    final cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
    if (cross.abs() < 1e-12) return false;
    final s = cross > 0 ? 1 : -1;
    if (sign == 0) {
      sign = s;
    } else if (s != sign) {
      return false;
    }
  }
  return quadArea(quad) > minArea;
}

/// 四边形面积（鞋带公式，取绝对值）。
double quadArea(List<PhotoPoint> quad) {
  var sum = 0.0;
  for (var i = 0; i < quad.length; i++) {
    final a = quad[i];
    final b = quad[(i + 1) % quad.length];
    sum += a.x * b.y - b.x * a.y;
  }
  return sum.abs() / 2;
}

/// 求把 [from] 的四个点映射到 [to] 的四个点的单应矩阵（3×3，按行展开，h33 = 1）。
/// 四个点里有三点共线时没有解，抛出 [ArgumentError]。
List<double> solveHomography(List<PhotoPoint> from, List<PhotoPoint> to) {
  if (from.length != 4 || to.length != 4) {
    throw ArgumentError('需要四对点');
  }
  // 8 个未知数 h0..h7：x' = (h0 x + h1 y + h2) / (h6 x + h7 y + 1)，y' 同理。
  final a = List.generate(8, (_) => List<double>.filled(9, 0));
  for (var i = 0; i < 4; i++) {
    final x = from[i].x, y = from[i].y;
    final u = to[i].x, v = to[i].y;
    a[2 * i]
      ..[0] = x
      ..[1] = y
      ..[2] = 1
      ..[6] = -x * u
      ..[7] = -y * u
      ..[8] = u;
    a[2 * i + 1]
      ..[3] = x
      ..[4] = y
      ..[5] = 1
      ..[6] = -x * v
      ..[7] = -y * v
      ..[8] = v;
  }
  for (var col = 0; col < 8; col++) {
    var pivot = col;
    for (var row = col + 1; row < 8; row++) {
      if (a[row][col].abs() > a[pivot][col].abs()) pivot = row;
    }
    if (a[pivot][col].abs() < 1e-12) {
      throw ArgumentError('四个点里有三点共线，无法求解');
    }
    if (pivot != col) {
      final t = a[pivot];
      a[pivot] = a[col];
      a[col] = t;
    }
    final p = a[col][col];
    for (var k = col; k < 9; k++) {
      a[col][k] /= p;
    }
    for (var row = 0; row < 8; row++) {
      if (row == col) continue;
      final f = a[row][col];
      if (f == 0) continue;
      for (var k = col; k < 9; k++) {
        a[row][k] -= f * a[col][k];
      }
    }
  }
  return [for (var i = 0; i < 8; i++) a[i][8], 1];
}

/// 用单应矩阵 [h] 变换一个点。
PhotoPoint applyHomography(List<double> h, PhotoPoint p) {
  final w = h[6] * p.x + h[7] * p.y + h[8];
  return (
    x: (h[0] * p.x + h[1] * p.y + h[2]) / w,
    y: (h[3] * p.x + h[4] * p.y + h[5]) / w,
  );
}

double _distance(PhotoPoint a, PhotoPoint b) =>
    math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));

/// 拉正后的尺寸：宽取上下两边的平均长度，高取左右两边的平均长度（像素），
/// 长边不超过 [maxLongSide]。
({int width, int height}) rectifiedSize(
  List<PhotoPoint> pixelCorners, {
  int maxLongSide = 2400,
}) {
  final c = pixelCorners;
  var width = (_distance(c[0], c[1]) + _distance(c[3], c[2])) / 2;
  var height = (_distance(c[0], c[3]) + _distance(c[1], c[2])) / 2;
  final long = math.max(width, height);
  if (long > maxLongSide) {
    final k = maxLongSide / long;
    width *= k;
    height *= k;
  }
  return (
    width: math.max(1, width.round()),
    height: math.max(1, height.round()),
  );
}

/// 交给后台线程的拉正请求。
class PhotoRectifyRequest {
  const PhotoRectifyRequest({
    required this.bytes,
    required this.corners,
    this.quarterTurns = 0,
    this.maxLongSide = 2400,
    this.quality = 90,
  });

  /// 原始照片（JPG / PNG 等 `package:image` 能解码的格式）。
  final Uint8List bytes;

  /// 画纸的四个角，左上、右上、右下、左下，归一化坐标，相对于按拍摄方向摆正、
  /// 再顺时针转了 [quarterTurns] 个 90° 之后的照片。
  final List<PhotoPoint> corners;
  final int quarterTurns;
  final int maxLongSide;
  final int quality;
}

/// 照片拉正失败（解码不了、四个角不成四边形）。
class PhotoRectifyException implements Exception {
  const PhotoRectifyException(this.message);

  final String message;

  @override
  String toString() => 'PhotoRectifyException: $message';
}

/// 解码照片，按拍摄方向摆正，再顺时针转 [quarterTurns] 个 90°。
img.Image orientPhoto(Uint8List bytes, {int quarterTurns = 0}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const PhotoRectifyException('无法读取这张照片');
  }
  var image = img.bakeOrientation(decoded);
  final turns = quarterTurns % 4;
  if (turns != 0) {
    image = img.copyRotate(image, angle: 90 * turns);
  }
  return image;
}

/// 透视校正：把照片里四个角围成的画纸拉成一个矩形，返回 JPG 字节。
/// 纯计算，适合放进 `compute`。
Uint8List rectifyPhoto(PhotoRectifyRequest request) {
  if (!isConvexQuad(request.corners)) {
    throw const PhotoRectifyException('四个角没有围成一个四边形');
  }
  final source = orientPhoto(request.bytes, quarterTurns: request.quarterTurns);
  final output = rectifyImage(
    source,
    request.corners,
    maxLongSide: request.maxLongSide,
  );
  return img.encodeJpg(output, quality: request.quality);
}

/// [rectifyPhoto] 的核心：按归一化的四个角对已经摆正的图做透视校正。
img.Image rectifyImage(
  img.Image source,
  List<PhotoPoint> corners, {
  int maxLongSide = 2400,
}) {
  final sw = source.width, sh = source.height;
  final pixelCorners = [for (final p in corners) (x: p.x * sw, y: p.y * sh)];
  final size = rectifiedSize(pixelCorners, maxLongSide: maxLongSide);
  final w = size.width, h = size.height;
  // 从输出矩形反推到原图：输出的每个像素中心找到原图里的位置再双线性取样。
  final m = solveHomography([
    (x: 0, y: 0),
    (x: w.toDouble(), y: 0),
    (x: w.toDouble(), y: h.toDouble()),
    (x: 0, y: h.toDouble()),
  ], pixelCorners);
  final src = source
      .convert(format: img.Format.uint8, numChannels: 3)
      .getBytes(order: img.ChannelOrder.rgb);
  final out = Uint8List(w * h * 3);
  final maxX = sw - 1, maxY = sh - 1;
  var o = 0;
  for (var y = 0; y < h; y++) {
    final cy = y + 0.5;
    // 一行里分子分母都随 x 线性变化，逐像素累加。
    var nx = m[0] * 0.5 + m[1] * cy + m[2];
    var ny = m[3] * 0.5 + m[4] * cy + m[5];
    var dw = m[6] * 0.5 + m[7] * cy + m[8];
    for (var x = 0; x < w; x++) {
      var sx = nx / dw - 0.5;
      var sy = ny / dw - 0.5;
      nx += m[0];
      ny += m[3];
      dw += m[6];
      if (sx < 0) sx = 0;
      if (sy < 0) sy = 0;
      if (sx > maxX) sx = maxX.toDouble();
      if (sy > maxY) sy = maxY.toDouble();
      final x0 = sx.floor(), y0 = sy.floor();
      final x1 = x0 < maxX ? x0 + 1 : x0;
      final y1 = y0 < maxY ? y0 + 1 : y0;
      final fx = sx - x0, fy = sy - y0;
      final i00 = (y0 * sw + x0) * 3, i10 = (y0 * sw + x1) * 3;
      final i01 = (y1 * sw + x0) * 3, i11 = (y1 * sw + x1) * 3;
      for (var c = 0; c < 3; c++) {
        final top = src[i00 + c] + (src[i10 + c] - src[i00 + c]) * fx;
        final bottom = src[i01 + c] + (src[i11 + c] - src[i01 + c]) * fx;
        out[o++] = (top + (bottom - top) * fy + 0.5).toInt();
      }
    }
  }
  return img.Image.fromBytes(
    width: w,
    height: h,
    bytes: out.buffer,
    numChannels: 3,
  );
}
