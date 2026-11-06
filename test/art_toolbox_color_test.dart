import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/logic/color_analysis.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/logic/color_harmony.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/logic/image_ops.dart';

ArtImageData _image(int width, int height, List<List<int>> pixels) {
  final rgba = Uint8List(width * height * 4);
  for (var i = 0; i < pixels.length; i++) {
    rgba[i * 4] = pixels[i][0];
    rgba[i * 4 + 1] = pixels[i][1];
    rgba[i * 4 + 2] = pixels[i][2];
    rgba[i * 4 + 3] = 255;
  }
  return ArtImageData(width: width, height: height, rgba: rgba);
}

int _sum(List<int> values) => values.fold(0, (a, b) => a + b);

void main() {
  group('percentages', () {
    test('largest remainder keeps the total at 100', () {
      expect(percentagesOf([1, 1, 1]), [34, 33, 33]);
      expect(percentagesOf([0.5, 0.3, 0.2]), [50, 30, 20]);
      expect(percentagesOf([2, 1]), [67, 33]);
      expect(percentagesOf([0, 0]), [0, 0]);
      final random = math.Random(3);
      for (var round = 0; round < 50; round++) {
        final parts = [for (var i = 0; i < 1 + random.nextInt(11); i++) random.nextDouble()];
        expect(_sum(percentagesOf(parts)), 100);
      }
    });
  });

  group('warm / cool', () {
    test('classifies familiar colors', () {
      const warm = [
        [220, 30, 40], // 红
        [240, 140, 40], // 橙
        [230, 210, 40], // 黄
        [150, 200, 50], // 黄绿
        [200, 40, 150], // 紫红
      ];
      const cool = [
        [40, 160, 60], // 绿
        [40, 180, 200], // 青
        [40, 90, 200], // 蓝
        [120, 60, 200], // 蓝紫
      ];
      const neutral = [
        [128, 128, 128],
        [20, 10, 30],
        [250, 250, 248],
        [140, 136, 130],
      ];
      for (final c in warm) {
        expect(temperatureOf(c[0], c[1], c[2]), ColorTemperature.warm, reason: '$c');
      }
      for (final c in cool) {
        expect(temperatureOf(c[0], c[1], c[2]), ColorTemperature.cool, reason: '$c');
      }
      for (final c in neutral) {
        expect(temperatureOf(c[0], c[1], c[2]), ColorTemperature.neutral, reason: '$c');
      }
      expect(
        temperatureOf(140, 136, 130, neutralChroma: 5),
        ColorTemperature.warm,
      );
    });

    test('agrees with the single-color description for saturated colors', () {
      for (var hue = 0; hue < 360; hue += 5) {
        final color = hsbToRgb(hue.toDouble(), 0.8, 0.9);
        expect(
          temperatureOf(color.r, color.g, color.b),
          describeTemperature(color).temperature,
          reason: 'hue $hue',
        );
      }
    });

    test('map counts areas and paints orange / blue / grey', () {
      final result = temperatureMap(
        TemperatureRequest(
          _image(2, 2, [
            [220, 30, 40],
            [40, 90, 200],
            [128, 128, 128],
            [240, 140, 40],
          ]),
          keepShading: false,
        ),
      );
      expect(result.warm, 0.5);
      expect(result.cool, 0.25);
      expect(result.neutral, 0.25);
      expect(result.percents, [50, 25, 25]);
      expect(pixelAt(result.image, 0, 0), kWarmMapColor);
      expect(pixelAt(result.image, 1, 0), kCoolMapColor);
      expect(pixelAt(result.image, 0, 1), kNeutralMapColor);
    });

    test('shading keeps light and dark apart', () {
      final result = temperatureMap(
        TemperatureRequest(
          _image(2, 1, [
            [120, 20, 10],
            [255, 200, 150],
          ]),
        ),
      );
      final dark = pixelAt(result.image, 0, 0);
      final light = pixelAt(result.image, 1, 0);
      expect(luminanceOf(dark.r, dark.g, dark.b), lessThan(luminanceOf(light.r, light.g, light.b)));
      expect(dark.r, greaterThan(dark.b));
    });

    test('summary reflects the dominant temperature', () {
      expect(temperatureSummary(0.6, 0.2, 0.2), contains('偏暖'));
      expect(temperatureSummary(0.1, 0.5, 0.4), contains('偏冷'));
      expect(temperatureSummary(0.1, 0.1, 0.8), contains('中性灰'));
      expect(temperatureSummary(0.35, 0.3, 0.35), contains('接近'));
    });
  });

  group('color simplify', () {
    const red = [220, 30, 40];
    const blue = [30, 60, 200];
    const white = [250, 250, 250];
    final source = _image(10, 10, [
      for (var i = 0; i < 100; i++) i < 50 ? red : (i < 80 ? blue : white),
    ]);

    test('reduces to the requested colors with exact area shares', () {
      final result = simplifyColors(SimplifyRequest(source, 3, smooth: 0));
      expect(result.swatches.map((s) => s.color), const [
        RgbColor(220, 30, 40),
        RgbColor(30, 60, 200),
        RgbColor(250, 250, 250),
      ]);
      expect(result.percents, [50, 30, 20]);
      expect(_sum(result.percents), 100);
      final colors = <RgbColor>{
        for (var y = 0; y < 10; y++)
          for (var x = 0; x < 10; x++) pixelAt(result.image, x, y),
      };
      expect(colors, hasLength(3));
    });

    test('never invents colors that are not in the picture', () {
      final result = simplifyColors(SimplifyRequest(source, 8, smooth: 0));
      expect(result.swatches, hasLength(3));
    });

    test('percentages of a gradient still sum to 100', () {
      final gradient = _image(64, 4, [
        for (var y = 0; y < 4; y++)
          for (var x = 0; x < 64; x++) [x * 4, 255 - x * 4, (x * 9) % 256],
      ]);
      for (final count in [3, 5, 12]) {
        final result = simplifyColors(SimplifyRequest(gradient, count));
        expect(result.swatches.length, lessThanOrEqualTo(count));
        expect(_sum(result.percents), 100);
        expect(
          result.swatches.fold<double>(0, (sum, s) => sum + s.ratio),
          closeTo(1, 1e-9),
        );
        for (var i = 1; i < result.swatches.length; i++) {
          expect(result.swatches[i - 1].ratio, greaterThanOrEqualTo(result.swatches[i].ratio));
        }
      }
    });
  });

  group('harmony', () {
    test('scheme offsets', () {
      expect(HarmonyScheme.complementary.offsets, [0, 180]);
      expect(HarmonyScheme.analogous.offsets, [0, -30, 30]);
      expect(HarmonyScheme.triadic.offsets, [0, 120, 240]);
      expect(HarmonyScheme.splitComplementary.offsets, [0, 150, 210]);
    });

    test('wheel positions follow the offsets on both wheels', () {
      const base = RgbColor(200, 120, 40);
      for (final wheel in ColorWheelKind.values) {
        for (final scheme in HarmonyScheme.values) {
          final swatches = harmonyOf(base, scheme, wheel: wheel);
          final baseHue = swatches.first.wheelHue;
          expect(swatches.first.isBase, isTrue);
          expect(swatches.first.color, base);
          for (var i = 0; i < swatches.length; i++) {
            expect(
              swatches[i].wheelHue,
              closeTo(normalizeHue(baseHue + scheme.offsets[i]), 1e-9),
            );
          }
        }
      }
    });

    test('optical complement of red is cyan', () {
      final pair = harmonyOf(
        const RgbColor(255, 0, 0),
        HarmonyScheme.complementary,
        wheel: ColorWheelKind.optical,
      );
      expect(pair.last.color, const RgbColor(0, 255, 255));
    });

    test('artist wheel pairs red-green, yellow-purple, blue-orange', () {
      RgbColor complementOf(RgbColor c) =>
          harmonyOf(c, HarmonyScheme.complementary).last.color;
      expect(complementOf(const RgbColor(255, 0, 0)), const RgbColor(0, 255, 0));
      expect(complementOf(const RgbColor(255, 255, 0)), const RgbColor(170, 0, 255));
      expect(complementOf(const RgbColor(0, 0, 255)), const RgbColor(255, 128, 0));
      final triad = harmonyOf(const RgbColor(255, 0, 0), HarmonyScheme.triadic);
      expect(triad.map((s) => s.color), const [
        RgbColor(255, 0, 0),
        RgbColor(255, 255, 0),
        RgbColor(0, 0, 255),
      ]);
    });

    test('keeps saturation and brightness of the base color', () {
      const base = RgbColor(180, 90, 60);
      final hsb = base.toHsb();
      for (final swatch in harmonyOf(base, HarmonyScheme.splitComplementary)) {
        final other = swatch.color.toHsb();
        expect(other.saturation, closeTo(hsb.saturation, 0.02));
        expect(other.brightness, closeTo(hsb.brightness, 0.01));
      }
    });

    test('artist and optical hue mappings are inverse', () {
      expect(opticalToArtistHue(30), closeTo(60, 1e-9));
      expect(opticalToArtistHue(60), closeTo(120, 1e-9));
      expect(artistToOpticalHue(300), closeTo(280, 1e-9));
      for (var h = 0.0; h < 360; h += 7) {
        expect(artistToOpticalHue(opticalToArtistHue(h)), closeTo(h, 1e-9));
      }
    });

    test('hsb to rgb', () {
      expect(hsbToRgb(0, 1, 1), const RgbColor(255, 0, 0));
      expect(hsbToRgb(120, 1, 1), const RgbColor(0, 255, 0));
      expect(hsbToRgb(240, 1, 1), const RgbColor(0, 0, 255));
      expect(hsbToRgb(30, 1, 1), const RgbColor(255, 128, 0));
      expect(hsbToRgb(-60, 1, 1), const RgbColor(255, 0, 255));
      expect(hsbToRgb(0, 0, 0.5), const RgbColor(128, 128, 128));
    });

    test('hue, value and chroma attributes', () {
      final red = colorAttributesOf(const RgbColor(255, 0, 0));
      expect((red.hueName, red.value, red.chroma), ('红', 30, 100));
      final yellow = colorAttributesOf(const RgbColor(255, 255, 0));
      expect((yellow.hueName, yellow.value), ('黄', 89));
      final blue = colorAttributesOf(const RgbColor(0, 0, 255));
      expect((blue.hueName, blue.value), ('蓝', 11));
      expect(colorAttributesOf(const RgbColor(255, 128, 0)).hueName, '橙');
      expect(colorAttributesOf(const RgbColor(0, 255, 0)).hueName, '绿');
      final dark = colorAttributesOf(const RgbColor(128, 0, 0));
      expect(dark.chroma, 50);
      final gray = colorAttributesOf(const RgbColor(128, 128, 128));
      expect((gray.hueName, gray.chroma, gray.achromatic), ('灰色', 0, true));
      expect(colorAttributesOf(const RgbColor(250, 250, 250)).hueName, '白色');
      expect(colorAttributesOf(const RgbColor(10, 10, 12)).hueName, '黑色');
    });
  });
}
