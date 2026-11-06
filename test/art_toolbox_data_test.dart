import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/data/exam_checklist.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/data/figure_proportions.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/data/toolbox_catalog.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/data/value_order_records.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/logic/value_order_game.dart';

void main() {
  group('catalog', () {
    test('existing keys and aliases still resolve', () {
      const legacy = <String, ArtTool>{
        'value': ArtTool.value,
        'mirror': ArtTool.mirror,
        'grid': ArtTool.grid,
        'color': ArtTool.color,
        'quickSketch': ArtTool.quickSketch,
        'countdown': ArtTool.countdown,
        '明度': ArtTool.value,
        '镜像': ArtTool.mirror,
        '网格': ArtTool.grid,
        '取色': ArtTool.color,
        '取色色卡': ArtTool.color,
        '速写计时': ArtTool.quickSketch,
        '倒计时': ArtTool.countdown,
        '明度检查': ArtTool.value,
        '构图网格': ArtTool.grid,
      };
      legacy.forEach((key, tool) => expect(ArtTool.tryParse(key), tool, reason: key));
      expect(ArtTool.tryParse(' grid '), ArtTool.grid);
      expect(ArtTool.tryParse(''), isNull);
      expect(ArtTool.tryParse(null), isNull);
      expect(ArtTool.tryParse('unknown'), isNull);
    });

    test('new keys and aliases resolve', () {
      const added = <String, ArtTool>{
        'blur': ArtTool.blur,
        'simplify': ArtTool.simplify,
        'temperature': ArtTool.temperature,
        'edges': ArtTool.edges,
        'measure': ArtTool.measure,
        'perspective': ArtTool.perspective,
        'portrait': ArtTool.portrait,
        'figure': ArtTool.figure,
        'valueOrder': ArtTool.valueOrder,
        'score': ArtTool.score,
        'checklist': ArtTool.checklist,
        '眯眼': ArtTool.blur,
        '模糊': ArtTool.blur,
        '色块': ArtTool.simplify,
        '冷暖': ArtTool.temperature,
        '线稿': ArtTool.edges,
        '轮廓': ArtTool.edges,
        '比例': ArtTool.measure,
        '透视': ArtTool.perspective,
        '三庭五眼': ArtTool.portrait,
        '人体比例': ArtTool.figure,
        '明度排序': ArtTool.valueOrder,
        '综合分': ArtTool.score,
        '物品清单': ArtTool.checklist,
      };
      added.forEach((key, tool) => expect(ArtTool.tryParse(key), tool, reason: key));
      for (final tool in ArtTool.values) {
        expect(ArtTool.tryParse(tool.label), tool);
        expect(tool.key, tool.name);
      }
    });

    test('tools are grouped and only analysis tools need an image', () {
      expect(ArtToolGroup.analysis.tools, hasLength(11));
      expect(ArtToolGroup.practice.tools, [ArtTool.quickSketch, ArtTool.figure, ArtTool.valueOrder]);
      expect(ArtToolGroup.exam.tools, [ArtTool.countdown, ArtTool.score, ArtTool.checklist]);
      for (final tool in ArtTool.values) {
        expect(tool.usesImage, tool.group == ArtToolGroup.analysis);
        expect(tool.description, isNotEmpty);
        expect(tool.help, isNotEmpty);
      }
      expect(ArtTool.values.map((t) => t.key).toSet(), hasLength(ArtTool.values.length));
    });

    test('copy avoids exclamation marks and absolute wording', () {
      final texts = [
        for (final tool in ArtTool.values) ...[tool.label, tool.description, tool.help],
        for (final group in ArtToolGroup.values) group.description,
        for (final pose in FigurePose.values) ...pose.notes,
        ...kFigureCommonNotes,
        kChecklistNotice,
      ];
      for (final text in texts) {
        for (final banned in const ['！', '!', '最好', '第一', '提分', '保过']) {
          expect(text.contains(banned), isFalse, reason: text);
        }
      }
    });
  });

  group('exam checklist', () {
    test('defaults cover every group', () {
      const checklist = ExamChecklist();
      for (final group in ChecklistGroup.values) {
        expect(checklist.itemsOf(group), isNotEmpty, reason: group.label);
      }
      final labels = checklist.items.map((i) => i.label).join('|');
      for (final name in const ['准考证', '身份证', '铅笔', '炭笔', '可塑橡皮', '美工刀', '水粉颜料', '水粉笔', '调色盒', '水桶', '吸水海绵', '纸胶带', '速写用笔', '手表']) {
        expect(labels, contains(name));
      }
      expect(checklist.items.map((i) => i.id).toSet(), hasLength(checklist.total));
      expect(checklist.checkedCount, 0);
    });

    test('toggle, add, remove and reset', () {
      var checklist = const ExamChecklist().toggle('doc-id');
      expect(checklist.isChecked('doc-id'), isTrue);
      expect(checklist.checkedCount, 1);
      checklist = checklist.toggle('doc-id');
      expect(checklist.checkedCount, 0);

      checklist = checklist.add(ChecklistGroup.other, '  折叠小凳  ', id: 'c1');
      expect(checklist.itemsOf(ChecklistGroup.other).last.label, '折叠小凳');
      expect(identical(checklist.add(ChecklistGroup.other, '折叠小凳'), checklist), isTrue);
      expect(identical(checklist.add(ChecklistGroup.other, '   '), checklist), isTrue);
      expect(
        checklist.add(ChecklistGroup.other, '超' * 40, id: 'c2').custom.last.label.length,
        kChecklistLabelMaxLength,
      );

      checklist = checklist.toggle('c1').toggle('doc-admission');
      expect(checklist.checkedCount, 2);
      expect(identical(checklist.remove('doc-admission'), checklist), isTrue);
      final removed = checklist.remove('c1');
      expect(removed.custom, isEmpty);
      expect(removed.checkedCount, 1);

      final keep = checklist.reset(keepCustom: true);
      expect((keep.checkedCount, keep.custom.length), (0, 1));
      final clean = checklist.reset();
      expect((clean.checkedCount, clean.custom.length), (0, 0));
    });

    test('tick state and custom items persist locally', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final repository = ExamChecklistRepository();
      expect((await repository.load()).checkedCount, 0);
      final checklist = const ExamChecklist()
          .add(ChecklistGroup.color, '小喷壶', id: 'custom-1')
          .toggle('custom-1')
          .toggle('color-paint')
          .toggle('doc-id');
      await repository.save(checklist);

      final loaded = await ExamChecklistRepository().load();
      expect(loaded.checked, {'custom-1', 'color-paint', 'doc-id'});
      expect(loaded.custom.single.label, '小喷壶');
      expect(loaded.custom.single.group, ChecklistGroup.color);
      expect(loaded.custom.single.custom, isTrue);
      expect(loaded.checkedCount, 3);
    });

    test('broken storage falls back to an empty list', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        ExamChecklistRepository.storageKey: '{"custom":[{"id":"x","group":"nope","label":"a"}],"checked":"bad"}',
      });
      final loaded = await ExamChecklistRepository().load();
      expect(loaded.custom, isEmpty);
      expect(loaded.checked, isEmpty);
      SharedPreferences.setMockInitialValues(<String, Object>{
        ExamChecklistRepository.storageKey: '[[',
      });
      expect((await ExamChecklistRepository().load()).total, kDefaultChecklistItems.length);
    });
  });

  group('value order game', () {
    test('perceptual grey scale', () {
      expect(greyForLightness(0), 0);
      expect(greyForLightness(100), 255);
      expect(greyForLightness(50), 119);
      expect(greyForLightness(30), lessThan(greyForLightness(31)));
    });

    test('deals distinct shuffled greys inside the level range', () {
      for (final level in ValueOrderLevel.values) {
        for (final count in valueOrderCounts) {
          final game = ValueOrderGame.deal(count: count, level: level, random: math.Random(count));
          expect(game.length, count);
          expect(game.levels.toSet(), hasLength(count));
          expect(game.solved, isFalse);
          expect(game.answer.first, greyForLightness(level.minLightness));
          expect(game.answer.last, greyForLightness(level.maxLightness));
          expect(game.mistakes().length, greaterThan(count - count ~/ 3 - 1));
        }
      }
    });

    test('checks the order and reports misplaced swatches', () {
      final game = ValueOrderGame([10, 30, 20, 40]);
      expect(game.mistakes(), [1, 2]);
      expect(game.rankOf(1), 2);
      game.swap(1, 2);
      expect(game.solved, isTrue);
      game.move(0, 3);
      expect(game.levels, [20, 30, 40, 10]);
      expect(game.mistakes(), [0, 1, 2, 3]);
      game.move(3, 0);
      expect(game.solved, isTrue);
    });

    test('formats elapsed time', () {
      expect(formatValueOrderTime(65300), '1:05.3');
      expect(formatValueOrderTime(9049), '0:09.0');
    });

    test('best time is kept per count and level', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final key = ValueOrderRecordRepository.keyOf(9, ValueOrderLevel.fine);
      expect(key, '9-fine');
      final first = recordIfBest(const {}, key, 42000)!;
      expect(first[key], 42000);
      expect(recordIfBest(first, key, 50000), isNull);
      final better = recordIfBest(first, key, 38000)!;
      expect(better[key], 38000);

      await ValueOrderRecordRepository().save(better);
      final loaded = await ValueOrderRecordRepository().load();
      expect(loaded, {'9-fine': 38000});
    });
  });

  group('figure proportions', () {
    test('standing seven, sitting five, crouching three and a half', () {
      expect(FigurePose.standing.skeleton.height, closeTo(7, 1e-9));
      expect(FigurePose.sitting.skeleton.height, closeTo(5, 1e-9));
      expect(FigurePose.crouching.skeleton.height, closeTo(3.5, 1e-9));
      for (final pose in FigurePose.values) {
        expect(pose.skeleton.height, closeTo(pose.heads, 1e-9));
        expect(pose.landmarks.last.$1, pose.heads);
        expect(pose.notes, isNotEmpty);
      }
    });

    test('arms are three heads: 4/3 + 1 + 2/3', () {
      for (final pose in FigurePose.values) {
        final arms = pose.skeleton.armBones;
        expect(arms.length % 3, 0);
        for (var i = 0; i < arms.length; i += 3) {
          expect(arms[i].length, closeTo(4 / 3, 1e-9));
          expect(arms[i + 1].length, closeTo(1, 1e-9));
          expect(arms[i + 2].length, closeTo(2 / 3, 1e-9));
          expect(arms[i].length + arms[i + 1].length + arms[i + 2].length, closeTo(3, 1e-9));
        }
      }
    });

    test('male shoulder width is about two heads', () {
      final arms = FigurePose.standing.skeleton.armBones;
      expect((arms[3].from - arms[0].from).distance, closeTo(2, 1e-9));
    });
  });
}
