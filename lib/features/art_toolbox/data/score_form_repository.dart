import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/score_calculator.dart';

/// 综合分计算器上次的输入（原样保存文本，下次打开直接回填）。
@immutable
class ScoreFormData {
  const ScoreFormData({
    this.province = ScoreProvince.gansu,
    this.culture = '',
    this.professional = '',
    this.bonus = '',
    this.yunnanMode = YunnanMode.balanced,
    this.custom = const CustomScoreRule(),
  });

  final ScoreProvince province;
  final String culture;
  final String professional;
  final String bonus;
  final YunnanMode yunnanMode;
  final CustomScoreRule custom;

  ScoreRule get rule =>
      scoreRuleFor(province, yunnan: yunnanMode, custom: custom);

  ScoreOutcome get outcome => computeScore(
    rule,
    culture: culture,
    professional: professional,
    bonus: bonus,
  );

  ScoreFormData copyWith({
    ScoreProvince? province,
    String? culture,
    String? professional,
    String? bonus,
    YunnanMode? yunnanMode,
    CustomScoreRule? custom,
  }) => ScoreFormData(
    province: province ?? this.province,
    culture: culture ?? this.culture,
    professional: professional ?? this.professional,
    bonus: bonus ?? this.bonus,
    yunnanMode: yunnanMode ?? this.yunnanMode,
    custom: custom ?? this.custom,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'province': province.name,
    'culture': culture,
    'professional': professional,
    'bonus': bonus,
    'yunnanMode': yunnanMode.name,
    'customCulturePercent': custom.culturePercent,
    'customProfessionalFull': custom.professionalFull,
    'customDecimals': custom.decimals,
  };

  static ScoreFormData fromJson(Object? json) {
    if (json is! Map) {
      return const ScoreFormData();
    }
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) {
      for (final value in values) {
        if (value.name == name) {
          return value;
        }
      }
      return fallback;
    }

    int number(Object? value, int fallback, int min, int max) {
      final parsed = value is num ? value.toInt() : int.tryParse('$value');
      return parsed == null ? fallback : parsed.clamp(min, max);
    }

    const defaults = CustomScoreRule();
    return ScoreFormData(
      province: pick(ScoreProvince.values, json['province'], ScoreProvince.gansu),
      culture: json['culture']?.toString() ?? '',
      professional: json['professional']?.toString() ?? '',
      bonus: json['bonus']?.toString() ?? '',
      yunnanMode: pick(YunnanMode.values, json['yunnanMode'], YunnanMode.balanced),
      custom: CustomScoreRule(
        culturePercent: number(
          json['customCulturePercent'],
          defaults.culturePercent,
          0,
          100,
        ),
        professionalFull: number(
          json['customProfessionalFull'],
          defaults.professionalFull,
          1,
          kMaxProfessionalFull,
        ),
        decimals: number(json['customDecimals'], defaults.decimals, 0, 3),
      ),
    );
  }
}

class ScoreFormRepository {
  static const storageKey = 'art_toolbox_score_form_v1';

  Future<ScoreFormData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) {
      return const ScoreFormData();
    }
    try {
      return ScoreFormData.fromJson(jsonDecode(raw));
    } catch (_) {
      return const ScoreFormData();
    }
  }

  Future<void> save(ScoreFormData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(data.toJson()));
  }
}
