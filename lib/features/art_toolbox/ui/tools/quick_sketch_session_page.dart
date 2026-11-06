import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/theme/app_font.dart';
import '../../data/toolbox_catalog.dart';

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

const _background = Color(0xFF121117);
const _surface = Color(0xFF1D1B24);
const _accent = Color(0xFF4CC38A);
const _warning = Color(0xFFFF5D6C);

String _clockText(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

String _durationText(Duration duration) =>
    _clockText((duration.inMilliseconds / 1000).round());

/// 全屏速写计时：大图参考 + 环形倒计时，最后 5 秒高亮提醒；结束后回顾每张实际用时。
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
    if (left > 0 && left <= 5) {
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
        backgroundColor: _background,
        body: SafeArea(
          child: _finished
              ? _SketchReview(
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final landscape =
            constraints.maxWidth >= constraints.maxHeight &&
            constraints.maxWidth >= 700;
        final reference = _buildReference();
        if (landscape) {
          return Row(
            children: [
              Expanded(child: reference),
              SizedBox(width: 300, child: _buildSidePanel()),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: reference),
            _buildBottomBar(),
          ],
        );
      },
    );
  }

  Widget _buildReference() {
    final asset = _sequence[_index];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ValueListenableBuilder<int>(
        valueListenable: _remaining,
        builder: (context, left, child) {
          final warn = !_paused && left <= 5;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: warn ? _warning : Colors.transparent,
                width: 3,
              ),
              boxShadow: warn
                  ? [
                      BoxShadow(
                        color: _warning.withValues(alpha: 0.35),
                        blurRadius: 24,
                      ),
                    ]
                  : null,
            ),
            child: child,
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: Image.asset(
                      asset,
                      key: ValueKey('$_index-$asset'),
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                top: 14,
                child: _DarkChip(
                  '第 ${_index + 1} / ${_sequence.length} 张 · ${widget.setLabel}',
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: _RoundButton(
                  icon: Icons.close_rounded,
                  tooltip: '结束练习',
                  size: 38,
                  onTap: _stop,
                ),
              ),
              if (_paused)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _togglePause,
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.pause_circle_outline_rounded,
                            color: Colors.white,
                            size: 56,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '已暂停，点击继续',
                            style: ArtText.body(color: Colors.white),
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

  Widget _buildSidePanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('速写计时练习', style: ArtText.title(size: 17, color: Colors.white)),
            const SizedBox(height: 4),
            Text(
              '每张 ${sketchIntervalLabel(widget.interval.inSeconds)} · 共 ${_sequence.length} 张',
              style: ArtText.caption(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const Spacer(),
            Center(
              child: _CountdownRing(
                clock: _clock,
                remaining: _remaining,
                interval: widget.interval,
                paused: _paused,
                size: 176,
              ),
            ),
            const SizedBox(height: 18),
            _ProgressDots(total: _sequence.length, current: _index),
            const Spacer(),
            _SessionButton(
              icon: _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              label: _paused ? '继续' : '暂停',
              primary: true,
              onTap: _togglePause,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _SessionButton(
                    icon: Icons.skip_next_rounded,
                    label: '跳过',
                    onTap: () => _next(SketchOutcome.skipped),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SessionButton(
                    icon: Icons.stop_rounded,
                    label: '结束',
                    onTap: _stop,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            _CountdownRing(
              clock: _clock,
              remaining: _remaining,
              interval: widget.interval,
              paused: _paused,
              size: 84,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '第 ${_index + 1} / ${_sequence.length} 张',
                    style: ArtText.body(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  _ProgressDots(total: _sequence.length, current: _index),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _RoundButton(
              icon: _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              tooltip: _paused ? '继续' : '暂停',
              highlighted: true,
              onTap: _togglePause,
            ),
            const SizedBox(width: 8),
            _RoundButton(
              icon: Icons.skip_next_rounded,
              tooltip: '跳过',
              onTap: () => _next(SketchOutcome.skipped),
            ),
            const SizedBox(width: 8),
            _RoundButton(icon: Icons.stop_rounded, tooltip: '结束', onTap: _stop),
          ],
        ),
      ),
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
              strokeWidth: size * 0.07,
            ),
          ),
          Center(
            child: ValueListenableBuilder<int>(
              valueListenable: remaining,
              builder: (context, left, _) {
                final warn = !paused && left <= 5;
                final text = Text(
                  _clockText(left),
                  style: ArtText.number(
                    size: size * 0.22,
                    color: warn ? _warning : Colors.white,
                  ),
                );
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (warn)
                      TweenAnimationBuilder<double>(
                        key: ValueKey(left),
                        tween: Tween<double>(begin: 1.25, end: 1),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                        builder: (context, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: text,
                      )
                    else
                      text,
                    if (size >= 120) ...[
                      const SizedBox(height: 4),
                      Text(
                        paused ? '已暂停' : (warn ? '准备换下一张' : '剩余时间'),
                        style: ArtText.caption(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
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
        ..color = Colors.white.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
    final left = 1 - clock.value;
    if (left <= 0) {
      return;
    }
    final warn = left * interval.inMilliseconds <= 5000;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * left,
      false,
      Paint()
        ..color = warn ? _warning : _accent
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

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.total, required this.current});

  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: i == current ? 16 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i < current
                  ? _accent
                  : (i == current
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

class _DarkChip extends StatelessWidget {
  const _DarkChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: ArtText.caption(color: Colors.white)),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.highlighted = false,
    this.size = 46,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool highlighted;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: highlighted ? _accent : Colors.white.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: size * 0.5),
        ),
      ),
    );
  }
}

class _SessionButton extends StatelessWidget {
  const _SessionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: primary ? _accent : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(23),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                height: 1.2,
                color: Colors.white,
                fontWeight: AppFont.w500,
                fontFamily: 'PingFang SC',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SketchReview extends StatelessWidget {
  const _SketchReview({
    required this.records,
    required this.total,
    required this.interval,
    required this.setLabel,
    required this.onRestart,
    required this.onClose,
  });

  final List<SketchRecord> records;
  final int total;
  final Duration interval;
  final String setLabel;
  final VoidCallback onRestart;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final totalTime = records.fold<Duration>(
      Duration.zero,
      (sum, r) => sum + r.spent,
    );
    final completed = records
        .where((r) => r.outcome == SketchOutcome.completed)
        .length;
    final average = records.isEmpty
        ? Duration.zero
        : totalTime ~/ records.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '练习回顾',
                      style: ArtText.title(size: 20, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$setLabel · 每张 ${sketchIntervalLabel(interval.inSeconds)}',
                      style: ArtText.caption(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              _SessionButton(
                icon: Icons.replay_rounded,
                label: '再练一组',
                primary: true,
                onTap: onRestart,
              ),
              const SizedBox(width: 10),
              _SessionButton(
                icon: Icons.check_rounded,
                label: '完成',
                onTap: onClose,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ReviewStat(label: '按时完成', value: '$completed / $total 张'),
              _ReviewStat(label: '实际总用时', value: _durationText(totalTime)),
              _ReviewStat(label: '平均每张', value: _durationText(average)),
              _ReviewStat(
                label: '跳过 / 提前结束',
                value: '${records.length - completed} 张',
              ),
            ],
          ),
        ),
        Expanded(
          child: records.isEmpty
              ? Center(
                  child: Text(
                    '这一组还没有开始画',
                    style: ArtText.body(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 190,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: records.length,
                  itemBuilder: (context, index) =>
                      _RecordTile(index: index, record: records[index]),
                ),
        ),
      ],
    );
  }
}

class _ReviewStat extends StatelessWidget {
  const _ReviewStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: ArtText.caption(color: Colors.white.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 6),
          Text(value, style: ArtText.number(size: 20, color: Colors.white)),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.index, required this.record});

  final int index;
  final SketchRecord record;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (record.outcome) {
      SketchOutcome.completed => ('按时完成', _accent),
      SketchOutcome.skipped => ('跳过', const Color(0xFFF2B33D)),
      SketchOutcome.stopped => ('提前结束', Colors.white.withValues(alpha: 0.6)),
    };
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Image.asset(
              record.asset,
              fit: BoxFit.cover,
              cacheWidth: 400,
              filterQuality: FilterQuality.medium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '第 ${index + 1} 张',
                        style: ArtText.body(size: 13, color: Colors.white),
                      ),
                    ),
                    Text(
                      _durationText(record.spent),
                      style: ArtText.number(size: 14, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(label, style: ArtText.caption(size: 11, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
