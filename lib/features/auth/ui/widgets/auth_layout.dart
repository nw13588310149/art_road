import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/ui/ui.dart';
import '../../../common/ui/terms_page.dart';
import 'auth_design_canvas.dart';

/// 登录、注册、找回密码共用的版式：Logo 与卡片左上角位置固定，卡片高度随内容。
///
/// 内容按 399 宽排版，再随 [AuthDesignCanvas] 的比例整体缩放，与背景插画保持一致。
class AuthPageFrame extends StatelessWidget {
  const AuthPageFrame({
    required this.card,
    this.below,
    this.cardTop = 163,
    super.key,
  });

  final Widget card;

  /// 卡片下方的附加面板（演示身份）。
  final Widget? below;

  static const double left = 691;
  static const double logoTop = 96;
  final double cardTop;
  static const double width = 399;

  @override
  Widget build(BuildContext context) {
    final extra = below;
    return Scaffold(
      // 设计稿按 1180×820 等比缩放，键盘弹出时不压缩 body，避免整页重新缩放。
      resizeToAvoidBottomInset: false,
      body: AuthDesignCanvas(
        builder: (scale) => Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: left * scale,
              top: logoTop * scale,
              child: _Scaled(scale: scale, child: const AuthBrandLogo()),
            ),
            Positioned(
              left: left * scale,
              top: cardTop * scale,
              bottom: 0,
              width: width * scale,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: AppSpace.s16 * scale),
                child: _Scaled(
                  scale: scale,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      card,
                      if (extra != null) ...[
                        const SizedBox(height: AppSpace.s16),
                        extra,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Scaled extends StatelessWidget {
  const _Scaled({required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AuthPageFrame.width * scale,
      child: FittedBox(
        fit: BoxFit.fitWidth,
        alignment: Alignment.topLeft,
        child: SizedBox(width: AuthPageFrame.width, child: child),
      ),
    );
  }
}

/// 卡片上方的艺考网标识。
class AuthBrandLogo extends StatelessWidget {
  const AuthBrandLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        label: '艺考网',
        image: true,
        child: SvgPicture.asset(
          AppAssets.shellLogo,
          height: 40,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }
}

/// 登录、注册和找回密码沿用同一套居中标题和渐变表单面板。
class AuthCard extends StatelessWidget {
  const AuthCard({
    required this.title,
    required this.children,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final note = subtitle;
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 33, 17, 17),
      decoration: BoxDecoration(
        borderRadius: AppRadius.br24,
        border: Border.all(color: AppColors.surface, width: 2),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.brandTint, AppColors.surface, AppColors.surface],
          stops: [0, 0.25, 1],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, textAlign: TextAlign.center, style: AppText.title24),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s4),
            Text(note, textAlign: TextAlign.center, style: AppText.body13),
          ],
          SizedBox(height: note == null ? 33 : AppSpace.s20),
          ...children,
        ],
      ),
    );
  }
}

/// 协议页的两个章节。
enum AuthTermsSection {
  service('《用户服务协议》'),
  privacy('《隐私政策》');

  const AuthTermsSection(this.title);

  final String title;
}

/// 打开协议页（隐私政策直接定位到对应章节）；协议页「我已阅读并同意」返回 true 时视为同意。
Future<bool> openAuthTerms(
  BuildContext context,
  AuthTermsSection section,
) async {
  final result = await Navigator.of(context).pushNamed<Object?>(
    RoutePaths.xieyi2,
    arguments: section == AuthTermsSection.privacy
        ? TermsPage.privacyAnchor
        : null,
  );
  return result == true;
}

/// 「我已阅读并同意《用户服务协议》和《隐私政策》」：勾选框与说明文字切换勾选，
/// 协议链接只负责打开协议，不改变勾选状态。
class AuthAgreementRow extends StatelessWidget {
  const AuthAgreementRow({
    required this.checked,
    required this.onChanged,
    required this.onOpenTerms,
    super.key,
  });

  final bool checked;
  final ValueChanged<bool> onChanged;
  final ValueChanged<AuthTermsSection> onOpenTerms;

  @override
  Widget build(BuildContext context) {
    final text = AppText.body13;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AppCheckbox(
          value: checked,
          onChanged: onChanged,
          semanticLabel: '同意用户服务协议和隐私政策',
        ),
        const SizedBox(width: AppSpace.s4),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: text,
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: AppPressable(
                    onTap: () => onChanged(!checked),
                    child: Text('我已阅读并同意', style: text),
                  ),
                ),
                _termsLink(AuthTermsSection.service, text),
                const TextSpan(text: '和'),
                _termsLink(AuthTermsSection.privacy, text),
              ],
            ),
          ),
        ),
      ],
    );
  }

  InlineSpan _termsLink(AuthTermsSection section, TextStyle style) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: AppPressable(
        onTap: () => onOpenTerms(section),
        child: Text(
          section.title,
          style: style.copyWith(color: AppColors.brand),
        ),
      ),
    );
  }
}

/// 登录 / 注册页底部的互相切换入口，两页同一样式：左右细线 + 提示 + 文字按钮。
class AuthSwitchLine extends StatelessWidget {
  const AuthSwitchLine({
    required this.prompt,
    required this.action,
    required this.onTap,
    super.key,
  });

  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const line = Expanded(
      child: Divider(height: 1, thickness: 1, color: AppColors.lineSoft),
    );
    return Row(
      children: [
        line,
        const SizedBox(width: AppSpace.s12),
        Text(
          prompt,
          style: AppText.body14.copyWith(color: AppColors.textSecondary),
        ),
        AppButton(
          label: action,
          variant: AppButtonVariant.text,
          size: AppButtonSize.sm,
          onTap: onTap,
        ),
        const SizedBox(width: AppSpace.s12),
        line,
      ],
    );
  }
}

/// 未勾选协议就提交时的确认弹窗：说明需要同意的协议，可直接打开阅读。
///
/// 返回 true 表示用户点了「同意并…」，或在协议页点了「我已阅读并同意」。
Future<bool> showAuthTermsDialog(
  BuildContext context, {
  required String confirmLabel,
}) async {
  final result = await showAppDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final text = AppText.body14.copyWith(color: AppColors.textSecondary);
      Future<void> open(AuthTermsSection section) async {
        final agreed = await openAuthTerms(dialogContext, section);
        if (agreed && dialogContext.mounted) {
          Navigator.of(dialogContext).pop(true);
        }
      }

      InlineSpan link(AuthTermsSection section) => WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: AppPressable(
          onTap: () => open(section),
          child: Text(
            section.title,
            style: text.copyWith(color: AppColors.brand),
          ),
        ),
      );

      return AppDialog(
        title: '请先阅读并同意协议',
        actions: [
          AppButton(
            label: '不同意',
            variant: AppButtonVariant.secondary,
            onTap: () => Navigator.of(dialogContext).pop(false),
          ),
          AppButton(
            label: confirmLabel,
            onTap: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
        child: Text.rich(
          TextSpan(
            style: text,
            children: [
              const TextSpan(text: '为保障你的权益，请阅读'),
              link(AuthTermsSection.service),
              const TextSpan(text: '和'),
              link(AuthTermsSection.privacy),
              const TextSpan(text: '，了解我们如何收集和使用你的个人信息。同意后即可继续。'),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}
