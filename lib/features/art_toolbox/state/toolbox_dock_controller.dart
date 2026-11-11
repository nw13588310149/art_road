import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/toolbox_dock_preferences.dart';

final toolboxDockControllerProvider =
    StateNotifierProvider<ToolboxDockController, ToolboxDockPosition>(
      (ref) => ToolboxDockController(ToolboxDockPreferences()),
    );

class ToolboxDockController extends StateNotifier<ToolboxDockPosition> {
  ToolboxDockController(this._preferences)
    : super(const ToolboxDockPosition()) {
    unawaited(_restore());
  }

  final ToolboxDockPreferences _preferences;
  bool _moved = false;
  Future<void> _pendingSave = Future<void>.value();

  Future<void> _restore() async {
    try {
      final saved = await _preferences.load();
      if (mounted && !_moved) state = saved;
    } catch (_) {
      // 存储不可用时仍可拖动和使用工具。
    }
  }

  void dock(Offset point, Rect bounds) {
    _moved = true;
    final position = ToolboxDockGeometry.snap(point, bounds);
    state = position;
    // 顺序写入，快速连续拖动也不会被较早的保存覆盖。
    _pendingSave = _pendingSave.then((_) async {
      try {
        await _preferences.save(position);
      } catch (_) {
        // 位置仅影响下次启动，不阻塞当前交互。
      }
    });
  }
}

/// bounds 是入口左上角可移动的范围，调用方已扣除安全区与入口尺寸。
abstract final class ToolboxDockGeometry {
  static Offset clamp(Offset point, Rect bounds) => Offset(
    point.dx.clamp(bounds.left, bounds.right),
    point.dy.clamp(bounds.top, bounds.bottom),
  );

  static Offset resolve(ToolboxDockPosition dock, Rect bounds) {
    final x = bounds.left + bounds.width * dock.fraction;
    final y = bounds.top + bounds.height * dock.fraction;
    return switch (dock.edge) {
      ToolboxDockEdge.left => Offset(bounds.left, y),
      ToolboxDockEdge.right => Offset(bounds.right, y),
      ToolboxDockEdge.top => Offset(x, bounds.top),
      ToolboxDockEdge.bottom => Offset(x, bounds.bottom),
    };
  }

  static ToolboxDockPosition snap(Offset point, Rect bounds) {
    final p = clamp(point, bounds);
    final distances = <ToolboxDockEdge, double>{
      ToolboxDockEdge.left: p.dx - bounds.left,
      ToolboxDockEdge.right: bounds.right - p.dx,
      ToolboxDockEdge.top: p.dy - bounds.top,
      ToolboxDockEdge.bottom: bounds.bottom - p.dy,
    };
    final edge = distances.entries
        .reduce((a, b) => a.value <= b.value ? a : b)
        .key;
    final vertical =
        edge == ToolboxDockEdge.left || edge == ToolboxDockEdge.right;
    final length = vertical ? bounds.height : bounds.width;
    final distance = vertical ? p.dy - bounds.top : p.dx - bounds.left;
    return ToolboxDockPosition(
      edge: edge,
      fraction: length <= 0 ? 0 : (distance / length).clamp(0, 1),
    );
  }
}
