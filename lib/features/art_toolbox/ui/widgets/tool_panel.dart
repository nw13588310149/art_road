import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/ui.dart';
import '../../../gallery/ui/widgets/library_controls.dart';

/// 工具箱各工具共用的画面与参数控件。
///
/// 外观沿用范画库、美术书刊已经整理好的资料预览控件（`library_controls.dart`）：
/// 画布、角标、分区标题、图标按钮与进度条；选项块取原版设置页的独立选项块
/// （40 高、圆角 8、选中墨色底），滑条取原版「两端加减」的写法。

/// 画面区域：资料预览的画布（圆角 7、浅色底），四周 16 的留白由外层布局提供。
class ToolStage extends StatelessWidget {
  const ToolStage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LibraryCanvas(padding: EdgeInsets.zero, child: child);
  }
}

/// 画面角上的名称：贴着画布左上角，样式取自预览缩略图的页码徽标
/// （浅灰底、12 号字，只有右下角是圆角）。
class StageLabel extends StatelessWidget {
  const StageLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: const BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: BorderRadius.only(bottomRight: Radius.circular(8)),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: libraryText(size: 12, color: AppColors.ink, height: 1.2),
        ),
      ),
    );
  }
}

/// 画面左下角的操作提示，用预览页的计数徽标，位置与范画详情的缩放提示一致。
class StageHint extends StatelessWidget {
  const StageHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 10,
      bottom: 10,
      child: IgnorePointer(child: LibraryCounter(text)),
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
          Positioned(left: 0, top: 0, child: StageLabel(label!)),
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

/// 控制面板里的一个分区：预览侧栏的分区标题（16 号粗体 + 细线，右侧可带一句
/// 12 号说明），标题下 12 是内容，分区之间 20。
class ToolPanelSection extends StatelessWidget {
  const ToolPanelSection({
    required this.title,
    required this.child,
    this.trailing,
    this.bottom = AppSpace.s20,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  /// 分区下方的留白；内容以自带下边距的参数行结尾时可以调小。
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final note = trailing;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LibrarySectionTitle(
            title,
            trailing: note == null
                ? null
                : DefaultTextStyle.merge(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: libraryText(
                      size: 12,
                      color: AppColors.textPlaceholder,
                    ),
                    child: note,
                  ),
          ),
          const SizedBox(height: AppSpace.s12),
          child,
        ],
      ),
    );
  }
}

/// 表单里一项的名称：14 号字，下面 6 是控件（与输入框自带的标题同一写法）。
class ToolField extends StatelessWidget {
  const ToolField({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppText.body14),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// 工具参数的独立选项块，沿用原版设置页的数值：40 高、圆角 8、浅灰底，
/// 选中为墨色底白字，14 号字；同一行之间 12、换行之间 8。
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

  static const double _gap = AppSpace.s12;
  static const double _runGap = AppSpace.s8;
  static const double _minWidth = 56;

  /// 一行放得下几个；放不下时各行尽量排得一样多（5 个排成 3 + 2）。
  int _columnsFor(double width) {
    final fit = ((width + _gap) / (_minWidth + _gap)).floor().clamp(
      1,
      values.length,
    );
    final rows = (values.length / fit).ceil();
    return (values.length / rows).ceil();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(constraints.maxWidth);
        // 向下取到 0.5，避免浮点误差让一行的末项换行。
        final width =
            ((constraints.maxWidth - (columns - 1) * _gap) / columns * 2)
                .floorToDouble() /
            2;
        return Wrap(
          spacing: _gap,
          runSpacing: _runGap,
          children: [
            for (final option in values)
              AppPressable(
                enabled: enabled,
                selected: value == option,
                onTap: () => onChanged(option),
                child: Container(
                  width: width,
                  constraints: const BoxConstraints(minHeight: 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s4,
                    vertical: AppSpace.s8,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == option
                        ? AppColors.ink
                        : AppColors.surfaceSubtle,
                    borderRadius: AppRadius.br8,
                  ),
                  child: Text(
                    labelOf(option),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body14.copyWith(
                      color: value == option
                          ? AppColors.onBrand
                          : AppColors.ink,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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
                    Text(hint!, style: _noteStyle),
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

/// 参数行下面的一句说明：12 号浅灰字（预览侧栏的补充说明）。
final TextStyle _noteStyle = libraryText(
  size: 12,
  color: AppColors.textPlaceholder,
  height: 1.5,
);

/// 面板里的补充说明文字。
class ToolNote extends StatelessWidget {
  const ToolNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: _noteStyle);
}

/// 工具箱统一滑块，取原版「两端加减」滑条的写法：浅紫底圆角 12 的卡片，两端是
/// 减号 / 加号，中间白色轨道上是深浅渐变的进度和带三道握纹的滑钮。尺寸按 320 宽
/// 的侧栏收紧（原版用在整幅宽的页面里：卡片 82 高、轨道 8 高、滑钮 40×32）。
/// 拖动或点按轨道立即跳到对应位置，没有按压光圈与动画。
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
  static const double _thumbWidth = 28;

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
    final usable = width - _thumbWidth;
    if (usable <= 0) {
      return value;
    }
    final t = ((dx - _thumbWidth / 2) / usable).clamp(0.0, 1.0);
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
    void commit(double next) {
      _emit(next);
      onChangeEnd?.call(next);
    }

    final track = Semantics(
      slider: true,
      label: semanticLabel,
      value: _spoken(current),
      increasedValue: _spoken(increased),
      decreasedValue: _spoken(decreased),
      onIncrease: increased > current ? () => commit(increased) : null,
      onDecrease: decreased < current ? () => commit(decreased) : null,
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
                  painter: _SliderPainter(
                    fraction: fraction,
                    thumbWidth: _thumbWidth,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    final label = semanticLabel ?? '数值';
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: LibraryPalette.lilac,
        borderRadius: AppRadius.br12,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Row(
          children: [
            _SliderStepButton(
              icon: Icons.remove_rounded,
              semanticLabel: '减小$label',
              onTap: decreased < current ? () => commit(decreased) : null,
            ),
            const SizedBox(width: AppSpace.s8),
            Expanded(child: track),
            const SizedBox(width: AppSpace.s8),
            _SliderStepButton(
              icon: Icons.add_rounded,
              semanticLabel: '增大$label',
              onTap: increased > current ? () => commit(increased) : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// 滑条两端的减号 / 加号：直接画在浅紫底上，没有底框（原版是 48 见方的图片，
/// 这里的点按范围是 32 见方）。
class _SliderStepButton extends StatelessWidget {
  const _SliderStepButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: semanticLabel,
      excludeFromSemantics: true,
      child: AppPressable(
        onTap: onTap,
        enabled: onTap != null,
        semanticLabel: semanticLabel,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 20, color: AppColors.ink),
        ),
      ),
    );
  }
}

/// 轨道与滑钮的画法取自原版的加减滑条：白色圆头轨道，已选部分从品牌紫渐变到
/// 浅紫，滑钮是品牌紫的圆角矩形，中间三道白色握纹。
class _SliderPainter extends CustomPainter {
  const _SliderPainter({required this.fraction, required this.thumbWidth});

  final double fraction;
  final double thumbWidth;

  static const double _track = 6;
  static const double _thumbHeight = 22;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < thumbWidth) {
      return;
    }
    final y = size.height / 2;
    final x = thumbWidth / 2 + (size.width - thumbWidth) * fraction;
    const radius = Radius.circular(999);
    canvas.drawRRect(
      RRect.fromLTRBR(0, y - _track / 2, size.width, y + _track / 2, radius),
      Paint()..color = AppColors.surface,
    );
    final fill = Rect.fromLTRB(0, y - _track / 2, x, y + _track / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(fill, radius),
      Paint()
        ..shader = const LinearGradient(
          colors: [AppColors.brand, LibraryPalette.trackStart],
        ).createShader(fill),
    );
    final thumb = Rect.fromCenter(
      center: Offset(x, y),
      width: thumbWidth,
      height: _thumbHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(thumb, const Radius.circular(6)),
      Paint()..color = AppColors.brand,
    );
    final grip = Paint()
      ..color = AppColors.onBrand
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final dx in const [-6.0, 0.0, 6.0]) {
      canvas.drawLine(Offset(x + dx, y - 3), Offset(x + dx, y + 3), grip);
    }
  }

  @override
  bool shouldRepaint(covariant _SliderPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.thumbWidth != thumbWidth;
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
      padding: const EdgeInsets.only(bottom: AppSpace.s16),
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
            Text(hint!, style: _noteStyle),
          ],
          const SizedBox(height: AppSpace.s8),
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

/// 说明 / 技巧：预览侧栏的说明块（分区标题下一块浅灰底、圆角 8、内距 20×16，
/// 13 号字行高 26）。
class ToolTipCard extends StatelessWidget {
  const ToolTipCard({required this.title, required this.text, super.key});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LibrarySectionTitle(title),
        const SizedBox(height: AppSpace.s12),
        ToolTextBlock(text),
      ],
    );
  }
}

/// 一段说明文字的浅灰底块，数值同预览页的简介卡。
class ToolTextBlock extends StatelessWidget {
  const ToolTextBlock(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle.withValues(alpha: 0.6),
        borderRadius: AppRadius.br8,
      ),
      child: Text(
        text,
        style: libraryText(size: 13, color: AppColors.ink, height: 2),
      ),
    );
  }
}

/// 面板里的信息块：浅灰底、圆角 12、内距 12（预览侧栏的作者信息块）。
class ToolInfoBlock extends StatelessWidget {
  const ToolInfoBlock({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.s12),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: const BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: AppRadius.br12,
      ),
      child: child,
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
                style: libraryText(size: 12, color: AppColors.textPlaceholder),
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
