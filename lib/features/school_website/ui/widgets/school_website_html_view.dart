// 平台分发：完整 HTML 文档（含 <style>/<script>/CSS Grid 等）必须交给真正的
// 浏览器内核渲染——Web 用 <iframe srcdoc>，原生用 webview_flutter。
//
// 与项目其它平台分发文件（theory_pdf_view 等）一致，用 `dart.library.html`
// 判断：默认走原生实现，Web 编译时覆盖为 iframe 实现。
export 'school_website_html_view_io.dart'
    if (dart.library.html) 'school_website_html_view_web.dart';
