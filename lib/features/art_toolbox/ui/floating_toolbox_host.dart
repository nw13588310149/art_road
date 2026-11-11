import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../data/toolbox_catalog.dart';
import '../data/toolbox_dock_preferences.dart';
import '../state/toolbox_dock_controller.dart';
import '../state/companion_controller.dart';
import '../state/toolbox_image_controller.dart';
import 'art_toolbox_page.dart';
import 'toolbox_route_observer.dart';
import 'widgets/toolbox_companion.dart';
import 'widgets/art_companion_portrait.dart';

const _quickTools = <ArtTool>[
  ArtTool.grid,
  ArtTool.value,
  ArtTool.mirror,
  ArtTool.measure,
  ArtTool.color,
  ArtTool.quickSketch,
];

const _quickHints = <ArtTool, String>{
  ArtTool.grid: '看构图与重心',
  ArtTool.value: '看黑白灰关系',
  ArtTool.mirror: '换个方向找形误',
  ArtTool.measure: '比长度与角度',
  ArtTool.color: '取色、看配色',
  ArtTool.quickSketch: '限时练动态',
};

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
  final _workspaceNavigator = GlobalKey<NavigatorState>();
  final _selection = ValueNotifier<ArtTool?>(null);
  LocalHistoryEntry? _history;
  bool _panelOpen = false;
  bool _workspaceOpen = false;
  bool _workspaceCreated = false;
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
    if (!widget.observer.inSession ||
        pageChanged ||
        !widget.observer.unobstructed) {
      _close();
    }
    setState(() {
      if (!widget.observer.inSession) {
        _workspaceCreated = false;
        _selection.value = null;
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
    final imageState = inSession
        ? ref.watch(toolboxImageControllerProvider)
        : null;
    final dock = ref.watch(toolboxDockControllerProvider);
    final motionEnabled = ref.watch(companionMotionProvider);
    final media = MediaQuery.of(context);
    return Overlay.wrap(
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
          final panelWidth = math.min(368.0, constraints.maxWidth - 24);
          final horizontalEdge =
              dock.edge == ToolboxDockEdge.top ||
              dock.edge == ToolboxDockEdge.bottom;
          final panelHeight = math.min(
            _workspaceCreated ? 510.0 : 420.0,
            math.max(
              0.0,
              constraints.maxHeight -
                  media.padding.top -
                  math.max(media.padding.bottom, media.viewInsets.bottom) -
                  24 -
                  (horizontalEdge ? _extent + 12 : 0),
            ),
          );
          final panelLeft = switch (dock.edge) {
            ToolboxDockEdge.left => point.dx + _extent + 12,
            ToolboxDockEdge.right => point.dx - panelWidth - 12,
            _ => point.dx + _extent / 2 - panelWidth / 2,
          };
          final panelTop = switch (dock.edge) {
            ToolboxDockEdge.top => point.dy + _extent + 12,
            ToolboxDockEdge.bottom => point.dy - panelHeight - 12,
            _ => point.dy + _extent / 2 - panelHeight / 2,
          };
          final showLauncher =
              inSession && widget.observer.unobstructed && !_workspaceOpen;
          return Stack(
            children: [
              ExcludeFocus(
                excluding: _panelOpen || _workspaceOpen,
                child: ExcludeSemantics(
                  excluding: _panelOpen || _workspaceOpen,
                  child: widget.child,
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
                                                            onToolChanged: (tool) =>
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
                                          Text('画室工具箱', style: AppText.title16),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Text(
                                              '收起后可继续使用当前画作',
                                              style: AppText.caption12.copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          AppButton(
                                            label: '收起工具',
                                            icon:
                                                Icons.close_fullscreen_rounded,
                                            variant: AppButtonVariant.secondary,
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
              if (_panelOpen && showLauncher) ...[
                Positioned.fill(
                  child: ModalBarrier(
                    color: AppColors.ink.withValues(alpha: 0.12),
                    onDismiss: _close,
                    semanticsLabel: '关闭画具面板',
                  ),
                ),
                Positioned(
                  left: panelLeft.clamp(
                    12,
                    math.max(12, constraints.maxWidth - panelWidth - 12),
                  ),
                  top: panelTop.clamp(
                    12,
                    math.max(
                      12,
                      constraints.maxHeight -
                          media.viewInsets.bottom -
                          panelHeight -
                          12,
                    ),
                  ),
                  width: panelWidth,
                  height: panelHeight,
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.escape): _close,
                    },
                    child: FocusScope(
                      autofocus: true,
                      child: _QuickToolPanel(
                        imageState: imageState!,
                        lastTool: _selection.value,
                        canResume: _workspaceCreated,
                        onClose: _close,
                        onOpen: _openTool,
                        onResume: () =>
                            _openTool(_selection.value, resume: true),
                      ),
                    ),
                  ),
                ),
              ],
              if (showLauncher)
                Positioned(
                  left: point.dx,
                  top: point.dy,
                  width: _extent,
                  height: _extent,
                  child: ToolboxCompanion(
                    edge: dock.edge,
                    expanded: _panelOpen,
                    dragging: _dragPosition != null,
                    motionEnabled: motionEnabled,
                    onTap: _togglePanel,
                    onDragStart: (_) {
                      _close();
                      setState(() => _dragPosition = point);
                    },
                    onDragUpdate: (event) => setState(() {
                      _dragPosition = ToolboxDockGeometry.clamp(
                        (_dragPosition ?? point) + event.delta,
                        bounds,
                      );
                    }),
                    onDragEnd: (_) {
                      ref
                          .read(toolboxDockControllerProvider.notifier)
                          .dock(_dragPosition ?? point, bounds);
                      setState(() => _dragPosition = null);
                    },
                    onDragCancel: () => setState(() => _dragPosition = null),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _QuickToolPanel extends ConsumerWidget {
  const _QuickToolPanel({
    required this.imageState,
    required this.lastTool,
    required this.canResume,
    required this.onClose,
    required this.onOpen,
    required this.onResume,
  });

  final ToolboxImageState imageState;
  final ArtTool? lastTool;
  final bool canResume;
  final VoidCallback onClose;
  final ValueChanged<ArtTool?> onOpen;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = ref.watch(companionMotionProvider);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final image = imageState.image;
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: '画具快捷面板',
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.br16,
          boxShadow: AppShadow.popover,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                child: Row(
                  children: [
                    const ArtCompanionPortrait(size: 32, happy: true),
                    const SizedBox(width: 10),
                    Expanded(child: Text('随手用画具', style: AppText.title20)),
                    AppIconButton(
                      icon: Icons.close_rounded,
                      semanticLabel: '关闭画具面板',
                      onTap: onClose,
                      filled: false,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text('小墨 · 拖动贴边，轻点展开', style: AppText.body13),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (canResume) ...[
                        AppPressable(
                          semanticLabel: '继续上次工具',
                          onTap: onResume,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: AppRadius.br12,
                            ),
                            child: Row(
                              children: [
                                if (image != null)
                                  ClipRRect(
                                    borderRadius: AppRadius.br8,
                                    child: RawImage(
                                      image: image.image,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.history_rounded,
                                    size: 24,
                                    color: AppColors.textSecondary,
                                  ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '继续 · ${lastTool?.label ?? '工具箱'}',
                                        style: AppText.body14Strong,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        image?.label ?? '回到上次工作台',
                                        style: AppText.caption12.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 20,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      LayoutBuilder(
                        builder: (_, constraints) => Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            for (final tool in _quickTools)
                              SizedBox(
                                width: (constraints.maxWidth - 12) / 2,
                                child: AppPressable(
                                  onTap: () => onOpen(tool),
                                  semanticLabel: '全屏打开${tool.label}',
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Icon(
                                            tool.icon,
                                            size: 20,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                tool.label,
                                                style: AppText.body14Strong,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _quickHints[tool]!,
                                                style: AppText.caption12
                                                    .copyWith(
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                              ),
                                            ],
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
                      const SizedBox(height: 12),
                      Text(
                        image == null ? '图片工具支持选图或使用示例画作' : '已选画作可在图片工具之间共用',
                        style: AppText.caption12.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.line),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            reduced ? '已减少动态' : '精灵动态',
                            style: AppText.caption12Strong,
                          ),
                          const SizedBox(width: 8),
                          AppSwitch(
                            value: motion && !reduced,
                            enabled: !reduced,
                            size: AppControlSize.sm,
                            semanticLabel: '精灵动态',
                            onChanged: ref
                                .read(companionMotionProvider.notifier)
                                .setMotion,
                          ),
                        ],
                      ),
                    ),
                    AppButton(
                      label: '全部 ${ArtTool.values.length} 个工具',
                      variant: AppButtonVariant.secondary,
                      icon: Icons.open_in_full_rounded,
                      onTap: () => onOpen(null),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
