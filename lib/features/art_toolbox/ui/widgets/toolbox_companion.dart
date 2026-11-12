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
  blink(380),
  look(1800),
  peek(1700),
  dip(2000),
  doodle(2800),
  tap(420),
  plop(820),
  wave(1300);

  const _Act(this.ms);
  final int ms;
}

/// 贴边休息时每 7 秒轮换一段，蘸色与涂鸦穿插在眨眼和张望之间。
const _idleCycle = [
  _Act.blink,
  _Act.look,
  _Act.peek,
  _Act.dip,
  _Act.blink,
  _Act.doodle,
];
const _idleActs = {_Act.blink, _Act.look, _Act.peek, _Act.dip, _Act.doodle};

double _span(double t, double from, double to) =>
    ((t - from) / (to - from)).clamp(0.0, 1.0);

/// 在 [a, b] 升起、[c, d] 落下的平滑包络。
double _bump(double t, double a, double b, double c, double d) => t < b
    ? Curves.easeOut.transform(_span(t, a, b))
    : 1 - Curves.easeIn.transform(_span(t, c, d));

/// 进度走完即归零，表示这一轮效果已结束。
double _once(double progress) => progress >= 1 ? 0 : progress;

/// 角色动效是用户明确选择的入口形态；其余画具控件仍沿用即时响应。
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
    this.paint = 0,
    this.onPaintChanged,
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

  /// 笔尖颜料序号；提供 [onPaintChanged] 时由外部保存，蘸色后回调新序号。
  final int paint;
  final ValueChanged<int>? onPaintChanged;

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
    ..addListener(_onActTick)
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
  Timer? _gazeTimer;
  _Act? _current;
  int _rest = 0;
  int _idleStep = 0;
  int _doodleStep = 0;
  CompanionDoodle _doodle = CompanionDoodle.heart;
  int _dipTarget = 1;
  bool _dipped = false;
  int _ownPaint = 0;
  Offset _gaze = Offset.zero;
  bool _entered = false;
  bool _hover = false;
  bool _focusRing = false;
  bool _foreground = true;
  bool _reduced = false;
  bool _tickerEnabled = true;
  bool _trackingPointer = false;

  // 指针静止和指针操作留下的焦点都不算持续操作，否则松手后无法收纳。
  bool get _engaged => widget.expanded || widget.dragging || _focusRing;
  bool get _canMove =>
      widget.motionEnabled && !_reduced && _foreground && _tickerEnabled;
  int get _paint => widget.onPaintChanged == null ? _ownPaint : widget.paint;

  Offset get _inward => switch (widget.edge) {
    ToolboxDockEdge.left => const Offset(1, 0),
    ToolboxDockEdge.right => const Offset(-1, 0),
    ToolboxDockEdge.top => const Offset(0, 1),
    ToolboxDockEdge.bottom => const Offset(0, -1),
  };

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
    _trackPointer();
  }

  void _trackPointer() {
    if (_trackingPointer) return;
    _trackingPointer = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onGlobalPointer);
  }

  void _untrackPointer() {
    if (!_trackingPointer) return;
    _trackingPointer = false;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onGlobalPointer);
  }

  @override
  void activate() {
    super.activate();
    _trackPointer();
  }

  @override
  void deactivate() {
    _untrackPointer();
    super.deactivate();
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
    return switch (act) {
      // 贴上沿时帽子藏在屏幕外，改为张望。
      _Act.dip when widget.edge == ToolboxDockEdge.top => _Act.look,
      _Act.peek || _Act.doodle when _rest == 0 => _Act.wave,
      _ => act,
    };
  }

  void _play(_Act act) {
    if (!_canMove) return;
    _current = act;
    _dipped = false;
    if (act == _Act.dip) {
      _dipTarget = (_paint + 1) % companionPaints.length;
    }
    if (act == _Act.doodle) {
      _doodle =
          CompanionDoodle.values[_doodleStep++ % CompanionDoodle.values.length];
    }
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
    _gazeTimer?.cancel();
    _gaze = Offset.zero;
    _lean.stop();
    _bounce.stop();
    if (_lean.value != 0) _lean.value = 0;
    if (_bounce.value != 0) _bounce.value = 0;
  }

  void _onActTick() {
    if (_current != _Act.dip || _dipped || _act.value < 0.5) return;
    _dipped = true;
    final onPaintChanged = widget.onPaintChanged;
    if (onPaintChanged == null) {
      setState(() => _ownPaint = _dipTarget);
    } else {
      onPaintChanged(_dipTarget);
    }
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

  /// 点按或悬停在画面任意位置时，小画的眼睛会看过去。
  void _onGlobalPointer(PointerEvent event) {
    if (event is! PointerDownEvent && event is! PointerHoverEvent) return;
    if (!mounted || !_canMove || widget.dragging) return;
    if (context is! Element || !context.mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final delta =
        event.position - box.localToGlobal(box.size.center(Offset.zero));
    final distance = delta.distance;
    if (distance < 8) return;
    final reach = distance / (distance + 120) * 5;
    final gaze = Offset(
      (delta.dx / distance * reach).roundToDouble() / 5,
      (delta.dy / distance * reach).roundToDouble() / 5,
    );
    _gazeTimer?.cancel();
    _gazeTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted && _gaze != Offset.zero) {
        setState(() => _gaze = Offset.zero);
      }
    });
    if (gaze != _gaze) setState(() => _gaze = gaze);
  }

  void _setHover(bool value) {
    setState(() {
      _hover = value;
      if (value) _rest = 0;
    });
    // 收纳会缩小命中区并触发 onExit，离开时不能唤醒或重置计时。
    if (!value) return;
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
    final inward = _inward;
    final along =
        widget.edge == ToolboxDockEdge.left ||
            widget.edge == ToolboxDockEdge.right
        ? const Offset(0, 1)
        : const Offset(1, 0);
    var mood = widget.dragging
        ? CompanionMood.surprised
        : widget.expanded || _hover
        ? CompanionMood.happy
        : CompanionMood.calm;
    var look = _canMove ? _gaze : Offset.zero;
    if (look == Offset.zero && conceal > 0.2) look = inward * 0.5;
    if (widget.expanded) look = inward * 0.7;
    if (widget.dragging) {
      look = Offset((_lean.value * 2.4).clamp(-1.0, 1.0), 0.3);
    }
    var blink = 0.0;
    var peek = 0.0;
    var lift = 0.0;
    var scale = 1.0;
    var wave = 0.0;
    var swing = 0.0;
    var dip = 0.0;
    var dabWobble = 0.0;
    var brushOut = 0.0;
    var stroke = 0.0;
    var markFade = 0.0;
    var sparkle = 0.0;
    switch (act) {
      case null:
        break;
      case _Act.greet:
        final pop = _span(t, 0, 0.3);
        scale = 0.3 + 0.7 * Curves.easeOutBack.transform(pop);
        lift = math.sin(math.pi * pop) * 7;
        wave = _bump(t, 0.26, 0.36, 0.8, 0.92);
        swing = math.sin(_span(t, 0.28, 0.9) * math.pi * 5);
        mood = t < 0.26
            ? CompanionMood.surprised
            : t < 0.82
            ? CompanionMood.joy
            : CompanionMood.happy;
        sparkle = _once(_span(t, 0.12, 0.62));
      case _Act.pop:
        scale = 0.5 + 0.5 * Curves.easeOutBack.transform(_span(t, 0, 0.8));
        mood = CompanionMood.happy;
      case _Act.blink:
        blink = math.sin(math.pi * t);
      case _Act.look:
        // 眼珠像真眼睛一样快速跳到一侧、停一会儿，再跳到另一侧。
        final sweep = t < 0.42
            ? -_span(t, 0, 0.08)
            : t < 0.82
            ? -1 + 2 * _span(t, 0.42, 0.5)
            : 1 - _span(t, 0.82, 0.9);
        look = along * (sweep * 0.9) + inward * 0.35;
        blink = math.sin(math.pi * _span(t, 0.88, 1));
      case _Act.peek:
        peek = _bump(t, 0, 0.22, 0.74, 1);
        wave = _bump(t, 0.14, 0.3, 0.64, 0.8);
        swing = math.sin(_span(t, 0.16, 0.78) * math.pi * 4);
        mood = t > 0.24 && t < 0.72 ? CompanionMood.joy : CompanionMood.happy;
        look = inward * 0.6;
      case _Act.dip:
        peek = _bump(t, 0, 0.2, 0.8, 1) * 0.7;
        dip =
            _bump(t, 0.12, 0.4, 0.6, 0.88) +
            math.sin(_span(t, 0.4, 0.6) * math.pi * 2) * 0.05;
        dabWobble = _span(t, 0.42, 0.74);
        mood = t < 0.62 ? CompanionMood.focus : CompanionMood.happy;
        look = const Offset(0, -1) + inward * 0.3;
        blink = math.sin(math.pi * _span(t, 0.88, 1));
      case _Act.doodle:
        peek = _bump(t, 0, 0.14, 0.86, 1) * 0.8;
        brushOut = _bump(t, 0.06, 0.22, 0.7, 0.86);
        stroke = Curves.easeInOut.transform(_span(t, 0.22, 0.68));
        markFade = _span(t, 0.78, 1);
        mood = t < 0.7
            ? CompanionMood.focus
            : t < 0.88
            ? CompanionMood.joy
            : CompanionMood.happy;
        look = inward * 0.9 + along * 0.2;
      case _Act.tap:
        if (t < 0.85) mood = CompanionMood.joy;
      case _Act.plop:
        mood = t < 0.7 ? CompanionMood.joy : CompanionMood.happy;
        sparkle = _once(_span(t, 0, 0.8));
      case _Act.wave:
        wave = _bump(t, 0, 0.16, 0.78, 1);
        swing = math.sin(_span(t, 0.04, 0.96) * math.pi * 4.4);
        mood = CompanionMood.happy;
    }
    return CompanionPose(
      conceal: conceal,
      peek: peek,
      blink: blink,
      look: look,
      mood: mood,
      squash: _canMove ? _bounce.value.clamp(-0.3, 0.35) : 0,
      tilt: _canMove ? _lean.value.clamp(-0.5, 0.5) : 0,
      lift: lift,
      scale: scale,
      cheer: widget.expanded || widget.dragging ? 1 : 0,
      wave: wave,
      swing: swing,
      dip: dip,
      dipPaint: _dipTarget,
      dabWobble: dabWobble,
      doodle: _doodle,
      brushOut: brushOut,
      stroke: stroke,
      markFade: markFade,
      sparkle: sparkle,
      paint: _paint,
    );
  }

  @override
  void dispose() {
    _untrackPointer();
    _halfTimer?.cancel();
    _sleepTimer?.cancel();
    _idleTimer?.cancel();
    _leanRelax?.cancel();
    _gazeTimer?.cancel();
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
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: target),
        duration: _canMove ? const Duration(milliseconds: 200) : Duration.zero,
        curve: Curves.easeOutCubic,
        builder: (context, conceal, _) => AnimatedBuilder(
          animation: _motion,
          builder: (context, _) {
            final hitExtent = math.max(44.0, size * (1 - conceal));
            final label = widget.expanded ? '收起画具 · 小画' : '打开画具 · 小画';
            return SizedBox.square(
              dimension: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRect(
                        clipper: _EdgeClipper(widget.edge),
                        child: ArtCompanionPortrait(
                          edge: widget.edge,
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

/// 只裁掉屏幕外侧那一边；朝画面内的星光和涂鸦可以溢出入口方块。
class _EdgeClipper extends CustomClipper<Rect> {
  const _EdgeClipper(this.edge);

  final ToolboxDockEdge edge;

  @override
  Rect getClip(Size size) {
    const spill = 40.0;
    return Rect.fromLTRB(
      edge == ToolboxDockEdge.left ? 0 : -spill,
      edge == ToolboxDockEdge.top ? 0 : -spill,
      size.width + (edge == ToolboxDockEdge.right ? 0 : spill),
      size.height + (edge == ToolboxDockEdge.bottom ? 0 : spill),
    );
  }

  @override
  bool shouldReclip(_EdgeClipper oldClipper) => oldClipper.edge != edge;
}
