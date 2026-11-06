import 'package:flutter/material.dart';

import '../art/art_tokens.dart';
import '../ui/ui.dart';

/// 网络图片，委托 [AppImage]：自动补全相对路径、支持 `asset:` 引用。
class ArtNetworkImage extends StatelessWidget {
  const ArtNetworkImage(
    this.url, {
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.alignment = Alignment.center,
    super.key,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return AppImage(
      src: url,
      fit: fit,
      width: width,
      height: height,
      borderRadius: borderRadius,
      alignment: alignment,
    );
  }
}

/// 头像，委托 [AppAvatar]：有图显示图片，无图显示姓氏。
class ArtAvatar extends StatelessWidget {
  const ArtAvatar({
    required this.name,
    this.url = '',
    this.size = 40,
    super.key,
  });

  final String name;
  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AppAvatar(name: name, url: url, size: size);
  }
}

/// 模块页头，委托 [AppPageHeader]。[actions] 按传入的原样排列（调用方自带间距）。
class ArtPageHeader extends StatelessWidget {
  const ArtPageHeader({
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    this.onBack,
    this.bottom,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return AppPageHeader(
      title: title,
      subtitle: subtitle,
      onBack: onBack,
      actions: actions.isEmpty
          ? const <Widget>[]
          : [Row(mainAxisSize: MainAxisSize.min, children: actions)],
      bottom: bottom,
    );
  }
}

/// 空状态，委托 [AppEmptyState]。
class ArtEmptyState extends StatelessWidget {
  const ArtEmptyState({
    required this.message,
    this.icon = Icons.palette_outlined,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      title: message,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

/// 主按钮 / 次按钮，委托 [AppButton]：`primary: false` 为 quiet；
/// [height] 小于 40 用 sm（34 高），否则 md（44 高）。
class ArtButton extends StatelessWidget {
  const ArtButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.primary = true,
    this.loading = false,
    this.height = 38,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool primary;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      onTap: onTap,
      icon: icon,
      loading: loading,
      variant: primary ? AppButtonVariant.primary : AppButtonVariant.quiet,
      size: height < 40 ? AppButtonSize.sm : AppButtonSize.md,
    );
  }
}

/// 档位徽章（A–K）：档位色实底 + 白色 Manrope 字母。
class ArtGradeBadge extends StatelessWidget {
  const ArtGradeBadge({required this.grade, this.size = 24, super.key});

  final String grade;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ArtColors.grade(grade),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        grade.isEmpty ? '—' : grade,
        style: AppText.number(
          size: size * 0.55,
          color: AppColors.onBrand,
        ).copyWith(height: 1),
      ),
    );
  }
}

/// 指标，委托 [AppStatTile]。
class ArtStatTile extends StatelessWidget {
  const ArtStatTile({
    required this.label,
    required this.value,
    this.unit,
    this.delta,
    this.deltaSuffix = '',
    this.invertDelta = false,
    this.color = ArtColors.ink,
    super.key,
  });

  final String label;
  final String value;
  final String? unit;
  final num? delta;
  final String deltaSuffix;

  /// 名次类指标：数值变小代表进步。
  final bool invertDelta;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppStatTile(
      label: label,
      value: value,
      unit: unit,
      delta: delta,
      deltaSuffix: deltaSuffix,
      invertDelta: invertDelta,
      valueColor: color,
    );
  }
}

/// 分段切换，委托 [AppSegmented]（sm），选中立即切换。
class ArtSegmentTabs<T> extends StatelessWidget {
  const ArtSegmentTabs({
    required this.items,
    required this.value,
    required this.onChanged,
    this.labelOf,
    super.key,
  });

  final List<T> items;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(T item)? labelOf;

  @override
  Widget build(BuildContext context) {
    return AppSegmented<T>(
      segments: [
        for (final item in items)
          AppSegment<T>(
            value: item,
            label: labelOf?.call(item) ?? item.toString(),
          ),
      ],
      value: value,
      onChanged: onChanged,
      size: AppControlSize.sm,
    );
  }
}

/// 卡片，委托 [AppCard]：白卡带 1px 浅描边，浅灰子卡片不加描边。
class ArtCard extends StatelessWidget {
  const ArtCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
    this.onTap,
    this.radius = AppRadius.card,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: padding,
      color: color,
      onTap: onTap,
      radius: radius,
      bordered: color == AppColors.surface,
      child: child,
    );
  }
}
