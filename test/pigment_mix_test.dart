import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/data/gouache_pigments.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/logic/image_ops.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/logic/pigment_mix.dart';

GouachePigment _pigment(String name) =>
    kGouachePigments.firstWhere((p) => p.name == name);

RgbColor _rgbOf(GouachePigment p) => RgbColor(p.r, p.g, p.b);

void main() {
  group('色彩空间', () {
    test('sRGB 和 Lab 来回换不走样', () {
      for (final rgb in const [
        RgbColor(0, 0, 0),
        RgbColor(255, 255, 255),
        RgbColor(128, 128, 128),
        RgbColor(200, 30, 30),
        RgbColor(42, 60, 154),
        RgbColor(176, 138, 106),
        RgbColor(246, 194, 0),
      ]) {
        final back = labToRgb(rgbToLab(rgb));
        expect((back.r - rgb.r).abs(), lessThanOrEqualTo(1), reason: '$rgb');
        expect((back.g - rgb.g).abs(), lessThanOrEqualTo(1), reason: '$rgb');
        expect((back.b - rgb.b).abs(), lessThanOrEqualTo(1), reason: '$rgb');
      }
    });

    test('白和中灰的 Lab', () {
      final white = rgbToLab(const RgbColor(255, 255, 255));
      expect(white.l, closeTo(100, 0.01));
      expect(white.a.abs(), lessThan(0.01));
      expect(white.b.abs(), lessThan(0.01));
      expect(rgbToLab(const RgbColor(119, 119, 119)).l, closeTo(50, 0.5));
    });
  });

  group('CIEDE2000', () {
    // Sharma、Wu、Dalal 2005 论文附表中的参考数据。
    const pairs = <(LabColor, LabColor, double)>[
      ((l: 50, a: 2.6772, b: -79.7751), (l: 50, a: 0, b: -82.7485), 2.0425),
      ((l: 50, a: 3.1571, b: -77.2803), (l: 50, a: 0, b: -82.7485), 2.8615),
      ((l: 50, a: 0, b: 0), (l: 50, a: -1, b: 2), 2.3669),
      ((l: 50, a: 2.49, b: -0.001), (l: 50, a: -2.49, b: 0.0009), 7.1792),
      ((l: 50, a: 2.5, b: 0), (l: 73, a: 25, b: -18), 27.1492),
      ((l: 50, a: 2.5, b: 0), (l: 50, a: 3.1736, b: 0.5854), 1.0),
      (
        (l: 60.2574, a: -34.0099, b: 36.2677),
        (l: 60.4626, a: -34.1751, b: 39.4387),
        1.2644,
      ),
    ];

    test('与参考数据一致', () {
      for (final (p, q, expected) in pairs) {
        expect(deltaE2000(p, q), closeTo(expected, 1e-4), reason: '$p / $q');
        expect(deltaE2000(q, p), closeTo(expected, 1e-4), reason: '对称');
      }
    });

    test('同一颜色色差为 0', () {
      const lab = (l: 40.0, a: 12.0, b: -30.0);
      expect(deltaE2000(lab, lab), 0);
    });
  });

  group('混色', () {
    test('黄加蓝偏绿，加白变浅，加黑变深', () {
      final green = mixPigments([
        MixPart(_pigment('柠檬黄'), 1),
        MixPart(_pigment('群青'), 1),
      ]);
      expect(green.g, greaterThan(green.r));
      expect(green.g, greaterThan(green.b));

      final red = _pigment('大红');
      final pink = mixPigments([MixPart(red, 1), MixPart(_pigment('白'), 1)]);
      final dark = mixPigments([MixPart(red, 3), MixPart(_pigment('黑'), 1)]);
      expect(rgbToLab(pink).l, greaterThan(rgbToLab(_rgbOf(red)).l));
      expect(rgbToLab(dark).l, lessThan(rgbToLab(_rgbOf(red)).l));
    });

    test('只有一种颜料时就是它本身', () {
      final p = _pigment('赭石');
      final mixed = mixPigments([MixPart(p, 2)]);
      expect((mixed.r - p.r).abs(), lessThanOrEqualTo(1));
      expect((mixed.g - p.g).abs(), lessThanOrEqualTo(1));
      expect((mixed.b - p.b).abs(), lessThanOrEqualTo(1));
    });

    test('匹配分档', () {
      expect(mixMatchOf(2), MixMatch.close);
      expect(mixMatchOf(7), MixMatch.rough);
      expect(mixMatchOf(15), MixMatch.far);
      expect(MixMatch.close.label, '接近');
    });
  });

  group('配方', () {
    test('目标就是一支颜料时直接用它', () {
      for (final name in ['群青', '中黄', '赭石', '翠绿']) {
        final recipes = gouacheRecipesFor(_rgbOf(_pigment(name)));
        final first = recipes.first;
        expect(first.parts.single.pigment.name, name);
        expect(first.match, MixMatch.close);
        expect(first.text, '直接用$name');
      }
    });

    test('中灰用白加黑', () {
      final first = gouacheRecipesFor(const RgbColor(128, 128, 128)).first;
      expect(
        first.parts.map((p) => p.pigment.name).toSet(),
        {'白', '黑'},
        reason: first.text,
      );
      expect(first.match, MixMatch.close);
    });

    test('偏灰的暖色调得出来，配方合理', () {
      // 浅驼色：暖、偏灰、偏亮。
      final recipes = gouacheRecipesFor(const RgbColor(176, 138, 106));
      final first = recipes.first;
      final names = first.parts.map((p) => p.pigment.name).toSet();
      expect(first.deltaE, lessThan(kMixRoughDeltaE), reason: first.text);
      expect(names, contains('白'), reason: first.text);
      expect(
        names.intersection({'赭石', '土黄', '熟褐', '桔黄', '朱红'}),
        isNotEmpty,
        reason: first.text,
      );
    });

    test('给出三组用料不同的配方，份数从多到少', () {
      final recipes = gouacheRecipesFor(const RgbColor(60, 90, 140));
      expect(recipes, hasLength(3));
      final sets = {
        for (final r in recipes) r.parts.map((p) => p.pigment.name).join('+'),
      };
      expect(sets, hasLength(3));
      for (final r in recipes) {
        expect(r.parts.length, inInclusiveRange(1, 3));
        for (var i = 1; i < r.parts.length; i++) {
          expect(r.parts[i - 1].parts, greaterThanOrEqualTo(r.parts[i].parts));
        }
        for (final p in r.parts) {
          expect(p.parts, inInclusiveRange(1, 4));
        }
        if (r.parts.length > 1) {
          expect(r.text, matches(RegExp(r'^\S+ \d 份( \+ \S+ \d 份)+$')));
        }
      }
    });

    test('算得够快', () {
      gouacheRecipesFor(const RgbColor(10, 20, 30));
      final watch = Stopwatch()..start();
      gouacheRecipesFor(const RgbColor(176, 138, 106));
      expect(watch.elapsedMilliseconds, lessThan(1500));
    });
  });
}
