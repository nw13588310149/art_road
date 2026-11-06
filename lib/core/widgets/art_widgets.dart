import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../art/art_tokens.dart';
import '../network/media_url.dart';
import '../theme/app_font.dart';

/// 网络图片：自动补全相对路径，加载中显示浅底，失败显示占位图标。
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
    final resolved = MediaUrl.resolve(url);
    Widget child;
    if (resolved.isEmpty) {
      child = _placeholder(Icons.image_outlined);
    } else {
      child = CachedNetworkImage(
        imageUrl: resolved,
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (context, _) => _placeholder(null),
        errorWidget: (context, _, _) => _placeholder(Icons.broken_image_outlined),
      );
    }
    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return SizedBox(width: width, height: height, child: child);
  }

  Widget _placeholder(IconData? icon) {
    return Container(
      width: width,
      height: height,
      color: ArtColors.subtle,
      alignment: Alignment.center,
      child: icon == null
          ? null
          : Icon(icon, color: ArtColors.ink4, size: 28),
    );
  }
}

/// 头像：有图显示图片，无图按姓名首字生成彩色圆形头像。
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

  static const _palette = <Color>[
    Color(0xFF715EFE),
    Color(0xFF4A74D6),
    Color(0xFF3B9A6E),
    Color(0xFF1F8FA8),
    Color(0xFFDE7A34),
    Color(0xFFD64A62),
  ];

  @override
  Widget build(BuildContext context) {
    final resolved = MediaUrl.resolve(url);
    final text = name.trim();
    final initial = text.isEmpty ? '?' : text.characters.last;
    final color = _palette[text.hashCode.abs() % _palette.length];
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: AppFont.w600,
          fontFamily: 'PingFang SC',
          height: 1,
        ),
      ),
    );
    if (resolved.isEmpty) {
      return fallback;
    }
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: resolved,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, _) => fallback,
        errorWidget: (context, _, _) => fallback,
      ),
    );
  }
}

/// 模块页统一页头：标题 + 副标题 + 右侧操作区，可选返回按钮。
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (onBack != null) ...[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onBack,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: ArtColors.subtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: ArtColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ArtText.title(),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ArtText.caption(size: 13),
                      ),
                    ],
                  ],
                ),
              ),
              ...actions,
            ],
          ),
          if (bottom != null) ...[const SizedBox(height: 14), bottom!],
        ],
      ),
    );
  }
}

/// 空状态：图标 + 说明 + 可选操作按钮。
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: ArtColors.brandWash,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: ArtColors.brandSoft, size: 34),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: ArtText.body(color: ArtColors.ink3),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              ArtButton(label: actionLabel!, onTap: onAction!),
            ],
          ],
        ),
      ),
    );
  }
}

/// 主按钮 / 次按钮。
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
    final enabled = onTap != null && !loading;
    final fg = primary ? Colors.white : ArtColors.brandDeep;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: primary ? ArtColors.brandGradient : null,
            color: primary ? null : ArtColors.brandWash,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              else if (icon != null)
                Icon(icon, size: 16, color: fg),
              if (loading || icon != null) const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 14,
                  fontWeight: AppFont.w500,
                  fontFamily: 'PingFang SC',
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 档位徽章（A–K）。
class ArtGradeBadge extends StatelessWidget {
  const ArtGradeBadge({required this.grade, this.size = 24, super.key});

  final String grade;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = ArtColors.grade(grade);
    final isA = grade.trim().toUpperCase() == 'A';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isA ? null : color,
        gradient: isA
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ArtColors.brandSoft, ArtColors.brandDeep],
              )
            : null,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        grade.isEmpty ? '—' : grade,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.55,
          height: 1,
          fontWeight: AppFont.w600,
          fontFamily: 'Manrope',
        ),
      ),
    );
  }
}

/// 指标卡：标题 + 数值 + 单位 + 可选变化量（正数绿色上升，负数红色下降）。
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
    final d = delta;
    final better = d == null ? null : (invertDelta ? d < 0 : d > 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: ArtText.caption()),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value, style: ArtText.number(color: color)),
            if (unit != null) ...[
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(unit!, style: ArtText.caption()),
              ),
            ],
            if (d != null && d != 0) ...[
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '${better! ? '↑' : '↓'}${formatScore(d.abs())}$deltaSuffix',
                  style: ArtText.caption(
                    color: better ? ArtColors.up : ArtColors.down,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// 分段切换（页签 / 筛选）。
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
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ArtColors.subtle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(item),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: item == value ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: item == value
                      ? const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  labelOf?.call(item) ?? item.toString(),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    color: item == value ? ArtColors.brandDeep : ArtColors.ink2,
                    fontWeight: item == value ? AppFont.w600 : AppFont.w400,
                    fontFamily: 'PingFang SC',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 白底圆角卡片。
class ArtCard extends StatelessWidget {
  const ArtCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
    this.onTap,
    this.radius = 16,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
    if (onTap == null) {
      return card;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: card,
    );
  }
}
