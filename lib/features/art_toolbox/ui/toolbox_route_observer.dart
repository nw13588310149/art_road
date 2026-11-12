import 'package:flutter/material.dart';

import '../../../app/router/route_paths.dart';

/// 根路由观察器：工具可跨业务页调用，登录流程与模态确认时让出入口。
class ToolboxRouteObserver extends NavigatorObserver {
  final changes = ValueNotifier<int>(0);
  final _routes = <Route<dynamic>>[];
  bool _disposed = false;

  ModalRoute<dynamic>? get page {
    for (final route in _routes.reversed) {
      if (route is PageRoute) return route;
    }
    return null;
  }

  bool get inSession {
    return page != null &&
        !_routes.any(
          (route) =>
              route.settings.name == RoutePaths.login ||
              route.settings.name == RoutePaths.register ||
              route.settings.name == RoutePaths.forget,
        );
  }

  bool get unobstructed => _routes.isNotEmpty && _routes.last is PageRoute;

  void _changed() {
    // Navigator 更新可能发生于 build；下一帧再更新入口。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) changes.value++;
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    } else if (newRoute != null) {
      _routes.add(newRoute);
    }
    _changed();
  }

  void dispose() {
    _disposed = true;
    changes.dispose();
  }
}
