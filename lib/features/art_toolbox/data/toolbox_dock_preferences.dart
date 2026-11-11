import 'package:shared_preferences/shared_preferences.dart';

enum ToolboxDockEdge { left, right, top, bottom }

class ToolboxDockPosition {
  const ToolboxDockPosition({
    this.edge = ToolboxDockEdge.right,
    this.fraction = 0.64,
  });

  final ToolboxDockEdge edge;
  final double fraction;
}

/// 只保存入口位置；画作与练习留在当前会话，不写入偏好存储。
class ToolboxDockPreferences {
  static const edgeKey = 'art_toolbox_dock_edge_v1';
  static const fractionKey = 'art_toolbox_dock_fraction_v1';

  Future<ToolboxDockPosition> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(edgeKey);
    final fraction = prefs.getDouble(fractionKey) ?? 0.64;
    return ToolboxDockPosition(
      edge: ToolboxDockEdge.values.firstWhere(
        (edge) => edge.name == name,
        orElse: () => ToolboxDockEdge.right,
      ),
      fraction: fraction.isFinite ? fraction.clamp(0, 1) : 0.64,
    );
  }

  Future<void> save(ToolboxDockPosition position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(edgeKey, position.edge.name);
    await prefs.setDouble(fractionKey, position.fraction);
  }
}
