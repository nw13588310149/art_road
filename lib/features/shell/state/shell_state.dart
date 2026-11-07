import 'package:flutter/material.dart' show IconData;

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/storage/app_storage.dart';

/// 侧栏导航项。图标用单色线性图片（[icon]，按选中态统一着色）或 [iconData]。
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
    this.iconData,
  });

  final String label;
  final String route;
  final String icon;
  final String activeIcon;
  final int badge;

  /// 旧字段：角标统一用 AppBadge（红色），不再读取。
  final int badgeColor;
  final double? iconSize;

  /// 设置后优先于 [icon] 图片。
  final IconData? iconData;

  ShellNavItem copyWith({int? badge}) {
    return ShellNavItem(
      label: label,
      route: route,
      icon: icon,
      activeIcon: activeIcon,
      badge: badge ?? this.badge,
      badgeColor: badgeColor,
      iconSize: iconSize,
      iconData: iconData,
    );
  }
}

/// 顶栏铃铛里的一条消息。[targetType] + [targetId] 决定点开后去哪一页，
/// 映射见 `navigation/shell_notice_routes.dart`。
class ShellNoticeItem {
  const ShellNoticeItem({
    required this.id,
    required this.targetType,
    required this.content,
    required this.createTime,
    this.targetId = '',
    this.read = false,
  });

  final int id;
  final int targetType;
  final String content;
  final String createTime;

  /// 目标对象 id（考试 / 作品 / 书刊 id、工具 key）；为空时只打开对应模块。
  final String targetId;
  final bool read;

  ShellNoticeItem copyWith({bool? read}) {
    return ShellNoticeItem(
      id: id,
      targetType: targetType,
      content: content,
      createTime: createTime,
      targetId: targetId,
      read: read ?? this.read,
    );
  }
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

  /// `myInfo.user.primary` 专业方向。
  final String primary;

  /// `myInfo.user.secondary` 擅长科目。
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

/// 后端 `myInfo.user.role` 是否为教职角色（任课老师 / 班主任 / 宿管 / 管理员）。
/// 学情中心与作品档案对教职角色展示「班级学情」「作品点评」视角。
bool isStaffRole(String role) {
  final value = role.trim();
  return value.isNotEmpty && value != 'student';
}

/// 侧栏导航项（按显示顺序）。[role] 为 dormManager（宿管）时不显示「班级学情」
/// 「作品点评」：宿管不查看学生成绩与作品。条目数不固定，新增导航项直接插入列表。
List<ShellNavItem> buildDefaultNavItems({
  required bool schoolCoursewareEnabled,
  bool isStaff = false,
  String role = '',
}) {
  final academic = role.trim() != 'dormManager';
  final base = <ShellNavItem>[
    const ShellNavItem(
      label: '首页',
      route: RoutePaths.home,
      icon: AppAssets.leftNavHome,
      activeIcon: AppAssets.leftNavHome,
    ),
    const ShellNavItem(
      label: '小美同学',
      route: RoutePaths.personalAi,
      icon: AppAssets.leftNavAi,
      activeIcon: AppAssets.leftNavAi,
    ),
    if (academic) ...[
      ShellNavItem(
        label: isStaff ? '班级学情' : '我的学情',
        route: RoutePaths.studyCenter,
        icon: AppAssets.leftNavXueqing,
        activeIcon: AppAssets.leftNavXueqing,
      ),
      ShellNavItem(
        label: isStaff ? '作品点评' : '作品档案',
        route: RoutePaths.artworks,
        icon: AppAssets.leftNavZuopin,
        activeIcon: AppAssets.leftNavZuopin,
      ),
    ],
    const ShellNavItem(
      label: '范画库',
      route: RoutePaths.gallery,
      icon: AppAssets.leftNavFanhua,
      activeIcon: AppAssets.leftNavFanhua,
    ),
    const ShellNavItem(
      label: '美术书刊',
      route: RoutePaths.ebooks,
      icon: AppAssets.leftNavShukan,
      activeIcon: AppAssets.leftNavShukan,
    ),
    const ShellNavItem(
      label: '画室工具箱',
      route: RoutePaths.artToolbox,
      icon: AppAssets.leftNavGongju,
      activeIcon: AppAssets.leftNavGongju,
    ),
  ];

  const school = ShellNavItem(
    label: '校园课件',
    route: RoutePaths.school,
    icon: AppAssets.leftNavSchool,
    activeIcon: AppAssets.leftNavSchool,
  );

  const tail = <ShellNavItem>[
    ShellNavItem(
      label: '我的云盘',
      route: RoutePaths.courseware,
      icon: AppAssets.leftNavYunpan,
      activeIcon: AppAssets.leftNavYunpan,
    ),
    ShellNavItem(
      label: '视频中心',
      route: RoutePaths.videoTutorial,
      icon: AppAssets.leftNavVideo,
      activeIcon: AppAssets.leftNavVideo,
    ),
    ShellNavItem(
      label: '智慧校园',
      route: RoutePaths.smartCampus,
      icon: AppAssets.leftNavXiaoyuan,
      activeIcon: AppAssets.leftNavXiaoyuan,
    ),
    ShellNavItem(
      label: '我的笔记',
      route: RoutePaths.myNotes,
      icon: AppAssets.leftNavBiji,
      activeIcon: AppAssets.leftNavBiji,
    ),
    ShellNavItem(
      label: '我的收藏',
      route: RoutePaths.myCollection,
      icon: AppAssets.leftNavShoucang,
      activeIcon: AppAssets.leftNavShoucang,
    ),
    ShellNavItem(
      label: '个人中心',
      route: RoutePaths.personalCenter,
      icon: AppAssets.leftNavInfo,
      activeIcon: AppAssets.leftNavInfo,
    ),
  ];

  return [...base, if (schoolCoursewareEnabled) school, ...tail];
}

/// 侧栏底部固定的「意见反馈」入口（弱样式，见 ShellLeftNav._FooterFeedbackLink）。
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
