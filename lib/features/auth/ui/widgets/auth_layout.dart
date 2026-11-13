import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/widgets/app_asset_graphic.dart';
import '../../../common/ui/terms_page.dart';
import 'auth_design_canvas.dart';

const _cardLayer1 = 'assets/images/auth/figma_login_card_layer1.png';
const _cardLayer2 = 'assets/images/auth/figma_login_card_layer2.png';
const _cardGradientTop = Color(0xFFD8CCFF);

/// 登录卡片内的 14 号说明文字：行高 12，与原版设计稿的文字框一致。
final TextStyle authLineText = AppText.body14.copyWith(height: 12 / 14);

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

/// 卡片上方的美育集标识。
class AuthBrandLogo extends StatelessWidget {
  const AuthBrandLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        label: '美育集',
        image: true,
        child: AppAssetGraphic(
          AppAssets.shellLogo,
          height: 40,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// 原版登录卡片：浅紫渐变底、2px 白边、右上角淡出的校园建筑和渐变标题。
///
/// 标题距顶 33，首个输入框从卡片顶部 100 开始，内容左右各留 17。
class AuthCard extends StatelessWidget {
  const AuthCard({
    required this.title,
    required this.children,
    this.subtitle,
    this.bottomPadding = 24,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final note = subtitle;
    return ClipRRect(
      borderRadius: AppRadius.br24,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadius.br24,
          border: Border.all(color: AppColors.surface, width: 2),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_cardGradientTop, AppColors.surface, AppColors.surface],
            stops: [0, 0.25, 1],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              left: 158,
              top: 2,
              width: 239,
              height: 136,
              child: IgnorePointer(child: _CardBuilding()),
            ),
            Positioned(
              left: 178,
              top: 104,
              width: 241,
              height: 68,
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 9.15, sigmaY: 9.15),
                    child: const ColoredBox(color: AppColors.surface),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(17, 33, 17, bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(child: _AuthCardTitle(title)),
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.s4),
                    Text(
                      note,
                      textAlign: TextAlign.center,
                      style: AppText.caption12,
                    ),
                    const SizedBox(height: 9),
                  ] else
                    const SizedBox(height: 31),
                  ...children,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardBuilding extends StatelessWidget {
  const _CardBuilding();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.transparent, Color(0xFF5E5E5E)],
          ).createShader(bounds),
          child: const Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: -19,
                width: 288,
                height: 164,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image(image: AssetImage(_cardLayer1), fit: BoxFit.cover),
                    Image(image: AssetImage(_cardLayer2), fit: BoxFit.cover),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthCardTitle extends StatelessWidget {
  const _AuthCardTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => const LinearGradient(
          colors: [AppColors.ink, AppColors.brand],
        ).createShader(bounds),
        child: Text(
          title,
          style: AppText.title24.copyWith(
            color: AppColors.surface,
            height: 36 / 24,
          ),
        ),
      ),
    );
  }
}

/// 原版登录主按钮：45 高、圆角 12、品牌紫左深右浅渐变、14 号白字。
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    required this.label,
    required this.onTap,
    this.loading = false,
    this.fontFamily = 'Inter',
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final bool loading;
  final String fontFamily;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: loading ? null : onTap,
      child: Container(
        height: AppSize.buttonMd,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          borderRadius: AppRadius.br12,
          gradient: LinearGradient(
            colors: [AppColors.brand, AppColors.brandSoft],
          ),
        ),
        child: loading
            ? const AppLoadingIndicator(size: 16, color: AppColors.onBrand)
            : Text(
                label,
                style: TextStyle(
                  color: AppColors.onBrand,
                  fontSize: 14,
                  fontFamily: fontFamily,
                  fontFamilyFallback: const ['Harmony'],
                  fontWeight: FontWeight.w400,
                  height: 12 / 14,
                ),
              ),
      ),
    );
  }
}

/// 卡片里的纯文字入口（「忘记密码？」「返回登录」等），没有按钮底色。
class AuthTextLink extends StatelessWidget {
  const AuthTextLink({
    required this.label,
    required this.onTap,
    this.color = AppColors.textPlaceholder,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      child: Text(label, style: authLineText.copyWith(color: color)),
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

/// 打开协议页（隐私政策直接定位到对应章节）；协议页「我已知晓并同意上述协议」返回 true 时视为同意。
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

/// 原版协议勾选框：14 方形点击区内 12 方形、圆角 2，未选品牌紫描边，选中品牌紫底白勾。
class AuthAgreementCheckbox extends StatelessWidget {
  const AuthAgreementCheckbox({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: () => onChanged(!value),
      semanticLabel: '同意用户服务协议和隐私政策',
      checked: value,
      child: SizedBox.square(
        dimension: 14,
        child: Center(
          child: value
              ? const CustomPaint(
                  size: Size.square(12),
                  painter: _CheckedBoxPainter(),
                )
              : Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(2)),
                    border: Border.all(color: AppColors.brand),
                  ),
                ),
        ),
      ),
    );
  }
}

class _CheckedBoxPainter extends CustomPainter {
  const _CheckedBoxPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 12;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(2 * unit)),
      Paint()..color = AppColors.brand,
    );
    final tick = Path()
      ..moveTo(2 * unit, 5.318 * unit)
      ..lineTo(5.111 * unit, 8.5 * unit)
      ..lineTo(10 * unit, 3.5 * unit);
    canvas.drawPath(
      tick,
      Paint()
        ..color = AppColors.onBrand
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * unit,
    );
  }

  @override
  bool shouldRepaint(covariant _CheckedBoxPainter oldDelegate) => false;
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
    final text = authLineText;
    final link = text.copyWith(color: AppColors.brand);
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthAgreementCheckbox(value: checked, onChanged: onChanged),
          const SizedBox(width: AppSpace.s4),
          AppPressable(
            onTap: () => onChanged(!checked),
            child: Text('我已阅读并同意', style: text),
          ),
          for (final section in AuthTermsSection.values) ...[
            if (section != AuthTermsSection.values.first)
              Text('和', style: text),
            AppPressable(
              onTap: () => onOpenTerms(section),
              child: Text(section.title, style: link),
            ),
          ],
        ],
      ),
    );
  }
}

/// 登录 / 注册页底部的互相切换入口：「没有账号？」+ 品牌紫入口。
///
/// 登录页两侧带 100 宽细线，注册页不带，与原版一致。
class AuthSwitchLine extends StatelessWidget {
  const AuthSwitchLine({
    required this.prompt,
    required this.action,
    required this.onTap,
    this.divided = true,
    super.key,
  });

  final String prompt;
  final String action;
  final VoidCallback onTap;
  final bool divided;

  @override
  Widget build(BuildContext context) {
    const line = SizedBox(
      width: 100,
      child: Divider(height: 1, thickness: 1, color: AppColors.lineSoft),
    );
    return Row(
      children: [
        if (divided) line,
        Expanded(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(prompt, style: authLineText),
                const SizedBox(width: AppSpace.s4),
                AuthTextLink(
                  label: action,
                  color: AppColors.brand,
                  onTap: onTap,
                ),
              ],
            ),
          ),
        ),
        if (divided) line,
      ],
    );
  }
}

/// 未勾选协议就提交时的确认弹窗：说明需要同意的协议，可直接打开阅读。
///
/// 返回 true 表示用户点了「同意并…」，或在协议页点了「我已知晓并同意上述协议」。
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
