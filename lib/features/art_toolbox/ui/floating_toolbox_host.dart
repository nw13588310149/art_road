import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../data/toolbox_catalog.dart';
import '../state/toolbox_dock_controller.dart';
import '../state/page_tools_controller.dart';
import '../state/companion_controller.dart';
import '../state/toolbox_image_controller.dart';
import 'art_toolbox_page.dart';
import 'toolbox_route_observer.dart';
import 'widgets/art_companion_portrait.dart';
import 'widgets/companion_paint_trail.dart';
import 'widgets/toolbox_companion.dart';
import 'widgets/page_tools_drawer.dart';
import 'widgets/page_tool_overlay.dart';

/// 挂在 MaterialApp.builder：业务导航与工具导航并列，收起不销毁工作台。
class FloatingToolboxHost extends ConsumerStatefulWidget {
  const FloatingToolboxHost({
    required this.observer,
    required this.child,
    super.key,
  });

  final ToolboxRouteObserver observer;
  final Widget child;

  @override
  ConsumerState<FloatingToolboxHost> createState() =>
      _FloatingToolboxHostState();
}

class _FloatingToolboxHostState extends ConsumerState<FloatingToolboxHost> {
  static const _extent = ToolboxCompanion.extent;
  final _pageCapture = GlobalKey();
  int _sampleVersion = 0;
  final _workspaceNavigator = GlobalKey<NavigatorState>();
  final _trail = GlobalKey<CompanionPaintTrailState>();
  final _selection = ValueNotifier<ArtTool?>(null);
  LocalHistoryEntry? _history;
  bool _panelOpen = false;
  bool _workspaceOpen = false;
  bool _workspaceCreated = false;
  bool _greeted = false;
  bool _greetScheduled = false;
  int _paint = 0;
  Offset? _dragPosition;
  ModalRoute<dynamic>? _lastPage;

  @override
  void initState() {
    super.initState();
    widget.observer.changes.addListener(_routeChanged);
  }

  void _routeChanged() {
    if (!mounted) return;
    final pageChanged = _lastPage != widget.observer.page;
    _lastPage = widget.observer.page;
    if (pageChanged || !widget.observer.inSession) {
      _sampleVersion++;
      ref.read(pageToolsProvider.notifier).end();
    }
    if (!widget.observer.inSession) ref.invalidate(pageToolsProvider);
    if (!widget.observer.inSession ||
        pageChanged ||
        !widget.observer.unobstructed) {
      _close();
    }
    setState(() {
      if (!widget.observer.inSession) {
        _workspaceCreated = false;
        _selection.value = null;
        _greeted = false;
        _paint = 0;
      }
      if (!widget.observer.unobstructed) _panelOpen = false;
    });
  }

  void _attachHistory() {
    if (_history != null) return;
    _history = LocalHistoryEntry(
      onRemove: () {
        _history = null;
        if (mounted) {
          setState(() {
            _panelOpen = false;
            _workspaceOpen = false;
          });
        }
      },
    );
    widget.observer.page?.addLocalHistoryEntry(_history!);
  }

  void _close() {
    if (!_panelOpen && !_workspaceOpen && _history == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final history = _history;
    _history = null;
    history?.remove();
    setState(() {
      _panelOpen = false;
      _workspaceOpen = false;
    });
  }

  void _togglePanel() {
    if (_panelOpen) {
      _close();
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
      _attachHistory();
      setState(() => _panelOpen = true);
    }
  }

  void _openTool(ArtTool? tool, {bool resume = false}) {
    _attachHistory();
    if (!resume) {
      _workspaceNavigator.currentState?.popUntil((route) => route.isFirst);
      _selection.value = tool;
    }
    setState(() {
      _workspaceCreated = true;
      _panelOpen = false;
      _workspaceOpen = true;
    });
  }

  Future<void> _sampleColor(Offset position) async {
    final version = ++_sampleVersion;
    ui.Image? image;
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || ref.read(pageToolsProvider).tool != ArtTool.color) return;
      final boundary =
          _pageCapture.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (!mounted ||
          version != _sampleVersion ||
          ref.read(pageToolsProvider).tool != ArtTool.color ||
          data == null) {
        return;
      }
      final x = position.dx.floor().clamp(0, image.width - 1);
      final y = position.dy.floor().clamp(0, image.height - 1);
      final offset = (y * image.width + x) * 4;
      ref
          .read(pageToolsProvider.notifier)
          .sample(
            Color.fromARGB(
              255,
              data.getUint8(offset),
              data.getUint8(offset + 1),
              data.getUint8(offset + 2),
            ),
          );
    } catch (_) {
      if (mounted) {
        AppToast.showError(
          _pageCapture.currentContext ?? context,
          '暂时无法读取页面颜色，请稍后再试',
        );
      }
    } finally {
      image?.dispose();
    }
  }

  Future<void> _escape() async {
    if (_workspaceOpen &&
        await (_workspaceNavigator.currentState?.maybePop() ??
            Future.value(false))) {
      return;
    }
    if (mounted) _close();
  }

  @override
  void dispose() {
    widget.observer.changes.removeListener(_routeChanged);
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inSession = widget.observer.inSession;
    // 会话级监听让路由切换和收起后的原图继续可用；退出登录后自动释放。
    if (inSession) ref.watch(toolboxImageControllerProvider);
    final pageTools = ref.watch(pageToolsProvider);
    final dock = ref.watch(toolboxDockControllerProvider);
    final motionEnabled = ref.watch(companionMotionProvider);
    final media = MediaQuery.of(context);
    final paintTrail = motionEnabled && !media.disableAnimations;
    void trace(Offset position) {
      if (!paintTrail) return;
      _trail.currentState?.add(
        position + const Offset(_extent / 2, _extent / 2),
        companionPaints[_paint % companionPaints.length],
      );
    }

    return Overlay.wrap(
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (_workspaceOpen) {
              _escape();
            } else if (_panelOpen) {
              _close();
            } else {
              ref.read(pageToolsProvider.notifier).end();
            }
          },
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final left = media.padding.left;
            final top = media.padding.top;
            final bounds = Rect.fromLTRB(
              left,
              top,
              math.max(
                left,
                constraints.maxWidth - media.padding.right - _extent,
              ),
              math.max(
                top,
                constraints.maxHeight -
                    math.max(media.padding.bottom, media.viewInsets.bottom) -
                    _extent,
              ),
            );
            final point = ToolboxDockGeometry.clamp(
              _dragPosition ?? ToolboxDockGeometry.resolve(dock, bounds),
              bounds,
            );
            final panelWidth = math.min(
              360.0,
              constraints.maxWidth < 700
                  ? constraints.maxWidth - 16
                  : constraints.maxWidth * .48,
            );
            final pageToolVisible =
                inSession && widget.observer.unobstructed && !_workspaceOpen;
            final effect = pageToolVisible && !pageTools.original;
            final showLauncher =
                inSession && widget.observer.unobstructed && !_workspaceOpen;
            if (showLauncher && !_greeted && !_greetScheduled) {
              _greetScheduled = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _greetScheduled = false;
                if (mounted) _greeted = true;
              });
            }
            return Stack(
              children: [
                ExcludeFocus(
                  excluding: _workspaceOpen,
                  child: ExcludeSemantics(
                    excluding: _workspaceOpen,
                    child: RepaintBoundary(
                      key: _pageCapture,
                      child: ColorFiltered(
                        colorFilter: ColorFilter.matrix(
                          effect && pageTools.tool == ArtTool.value
                              ? pageGrayscaleMatrix
                              : pageIdentityMatrix,
                        ),
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.diagonal3Values(
                            effect &&
                                    pageTools.tool == ArtTool.mirror &&
                                    pageTools.mirrorX
                                ? -1
                                : 1,
                            effect &&
                                    pageTools.tool == ArtTool.mirror &&
                                    pageTools.mirrorY
                                ? -1
                                : 1,
                            1,
                          ),
                          child: Semantics(
                            container: true,
                            explicitChildNodes: true,
                            child: widget.child,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_workspaceCreated && inSession)
                  Positioned.fill(
                    child: Offstage(
                      offstage: !_workspaceOpen,
                      child: TickerMode(
                        enabled: _workspaceOpen,
                        child: ExcludeFocus(
                          excluding: !_workspaceOpen,
                          child: CallbackShortcuts(
                            bindings: {
                              const SingleActivator(LogicalKeyboardKey.escape):
                                  _escape,
                            },
                            child: FocusScope(
                              child: Material(
                                color: AppColors.page,
                                child: SafeArea(
                                  child: Column(
                                    // 导航先绘制，页头后绘制，避免路由遮断收起按钮的语义。
                                    verticalDirection: VerticalDirection.up,
                                    children: [
                                      Expanded(
                                        child: HeroControllerScope.none(
                                          child: Navigator(
                                            key: _workspaceNavigator,
                                            onGenerateRoute: (_) =>
                                                MaterialPageRoute<void>(
                                                  builder: (_) =>
                                                      ValueListenableBuilder<
                                                        ArtTool?
                                                      >(
                                                        valueListenable:
                                                            _selection,
                                                        builder: (_, tool, _) =>
                                                            ArtToolboxPage(
                                                              embedded: true,
                                                              initialTool: tool,
                                                              onToolChanged:
                                                                  (tool) =>
                                                                      _selection
                                                                              .value =
                                                                          tool,
                                                            ),
                                                      ),
                                                ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          20,
                                          8,
                                          12,
                                          8,
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.draw_outlined,
                                              size: 20,
                                              color: AppColors.brand,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '画室工具箱',
                                              style: AppText.title16,
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Text(
                                                '收起后可继续使用当前画作',
                                                style: AppText.caption12
                                                    .copyWith(
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            AppButton(
                                              label: '收起工具',
                                              icon: Icons
                                                  .close_fullscreen_rounded,
                                              variant:
                                                  AppButtonVariant.secondary,
                                              onTap: _close,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (pageToolVisible && pageTools.tool != null)
                  Positioned.fill(
                    child: PageToolOverlay(onSample: _sampleColor),
                  ),
                if (pageToolVisible && pageTools.tool != null && !_panelOpen)
                  Positioned(
                    bottom: media.padding.bottom + 16,
                    left: 16,
                    child: Semantics(
                      container: true,
                      explicitChildNodes: true,
                      child: Material(
                        color: AppColors.surface,
                        borderRadius: AppRadius.br12,
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                pageTools.tool!.icon,
                                size: 18,
                                color: AppColors.brand,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                pageTools.tool == ArtTool.quickSketch
                                    ? '速写 ${pageTools.clock}${pageTools.seconds == 0 ? " · 已结束" : ""}'
                                    : pageTools.tool == ArtTool.color
                                    ? pageTools.hex
                                    : pageTools.tool!.label,
                                style: AppText.body14,
                              ),
                              AppButton(
                                label: '调整',
                                onTap: _togglePanel,
                                variant: AppButtonVariant.text,
                                size: AppButtonSize.sm,
                              ),
                              AppIconButton(
                                icon: Icons.close_rounded,
                                semanticLabel: '结束当前页面工具',
                                filled: false,
                                onTap: ref.read(pageToolsProvider.notifier).end,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_panelOpen && showLauncher)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: media.viewInsets.bottom,
                    width: panelWidth,
                    child: CallbackShortcuts(
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.escape):
                            _close,
                      },
                      child: FocusScope(
                        autofocus: true,
                        child: Semantics(
                          container: true,
                          explicitChildNodes: true,
                          child: PageToolsDrawer(
                            paint: _paint,
                            onClose: _close,
                            onAllTools: () {
                              ref.read(pageToolsProvider.notifier).end();
                              _openTool(null);
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                if (showLauncher && !_panelOpen) ...[
                  Positioned.fill(child: CompanionPaintTrail(key: _trail)),
                  Positioned(
                    left: point.dx,
                    top: point.dy,
                    width: _extent,
                    height: _extent,
                    child: Semantics(
                      container: true,
                      explicitChildNodes: true,
                      child: ToolboxCompanion(
                        edge: dock.edge,
                        expanded: _panelOpen,
                        dragging: _dragPosition != null,
                        motionEnabled: motionEnabled,
                        greet: !_greeted,
                        paint: _paint,
                        onPaintChanged: (paint) {
                          if (_paint == paint) return;
                          setState(() => _paint = paint);
                        },
                        onTap: _togglePanel,
                        onDragStart: (_) {
                          _close();
                          trace(point);
                          setState(() => _dragPosition = point);
                        },
                        onDragUpdate: (event) {
                          final next = ToolboxDockGeometry.clamp(
                            (_dragPosition ?? point) + event.delta,
                            bounds,
                          );
                          trace(next);
                          setState(() => _dragPosition = next);
                        },
                        onDragEnd: (_) {
                          ref
                              .read(toolboxDockControllerProvider.notifier)
                              .dock(_dragPosition ?? point, bounds);
                          setState(() => _dragPosition = null);
                        },
                        onDragCancel: () =>
                            setState(() => _dragPosition = null),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
