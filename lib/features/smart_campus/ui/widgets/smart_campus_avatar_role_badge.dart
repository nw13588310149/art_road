import 'package:flutter/material.dart';
import 'package:the_road_of_art_flutter/core/theme/app_font.dart';

import '../../../../core/ui/app_image.dart';
import '../../../shell/ui/shell_layout.dart';
import '../../data/smart_campus_role_theme.dart';
import '../../state/smart_campus_state.dart';

/// 原版五身份标签色（R `features/smart_campus/data/smart_campus_role_theme.dart`
/// 9–37 行）：实色浅底 + 深色字；学生端沿用紫系，紫色换成品牌紫。
///
/// 仅用于右栏头像下方的身份徽章与「教师管理」卡片左下的身份标签。
({Color bg, Color fg}) smartCampusRoleBadgeColors(SmartCampusRole role) {
  const fg = Color(0xFF0B081A);
  switch (role) {
    case SmartCampusRole.principal:
      return (bg: const Color(0xFFE2D1FF), fg: fg);
    case SmartCampusRole.admin:
      return (bg: const Color(0xFFCBF5F3), fg: fg);
    case SmartCampusRole.headTeacher:
      return (bg: const Color(0xFFFFE7CC), fg: fg);
    case SmartCampusRole.teacher:
      return (bg: const Color(0xFFFFD9F6), fg: fg);
    case SmartCampusRole.dormManager:
      return (bg: const Color(0xFFD1EA65), fg: fg);
    case SmartCampusRole.student:
      return (bg: const Color(0xFFEAE5FF), fg: const Color(0xFF715EFE));
  }
}

/// 中文身份标签（「班主任」「任课老师」…）→ 原版身份色。
({Color bg, Color fg}) smartCampusRoleBadgeColorsForLabel(String label) =>
    smartCampusRoleBadgeColors(smartCampusRoleFromLabel(label));

/// 各身份共用的右栏名片，外观同原版各端首页的私有名片：
/// R `admin_home_view.dart` 1416–1557（`_ProfileHeader`）、
/// `dorm_manager_home_view.dart` 995–1135、`teacher_dashboard.dart` 1205–1324。
///
/// 72 圆形头像（浅紫底 + 28 号紫色首字）+ 姓名 16/500 + 白底细边「运行中」
/// 状态胶囊（11 号）+ 12 号机构名；身份徽章贴在头像下沿。
class SmartCampusProfileHeader extends StatelessWidget {
  const SmartCampusProfileHeader({
    required this.displayName,
    required this.avatarUrl,
    required this.institutionName,
    required this.role,
    required this.roleLabel,
    this.statusLabel,
    super.key,
  });

  final String displayName;
  final String avatarUrl;
  final String institutionName;
  final SmartCampusRole role;
  final String roleLabel;

  /// 状态胶囊文字；默认按原版：学生「在校」、宿管「在岗」、其余「运行中」。
  final String? statusLabel;

  String get _status {
    final custom = statusLabel;
    if (custom != null) return custom;
    switch (role) {
      case SmartCampusRole.student:
        return '在校';
      case SmartCampusRole.dormManager:
        return '在岗';
      case SmartCampusRole.teacher:
      case SmartCampusRole.headTeacher:
      case SmartCampusRole.admin:
      case SmartCampusRole.principal:
        return '运行中';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final name = displayName.trim().isEmpty ? roleLabel : displayName.trim();
    final institution = institutionName.trim();
    final initial = Center(
      child: Text(
        name.isEmpty ? '·' : name.characters.first,
        style: TextStyle(
          fontSize: ui(28),
          height: 1.0,
          color: const Color(0xFF715EFE),
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w500,
        ),
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: ui(72),
              height: ui(72),
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFEAE5FF),
              ),
              child: avatarUrl.isEmpty
                  ? initial
                  : AppImage(
                      src: avatarUrl,
                      width: ui(72),
                      height: ui(72),
                      placeholder: initial,
                      error: initial,
                    ),
            ),
            SizedBox(width: ui(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: ui(8)),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: ui(16),
                            height: 1.2,
                            fontWeight: AppFont.w500,
                            color: const Color(0xFF0B081A),
                            fontFamily: 'PingFang SC',
                          ),
                        ),
                      ),
                      SizedBox(width: ui(6)),
                      _ProfileStatusChip(label: _status),
                    ],
                  ),
                  if (institution.isNotEmpty) ...[
                    SizedBox(height: ui(4)),
                    Text(
                      institution,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(12),
                        height: 1.2,
                        color: const Color(0xFF6D6B75),
                        fontFamily: 'Source Han Sans SC',
                        fontWeight: AppFont.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        SmartCampusAvatarRoleBadge(label: roleLabel, role: role),
      ],
    );
  }
}

/// 原版名片右侧状态胶囊：白底 0.5 细边、6 绿点、11 号字。
class _ProfileStatusChip extends StatelessWidget {
  const _ProfileStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(6), vertical: ui(3)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(4)),
        border: Border.all(color: const Color(0xFFF3F2F3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ui(6),
            height: ui(6),
            decoration: const BoxDecoration(
              color: Color(0xFF12C58A),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: ui(4)),
          Text(
            label,
            style: TextStyle(
              fontSize: ui(11),
              height: 1.0,
              color: const Color(0xFF0B081A),
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      ),
    );
  }
}

/// 智慧校园各端首页右侧栏：头像下方身份徽章（仅此块使用五身份主题色）。
///
/// 尺寸与位置对齐个人中心 [_IdentityBadge]（82×82 头像：左 48 / 上 65 / 高 18）；
/// 侧栏 72×72 头像对应左 43 / 上 55。配色仍为五身份主题色 + 白描边。
class SmartCampusAvatarRoleBadge extends StatelessWidget {
  const SmartCampusAvatarRoleBadge({
    super.key,
    required this.label,
    required this.role,
    this.avatarSize = 72,
  });

  final String label;
  final SmartCampusRole role;

  /// 侧栏头像直径（设计稿 px）。
  final double avatarSize;

  /// 个人中心设计稿：徽标左缘 = 头像中心 + 7px。
  static const double _badgeLeftFromAvatarCenter = 7;

  /// 个人中心设计稿：徽标顶 = 头像顶 + (头像高 - 17px)，底边略超出头像 1px。
  static const double _badgeTopInsetFromAvatarBottom = 17;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final tag = smartCampusRoleBadgeColors(role);
    return Positioned(
      left: ui(avatarSize / 2 + _badgeLeftFromAvatarCenter),
      top: ui(avatarSize - _badgeTopInsetFromAvatarBottom),
      child: Container(
        height: ui(18),
        padding: EdgeInsets.symmetric(horizontal: ui(7)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tag.bg,
          borderRadius: BorderRadius.circular(ui(10)),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          strutStyle: StrutStyle(
            fontSize: ui(11),
            height: 1.1,
            forceStrutHeight: true,
          ),
          style: TextStyle(
            fontSize: ui(11),
            height: 1.1,
            color: tag.fg,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
          ),
        ),
      ),
    );
  }
}
