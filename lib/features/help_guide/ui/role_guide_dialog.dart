import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ui/ui.dart';
import '../../../core/widgets/app_asset_graphic.dart';
import '../data/role_guide_store.dart';
import '../data/role_guides.dart';

/// 打开 [role] 的新手引导（帮助页「新手引导」、身份第一次进入首页时）。
///
/// 只有弹窗本身淡入，换步立即切换；「跳过」在除最后一步外的每一步都可见。
Future<void> showRoleGuide(BuildContext context, {required String role}) {
  return showAppDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => RoleGuideDialog(guide: roleGuideFor(role)),
  );
}

/// 身份第一次进入首页时显示一次新手引导；弹出即记为已看过，刷新页面不会再弹。
abstract final class RoleGuideLauncher {
  static final Set<String> _checked = <String>{};

  /// 返回是否弹出了引导。
  static Future<bool> maybeShow(
    BuildContext context, {
    required String role,
    RoleGuideStore store = const RoleGuideStore(),
  }) async {
    final key = role.trim();
    if (key.isEmpty || !_checked.add(key)) {
      return false;
    }
    if (await store.hasSeen(key)) {
      return false;
    }
    await store.markSeen(key);
    if (!context.mounted) {
      return false;
    }
    unawaited(showRoleGuide(context, role: key));
    return true;
  }

  /// 清除本次运行里「已检查过」的记录（帮助页恢复引导后，下次进入首页重新判断）。
  static void forgetSession() => _checked.clear();
}

class RoleGuideDialog extends StatefulWidget {
  const RoleGuideDialog({required this.guide, super.key});

  final RoleGuide guide;

  @override
  State<RoleGuideDialog> createState() => _RoleGuideDialogState();
}

class _RoleGuideDialogState extends State<RoleGuideDialog> {
  int _index = 0;

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final guide = widget.guide;
    final steps = guide.steps;
    final step = steps[_index];
    final last = _index == steps.length - 1;
    return AppDialog(
      title: step.title,
      message: step.body,
      showClose: false,
      actions: [
        if (!last)
          AppButton(
            label: '跳过',
            variant: AppButtonVariant.secondary,
            onTap: _close,
          ),
        AppButton(
          label: last ? '开始使用' : '下一步',
          onTap: last ? _close : () => setState(() => _index++),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppCard(
            color: AppColors.surfaceSubtle,
            bordered: false,
            padding: const EdgeInsets.all(AppSpace.s12),
            child: Row(
              children: [
                AppAssetGraphic(step.iconAsset, width: 32, height: 32),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('在哪里找', style: AppText.caption12),
                      Text(step.where, style: AppText.body14Strong),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s16),
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Container(
                  width: i == _index ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _index ? AppColors.brand : AppColors.line,
                    borderRadius: AppRadius.brPill,
                  ),
                ),
              ],
              const Spacer(),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${guide.roleLabel}新手引导  ',
                        style: AppText.caption12,
                      ),
                      TextSpan(
                        text: '${_index + 1} / ${steps.length}',
                        style: AppText.number(
                          size: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
