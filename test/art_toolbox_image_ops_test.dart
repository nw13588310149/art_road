import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:the_road_of_art_flutter/features/art_toolbox/logic/image_ops.dart';

ArtImageData _image(int width, int height, List<List<int>> pixels) {
  assert(pixels.length == width * height);
  final rgba = Uint8List(width * height * 4);
  for (var i = 0; i < pixels.length; i++) {
    rgba[i * 4] = pixels[i][0];
    rgba[i * 4 + 1] = pixels[i][1];
    rgba[i * 4 + 2] = pixels[i][2];
    rgba[i * 4 + 3] = 255;
  }
  return ArtImageData(width: width, height: height, rgba: rgba);
}

List<int> _reds(ArtImageData image) => [
  for (var i = 0; i < image.pixelCount; i++) image.rgba[i * 4],
];

void main() {
  group('grayscale', () {
    test('uses perceptual luminance and stays opaque', () {
      final gray = grayscale(
        _image(3, 1, [
          [255, 0, 0],
          [0, 255, 0],
          [0, 0, 255],
        ]),
      );
      expect(gray.rgba.sublist(0, 4), [76, 76, 76, 255]);
      expect(gray.rgba.sublist(4, 8), [150, 150, 150, 255]);
      expect(gray.rgba.sublist(8, 12), [29, 29, 29, 255]);
    });
  });

  group('posterize', () {
    final source = _image(4, 1, [
      [0, 0, 0],
      [90, 90, 90],
      [170, 170, 170],
      [255, 255, 255],
    ]);

    test('maps luminance to evenly spaced gray levels', () {
      expect(_reds(posterize(source, 3)), [0, 128, 128, 255]);
      expect(_reds(posterize(source, 5)), [0, 64, 191, 255]);
    });

    test('value distribution covers every pixel once', () {
      expect(valueDistribution(source, 3), [0.25, 0.5, 0.25]);
      final result = posterizeWithDistribution(PosterizeRequest(source, 7));
      expect(
        result.distribution.fold<double>(0, (sum, v) => sum + v),
        closeTo(1, 1e-9),
      );
      expect(result.image.width, 4);
    });
  });

  group('flip', () {
    // A B
    // C D
    final source = _image(2, 2, [
      [1, 0, 0],
      [2, 0, 0],
      [3, 0, 0],
      [4, 0, 0],
    ]);

    test('horizontal', () {
      expect(_reds(flip(source, horizontal: true)), [2, 1, 4, 3]);
    });

    test('vertical', () {
      expect(_reds(flip(source, vertical: true)), [3, 4, 1, 2]);
    });

    test('both directions and identity', () {
      expect(_reds(flip(source, horizontal: true, vertical: true)), [
        4,
        3,
        2,
        1,
      ]);
      expect(_reds(flip(source)), [1, 2, 3, 4]);
    });
  });

  group('palette', () {
    test('finds dominant colors with their area ratios', () {
      const red = [220, 30, 40];
      const blue = [30, 60, 200];
      final palette = extractPalette(
        _image(4, 4, [for (var i = 0; i < 16; i++) i < 12 ? red : blue]),
      );
      expect(palette, hasLength(2));
      expect(palette.first.color, const RgbColor(220, 30, 40));
      expect(palette.first.ratio, closeTo(0.75, 1e-9));
      expect(palette.last.color, const RgbColor(30, 60, 200));
      expect(palette.last.ratio, closeTo(0.25, 1e-9));
    });

    test('merges nearly identical colors', () {
      final palette = extractPalette(
        _image(4, 4, [
          for (var i = 0; i < 16; i++)
            i < 8
                ? [250, 250, 250]
                : i < 12
                ? [246, 247, 248]
                : [10, 10, 10],
        ]),
      );
      expect(palette, hasLength(2));
      expect(palette.first.ratio, closeTo(0.75, 1e-9));
      expect(palette.last.color, const RgbColor(10, 10, 10));
    });

    test('keeps at most the requested number of colors', () {
      const colors = [
        [255, 0, 0],
        [0, 255, 0],
        [0, 0, 255],
        [255, 255, 0],
        [0, 255, 255],
        [255, 0, 255],
        [0, 0, 0],
        [255, 255, 255],
      ];
      final palette = extractPalette(
        _image(8, 2, [for (var i = 0; i < 16; i++) colors[i % 8]]),
        count: 6,
      );
      expect(palette.length, lessThanOrEqualTo(6));
      expect(
        palette.fold<double>(0, (sum, s) => sum + s.ratio),
        closeTo(1, 1e-9),
      );
      for (var i = 1; i < palette.length; i++) {
        expect(palette[i - 1].ratio, greaterThanOrEqualTo(palette[i].ratio));
      }
    });
  });

  group('pixel picking', () {
    test('accounts for BoxFit.contain letterboxing', () {
      // 200×100 的图放进 400×400：缩放 2 倍，上下各留白 100。
      ({int x, int y})? map(double dx, double dy) => containPointToPixel(
        dx: dx,
        dy: dy,
        boxWidth: 400,
        boxHeight: 400,
        imageWidth: 200,
        imageHeight: 100,
      );
      expect(map(10, 50), isNull);
      expect(map(200, 300), isNull);
      expect(map(0, 100), (x: 0, y: 0));
      expect(map(399, 299.9), (x: 199, y: 99));
      expect(map(201, 151), (x: 100, y: 25));
    });

    test('pixel centers round-trip through the mapping', () {
      for (final (x, y) in const [(0, 0), (37, 12), (149, 299)]) {
        final point = pixelToContainPoint(
          x: x,
          y: y,
          boxWidth: 320,
          boxHeight: 180,
          imageWidth: 150,
          imageHeight: 300,
        );
        expect(
          containPointToPixel(
            dx: point.dx,
            dy: point.dy,
            boxWidth: 320,
            boxHeight: 180,
            imageWidth: 150,
            imageHeight: 300,
          ),
          (x: x, y: y),
        );
      }
    });

    test('pixelAt reads RGB and clamps coordinates', () {
      final image = _image(2, 1, [
        [10, 20, 30],
        [40, 50, 60],
      ]);
      expect(pixelAt(image, 1, 0), const RgbColor(40, 50, 60));
      expect(pixelAt(image, 9, -3), const RgbColor(40, 50, 60));
    });
  });

  group('color conversions', () {
    test('hex and HSB', () {
      const orange = RgbColor(255, 128, 0);
      expect(orange.hex, '#FF8000');
      expect(orange.argb, 0xFFFF8000);
      final hsb = orange.toHsb();
      expect(hsb.hue, closeTo(30.1, 0.1));
      expect(hsb.saturation, 1);
      expect(hsb.brightness, 1);
      expect(const RgbColor(0, 0, 255).toHsb().hue, closeTo(240, 1e-9));
      expect(const RgbColor(128, 128, 128).toHsb().saturation, 0);
    });

    test('warm / cool tendency', () {
      expect(
        describeTemperature(const RgbColor(230, 120, 40)).temperature,
        ColorTemperature.warm,
      );
      expect(
        describeTemperature(const RgbColor(40, 90, 200)).temperature,
        ColorTemperature.cool,
      );
      expect(describeTemperature(const RgbColor(128, 128, 128)).family, '中性灰');
      expect(describeTemperature(const RgbColor(140, 136, 130)).family, '暖灰');
      expect(describeTemperature(const RgbColor(128, 132, 140)).family, '冷灰');
    });
  });

  group('decoding', () {
    test('decodes PNG and limits the long side', () {
      final source = img.Image(width: 2000, height: 10);
      img.fill(source, color: img.ColorRgb8(10, 20, 30));
      final decoded = decodeArtImage(img.encodePng(source))!;
      expect(decoded.width, kToolboxMaxSide);
      expect(decoded.height, 8);
      expect(pixelAt(decoded, 5, 5), const RgbColor(10, 20, 30));
    });

    test('flattens transparency onto white', () {
      final source = img.Image(width: 1, height: 1, numChannels: 4)
        ..setPixelRgba(0, 0, 0, 0, 0, 0);
      final decoded = decodeArtImage(img.encodePng(source))!;
      expect(pixelAt(decoded, 0, 0), const RgbColor(255, 255, 255));
    });

    test('returns null for unsupported bytes', () {
      expect(decodeArtImage(Uint8List.fromList([1, 2, 3, 4])), isNull);
    });

    test('flattens premultiplied engine pixels onto white', () {
      final data = artImageFromPremultiplied(
        2,
        1,
        Uint8List.fromList([0, 0, 0, 0, 100, 50, 0, 128]),
      );
      expect(data.rgba, [255, 255, 255, 255, 227, 177, 127, 255]);
    });
  });
}
