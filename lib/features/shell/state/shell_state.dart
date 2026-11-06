import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/storage/app_storage.dart';

class ShellNavItem {
  const ShellNavItem({
    required this.label,
    required this.route,
    required this.icon,
    required this.activeIcon,
    this.badge = 0,
    this.badgeColor = 0xFFE61F62,
    /// 导航 icon 边长（设计稿逻辑 px）；未指定时默认 24。
    this.iconSize,
  });

  final String label;
  final String route;
  final String icon;
  final String activeIcon;
  final int badge;
  final int badgeColor;
  final double? iconSize;

  ShellNavItem copyWith({int? badge}) {
    return ShellNavItem(
      label: label,
      route: route,
      icon: icon,
      activeIcon: activeIcon,
      badge: badge ?? this.badge,
      badgeColor: badgeColor,
      iconSize: iconSize,
    );
  }
}

class ShellNoticeItem {
  const ShellNoticeItem({
    required this.id,
    required this.targetType,
    required this.content,
    required this.createTime,
  });

  final int id;
  final int targetType;
  final String content;
  final String createTime;
}

class ShellUser {
  const ShellUser({
    this.id = '',
    this.nickname = '',
    this.realname = '',
    this.avatarUrl = '',
    this.province = '',
    this.role = '',
    this.identity = '',
    this.gender = '',
    this.primary = '',
    this.secondary = '',
    this.school = '',
    this.targetSchool = '',
    this.vipExpireDate,
  });

  /// 后端 `myInfo.user.id`（雪花长整型）。**必须以字符串形式承载**，
  /// web 端经 JS number(53bit) 转换会丢精度。空串表示未登录或未知。
  ///
  /// 用于 `/chat/sendMsg` 等接口的「我是谁」对照（`fromUserId == id`）以
  /// 渲染消息气泡左右位置。
  final String id;
  final String nickname;
  final String realname;
  final String avatarUrl;
  final String province;

  /// `myInfo` 接口的 `user.role` 原文，例如 `student` / `teacher` /
  /// `headTeacher` / `dormManager` / `admin` 等，用于上层做身份分发。
  final String role;

  /// `myInfo` 接口的 `user.identity` 原文（中文身份），如「学生 / 老师 /
  /// 班主任 / 宿管 / 管理员」，作为 `role` 字段的兜底。
  final String identity;

  /// `myInfo.user.gender`，如「男 / 女」。
  final String gender;

  /// `myInfo.user.primary` 专业主项。
  final String primary;

  /// `myInfo.user.secondary` 专业副项。
  final String secondary;

  /// `myInfo.user.school` 就读学校。
  final String school;

  /// `myInfo.user.targetSchool` 目标院校。
  final String targetSchool;

  /// `myInfo.user.vipExpireDate` 解析后的到期时间，单位为本地时间。
  ///
  /// 为 `null` 表示从未开通会员；非空但已早于 `DateTime.now()` 表示
  /// 会员已过期。两种状态都按「未开通 / 已失效」处理，由 [isVipActive]
  /// 统一对外暴露布尔结果。
  final DateTime? vipExpireDate;

  /// 是否有有效会员（VIP）。`true` 仅当 [vipExpireDate] 非空且晚于现
  /// 在；`null` 或过期都返回 `false`。
  bool get isVipActive {
    final expire = vipExpireDate;
    if (expire == null) {
      return false;
    }
    return expire.isAfter(DateTime.now());
  }

  String get displayName {
    if (nickname.isNotEmpty) {
      return nickname;
    }
    if (realname.isNotEmpty) {
      return realname;
    }
    return '\u7528\u6237';
  }

  /// `/myInfo` 已成功回包：`user.id` 非空。Shell 与各业务页在 id 就绪前
  /// 不应按默认「学生端」发起 `/student/*` 等身份相关请求。
  bool get isMyInfoReady => id.trim().isNotEmpty;

  ShellUser copyWith({
    String? id,
    String? nickname,
    String? realname,
    String? avatarUrl,
    String? province,
    String? role,
    String? identity,
    String? gender,
    String? primary,
    String? secondary,
    String? school,
    String? targetSchool,
    DateTime? vipExpireDate,
  }) {
    return ShellUser(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      realname: realname ?? this.realname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      province: province ?? this.province,
      role: role ?? this.role,
      identity: identity ?? this.identity,
      gender: gender ?? this.gender,
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      school: school ?? this.school,
      targetSchool: targetSchool ?? this.targetSchool,
      vipExpireDate: vipExpireDate ?? this.vipExpireDate,
    );
  }
}

class ShellState {
  const ShellState({
    required this.navItems,
    this.footerNavItem,
    this.collapsed = false,
    this.showFloatingMenu = false,
    this.logoUrl = '',
    this.schoolName = '',
    this.user = const ShellUser(),
    this.unreadCount = 0,
    this.noticeItems = const [],
    this.schoolCoursewareEnabled = false,
    this.isSchoolReady = false,
  });

  final List<ShellNavItem> navItems;

  /// 吸附在侧栏底部的独立入口（意见反馈），不参与常规 tab 列表滚动混排。
  final ShellNavItem? footerNavItem;
  final bool collapsed;
  final bool showFloatingMenu;
  final String logoUrl;

  /// `/schoolList` 首条记录的 `name`，即当前绑定机构名称。
  final String schoolName;
  final ShellUser user;
  final int unreadCount;
  final List<ShellNoticeItem> noticeItems;
  final bool schoolCoursewareEnabled;

  /// `/myInfo` 并行拉取的 `schoolList` 已成功写入本地 `schoolId`。
  /// 智慧校园等业务在 `false` 时不应发起带 `schoolId` 头的请求。
  final bool isSchoolReady;

  bool get isAuthenticated => true;

  ShellState copyWith({
    List<ShellNavItem>? navItems,
    ShellNavItem? footerNavItem,
    bool? collapsed,
    bool? showFloatingMenu,
    String? logoUrl,
    String? schoolName,
    ShellUser? user,
    int? unreadCount,
    List<ShellNoticeItem>? noticeItems,
    bool? schoolCoursewareEnabled,
    bool? isSchoolReady,
  }) {
    return ShellState(
      navItems: navItems ?? this.navItems,
      footerNavItem: footerNavItem ?? this.footerNavItem,
      collapsed: collapsed ?? this.collapsed,
      showFloatingMenu: showFloatingMenu ?? this.showFloatingMenu,
      logoUrl: logoUrl ?? this.logoUrl,
      schoolName: schoolName ?? this.schoolName,
      user: user ?? this.user,
      unreadCount: unreadCount ?? this.unreadCount,
      noticeItems: noticeItems ?? this.noticeItems,
      schoolCoursewareEnabled:
          schoolCoursewareEnabled ?? this.schoolCoursewareEnabled,
      isSchoolReady: isSchoolReady ?? this.isSchoolReady,
    );
  }
}

List<ShellNavItem> buildDefaultNavItems({
  required bool schoolCoursewareEnabled,
}) {
  const base = <ShellNavItem>[
    ShellNavItem(
      label: '\u9996\u9875',
      route: RoutePaths.home,
      icon: AppAssets.leftNavHome,
      activeIcon: AppAssets.leftNavHome,
    ),
    ShellNavItem(
      label: '\u5c0f\u827a\u540c\u5b66',
      route: RoutePaths.personalAi,
      icon: AppAssets.leftNavAi,
      activeIcon: AppAssets.leftNavAi,
    ),
  ];

  final school = ShellNavItem(
    label: '\u6821\u56ed\u8bfe\u4ef6',
    route: RoutePaths.school,
    icon: AppAssets.leftNavSchool,
    activeIcon: AppAssets.leftNavSchool,
  );

  final tail = <ShellNavItem>[
    const ShellNavItem(
      label: '\u6211\u7684\u4e91\u76d8',
      route: RoutePaths.courseware,
      icon: AppAssets.leftNavYunpan,
      activeIcon: AppAssets.leftNavYunpan,
    ),
    const ShellNavItem(
      label: '\u89c6\u9891\u4e2d\u5fc3',
      route: RoutePaths.videoTutorial,
      icon: AppAssets.leftNavVideo,
      activeIcon: AppAssets.leftNavVideo,
    ),
    const ShellNavItem(
      label: '\u667a\u80fd\u542c\u5199',
      route: RoutePaths.smartDictation,
      icon: AppAssets.leftNavTingxie,
      activeIcon: AppAssets.leftNavTingxie,
    ),
    const ShellNavItem(
      label: '\u667a\u80fd\u89c6\u5531',
      route: RoutePaths.smartSinging,
      icon: AppAssets.leftNavSing,
      activeIcon: AppAssets.leftNavSing,
    ),
    const ShellNavItem(
      label: '\u97f3\u4e50\u4f34\u4fa3',
      route: RoutePaths.music,
      icon: AppAssets.leftNavBanlv,
      activeIcon: AppAssets.leftNavBanlv,
    ),
    const ShellNavItem(
      label: '\u667a\u6167\u6821\u56ed',
      route: RoutePaths.smartCampus,
      icon: AppAssets.leftNavXiaoyuan,
      activeIcon: AppAssets.leftNavXiaoyuan,
    ),
    const ShellNavItem(
      label: '\u6211\u7684\u7b14\u8bb0',
      route: RoutePaths.myNotes,
      icon: AppAssets.leftNavBiji,
      activeIcon: AppAssets.leftNavBiji,
    ),
    const ShellNavItem(
      label: '\u5f55\u97f3\u7cfb\u7edf',
      route: RoutePaths.recording,
      icon: AppAssets.leftNavLuyin,
      activeIcon: AppAssets.leftNavLuyin,
    ),
    const ShellNavItem(
      label: '\u6211\u7684\u6536\u85cf',
      route: RoutePaths.myCollection,
      icon: AppAssets.leftNavShoucang,
      activeIcon: AppAssets.leftNavShoucang,
    ),
    const ShellNavItem(
      label: '\u4e2a\u4eba\u4e2d\u5fc3',
      route: RoutePaths.personalCenter,
      icon: AppAssets.leftNavInfo,
      activeIcon: AppAssets.leftNavInfo,
    ),
  ];

  return [...base, if (schoolCoursewareEnabled) school, ...tail];
}

/// 侧栏底部固定的「需求反馈」入口（弱样式，见 ShellLeftNav._FooterFeedbackLink）。
ShellNavItem buildFeedbackFooterNavItem() {
  return const ShellNavItem(
    label: '意见反馈',
    route: RoutePaths.helpFeedback,
    icon: AppAssets.homeFeedbackIcon,
    activeIcon: AppAssets.homeFeedbackIcon,
  );
}

ShellState createInitialShellState(AppStorage storage) {
  final cachedAvatar = storage.avatarUrl;
  final cachedNickname = storage.nickname;
  return ShellState(
    navItems: buildDefaultNavItems(schoolCoursewareEnabled: false),
    footerNavItem: buildFeedbackFooterNavItem(),
    user: (cachedAvatar.isNotEmpty || cachedNickname.isNotEmpty)
        ? ShellUser(avatarUrl: cachedAvatar, nickname: cachedNickname)
        : const ShellUser(),
  );
}
