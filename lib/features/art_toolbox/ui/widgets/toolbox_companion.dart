import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../../core/ui/ui.dart';
import '../../data/toolbox_dock_preferences.dart';
import 'art_companion_portrait.dart';

/// 小画的一段短表演，数值为时长（毫秒）。
enum _Act {
  greet(1800),
  pop(520),
  nod(700),
  look(1800),
  peek(1700),
  tap(420),
  plop(820),
  wave(1300);

  const _Act(this.ms);
  final int ms;
}

/// 贴边休息时每 7 秒轮换一段：点头、歪头张望、探出来晃一晃。
const _idleCycle = [
  _Act.nod,
  _Act.look,
  _Act.peek,
  _Act.nod,
  _Act.wave,
  _Act.peek,
];
const _idleActs = {_Act.nod, _Act.look, _Act.peek, _Act.wave};

double _span(double t, double from, double to) =>
    ((t - from) / (to - from)).clamp(0.0, 1.0);

/// 在 [a, b] 升起、[c, d] 落下的平滑包络。
double _bump(double t, double a, double b, double c, double d) => t < b
    ? Curves.easeOut.transform(_span(t, a, b))
    : 1 - Curves.easeIn.transform(_span(t, c, d));

/// 进度走完即归零，表示这一轮效果已结束。
double _once(double progress) => progress >= 1 ? 0 : progress;

/// 画具入口「小画」：一只戴眼镜的猫头鹰，轻点展开工具栏，拖动可换边停靠。
///
/// 角色动效是用户明确选择的入口形态；其余画具控件仍沿用即时响应。
/// 形象是一整张图，动作都是整体的点头、摇晃、探身和弹跳。
/// 没有常驻逐帧循环：每隔数秒才演一段短动作，弹簧回弹停稳即释放帧；
/// 隐藏、后台、关闭精灵动态和系统减少动态时全部停下。
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
    this.greet = false,
    this.edgeInset = 0,
    this.semanticLabel,
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

  /// 本次会话第一次出现时完整打招呼，之后重新出现只轻轻弹出。
  final bool greet;

  /// 64 点方框到屏幕真实边缘的距离。组件在停靠的那一侧多占这么宽，
  /// 休息时小画一直退到屏幕边上，而不是在离边几点的地方被切断。
  final double edgeInset;
  final String? semanticLabel;

  @override
  State<ToolboxCompanion> createState() => _ToolboxCompanionState();
}

class _ToolboxCompanionState extends State<ToolboxCompanion>
    with TickerProviderStateMixin {
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 13,
  );

  late final _act = AnimationController(vsync: this)
    ..addStatusListener(_onActStatus);
  late final _lean = AnimationController.unbounded(vsync: this);
  late final _bounce = AnimationController.unbounded(vsync: this);
  late final _motion = Listenable.merge([_act, _lean, _bounce]);
  late final AppLifecycleListener _lifecycle;
  final _focusNode = FocusNode(debugLabel: '小画画具');
  Timer? _halfTimer;
  Timer? _sleepTimer;
  Timer? _idleTimer;
  Timer? _leanRelax;
  _Act? _current;
  int _rest = 0;
  int _idleStep = 0;
  bool _entered = false;
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
    if (!_entered) {
      _entered = true;
      _play(widget.greet ? _Act.greet : _Act.pop);
    }
    _resetTimers();
  }

  @override
  void didUpdateWidget(covariant ToolboxCompanion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dragging != widget.dragging) {
      if (widget.dragging) {
        _stopAct();
        _springTo(_bounce, -0.08);
      } else {
        _leanRelax?.cancel();
        _springTo(_lean, 0);
        _springTo(_bounce, 0, 3.2);
        _play(_Act.plop);
      }
    }
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
    _idleTimer?.cancel();
    if (!_canMove) _stopMotion();
    if (!_foreground || !_tickerEnabled || _engaged) {
      if (_idleActs.contains(_current)) _stopAct();
      return;
    }
    // 收纳仍然生效；安静模式只取消表情与空间动画，不改变入口用途。
    _halfTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _rest = 1);
    });
    _sleepTimer = Timer(const Duration(seconds: 12), () {
      if (mounted) setState(() => _rest = 2);
    });
    _scheduleIdle();
  }

  void _scheduleIdle() {
    _idleTimer?.cancel();
    if (!_canMove || _engaged) return;
    _idleTimer = Timer(const Duration(seconds: 7), () {
      if (!mounted || !_canMove || _engaged) return;
      _play(_nextIdle());
      _scheduleIdle();
    });
  }

  _Act _nextIdle() {
    final act = _idleCycle[_idleStep++ % _idleCycle.length];
    // 还完整站在外面时没有可探的身子，改成晃一晃。
    return act == _Act.peek && _rest == 0 ? _Act.wave : act;
  }

  void _play(_Act act) {
    if (!_canMove) return;
    _current = act;
    _act.duration = Duration(milliseconds: act.ms);
    _act.forward(from: 0);
  }

  void _stopAct() {
    _current = null;
    _act.stop();
    _act.value = 0;
  }

  void _stopMotion() {
    _stopAct();
    _leanRelax?.cancel();
    _lean.stop();
    _bounce.stop();
    if (_lean.value != 0) _lean.value = 0;
    if (_bounce.value != 0) _bounce.value = 0;
  }

  void _onActStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _current = null);
    }
  }

  void _springTo(AnimationController controller, double target, [double? v]) {
    if (!_canMove) {
      if (controller.value != 0) controller.value = 0;
      return;
    }
    controller.animateWith(
      SpringSimulation(
        _spring,
        controller.value,
        target,
        v ?? controller.velocity,
      ),
    );
  }

  void _handleTap() {
    _springTo(_bounce, 0, 2.6);
    _play(_Act.tap);
    widget.onTap();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    widget.onDragUpdate(details);
    if (!_canMove) return;
    // 拎着走时身体朝运动方向甩、沿速度拉长，停手后回弹。
    _springTo(_lean, (details.delta.dx * 0.05).clamp(-0.42, 0.42));
    _springTo(
      _bounce,
      -(0.08 + math.min(0.14, details.delta.distance * 0.008)),
    );
    _leanRelax?.cancel();
    _leanRelax = Timer(const Duration(milliseconds: 110), () {
      if (!mounted || !widget.dragging) return;
      _springTo(_lean, 0);
      _springTo(_bounce, -0.08);
    });
  }

  void _setHover(bool value) {
    // 收纳会缩小命中区并触发 onExit，离开时不能唤醒或重置计时。
    if (!value) return;
    setState(() => _rest = 0);
    if (_idleActs.contains(_current)) _stopAct();
    _resetTimers();
    if (!_engaged && _current == null) _play(_Act.wave);
  }

  void _setFocusHighlight(bool value) {
    if (_focusRing == value) return;
    setState(() {
      _focusRing = value;
      if (value) _rest = 0;
    });
    _resetTimers();
  }

  CompanionPose _pose(double conceal) {
    final act = _canMove ? _current : null;
    final t = _act.value;
    var peek = 0.0;
    var nod = 0.0;
    var sway = 0.0;
    var lift = 0.0;
    var scale = 1.0;
    var sparkle = 0.0;
    switch (act) {
      case null:
        break;
      case _Act.greet:
        // 弹出来、跳一下，再左右晃着打招呼。
        final pop = _span(t, 0, 0.3);
        scale = 0.3 + 0.7 * Curves.easeOutBack.transform(pop);
        lift = math.sin(math.pi * pop) * 7;
        sway =
            _bump(t, 0.26, 0.36, 0.8, 0.92) *
            math.sin(_span(t, 0.28, 0.9) * math.pi * 5);
        sparkle = _once(_span(t, 0.12, 0.62));
      case _Act.pop:
        scale = 0.5 + 0.5 * Curves.easeOutBack.transform(_span(t, 0, 0.8));
      case _Act.nod:
        nod = math.sin(math.pi * t);
      case _Act.look:
        // 歪向一侧停一会儿，再歪向另一侧，最后回正。
        final lean = t < 0.42
            ? -Curves.easeInOut.transform(_span(t, 0, 0.16))
            : t < 0.82
            ? -1 + 2 * Curves.easeInOut.transform(_span(t, 0.42, 0.58))
            : 1 - Curves.easeInOut.transform(_span(t, 0.82, 1));
        sway = lean * 0.55;
      case _Act.peek:
        peek = _bump(t, 0, 0.22, 0.74, 1);
        sway =
            _bump(t, 0.14, 0.3, 0.64, 0.8) *
            math.sin(_span(t, 0.16, 0.78) * math.pi * 4) *
            0.8;
      case _Act.tap:
        nod = math.sin(math.pi * t) * 0.8;
      case _Act.plop:
        sparkle = _once(_span(t, 0, 0.8));
      case _Act.wave:
        sway =
            _bump(t, 0, 0.16, 0.78, 1) *
            math.sin(_span(t, 0.04, 0.96) * math.pi * 4.4);
    }
    return CompanionPose(
      conceal: conceal,
      peek: peek,
      nod: nod,
      sway: sway,
      squash: _canMove ? _bounce.value.clamp(-0.3, 0.35) : 0,
      tilt: _canMove ? _lean.value.clamp(-0.5, 0.5) : 0,
      lift: lift,
      scale: scale,
      sparkle: sparkle,
    );
  }

  @override
  void dispose() {
    _halfTimer?.cancel();
    _sleepTimer?.cancel();
    _idleTimer?.cancel();
    _leanRelax?.cancel();
    _lifecycle.dispose();
    _act.dispose();
    _lean.dispose();
    _bounce.dispose();
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
    final side =
        widget.edge == ToolboxDockEdge.left ||
        widget.edge == ToolboxDockEdge.right;
    final inset = math.max(0.0, widget.edgeInset);
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: target),
        duration: _canMove ? const Duration(milliseconds: 200) : Duration.zero,
        curve: Curves.easeOutCubic,
        builder: (context, conceal, _) => AnimatedBuilder(
          animation: _motion,
          builder: (context, _) {
            final hitExtent = math.max(44.0, size * (1 - conceal)) + inset;
            final label =
                widget.semanticLabel ??
                (widget.expanded ? '收起画具 · 小画' : '打开画具 · 小画');
            return SizedBox(
              width: side ? size + inset : size,
              height: side ? size : size + inset,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 形象的方框贴着画面内侧，多出来的一条留给屏幕边缘。
                  Align(
                    alignment: -alignment,
                    child: IgnorePointer(
                      child: ClipRect(
                        clipper: _EdgeClipper(widget.edge, inset),
                        child: ArtCompanionPortrait(
                          edge: widget.edge,
                          edgeInset: inset,
                          pose: _pose(conceal),
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
                              _handleTap();
                              return null;
                            },
                          ),
                          ButtonActivateIntent:
                              CallbackAction<ButtonActivateIntent>(
                                onInvoke: (_) {
                                  _handleTap();
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
                              message: '小画 · 轻点用画具，拖动可贴边',
                              excludeFromSemantics: true,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                dragStartBehavior: DragStartBehavior.down,
                                onPanDown: (_) => _focusNode.unfocus(),
                                onTapDown: (_) => _play(_Act.tap),
                                onTap: _handleTap,
                                onPanStart: widget.onDragStart,
                                onPanUpdate: _handleDragUpdate,
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

/// 只在屏幕边缘那一侧裁切（方框外再让出 [inset]）；朝画面内的星光可以
/// 溢出入口方块。
class _EdgeClipper extends CustomClipper<Rect> {
  const _EdgeClipper(this.edge, this.inset);

  final ToolboxDockEdge edge;
  final double inset;

  @override
  Rect getClip(Size size) {
    const spill = 40.0;
    return Rect.fromLTRB(
      edge == ToolboxDockEdge.left ? -inset : -spill,
      edge == ToolboxDockEdge.top ? -inset : -spill,
      size.width + (edge == ToolboxDockEdge.right ? inset : spill),
      size.height + (edge == ToolboxDockEdge.bottom ? inset : spill),
    );
  }

  @override
  bool shouldReclip(_EdgeClipper oldClipper) =>
      oldClipper.edge != edge || oldClipper.inset != inset;
}
