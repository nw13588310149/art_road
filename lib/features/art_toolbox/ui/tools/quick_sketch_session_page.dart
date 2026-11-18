import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/ui.dart';
import '../../data/toolbox_catalog.dart';
import 'quick_sketch_review.dart';
import 'sketch_session_header.dart';

enum SketchOutcome { completed, skipped, stopped }

class SketchRecord {
  const SketchRecord({
    required this.asset,
    required this.spent,
    required this.outcome,
  });

  final String asset;
  final Duration spent;
  final SketchOutcome outcome;
}

/// 最后几秒提醒换下一张。
const _warnSeconds = 5;

String _clockText(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

String sketchDurationText(Duration duration) =>
    _clockText((duration.inMilliseconds / 1000).round());

/// 全屏速写计时：大图参考 + 环形倒计时，最后 5 秒红框提醒；结束后回顾每张实际用时。
///
/// 沉浸页（设计语言第九节）：白色顶栏，下面是中性灰画布上的参考图，画布下一行
/// 是计时与进度、暂停 / 继续、跳过与结束。
class QuickSketchSessionPage extends StatefulWidget {
  const QuickSketchSessionPage({
    required this.pool,
    required this.count,
    required this.interval,
    required this.setLabel,
    super.key,
  });

  final List<String> pool;
  final int count;
  final Duration interval;
  final String setLabel;

  @override
  State<QuickSketchSessionPage> createState() => _QuickSketchSessionPageState();
}

class _QuickSketchSessionPageState extends State<QuickSketchSessionPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: widget.interval)
        ..addListener(_handleTick)
        ..addStatusListener(_handleStatus);
  final ValueNotifier<int> _remaining = ValueNotifier<int>(0);
  final List<SketchRecord> _records = <SketchRecord>[];
  List<String> _sequence = const <String>[];
  int _index = 0;
  bool _paused = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  @override
  void dispose() {
    _clock.dispose();
    _remaining.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 全局工作台收起后暂停练习，重新展开由用户决定何时继续。
    if (!TickerMode.valuesOf(context).enabled && _clock.isAnimating) {
      _clock.stop();
      _paused = true;
    }
  }

  void _begin() {
    _sequence = buildSketchSequence(widget.pool, widget.count);
    _records.clear();
    _index = 0;
    _paused = false;
    _finished = _sequence.isEmpty;
    _remaining.value = widget.interval.inSeconds;
    if (!_finished) {
      _clock.forward(from: 0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _precacheNext());
    }
  }

  void _precacheNext() {
    final next = _index + 1;
    if (mounted && next < _sequence.length) {
      precacheImage(AssetImage(_sequence[next]), context);
    }
  }

  int _secondsLeft() =>
      ((1 - _clock.value) * widget.interval.inMilliseconds / 1000).ceil();

  void _handleTick() {
    final left = _secondsLeft();
    if (left == _remaining.value) {
      return;
    }
    _remaining.value = left;
    if (left > 0 && left <= _warnSeconds) {
      HapticFeedback.selectionClick();
    }
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_finished) {
      _next(SketchOutcome.completed);
    }
  }

  Duration get _spent => widget.interval * _clock.value;

  void _next(SketchOutcome outcome) {
    _records.add(
      SketchRecord(asset: _sequence[_index], spent: _spent, outcome: outcome),
    );
    if (_index + 1 >= _sequence.length) {
      _finish();
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _index++;
      _paused = false;
    });
    _remaining.value = widget.interval.inSeconds;
    _clock.forward(from: 0);
    _precacheNext();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _clock.stop();
    } else {
      _clock.forward();
    }
  }

  void _stop() {
    if (_finished) {
      return;
    }
    if (_clock.value > 0) {
      _records.add(
        SketchRecord(
          asset: _sequence[_index],
          spent: _spent,
          outcome: SketchOutcome.stopped,
        ),
      );
    }
    _finish();
  }

  void _finish() {
    _clock.stop();
    HapticFeedback.heavyImpact();
    setState(() => _finished = true);
  }

  void _restart() => setState(_begin);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _finished,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _stop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: _finished
              ? SketchReview(
                  records: _records,
                  total: _sequence.length,
                  interval: widget.interval,
                  setLabel: widget.setLabel,
                  onRestart: _restart,
                  onClose: () => Navigator.of(context).maybePop(),
                )
              : _buildSession(),
        ),
      ),
    );
  }

  Widget _buildSession() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SessionHeader(
          title: ArtTool.quickSketch.label,
          caption:
              '${widget.setLabel} · 每张 ${sketchIntervalLabel(widget.interval.inSeconds)}',
          onBack: _stop,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 短横屏把上下留白让给参考图。
              final compact = constraints.maxHeight < 560;
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpace.s24,
                  compact ? AppSpace.s12 : AppSpace.s24,
                  AppSpace.s24,
                  compact ? AppSpace.s12 : AppSpace.s24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildReference()),
                    SizedBox(height: compact ? AppSpace.s12 : AppSpace.s16),
                    _buildControls(),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReference() {
    final asset = _sequence[_index];
    return ValueListenableBuilder<int>(
      valueListenable: _remaining,
      builder: (context, left, child) {
        final warn = !_paused && left <= _warnSeconds;
        return DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: AppCanvasLayout.radius,
            border: warn ? Border.all(color: AppColors.danger, width: 3) : null,
          ),
          child: child,
        );
      },
      child: ClipRRect(
        borderRadius: AppCanvasLayout.radius,
        child: ColoredBox(
          color: AppColors.canvas,
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s16),
                  child: Image.asset(
                    asset,
                    key: ValueKey('$_index-$asset'),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                  ),
                ),
              ),
              if (_paused)
                Positioned.fill(
                  child: AppPressable(
                    onTap: _togglePause,
                    semanticLabel: '继续',
                    child: ColoredBox(
                      color: AppColors.ink.withValues(alpha: 0.6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.pause_circle_outline_rounded,
                            color: AppColors.onBrand,
                            size: 56,
                          ),
                          const SizedBox(height: AppSpace.s8),
                          Text(
                            '已暂停，点击继续',
                            style: AppText.body16.copyWith(
                              color: AppColors.onBrand,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 画布下面一行：左边倒计时与进度，中间暂停 / 继续（唯一的主按钮），右边跳过与结束。
  Widget _buildControls() {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              _CountdownRing(
                clock: _clock,
                remaining: _remaining,
                interval: widget.interval,
                paused: _paused,
                size: 72,
              ),
              const SizedBox(width: AppSpace.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '第 ', style: AppText.body14),
                          TextSpan(
                            text: '${_index + 1}',
                            style: AppText.number(size: 16),
                          ),
                          TextSpan(
                            text: ' / ${_sequence.length} 张',
                            style: AppText.body14,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.s8),
                    _ProgressDots(total: _sequence.length, current: _index),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpace.s12),
        AppButton(
          label: _paused ? '继续' : '暂停',
          icon: _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          onTap: _togglePause,
        ),
        const SizedBox(width: AppSpace.s12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppPlainButton(
                label: '跳过',
                icon: Icons.skip_next_rounded,
                onTap: () => _next(SketchOutcome.skipped),
              ),
              AppPlainButton(
                label: '结束',
                icon: Icons.stop_rounded,
                onTap: _stop,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CountdownRing extends StatelessWidget {
  const _CountdownRing({
    required this.clock,
    required this.remaining,
    required this.interval,
    required this.paused,
    required this.size,
  });

  final Animation<double> clock;
  final ValueListenable<int> remaining;
  final Duration interval;
  final bool paused;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _RingPainter(
              clock: clock,
              interval: interval,
              strokeWidth: 5,
            ),
          ),
          Center(
            child: ValueListenableBuilder<int>(
              valueListenable: remaining,
              builder: (context, left, _) {
                final warn = !paused && left <= _warnSeconds;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _clockText(left),
                      style: AppText.displayNumber(
                        size: 20,
                        color: warn ? AppColors.danger : AppColors.ink,
                      ),
                    ),
                    Text(
                      paused ? '已暂停' : (warn ? '即将换图' : '剩余'),
                      style: AppText.caption12.copyWith(
                        color: warn ? AppColors.danger : AppColors.textTertiary,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.clock,
    required this.interval,
    required this.strokeWidth,
  }) : super(repaint: clock);

  final Animation<double> clock;
  final Duration interval;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    canvas.drawOval(
      rect,
      Paint()
        ..color = AppColors.lineSoft
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
    final left = 1 - clock.value;
    if (left <= 0) {
      return;
    }
    final warn = left * interval.inMilliseconds <= _warnSeconds * 1000;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * left,
      false,
      Paint()
        ..color = warn ? AppColors.danger : AppColors.brand
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.clock != clock ||
      oldDelegate.interval != interval ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// 进度点：画过的深灰，当前这张墨色加长，没画的浅灰。
class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.total, required this.current});

  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        for (var i = 0; i < total; i++)
          Container(
            width: i == current ? 16 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i < current
                  ? AppColors.textTertiary
                  : (i == current ? AppColors.ink : AppColors.line),
              borderRadius: AppRadius.brPill,
            ),
          ),
      ],
    );
  }
}
