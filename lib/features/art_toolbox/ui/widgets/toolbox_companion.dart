import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/toolbox_dock_preferences.dart';
import 'art_companion_portrait.dart';

/// 角色动效是用户明确选择的入口形态；其余画具控件仍沿用即时响应。
/// 无常驻逐帧循环：每隔数秒才播放一次短动作，隐藏、后台和减少动态时停下。
class ToolboxCompanion extends StatefulWidget {
  const ToolboxCompanion({
    required this.edge,
    required this.expanded,
    required this.dragging,
    required this.motionEnabled,
    required this.onTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
    super.key,
  });

  static const extent = 64.0;
  final ToolboxDockEdge edge;
  final bool expanded;
  final bool dragging;
  final bool motionEnabled;
  final VoidCallback onTap;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final GestureDragCancelCallback onDragCancel;

  @override
  State<ToolboxCompanion> createState() => _ToolboxCompanionState();
}

class _ToolboxCompanionState extends State<ToolboxCompanion>
    with SingleTickerProviderStateMixin {
  late final _life = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final AppLifecycleListener _lifecycle;
  final _focusNode = FocusNode(debugLabel: '小墨画具');
  Timer? _halfTimer;
  Timer? _sleepTimer;
  Timer? _gestureTimer;
  int _rest = 0;
  int _cycle = 0;
  bool _peeking = false;
  bool _hover = false;
  bool _focusRing = false;
  bool _foreground = true;
  bool _reduced = false;
  bool _tickerEnabled = true;

  // 指针静止和指针操作留下的焦点都不算持续操作，否则松手后无法收纳。
  bool get _engaged => widget.expanded || widget.dragging || _focusRing;
  bool get _canMove =>
      widget.motionEnabled && !_reduced && _foreground && _tickerEnabled;

  @override
  void initState() {
    super.initState();
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (!mounted) return;
        setState(() => _foreground = state == AppLifecycleState.resumed);
        _resetTimers();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _resetTimers();
  }

  @override
  void didUpdateWidget(covariant ToolboxCompanion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != widget.expanded ||
        oldWidget.dragging != widget.dragging ||
        oldWidget.motionEnabled != widget.motionEnabled ||
        oldWidget.edge != widget.edge) {
      _rest = 0;
      _resetTimers();
    }
  }

  void _resetTimers() {
    _halfTimer?.cancel();
    _sleepTimer?.cancel();
    _gestureTimer?.cancel();
    _life.stop();
    _life.value = 0;
    if (!_foreground || !_tickerEnabled || _engaged) return;
    // 收纳仍然生效；安静模式只取消表情与空间动画，不改变入口用途。
    _halfTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _rest = 1);
    });
    _sleepTimer = Timer(const Duration(seconds: 12), () {
      if (mounted) setState(() => _rest = 2);
    });
    _scheduleGesture();
  }

  void _scheduleGesture() {
    if (!_canMove || _engaged) return;
    _gestureTimer = Timer(const Duration(seconds: 7), () {
      if (!mounted || !_canMove || _engaged) return;
      _peeking = ++_cycle % 3 == 0;
      _life.forward(from: 0);
      _scheduleGesture();
    });
  }

  void _setHover(bool value) {
    setState(() {
      _hover = value;
      if (value) _rest = 0;
    });
    // 收纳会缩小命中区并触发 onExit，离开时不能唤醒或重置计时。
    if (value) _resetTimers();
  }

  void _setFocusHighlight(bool value) {
    if (_focusRing == value) return;
    setState(() {
      _focusRing = value;
      if (value) _rest = 0;
    });
    _resetTimers();
  }

  @override
  void dispose() {
    _halfTimer?.cancel();
    _sleepTimer?.cancel();
    _gestureTimer?.cancel();
    _lifecycle.dispose();
    _life.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = ToolboxCompanion.extent;
    final target = _engaged || _rest == 0
        ? 0.0
        : _rest == 1
        ? 0.5
        : 2 / 3;
    final alignment = switch (widget.edge) {
      ToolboxDockEdge.left => Alignment.centerLeft,
      ToolboxDockEdge.right => Alignment.centerRight,
      ToolboxDockEdge.top => Alignment.topCenter,
      ToolboxDockEdge.bottom => Alignment.bottomCenter,
    };
    final outward = Offset(alignment.x, alignment.y);
    final side =
        widget.edge == ToolboxDockEdge.left ||
        widget.edge == ToolboxDockEdge.right;
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: target),
        duration: _canMove ? const Duration(milliseconds: 200) : Duration.zero,
        curve: Curves.easeOutCubic,
        builder: (context, hiding, _) => AnimatedBuilder(
          animation: _life,
          builder: (context, _) {
            final phase = _canMove ? _life.value : 0.0;
            final pulse = math.sin(phase * math.pi);
            final conceal = math.max(
              0.0,
              hiding - (_peeking ? pulse * 0.12 : 0),
            );
            final blinkPhase = ((phase - 0.12) / 0.22).clamp(0.0, 1.0);
            final blink = math.sin(blinkPhase * math.pi);
            final hitExtent = math.max(44.0, size * (1 - conceal));
            final label = widget.expanded ? '收起画具 · 小墨' : '打开画具 · 小墨';
            return SizedBox.square(
              dimension: size,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRect(
                        child: Transform.translate(
                          offset: outward * (size * conceal),
                          child: Transform.rotate(
                            angle: widget.dragging && _canMove
                                ? -0.09
                                : pulse * 0.025,
                            child: Transform.scale(
                              scale: 1 + pulse * 0.012,
                              child: ArtCompanionPortrait(
                                edge: widget.edge,
                                conceal: conceal,
                                blink: blink,
                                glance: pulse,
                                happy: widget.expanded || _hover,
                                carried: widget.dragging,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: alignment,
                    child: Semantics(
                      button: true,
                      label: label,
                      hint: '轻点展开画具，拖动可换到其他边缘',
                      child: FocusableActionDetector(
                        focusNode: _focusNode,
                        onShowFocusHighlight: _setFocusHighlight,
                        actions: {
                          ActivateIntent: CallbackAction<ActivateIntent>(
                            onInvoke: (_) {
                              widget.onTap();
                              return null;
                            },
                          ),
                          ButtonActivateIntent:
                              CallbackAction<ButtonActivateIntent>(
                                onInvoke: (_) {
                                  widget.onTap();
                                  return null;
                                },
                              ),
                        },
                        child: MouseRegion(
                          cursor: widget.dragging
                              ? SystemMouseCursors.grabbing
                              : SystemMouseCursors.grab,
                          onEnter: (_) => _setHover(true),
                          onExit: (_) => _setHover(false),
                          child: TooltipVisibility(
                            visible: _rest == 0 || _engaged,
                            child: Tooltip(
                              message: '小墨 · 轻点用画具，拖动可贴边',
                              excludeFromSemantics: true,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                dragStartBehavior: DragStartBehavior.down,
                                onPanDown: (_) => _focusNode.unfocus(),
                                onTap: widget.onTap,
                                onPanStart: widget.onDragStart,
                                onPanUpdate: widget.onDragUpdate,
                                onPanEnd: widget.onDragEnd,
                                onPanCancel: widget.onDragCancel,
                                child: Container(
                                  key: const ValueKey(
                                    'floating-toolbox-handle',
                                  ),
                                  width: side ? hitExtent : size,
                                  height: side ? size : hitExtent,
                                  decoration: BoxDecoration(
                                    borderRadius: AppRadius.br12,
                                    border: _focusRing
                                        ? Border.all(
                                            color: AppColors.brandDeep,
                                            width: 2,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
