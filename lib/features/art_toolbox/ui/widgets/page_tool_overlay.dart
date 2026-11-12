import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/ui/ui.dart';
import '../../data/toolbox_catalog.dart';
import '../../state/page_tools_controller.dart';

/// 页面的绘制与命中坐标始终相同；抽屉不改变页面大小。
class PageToolOverlay extends ConsumerWidget {
  const PageToolOverlay({required this.onSample, super.key});
  final ValueChanged<Offset> onSample;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pageToolsProvider);
    if (state.original) return const SizedBox.shrink();
    if (state.tool == ArtTool.color) {
      return MouseRegion(
        cursor: SystemMouseCursors.precise,
        child: GestureDetector(
          key: const ValueKey('page-color-sampler'),
          behavior: HitTestBehavior.opaque,
          onTapDown: (event) => onSample(event.localPosition),
          child: const SizedBox.expand(),
        ),
      );
    }
    if (state.tool != ArtTool.grid && state.tool != ArtTool.measure) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  key: const ValueKey('page-tool-lines'),
                  painter: _LinesPainter(state),
                ),
              ),
            ),
            if (state.tool == ArtTool.measure)
              for (var i = 0; i < state.points.length; i++)
                Positioned(
                  left: state.points[i].dx * size.width - 24,
                  top: state.points[i].dy * size.height - 24,
                  width: 48,
                  height: 48,
                  child: Semantics(
                    label: '测量端点 ${i + 1}',
                    onIncrease: () => ref
                        .read(pageToolsProvider.notifier)
                        .movePoint(i, state.points[i] + const Offset(.01, 0)),
                    onDecrease: () => ref
                        .read(pageToolsProvider.notifier)
                        .movePoint(i, state.points[i] - const Offset(.01, 0)),
                    child: GestureDetector(
                      key: ValueKey('measure-point-$i'),
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (event) => ref
                          .read(pageToolsProvider.notifier)
                          .movePoint(
                            i,
                            ref.read(pageToolsProvider).points[i] +
                                Offset(
                                  event.delta.dx / size.width,
                                  event.delta.dy / size.height,
                                ),
                          ),
                      child: Center(
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: i < 2 ? AppColors.brand : AppColors.ink,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                        ),
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

class _LinesPainter extends CustomPainter {
  _LinesPainter(this.state);
  final PageToolsState state;
  @override
  void paint(Canvas canvas, Size size) {
    if (state.tool == ArtTool.grid) {
      final paint = Paint()
        ..color = (state.lightLines ? Colors.white : AppColors.ink).withValues(
          alpha: state.opacity,
        )
        ..strokeWidth = 1;
      for (var i = 1; i < state.grid; i++) {
        canvas.drawLine(
          Offset(size.width * i / state.grid, 0),
          Offset(size.width * i / state.grid, size.height),
          paint,
        );
        canvas.drawLine(
          Offset(0, size.height * i / state.grid),
          Offset(size.width, size.height * i / state.grid),
          paint,
        );
      }
    } else {
      for (var i = 0; i < 4; i += 2) {
        final a = Offset(
          state.points[i].dx * size.width,
          state.points[i].dy * size.height,
        );
        final b = Offset(
          state.points[i + 1].dx * size.width,
          state.points[i + 1].dy * size.height,
        );
        canvas.drawLine(
          a,
          b,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 5,
        );
        canvas.drawLine(
          a,
          b,
          Paint()
            ..color = i == 0 ? AppColors.brand : AppColors.ink
            ..strokeWidth = 2,
        );
        final length = (b - a).distance;
        final angle = math.atan2((b - a).dy, (b - a).dx) * 180 / math.pi;
        final text = TextPainter(
          text: TextSpan(
            text:
                '${i == 0 ? 'A' : 'B'}  ${length.toStringAsFixed(0)} px · ${angle.toStringAsFixed(0)}°',
            style: AppText.caption12.copyWith(
              color: AppColors.ink,
              backgroundColor: Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, (a + b) / 2 - Offset(text.width / 2, 24));
      }
    }
  }

  @override
  bool shouldRepaint(_LinesPainter oldDelegate) => oldDelegate.state != state;
}

const pageGrayscaleMatrix = <double>[
  .2126,
  .7152,
  .0722,
  0,
  0,
  .2126,
  .7152,
  .0722,
  0,
  0,
  .2126,
  .7152,
  .0722,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];
const pageIdentityMatrix = <double>[
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];
