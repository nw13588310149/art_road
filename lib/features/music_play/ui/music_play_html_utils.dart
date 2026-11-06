import 'package:flutter/material.dart';

import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

/// 与 AI 聊天正文（`_MessageText` baseStyle）一致的排版。
const Color kMusicPlayAiBodyTextColor = Color(0xFF0B081A);
const double kMusicPlayAiBodyFontSize = 14;
const double kMusicPlayAiBodyLineHeight = 1.7;

TextStyle musicPlayAiBodyTextStyle({double? fontSize}) {
  return TextStyle(
    color: kMusicPlayAiBodyTextColor,
    fontSize: fontSize ?? kMusicPlayAiBodyFontSize,
    fontFamily: 'PingFang SC',
    fontWeight: AppFont.w400,
    height: kMusicPlayAiBodyLineHeight,
  );
}

/// 去掉内联 `font-family`，避免盖掉 [HtmlWidget] 的 `textStyle`。
String musicPlayHtmlForcePingFangSc(String html) {
  return _musicPlayHtmlStripInlineProps(
    html,
    props: const <String>['font-family'],
  );
}

/// 去掉内联排版属性，便于统一为 AI 正文样式。
String musicPlayHtmlStripInlineTypography(String html) {
  return _musicPlayHtmlStripInlineProps(
    html,
    props: const <String>[
      'font-family',
      'font-size',
      'font-weight',
      'line-height',
      'color',
    ],
  );
}

String _musicPlayHtmlStripInlineProps(String html, {required List<String> props}) {
  if (html.isEmpty) return html;

  var result = html;
  for (final prop in props) {
    result = result.replaceAll(
      RegExp(
        '${RegExp.escape(prop)}\\s*:\\s*[^;}>]+(?:\\s*!important)?\\s*;?',
        caseSensitive: false,
      ),
      '',
    );
  }

  result = result.replaceAllMapped(
    RegExp(
      r'(\s)face\s*=\s*(?:"[^"]*"|[^\s>]+)',
      caseSensitive: false,
    ),
    (match) => match.group(1)!,
  );

  result = result.replaceAllMapped(
    RegExp(r'\sstyle\s*=\s*"\s*"\s*', caseSensitive: false),
    (_) => ' ',
  );
  result = result.replaceAllMapped(
    RegExp(r"\sstyle\s*=\s*'\s*'\s*", caseSensitive: false),
    (_) => ' ',
  );

  return result;
}

/// 将 `<strong>` / `<b>` 强制替换为带粗体内联样式的 `<span>`，
/// 避免 [HtmlWidget] 未正确识别语义标签导致不加粗。
String musicPlayHtmlForceBoldTags(String html) {
  if (html.isEmpty) return html;

  const boldOpen = '<span style="font-weight: 600 !important;">';
  var result = html.replaceAllMapped(
    RegExp(r'<\s*(strong|b)\b[^>]*>', caseSensitive: false),
    (_) => boldOpen,
  );
  result = result.replaceAllMapped(
    RegExp(r'<\s*/\s*(strong|b)\s*>', caseSensitive: false),
    (_) => '</span>',
  );
  return result;
}

const Set<String> _musicPlayHtmlTextTags = <String>{
  'p',
  'span',
  'div',
  'li',
  'td',
  'th',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'strong',
  'em',
  'b',
  'i',
  'u',
  'a',
  'font',
  'label',
  'blockquote',
};

const Set<String> _musicPlayHtmlBoldTags = <String>{'strong', 'b'};

Map<String, String> _musicPlayAiBodyCss({bool bold = false}) {
  return <String, String>{
    'font-family': 'PingFang SC',
    'font-size': '${kMusicPlayAiBodyFontSize}px',
    'color': '#0B081A',
    'font-weight': bold ? '600' : '400',
    'line-height': '$kMusicPlayAiBodyLineHeight',
  };
}

/// 深色长文面板：仅统一字体，保留 HTML 自带颜色/字号。
Map<String, String>? musicPlayHtmlCustomStyles(dynamic element) {
  final tag = element.localName?.toLowerCase();
  if (tag == null || !_musicPlayHtmlTextTags.contains(tag)) {
    return null;
  }
  final styles = <String, String>{'font-family': 'PingFang SC'};
  if (_musicPlayHtmlBoldTags.contains(tag)) {
    styles['font-weight'] = '600';
  }
  if (tag == 'p') {
    styles['margin'] = '0';
    styles['padding'] = '0';
  }
  return styles;
}

/// 声乐/器乐简介卡片：强制对齐 AI 正文排版。
Map<String, String>? musicPlayDescriptionHtmlCustomStyles(dynamic element) {
  final tag = element.localName?.toLowerCase();
  if (tag == null || !_musicPlayHtmlTextTags.contains(tag)) {
    return null;
  }
  final styles = _musicPlayAiBodyCss(bold: _musicPlayHtmlBoldTags.contains(tag));
  if (tag == 'p') {
    styles['margin'] = '0';
    styles['padding'] = '0';
  }
  return styles;
}
