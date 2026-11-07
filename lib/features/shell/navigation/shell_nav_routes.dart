import '../../../app/router/route_paths.dart';

/// 不是侧栏导航项的页面归属哪个导航项。
///
/// 值为 null 表示不高亮任何导航项（帮助、资讯、题库这类从首页或顶栏进入的全局页），
/// 这些页面由页头的返回按钮回到来源页。表外的路由按自身路径匹配导航项。
const Map<String, String?> _ownerRoutes = {
  RoutePaths.info: RoutePaths.personalCenter,
  RoutePaths.qrcode: RoutePaths.personalCenter,
  RoutePaths.set: RoutePaths.personalCenter,
  RoutePaths.email: RoutePaths.personalCenter,
  RoutePaths.verifie: RoutePaths.personalCenter,
  RoutePaths.xieyi: RoutePaths.personalCenter,
  // 校圈只有一个归属：首页快捷入口与智慧校园入口打开时都高亮「智慧校园」。
  RoutePaths.circle: RoutePaths.smartCampus,
  RoutePaths.chat: RoutePaths.smartCampus,
  RoutePaths.noteDetail: RoutePaths.myNotes,
  RoutePaths.noteBg: RoutePaths.myNotes,
  RoutePaths.schoolWebsite: RoutePaths.school,
  RoutePaths.schoolCamp: RoutePaths.school,
  RoutePaths.schoolVideo: RoutePaths.school,
  RoutePaths.detail: RoutePaths.school,
  RoutePaths.detail2: RoutePaths.school,
  RoutePaths.fankui: RoutePaths.helpFeedback,
  RoutePaths.helpGuide: null,
  RoutePaths.consultation: null,
  RoutePaths.consultationDetail: null,
  RoutePaths.camp: null,
  RoutePaths.campAnswer: null,
  RoutePaths.campOver: null,
  RoutePaths.mock: null,
  RoutePaths.designSystem: null,
};

String _pathOf(String route) {
  final query = route.indexOf('?');
  return query < 0 ? route : route.substring(0, query);
}

/// [route] 归属的导航路由；null 表示不归属任何导航项。
String? shellNavOwnerOf(String route) {
  final path = _pathOf(route);
  if (_ownerRoutes.containsKey(path)) {
    return _ownerRoutes[path];
  }
  return path;
}

/// 当前路由在 [navRoutes]（侧栏导航项路由，按显示顺序）中对应的序号，没有时为 -1。
///
/// 每个路由最多对应一个导航项：先按归属精确匹配，再按路径前缀匹配子路由
/// （如 `/smart-campus/sign-records` → 智慧校园）。首页只精确匹配。
int shellActiveNavIndex(List<String> navRoutes, String route) {
  final owner = shellNavOwnerOf(route);
  if (owner == null) {
    return -1;
  }
  final exact = navRoutes.indexOf(owner);
  if (exact >= 0) {
    return exact;
  }
  for (var i = 0; i < navRoutes.length; i++) {
    final nav = navRoutes[i];
    if (nav != RoutePaths.home && owner.startsWith('$nav/')) {
      return i;
    }
  }
  return -1;
}
