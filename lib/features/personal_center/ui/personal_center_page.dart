import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/app_asset_graphic.dart';
import '../../shell/state/shell_controller.dart';
import '../state/personal_center_controller.dart';
import '../state/personal_center_state.dart';
import '../state/profile_format.dart';
import 'widgets/my_qr_code_card.dart';

/// 美术之路尚未上架，推广二维码暂指向艺考网官网；上架后替换为 App Store 地址。
const _kAppPromoUrl = 'https://yyzl0931.com/';

/// 客服邮箱占位，上线前替换为美术之路官方客服邮箱。
const _kSupportEmail = 'service@yyzl0931.com';

const _kPriceNote = '开通方式与价格以正式页面为准；已有兑换码可在「兑换中心」兑换。';

class PersonalCenterPage extends ConsumerWidget {
  const PersonalCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(personalCenterControllerProvider);
    final controller = ref.read(personalCenterControllerProvider.notifier);
    final Widget body;
    if (state.loading && state.user.isEmpty) {
      body = const _PersonalCenterSkeleton();
    } else if ((state.errorMessage ?? '').isNotEmpty && state.user.isEmpty) {
      body = AppErrorState(
        title: '个人资料加载失败',
        description: state.errorMessage,
        onRetry: controller.refresh,
      );
    } else {
      body = _PersonalCenterBody(
        state: state,
        controller: controller,
        actions: _PersonalCenterActions(context, ref, state, controller),
      );
    }

    return body;
  }
}

/// 页面上所有入口的处理函数，集中在一处便于两栏 / 单栏布局共用。
class _PersonalCenterActions {
  _PersonalCenterActions(this.context, this.ref, this.state, this.controller);

  final BuildContext context;
  final WidgetRef ref;
  final PersonalCenterState state;
  final PersonalCenterController controller;

  void editProfile() => Navigator.pushNamed(context, RoutePaths.info);

  Future<void> showMyQr() async {
    final result = await controller.fetchQrImageUrl();
    if (!context.mounted) {
      return;
    }
    final url = result.url;
    if (result.error != null || url == null) {
      AppToast.showError(context, result.error ?? '二维码加载失败');
      return;
    }
    await showAppDialog<void>(
      context: context,
      builder: (_) => _MyQrCodeDialog(
        nickname: state.user['nickname']?.toString().trim() ?? '',
        mobile: state.user['mobile']?.toString() ?? '',
        avatarUrl: state.user['headUrl']?.toString() ?? '',
        imageUrl: url,
      ),
    );
  }

  void recommend() {
    showAppDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: '推荐给好友',
        message: '把美术之路推荐给同学和朋友，一起在这里学画。',
        actions: [
          AppButton(
            label: '关闭',
            variant: AppButtonVariant.secondary,
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
          AppButton(
            label: '复制链接',
            onTap: () async {
              await Clipboard.setData(const ClipboardData(text: _kAppPromoUrl));
              if (!dialogContext.mounted) {
                return;
              }
              Navigator.of(dialogContext).pop();
              AppToast.showSuccess(context, '链接已复制');
            },
          ),
        ],
        child: const _CopyField(label: '推广链接', value: _kAppPromoUrl),
      ),
    );
  }

  void feedback() {
    Navigator.pushReplacementNamed(context, RoutePaths.helpFeedback);
  }

  void contactService() {
    showAppDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: '联系客服',
        message: '发送邮件联系我们，请写明登录手机号和遇到的问题。',
        actions: [
          AppButton(
            label: '关闭',
            variant: AppButtonVariant.secondary,
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
          AppButton(
            label: '复制邮箱',
            onTap: () async {
              await Clipboard.setData(
                const ClipboardData(text: _kSupportEmail),
              );
              if (!dialogContext.mounted) {
                return;
              }
              Navigator.of(dialogContext).pop();
              AppToast.showSuccess(context, '已复制客服邮箱');
            },
          ),
        ],
        child: const _CopyField(label: '客服邮箱', value: _kSupportEmail),
      ),
    );
  }

  void openGuide() => Navigator.pushNamed(context, RoutePaths.helpGuide);

  void openTerms() => Navigator.pushNamed(context, RoutePaths.xieyi);

  Future<void> redeem() async {
    final code = await showAppDialog<String>(
      context: context,
      builder: (_) => const _RedeemVipDialog(),
    );
    if (!context.mounted || code == null || code.isEmpty) {
      return;
    }
    final msg = await controller.redeemVip(code);
    if (!context.mounted) {
      return;
    }
    if (msg != null) {
      AppToast.showError(context, msg);
      return;
    }
    await ref.read(shellControllerProvider.notifier).refreshUserAndSchool();
    if (!context.mounted) {
      return;
    }
    AppToast.showSuccess(context, '兑换成功，会员有效期已更新');
  }

  void openPlan(VipPackageRow plan) {
    showAppDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: '开通「${plan.name}」',
        message: _kPriceNote,
        actions: [
          AppButton(
            label: '关闭',
            variant: AppButtonVariant.secondary,
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
          AppButton(
            label: '去兑换',
            onTap: () {
              Navigator.of(dialogContext).pop();
              redeem();
            },
          ),
        ],
      ),
    );
  }
}

class _PersonalCenterBody extends StatelessWidget {
  const _PersonalCenterBody({
    required this.state,
    required this.controller,
    required this.actions,
  });

  final PersonalCenterState state;
  final PersonalCenterController controller;
  final _PersonalCenterActions actions;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpace.s16),
      children: [
        _ProfileCard(state: state, onEdit: actions.editProfile),
        if (state.checkStatusEnabled) ...[
          const SizedBox(height: AppSpace.s12),
          _MembershipCard(
            state: state,
            daysRemaining: controller.vipDaysRemaining(),
            onOpenPlan: actions.openPlan,
          ),
        ],
        const SizedBox(height: AppSpace.s16),
        _ServiceCard(
          checkStatusEnabled: state.checkStatusEnabled,
          actions: actions,
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.state, required this.onEdit});

  final PersonalCenterState state;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final user = state.user;
    final nick = user['nickname']?.toString().trim() ?? '';
    final name = nick.isEmpty ? '未命名' : nick;
    final role = identityLabelOf(user['role']);
    final meta = <String>[
      maskMobile(user['mobile']?.toString() ?? ''),
      user['school']?.toString().trim() ?? '',
      user['campus']?.toString().trim() ?? '',
    ].where((e) => e.isNotEmpty).join(' · ');
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: AppRadius.br16,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandTint, AppColors.brandWash],
        ),
      ),
      child: AppCard(
        color: Colors.transparent,
        bordered: false,
        padding: const EdgeInsets.all(AppSpace.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AppAvatar(
                  name: name,
                  url: user['headUrl']?.toString() ?? '',
                  size: 64,
                ),
                const SizedBox(width: AppSpace.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: AppSpace.s8,
                        runSpacing: AppSpace.s4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(name, style: AppText.title20),
                          if (role != null)
                            AppTag(label: role, tone: AppTone.brand),
                        ],
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: AppSpace.s4),
                        Text(meta, style: AppText.body13),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.s12),
                AppButton(
                  label: '编辑资料',
                  iconAsset: AppAssets.homeRename,
                  variant: AppButtonVariant.quiet,
                  size: AppButtonSize.sm,
                  onTap: onEdit,
                ),
              ],
            ),
            if (state.checkStatusEnabled) ...[
              const SizedBox(height: AppSpace.s16),
              Row(
                children: [
                  Expanded(
                    child: AppStatTile(
                      label: '钱包余额',
                      value: state.walletText,
                      unit: '元',
                      boxed: true,
                    ),
                  ),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: AppStatTile(
                      label: '我的积分',
                      value: state.pointsText,
                      boxed: true,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MembershipCard extends StatelessWidget {
  const _MembershipCard({
    required this.state,
    required this.daysRemaining,
    required this.onOpenPlan,
  });

  final PersonalCenterState state;
  final int? daysRemaining;
  final ValueChanged<VipPackageRow> onOpenPlan;

  @override
  Widget build(BuildContext context) {
    final days = daysRemaining;
    final active = days != null && days >= 1;
    final expire = formatProfileDate(state.user['vipExpireDate']);
    final plans = state.vipPackages;
    final benefits = plans.isEmpty
        ? const <String>[]
        : plans
              .reduce((a, b) => a.benefits.length >= b.benefits.length ? a : b)
              .benefits;
    return AppCard(
      title: '会员',
      trailing: AppTag(
        label: active ? '生效中' : '未开通',
        tone: active ? AppTone.success : AppTone.neutral,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (active)
            Text.rich(
              TextSpan(
                style: AppText.body13,
                children: [
                  if (expire.isNotEmpty) ...[
                    const TextSpan(text: '有效期至 '),
                    TextSpan(
                      text: expire,
                      style: AppText.number(size: 13, color: AppColors.ink),
                    ),
                    const TextSpan(text: '，'),
                  ],
                  const TextSpan(text: '剩余 '),
                  TextSpan(
                    text: '$days',
                    style: AppText.number(size: 13, color: AppColors.brand),
                  ),
                  const TextSpan(text: ' 天'),
                ],
              ),
            )
          else
            Text('开通会员后可使用以下权益', style: AppText.body13),
          if (benefits.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s12),
            Wrap(
              spacing: AppSpace.s20,
              runSpacing: AppSpace.s8,
              children: [
                for (final benefit in benefits)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: AppSpace.s4),
                      Text(benefit, style: AppText.body14),
                    ],
                  ),
              ],
            ),
          ],
          if (plans.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s16),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = AppSpace.s12;
                final columns = constraints.maxWidth >= 480
                    ? plans.length.clamp(1, 3)
                    : 1;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final plan in plans)
                      SizedBox(
                        width: width,
                        child: _PlanTile(
                          plan: plan,
                          actionLabel: active ? '续费' : '开通',
                          onTap: () => onOpenPlan(plan),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: AppSpace.s12),
          Text(_kPriceNote, style: AppText.caption12),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.plan,
    required this.actionLabel,
    required this.onTap,
  });

  final VipPackageRow plan;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surfaceSubtle,
      bordered: false,
      padding: const EdgeInsets.all(AppSpace.s12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(plan.name, style: AppText.body14Strong),
                if (plan.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    plan.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption12,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          AppButton(
            label: actionLabel,
            variant: AppButtonVariant.quiet,
            size: AppButtonSize.sm,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.checkStatusEnabled, required this.actions});

  final bool checkStatusEnabled;
  final _PersonalCenterActions actions;

  @override
  Widget build(BuildContext context) {
    final common = <_MenuEntry>[
      _MenuEntry.asset(AppAssets.profileQr, '我的二维码', actions.showMyQr),
      if (checkStatusEnabled) ...[
        _MenuEntry.asset(
          AppAssets.profileRecommend,
          '推荐美术之路给好友',
          actions.recommend,
        ),
        _MenuEntry.asset(AppAssets.profileRedeem, '兑换中心', actions.redeem),
      ],
    ];
    final support = <_MenuEntry>[
      _MenuEntry.asset(AppAssets.profileFeedback, '意见反馈', actions.feedback),
      _MenuEntry.asset(
        AppAssets.profileService,
        '联系客服',
        actions.contactService,
      ),
      _MenuEntry(Icons.menu_book_outlined, '操作指南', actions.openGuide),
      _MenuEntry(Icons.description_outlined, '服务协议与隐私政策', actions.openTerms),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MenuGroup(title: '常用服务', entries: common),
        const SizedBox(height: AppSpace.s16),
        _MenuGroup(title: '帮助与支持', entries: support),
      ],
    );
  }
}

class _MenuEntry {
  const _MenuEntry(this.icon, this.label, this.onTap) : iconAsset = null;
  const _MenuEntry.asset(this.iconAsset, this.label, this.onTap) : icon = null;

  final IconData? icon;
  final String? iconAsset;
  final String label;
  final VoidCallback onTap;
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.title, required this.entries});

  final String title;
  final List<_MenuEntry> entries;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.only(bottom: AppSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s16,
              AppSpace.s16,
              AppSpace.s16,
              AppSpace.s4,
            ),
            child: Text(title, style: AppText.title16),
          ),
          for (var i = 0; i < entries.length; i++)
            AppListRow(
              title: entries[i].label,
              leading: SizedBox.square(
                dimension: 24,
                child: switch (entries[i].iconAsset) {
                  final String asset => AppAssetGraphic(asset),
                  null => Icon(entries[i].icon, size: 20, color: AppColors.ink),
                },
              ),
              chevron: true,
              divider: i < entries.length - 1,
              onTap: entries[i].onTap,
            ),
        ],
      ),
    );
  }
}

class _MyQrCodeDialog extends StatefulWidget {
  const _MyQrCodeDialog({
    required this.nickname,
    required this.mobile,
    required this.avatarUrl,
    required this.imageUrl,
  });

  final String nickname;
  final String mobile;
  final String avatarUrl;
  final String imageUrl;

  @override
  State<_MyQrCodeDialog> createState() => _MyQrCodeDialogState();
}

class _MyQrCodeDialogState extends State<_MyQrCodeDialog> {
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final saved = await saveMyQrCode(
      context,
      imageUrl: widget.imageUrl,
      nickname: widget.nickname,
    );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (saved) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: '我的二维码',
      actions: [
        AppButton(
          label: '关闭',
          variant: AppButtonVariant.secondary,
          onTap: () => Navigator.of(context).pop(),
        ),
        AppButton(label: '保存二维码', loading: _saving, onTap: _save),
      ],
      child: MyQrCodeCard(
        nickname: widget.nickname.isEmpty ? '未命名' : widget.nickname,
        mobile: widget.mobile,
        avatarUrl: widget.avatarUrl,
        imageUrl: widget.imageUrl,
      ),
    );
  }
}

class _RedeemVipDialog extends StatefulWidget {
  const _RedeemVipDialog();

  @override
  State<_RedeemVipDialog> createState() => _RedeemVipDialogState();
}

class _RedeemVipDialogState extends State<_RedeemVipDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_ctrl.text.trim());

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: '兑换会员',
      message: '输入画室发放的兑换码，兑换后会员有效期自动顺延。',
      actions: [
        AppButton(
          label: '取消',
          variant: AppButtonVariant.secondary,
          onTap: () => Navigator.of(context).pop(),
        ),
        AppButton(label: '兑换', onTap: _submit),
      ],
      child: AppInputField(
        controller: _ctrl,
        hint: '请输入兑换码',
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
    );
  }
}

/// 带复制按钮的只读字段（客服邮箱、推广链接）。
class _CopyField extends StatelessWidget {
  const _CopyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppText.caption12Strong),
        const SizedBox(height: AppSpace.s8),
        Container(
          height: AppSize.iconButton,
          padding: const EdgeInsets.only(left: AppSpace.s12),
          decoration: const BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: AppRadius.br8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body14,
                ),
              ),
              AppIconButton(
                icon: Icons.copy_rounded,
                semanticLabel: '复制',
                size: AppButtonSize.sm,
                filled: false,
                color: AppColors.brand,
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: value));
                  if (!context.mounted) {
                    return;
                  }
                  AppToast.showSuccess(context, '已复制');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PersonalCenterSkeleton extends StatelessWidget {
  const _PersonalCenterSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpace.page,
        AppSpace.s4,
        AppSpace.page,
        AppSpace.s24,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                AppCard(
                  padding: EdgeInsets.all(AppSpace.s20),
                  child: Row(
                    children: [
                      AppSkeleton.circle(size: 64),
                      SizedBox(width: AppSpace.s16),
                      Expanded(
                        child: AppSkeletonText(lines: 2, lineHeight: 16),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppSpace.s16),
                AppCard(child: AppSkeletonText(lines: 4)),
              ],
            ),
          ),
          SizedBox(width: AppSpace.s16),
          SizedBox(
            width: 320,
            child: AppCard(child: AppSkeletonText(lines: 6)),
          ),
        ],
      ),
    );
  }
}
