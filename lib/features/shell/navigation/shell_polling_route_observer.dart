import 'package:flutter/material.dart';

import '../../../app/router/route_paths.dart';

typedef ShellPollingSync = void Function(bool isAuthRoute);

/// 根据当前路由暂停 / 恢复 Shell 层的 myInfo / schoolList / 未读消息轮询。
///
/// 登出或 401 会清 token 并主动 pausePolling；本观察器
/// 作为兜底，确保用户停留在登录 / 注册 / 找回密码页时不会继续打接口。
///
/// 轮询控制通过 [onSyncPolling] 注入，避免本库在初始化时拉入 Shell 重依赖链。
class ShellPollingRouteObserver extends NavigatorObserver {
  ShellPollingRouteObserver({required ShellPollingSync onSyncPolling})
    : _onSyncPolling = onSyncPolling;

  final ShellPollingSync _onSyncPolling;

  static bool isAuthRoute(String routeName) {
    return routeName == RoutePaths.login ||
        routeName == RoutePaths.register ||
        routeName == RoutePaths.forget;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _syncPollingForRoute(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      _syncPollingForRoute(newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      _syncPollingForRoute(previousRoute);
    }
  }

  void _syncPollingForRoute(Route<dynamic> route) {
    final routeName = route.settings.name;
    if (routeName == null) {
      return;
    }
    _onSyncPolling(isAuthRoute(routeName));
  }
}
