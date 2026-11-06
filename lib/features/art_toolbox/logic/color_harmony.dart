import 'dart:math' as math;

import 'image_ops.dart';

/// 色环：美术色环以红黄蓝为三原色（伊顿十二色相环），光学色环即 HSB 色相环。
enum ColorWheelKind {
  artist('美术色环', '红黄蓝三原色，补色关系与水粉调色一致：红对绿、黄对紫、蓝对橙'),
  optical('光学色环', '红绿蓝三原色，与屏幕显示和设计软件的色相一致');

  const ColorWheelKind(this.label, this.description);

  final String label;
  final String description;
}

enum HarmonyScheme {
  complementary('互补色', '色环上相对的两色，对比强烈', <double>[0, 180]),
  analogous('邻近色', '色环上相邻 30° 的颜色，统一柔和', <double>[0, -30, 30]),
  triadic('三角色', '色环上等距的三色，鲜明而均衡', <double>[0, 120, 240]),
  splitComplementary('分裂互补', '补色两侧各 30°，对比比互补色缓和', <double>[0, 150, 210]);

  const HarmonyScheme(this.label, this.description, this.offsets);

  final String label;
  final String description;

  /// 相对基色的色环角度，第一个恒为 0（基色）。
  final List<double> offsets;
}

/// HSB 色相与美术色环角度的对应节点：橙 30°→60°、黄 60°→120°、绿 120°→180°、
/// 蓝 240°→240°、紫 280°→300°，中间线性插值，两个方向互为反函数。
const _opticalStops = <double>[0, 30, 60, 120, 240, 280, 360];
const _artistStops = <double>[0, 60, 120, 180, 240, 300, 360];

double normalizeHue(double hue) {
  final h = hue % 360;
  return h < 0 ? h + 360 : h;
}

double _interpolate(double value, List<double> from, List<double> to) {
  final h = normalizeHue(value);
  for (var i = 0; i < from.length - 1; i++) {
    if (h <= from[i + 1]) {
      final t = (h - from[i]) / (from[i + 1] - from[i]);
      return to[i] + t * (to[i + 1] - to[i]);
    }
  }
  return to.last;
}

/// HSB 色相 → 美术色环角度。
double opticalToArtistHue(double hue) =>
    normalizeHue(_interpolate(hue, _opticalStops, _artistStops));

/// 美术色环角度 → HSB 色相。
double artistToOpticalHue(double hue) =>
    normalizeHue(_interpolate(hue, _artistStops, _opticalStops));

/// HSB 色相在指定色环上的角度。
double wheelHueOf(double opticalHue, ColorWheelKind wheel) =>
    wheel == ColorWheelKind.artist
    ? opticalToArtistHue(opticalHue)
    : normalizeHue(opticalHue);

/// 色环角度换回 HSB 色相。
double opticalHueOf(double wheelHue, ColorWheelKind wheel) =>
    wheel == ColorWheelKind.artist
    ? artistToOpticalHue(wheelHue)
    : normalizeHue(wheelHue);

/// 色相 0–360，饱和度、明度 0–1。
RgbColor hsbToRgb(double hue, double saturation, double brightness) {
  final h = normalizeHue(hue);
  final s = saturation.clamp(0.0, 1.0);
  final v = brightness.clamp(0.0, 1.0);
  final c = v * s;
  final x = c * (1 - ((h / 60) % 2 - 1).abs());
  final m = v - c;
  final (r, g, b) = switch (h ~/ 60) {
    0 => (c, x, 0.0),
    1 => (x, c, 0.0),
    2 => (0.0, c, x),
    3 => (0.0, x, c),
    4 => (x, 0.0, c),
    _ => (c, 0.0, x),
  };
  int to255(double value) => ((value + m) * 255).round().clamp(0, 255);
  return RgbColor(to255(r), to255(g), to255(b));
}

class HarmonySwatch {
  const HarmonySwatch(this.color, this.wheelHue, this.offset);

  final RgbColor color;

  /// 在所选色环上的角度 0–360。
  final double wheelHue;

  /// 相对基色的角度，基色为 0。
  final double offset;

  bool get isBase => offset == 0;
}

/// 以 [base] 为基色，在色环上按配色方案旋转色相，饱和度与明度保持不变。
List<HarmonySwatch> harmonyOf(
  RgbColor base,
  HarmonyScheme scheme, {
  ColorWheelKind wheel = ColorWheelKind.artist,
}) {
  final hsb = base.toHsb();
  final baseWheel = wheelHueOf(hsb.hue, wheel);
  return [
    for (final offset in scheme.offsets)
      if (offset == 0)
        HarmonySwatch(base, baseWheel, 0)
      else
        HarmonySwatch(
          hsbToRgb(
            opticalHueOf(baseWheel + offset, wheel),
            hsb.saturation,
            hsb.brightness,
          ),
          normalizeHue(baseWheel + offset),
          offset,
        ),
  ];
}

/// 伊顿十二色相环的名称，按美术色环每 30° 一个。
const kTwelveHueNames = <String>[
  '红',
  '红橙',
  '橙',
  '黄橙',
  '黄',
  '黄绿',
  '绿',
  '蓝绿',
  '蓝',
  '蓝紫',
  '紫',
  '红紫',
];

/// 色彩三要素：色相、明度、纯度。
class ColorAttributes {
  const ColorAttributes({
    required this.hue,
    required this.hueName,
    required this.value,
    required this.chroma,
  });

  /// HSB 色相 0–360。
  final double hue;

  /// 十二色相名称；色度很低时为「黑色」「白色」「灰色」。
  final String hueName;

  /// 明度 0–100：感知亮度，黄色明度高、蓝紫色明度低。
  final int value;

  /// 纯度 0–100：最大与最小分量之差，加黑、加白、加灰都会降低纯度。
  final int chroma;

  bool get achromatic => chroma < 6;
}

ColorAttributes colorAttributesOf(RgbColor color) {
  final hsb = color.toHsb();
  final maxC = math.max(color.r, math.max(color.g, color.b));
  final minC = math.min(color.r, math.min(color.g, color.b));
  final chroma = ((maxC - minC) * 100 / 255).round();
  final value = (luminanceOf(color.r, color.g, color.b) * 100 / 255).round();
  final String name;
  if (chroma < 6) {
    name = value >= 88 ? '白色' : (value <= 12 ? '黑色' : '灰色');
  } else {
    final index = (opticalToArtistHue(hsb.hue) / 30).round() % 12;
    name = kTwelveHueNames[index];
  }
  return ColorAttributes(
    hue: hsb.hue,
    hueName: name,
    value: value,
    chroma: chroma,
  );
}
