import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_font.dart';
import '../../../../core/ui/ui.dart';
import '../../../gallery/ui/widgets/library_controls.dart';
import '../../data/toolbox_catalog.dart';
import '../widgets/image_tool_frame.dart';
import '../widgets/tool_panel.dart';

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

String _durationText(Duration duration) =>
    _clockText((duration.inMilliseconds / 1000).round());

/// 全屏速写计时：大图参考 + 环形倒计时，最后 5 秒红框提醒；结束后回顾每张实际用时。
///
/// 版式取自原版的录制详情：56 高的工具栏（返回、居中标题）、全幅画面、底部三段
/// 操作栏（左侧计时与进度、中间暂停 / 继续、右侧跳过与结束）。
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToolDetailHeader(
          title: ArtTool.quickSketch.label,
          subtitle:
              '${widget.setLabel} · 每张 ${sketchIntervalLabel(widget.interval.inSeconds)}',
          onBack: _stop,
          prominent: true,
          // 右侧留出与返回按钮等宽的位置，标题保持居中（原版录制详情的写法）。
          actions: const [SizedBox(width: LibraryIconButton.extent)],
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 原版录制详情的正文：四周 20（上 25），画面左右再收 8、上收 8，
              // 底部操作栏左右收 22、距底 40。短横屏（原版同样以 560 为界）不再
              // 额外收上边和底边，把高度让给参考图。
              final compact = constraints.maxHeight < 560;
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 25, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(8, compact ? 0 : 8, 8, 0),
                        child: _buildReference(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Padding(
                      padding: EdgeInsets.fromLTRB(22, 0, 22, compact ? 0 : 40),
                      child: _buildControls(),
                    ),
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
            borderRadius: LibraryCanvas.radius,
            border: warn ? Border.all(color: AppColors.danger, width: 3) : null,
          ),
          child: child,
        );
      },
      child: ToolStage(
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
    );
  }

  /// 底部三段操作栏：左侧倒计时与进度，中间暂停 / 继续，右侧跳过与结束。
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
                size: 84,
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '第 ${_index + 1} / ${_sequence.length} 张',
                      style: AppText.body14Strong,
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
              LibraryIconButton(
                icon: Icons.skip_next_rounded,
                semanticLabel: '跳过',
                onTap: () => _next(SketchOutcome.skipped),
              ),
              const SizedBox(width: AppSpace.s8),
              LibraryIconButton(
                icon: Icons.stop_rounded,
                semanticLabel: '结束',
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
              strokeWidth: size * 0.07,
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
                      paused ? '已暂停' : (warn ? '即将换图' : '剩余时间'),
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
        ..color = AppColors.line
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
          Container(
            width: i == current ? 16 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i < current
                  ? AppColors.brandSoft
                  : (i == current ? AppColors.brand : AppColors.line),
              borderRadius: AppRadius.brPill,
            ),
          ),
      ],
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
        ToolDetailHeader(
          title: '练习回顾',
          subtitle: '$setLabel · 每张 ${sketchIntervalLabel(interval.inSeconds)}',
          prominent: true,
          actions: [
            LibraryActionPill(
              label: '完成',
              icon: Icons.check_rounded,
              iconSize: 18,
              onTap: onClose,
            ),
            LibraryActionPill(
              label: '再练一组',
              icon: Icons.replay_rounded,
              iconSize: 18,
              primary: true,
              onTap: onRestart,
            ),
          ],
        ),
        // 正文左右 20、上 25，与练习页（原版录制详情的正文）一致。
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 25, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: AppStatTile(
                  label: '按时完成',
                  value: '$completed',
                  unit: '/ $total 张',
                  boxed: true,
                ),
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: AppStatTile(
                  label: '实际总用时',
                  value: _durationText(totalTime),
                  boxed: true,
                ),
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: AppStatTile(
                  label: '平均每张',
                  value: _durationText(average),
                  boxed: true,
                ),
              ),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: AppStatTile(
                  label: '跳过 / 提前结束',
                  value: '${records.length - completed}',
                  unit: '张',
                  boxed: true,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: records.isEmpty
              ? const AppEmptyState(
                  title: '这一组还没有开始画',
                  description: '点「再练一组」重新开始计时',
                  icon: Icons.timer_outlined,
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  // 列缝与行缝 16，同原版的图片卡网格。
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 190,
                    mainAxisSpacing: AppSpace.s16,
                    crossAxisSpacing: AppSpace.s16,
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

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.index, required this.record});

  final int index;
  final SketchRecord record;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (record.outcome) {
      SketchOutcome.completed => ('按时完成', AppTone.success),
      SketchOutcome.skipped => ('跳过', AppTone.warning),
      SketchOutcome.stopped => ('提前结束', AppTone.neutral),
    };
    // 图片卡取原版视频网格卡的外观：浅灰底、圆角 12、标题 13 号中等字重。
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: AppRadius.br12,
      ),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: libraryText(
                          size: 13,
                          weight: AppFont.w500,
                          color: AppColors.ink,
                          height: 1.3,
                        ),
                      ),
                    ),
                    Text(
                      _durationText(record.spent),
                      style: AppText.number(size: 13),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s4),
                AppStatusTag(label: label, tone: tone),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
