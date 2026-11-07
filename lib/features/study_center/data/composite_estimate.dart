import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../art_toolbox/logic/score_calculator.dart';

/// 学情页「综合分预估」可选的省份；自定义公式到画室工具箱的综合分计算器里设置。
const compositeEstimateProvinces = <ScoreProvince>[
  ScoreProvince.gansu,
  ScoreProvince.anhui,
  ScoreProvince.beijing,
  ScoreProvince.fujian,
  ScoreProvince.heilongjiang,
  ScoreProvince.yunnan,
];

/// 专业成绩按 300 分制参与计算：考试满分不是 300 时按比例折算，保留两位小数。
double? professionalOn300(double? score, double? fullScore) {
  if (score == null) {
    return null;
  }
  final full = fullScore ?? kDefaultProfessionalFull.toDouble();
  if (full <= 0) {
    return null;
  }
  final scaled = full == kDefaultProfessionalFull
      ? score
      : score * kDefaultProfessionalFull / full;
  return (scaled * 100).round() / 100;
}

/// 分数写成计算器能解析的文本：最多两位小数，去掉末尾的 0。
String scoreInputText(double value) {
  var text = value.toStringAsFixed(2);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return text;
}

@immutable
class CompositeEstimate {
  const CompositeEstimate({
    required this.rule,
    this.professional,
    this.result,
    this.cultureError,
    this.target,
    this.targetError,
    this.gap,
  });

  final ScoreRule rule;

  /// 参与计算的专业成绩（300 分制）；没有已出分的考试时为空。
  final double? professional;

  /// 文化课预估分为空或格式不对时为空。
  final ScoreResult? result;
  final String? cultureError;
  final double? target;
  final String? targetError;

  /// 目标分减预估分（两位小数）：大于 0 表示还差多少，不大于 0 表示已达到。
  final double? gap;
}

/// 用画室工具箱的综合分计算器（[computeScore]）按省份公式估算。
CompositeEstimate estimateComposite({
  required ScoreProvince province,
  required double? professionalScore,
  double? professionalFull,
  required String culture,
  String target = '',
}) {
  final rule = scoreRuleFor(province);
  final professional = professionalOn300(professionalScore, professionalFull);
  ScoreResult? result;
  String? cultureError;
  if (professional != null) {
    final outcome = computeScore(
      rule,
      culture: culture,
      professional: scoreInputText(professional),
    );
    result = outcome.result;
    cultureError = outcome.error;
  }

  double? targetValue;
  String? targetError;
  final targetText = target.trim();
  if (targetText.isNotEmpty) {
    final parsed = parseScoreText(targetText);
    if (parsed == null || parsed > kCultureFullScore * 100) {
      targetError = '目标分应在 0–750 之间，小数不超过两位';
    } else {
      targetValue = parsed / 100;
    }
  }

  final value = result?.value;
  return CompositeEstimate(
    rule: rule,
    professional: professional,
    result: result,
    cultureError: cultureError,
    target: targetValue,
    targetError: targetError,
    gap: value == null || targetValue == null
        ? null
        : ((targetValue - value) * 100).round() / 100,
  );
}

/// 学生填写的预估输入，原样保存文本，下次打开直接回填。
@immutable
class CompositeEstimateForm {
  const CompositeEstimateForm({
    this.province = ScoreProvince.gansu,
    this.culture = '',
    this.target = '',
  });

  final ScoreProvince province;
  final String culture;
  final String target;

  CompositeEstimateForm copyWith({
    ScoreProvince? province,
    String? culture,
    String? target,
  }) => CompositeEstimateForm(
    province: province ?? this.province,
    culture: culture ?? this.culture,
    target: target ?? this.target,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'province': province.name,
    'culture': culture,
    'target': target,
  };

  static CompositeEstimateForm fromJson(Object? json) {
    if (json is! Map) {
      return const CompositeEstimateForm();
    }
    final province = compositeEstimateProvinces
        .where((p) => p.name == json['province'])
        .firstOrNull;
    return CompositeEstimateForm(
      province: province ?? ScoreProvince.gansu,
      culture: json['culture']?.toString() ?? '',
      target: json['target']?.toString() ?? '',
    );
  }
}

/// 预估输入保存在本机，按账号（手机号）分开存。
class CompositeEstimateStore {
  const CompositeEstimateStore({this.account = ''});

  static const _key = 'study_composite_estimate_v1';

  final String account;

  String get storageKey => account.trim().isEmpty ? _key : '$_key:${account.trim()}';

  Future<CompositeEstimateForm> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) {
      return const CompositeEstimateForm();
    }
    try {
      return CompositeEstimateForm.fromJson(jsonDecode(raw));
    } catch (_) {
      return const CompositeEstimateForm();
    }
  }

  Future<void> save(CompositeEstimateForm form) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(form.toJson()));
  }
}
