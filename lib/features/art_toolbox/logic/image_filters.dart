import 'dart:math' as math;
import 'dart:typed_data';

import 'image_ops.dart';

/// 滑块实时调整的工具（剪影、模糊、色块、冷暖、线稿）先把图缩到这个长边再处理，拖动更跟手。
const int kToolboxWorkSide = 1024;

// ── 缩小 ──────────────────────────────────────────────────────────────────

/// 面积平均缩小到长边不超过 [maxSide]；本身足够小时原样返回。
ArtImageData downscale(ArtImageData source, int maxSide) {
  final w = source.width;
  final h = source.height;
  final longSide = math.max(w, h);
  if (maxSide <= 0 || longSide <= maxSide) {
    return source;
  }
  final tw = math.max(1, (w * maxSide / longSide).round());
  final th = math.max(1, (h * maxSide / longSide).round());
  final colOf = Int32List(w);
  final colCount = Int32List(tw);
  for (var x = 0; x < w; x++) {
    final c = x * tw ~/ w;
    colOf[x] = c;
    colCount[c]++;
  }
  final src = source.rgba;
  final out = Uint8List(tw * th * 4);
  final sums = Int32List(tw * 3);
  var band = 0;
  var rows = 0;

  void flush() {
    for (var c = 0; c < tw; c++) {
      final count = colCount[c] * rows;
      final o = (band * tw + c) * 4;
      out[o] = (sums[c * 3] + count ~/ 2) ~/ count;
      out[o + 1] = (sums[c * 3 + 1] + count ~/ 2) ~/ count;
      out[o + 2] = (sums[c * 3 + 2] + count ~/ 2) ~/ count;
      out[o + 3] = 255;
    }
    sums.fillRange(0, sums.length, 0);
    rows = 0;
  }

  for (var y = 0; y < h; y++) {
    final target = y * th ~/ h;
    if (target != band) {
      flush();
      band = target;
    }
    final row = y * w * 4;
    for (var x = 0; x < w; x++) {
      final i = row + x * 4;
      final c = colOf[x] * 3;
      sums[c] += src[i];
      sums[c + 1] += src[i + 1];
      sums[c + 2] += src[i + 2];
    }
    rows++;
  }
  flush();
  return ArtImageData(width: tw, height: th, rgba: out);
}

/// 供 `compute` 调用：生成交互式滤镜用的工作图。
ArtImageData downscaleForWork(ArtImageData source) =>
    downscale(source, kToolboxWorkSide);

// ── 亮度平面与模糊 ──────────────────────────────────────────────────────────

/// 每像素一个字节的感知亮度。
Uint8List luminancePlane(ArtImageData source) {
  final src = source.rgba;
  final out = Uint8List(source.pixelCount);
  for (var p = 0, i = 0; p < out.length; p++, i += 4) {
    out[p] = luminanceOf(src[i], src[i + 1], src[i + 2]);
  }
  return out;
}

/// 亮度直方图（256 档）。
List<int> luminanceHistogram(ArtImageData source) {
  final counts = List<int>.filled(256, 0);
  final src = source.rgba;
  for (var i = 0; i < src.length; i += 4) {
    counts[luminanceOf(src[i], src[i + 1], src[i + 2])]++;
  }
  return counts;
}

/// 多次盒式模糊近似高斯模糊：水平、垂直分离，滑动窗口求和，耗时与半径无关；边缘按复制处理。
Uint8List boxBlurPlane(
  Uint8List plane,
  int width,
  int height,
  int radius, {
  int passes = 3,
}) {
  var a = Uint8List.fromList(plane);
  if (radius <= 0 || passes <= 0) {
    return a;
  }
  var b = Uint8List(plane.length);
  for (var p = 0; p < passes; p++) {
    _blurLines(a, b, width, height, radius, horizontal: true);
    _blurLines(b, a, width, height, radius, horizontal: false);
  }
  return a;
}

void _blurLines(
  Uint8List src,
  Uint8List dst,
  int width,
  int height,
  int radius, {
  required bool horizontal,
}) {
  final lines = horizontal ? height : width;
  final length = horizontal ? width : height;
  final step = horizontal ? 1 : width;
  final window = 2 * radius + 1;
  final half = window ~/ 2;
  final last = length - 1;
  for (var line = 0; line < lines; line++) {
    final base = horizontal ? line * width : line;
    var sum = 0;
    for (var k = -radius; k <= radius; k++) {
      final index = k < 0 ? 0 : (k > last ? last : k);
      sum += src[base + index * step];
    }
    for (var i = 0; i < length; i++) {
      dst[base + i * step] = (sum + half) ~/ window;
      final add = i + radius + 1;
      final remove = i - radius;
      sum +=
          src[base + (add > last ? last : add) * step] -
          src[base + (remove < 0 ? 0 : remove) * step];
    }
  }
}

class BlurRequest {
  const BlurRequest(this.image, this.radius, {this.grayscale = false});

  final ArtImageData image;
  final int radius;
  final bool grayscale;
}

/// 眨眼模糊：彩色逐通道模糊，或先转灰度再模糊。
ArtImageData blurImage(BlurRequest request) {
  final source = request.image;
  final w = source.width;
  final h = source.height;
  final n = source.pixelCount;
  final out = Uint8List(n * 4);
  if (request.grayscale) {
    final plane = boxBlurPlane(luminancePlane(source), w, h, request.radius);
    for (var p = 0, i = 0; p < n; p++, i += 4) {
      final v = plane[p];
      out[i] = v;
      out[i + 1] = v;
      out[i + 2] = v;
      out[i + 3] = 255;
    }
    return ArtImageData(width: w, height: h, rgba: out);
  }
  final channel = Uint8List(n);
  for (var c = 0; c < 3; c++) {
    for (var p = 0, i = c; p < n; p++, i += 4) {
      channel[p] = source.rgba[i];
    }
    final blurred = boxBlurPlane(channel, w, h, request.radius);
    for (var p = 0, i = c; p < n; p++, i += 4) {
      out[i] = blurred[p];
    }
  }
  for (var i = 3; i < out.length; i += 4) {
    out[i] = 255;
  }
  return ArtImageData(width: w, height: h, rgba: out);
}

/// 模糊档位（0–10）换算成工作图上的模糊半径：10 档约为长边的 2.8%。
int blurRadiusForLevel(int level, int longSide) {
  if (level <= 0 || longSide <= 0) {
    return 0;
  }
  return math.max(1, (longSide * level.clamp(0, 10) * 0.0028).round());
}

// ── 黑白剪影 ─────────────────────────────────────────────────────────────

class NotanRequest {
  const NotanRequest(this.image, this.threshold, {this.smooth = 0});

  final ArtImageData image;

  /// 亮度低于阈值归为黑。
  final int threshold;

  /// 先模糊再分黑白的半径，越大越概括。
  final int smooth;
}

class NotanResult {
  const NotanResult(this.image, this.darkRatio);

  final ArtImageData image;

  /// 黑色面积占比 0–1。
  final double darkRatio;
}

/// 黑白剪影（Notan）：只保留黑、白两块，检查大的明暗布局。
NotanResult notan(NotanRequest request) {
  final source = request.image;
  final n = source.pixelCount;
  var plane = luminancePlane(source);
  if (request.smooth > 0) {
    plane = boxBlurPlane(
      plane,
      source.width,
      source.height,
      request.smooth,
      passes: 2,
    );
  }
  final out = Uint8List(n * 4);
  var dark = 0;
  for (var p = 0, i = 0; p < n; p++, i += 4) {
    final isDark = plane[p] < request.threshold;
    if (isDark) {
      dark++;
    }
    final v = isDark ? 0 : 255;
    out[i] = v;
    out[i + 1] = v;
    out[i + 2] = v;
    out[i + 3] = 255;
  }
  return NotanResult(
    ArtImageData(width: source.width, height: source.height, rgba: out),
    dark / n,
  );
}

/// 大津法自动阈值：让暗、亮两类的类间方差最大，取最优区间的中点。
/// 返回 1–255，含义同 [NotanRequest.threshold]（亮度低于它为暗）；直方图为空返回 128。
int otsuThreshold(List<int> histogram) {
  var total = 0;
  var weightedSum = 0.0;
  for (var v = 0; v < histogram.length; v++) {
    total += histogram[v];
    weightedSum += v * histogram[v];
  }
  if (total == 0) {
    return 128;
  }
  var darkCount = 0;
  var darkSum = 0.0;
  var best = -1.0;
  var firstBest = 0;
  var lastBest = 0;
  for (var t = 0; t < histogram.length - 1; t++) {
    darkCount += histogram[t];
    darkSum += t * histogram[t];
    final lightCount = total - darkCount;
    if (darkCount == 0 || lightCount == 0) {
      continue;
    }
    final meanDark = darkSum / darkCount;
    final meanLight = (weightedSum - darkSum) / lightCount;
    final diff = meanDark - meanLight;
    final variance = darkCount.toDouble() * lightCount * diff * diff;
    if (variance > best * (1 + 1e-12)) {
      best = variance;
      firstBest = t;
      lastBest = t;
    } else if (variance >= best * (1 - 1e-12)) {
      lastBest = t;
    }
  }
  if (best < 0) {
    return 128;
  }
  return ((firstBest + lastBest) ~/ 2 + 1).clamp(1, 255);
}

// ── 反相 ──────────────────────────────────────────────────────────────────

ArtImageData invert(ArtImageData source) {
  final src = source.rgba;
  final out = Uint8List(src.length);
  for (var i = 0; i < src.length; i += 4) {
    out[i] = 255 - src[i];
    out[i + 1] = 255 - src[i + 1];
    out[i + 2] = 255 - src[i + 2];
    out[i + 3] = 255;
  }
  return ArtImageData(width: source.width, height: source.height, rgba: out);
}

// ── 轮廓线稿 ─────────────────────────────────────────────────────────────

/// Sobel 梯度幅值，除以 4 归一化到 0–255：纯黑与纯白相接的直边两侧像素约为 255。
/// 边界像素按复制边缘计算，不会在画面四周产生假轮廓。
Uint8List sobelMagnitude(Uint8List gray, int width, int height) {
  final out = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    final r0 = (y == 0 ? 0 : y - 1) * width;
    final r1 = y * width;
    final r2 = (y == height - 1 ? y : y + 1) * width;
    for (var x = 0; x < width; x++) {
      final x0 = x == 0 ? 0 : x - 1;
      final x2 = x == width - 1 ? x : x + 1;
      final a = gray[r0 + x0];
      final b = gray[r0 + x];
      final c = gray[r0 + x2];
      final d = gray[r1 + x0];
      final f = gray[r1 + x2];
      final g = gray[r2 + x0];
      final h = gray[r2 + x];
      final i = gray[r2 + x2];
      final gx = (c + 2 * f + i) - (a + 2 * d + g);
      final gy = (g + 2 * h + i) - (a + 2 * b + c);
      final m = math.sqrt(gx * gx + gy * gy) / 4;
      out[r1 + x] = m >= 255 ? 255 : m.round();
    }
  }
  return out;
}

class EdgeRequest {
  const EdgeRequest(this.image, this.threshold, {this.smooth = 1});

  final ArtImageData image;

  /// 梯度幅值达到阈值才画线，越大线条越少。
  final int threshold;

  /// 检测前的模糊半径，越大越只保留大的结构线。
  final int smooth;
}

/// 轮廓线稿：白底深色线条，边缘越强线条越深。
ArtImageData edgeSketch(EdgeRequest request) {
  final source = request.image;
  final w = source.width;
  final h = source.height;
  var gray = luminancePlane(source);
  if (request.smooth > 0) {
    gray = boxBlurPlane(gray, w, h, request.smooth, passes: 2);
  }
  final magnitude = sobelMagnitude(gray, w, h);
  final threshold = math.max(1, request.threshold);
  final out = Uint8List(w * h * 4);
  for (var p = 0, i = 0; p < magnitude.length; p++, i += 4) {
    final m = magnitude[p];
    final v = m < threshold ? 255 : math.max(16, 145 - (m - threshold) * 4);
    out[i] = v;
    out[i + 1] = v;
    out[i + 2] = v;
    out[i + 3] = 255;
  }
  return ArtImageData(width: w, height: h, rgba: out);
}
