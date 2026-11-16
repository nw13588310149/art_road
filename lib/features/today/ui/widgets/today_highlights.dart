import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/today_models.dart';
import '../today_style.dart';

/// 头图下面的一排数字卡：这个身份今天最该知道的四个数。
///
/// 每张卡一个图标、一个大数字和一句说明，点开直达对应的地方。数字旁边按数据
/// 画一个小图：有比例的画进度环，有近几天数值的画一排小柱子。
class TodayHighlights extends StatelessWidget {
  const TodayHighlights({required this.items, required this.onOpen, super.key});

  final List<TodayHighlight> items;
  final ValueChanged<TodayAction> onOpen;

  @override
  Widget build(BuildContext context) {
    final shown = items.take(4).toList();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpace.s12),
            Expanded(
              child: _Tile(item: shown[i], onOpen: onOpen),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item, required this.onOpen});

  final TodayHighlight item;
  final ValueChanged<TodayAction> onOpen;

  @override
  Widget build(BuildContext context) {
    final tint = TodayTint.parse(item.tone);
    final ratio = item.ratio;
    final action = item.action;
    final Widget? visual = item.trend.length >= 2
        ? _Spark(values: item.trend, tint: tint)
        : (ratio == null ? null : _Ring(ratio: ratio, tint: tint));
    final tile = Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.br16,
        border: Border.all(color: AppColors.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              TodayIconChip(icon: todayIcon(item.icon), tint: tint, size: 32),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body13,
                ),
              ),
              if (action != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.textPlaceholder,
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          SizedBox(
            height: 40,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: item.value,
                          style: AppText.displayNumber(size: 32),
                        ),
                        if (item.unit.isNotEmpty)
                          TextSpan(
                            text: item.unit == '%'
                                ? item.unit
                                : ' ${item.unit}',
                            style: AppText.body13,
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (visual != null) ...[
                  const SizedBox(width: AppSpace.s8),
                  visual,
                ],
              ],
            ),
          ),
          if (item.caption.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s4),
            Text(
              item.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption12,
            ),
          ],
        ],
      ),
    );
    final label = [
      item.label,
      '${item.value} ${item.unit}'.trim(),
      if (ratio != null) '进度 ${(ratio * 100).round()}%',
      item.caption,
    ].where((t) => t.isNotEmpty).join('，');
    if (action == null) {
      return Semantics(
        container: true,
        label: label,
        child: ExcludeSemantics(child: tile),
      );
    }
    return AppPressable(
      onTap: () => onOpen(action),
      semanticLabel: label,
      child: ExcludeSemantics(child: tile),
    );
  }
}

/// 数字旁边的进度环。满了以后中间打一个勾。
class _Ring extends StatelessWidget {
  const _Ring({required this.ratio, required this.tint});

  final double ratio;
  final TodayTint tint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: CustomPaint(
        painter: _RingPainter(
          ratio: ratio,
          color: tint.color,
          // 比图标底色深一档，进度是 0 的时候也看得出这是一个环。
          track: tint.color.withValues(alpha: 0.16),
        ),
        child: ratio >= 1
            ? Icon(Icons.check_rounded, size: 18, color: tint.color)
            : null,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.ratio,
    required this.color,
    required this.track,
  });

  final double ratio;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (ratio <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * ratio.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.ratio != ratio ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}

/// 数字旁边的一排小柱子：近几天的数，最后一根是今天，颜色最深。
class _Spark extends StatelessWidget {
  const _Spark({required this.values, required this.tint});

  final List<double> values;
  final TodayTint tint;

  @override
  Widget build(BuildContext context) {
    final shown = values.length > 7
        ? values.sublist(values.length - 7)
        : values;
    return SizedBox(
      width: shown.length * 6 + (shown.length - 1) * 3,
      height: 30,
      child: CustomPaint(
        painter: _SparkPainter(values: shown, color: tint.color),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final high = values.fold<double>(0, math.max);
    const width = 6.0;
    const gap = 3.0;
    for (var i = 0; i < values.length; i++) {
      // 没有数的那天留一个 2px 的底，看得出这一天在。
      final height = high <= 0
          ? 2.0
          : math.max(2.0, size.height * values[i] / high);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(i * (width + gap), size.height - height, width, height),
        topLeft: const Radius.circular(2),
        topRight: const Radius.circular(2),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = i == values.length - 1
              ? color
              : color.withValues(alpha: 0.32),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.values != values;
}
