import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/theme/app_font.dart';
import '../../../../core/widgets/app_loading_indicator.dart';

/// 画面区域底色（浅灰，便于看清白底画作的边缘）。
const kToolStageColor = Color(0xFFF2F1F6);

class ToolStage extends StatelessWidget {
  const ToolStage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(color: kToolStageColor, child: child),
    );
  }
}

/// 画面上的半透明小标签。
class StageLabel extends StatelessWidget {
  const StageLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: ArtText.caption(color: Colors.white)),
      ),
    );
  }
}

/// 等比完整显示一张处理结果；[image] 为空时显示处理中。
class StageImagePane extends StatelessWidget {
  const StageImagePane({
    required this.image,
    this.label,
    this.padding = const EdgeInsets.all(12),
    super.key,
  });

  final ui.Image? image;
  final String? label;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final image = this.image;
    return Stack(
      children: [
        Positioned.fill(
          child: image == null
              ? const Center(child: AppLoadingIndicator(size: 32))
              : Padding(
                  padding: padding,
                  child: RawImage(
                    image: image,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
        ),
        if (label != null)
          Positioned(left: 12, top: 12, child: StageLabel(label!)),
      ],
    );
  }
}

class ToolPanelSection extends StatelessWidget {
  const ToolPanelSection({
    required this.title,
    required this.child,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: ArtText.body(
                    size: 13,
                    color: ArtColors.ink2,
                    weight: AppFont.w500,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// 胶囊开关（统一品牌色，不依赖平台开关样式）。
class ArtToggle extends StatelessWidget {
  const ArtToggle({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 26,
        padding: const EdgeInsets.all(3),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: value ? ArtColors.brand : ArtColors.ink4,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ToolSwitchRow extends StatelessWidget {
  const ToolSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    super.key,
  });

  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: ArtText.body(weight: AppFont.w500)),
                  if (hint != null) ...[
                    const SizedBox(height: 2),
                    Text(hint!, style: ArtText.caption(size: 11)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            ArtToggle(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class ToolSliderRow extends StatelessWidget {
  const ToolSliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.valueLabel,
    required this.onChanged,
    this.divisions,
    super.key,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: ArtText.body(weight: AppFont.w500)),
              ),
              Text(
                valueLabel,
                style: ArtText.number(size: 14, color: ArtColors.brandDeep),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: ArtColors.brand,
              inactiveTrackColor: ArtColors.brandTint,
              thumbColor: ArtColors.brand,
              overlayColor: ArtColors.brand.withValues(alpha: 0.12),
              activeTickMarkColor: Colors.transparent,
              inactiveTickMarkColor: Colors.transparent,
            ),
            child: Slider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// 说明 / 技巧卡片。
class ToolTipCard extends StatelessWidget {
  const ToolTipCard({
    required this.title,
    required this.text,
    this.icon = Icons.lightbulb_outline_rounded,
    super.key,
  });

  final String title;
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ArtColors.brandWash,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: ArtColors.brandDeep),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: ArtText.body(
                    size: 13,
                    color: ArtColors.brandDeep,
                    weight: AppFont.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(text, style: ArtText.caption(size: 12, color: ArtColors.ink2)),
        ],
      ),
    );
  }
}

/// 设置项里的单选胶囊。
class ToolOptionChip extends StatelessWidget {
  const ToolOptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = ArtColors.brand,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.12) : ArtColors.subtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            height: 1.2,
            color: selected ? accent : ArtColors.ink2,
            fontWeight: selected ? AppFont.w600 : AppFont.w400,
            fontFamily: 'PingFang SC',
          ),
        ),
      ),
    );
  }
}
