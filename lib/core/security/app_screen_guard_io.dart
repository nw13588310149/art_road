import 'package:flutter/foundation.dart';

/// 移动端截屏 / 录屏防护由原生层负责，Dart 侧保持 no-op：
/// - iOS：ScreenProtectorKit（仅拦截截屏与录屏，切后台不盖黑屏）
/// - Android：`MainActivity` 设置 `FLAG_SECURE`
Future<void> enableAppScreenGuard() async {
  if (kDebugMode) {
    debugPrint('enableAppScreenGuard: handled natively on iOS/Android');
  }
}
