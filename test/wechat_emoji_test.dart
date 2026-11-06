import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_music_flutter/core/widgets/wechat_emoji.dart';

void main() {
  test('uses the mini-program panel order and atlas coordinates', () {
    expect(WechatEmoji.names, hasLength(108));
    expect(kWechatEmojiCategories, hasLength(6));
    expect(WechatEmoji.tokenForIndex(0), '[微笑]');
    expect(WechatEmoji.indexForToken('[红包]'), 107);

    final smile = WechatEmoji.spriteCellForToken('[微笑]');
    expect(smile?.left, 132);
    expect(smile?.top, 132);

    final decline = WechatEmoji.spriteCellForToken('[衰]');
    expect(decline?.left, 198);
    expect(decline?.top, 396);

    final grimace = WechatEmoji.spriteCellForToken('[撇嘴]');
    expect(grimace?.left, 660);
    expect(grimace?.top, 594);
    expect(grimace?.width, 63);
  });

  test('turns known mini-program tokens into sprite widget spans', () {
    final spans = buildWechatEmojiTextSpans(
      text: '你好[微笑][衰]未知[不存在]',
      baseStyle: const TextStyle(fontSize: 14),
      emojiSize: 18,
    );

    expect(spans.whereType<WidgetSpan>(), hasLength(2));
    expect(
      spans.whereType<TextSpan>().map((span) => span.text).join(),
      '你好未知[不存在]',
    );
  });
}
