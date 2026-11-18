import 'dart:math' as math;

import '../data/gouache_pigments.dart';
import 'color_harmony.dart';
import 'image_ops.dart';

/// 水粉调色估算：色彩空间换算、色差和配方搜索。全是纯函数。
///
/// - 色差用 CIEDE2000（ΔE00），参考白 D65。
/// - 混色用「线性反射率按份数加权的几何平均」：每个通道
///   `mix = Π rᵢ^(wᵢ)`，`wᵢ` 是这一色的份数占比。它像减色混合一样越调越暗、
///   黄加蓝得绿，白提亮、黑压暗，但不考虑各色的着色力差异，所以只是估算。
/// - 配方：1 到 3 种颜料（白、黑也算一种），每种 1–4 份。

/// CIELab 颜色。
typedef LabColor = ({double l, double a, double b});

/// 匹配程度，按 ΔE00 分三档（见 [mixMatchOf]）。
enum MixMatch {
  close('接近'),
  rough('大致'),
  far('偏差较大');

  const MixMatch(this.label);

  final String label;
}

/// ΔE00 小于 5 算「接近」：并排比较能看出差别，但调色时已经够用。
const double kMixCloseDeltaE = 5;

/// ΔE00 小于 10 算「大致」：色相方向对，明度或纯度还要再调；再大是「偏差较大」。
const double kMixRoughDeltaE = 10;

MixMatch mixMatchOf(double deltaE) => deltaE < kMixCloseDeltaE
    ? MixMatch.close
    : deltaE < kMixRoughDeltaE
    ? MixMatch.rough
    : MixMatch.far;

// ───────────────────────── 色彩空间 ─────────────────────────

/// sRGB 8 位通道值换成线性值（0–1）。
double srgbToLinear(int channel) {
  final c = channel / 255;
  return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4) as double;
}

/// 线性值（0–1）换回 sRGB 8 位通道值，超出范围的截断。
int linearToSrgb(double value) {
  final v = value.clamp(0.0, 1.0);
  final c = v <= 0.0031308 ? v * 12.92 : 1.055 * math.pow(v, 1 / 2.4) - 0.055;
  return (c * 255).round().clamp(0, 255);
}

const double _xn = 0.95047, _yn = 1.0, _zn = 1.08883;
const double _delta = 6 / 29;

double _f(double t) => t > _delta * _delta * _delta
    ? math.pow(t, 1 / 3) as double
    : t / (3 * _delta * _delta) + 4 / 29;

double _fInv(double t) =>
    t > _delta ? t * t * t : 3 * _delta * _delta * (t - 4 / 29);

/// 线性 RGB 换成 Lab（D65）。
LabColor linearRgbToLab(double r, double g, double b) {
  final x = 0.4124564 * r + 0.3575761 * g + 0.1804375 * b;
  final y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b;
  final z = 0.0193339 * r + 0.1191920 * g + 0.9503041 * b;
  final fx = _f(x / _xn), fy = _f(y / _yn), fz = _f(z / _zn);
  return (l: 116 * fy - 16, a: 500 * (fx - fy), b: 200 * (fy - fz));
}

/// sRGB 换成 Lab（D65）。
LabColor rgbToLab(RgbColor color) => linearRgbToLab(
  srgbToLinear(color.r),
  srgbToLinear(color.g),
  srgbToLinear(color.b),
);

/// Lab 换回 sRGB，超出色域的通道截断。
RgbColor labToRgb(LabColor lab) {
  final fy = (lab.l + 16) / 116;
  final x = _xn * _fInv(fy + lab.a / 500);
  final y = _yn * _fInv(fy);
  final z = _zn * _fInv(fy - lab.b / 200);
  final r = 3.2404542 * x - 1.5371385 * y - 0.4985314 * z;
  final g = -0.9692660 * x + 1.8760108 * y + 0.0415560 * z;
  final b = 0.0556434 * x - 0.2040259 * y + 1.0572252 * z;
  return RgbColor(linearToSrgb(r), linearToSrgb(g), linearToSrgb(b));
}

/// CIE76 色差（Lab 欧氏距离），只用来粗筛。
double deltaE76(LabColor p, LabColor q) {
  final dl = p.l - q.l, da = p.a - q.a, db = p.b - q.b;
  return math.sqrt(dl * dl + da * da + db * db);
}

double _deg(double rad) => rad * 180 / math.pi;
double _rad(double deg) => deg * math.pi / 180;

/// CIEDE2000 色差（Sharma、Wu、Dalal 2005 的写法，kL = kC = kH = 1）。
double deltaE2000(LabColor p, LabColor q) {
  final c1 = math.sqrt(p.a * p.a + p.b * p.b);
  final c2 = math.sqrt(q.a * q.a + q.b * q.b);
  final cBar = (c1 + c2) / 2;
  final cBar7 = math.pow(cBar, 7);
  final g = 0.5 * (1 - math.sqrt(cBar7 / (cBar7 + 6103515625))); // 25^7
  final a1 = (1 + g) * p.a, a2 = (1 + g) * q.a;
  final c1p = math.sqrt(a1 * a1 + p.b * p.b);
  final c2p = math.sqrt(a2 * a2 + q.b * q.b);
  double hueOf(double b, double a) {
    if (a == 0 && b == 0) return 0;
    final h = _deg(math.atan2(b, a));
    return h < 0 ? h + 360 : h;
  }

  final h1p = hueOf(p.b, a1), h2p = hueOf(q.b, a2);
  final dLp = q.l - p.l;
  final dCp = c2p - c1p;
  double dhp;
  if (c1p * c2p == 0) {
    dhp = 0;
  } else if ((h2p - h1p).abs() <= 180) {
    dhp = h2p - h1p;
  } else if (h2p - h1p > 180) {
    dhp = h2p - h1p - 360;
  } else {
    dhp = h2p - h1p + 360;
  }
  final dHp = 2 * math.sqrt(c1p * c2p) * math.sin(_rad(dhp / 2));
  final lBarP = (p.l + q.l) / 2;
  final cBarP = (c1p + c2p) / 2;
  double hBarP;
  if (c1p * c2p == 0) {
    hBarP = h1p + h2p;
  } else if ((h1p - h2p).abs() <= 180) {
    hBarP = (h1p + h2p) / 2;
  } else if (h1p + h2p < 360) {
    hBarP = (h1p + h2p + 360) / 2;
  } else {
    hBarP = (h1p + h2p - 360) / 2;
  }
  final t =
      1 -
      0.17 * math.cos(_rad(hBarP - 30)) +
      0.24 * math.cos(_rad(2 * hBarP)) +
      0.32 * math.cos(_rad(3 * hBarP + 6)) -
      0.20 * math.cos(_rad(4 * hBarP - 63));
  final dTheta = 30 * math.exp(-math.pow((hBarP - 275) / 25, 2));
  final cBarP7 = math.pow(cBarP, 7);
  final rc = 2 * math.sqrt(cBarP7 / (cBarP7 + 6103515625));
  final l50 = (lBarP - 50) * (lBarP - 50);
  final sl = 1 + 0.015 * l50 / math.sqrt(20 + l50);
  final sc = 1 + 0.045 * cBarP;
  final sh = 1 + 0.015 * cBarP * t;
  final rt = -math.sin(_rad(2 * dTheta)) * rc;
  final lTerm = dLp / sl, cTerm = dCp / sc, hTerm = dHp / sh;
  return math.sqrt(
    lTerm * lTerm + cTerm * cTerm + hTerm * hTerm + rt * cTerm * hTerm,
  );
}

// ───────────────────────── 混色与配方 ─────────────────────────

/// 配方里的一种颜料和份数。
class MixPart {
  const MixPart(this.pigment, this.parts);

  final GouachePigment pigment;
  final int parts;
}

/// 一个调色配方：用哪些颜料各几份、估算调出的颜色和与目标的色差。
class GouacheRecipe {
  const GouacheRecipe({
    required this.parts,
    required this.mixed,
    required this.deltaE,
  });

  /// 份数从多到少排列。
  final List<MixPart> parts;
  final RgbColor mixed;

  /// 与目标色的 ΔE00。
  final double deltaE;

  MixMatch get match => mixMatchOf(deltaE);

  /// 「群青 2 份 + 赭石 1 份 + 白 1 份」；只有一种时是「直接用群青」。
  String get text => segments.join(' + ');

  /// [text] 按颜料拆开的几段（「群青 2 份」「赭石 1 份」）。
  List<String> get segments => parts.length == 1
      ? ['直接用${parts.single.pigment.name}']
      : [for (final p in parts) '${p.pigment.name} ${p.parts} 份'];
}

/// 反射率的下限，避免某个通道为 0 时几何平均整体变成 0。
const double _minReflectance = 0.004;

double _logReflectance(int channel) =>
    math.log(math.max(srgbToLinear(channel), _minReflectance));

/// 估算按份数混合几种颜料后的颜色。
RgbColor mixPigments(List<MixPart> parts) {
  final total = parts.fold<int>(0, (sum, p) => sum + p.parts);
  var r = 0.0, g = 0.0, b = 0.0;
  for (final p in parts) {
    final w = p.parts / total;
    r += w * _logReflectance(p.pigment.r);
    g += w * _logReflectance(p.pigment.g);
    b += w * _logReflectance(p.pigment.b);
  }
  return RgbColor(
    linearToSrgb(math.exp(r)),
    linearToSrgb(math.exp(g)),
    linearToSrgb(math.exp(b)),
  );
}

/// 混色模型本身的误差量级：排序时 ΔE00 低于这个数一律按这个数算，几个配方都
/// 足够接近时由用料多少决定先后，不为模型分辨不出的差别多加颜料。
const double kMixModelTolerance = 3;

/// 多用一种颜料要换来的色差改善：小于这个数时宁可少用一种。
const double kExtraPigmentPenalty = 1.5;

/// 配方里每有一对互为对比色的纯色颜料（美术色环上相差超过
/// [kComplementHueGap] 度，土色和黑白不算）加的分：对比色互调容易调脏，
/// 同样接近时优先给同类色或土色的配方。
const double kComplementPenalty = 1.5;
const double kComplementHueGap = 135;

/// 三种颜料都是纯色（没有土色、白或黑）时加的分：常见的调法是一个主色加一个
/// 调整色，再用白、黑或土色调明度和纯度。
const double kThreeHuesPenalty = 1.0;

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

/// 颜料在美术色环上的色相；土色和黑白返回 null。
double? _artistHueOf(GouachePigment p) {
  if (p.earth || p.isWhite || p.isBlack) return null;
  return opticalToArtistHue(RgbColor(p.r, p.g, p.b).toHsb().hue);
}

/// 给目标色找最多 [count] 个调色配方，各用一组不同的颜料，按「色差（不低于
/// [kMixModelTolerance]）+ 每多一种
/// 颜料 [kExtraPigmentPenalty] + 每对对比色 [kComplementPenalty] + 三种纯色
/// [kThreeHuesPenalty]」从好到差排列。
///
/// 先对每组颜料按 CIE76 找出最合适的份数（粗筛，约 13 万次估算），再用 CIEDE2000
/// 给每组的最佳份数打分。桌面端约几十毫秒，界面里放进 `compute` 调用。
List<GouacheRecipe> gouacheRecipesFor(
  RgbColor target, {
  int count = 3,
  List<GouachePigment> pigments = kGouachePigments,
}) {
  final n = pigments.length;
  final logs = [
    for (final p in pigments)
      [_logReflectance(p.r), _logReflectance(p.g), _logReflectance(p.b)],
  ];
  final goal = rgbToLab(target);
  final hues = [for (final p in pigments) _artistHueOf(p)];
  int clashes(List<int> set) {
    var count = 0;
    for (var i = 0; i < set.length; i++) {
      for (var j = i + 1; j < set.length; j++) {
        final a = hues[set[i]], b = hues[set[j]];
        if (a == null || b == null) continue;
        final gap = (a - b).abs() % 360;
        if (math.min(gap, 360 - gap) > kComplementHueGap) count++;
      }
    }
    return count;
  }

  // 每组颜料（按下标）记下 CIE76 最小的份数。
  final best = <int, ({List<int> set, List<int> parts, double de})>{};
  void consider(List<int> set, List<int> parts) {
    final total = parts.fold<int>(0, (s, v) => s + v);
    var r = 0.0, g = 0.0, b = 0.0;
    for (var i = 0; i < set.length; i++) {
      final w = parts[i] / total;
      final l = logs[set[i]];
      r += w * l[0];
      g += w * l[1];
      b += w * l[2];
    }
    final de = deltaE76(
      linearRgbToLab(math.exp(r), math.exp(g), math.exp(b)),
      goal,
    );
    final key = set.fold<int>(0, (k, i) => k * 64 + i + 1);
    final current = best[key];
    if (current == null || de < current.de) {
      best[key] = (set: set, parts: List.of(parts), de: de);
    }
  }

  for (var i = 0; i < n; i++) {
    consider([i], const [1]);
  }
  final pairRatios = [
    for (var a = 1; a <= 4; a++)
      for (var b = 1; b <= 4; b++)
        if (_gcd(a, b) == 1) [a, b],
  ];
  final tripleRatios = [
    for (var a = 1; a <= 4; a++)
      for (var b = 1; b <= 4; b++)
        for (var c = 1; c <= 4; c++)
          if (_gcd(_gcd(a, b), c) == 1) [a, b, c],
  ];
  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      final pair = [i, j];
      for (final ratio in pairRatios) {
        consider(pair, ratio);
      }
      for (var k = j + 1; k < n; k++) {
        final triple = [i, j, k];
        for (final ratio in tripleRatios) {
          consider(triple, ratio);
        }
      }
    }
  }

  final scored = <({GouacheRecipe recipe, double score})>[];
  for (final found in best.values) {
    final set = found.set;
    final order = [for (var i = 0; i < set.length; i++) i]
      ..sort((x, y) {
        final byParts = found.parts[y].compareTo(found.parts[x]);
        return byParts != 0 ? byParts : set[x].compareTo(set[y]);
      });
    final parts = [
      for (final i in order) MixPart(pigments[set[i]], found.parts[i]),
    ];
    final mixed = mixPigments(parts);
    final de = deltaE2000(rgbToLab(mixed), goal);
    scored.add((
      recipe: GouacheRecipe(parts: parts, mixed: mixed, deltaE: de),
      score:
          math.max(de, kMixModelTolerance) +
          kExtraPigmentPenalty * (set.length - 1) +
          kComplementPenalty * clashes(set) +
          (set.length == 3 && set.every((i) => hues[i] != null)
              ? kThreeHuesPenalty
              : 0),
    ));
  }
  scored.sort((x, y) {
    final byScore = x.score.compareTo(y.score);
    return byScore != 0 ? byScore : x.recipe.deltaE.compareTo(y.recipe.deltaE);
  });
  return [for (final s in scored.take(count)) s.recipe];
}
