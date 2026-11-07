import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/ui.dart';

/// 画面区域：浅灰底，便于看清白底画作的边缘。
class ToolStage extends StatelessWidget {
  const ToolStage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.br12,
      child: ColoredBox(color: AppColors.surfaceSubtle, child: child),
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s8,
          vertical: AppSpace.s4,
        ),
        decoration: BoxDecoration(
          color: AppColors.ink.withValues(alpha: 0.6),
          borderRadius: AppRadius.br8,
        ),
        child: Text(
          text,
          style: AppText.caption12.copyWith(color: AppColors.onBrand),
        ),
      ),
    );
  }
}

/// 等比完整显示一张图；[image] 为空时显示处理中，[failed] 时显示错误状态与重试。
class StageImagePane extends StatelessWidget {
  const StageImagePane({
    required this.image,
    this.label,
    this.failed = false,
    this.onRetry,
    this.padding = const EdgeInsets.all(AppSpace.s12),
    super.key,
  });

  final ui.Image? image;
  final String? label;
  final bool failed;
  final VoidCallback? onRetry;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final image = this.image;
    return Stack(
      children: [
        Positioned.fill(
          child: image == null
              ? (failed
                    ? AppErrorState(
                        title: '处理失败',
                        description: '这张图片暂时无法处理，可以重试或换一张图片',
                        icon: Icons.broken_image_outlined,
                        onRetry: onRetry,
                      )
                    : const Center(child: AppLoadingIndicator(size: 32)))
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
          Positioned(
            left: AppSpace.s12,
            top: AppSpace.s12,
            child: StageLabel(label!),
          ),
      ],
    );
  }
}

/// 处理结果与原图：打开对比时左右并排，否则只显示结果。
class CompareStage extends StatelessWidget {
  const CompareStage({
    required this.original,
    required this.processed,
    required this.label,
    required this.compare,
    this.failed = false,
    this.onRetry,
    super.key,
  });

  final ui.Image original;
  final ui.Image? processed;
  final String label;
  final bool compare;
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final result = ToolStage(
      child: StageImagePane(
        image: processed,
        label: label,
        failed: failed,
        onRetry: onRetry,
      ),
    );
    if (!compare) {
      return result;
    }
    return Row(
      children: [
        Expanded(
          child: ToolStage(
            child: StageImagePane(image: original, label: '原图'),
          ),
        ),
        const SizedBox(width: AppSpace.s12),
        Expanded(child: result),
      ],
    );
  }
}

/// 控制面板里的一个分区：小标题 + 右侧补充 + 内容。
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
      padding: const EdgeInsets.only(bottom: AppSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppText.body14Strong)),
              if (trailing != null) ...[
                const SizedBox(width: AppSpace.s8),
                DefaultTextStyle.merge(
                  style: AppText.caption12,
                  child: trailing!,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          child,
        ],
      ),
    );
  }
}

/// 面板里的分段选择，各段等分宽度。
class ToolSegmented<T> extends StatelessWidget {
  const ToolSegmented({
    required this.values,
    required this.value,
    required this.labelOf,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final List<T> values;
  final T value;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppSegmented<T>(
      segments: [
        for (final v in values) AppSegment<T>(value: v, label: labelOf(v)),
      ],
      value: value,
      onChanged: onChanged,
      enabled: enabled,
      expand: true,
    );
  }
}

/// 开关行：标题 + 说明 + 开关，整行可点。
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
      padding: const EdgeInsets.only(bottom: AppSpace.s16),
      child: AppPressable(
        onTap: () => onChanged(!value),
        toggled: value,
        semanticLabel: label,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: AppText.body14Strong),
                  if (hint != null) ...[
                    const SizedBox(height: 2),
                    Text(hint!, style: AppText.caption12),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpace.s12),
            ExcludeSemantics(
              child: AppSwitch(value: value, onChanged: onChanged),
            ),
          ],
        ),
      ),
    );
  }
}

/// 工具箱统一滑块：拖动或点按轨道立即跳到对应位置，没有按压光圈与动画。
class ToolSlider extends StatelessWidget {
  const ToolSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.onChangeEnd,
    this.semanticLabel,
    super.key,
  });

  final double value;
  final double min;
  final double max;

  /// 设置后只停在等分点上。
  final int? divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final String? semanticLabel;

  static const double _height = 32;
  static const double _thumb = 18;

  double _snap(double raw) {
    final clamped = raw.clamp(min, max).toDouble();
    final steps = divisions;
    if (steps == null || steps <= 0 || max <= min) {
      return clamped;
    }
    final step = (max - min) / steps;
    return min + ((clamped - min) / step).round() * step;
  }

  double _valueAt(double dx, double width) {
    final usable = width - _thumb;
    if (usable <= 0) {
      return value;
    }
    final t = ((dx - _thumb / 2) / usable).clamp(0.0, 1.0);
    return _snap(min + (max - min) * t);
  }

  void _emit(double next) {
    if (next != value) {
      onChanged(next);
    }
  }

  double get _step {
    final steps = divisions;
    return steps == null || steps <= 0 ? (max - min) / 20 : (max - min) / steps;
  }

  /// 读屏用的数值：等分步长为整数时读整数，否则保留两位小数。
  String _spoken(double v) {
    final integral =
        _step == _step.roundToDouble() && min == min.roundToDouble();
    return v.toStringAsFixed(integral ? 0 : 2);
  }

  @override
  Widget build(BuildContext context) {
    final current = value.clamp(min, max).toDouble();
    final fraction = max > min ? (current - min) / (max - min) : 0.0;
    final increased = _snap(current + _step);
    final decreased = _snap(current - _step);
    return Semantics(
      slider: true,
      label: semanticLabel,
      value: _spoken(current),
      increasedValue: _spoken(increased),
      decreasedValue: _spoken(decreased),
      onIncrease: () {
        _emit(increased);
        onChangeEnd?.call(increased);
      },
      onDecrease: () {
        _emit(decreased);
        onChangeEnd?.call(decreased);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) =>
                  _emit(_valueAt(details.localPosition.dx, width)),
              onTapUp: (details) =>
                  onChangeEnd?.call(_valueAt(details.localPosition.dx, width)),
              onHorizontalDragStart: (details) =>
                  _emit(_valueAt(details.localPosition.dx, width)),
              onHorizontalDragUpdate: (details) =>
                  _emit(_valueAt(details.localPosition.dx, width)),
              onHorizontalDragEnd: (_) => onChangeEnd?.call(value),
              child: SizedBox(
                height: _height,
                width: double.infinity,
                child: CustomPaint(
                  painter: _SliderPainter(fraction: fraction, thumb: _thumb),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SliderPainter extends CustomPainter {
  const _SliderPainter({required this.fraction, required this.thumb});

  final double fraction;
  final double thumb;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final left = thumb / 2;
    final right = size.width - thumb / 2;
    final x = left + (right - left) * fraction;
    final track = Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(
        Offset(left, cy),
        Offset(right, cy),
        track..color = AppColors.line,
      )
      ..drawLine(Offset(left, cy), Offset(x, cy), track..color = AppColors.brand);
    final center = Offset(x, cy);
    for (final shadow in AppShadow.knob) {
      canvas.drawCircle(
        center + shadow.offset,
        thumb / 2,
        Paint()
          ..color = shadow.color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurSigma),
      );
    }
    canvas
      ..drawCircle(center, thumb / 2, Paint()..color = AppColors.surface)
      ..drawCircle(
        center,
        thumb / 2 - 1,
        Paint()
          ..color = AppColors.brand
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
  }

  @override
  bool shouldRepaint(covariant _SliderPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.thumb != thumb;
}

/// 滑块行：标题 + 当前值 + 滑块。
class ToolSliderRow extends StatelessWidget {
  const ToolSliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.valueLabel,
    required this.onChanged,
    this.divisions,
    this.onChangeEnd,
    this.hint,
    super.key,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String valueLabel;
  final String? hint;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: AppText.body14Strong)),
              Text(
                valueLabel,
                style: AppText.number(size: 14, color: AppColors.brand),
              ),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint!, style: AppText.caption12),
          ],
          const SizedBox(height: AppSpace.s4),
          ToolSlider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
            semanticLabel: label,
          ),
        ],
      ),
    );
  }
}

/// 说明 / 技巧卡片：浅灰底，不抢主操作的颜色。
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
      padding: const EdgeInsets.all(AppSpace.s12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: AppRadius.br8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: AppText.body14Strong)),
            ],
          ),
          const SizedBox(height: AppSpace.s4),
          Text(text, style: AppText.body13),
        ],
      ),
    );
  }
}

/// 提示条：用于「以考试院公布为准」等说明。
class ToolNotice extends StatelessWidget {
  const ToolNotice(this.text, {this.tone = AppTone.warning, super.key});

  final String text;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s12,
        vertical: AppSpace.s8,
      ),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: AppRadius.br8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: tone.foreground,
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          Expanded(
            child: Text(
              text,
              style: AppText.body13.copyWith(color: tone.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// 色块 + HEX + 补充说明 + 百分比的一行，点击复制 HEX。
class SwatchRow extends StatelessWidget {
  const SwatchRow({
    required this.color,
    required this.hex,
    required this.onCopy,
    this.caption,
    this.trailing,
    super.key,
  });

  final Color color;
  final String hex;
  final String? caption;
  final String? trailing;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: () => onCopy(hex),
      semanticLabel: '复制 $hex',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: AppRadius.br8,
                border: Border.all(color: AppColors.line),
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            Text(hex, style: AppText.number(size: 14)),
            const SizedBox(width: AppSpace.s8),
            Expanded(
              child: Text(
                caption ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption12,
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: AppText.number(size: 13, color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}

/// 面积比例条：按比例横向排列的色块。
class RatioBar extends StatelessWidget {
  const RatioBar({
    required this.colors,
    required this.ratios,
    this.height = 20,
    super.key,
  });

  final List<Color> colors;
  final List<double> ratios;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.br4,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: AppRadius.br4,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < colors.length; i++)
              if (ratios[i] > 0)
                Expanded(
                  flex: (ratios[i] * 1000).round().clamp(1, 1000),
                  child: ColoredBox(color: colors[i]),
                ),
          ],
        ),
      ),
    );
  }
}

/// 复制 HEX 并提示。
Future<void> copyHex(BuildContext context, String hex) async {
  await Clipboard.setData(ClipboardData(text: hex));
  if (context.mounted) {
    AppToast.showSuccess(context, '已复制 $hex');
  }
}
