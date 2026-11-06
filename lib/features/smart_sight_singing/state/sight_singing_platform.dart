import 'sight_singing_platform_stub.dart'
    if (dart.library.io) 'sight_singing_platform_io.dart';

/// 智能视唱平台能力（伴奏音量由系统实体键控制，不做软件衰减）。
abstract final class SightSingingPlatform {
  static bool get isIosTablet => isIosTabletImpl;

  /// 默认播放伴奏；用户可通过「无声跟唱」开关关闭外放。
  static bool get defaultsToVisualOnlyMode => false;
}
