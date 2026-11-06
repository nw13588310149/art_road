import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/logic/geometry.dart';

void main() {
  group('ratio and angle', () {
    test('length and angle to horizontal / vertical', () {
      expect(segmentLength(Offset.zero, const Offset(3, 4)), 5);
      expect(angleToHorizontal(Offset.zero, const Offset(10, 0)), 0);
      expect(angleToHorizontal(Offset.zero, const Offset(0, 10)), 90);
      expect(angleToHorizontal(Offset.zero, const Offset(10, -10)), closeTo(45, 1e-9));
      expect(angleToHorizontal(const Offset(10, -10), Offset.zero), closeTo(45, 1e-9));
      final thirty = Offset(10, 10 * math.tan(math.pi / 6));
      expect(angleToHorizontal(Offset.zero, thirty), closeTo(30, 1e-9));
      expect(angleToVertical(Offset.zero, thirty), closeTo(60, 1e-9));
      expect(angleToHorizontal(const Offset(2, 2), const Offset(2, 2)), 0);
    });

    test('slope direction in screen coordinates', () {
      expect(slopeOf(Offset.zero, const Offset(10, -5)), LineSlope.risingRight);
      expect(slopeOf(const Offset(10, -5), Offset.zero), LineSlope.risingRight);
      expect(slopeOf(Offset.zero, const Offset(10, 5)), LineSlope.fallingRight);
      expect(slopeOf(Offset.zero, const Offset(10, 0.05)), LineSlope.level);
      expect(slopeOf(Offset.zero, const Offset(0.05, 10)), LineSlope.plumb);
    });

    test('points pair up into segments', () {
      final points = [for (var i = 0; i < 5; i++) Offset(i.toDouble(), 0)];
      final segments = segmentsOf(points);
      expect(segments, hasLength(2));
      expect(segments[1], (const Offset(2, 0), const Offset(3, 0)));
    });

    test('ratio to the first segment and simple ratio labels', () {
      expect(ratioTo(2, 3), 1.5);
      expect(ratioTo(0, 3), isNull);
      expect(simpleRatioLabel(1.5), '2 : 3');
      expect(simpleRatioLabel(2.0), '1 : 2');
      expect(simpleRatioLabel(0.5), '2 : 1');
      expect(simpleRatioLabel(1.01), '1 : 1');
      expect(simpleRatioLabel(1.618), isNull);
      expect(simpleRatioLabel(0), isNull);
    });
  });

  group('composition grid', () {
    test('golden section and even divisions', () {
      expect(kGoldenMinor + kGoldenMajor, closeTo(1, 1e-12));
      expect(kGoldenMajor * kGoldenMajor, closeTo(kGoldenMinor, 1e-12));
      expect(evenFractions(3), [1 / 3, 2 / 3]);
      expect(evenFractions(1), isEmpty);
    });

    test('square cells follow the long side', () {
      final grid = squareGridLines(const Size(300, 200), 3);
      expect(grid.cell, 100);
      expect(grid.xs, [100, 200]);
      expect(grid.ys, [100]);
    });

    test('paper crop keeps the paper aspect inside the image', () {
      expect(fitAspectRect(const Size(400, 300), 1), const Rect.fromLTWH(50, 0, 300, 300));
      expect(
        fitAspectRect(const Size(400, 300), 1, shift: 0),
        const Rect.fromLTWH(0, 0, 300, 300),
      );
      expect(
        fitAspectRect(const Size(300, 400), 1.5),
        const Rect.fromLTWH(0, 100, 300, 200),
      );
      final eighth = ExamPaper.eighth.aspect(landscape: true);
      expect(eighth, closeTo(390 / 270, 1e-12));
      final crop = fitAspectRect(const Size(1000, 1000), eighth);
      expect(crop.width / crop.height, closeTo(eighth, 1e-9));
      expect(ExamPaper.quarter.sizeText(landscape: false), '395×545mm');
      expect(ExamPaper.sixteenth.aspect(landscape: false), closeTo(195 / 270, 1e-12));
    });

    test('grid enlargement cell size on paper', () {
      final cell = paperCellMm(ExamPaper.eighth, landscape: true, rows: 3, cols: 6);
      expect(cell.width, 65);
      expect(cell.height, 90);
      final portrait = paperCellMm(ExamPaper.quarter, landscape: false, rows: 5, cols: 5);
      expect(portrait.width, 79);
      expect(portrait.height, 109);
    });
  });

  group('perspective', () {
    const box = Rect.fromLTWH(10, -5, 20, 10);

    test('rays are clipped to the rectangle', () {
      expect(clipRay(Offset.zero, const Offset(1, 0), box), (const Offset(10, 0), const Offset(30, 0)));
      expect(clipRay(const Offset(15, 0), const Offset(1, 0), box), (const Offset(15, 0), const Offset(30, 0)));
      expect(clipRay(Offset.zero, const Offset(-1, 0), box), isNull);
      expect(clipRay(const Offset(0, 20), const Offset(1, 0), box), isNull);
      expect(clipRay(Offset.zero, Offset.zero, box), isNull);
    });

    test('fan from a vanishing point inside covers a full turn', () {
      final directions = fanDirections(const Offset(20, 0), box, 8);
      expect(directions, hasLength(8));
      for (var i = 0; i < 8; i++) {
        expect(directions[i].distance, closeTo(1, 1e-9));
        expect(math.atan2(directions[i].dy, directions[i].dx), closeTo(_wrap(math.pi * 2 * i / 8), 1e-9));
      }
    });

    test('fan from an outside vanishing point crosses the picture', () {
      const picture = Rect.fromLTWH(0, 0, 400, 300);
      for (final vp in const [Offset(-500, 150), Offset(900, 40), Offset(200, -800)]) {
        final directions = fanDirections(vp, picture, 12);
        expect(directions, hasLength(12));
        for (final direction in directions) {
          expect(direction.distance, closeTo(1, 1e-9));
          expect(clipRay(vp, direction, picture), isNotNull);
        }
      }
      expect(fanDirections(Offset.zero, picture, 0), isEmpty);
    });
  });

  group('portrait', () {
    test('facial thirds relative to the upper third', () {
      expect(facialThirds(0, 10, 20, 30), [1, 1, 1]);
      final measured = facialThirds(0, 10, 21, 30)!;
      expect(measured[1], closeTo(1.1, 1e-9));
      expect(measured[2], closeTo(0.9, 1e-9));
      expect(facialThirds(5, 5, 10, 20), isNull);
    });

    test('five eye widths split the face evenly', () {
      expect(fiveEyeLines(0, 100), [0, 20, 40, 60, 80, 100]);
    });
  });
}

double _wrap(double angle) => angle > math.pi ? angle - math.pi * 2 : angle;
