import 'dart:math' as math;
import 'dart:typed_data';

import 'image_filters.dart';
import 'image_ops.dart';
import 'kmeans.dart';

/// 最大余数法：把各部分换算成合计正好 100 的整数百分比（全为 0 时返回全 0）。
List<int> percentagesOf(List<num> parts) {
  final total = parts.fold<double>(0, (sum, v) => sum + math.max(0, v));
  if (total <= 0) {
    return List<int>.filled(parts.length, 0);
  }
  final exact = [for (final v in parts) math.max(0, v) * 100 / total];
  final result = [for (final v in exact) v.floor()];
  var remaining = 100 - result.fold<int>(0, (sum, v) => sum + v);
  final order = List<int>.generate(parts.length, (i) => i)
    ..sort((a, b) {
      final byFraction = (exact[b] - result[b]).compareTo(exact[a] - result[a]);
      return byFraction != 0 ? byFraction : a.compareTo(b);
    });
  for (var k = 0; remaining > 0 && k < order.length; k++, remaining--) {
    result[order[k]]++;
  }
  return result;
}

// ── 冷暖分布 ─────────────────────────────────────────────────────────────

/// 色度（最大分量减最小分量）低于该值算作中性灰的默认门槛。
const int kDefaultNeutralChroma = 24;

/// 单个像素的冷暖：很暗或色度很低为中性；其余按色相，110°–300°（绿、青、蓝、蓝紫）为冷，
/// 其余（红、橙、黄、黄绿、紫红）为暖，与 [describeTemperature] 的色相划分一致。
ColorTemperature temperatureOf(
  int r,
  int g,
  int b, {
  int neutralChroma = kDefaultNeutralChroma,
}) {
  final maxC = math.max(r, math.max(g, b));
  final minC = math.min(r, math.min(g, b));
  final chroma = maxC - minC;
  if (maxC < 32 || chroma < neutralChroma || chroma == 0) {
    return ColorTemperature.neutral;
  }
  double hue;
  if (maxC == r) {
    hue = 60 * (((g - b) / chroma) % 6);
  } else if (maxC == g) {
    hue = 60 * ((b - r) / chroma + 2);
  } else {
    hue = 60 * ((r - g) / chroma + 4);
  }
  if (hue < 0) {
    hue += 360;
  }
  return hue >= 110 && hue < 300
      ? ColorTemperature.cool
      : ColorTemperature.warm;
}

/// 冷暖图配色：暖橙、冷蓝、中性灰。
const kWarmMapColor = RgbColor(240, 140, 50);
const kCoolMapColor = RgbColor(60, 125, 225);
const kNeutralMapColor = RgbColor(160, 160, 160);

class TemperatureRequest {
  const TemperatureRequest(
    this.image, {
    this.neutralChroma = kDefaultNeutralChroma,
    this.keepShading = true,
  });

  final ArtImageData image;
  final int neutralChroma;

  /// 保留原图明暗：颜色按亮度加深或提亮，便于对照形体。
  final bool keepShading;
}

class TemperatureResult {
  const TemperatureResult(this.image, this.warm, this.cool, this.neutral);

  final ArtImageData image;

  /// 面积占比 0–1，三者合计为 1。
  final double warm;
  final double cool;
  final double neutral;

  /// 合计 100 的整数百分比：暖、冷、中性。
  List<int> get percents => percentagesOf([warm, cool, neutral]);
}

TemperatureResult temperatureMap(TemperatureRequest request) {
  final source = request.image;
  final src = source.rgba;
  final out = Uint8List(src.length);
  var warm = 0;
  var cool = 0;
  var neutral = 0;
  for (var i = 0; i < src.length; i += 4) {
    final r = src[i];
    final g = src[i + 1];
    final b = src[i + 2];
    final kind = temperatureOf(r, g, b, neutralChroma: request.neutralChroma);
    final RgbColor base;
    switch (kind) {
      case ColorTemperature.warm:
        warm++;
        base = kWarmMapColor;
      case ColorTemperature.cool:
        cool++;
        base = kCoolMapColor;
      case ColorTemperature.neutral:
        neutral++;
        base = kNeutralMapColor;
    }
    if (!request.keepShading) {
      out[i] = base.r;
      out[i + 1] = base.g;
      out[i + 2] = base.b;
    } else {
      final l = luminanceOf(r, g, b) / 255;
      if (kind == ColorTemperature.neutral) {
        final v = (40 + l * 185).round();
        out[i] = v;
        out[i + 1] = v;
        out[i + 2] = v;
      } else {
        out[i] = _shade(base.r, l);
        out[i + 1] = _shade(base.g, l);
        out[i + 2] = _shade(base.b, l);
      }
    }
    out[i + 3] = 255;
  }
  final total = source.pixelCount;
  return TemperatureResult(
    ArtImageData(width: source.width, height: source.height, rgba: out),
    warm / total,
    cool / total,
    neutral / total,
  );
}

/// 亮度 0 时为底色的 30%，0.5 时为底色本身，1 时向白色提亮 65%。
int _shade(int base, double l) {
  final v = l < 0.5
      ? base * (0.3 + 1.4 * l)
      : base + (255 - base) * (l - 0.5) * 1.3;
  return v.round().clamp(0, 255);
}

/// 冷暖面积的一句话判断（比例 0–1）。
String temperatureSummary(double warm, double cool, double neutral) {
  if (neutral >= 0.6) {
    return '中性灰占大部分面积，色彩倾向较弱，可以加强冷暖对比让画面更有色彩感';
  }
  if (warm >= 0.3 && warm >= cool * 1.5) {
    return '画面整体偏暖，可在暗部、投影和背景里安排冷色，与暖色形成对比';
  }
  if (cool >= 0.3 && cool >= warm * 1.5) {
    return '画面整体偏冷，可在受光面或主体上安排暖色，避免画面发闷';
  }
  return '冷暖面积比较接近，建议明确主色调，让一方占主导、另一方作对比';
}

// ── 色块简化 ─────────────────────────────────────────────────────────────

class SimplifyRequest {
  const SimplifyRequest(this.image, this.colors, {this.smooth = 1});

  final ArtImageData image;

  /// 目标颜色数 3–12。
  final int colors;

  /// 聚类前的模糊半径，用于合并细碎色点。
  final int smooth;
}

class SimplifyResult {
  const SimplifyResult(this.image, this.swatches);

  final ArtImageData image;

  /// 按面积从大到小，[PaletteSwatch.ratio] 合计为 1。
  final List<PaletteSwatch> swatches;

  /// 合计 100 的整数百分比，与 [swatches] 一一对应。
  List<int> get percents => percentagesOf([for (final s in swatches) s.ratio]);
}

/// 色块简化：k-means 聚出至多 [SimplifyRequest.colors] 种颜色，每个像素换成最近的颜色。
/// 像素归类用 15 位颜色查找表，工作图上的耗时与颜色数基本无关。
SimplifyResult simplifyColors(SimplifyRequest request) {
  final source = request.smooth > 0
      ? blurImage(BlurRequest(request.image, request.smooth))
      : request.image;
  final k = request.colors.clamp(1, 32);
  final samples = sampleRgb(source.rgba, source.width, source.height, 9000);
  if (samples.isEmpty) {
    return SimplifyResult(source, const <PaletteSwatch>[]);
  }
  final clustered = kMeansRgb(samples, k, seed: 11, maxIterations: 20);
  final centers = <RgbColor>[
    for (var c = 0; c < clustered.centers.length; c++)
      if (clustered.sizes[c] > 0)
        RgbColor(
          clustered.centers[c][0].round().clamp(0, 255),
          clustered.centers[c][1].round().clamp(0, 255),
          clustered.centers[c][2].round().clamp(0, 255),
        ),
  ];
  final lut = Uint8List(1 << 15);
  for (var key = 0; key < lut.length; key++) {
    final r = ((key >> 10) & 31) * 8 + 4;
    final g = ((key >> 5) & 31) * 8 + 4;
    final b = (key & 31) * 8 + 4;
    var best = 0;
    var bestD = 1 << 30;
    for (var c = 0; c < centers.length; c++) {
      final dr = r - centers[c].r;
      final dg = g - centers[c].g;
      final db = b - centers[c].b;
      final d = dr * dr + dg * dg + db * db;
      if (d < bestD) {
        bestD = d;
        best = c;
      }
    }
    lut[key] = best;
  }
  final src = source.rgba;
  final out = Uint8List(src.length);
  final counts = List<int>.filled(centers.length, 0);
  for (var i = 0; i < src.length; i += 4) {
    final c =
        lut[((src[i] >> 3) << 10) | ((src[i + 1] >> 3) << 5) | (src[i + 2] >> 3)];
    counts[c]++;
    final color = centers[c];
    out[i] = color.r;
    out[i + 1] = color.g;
    out[i + 2] = color.b;
    out[i + 3] = 255;
  }
  final total = source.pixelCount;
  final swatches = <PaletteSwatch>[
    for (var c = 0; c < centers.length; c++)
      if (counts[c] > 0) PaletteSwatch(centers[c], counts[c] / total),
  ]..sort((a, b) => b.ratio.compareTo(a.ratio));
  return SimplifyResult(
    ArtImageData(width: source.width, height: source.height, rgba: out),
    swatches,
  );
}
