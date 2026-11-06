const _viewportMeta =
    '<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">';

const _injectedStyles = '''
<style id="school-website-app-overrides">
html, body {
  width: 100% !important;
  max-width: 100% !important;
  min-width: 0 !important;
  margin: 0 !important;
  padding: 0 !important;
  overflow-x: hidden !important;
  -ms-overflow-style: none;
  scrollbar-width: none;
  box-sizing: border-box;
}
*, *::before, *::after {
  box-sizing: border-box;
}
img, video, iframe, table {
  max-width: 100% !important;
  height: auto;
}
#app, #root, main, .page, .main, .container, .wrapper, .content,
[class*="container"], [class*="wrapper"], [class*="content"],
[class*="section"], [class*="card"] {
  max-width: 100% !important;
  min-width: 0 !important;
}
html::-webkit-scrollbar,
body::-webkit-scrollbar {
  display: none;
  width: 0;
  height: 0;
}
.hero-carousel-nav {
  display: none !important;
}
</style>
''';

/// 后端页面并不共享统一的布局实现：部分区块使用 `margin-left + width: 100%`，
/// 在嵌入视图中会形成「左侧有间距、右侧贴边或溢出」。此脚本以实际 viewport 为准，
/// 只修正这类宽区块；本来左右对称的轮播、卡片不会被改写。
const _layoutScript = '''
<script id="school-website-app-layout">
(function () {
  var insetAttribute = 'data-school-app-inline-inset';
  var scheduled = false;
  var running = false;
  var candidateSelector = [
    'body > *',
    '#app > *',
    '#root > *',
    'main > *',
    '.page > *',
    '.main > *',
    '.container > *',
    '.wrapper > *',
    '.content > *',
    'section',
    '[class*="section"]'
  ].join(',');

  function setDocumentBounds(width) {
    var px = width + 'px';
    var root = document.documentElement;
    var body = document.body;
    root.style.setProperty('width', px, 'important');
    root.style.setProperty('max-width', px, 'important');
    root.style.setProperty('overflow-x', 'hidden', 'important');
    if (!body) return;
    body.style.setProperty('width', px, 'important');
    body.style.setProperty('max-width', px, 'important');
    body.style.setProperty('overflow-x', 'hidden', 'important');
    body.style.setProperty('margin', '0', 'important');
    body.style.setProperty('padding-left', '0', 'important');
    body.style.setProperty('padding-right', '0', 'important');
  }

  function applySymmetricWidth(element, viewportWidth, inset) {
    var targetWidth = Math.max(0, viewportWidth - inset * 2);
    var px = targetWidth + 'px';
    element.setAttribute(insetAttribute, String(inset));
    element.style.setProperty('width', px, 'important');
    element.style.setProperty('max-width', px, 'important');
    element.style.setProperty('min-width', '0', 'important');
  }

  function normalizeWideBlocks(viewportWidth) {
    if (!document.body) return;
    var elements = document.querySelectorAll(candidateSelector);
    for (var i = 0; i < elements.length; i++) {
      var element = elements[i];
      var storedInset = element.getAttribute(insetAttribute);
      if (storedInset !== null) {
        var remembered = parseFloat(storedInset);
        if (isFinite(remembered) && remembered > 0) {
          applySymmetricWidth(element, viewportWidth, remembered);
        }
        continue;
      }

      var style = window.getComputedStyle(element);
      if (style.position === 'fixed' || style.position === 'absolute') continue;

      var rect = element.getBoundingClientRect();
      if (rect.width < viewportWidth * 0.55 || rect.height <= 0) continue;

      var leftInset = Math.max(0, rect.left);
      var rightInset = Math.max(0, viewportWidth - rect.right);
      if (leftInset < 4 || rightInset >= leftInset - 1.5) continue;

      applySymmetricWidth(element, viewportWidth, leftInset);
    }
  }

  function fit() {
    if (running) return;
    running = true;
    try {
      var width = document.documentElement.clientWidth || window.innerWidth;
      if (!width || width <= 0) return;
      setDocumentBounds(width);
      normalizeWideBlocks(width);
    } finally {
      running = false;
    }
  }

  function scheduleFit() {
    if (scheduled) return;
    scheduled = true;
    var enqueue = window.requestAnimationFrame || function (callback) {
      return window.setTimeout(callback, 0);
    };
    enqueue(function () {
      scheduled = false;
      fit();
    });
  }

  scheduleFit();
  window.addEventListener('resize', scheduleFit);
  window.addEventListener('load', scheduleFit);
  document.addEventListener('DOMContentLoaded', scheduleFit);

  try {
    var resizeObserver = new ResizeObserver(scheduleFit);
    resizeObserver.observe(document.documentElement);
    if (document.body) resizeObserver.observe(document.body);
  } catch (e) {}

  try {
    var mutationObserver = new MutationObserver(scheduleFit);
    mutationObserver.observe(document.documentElement, {
      childList: true,
      subtree: true
    });
  } catch (e) {}
})();
</script>
''';

const _injectedHeadFragment = '$_viewportMeta$_injectedStyles';
const _injectedTailFragment = _layoutScript;

/// 在官网 HTML 文档内注入 App 端样式覆盖：viewport、隐藏滚动条、隐藏轮播左右箭头、
/// 禁止横向溢出。
String schoolWebsiteHtmlForEmbeddedView(String html) {
  if (html.isEmpty) return html;

  var doc = _injectHead(html);
  doc = _injectBeforeBodyClose(doc);
  return doc;
}

String _injectHead(String html) {
  final lower = html.toLowerCase();
  final headClose = lower.indexOf('</head>');
  if (headClose >= 0) {
    return '${html.substring(0, headClose)}$_injectedHeadFragment${html.substring(headClose)}';
  }

  final headOpen = lower.indexOf('<head');
  if (headOpen >= 0) {
    final headTagEnd = lower.indexOf('>', headOpen);
    if (headTagEnd >= 0) {
      final insertAt = headTagEnd + 1;
      return '${html.substring(0, insertAt)}$_injectedHeadFragment${html.substring(insertAt)}';
    }
  }

  return '$_injectedHeadFragment$html';
}

String _injectBeforeBodyClose(String html) {
  final lower = html.toLowerCase();
  final bodyClose = lower.indexOf('</body>');
  if (bodyClose >= 0) {
    return '${html.substring(0, bodyClose)}$_injectedTailFragment${html.substring(bodyClose)}';
  }
  return '$html$_injectedTailFragment';
}
