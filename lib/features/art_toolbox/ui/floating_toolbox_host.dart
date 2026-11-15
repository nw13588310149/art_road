import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ui/ui.dart';
import '../../../app/router/route_paths.dart';
import '../../my_notes/state/my_notes_controller.dart';
import '../../my_notes/state/my_notes_state.dart';
import '../data/toolbox_catalog.dart';
import '../state/toolbox_dock_controller.dart';
import '../state/page_tools_controller.dart';
import '../state/toolbox_image_controller.dart';
import '../state/companion_controller.dart';
import 'art_toolbox_page.dart';
import 'toolbox_route_observer.dart';
import 'widgets/page_tools_drawer.dart';
import 'widgets/page_tool_overlay.dart';
import 'widgets/professional_tool_rail.dart';
import 'widgets/toolbox_companion.dart';
import 'widgets/art_companion_portrait.dart';
import 'widgets/companion_paint_trail.dart';

/// 业务页面与工具工作台分开保留，参数关闭不结束当前工具。
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

class _FloatingToolboxHostState extends ConsumerState<FloatingToolboxHost>
    with WidgetsBindingObserver {
  final _pageCapture = GlobalKey();
  final _toolFocus = FocusNode(debugLabel: 'Page tools');
  final _trail = GlobalKey<CompanionPaintTrailState>();
  bool _greeted = false;
  int _paint = 0;
  int _sampleVersion = 0;
  final _workspaceNavigator = GlobalKey<NavigatorState>();
  final _selection = ValueNotifier<ArtTool?>(null);
  LocalHistoryEntry? _history;
  bool _panelOpen = false, _railExpanded = false;
  bool _workspaceOpen = false, _workspaceCreated = false;
  Offset? _dragPosition;
  ModalRoute<dynamic>? _lastPage;

  @override
  void initState() {
    super.initState();
    widget.observer.changes.addListener(_routeChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      ref.read(pageToolsProvider.notifier).pause();
    }
  }

  void _routeChanged() {
    if (!mounted) return;
    final changed = _lastPage != widget.observer.page;
    _lastPage = widget.observer.page;
    if (changed) _railExpanded = false;
    if (changed || !widget.observer.inSession) {
      _sampleVersion++;
      ref.read(pageToolsProvider.notifier).end();
    }
    if (!widget.observer.inSession) ref.invalidate(pageToolsProvider);
    if (!widget.observer.inSession ||
        changed ||
        !widget.observer.unobstructed) {
      _close();
    }
    setState(() {
      if (!widget.observer.inSession) {
        _workspaceCreated = false;
        _selection.value = null;
      }
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
    FocusManager.instance.primaryFocus?.unfocus();
    final history = _history;
    _history = null;
    history?.remove();
    if (mounted) {
      setState(() {
        _panelOpen = false;
        _workspaceOpen = false;
      });
    }
  }

  void _options() {
    if (_panelOpen) {
      _close();
      return;
    }
    _attachHistory();
    setState(() => _panelOpen = true);
  }

  void _select(ArtTool tool) {
    final current = ref.read(pageToolsProvider).tool;
    if (current == tool) {
      _options();
      return;
    }
    ref.read(pageToolsProvider.notifier).select(tool);
    _attachHistory();
    setState(() {
      _panelOpen = tool != ArtTool.color && tool != ArtTool.measure;
      if (!_panelOpen) _railExpanded = false;
    });
  }

  void _end() {
    _sampleVersion++;
    ref.read(pageToolsProvider.notifier).end();
    _close();
    setState(() => _railExpanded = true);
    _toolFocus.requestFocus();
  }

  void _openTool(ArtTool? tool) {
    ref.read(pageToolsProvider.notifier).pause();
    _attachHistory();
    _workspaceNavigator.currentState?.popUntil((route) => route.isFirst);
    _selection.value = tool;
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
    if (_workspaceOpen || _panelOpen) {
      _close();
    } else {
      if (ref.read(pageToolsProvider).tool != null) {
        _end();
      } else {
        setState(() => _railExpanded = false);
      }
    }
  }

  @override
  void dispose() {
    widget.observer.changes.removeListener(_routeChanged);
    WidgetsBinding.instance.removeObserver(this);
    _selection.dispose();
    _toolFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inSession = widget.observer.inSession;
    if (inSession) ref.watch(toolboxImageControllerProvider);
    final pageTools = ref.watch(pageToolsProvider);
    final dock = ref.watch(toolboxDockControllerProvider);
    final media = MediaQuery.of(context);
    final motion = ref.watch(companionMotionProvider);
    final route = widget.observer.page?.settings.name;
    final ownTools =
        route == RoutePaths.artToolbox ||
        (route == RoutePaths.myNotes &&
            ref.watch(myNotesControllerProvider.select((s) => s.view)) ==
                MyNotesView.editor);
    final visible =
        inSession &&
        widget.observer.unobstructed &&
        !_workspaceOpen &&
        !ownTools;
    final effect = visible && !pageTools.original;
    return Overlay.wrap(
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _escape},
        child: Focus(
          focusNode: _toolFocus,
          skipTraversal: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final safeBottom = math.max(
                media.padding.bottom,
                media.viewInsets.bottom,
              );
              final railHeight = math.min(
                _railExpanded ? 420.0 : ToolboxCompanion.extent,
                math.max(
                  ToolboxCompanion.extent,
                  constraints.maxHeight - media.padding.top - safeBottom - 16,
                ),
              );
              final railWidth = _railExpanded ? 52.0 : ToolboxCompanion.extent;
              // 持久位置始终按小画的 64 点热区计算；展开只夹紧视觉位置，
              // 收起后回到原来的贴边位置，不因工具栏高度改写偏好。
              final anchorBounds = Rect.fromLTRB(
                media.padding.left + 8,
                media.padding.top + 8,
                math.max(
                  media.padding.left + 8,
                  constraints.maxWidth - media.padding.right - 72,
                ),
                math.max(
                  media.padding.top + 8,
                  constraints.maxHeight - safeBottom - 72,
                ),
              );
              final anchor = ToolboxDockGeometry.resolve(dock, anchorBounds);
              final bounds = Rect.fromLTRB(
                media.padding.left + 8,
                media.padding.top + 8,
                math.max(
                  media.padding.left + 8,
                  constraints.maxWidth - media.padding.right - railWidth - 8,
                ),
                math.max(
                  media.padding.top + 8,
                  constraints.maxHeight - safeBottom - railHeight - 8,
                ),
              );
              final point = ToolboxDockGeometry.clamp(
                _dragPosition ??
                    anchor.translate(
                      _railExpanded && anchor.dx > constraints.maxWidth / 2
                          ? 12
                          : 0,
                      0,
                    ),
                bounds,
              );
              final onRight = point.dx > constraints.maxWidth / 2;
              final panelWidth = math.min(300.0, constraints.maxWidth - 88);
              final panelLeft =
                  (onRight
                          ? point.dx - panelWidth - 8
                          : point.dx + railWidth + 8)
                      .clamp(8.0, constraints.maxWidth - panelWidth - 8);
              final panelHeight = math.min(switch (pageTools.tool) {
                ArtTool.grid => 330.0,
                ArtTool.value => 320.0,
                ArtTool.mirror => 300.0,
                ArtTool.measure => 250.0,
                ArtTool.color => 460.0,
                _ => 400.0,
              }, constraints.maxHeight - media.padding.top - safeBottom - 24);
              void trace(Offset p) {
                if (motion && !media.disableAnimations && !_railExpanded) {
                  _trail.currentState?.add(
                    p + const Offset(32, 32),
                    companionPaints[_paint % companionPaints.length],
                  );
                }
              }

              void dragStart(DragStartDetails _) {
                _close();
                setState(() => _dragPosition = point);
                trace(point);
              }

              void dragUpdate(DragUpdateDetails e) {
                setState(
                  () => _dragPosition = ToolboxDockGeometry.clamp(
                    (_dragPosition ?? point) + e.delta,
                    bounds,
                  ),
                );
                trace(_dragPosition!);
              }

              void dragEnd(DragEndDetails _) {
                final p = _dragPosition ?? point;
                final adjusted = p.translate(
                  _railExpanded && p.dx > constraints.maxWidth / 2 ? -12 : 0,
                  0,
                );
                final controller = ref.read(
                  toolboxDockControllerProvider.notifier,
                );
                if (_railExpanded) {
                  controller.dockVertical(adjusted, anchorBounds);
                } else {
                  controller.dock(adjusted, anchorBounds);
                }
                setState(() => _dragPosition = null);
              }

              void dragCancel() => setState(() => _dragPosition = null);
              final greet = !_greeted;
              if (visible && !_railExpanded) _greeted = true;
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
                                const SingleActivator(
                                  LogicalKeyboardKey.escape,
                                ): _escape,
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
                                                                initialTool:
                                                                    tool,
                                                                onToolChanged:
                                                                    (tool) =>
                                                                        _selection.value =
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
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

                  if (visible && pageTools.tool != null)
                    Positioned.fill(
                      child: PageToolOverlay(onSample: _sampleColor),
                    ),
                  if (visible && pageTools.tool != null && !_panelOpen)
                    Positioned(
                      left: 16,
                      bottom: safeBottom + 12,
                      child: Material(
                        color: AppColors.surface,
                        elevation: 3,
                        borderRadius: AppRadius.br12,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
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
                                onTap: _options,
                                variant: AppButtonVariant.text,
                                size: AppButtonSize.sm,
                              ),
                              RailButton(
                                icon: Icons.close,
                                label: '结束当前页面工具',
                                onTap: _end,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (visible && _panelOpen && pageTools.tool != null)
                    Positioned(
                      left: panelLeft,
                      top: point.dy.clamp(
                        media.padding.top + 8,
                        math.max(
                          media.padding.top + 8,
                          constraints.maxHeight - safeBottom - panelHeight - 8,
                        ),
                      ),
                      width: panelWidth,
                      height: panelHeight,
                      child: Material(
                        key: const ValueKey('page-tool-options'),
                        color: AppColors.surface,
                        elevation: 6,
                        borderRadius: AppRadius.br12,
                        clipBehavior: Clip.antiAlias,
                        child: FocusScope(
                          autofocus: true,
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  right: 4,
                                  top: 4,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        pageTools.tool!.label,
                                        style: AppText.title16,
                                      ),
                                    ),
                                    RailButton(
                                      icon: Icons.close,
                                      label: '收起工具参数',
                                      onTap: _close,
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: PageToolOptions(state: pageTools),
                                ),
                              ),
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Row(
                                  children: [
                                    RailButton(
                                      icon: Icons.undo,
                                      label: '撤销工具调整',
                                      enabled: pageTools.canUndo,
                                      onTap: ref
                                          .read(pageToolsProvider.notifier)
                                          .undo,
                                    ),
                                    AppButton(
                                      label: '重置参数',
                                      variant: AppButtonVariant.text,
                                      onTap: ref
                                          .read(pageToolsProvider.notifier)
                                          .reset,
                                    ),
                                    const Spacer(),
                                    AppButton(
                                      label: '完成',
                                      onTap: _end,
                                      size: AppButtonSize.sm,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (visible &&
                      !_railExpanded &&
                      motion &&
                      !media.disableAnimations)
                    Positioned.fill(child: CompanionPaintTrail(key: _trail)),
                  if (visible)
                    Positioned(
                      left: point.dx,
                      top: point.dy,
                      width: railWidth,
                      height: railHeight,
                      child: !_railExpanded
                          ? ToolboxCompanion(
                              key: const ValueKey('floating-toolbox-companion'),
                              edge: dock.edge,
                              expanded: false,
                              dragging: _dragPosition != null,
                              motionEnabled: motion,
                              semanticLabel: '展开工具栏，拖动可移动',
                              greet: greet,
                              paint: _paint,
                              onPaintChanged: (paint) =>
                                  setState(() => _paint = paint),
                              onTap: () {
                                _close();
                                setState(() => _railExpanded = true);
                                _toolFocus.requestFocus();
                              },
                              onDragStart: dragStart,
                              onDragUpdate: dragUpdate,
                              onDragEnd: dragEnd,
                              onDragCancel: dragCancel,
                            )
                          : ProfessionalToolRail(
                              expanded: _railExpanded,
                              selected: pageTools.tool,
                              onSelect: _select,
                              onPointer: _end,
                              onAllTools: () => _openTool(null),
                              onToggle: () {
                                _close();
                                setState(() => _railExpanded = !_railExpanded);
                              },
                              onDragStart: dragStart,
                              onDragUpdate: dragUpdate,
                              onDragEnd: dragEnd,
                              onDragCancel: dragCancel,
                            ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
