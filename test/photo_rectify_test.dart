import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:the_road_of_art_flutter/core/art/photo_rectify.dart';
import 'package:the_road_of_art_flutter/features/artworks/data/artwork_rules.dart';

/// 在浅灰「桌面」上画一张歪着的画纸：四个象限四种颜色，中心一个黑点。
/// 画纸的四个角是 [quad]（像素坐标）。
img.Image _skewedPaper(int w, int h, List<PhotoPoint> quad) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(200, 200, 200));
  // 从画纸的单位正方形映射到照片里的四边形，逐像素反推是否落在画纸里。
  final toPaper = solveHomography(quad, [
    (x: 0, y: 0),
    (x: 1, y: 0),
    (x: 1, y: 1),
    (x: 0, y: 1),
  ]);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = applyHomography(toPaper, (x: x + 0.5, y: y + 0.5));
      if (p.x < 0 || p.x > 1 || p.y < 0 || p.y > 1) continue;
      final dx = p.x - 0.5, dy = p.y - 0.5;
      final img.Color color;
      if (dx * dx + dy * dy < 0.004) {
        color = img.ColorRgb8(0, 0, 0);
      } else if (p.y < 0.5) {
        color = p.x < 0.5
            ? img.ColorRgb8(220, 30, 30)
            : img.ColorRgb8(30, 180, 40);
      } else {
        color = p.x < 0.5
            ? img.ColorRgb8(30, 60, 210)
            : img.ColorRgb8(240, 210, 20);
      }
      image.setPixel(x, y, color);
    }
  }
  return image;
}

void _expectColor(img.Image image, double u, double v, List<int> rgb) {
  final p = image.getPixel(
    (u * image.width).floor().clamp(0, image.width - 1),
    (v * image.height).floor().clamp(0, image.height - 1),
  );
  final got = [p.r.toInt(), p.g.toInt(), p.b.toInt()];
  for (var c = 0; c < 3; c++) {
    expect(
      (got[c] - rgb[c]).abs(),
      lessThan(40),
      reason: '($u, $v) 应接近 $rgb，实际 $got',
    );
  }
}

void main() {
  group('单应矩阵', () {
    final from = <PhotoPoint>[
      (x: 0, y: 0),
      (x: 400, y: 0),
      (x: 400, y: 300),
      (x: 0, y: 300),
    ];
    final to = <PhotoPoint>[
      (x: 52, y: 31),
      (x: 470, y: 80),
      (x: 430, y: 390),
      (x: 20, y: 340),
    ];

    test('四个角精确对应', () {
      final h = solveHomography(from, to);
      for (var i = 0; i < 4; i++) {
        final p = applyHomography(h, from[i]);
        expect(p.x, closeTo(to[i].x, 1e-6));
        expect(p.y, closeTo(to[i].y, 1e-6));
      }
    });

    test('中心落在四边形对角线的交点上', () {
      final h = solveHomography(from, to);
      final c = applyHomography(h, (x: 200, y: 150));
      // 透视变换保持直线：矩形中心（对角线交点）映射到四边形的对角线交点。
      final a = to[0], b = to[2], p = to[1], q = to[3];
      final d = (b.x - a.x) * (q.y - p.y) - (b.y - a.y) * (q.x - p.x);
      final t = ((p.x - a.x) * (q.y - p.y) - (p.y - a.y) * (q.x - p.x)) / d;
      expect(c.x, closeTo(a.x + t * (b.x - a.x), 1e-6));
      expect(c.y, closeTo(a.y + t * (b.y - a.y), 1e-6));
    });

    test('三点共线时没有解', () {
      expect(
        () => solveHomography([
          (x: 0, y: 0),
          (x: 1, y: 1),
          (x: 2, y: 2),
          (x: 0, y: 5),
        ], to),
        throwsArgumentError,
      );
    });
  });

  group('四边形', () {
    test('凸四边形可用，交叉和凹进去的不行', () {
      expect(isConvexQuad(defaultPhotoCorners()), isTrue);
      expect(
        isConvexQuad([(x: 0, y: 0), (x: 1, y: 0), (x: 0, y: 1), (x: 1, y: 1)]),
        isFalse,
        reason: '交叉',
      );
      expect(
        isConvexQuad([
          (x: 0, y: 0),
          (x: 1, y: 0),
          (x: 0.3, y: 0.3),
          (x: 0, y: 1),
        ]),
        isFalse,
        reason: '凹进去',
      );
    });

    test('默认四个角从边上收 4%', () {
      final c = defaultPhotoCorners();
      expect(c.first, (x: 0.04, y: 0.04));
      expect(c[2], (x: 0.96, y: 0.96));
    });

    test('顺时针转 90° 后四个角仍从左上开始', () {
      final turned = rotatePhotoCornersClockwise([
        (x: 0.1, y: 0.2),
        (x: 0.9, y: 0.2),
        (x: 0.9, y: 0.7),
        (x: 0.1, y: 0.7),
      ]);
      expect(turned[0].x, closeTo(0.3, 1e-9));
      expect(turned[0].y, closeTo(0.1, 1e-9));
      expect(turned[2].x, closeTo(0.8, 1e-9));
      expect(turned[2].y, closeTo(0.9, 1e-9));
      expect(isConvexQuad(turned), isTrue);
    });
  });

  group('拉正', () {
    const w = 320, h = 240;
    final quad = <PhotoPoint>[
      (x: 60, y: 30),
      (x: 280, y: 55),
      (x: 300, y: 215),
      (x: 25, y: 190),
    ];
    final normalized = [for (final p in quad) (x: p.x / w, y: p.y / h)];

    test('歪着的画纸拉正后四角和中心是对的颜色', () {
      final photo = _skewedPaper(w, h, quad);
      final out = rectifyImage(photo, normalized);
      _expectColor(out, 0.1, 0.1, [220, 30, 30]);
      _expectColor(out, 0.9, 0.1, [30, 180, 40]);
      _expectColor(out, 0.1, 0.9, [30, 60, 210]);
      _expectColor(out, 0.9, 0.9, [240, 210, 20]);
      _expectColor(out, 0.5, 0.5, [0, 0, 0]);
      // 尺寸取对边平均长度。
      final size = rectifiedSize(quad);
      expect(out.width, size.width);
      expect(out.height, size.height);
    });

    test('JPG 进 JPG 出，结果能通过上传校验', () {
      final bytes = img.encodeJpg(_skewedPaper(w, h, quad), quality: 95);
      final result = rectifyPhoto(
        PhotoRectifyRequest(bytes: bytes, corners: normalized),
      );
      expect(ArtworkRules.imageError(result), isNull);
      final decoded = img.decodeJpg(result)!;
      _expectColor(decoded, 0.1, 0.1, [220, 30, 30]);
      _expectColor(decoded, 0.9, 0.9, [240, 210, 20]);
    });

    test('先转 90° 再拉正', () {
      final bytes = Uint8List.fromList(
        img.encodePng(_skewedPaper(w, h, quad)),
      );
      // 照片顺时针转 90° 后，画纸的四个角也跟着转。
      final turned = rotatePhotoCornersClockwise(normalized);
      final result = rectifyPhoto(
        PhotoRectifyRequest(bytes: bytes, corners: turned, quarterTurns: 1),
      );
      final out = img.decodeJpg(result)!;
      // 转过之后画纸是竖的：原来的左下（蓝）到了左上，左上（红）到了右上。
      expect(out.height, greaterThan(out.width));
      _expectColor(out, 0.1, 0.1, [30, 60, 210]);
      _expectColor(out, 0.9, 0.1, [220, 30, 30]);
      _expectColor(out, 0.9, 0.9, [30, 180, 40]);
      _expectColor(out, 0.1, 0.9, [240, 210, 20]);
    });

    test('长边不超过上限', () {
      final size = rectifiedSize([
        (x: 0, y: 0),
        (x: 6000, y: 0),
        (x: 6000, y: 3000),
        (x: 0, y: 3000),
      ]);
      expect(size.width, 2400);
      expect(size.height, 1200);
      final photo = _skewedPaper(w, h, quad);
      final out = rectifyImage(photo, normalized, maxLongSide: 100);
      expect(out.width, lessThanOrEqualTo(100));
      expect(out.height, lessThanOrEqualTo(100));
    });

    test('四个角不成四边形时报错', () {
      final bytes = img.encodeJpg(img.Image(width: 10, height: 10));
      expect(
        () => rectifyPhoto(
          PhotoRectifyRequest(
            bytes: bytes,
            corners: const [
              (x: 0, y: 0),
              (x: 1, y: 0),
              (x: 0, y: 1),
              (x: 1, y: 1),
            ],
          ),
        ),
        throwsA(isA<PhotoRectifyException>()),
      );
    });
  });
}
