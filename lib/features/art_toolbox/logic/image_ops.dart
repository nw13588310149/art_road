import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'kmeans.dart';

/// 工具箱处理图片的长边上限：超过先等比缩小，保证处理耗时与内存可控。
const int kToolboxMaxSide = 1600;

/// 8 位 RGBA 像素缓冲（不透明、逐行存储），工具箱所有像素运算的输入输出。
class ArtImageData {
  ArtImageData({required this.width, required this.height, required this.rgba})
    : assert(width > 0 && height > 0),
      assert(rgba.length == width * height * 4);

  final int width;
  final int height;
  final Uint8List rgba;

  int get pixelCount => width * height;
}

class RgbColor {
  const RgbColor(this.r, this.g, this.b);

  final int r;
  final int g;
  final int b;

  int get argb => 0xFF000000 | (r << 16) | (g << 8) | b;

  String get hex => '#${_hex2(r)}${_hex2(g)}${_hex2(b)}'.toUpperCase();

  HsbColor toHsb() {
    final rf = r / 255;
    final gf = g / 255;
    final bf = b / 255;
    final maxC = math.max(rf, math.max(gf, bf));
    final minC = math.min(rf, math.min(gf, bf));
    final delta = maxC - minC;
    var hue = 0.0;
    if (delta > 0) {
      if (maxC == rf) {
        hue = 60 * (((gf - bf) / delta) % 6);
      } else if (maxC == gf) {
        hue = 60 * ((bf - rf) / delta + 2);
      } else {
        hue = 60 * ((rf - gf) / delta + 4);
      }
    }
    if (hue < 0) {
      hue += 360;
    }
    return HsbColor(hue, maxC == 0 ? 0 : delta / maxC, maxC);
  }

  @override
  bool operator ==(Object other) =>
      other is RgbColor && other.r == r && other.g == g && other.b == b;

  @override
  int get hashCode => Object.hash(r, g, b);

  @override
  String toString() => 'RgbColor($r, $g, $b)';
}

String _hex2(int value) => value.toRadixString(16).padLeft(2, '0');

/// 色相 0–360，饱和度、明度 0–1。
class HsbColor {
  const HsbColor(this.hue, this.saturation, this.brightness);

  final double hue;
  final double saturation;
  final double brightness;
}

enum ColorTemperature { warm, cool, neutral }

class ColorTemperatureInfo {
  const ColorTemperatureInfo(this.temperature, this.label, this.family);

  final ColorTemperature temperature;

  /// 暖色 / 偏暖 / 冷色 / 偏冷 / 中性灰 等。
  final String label;

  /// 色系描述，如「橙色系」「冷灰」。
  final String family;
}

/// 冷暖倾向：低饱和度按红蓝分量判断冷灰 / 暖灰，其余按色相划分。
ColorTemperatureInfo describeTemperature(RgbColor color) {
  final hsb = color.toHsb();
  if (hsb.brightness < 0.12) {
    return const ColorTemperatureInfo(
      ColorTemperature.neutral,
      '中性',
      '深暗色，冷暖不明显',
    );
  }
  if (hsb.saturation < 0.1) {
    final diff = color.r - color.b;
    if (diff > 6) {
      return const ColorTemperatureInfo(ColorTemperature.warm, '偏暖', '暖灰');
    }
    if (diff < -6) {
      return const ColorTemperatureInfo(ColorTemperature.cool, '偏冷', '冷灰');
    }
    return const ColorTemperatureInfo(ColorTemperature.neutral, '中性', '中性灰');
  }
  final h = hsb.hue;
  if (h >= 330 || h < 20) {
    return const ColorTemperatureInfo(ColorTemperature.warm, '暖色', '红色系');
  }
  if (h < 45) {
    return const ColorTemperatureInfo(ColorTemperature.warm, '暖色', '橙色系');
  }
  if (h < 70) {
    return const ColorTemperatureInfo(ColorTemperature.warm, '暖色', '黄色系');
  }
  if (h < 110) {
    return const ColorTemperatureInfo(ColorTemperature.warm, '偏暖', '黄绿色系');
  }
  if (h < 170) {
    return const ColorTemperatureInfo(ColorTemperature.cool, '偏冷', '绿色系');
  }
  if (h < 260) {
    return const ColorTemperatureInfo(ColorTemperature.cool, '冷色', '青蓝色系');
  }
  if (h < 300) {
    return const ColorTemperatureInfo(ColorTemperature.cool, '偏冷', '蓝紫色系');
  }
  return const ColorTemperatureInfo(ColorTemperature.warm, '偏暖', '紫红色系');
}

// ── 解码 ──────────────────────────────────────────────────────────────────

/// 用 image 包解码（引擎解码失败时的兜底，在 isolate 中运行）：
/// 校正 EXIF 方向、长边缩到 [kToolboxMaxSide] 以内、透明区域铺白。
ArtImageData? decodeArtImage(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    return null;
  }
  if (decoded == null || decoded.width == 0 || decoded.height == 0) {
    return null;
  }
  var image = img.bakeOrientation(decoded);
  if (math.max(image.width, image.height) > kToolboxMaxSide) {
    final landscape = image.width >= image.height;
    image = img.copyResize(
      image,
      width: landscape ? kToolboxMaxSide : null,
      height: landscape ? null : kToolboxMaxSide,
      interpolation: img.Interpolation.average,
    );
  }
  final rgbaImage = image.convert(
    format: img.Format.uint8,
    numChannels: 4,
    alpha: 255,
  );
  final rgba = Uint8List.fromList(
    rgbaImage.getBytes(order: img.ChannelOrder.rgba),
  );
  for (var i = 0; i < rgba.length; i += 4) {
    final a = rgba[i + 3];
    if (a == 255) {
      continue;
    }
    final keep = 255 - a;
    rgba[i] = (rgba[i] * a + 255 * keep) ~/ 255;
    rgba[i + 1] = (rgba[i + 1] * a + 255 * keep) ~/ 255;
    rgba[i + 2] = (rgba[i + 2] * a + 255 * keep) ~/ 255;
    rgba[i + 3] = 255;
  }
  return ArtImageData(width: image.width, height: image.height, rgba: rgba);
}

/// 引擎导出的预乘 RGBA（`ImageByteFormat.rawRgba`）原地铺白：c' = c + (255 - a)。
ArtImageData artImageFromPremultiplied(int width, int height, Uint8List rgba) {
  for (var i = 0; i < rgba.length; i += 4) {
    final a = rgba[i + 3];
    if (a == 255) {
      continue;
    }
    final keep = 255 - a;
    rgba[i] = math.min(255, rgba[i] + keep);
    rgba[i + 1] = math.min(255, rgba[i + 1] + keep);
    rgba[i + 2] = math.min(255, rgba[i + 2] + keep);
    rgba[i + 3] = 255;
  }
  return ArtImageData(width: width, height: height, rgba: rgba);
}

/// 供 `compute` 调用的单参数版本。
ArtImageData flattenPremultipliedImage(ArtImageData image) =>
    artImageFromPremultiplied(image.width, image.height, image.rgba);

// ── 明度 ──────────────────────────────────────────────────────────────────

/// 感知亮度（Rec.601 权重），0–255。
int luminanceOf(int r, int g, int b) =>
    (r * 299 + g * 587 + b * 114 + 500) ~/ 1000;

ArtImageData grayscale(ArtImageData source) {
  final src = source.rgba;
  final out = Uint8List(src.length);
  for (var i = 0; i < src.length; i += 4) {
    final v = luminanceOf(src[i], src[i + 1], src[i + 2]);
    out[i] = v;
    out[i + 1] = v;
    out[i + 2] = v;
    out[i + 3] = 255;
  }
  return ArtImageData(width: source.width, height: source.height, rgba: out);
}

/// 明度第几档：把 0–255 等分成 [levels] 档，0 为最暗。
int valueLevelOf(int luminance, int levels) =>
    math.min(levels - 1, luminance * levels ~/ 256);

/// 灰度色阶：按亮度分成 [levels] 档，每档填充等距灰度（最暗 0、最亮 255）。
ArtImageData posterize(ArtImageData source, int levels) {
  final steps = levels.clamp(2, 256);
  final lut = Uint8List(256);
  for (var v = 0; v < 256; v++) {
    lut[v] = (valueLevelOf(v, steps) * 255 / (steps - 1)).round();
  }
  final src = source.rgba;
  final out = Uint8List(src.length);
  for (var i = 0; i < src.length; i += 4) {
    final v = lut[luminanceOf(src[i], src[i + 1], src[i + 2])];
    out[i] = v;
    out[i + 1] = v;
    out[i + 2] = v;
    out[i + 3] = 255;
  }
  return ArtImageData(width: source.width, height: source.height, rgba: out);
}

/// 各明度档所占面积比例（从暗到亮，合计为 1）。
List<double> valueDistribution(ArtImageData source, int levels) {
  final steps = levels.clamp(2, 256);
  final counts = List<int>.filled(steps, 0);
  final src = source.rgba;
  for (var i = 0; i < src.length; i += 4) {
    counts[valueLevelOf(luminanceOf(src[i], src[i + 1], src[i + 2]), steps)]++;
  }
  final total = source.pixelCount;
  return [for (final c in counts) c / total];
}

class PosterizeRequest {
  const PosterizeRequest(this.image, this.levels);

  final ArtImageData image;
  final int levels;
}

class PosterizeResult {
  const PosterizeResult(this.image, this.distribution);

  final ArtImageData image;
  final List<double> distribution;
}

/// 供 `compute` 调用：色阶图 + 明度分布一次算完。
PosterizeResult posterizeWithDistribution(PosterizeRequest request) {
  return PosterizeResult(
    posterize(request.image, request.levels),
    valueDistribution(request.image, request.levels),
  );
}

// ── 镜像 ──────────────────────────────────────────────────────────────────

ArtImageData flip(
  ArtImageData source, {
  bool horizontal = false,
  bool vertical = false,
}) {
  final w = source.width;
  final h = source.height;
  final src = source.rgba;
  final out = Uint8List(src.length);
  for (var y = 0; y < h; y++) {
    final sy = vertical ? h - 1 - y : y;
    for (var x = 0; x < w; x++) {
      final sx = horizontal ? w - 1 - x : x;
      final from = (sy * w + sx) * 4;
      final to = (y * w + x) * 4;
      out[to] = src[from];
      out[to + 1] = src[from + 1];
      out[to + 2] = src[from + 2];
      out[to + 3] = src[from + 3];
    }
  }
  return ArtImageData(width: w, height: h, rgba: out);
}

// ── 取色 ──────────────────────────────────────────────────────────────────

RgbColor pixelAt(ArtImageData image, int x, int y) {
  final cx = x.clamp(0, image.width - 1);
  final cy = y.clamp(0, image.height - 1);
  final i = (cy * image.width + cx) * 4;
  return RgbColor(image.rgba[i], image.rgba[i + 1], image.rgba[i + 2]);
}

/// 图片以 [BoxFit.contain] 居中显示在 `boxWidth × boxHeight` 的容器中时，
/// 把容器内坐标映射到图片像素；落在上下 / 左右留白处返回 null。
({int x, int y})? containPointToPixel({
  required double dx,
  required double dy,
  required double boxWidth,
  required double boxHeight,
  required int imageWidth,
  required int imageHeight,
}) {
  if (boxWidth <= 0 || boxHeight <= 0 || imageWidth <= 0 || imageHeight <= 0) {
    return null;
  }
  final scale = math.min(boxWidth / imageWidth, boxHeight / imageHeight);
  final left = (boxWidth - imageWidth * scale) / 2;
  final top = (boxHeight - imageHeight * scale) / 2;
  final u = (dx - left) / scale;
  final v = (dy - top) / scale;
  if (u < 0 || v < 0 || u >= imageWidth || v >= imageHeight) {
    return null;
  }
  return (
    x: u.floor().clamp(0, imageWidth - 1),
    y: v.floor().clamp(0, imageHeight - 1),
  );
}

/// [containPointToPixel] 的逆运算：像素中心在容器内的坐标。
({double dx, double dy}) pixelToContainPoint({
  required int x,
  required int y,
  required double boxWidth,
  required double boxHeight,
  required int imageWidth,
  required int imageHeight,
}) {
  final scale = math.min(boxWidth / imageWidth, boxHeight / imageHeight);
  final left = (boxWidth - imageWidth * scale) / 2;
  final top = (boxHeight - imageHeight * scale) / 2;
  return (dx: left + (x + 0.5) * scale, dy: top + (y + 0.5) * scale);
}

// ── 色卡 ──────────────────────────────────────────────────────────────────

class PaletteSwatch {
  const PaletteSwatch(this.color, this.ratio);

  final RgbColor color;

  /// 占画面比例 0–1。
  final double ratio;
}

/// 主色提取：均匀采样后做 k-means（k-means++ 初始化，固定种子保证结果稳定），
/// 合并相近色后兼顾面积与色差挑出 [count] 个（小面积的点缀色也能入选），
/// 最后把全部采样归入最近的入选色统计占比。
List<PaletteSwatch> extractPalette(
  ArtImageData image, {
  int count = 6,
  int maxSamples = 6000,
}) {
  final samples = sampleRgb(image.rgba, image.width, image.height, maxSamples);
  final n = samples.length ~/ 3;
  if (n == 0 || count <= 0) {
    return const <PaletteSwatch>[];
  }
  final clustered = kMeansRgb(samples, count * 2);
  final groups = <_Cluster>[
    for (var c = 0; c < clustered.centers.length; c++)
      if (clustered.sizes[c] > 0)
        _Cluster(clustered.centers[c], clustered.sizes[c].toDouble()),
  ];
  _mergeNear(groups, 20);
  final kept = _pickDistinct(groups, count);
  // 未入选色团的像素只计入最近入选色的占比，不改变入选色本身。
  final assignment = Int32List(n);
  assignNearest(samples, kept, assignment);
  final sizes = List<int>.filled(kept.length, 0);
  for (var i = 0; i < n; i++) {
    sizes[assignment[i]]++;
  }
  final swatches = <PaletteSwatch>[
    for (var c = 0; c < kept.length; c++)
      if (sizes[c] > 0)
        PaletteSwatch(
          RgbColor(
            kept[c][0].round().clamp(0, 255),
            kept[c][1].round().clamp(0, 255),
            kept[c][2].round().clamp(0, 255),
          ),
          sizes[c] / n,
        ),
  ];
  swatches.sort((a, b) => b.ratio.compareTo(a.ratio));
  return swatches;
}

class _Cluster {
  _Cluster(this.center, this.weight);

  List<double> center;
  double weight;
}

/// 先取面积最大的色团，之后每次取「√面积 × 与已选色最小色差」最大者。
List<List<double>> _pickDistinct(List<_Cluster> groups, int count) {
  final pool = [...groups]..sort((a, b) => b.weight.compareTo(a.weight));
  if (pool.length <= count) {
    return [for (final g in pool) g.center];
  }
  final picked = <_Cluster>[pool.removeAt(0)];
  while (picked.length < count && pool.isNotEmpty) {
    var bestIndex = 0;
    var bestScore = -1.0;
    for (var i = 0; i < pool.length; i++) {
      var nearest = double.infinity;
      for (final p in picked) {
        final dr = pool[i].center[0] - p.center[0];
        final dg = pool[i].center[1] - p.center[1];
        final db = pool[i].center[2] - p.center[2];
        nearest = math.min(nearest, math.sqrt(dr * dr + dg * dg + db * db));
      }
      final score = math.sqrt(pool[i].weight) * nearest;
      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }
    picked.add(pool.removeAt(bestIndex));
  }
  return [for (final g in picked) g.center];
}

/// 两两合并欧氏距离小于 [threshold] 的色团（按权重加权平均）。
void _mergeNear(List<_Cluster> groups, double threshold) {
  final limit = threshold * threshold;
  var merged = true;
  while (merged) {
    merged = false;
    for (var a = 0; a < groups.length && !merged; a++) {
      for (var b = a + 1; b < groups.length; b++) {
        final ca = groups[a].center;
        final cb = groups[b].center;
        final dr = ca[0] - cb[0];
        final dg = ca[1] - cb[1];
        final db = ca[2] - cb[2];
        if (dr * dr + dg * dg + db * db < limit) {
          final wa = groups[a].weight;
          final wb = groups[b].weight;
          final w = wa + wb;
          groups[a]
            ..center = [
              (ca[0] * wa + cb[0] * wb) / w,
              (ca[1] * wa + cb[1] * wb) / w,
              (ca[2] * wa + cb[2] * wb) / w,
            ]
            ..weight = w;
          groups.removeAt(b);
          merged = true;
          break;
        }
      }
    }
  }
}
