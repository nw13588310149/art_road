import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/data/score_form_repository.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/logic/score_calculator.dart';

ScoreResult _score(
  ScoreProvince province, {
  required String culture,
  String professional = '',
  String bonus = '',
  YunnanMode yunnan = YunnanMode.balanced,
  CustomScoreRule custom = const CustomScoreRule(),
}) {
  final outcome = computeScore(
    scoreRuleFor(province, yunnan: yunnan, custom: custom),
    culture: culture,
    professional: professional,
    bonus: bonus,
  );
  expect(outcome.error, isNull);
  return outcome.result!;
}

void main() {
  group('province formulas', () {
    test('甘肃 worked example: 文化 500 专业 240 = 550.00', () {
      final result = _score(ScoreProvince.gansu, culture: '500', professional: '240');
      expect(result.text, '550.00');
      expect(result.value, 550);
      expect(result.steps.map((s) => s.expression), [
        '500 × 50% = 250.00',
        '240 ÷ 300 × 750 × 50% = 300.00',
        '250.00 + 300.00 = 550.00',
      ]);
      expect(
        scoreRuleFor(ScoreProvince.gansu).source,
        contains('关于做好2026年甘肃省普通高等学校艺术类专业考试招生工作的通知'),
      );
    });

    test('甘肃 keeps two decimals', () {
      expect(_score(ScoreProvince.gansu, culture: '501', professional: '241').text, '551.75');
      expect(_score(ScoreProvince.gansu, culture: '480.5', professional: '230.5').text, '528.38');
    });

    test('安徽 uses ×2.5', () {
      final result = _score(ScoreProvince.anhui, culture: '500', professional: '240');
      expect(result.text, '550.00');
      expect(result.steps[1].expression, '240 × 2.5 × 50% = 300.00');
      expect(_score(ScoreProvince.anhui, culture: '433', professional: '211').text, '480.25');
    });

    test('北京 rounds to an integer', () {
      expect(_score(ScoreProvince.beijing, culture: '501', professional: '241').text, '552');
      expect(_score(ScoreProvince.beijing, culture: '500', professional: '241').text, '551');
      final half = _score(ScoreProvince.beijing, culture: '501', professional: '240');
      expect(half.text, '551');
      expect(half.decimals, 0);
      expect(half.steps.last.expression, '250.50 + 300.00 = 550.50，四舍五入取整为 551');
    });

    test('福建 adds policy points to the culture score', () {
      final withBonus = _score(
        ScoreProvince.fujian,
        culture: '500',
        professional: '240',
        bonus: '10',
      );
      expect(withBonus.text, '555.00');
      expect(withBonus.steps.first.expression, '（500 + 10）× 50% = 255.00');
      expect(_score(ScoreProvince.fujian, culture: '500', professional: '240').text, '550.00');
    });

    test('黑龙江 weights professional 40% and culture 60%', () {
      final result = _score(ScoreProvince.heilongjiang, culture: '500', professional: '240');
      expect(result.text, '540.00');
      expect(result.steps[0].expression, '500 × 60% = 300.00');
      expect(result.steps[1].expression, '240 ÷ 300 × 750 × 40% = 240.00');
    });

    test('云南 three options', () {
      expect(
        _score(ScoreProvince.yunnan, culture: '500', professional: '240').text,
        '550.00',
      );
      final weighted = _score(
        ScoreProvince.yunnan,
        culture: '500',
        professional: '240',
        yunnan: YunnanMode.cultureWeighted,
      );
      expect(weighted.text, '530.00');
      expect(weighted.steps[1].expression, '240 × 750 ÷ 300 × 30% = 180.00');
      expect(
        _score(ScoreProvince.yunnan, culture: '500', yunnan: YunnanMode.cultureOnly).text,
        '500.00',
      );
    });

    test('自定义 weight, full score and decimals', () {
      expect(
        _score(
          ScoreProvince.custom,
          culture: '500',
          professional: '240',
          custom: const CustomScoreRule(culturePercent: 60, decimals: 1),
        ).text,
        '540.0',
      );
      expect(
        _score(
          ScoreProvince.custom,
          culture: '500',
          professional: '120',
          custom: const CustomScoreRule(professionalFull: 150),
        ).text,
        '550.00',
      );
      final repeating = _score(
        ScoreProvince.custom,
        culture: '500',
        professional: '241',
        custom: const CustomScoreRule(professionalFull: 270),
      );
      expect(repeating.text, '584.72');
      expect(repeating.steps[1].expression, contains('≈334.7222'));
      expect(
        _score(
          ScoreProvince.custom,
          culture: '500',
          professional: '241',
          custom: const CustomScoreRule(decimals: 0),
        ).text,
        '551',
      );
      final rule = scoreRuleFor(
        ScoreProvince.custom,
        custom: const CustomScoreRule(culturePercent: 70, professionalFull: 100),
      );
      expect((rule.culturePercent, rule.professionalPercent, rule.professionalFull), (70, 30, 100));
    });
  });

  group('input handling', () {
    test('parses scores with up to two decimals', () {
      expect(parseScoreText('500'), 50000);
      expect(parseScoreText(' 245.5 '), 24550);
      expect(parseScoreText('245.55'), 24555);
      expect(parseScoreText('245.555'), isNull);
      expect(parseScoreText('-1'), isNull);
      expect(parseScoreText(''), isNull);
      expect(parseScoreText('abc'), isNull);
    });

    test('incomplete and out-of-range inputs', () {
      final rule = scoreRuleFor(ScoreProvince.gansu);
      final empty = computeScore(rule, culture: '', professional: '240');
      expect((empty.result, empty.error), (null, null));
      expect(computeScore(rule, culture: '800', professional: '240').error, contains('0–750'));
      expect(computeScore(rule, culture: '500', professional: '301').error, contains('0–300'));
      expect(computeScore(rule, culture: '5x', professional: '240').error, isNotNull);
      final fujian = scoreRuleFor(ScoreProvince.fujian);
      expect(
        computeScore(fujian, culture: '500', professional: '240', bonus: '1000').error,
        isNotNull,
      );
      expect(computeScore(rule, culture: '750', professional: '300').result!.text, '750.00');
    });
  });

  group('form persistence', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('remembers the last inputs', () async {
      final repository = ScoreFormRepository();
      expect((await repository.load()).province, ScoreProvince.gansu);
      const data = ScoreFormData(
        province: ScoreProvince.custom,
        culture: '512',
        professional: '186.5',
        bonus: '5',
        yunnanMode: YunnanMode.cultureOnly,
        custom: CustomScoreRule(culturePercent: 40, professionalFull: 200, decimals: 3),
      );
      await repository.save(data);
      final loaded = await ScoreFormRepository().load();
      expect(loaded.province, ScoreProvince.custom);
      expect((loaded.culture, loaded.professional, loaded.bonus), ('512', '186.5', '5'));
      expect(loaded.yunnanMode, YunnanMode.cultureOnly);
      expect(loaded.custom, data.custom);
      expect(loaded.outcome.result!.text, '624.425');
    });

    test('falls back to defaults for broken data', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        ScoreFormRepository.storageKey: '{"province":"mars","customProfessionalFull":99999}',
      });
      final loaded = await ScoreFormRepository().load();
      expect(loaded.province, ScoreProvince.gansu);
      expect(loaded.custom.professionalFull, kMaxProfessionalFull);
      SharedPreferences.setMockInitialValues(<String, Object>{
        ScoreFormRepository.storageKey: 'not json',
      });
      expect((await ScoreFormRepository().load()).culture, '');
    });
  });
}
