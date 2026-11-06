import 'dart:io';

import 'package:flutter/foundation.dart';

bool get isIosTabletImpl {
  if (kIsWeb || !Platform.isIOS) return false;
  final views = PlatformDispatcher.instance.views;
  if (views.isEmpty) return false;
  final view = views.first;
  final logicalShortest =
      view.physicalSize.shortestSide / view.devicePixelRatio;
  // iPhone 最短边 < 600；iPad 全系 >= 600（含 mini）。
  return logicalShortest >= 600;
}
