import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:the_road_of_art_flutter/core/theme/app_font.dart';

import '../../../shell/ui/shell_layout.dart';
import '../../data/smart_campus_role_theme.dart';
import '../../state/smart_campus_state.dart';

/// 各身份共用的右栏名片。身份标贴在头像下沿，名称与在岗状态共用一行。
class SmartCampusProfileHeader extends StatelessWidget {
  const SmartCampusProfileHeader({
    required this.displayName,
    required this.avatarUrl,
    required this.institutionName,
    required this.role,
    required this.roleLabel,
    super.key,
  });

  final String displayName;
  final String avatarUrl;
  final String institutionName;
  final SmartCampusRole role;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    final name = displayName.trim().isEmpty ? roleLabel : displayName.trim();
    final institution = institutionName.trim();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAvatar(name: name, url: avatarUrl, size: 72),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: AppSpace.s8,
                  bottom: AppSpace.s20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.title16,
                          ),
                        ),
                        const SizedBox(width: AppSpace.s8),
                        AppStatusTag(
                          label: role == SmartCampusRole.student ? '在校' : '在岗',
                          tone: AppTone.success,
                        ),
                      ],
                    ),
                    if (institution.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.s4),
                      Text(
                        institution,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption12,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        SmartCampusAvatarRoleBadge(label: roleLabel, role: role),
      ],
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
    final tag = smartCampusRoleTagStyle(role);
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
          border: Border.all(color: AppColors.surface, width: 1),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          strutStyle: StrutStyle(
            fontSize: ui(12),
            height: 1.1,
            forceStrutHeight: true,
          ),
          style: TextStyle(
            fontSize: ui(12),
            height: 1.1,
            color: tag.fg,
            fontWeight: AppFont.w400,
          ),
        ),
      ),
    );
  }
}
