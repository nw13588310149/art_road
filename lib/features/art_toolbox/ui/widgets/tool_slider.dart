import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';

/// 工具箱的滑条：两端是减一格 / 加一格（44 见方的图标操作），中间一条细轨道，
/// 已选部分墨色，白色圆钮。滑条是控件的状态，不用品牌紫。
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

  static const double _height = 44;
  static const double _thumb = 20;

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
                  painter: _SliderPainter(fraction: fraction, thumb: _thumb),
                ),
              ),
            ),
          );
        },
      ),
    );
    final label = semanticLabel ?? '数值';
    return Row(
      children: [
        _StepButton(
          icon: Icons.remove_rounded,
          semanticLabel: '减小$label',
          alignment: Alignment.centerLeft,
          onTap: decreased < current ? () => commit(decreased) : null,
        ),
        Expanded(child: track),
        _StepButton(
          icon: Icons.add_rounded,
          semanticLabel: '增大$label',
          alignment: Alignment.centerRight,
          onTap: increased > current ? () => commit(increased) : null,
        ),
      ],
    );
  }
}

/// 减一格 / 加一格：点击区域 44 见方，图标贴着外侧，和上面的名称、数值对齐。
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.semanticLabel,
    required this.alignment,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final Alignment alignment;
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
          width: 44,
          height: 44,
          child: Align(
            alignment: alignment,
            child: Icon(
              icon,
              size: 18,
              color: onTap == null ? AppColors.textPlaceholder : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// 轨道 4 高、圆头；已选部分墨色；圆钮白底、细描边、一层很淡的投影。
class _SliderPainter extends CustomPainter {
  const _SliderPainter({required this.fraction, required this.thumb});

  final double fraction;
  final double thumb;

  static const double _track = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < thumb) {
      return;
    }
    final y = size.height / 2;
    final x = thumb / 2 + (size.width - thumb) * fraction;
    const radius = Radius.circular(999);
    canvas
      ..drawRRect(
        RRect.fromLTRBR(0, y - _track / 2, size.width, y + _track / 2, radius),
        Paint()..color = AppColors.line,
      )
      ..drawRRect(
        RRect.fromLTRBR(0, y - _track / 2, x, y + _track / 2, radius),
        Paint()..color = AppColors.ink,
      )
      ..drawCircle(
        Offset(x, y + 1),
        thumb / 2,
        Paint()
          ..color = AppColors.ink.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      )
      ..drawCircle(Offset(x, y), thumb / 2, Paint()..color = AppColors.surface)
      ..drawCircle(
        Offset(x, y),
        thumb / 2 - 0.5,
        Paint()
          ..color = AppColors.line
          ..style = PaintingStyle.stroke,
      );
  }

  @override
  bool shouldRepaint(covariant _SliderPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.thumb != thumb;
}
