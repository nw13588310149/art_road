import 'dart:typed_data';

/// 作品档案 / 作品点评的输入规则与展示格式（与阅卷系统接口校验一致）。
abstract final class ArtworkRules {
  static const imageLimit = 9;
  static const maxImageBytes = 20 * 1024 * 1024;
  static const titleLimit = 100;
  static const subjectLimit = 50;

  /// 作品说明写练习重点即可，比接口上限（2000）收紧。
  static const descriptionLimit = 200;
  static const commentLimit = 2000;
  static const tagsPerReview = 8;
  static const tagLimit = 50;
  static const tagNameLimit = 50;
  static const tagExplanationLimit = 500;
  static const defaultFullScore = 100.0;

  /// 点评标签分「问题」「亮点」两类，接口仍以颜色字段保存：亮点固定绿色，其余都按问题处理。
  static const problemTagColor = '#B9770F';
  static const highlightTagColor = '#3B9A6E';

  static bool isHighlightTag(String color, {bool positive = false}) =>
      positive || color.trim().toUpperCase() == highlightTagColor;

  static final _hexColor = RegExp(r'^#[0-9A-Fa-f]{6}$');

  static int lengthOf(String text) => text.trim().runes.length;

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String? validateDraft({
    required int imageCount,
    required String title,
    required String subject,
    required DateTime? drawingDate,
    required String description,
    DateTime? now,
  }) {
    if (imageCount == 0) {
      return '请至少选择 1 张作品照片';
    }
    if (imageCount > imageLimit) {
      return '每份作品最多 $imageLimit 张照片';
    }
    if (lengthOf(title) == 0) {
      return '请填写作品名称';
    }
    if (lengthOf(title) > titleLimit) {
      return '作品名称最多 $titleLimit 个字';
    }
    if (lengthOf(subject) == 0) {
      return '请选择或填写作品科目';
    }
    if (lengthOf(subject) > subjectLimit) {
      return '作品科目最多 $subjectLimit 个字';
    }
    if (drawingDate == null) {
      return '请选择绘画日期';
    }
    if (dateOnly(drawingDate).isAfter(dateOnly(now ?? DateTime.now()))) {
      return '绘画日期不能晚于今天';
    }
    if (lengthOf(description) > descriptionLimit) {
      return '作品说明最多 $descriptionLimit 个字';
    }
    return null;
  }

  /// 选图时的单张校验；返回 null 表示可用。
  static String? imageError(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) {
      return '无法读取照片内容，请重新选择';
    }
    if (bytes.length > maxImageBytes) {
      return '每张作品照片不能超过 20MB';
    }
    if (!isSupportedImage(bytes)) {
      return '照片格式不支持，请选择 JPG 或 PNG 照片';
    }
    return null;
  }

  /// 按文件头识别 JPG / PNG / GIF / WebP（HEIC 等格式无法在 Web 端显示）。
  static bool isSupportedImage(Uint8List b) {
    bool at(int offset, List<int> signature) {
      if (b.length < offset + signature.length) {
        return false;
      }
      for (var i = 0; i < signature.length; i++) {
        if (b[offset + i] != signature[i]) {
          return false;
        }
      }
      return true;
    }

    return at(0, const [0xFF, 0xD8, 0xFF]) ||
        at(0, const [0x89, 0x50, 0x4E, 0x47]) ||
        at(0, const [0x47, 0x49, 0x46, 0x38]) ||
        (at(0, const [0x52, 0x49, 0x46, 0x46]) &&
            at(8, const [0x57, 0x45, 0x42, 0x50]));
  }

  static bool atMostTwoDecimals(double value) =>
      ((value * 100) - (value * 100).roundToDouble()).abs() < 1e-6;

  /// 解析点评分数。分数留空表示只写评语 / 标签；[requiredFullScore] 非空时
  /// 满分沿用其他老师的满分。
  static ({double? score, double maxScore, String? error}) parseScore(
    String scoreText,
    String maxScoreText, {
    double? requiredFullScore,
  }) {
    final maxText = maxScoreText.trim();
    final maxScore =
        requiredFullScore ??
        (maxText.isEmpty ? defaultFullScore : double.tryParse(maxText));
    if (maxScore == null ||
        !maxScore.isFinite ||
        maxScore <= 0 ||
        !atMostTwoDecimals(maxScore)) {
      return (
        score: null,
        maxScore: defaultFullScore,
        error: '满分须为大于 0 的数字，最多两位小数',
      );
    }
    final text = scoreText.trim();
    if (text.isEmpty) {
      return (score: null, maxScore: maxScore, error: null);
    }
    final score = double.tryParse(text);
    if (score == null ||
        !score.isFinite ||
        score < 0 ||
        !atMostTwoDecimals(score)) {
      return (score: null, maxScore: maxScore, error: '分数须为不小于 0 的数字，最多两位小数');
    }
    if (score > maxScore) {
      return (
        score: null,
        maxScore: maxScore,
        error: '分数不能超过满分 ${formatScore(maxScore)}',
      );
    }
    return (score: score, maxScore: maxScore, error: null);
  }

  static String? validateReview({
    required double? score,
    required int tagCount,
    required String comment,
  }) {
    if (lengthOf(comment) > commentLimit) {
      return '评语最多 $commentLimit 个字';
    }
    if (tagCount > tagsPerReview) {
      return '每份作品最多选择 $tagsPerReview 个标签';
    }
    if (score == null && tagCount == 0 && lengthOf(comment) == 0) {
      return '请至少填写分数、选择标签或填写评语';
    }
    return null;
  }

  static String? validateTag({
    required String name,
    required String explanation,
    required String color,
    Iterable<String> otherNames = const <String>[],
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '请填写标签名称';
    }
    if (lengthOf(trimmed) > tagNameLimit) {
      return '标签名称最多 $tagNameLimit 个字';
    }
    if (lengthOf(explanation) > tagExplanationLimit) {
      return '标签解释最多 $tagExplanationLimit 个字';
    }
    if (!_hexColor.hasMatch(color)) {
      return '请选择标签颜色';
    }
    final lower = trimmed.toLowerCase();
    if (otherNames.any((n) => n.trim().toLowerCase() == lower)) {
      return '已有同名标签，请换一个名称';
    }
    return null;
  }

  /// 展示用分数：最多一位小数（88 / 87.5 / 84.7）；空值显示「—」。
  static String displayScore(num? value) {
    if (value == null) {
      return '—';
    }
    final rounded = (value * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1);
  }

  /// 输入框里的分数：最多两位小数并去掉末尾的 0（88 / 87.5 / 86.33）；空值显示「—」。
  static String formatScore(num? value) {
    if (value == null) {
      return '—';
    }
    var text = value.toStringAsFixed(2);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '');
      if (text.endsWith('.')) {
        text = text.substring(0, text.length - 1);
      }
    }
    return text;
  }

  static String ymd(DateTime value) =>
      '${value.year}-${_two(value.month)}-${_two(value.day)}';

  /// `yyyy-MM-dd HH:mm:ss` → `MM-dd HH:mm`（同年）或 `yyyy-MM-dd HH:mm`。
  static String shortTime(String raw, {DateTime? now}) {
    final parsed = DateTime.tryParse(raw.trim().replaceFirst(' ', 'T'));
    if (parsed == null) {
      return raw;
    }
    final time = '${_two(parsed.hour)}:${_two(parsed.minute)}';
    final sameYear = parsed.year == (now ?? DateTime.now()).year;
    return sameYear
        ? '${_two(parsed.month)}-${_two(parsed.day)} $time'
        : '${ymd(parsed)} $time';
  }

  /// `yyyy-MM-dd HH:mm:ss` / `yyyy-MM-dd` → `yyyy-MM-dd`。
  static String dateText(String raw) {
    final text = raw.trim();
    return text.length >= 10 ? text.substring(0, 10) : text;
  }

  /// 按绘画日期的月份分组（保持原有顺序）：`[('2026-10', [...]), ...]`。
  static List<(String, List<T>)> groupByMonth<T>(
    List<T> items,
    String Function(T item) dateOf,
  ) {
    final groups = <(String, List<T>)>[];
    for (final item in items) {
      final date = dateOf(item).trim();
      final key = date.length >= 7 ? date.substring(0, 7) : '';
      if (groups.isEmpty || groups.last.$1 != key) {
        groups.add((key, <T>[item]));
      } else {
        groups.last.$2.add(item);
      }
    }
    return groups;
  }

  /// `2026-10` → `2026 年 10 月`。
  static String monthLabel(String key) {
    final parts = key.split('-');
    final month = parts.length == 2 ? int.tryParse(parts[1]) : null;
    if (month == null) {
      return '更早';
    }
    return '${parts[0]} 年 $month 月';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
