import 'package:flutter/material.dart';

import '../../app/router/app_navigator.dart';
import '../../app/router/route_paths.dart';
import '../storage/app_storage.dart';
import '../widgets/app_toast.dart';

/// 业务 `code == 401` 或 HTTP 401：未登录 / 登录失效的全局处理。
///
/// 同一时刻多个接口并发返回 401 时，只提示一次「账号未登录」并只跳转一次登录页。
/// [reset] 会在登录 / 注册 / 换 token 成功后递增会话代次，使仍在飞行中的旧
/// 401 处理在清 token 或跳转前自动作废，避免误清新会话。
class ApiUnauthorizedHandler {
  ApiUnauthorizedHandler._();

  static final ApiUnauthorizedHandler instance = ApiUnauthorizedHandler._();

  static const String defaultMessage = '账号未登录';

  VoidCallback? _onSessionCleared;
  bool _handling = false;

  /// 每次建立新会话时递增；[handle] 捕获启动时的代次，代次变化则中止处理。
  int _sessionGeneration = 0;

  int get sessionGeneration => _sessionGeneration;

  void bindSessionCleared(VoidCallback? callback) {
    _onSessionCleared = callback;
  }

  /// 新会话建立后调用：作废仍在飞行中的 401 处理，并允许后续再次触发。
  void reset() {
    _sessionGeneration++;
    _handling = false;
  }

  Future<void> handle({
    required AppStorage storage,
    String? message,
    required String requestToken,
    required int requestGeneration,
  }) async {
    if (_handling ||
        requestGeneration != _sessionGeneration ||
        requestToken.isEmpty ||
        storage.token != requestToken) {
      return;
    }
    _handling = true;
    bool isStale() => requestGeneration != _sessionGeneration;

    try {
      final cleared = await storage.clearTokenIfCurrent(
        requestToken,
        () => !isStale(),
      );
      if (!cleared || isStale() || storage.token.isNotEmpty) return;
      _onSessionCleared?.call();
      if (isStale()) {
        return;
      }

      final context = rootNavigatorKey.currentContext;
      final toastText = (message == null || message.trim().isEmpty)
          ? defaultMessage
          : message.trim();
      if (context == null || !context.mounted) {
        // 切换账号时根导航会在下一帧重新挂载，登录页由新的应用状态打开。
        _showToastOnLoginPage(toastText, requestGeneration);
        return;
      }

      final routeName = ModalRoute.of(context)?.settings.name;
      final onAuthPage =
          routeName == RoutePaths.login ||
          routeName == RoutePaths.register ||
          routeName == RoutePaths.forget;

      if (!onAuthPage) {
        if (isStale()) {
          return;
        }
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(RoutePaths.login, (route) => false);
        // Toast 必须在跳转后显示：跳转前插入的 Overlay 会随旧路由销毁。
        _showToastOnLoginPage(toastText, requestGeneration);
      }
    } finally {
      // 吞掉同一轮并发 401；登录成功后会 [reset]。
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (!isStale()) _handling = false;
      });
    }
  }

  void _showToastOnLoginPage(String message, int generation) {
    void tryShow([int attempt = 0]) {
      if (_sessionGeneration != generation) return;
      final context = rootNavigatorKey.currentContext;
      if (context == null || !context.mounted) {
        if (attempt < 5) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => tryShow(attempt + 1),
          );
        }
        return;
      }
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null) {
        if (attempt < 5) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => tryShow(attempt + 1),
          );
        }
        return;
      }
      AppToast.show(context, message, type: AppToastType.error);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => tryShow());
  }
}
