import 'quiz_html.dart';

/// 供 [compute] 预热 isolate，避免首次进入做题页时才冷启动 worker。
List<Map<String, dynamic>> warmupQuizQuestionParser(void _) =>
    const <Map<String, dynamic>>[];

/// 在后台 isolate 解析题目列表：HTML strip / 媒体检测均在此完成。
List<Map<String, dynamic>> parseQuizQuestionsPayload(dynamic data) {
  if (data is! List) return const <Map<String, dynamic>>[];

  final list = <Map<String, dynamic>>[];
  for (final item in data) {
    if (item is! Map) continue;
    final question = item['question'];
    if (question is! Map) continue;

    final id = _toInt(item['id']);
    if (id == null) continue;

    final questionHtml = _asString(question['question']);
    final options = <String>[
      _asString(question['param1']),
      _asString(question['param2']),
      _asString(question['param3']),
      _asString(question['param4']),
    ];
    final parseHtml = _asString(question['parse']);

    list.add(<String, dynamic>{
      'itemId': id,
      'questionHtml': questionHtml,
      'options': options,
      'correctAnswer': _toInt(question['answer']) ?? 0,
      'parseHtml': parseHtml,
      'userAnswer': _toInt(item['answer']),
      'status': _toInt(item['status']) ?? 0,
      'questionStripped': stripHtmlToText(questionHtml),
      'parseStripped': stripHtmlToText(parseHtml),
      'optionsStripped': options.map(stripHtmlToText).toList(growable: false),
      'questionHasMedia': htmlHasMedia(questionHtml),
      'questionHasInlineRich': htmlHasInlineRich(questionHtml),
      'parseHasMedia': htmlHasMedia(parseHtml),
      'parseHasInlineRich': htmlHasInlineRich(parseHtml),
      'optionsHasMedia': options.map(htmlHasMedia).toList(growable: false),
      'optionsHasInlineRich':
          options.map(htmlHasInlineRich).toList(growable: false),
    });
  }
  return list;
}

String _asString(dynamic value) {
  if (value == null) return '';
  return value.toString();
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
