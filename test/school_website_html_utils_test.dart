import 'package:flutter_test/flutter_test.dart';
import 'package:the_road_of_music_flutter/features/school_website/ui/widgets/school_website_html_utils.dart';

void main() {
  group('schoolWebsiteHtmlForEmbeddedView', () {
    test('injects layout policy into a complete document', () {
      const source = '<html><head><title>微校</title></head>'
          '<body><main><section>校园数据</section></main></body></html>';

      final result = schoolWebsiteHtmlForEmbeddedView(source);

      expect(result, contains('id="school-website-app-overrides"'));
      expect(result, contains('id="school-website-app-layout"'));
      expect(result, contains('data-school-app-inline-inset'));
      expect(result, contains('MutationObserver'));
      expect(
        result.indexOf('id="school-website-app-layout"'),
        lessThan(result.indexOf('</body>')),
      );
    });

    test('supports fragments without head or body tags', () {
      const source = '<section>校园数据</section>';

      final result = schoolWebsiteHtmlForEmbeddedView(source);

      expect(result, startsWith('<meta name="viewport"'));
      expect(result, endsWith('</script>\n'));
      expect(result, contains(source));
    });

    test('keeps empty html unchanged', () {
      expect(schoolWebsiteHtmlForEmbeddedView(''), isEmpty);
    });
  });
}
