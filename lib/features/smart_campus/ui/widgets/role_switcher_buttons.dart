import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:flutter/material.dart';

import '../../state/smart_campus_state.dart';

/// 智慧校园右侧栏「身份切换」按钮组。
///
/// 命中 [selectedRole] 的那颗紫渐变底白字，其它白底深色字 + 1px
/// `#F3F2F3` 边框。视觉与教师 dashboard 原先的「任课老师 / 班主任」
/// tab (`_TeacherRoleTabButton`) 保持一致，确保 admin / 班主任 / 任课老师 等多端右栏的视觉语言统一。
///
/// 每行两个等宽按钮。`label` 走 [SmartCampusRoleX.label]（学生端 / 任课老师 /
/// 班主任 / 宿管 / 管理员），让数据完全由 controller / 后端
/// `/teacher/teacherRole` 决定。
///
/// `onSelectRole` 应该指向 `SmartCampusController.selectRole`：tap 之
/// 后 state 变更 → SmartCampusPage 重 build → 路由到目标身份对应的
/// 大 dashboard（admin → AdminHomeView，teacher/headTeacher →
/// TeacherDashboardLayout，student → StudentDashboardLayout）。
class RoleSwitcherButtons extends StatelessWidget {
  const RoleSwitcherButtons({
    super.key,
    required this.availableRoles,
    required this.selectedRole,
    required this.onSelectRole,
  });

  final List<SmartCampusRole> availableRoles;
  final SmartCampusRole selectedRole;
  final ValueChanged<SmartCampusRole> onSelectRole;

  @override
  Widget build(BuildContext context) {
    if (availableRoles.isEmpty) {
      return const SizedBox.shrink();
    }
    Widget button(SmartCampusRole role) => _RoleSwitcherButton(
      label: role.label,
      active: role == selectedRole,
      onTap: () => onSelectRole(role),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < availableRoles.length; i += 2) ...[
          if (i > 0) const SizedBox(height: AppSpace.s8),
          Row(
            children: [
              Expanded(child: button(availableRoles[i])),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: i + 1 < availableRoles.length
                    ? button(availableRoles[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RoleSwitcherButton extends StatelessWidget {
  const _RoleSwitcherButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      selected: active,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [AppColors.brandSoft, AppColors.brand],
                )
              : null,
          color: active ? null : AppColors.surface,
          borderRadius: AppRadius.br8,
          border: Border.all(color: AppColors.lineSoft),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (active ? AppText.caption12Strong : AppText.caption12)
              .copyWith(color: active ? AppColors.surface : AppColors.ink),
        ),
      ),
    );
  }
}
