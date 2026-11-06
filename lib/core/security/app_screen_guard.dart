/// 全应用截屏 / 录屏防护（iOS / Android）。
///
/// Web / 桌面走 stub no-op；iOS / Android 在原生层启用，Dart 调用为兼容保留。
library;

export 'app_screen_guard_stub.dart'
    if (dart.library.io) 'app_screen_guard_io.dart';
