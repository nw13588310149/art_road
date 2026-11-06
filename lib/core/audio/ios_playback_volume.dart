import 'package:flutter/foundation.dart';

/// iOS 短音 / 节拍器软件增益：满幅输出，响度完全交由系统音量键。
abstract final class IosPlaybackVolume {
  static bool get isIosNative =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// 非 iOS 保留原 requested；iOS 恒为 1.0。
  static double apply(double requested) => isIosNative ? 1.0 : requested;
}
