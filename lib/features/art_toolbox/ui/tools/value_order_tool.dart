import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../data/toolbox_catalog.dart';
import '../../data/value_order_records.dart';
import '../../logic/value_order_game.dart';
import '../../state/value_order_controller.dart';
import '../widgets/image_tool_frame.dart';
import '../widgets/tool_panel.dart';

/// 明度排序训练：7–9 块打乱的灰色，从暗到亮排好；检查时标出放错的位置，并保存个人纪录。
class ValueOrderTool extends ConsumerStatefulWidget {
  const ValueOrderTool({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  ConsumerState<ValueOrderTool> createState() => _ValueOrderToolState();
}

class _ValueOrderToolState extends ConsumerState<ValueOrderTool> {
  int _count = valueOrderCounts.first;
  ValueOrderLevel _level = ValueOrderLevel.standard;
  late ValueOrderGame _game = ValueOrderGame.deal(count: _count, level: _level);
  int? _selected;
  Set<int> _wrong = <int>{};
  bool _solved = false;
  int _checks = 0;
  bool _newRecord = false;
  final Stopwatch _watch = Stopwatch();
  Timer? _ticker;
  final ValueNotifier<int> _elapsed = ValueNotifier<int>(0);

  @override
  void dispose() {
    _ticker?.cancel();
    _elapsed.dispose();
    super.dispose();
  }

  void _deal() {
    _ticker?.cancel();
    _ticker = null;
    _watch
      ..stop()
      ..reset();
    _elapsed.value = 0;
    setState(() {
      _game = ValueOrderGame.deal(count: _count, level: _level);
      _selected = null;
      _wrong = <int>{};
      _solved = false;
      _checks = 0;
      _newRecord = false;
    });
  }

  /// 第一次操作时开始计时。
  void _touch() {
    if (_watch.isRunning || _solved) {
      return;
    }
    _watch.start();
    _ticker = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _elapsed.value = _watch.elapsedMilliseconds,
    );
  }

  void _tap(int index) {
    if (_solved) {
      return;
    }
    _touch();
    final selected = _selected;
    HapticFeedback.selectionClick();
    setState(() {
      if (selected == null) {
        _selected = index;
      } else if (selected == index) {
        _selected = null;
      } else {
        _game.swap(selected, index);
        _selected = null;
        _wrong = <int>{};
      }
    });
  }

  void _drop(int from, int to) {
    if (_solved || from == to) {
      return;
    }
    _touch();
    setState(() {
      _game.move(from, to);
      _selected = null;
      _wrong = <int>{};
    });
  }

  Future<void> _check() async {
    _touch();
    final mistakes = _game.mistakes();
    if (mistakes.isNotEmpty) {
      HapticFeedback.mediumImpact();
      setState(() {
        _checks++;
        _wrong = mistakes.toSet();
        _selected = null;
      });
      return;
    }
    _watch.stop();
    _ticker?.cancel();
    final millis = _watch.elapsedMilliseconds;
    _elapsed.value = millis;
    setState(() {
      _checks++;
      _solved = true;
      _wrong = <int>{};
      _selected = null;
    });
    final best = await ref
        .read(valueOrderRecordsProvider.notifier)
        .submit(_count, _level, millis);
    if (mounted && best) {
      setState(() => _newRecord = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolPageScaffold(
      tool: ArtTool.valueOrder,
      onBack: widget.onBack,
      caption: '${_game.length} 块 · ${_level.label}',
      actions: [
        AppPlainButton(label: '换一组', icon: Icons.refresh_rounded, onTap: _deal),
        AppButton(
          label: _solved ? '已完成' : '检查顺序',
          icon: Icons.check_rounded,
          onTap: _solved ? null : _check,
        ),
      ],
      body: ImageToolLayout(
        hint: '点两个色块交换位置，或按住一个拖到目标位置；左边放深的，右边放浅的',
        stage: (_) => Center(
          child: SingleChildScrollView(
            primary: false,
            padding: const EdgeInsets.all(AppSpace.s24),
            child: _buildGame(),
          ),
        ),
        panel: (_) => _buildPanel(),
      ),
    );
  }

  /// 画布里的一局：用时、色块、暗到亮的标尺和检查结果。
  Widget _buildGame() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: Text('从暗到亮排列', style: AppText.title16)),
            Text('用时 ', style: AppText.caption12),
            ValueListenableBuilder<int>(
              valueListenable: _elapsed,
              builder: (context, millis, _) => Text(
                formatValueOrderTime(millis),
                style: AppText.displayNumber(
                  size: 24,
                  color: _solved ? AppColors.brand : AppColors.ink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s16),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = AppSpace.s8;
            final width =
                (constraints.maxWidth - gap * (_game.length - 1)) /
                _game.length;
            return Row(
              children: [
                for (var i = 0; i < _game.length; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  _buildSlot(i, width),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: AppSpace.s8),
        Row(
          children: [
            Text('暗', style: AppText.caption12),
            const SizedBox(width: AppSpace.s8),
            Expanded(
              child: Container(
                height: 4,
                decoration: const BoxDecoration(
                  borderRadius: AppRadius.brPill,
                  gradient: LinearGradient(
                    colors: [AppColors.ink, AppColors.line],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            Text('亮', style: AppText.caption12),
          ],
        ),
        if (_solved || _wrong.isNotEmpty) const SizedBox(height: AppSpace.s24),
        if (_solved)
          ToolNotice(
            '全部排对了，用时 ${formatValueOrderTime(_elapsed.value)}，检查了 $_checks 次'
            '${_newRecord ? '，刷新了这一档的个人纪录' : ''}。色块下方的数字是各自的明度。',
            tone: AppTone.success,
          )
        else if (_wrong.isNotEmpty)
          ToolNotice(
            '有 ${_wrong.length} 块位置不对，已用红框和 × 标出，调整后再检查',
            tone: AppTone.danger,
          ),
      ],
    );
  }

  Widget _buildSlot(int index, double width) {
    final grey = _game.levels[index];
    final tile = _Swatch(
      grey: grey,
      width: width,
      selected: _selected == index,
      wrong: _wrong.contains(index),
      valueLabel: _solved ? '${(grey * 100 / 255).round()}' : null,
    );
    return Column(
      children: [
        DragTarget<int>(
          onWillAcceptWithDetails: (details) =>
              !_solved && details.data != index,
          onAcceptWithDetails: (details) => _drop(details.data, index),
          builder: (context, candidates, _) => Draggable<int>(
            data: index,
            maxSimultaneousDrags: _solved ? 0 : 1,
            onDragStarted: _touch,
            feedback: _Swatch(grey: grey, width: width, dragging: true),
            childWhenDragging: _SwatchPlaceholder(width: width),
            child: AppPressable(
              onTap: () => _tap(index),
              selected: _selected == index,
              semanticLabel: '第 ${index + 1} 块灰色',
              child: candidates.isEmpty
                  ? tile
                  : Stack(
                      children: [
                        tile,
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: AppRadius.br8,
                              border: Border.all(
                                color: AppColors.ink,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s4),
        Text(
          '${index + 1}',
          style: AppText.number(size: 12, color: AppColors.textTertiary),
        ),
      ],
    );
  }

  Widget _buildPanel() {
    final records = ref.watch(valueOrderRecordsProvider);
    final best = records[ValueOrderRecordRepository.keyOf(_count, _level)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToolPanelSection(
          title: '色块数',
          child: ToolSegmented<int>(
            values: valueOrderCounts,
            value: _count,
            labelOf: (n) => '$n 块',
            onChanged: (n) {
              _count = n;
              _deal();
            },
          ),
        ),
        ToolPanelSection(
          title: '难度',
          note: _level.description,
          bottom: AppSpace.s12,
          child: ToolSegmented<ValueOrderLevel>(
            values: ValueOrderLevel.values,
            value: _level,
            labelOf: (l) => l.label,
            onChanged: (l) {
              _level = l;
              _deal();
            },
          ),
        ),
        const AppRule(),
        AppStatRow(
          label: '个人纪录',
          caption: '$_count 块 · ${_level.label} · 只保存在本机',
          value: best == null ? '—' : formatValueOrderTime(best),
        ),
        const AppRule(),
        const SizedBox(height: AppSpace.s24),
        const ToolTipCard(
          title: '为什么练明度',
          text:
              '素描和色彩都离不开明度判断。把相近的灰色排好顺序，能提高对明暗层次的敏感度；'
              '色彩写生时同样要分得清不同颜色的明度高低。细腻档的灰色集中在中间调，更接近画面里真实的灰。',
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.grey,
    required this.width,
    this.selected = false,
    this.wrong = false,
    this.dragging = false,
    this.valueLabel,
  });

  final int grey;
  final double width;
  final bool selected;
  final bool wrong;
  final bool dragging;
  final String? valueLabel;

  static const double height = 160;

  @override
  Widget build(BuildContext context) {
    final color = Color.fromARGB(255, grey, grey, grey);
    final onColor = grey > 140 ? AppColors.ink : AppColors.onBrand;
    final Color borderColor;
    final double borderWidth;
    if (wrong) {
      borderColor = AppColors.danger;
      borderWidth = 3;
    } else if (selected || dragging) {
      borderColor = AppColors.ink;
      borderWidth = 3;
    } else {
      borderColor = AppColors.line;
      borderWidth = 1;
    }
    final label = valueLabel;
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: AppRadius.br8,
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Stack(
          children: [
            if (wrong)
              Positioned(
                top: AppSpace.s4,
                right: AppSpace.s4,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: AppColors.onBrand,
                  ),
                ),
              ),
            if (selected)
              Positioned(
                left: 0,
                right: 0,
                bottom: AppSpace.s8,
                child: Text(
                  '已选',
                  textAlign: TextAlign.center,
                  style: AppText.caption12Strong.copyWith(color: onColor),
                ),
              ),
            if (label != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: AppSpace.s8,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppText.number(size: 13, color: onColor),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SwatchPlaceholder extends StatelessWidget {
  const _SwatchPlaceholder({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: _Swatch.height,
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: AppRadius.br8,
        border: Border.all(color: AppColors.line),
      ),
    );
  }
}
