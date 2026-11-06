import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/logic/image_filters.dart';
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

ArtImageData _gray(int width, int height, List<int> values) =>
    _image(width, height, [for (final v in values) [v, v, v]]);

ArtImageData _uniform(int width, int height, List<int> color) =>
    _image(width, height, [for (var i = 0; i < width * height; i++) color]);

List<int> _reds(ArtImageData image) => [
  for (var i = 0; i < image.pixelCount; i++) image.rgba[i * 4],
];

/// 左半黑、右半白的竖直边缘。
ArtImageData _verticalStep(int width, int height) => _gray(width, height, [
  for (var y = 0; y < height; y++)
    for (var x = 0; x < width; x++) x < width ~/ 2 ? 0 : 255,
]);

void main() {
  group('downscale', () {
    test('averages each block of source pixels', () {
      final source = _image(4, 2, [
        [0, 0, 0],
        [100, 100, 100],
        [10, 20, 30],
        [30, 40, 50],
        [200, 200, 200],
        [100, 100, 100],
        [50, 60, 70],
        [70, 80, 90],
      ]);
      final small = downscale(source, 2);
      expect(small.width, 2);
      expect(small.height, 1);
      expect(small.rgba, [100, 100, 100, 255, 40, 50, 60, 255]);
    });

    test('keeps the aspect ratio for uneven factors and leaves small images', () {
      final small = downscale(_uniform(5, 3, [9, 99, 199]), 3);
      expect((small.width, small.height), (3, 2));
      expect(pixelAt(small, 2, 1), const RgbColor(9, 99, 199));
      final tiny = _uniform(3, 2, [1, 2, 3]);
      expect(identical(downscale(tiny, 1024), tiny), isTrue);
    });
  });

  group('posterize and notan', () {
    test('two-level posterize splits at the middle', () {
      expect(_reds(posterize(_gray(4, 1, [0, 127, 128, 255]), 2)), [
        0,
        0,
        255,
        255,
      ]);
      expect(valueDistribution(_gray(4, 1, [0, 127, 128, 255]), 2), [
        0.5,
        0.5,
      ]);
    });

    test('pixels darker than the threshold turn black', () {
      final source = _gray(4, 1, [10, 99, 100, 200]);
      final result = notan(NotanRequest(source, 100));
      expect(_reds(result.image), [0, 0, 255, 255]);
      expect(result.darkRatio, 0.5);
      expect(result.image.rgba[3], 255);
    });

    test('threshold extremes and smoothing of flat areas', () {
      final source = _gray(4, 1, [10, 99, 100, 200]);
      expect(notan(NotanRequest(source, 0)).darkRatio, 0);
      expect(notan(NotanRequest(source, 256)).darkRatio, 1);
      final flat = notan(NotanRequest(_gray(3, 3, List.filled(9, 90)), 128, smooth: 2));
      expect(_reds(flat.image), List.filled(9, 0));
    });

    test('otsu picks the middle of the gap between two value groups', () {
      final histogram = List<int>.filled(256, 0)
        ..[50] = 50
        ..[200] = 50;
      expect(otsuThreshold(histogram), 125);
      expect(otsuThreshold(List<int>.filled(256, 0)), 128);
      final image = _gray(4, 1, [20, 30, 220, 230]);
      final threshold = otsuThreshold(luminanceHistogram(image));
      expect(threshold, greaterThan(30));
      expect(threshold, lessThanOrEqualTo(220));
      expect(notan(NotanRequest(image, threshold)).darkRatio, 0.5);
    });
  });

  group('blur', () {
    test('flat images stay flat and radius 0 copies', () {
      final source = _uniform(6, 4, [40, 120, 200]);
      final blurred = blurImage(BlurRequest(source, 3));
      for (var y = 0; y < 4; y++) {
        for (var x = 0; x < 6; x++) {
          expect(pixelAt(blurred, x, y), const RgbColor(40, 120, 200));
        }
      }
      final copy = blurImage(BlurRequest(source, 0));
      expect(copy.rgba, source.rgba);
      expect(identical(copy.rgba, source.rgba), isFalse);
    });

    test('a bright dot spreads symmetrically and fades with distance', () {
      final source = _gray(9, 9, [for (var i = 0; i < 81; i++) i == 40 ? 255 : 0]);
      final blurred = blurImage(BlurRequest(source, 1));
      int at(int x, int y) => pixelAt(blurred, x, y).r;
      expect(at(4, 4), lessThan(255));
      expect(at(4, 4), greaterThan(at(5, 4)));
      expect(at(5, 4), greaterThan(at(7, 4)));
      expect(at(3, 4), at(5, 4));
      expect(at(4, 3), at(4, 5));
      expect(at(0, 0), 0);
    });

    test('step edges become a monotonic ramp', () {
      final row = _reds(blurImage(BlurRequest(_verticalStep(20, 1), 2)));
      expect(row.first, 0);
      expect(row.last, 255);
      for (var i = 1; i < row.length; i++) {
        expect(row[i], greaterThanOrEqualTo(row[i - 1]));
      }
      expect(row[9], inExclusiveRange(0, 255));
      expect(row[10], inExclusiveRange(row[9], 255));
    });

    test('grayscale option outputs neutral pixels', () {
      final blurred = blurImage(
        BlurRequest(_uniform(3, 3, [255, 0, 0]), 1, grayscale: true),
      );
      expect(pixelAt(blurred, 1, 1), const RgbColor(76, 76, 76));
    });

    test('blur level maps to a radius relative to the long side', () {
      expect(blurRadiusForLevel(0, 1024), 0);
      expect(blurRadiusForLevel(1, 50), 1);
      expect(blurRadiusForLevel(10, 1024), 29);
      expect(
        blurRadiusForLevel(4, 1024),
        lessThan(blurRadiusForLevel(8, 1024)),
      );
    });
  });

  test('invert flips every channel', () {
    final inverted = invert(_image(2, 1, [
      [10, 20, 30],
      [255, 0, 128],
    ]));
    expect(inverted.rgba, [245, 235, 225, 255, 0, 255, 127, 255]);
  });

  group('sobel edges', () {
    test('a vertical step lights up only the two columns at the boundary', () {
      final gray = luminancePlane(_verticalStep(8, 4));
      final magnitude = sobelMagnitude(gray, 8, 4);
      for (var y = 0; y < 4; y++) {
        expect(magnitude.sublist(y * 8, y * 8 + 8), [0, 0, 0, 255, 255, 0, 0, 0]);
      }
    });

    test('a horizontal step responds through the vertical gradient', () {
      final image = _gray(4, 6, [
        for (var y = 0; y < 6; y++)
          for (var x = 0; x < 4; x++) y < 3 ? 255 : 0,
      ]);
      final magnitude = sobelMagnitude(luminancePlane(image), 4, 6);
      expect([for (var y = 0; y < 6; y++) magnitude[y * 4 + 1]], [
        0,
        0,
        255,
        255,
        0,
        0,
      ]);
    });

    test('line sketch draws dark lines on white', () {
      final sketch = edgeSketch(EdgeRequest(_verticalStep(8, 4), 64, smooth: 0));
      for (var y = 0; y < 4; y++) {
        expect([for (var x = 0; x < 8; x++) pixelAt(sketch, x, y).r], [
          255,
          255,
          255,
          16,
          16,
          255,
          255,
          255,
        ]);
      }
      final flat = edgeSketch(EdgeRequest(_uniform(5, 5, [90, 90, 90]), 10));
      expect(_reds(flat), List.filled(25, 255));
    });

    test('a higher threshold removes weak edges', () {
      final soft = _gray(6, 2, [
        for (var y = 0; y < 2; y++)
          for (var x = 0; x < 6; x++) x < 3 ? 100 : 140,
      ]);
      expect(_reds(edgeSketch(EdgeRequest(soft, 20, smooth: 0))), contains(lessThan(255)));
      expect(
        _reds(edgeSketch(EdgeRequest(soft, 80, smooth: 0))),
        everyElement(255),
      );
    });
  });
}
