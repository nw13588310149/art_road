import 'dart:async';

import 'package:flutter/foundation.dart';

/// iOS 全应用共用的原生钢琴 MethodChannel 操作串行合并。
///
/// 避免视唱离开、音乐伴侣进入、听写 reclaim 等在原生队列里叠两次，
/// 导致迟播或无声。
///
/// 关键安全约束：
/// 1. 串行**执行**每一次 handoff（不能「等前一个完就 return」丢掉自己的 action）。
/// 2. 单次 action 有 [_kTimeout] 上限，避免 MethodChannel 卡死占满队列。
abstract final class NativePianoHandoff {
  static Future<void>? _chain;

  static const Duration _kTimeout = Duration(seconds: 15);

  static Future<void> run(Future<void> Function() action) async {
    if (kIsWeb) {
      await action();
      return;
    }
    final previous = _chain;
    final task = previous != null
        ? previous
            .then((_) => _guarded(action))
            .catchError((_) => _guarded(action))
        : _guarded(action);
    _chain = task.whenComplete(() {
      if (identical(_chain, task)) {
        _chain = null;
      }
    });
    await task;
  }

  static Future<void> _guarded(Future<void> Function() action) async {
    try {
      await action().timeout(_kTimeout);
    } catch (error, stack) {
      debugPrint('NativePianoHandoff action failed/timed out: $error\n$stack');
    }
  }
}
