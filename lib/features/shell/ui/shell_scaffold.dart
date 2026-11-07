import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/network/app_network_monitor.dart';
import '../../../core/network/network_page_refresh.dart';
import '../../../core/ui/ui.dart';
import '../../help_guide/ui/role_guide_dialog.dart';
import '../../home/state/home_dashboard_controller.dart';
import '../navigation/shell_notice_routes.dart';
import '../state/school_binding_controller.dart';
import '../state/school_binding_state.dart';
import '../state/shell_controller.dart';
import '../state/shell_state.dart';
import 'dashboard_scaffold.dart';
import 'shell_layout.dart';
import 'widgets/school_binding_overlay.dart';
import 'widgets/shell_left_nav.dart';
import 'widgets/shell_top_bar.dart';

class ShellScaffold extends ConsumerStatefulWidget {
  const ShellScaffold({
    required this.currentRoute,
    required this.child,
    super.key,
  });

  final String currentRoute;
  final Widget child;

  @override
  ConsumerState<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends ConsumerState<ShellScaffold> {
  /// 「未开通 / 已过期」自动跳转 personalCenter 仅在每个 ShellScaffold
  /// 实例内触发一次，避免 myInfo 30s 轮询导致重复弹 toast / 重复跳转。
  /// 实际限流由 [build] 中的 post-frame 调度兜底 —— 跳转后老实例会被销
  /// 毁，新实例（personalCenter）路由本身在豁免清单里，不会再次触发。
  bool _vipRedirectScheduled = false;
  bool _offlineDialogOpen = false;
  bool _offlineDialogScheduled = false;
  bool _roleGuideChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncOfflineDialogForCurrentNetwork();
    });
  }

  void _syncOfflineDialogForCurrentNetwork() {
    if (!mounted) {
      return;
    }
    final network = ref.read(appNetworkMonitorProvider);
    if (!network.hasConnection && !network.offlineUseAcknowledged) {
      unawaited(_presentOfflineDialogIfNeeded());
      return;
    }
    if (network.hasConnection) {
      _dismissOfflineDialogIfOpen();
    }
  }

  void _handleNetworkTransition(
    AppNetworkState? previous,
    AppNetworkState next,
  ) {
    if (next.hasConnection) {
      _dismissOfflineDialogIfOpen();
      if (previous?.hasConnection == false) {
        unawaited(refreshAfterNetworkRestore(ref, widget.currentRoute));
      }
      return;
    }

    if (previous?.hasConnection != false &&
        !next.offlineUseAcknowledged &&
        !_offlineDialogOpen &&
        !_offlineDialogScheduled) {
      unawaited(_presentOfflineDialogIfNeeded());
    }
  }

  void _dismissOfflineDialogIfOpen() {
    if (!_offlineDialogOpen) {
      return;
    }
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
    _offlineDialogOpen = false;
    _offlineDialogScheduled = false;
  }

  Future<void> _presentOfflineDialogIfNeeded() async {
    if (!mounted || _offlineDialogOpen || _offlineDialogScheduled) {
      return;
    }
    final network = ref.read(appNetworkMonitorProvider);
    if (network.hasConnection || network.offlineUseAcknowledged) {
      return;
    }

    _offlineDialogScheduled = true;
    _offlineDialogOpen = true;
    final exitApp = await showAppConfirm(
      context: context,
      barrierDismissible: false,
      title: '网络不可用',
      message: '当前设备未连接网络。你可以继续使用已加载的内容，或退出应用。',
      cancelLabel: '无网使用',
      confirmLabel: '退出应用',
    );
    _offlineDialogOpen = false;
    _offlineDialogScheduled = false;

    if (!mounted) {
      return;
    }

    if (ref.read(appNetworkMonitorProvider).hasConnection) {
      return;
    }

    if (exitApp) {
      await SystemNavigator.pop();
      return;
    }

    ref.read(appNetworkMonitorProvider.notifier).acknowledgeOfflineUse();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shellControllerProvider);
    final controller = ref.read(shellControllerProvider.notifier);
    // 观察「绑定学校」遮罩状态：未绑定时 DashboardScaffold 渲染 overlayChild
    // 强制盖在所有内容之上。read notifier 只是为了在 ShellScaffold 挂载
    // 时把 SchoolBindingController 实例化（构造里会自动开启 5s 轮询）。
    final bindingState = ref.watch(schoolBindingControllerProvider);
    ref.read(schoolBindingControllerProvider.notifier);

    // 绑定学校成功后立即刷新 schoolList，更新侧栏 logo。
    ref.listen<SchoolBindingState>(schoolBindingControllerProvider, (
      previous,
      next,
    ) {
      if (next.hasSchool && previous?.hasSchool != true) {
        unawaited(controller.refreshUserAndSchool());
      }
    });

    ref.listen<AppNetworkState>(
      appNetworkMonitorProvider,
      _handleNetworkTransition,
    );

    // 学校绑定遮罩优先：一旦遮罩生效，所有点击都被它兜住，VIP 校验暂停。
    // 等绑定完成、遮罩消失，下一帧 build 会按需触发 VIP 跳转。
    if (!bindingState.shouldShowOverlay) {
      _maybeScheduleVipRedirect(state);
      _maybeShowRoleGuide(state);
    }

    return DashboardScaffold(
      sidebarWidth: state.collapsed
          ? ShellLayoutSpec.collapsedSidebarWidth
          : ShellLayoutSpec.sidebarWidth,
      overlayChild: bindingState.shouldShowOverlay
          ? const SchoolBindingOverlay()
          : null,
      resizeToAvoidBottomInset: true,
      sidebar: RepaintBoundary(
        child: ShellLeftNav(
          state: state,
          currentRoute: widget.currentRoute,
          onToggleCollapse: controller.toggleCollapse,
          onNavigate: (route) => _navigate(context, ref, route),
        ),
      ),
      topBar: ShellTopBar(
        state: state,
        onNavigate: (route) => _navigate(context, ref, route),
        onLogout: controller.logout,
        onMarkAllRead: controller.markAllNoticeRead,
        onLoadProvinces: controller.loadProvinces,
        onUpdateProvince: controller.updateProvince,
        onOpenNotice: (item) => openShellNotice(context, ref, item),
      ),
      child: RepaintBoundary(
        child: ShellPageSurface(
          clipBehavior: Clip.antiAlias,
          child: widget.child,
        ),
      ),
    );
  }

  /// 当用户已加载且 VIP 失效时，把非豁免页面强制踢回个人中心，并 toast
  /// 提示「请先开通会员」。借助 `_vipRedirectScheduled` 一次性标记避免
  /// 一次 build 中重复 schedule；老实例跳转后会被销毁，所以无需手动复位。
  void _maybeScheduleVipRedirect(ShellState state) {
    if (_vipRedirectScheduled) {
      return;
    }
    if (ShellController.isRouteAllowedWithoutVip(widget.currentRoute)) {
      return;
    }
    // user.id 为空说明 myInfo 还没回包，先不要乱判 VIP。
    if (state.user.id.isEmpty) {
      return;
    }
    if (state.user.isVipActive) {
      return;
    }
    _vipRedirectScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      AppToast.show(context, '请先开通会员');
      Navigator.of(context).pushReplacementNamed(RoutePaths.personalCenter);
    });
  }

  /// 身份第一次进入首页时弹出新手引导：等 `/myInfo` 回包拿到真实身份，
  /// 会员失效（将被带去个人中心）或断网提示弹出时不打扰。
  void _maybeShowRoleGuide(ShellState state) {
    if (_roleGuideChecked || widget.currentRoute != RoutePaths.home) {
      return;
    }
    final user = state.user;
    final role = user.role.trim();
    if (!user.isMyInfoReady ||
        role.isEmpty ||
        !user.isVipActive ||
        _offlineDialogOpen) {
      return;
    }
    _roleGuideChecked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      // 首次启动的权限说明等弹窗还开着时先不弹，等外壳下次刷新再判断。
      if (ModalRoute.of(context)?.isCurrent == false) {
        _roleGuideChecked = false;
        return;
      }
      unawaited(RoleGuideLauncher.maybeShow(context, role: role));
    });
  }

  void _navigate(BuildContext context, WidgetRef ref, String route) {
    final navigator = Navigator.of(context);

    // 帮助页是覆盖当前业务页的全局说明页，保留来源路由，返回箭头才能回到
    // 用户进入帮助前的位置；其余主导航仍沿用 replacement 语义。
    if (route == RoutePaths.helpGuide) {
      navigator.pushNamed(route);
      return;
    }

    // 切换主导航前先 pop 掉栈顶 overlay route，避免其叠在 Shell 上。
    if (navigator.canPop()) {
      navigator.popUntil((r) => r.isFirst);
    }

    if (route == widget.currentRoute) {
      // 首页再次点击时刷新数据；其他模块再点同一项不做处理，保留页内 UI 状态。
      if (route == RoutePaths.home &&
          ref.exists(homeDashboardControllerProvider)) {
        unawaited(ref.read(homeDashboardControllerProvider.notifier).refresh());
      }
      return;
    }
    // VIP 拦截：未开通 / 已过期的用户点击非豁免左侧导航或顶部菜单时，只
    // toast 提示而不真正跳转。学校绑定遮罩生效期间走另一条主线（遮罩自
    // 己吞点击），此处不会被触达。
    final shellState = ref.read(shellControllerProvider);
    if (shellState.user.id.isNotEmpty &&
        !shellState.user.isVipActive &&
        !ShellController.isRouteAllowedWithoutVip(route)) {
      AppToast.show(context, '请先开通会员');
      return;
    }
    Navigator.pushReplacementNamed(context, route);
  }
}
