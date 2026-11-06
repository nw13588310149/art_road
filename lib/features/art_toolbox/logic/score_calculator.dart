/// 艺术类综合分（排序成绩）估算：各省预设公式，成绩按 0.01 分为单位做整数运算，避免浮点误差。
library;

const int kCultureFullScore = 750;
const int kDefaultProfessionalFull = 300;

/// 自定义专业满分的上限（同时保证 Web 上整数运算不超出安全范围）。
const int kMaxProfessionalFull = 1000;

/// 每个页面都显示的提示。
const String kScoreDisclaimer = '各省以当年省教育考试院公布为准';

enum ScoreProvince {
  gansu('甘肃'),
  anhui('安徽'),
  beijing('北京'),
  fujian('福建'),
  heilongjiang('黑龙江'),
  yunnan('云南'),
  custom('自定义');

  const ScoreProvince(this.label);

  final String label;
}

enum YunnanMode {
  balanced('50/50', '文化 50% + 专业 50%'),
  cultureWeighted('70/30', '文化 70% + 专业 30%'),
  cultureOnly('按文化成绩', '专业合格后按文化成绩');

  const YunnanMode(this.label, this.description);

  final String label;
  final String description;
}

/// 专业成绩折算到 750 分制的写法，数值上等价，只影响计算过程的展示。
enum ProfessionalStyle {
  /// 专业 ÷ 满分 × 750
  divide,

  /// 专业 × 750 ÷ 满分
  scale,

  /// 专业 × 2.5（满分 300 时）
  multiply,
}

class CustomScoreRule {
  const CustomScoreRule({
    this.culturePercent = 50,
    this.professionalFull = kDefaultProfessionalFull,
    this.decimals = 2,
  });

  /// 文化成绩权重 0–100，专业成绩权重为 100 减去它。
  final int culturePercent;
  final int professionalFull;

  /// 保留小数位 0–3。
  final int decimals;

  CustomScoreRule copyWith({
    int? culturePercent,
    int? professionalFull,
    int? decimals,
  }) => CustomScoreRule(
    culturePercent: culturePercent ?? this.culturePercent,
    professionalFull: professionalFull ?? this.professionalFull,
    decimals: decimals ?? this.decimals,
  );

  @override
  bool operator ==(Object other) =>
      other is CustomScoreRule &&
      other.culturePercent == culturePercent &&
      other.professionalFull == professionalFull &&
      other.decimals == decimals;

  @override
  int get hashCode => Object.hash(culturePercent, professionalFull, decimals);
}

class ScoreRule {
  const ScoreRule({
    required this.culturePercent,
    required this.professionalPercent,
    required this.formula,
    required this.source,
    this.professionalFull = kDefaultProfessionalFull,
    this.decimals = 2,
    this.withBonus = false,
    this.style = ProfessionalStyle.divide,
    this.note = '',
  });

  final int culturePercent;
  final int professionalPercent;
  final int professionalFull;
  final int decimals;

  /// 文化成绩可加政策加分（福建）。
  final bool withBonus;
  final ProfessionalStyle style;
  final String formula;
  final String source;
  final String note;

  bool get cultureOnly => professionalPercent == 0;
}

ScoreRule scoreRuleFor(
  ScoreProvince province, {
  YunnanMode yunnan = YunnanMode.balanced,
  CustomScoreRule custom = const CustomScoreRule(),
}) {
  switch (province) {
    case ScoreProvince.gansu:
      return const ScoreRule(
        culturePercent: 50,
        professionalPercent: 50,
        formula: '排序成绩 = 文化成绩 × 50% + 专业成绩 ÷ 300 × 750 × 50%',
        source: '甘肃省教育考试院《关于做好2026年甘肃省普通高等学校艺术类专业考试招生工作的通知》',
        note: '美术与设计类，保留两位小数',
      );
    case ScoreProvince.anhui:
      return const ScoreRule(
        culturePercent: 50,
        professionalPercent: 50,
        style: ProfessionalStyle.multiply,
        formula: '综合分 = 文化成绩 × 50% + 专业成绩 × 2.5 × 50%',
        source: '安徽省教育招生考试院艺术类专业录取规则',
        note: '结果按两位小数显示',
      );
    case ScoreProvince.beijing:
      return const ScoreRule(
        culturePercent: 50,
        professionalPercent: 50,
        decimals: 0,
        formula: '综合分 = 专业成绩 ÷ 300 × 750 × 50% + 文化成绩 × 50%',
        source: '北京教育考试院艺术类本科录取规则（2025 年）',
        note: '本科批次，四舍五入取整',
      );
    case ScoreProvince.fujian:
      return const ScoreRule(
        culturePercent: 50,
        professionalPercent: 50,
        withBonus: true,
        style: ProfessionalStyle.multiply,
        formula: '综合分 = （文化成绩 + 政策加分）× 50% + 专业成绩 × 2.5 × 50%',
        source: '福建省教育考试院艺术类录取规则（2025 年）',
        note: '结果按两位小数显示',
      );
    case ScoreProvince.heilongjiang:
      return const ScoreRule(
        culturePercent: 60,
        professionalPercent: 40,
        formula: '综合分 = （专业成绩 ÷ 专业满分 × 750）× 40% + 文化成绩 × 60%',
        source: '黑龙江省招生考试院美术与设计类录取规则',
        note: '美术与设计类，结果按两位小数显示',
      );
    case ScoreProvince.yunnan:
      return switch (yunnan) {
        YunnanMode.balanced => const ScoreRule(
          culturePercent: 50,
          professionalPercent: 50,
          style: ProfessionalStyle.scale,
          formula: '综合分 = 文化成绩 × 50% + 专业成绩 × 750 ÷ 300 × 50%',
          source: '云南省招生考试院艺术类录取规则（院校按招生章程选用计算方式）',
          note: '结果按两位小数显示',
        ),
        YunnanMode.cultureWeighted => const ScoreRule(
          culturePercent: 70,
          professionalPercent: 30,
          style: ProfessionalStyle.scale,
          formula: '综合分 = 文化成绩 × 70% + 专业成绩 × 750 ÷ 300 × 30%',
          source: '云南省招生考试院艺术类录取规则（院校按招生章程选用计算方式）',
          note: '结果按两位小数显示',
        ),
        YunnanMode.cultureOnly => const ScoreRule(
          culturePercent: 100,
          professionalPercent: 0,
          formula: '专业成绩达到合格线后，按文化成绩排序',
          source: '云南省招生考试院艺术类录取规则（院校按招生章程选用计算方式）',
          note: '专业成绩只作合格判断',
        ),
      };
    case ScoreProvince.custom:
      final culture = custom.culturePercent.clamp(0, 100);
      final full = custom.professionalFull.clamp(1, kMaxProfessionalFull);
      final decimals = custom.decimals.clamp(0, 3);
      return ScoreRule(
        culturePercent: culture,
        professionalPercent: 100 - culture,
        professionalFull: full,
        decimals: decimals,
        formula:
            '综合分 = 文化成绩 × $culture% + 专业成绩 ÷ $full × 750 × ${100 - culture}%',
        source: '自定义公式',
        note: decimals == 0 ? '四舍五入取整' : '保留 $decimals 位小数',
      );
  }
}

/// 解析成绩文本（最多两位小数），返回以 0.01 分为单位的整数；为空或格式不对返回 null。
int? parseScoreText(String text) {
  final match = RegExp(r'^(\d{1,4})(?:\.(\d{1,2}))?$').firstMatch(text.trim());
  if (match == null) {
    return null;
  }
  final fraction = match.group(2) ?? '';
  return int.parse(match.group(1)!) * 100 +
      (fraction.isEmpty ? 0 : int.parse(fraction.padRight(2, '0')));
}

class ScoreStep {
  const ScoreStep(this.label, this.expression);

  final String label;
  final String expression;
}

class ScoreResult {
  const ScoreResult({
    required this.scaled,
    required this.decimals,
    required this.steps,
  });

  /// 结果乘以 10^[decimals] 后的整数。
  final int scaled;
  final int decimals;
  final List<ScoreStep> steps;

  double get value => scaled / _pow10(decimals);

  String get text => _fixed(scaled, decimals);
}

/// 计算结果：输入不完整时 [result] 与 [error] 都为空。
class ScoreOutcome {
  const ScoreOutcome._({this.result, this.error});

  const ScoreOutcome.incomplete() : this._();

  final ScoreResult? result;
  final String? error;
}

ScoreOutcome computeScore(
  ScoreRule rule, {
  required String culture,
  required String professional,
  String bonus = '',
}) {
  final cultureText = culture.trim();
  final professionalText = professional.trim();
  final bonusText = bonus.trim();
  final needsProfessional = !rule.cultureOnly;
  if (cultureText.isEmpty || (needsProfessional && professionalText.isEmpty)) {
    return const ScoreOutcome.incomplete();
  }
  final c = parseScoreText(cultureText);
  if (c == null || c > kCultureFullScore * 100) {
    return const ScoreOutcome._(error: '文化课成绩应在 0–750 之间，小数不超过两位');
  }
  var p = 0;
  if (needsProfessional) {
    final parsed = parseScoreText(professionalText);
    if (parsed == null || parsed > rule.professionalFull * 100) {
      return ScoreOutcome._(
        error: '专业成绩应在 0–${rule.professionalFull} 之间，小数不超过两位',
      );
    }
    p = parsed;
  }
  var b = 0;
  if (rule.withBonus && bonusText.isNotEmpty) {
    final parsed = parseScoreText(bonusText);
    if (parsed == null || parsed > 100 * 100) {
      return const ScoreOutcome._(error: '政策加分应在 0–100 之间，小数不超过两位');
    }
    b = parsed;
  }
  return ScoreOutcome._(result: _calculate(rule, c, p, b));
}

ScoreResult _calculate(ScoreRule rule, int culture, int professional, int bonus) {
  final full = rule.professionalFull;
  final decimals = rule.decimals;
  if (rule.cultureOnly) {
    final scaled = _roundHalfUp(culture, 100, decimals);
    return ScoreResult(
      scaled: scaled,
      decimals: decimals,
      steps: [ScoreStep('按文化成绩', '${_input(culture)} 分（专业成绩需达到合格线）')],
    );
  }
  // 文化部分 = (文化 + 加分) × cw ÷ 100，专业部分 = 专业 × 750 × pw ÷ (满分 × 100)，成绩以 0.01 分为单位。
  final cultureNum = (culture + bonus) * rule.culturePercent;
  const cultureDen = 10000;
  final professionalNum = professional * kCultureFullScore * rule.professionalPercent;
  final professionalDen = 10000 * full;
  final totalNum = cultureNum * full + professionalNum;
  final totalDen = cultureDen * full;
  final scaled = _roundHalfUp(totalNum, totalDen, decimals);

  final cultureExpression = rule.withBonus
      ? '（${_input(culture)} + ${_input(bonus)}）× ${rule.culturePercent}%'
      : '${_input(culture)} × ${rule.culturePercent}%';
  final p = _input(professional);
  final professionalInput = switch (rule.style) {
    ProfessionalStyle.divide => '$p ÷ $full × 750',
    ProfessionalStyle.scale => '$p × 750 ÷ $full',
    ProfessionalStyle.multiply => '$p × ${_trim(kCultureFullScore / full)}',
  };
  final culturePart = _part(cultureNum, cultureDen);
  final professionalPart = _part(professionalNum, professionalDen);
  final exactTotal = _part(totalNum, totalDen);
  final rounded = _fixed(scaled, decimals);
  final roundingText = exactTotal == rounded
      ? ''
      : (decimals == 0 ? '，四舍五入取整为 $rounded' : '，保留 $decimals 位小数为 $rounded');
  return ScoreResult(
    scaled: scaled,
    decimals: decimals,
    steps: [
      ScoreStep(
        rule.withBonus ? '文化部分（含政策加分）' : '文化部分',
        '$cultureExpression = $culturePart',
      ),
      ScoreStep(
        '专业部分',
        '$professionalInput × ${rule.professionalPercent}% = $professionalPart',
      ),
      ScoreStep(
        '综合分',
        '$culturePart + $professionalPart = $exactTotal$roundingText',
      ),
    ],
  );
}

int _pow10(int n) {
  var v = 1;
  for (var i = 0; i < n; i++) {
    v *= 10;
  }
  return v;
}

/// 非负有理数 [num] / [den] 四舍五入到 [decimals] 位，返回乘以 10^decimals 的整数。
int _roundHalfUp(int num, int den, int decimals) =>
    (num * _pow10(decimals) * 2 + den) ~/ (den * 2);

String _fixed(int scaled, int decimals) {
  if (decimals == 0) {
    return '$scaled';
  }
  final unit = _pow10(decimals);
  return '${scaled ~/ unit}.${(scaled % unit).toString().padLeft(decimals, '0')}';
}

/// 计算过程里的中间值：两位小数能精确表示时写两位，否则最多四位，仍除不尽时加「≈」。
String _part(int num, int den) {
  for (final decimals in const [2, 3, 4]) {
    if ((num * _pow10(decimals)) % den == 0) {
      return _fixed(num * _pow10(decimals) ~/ den, decimals);
    }
  }
  return '≈${_fixed(_roundHalfUp(num, den, 4), 4)}';
}

/// 输入的成绩原样显示：整数不带小数，有小数时去掉末尾的 0。
String _input(int hundredths) {
  if (hundredths % 100 == 0) {
    return '${hundredths ~/ 100}';
  }
  final text = _fixed(hundredths, 2);
  return text.endsWith('0') ? text.substring(0, text.length - 1) : text;
}

String _trim(double value) {
  final text = value.toStringAsFixed(4);
  return text.contains('.')
      ? text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
      : text;
}
