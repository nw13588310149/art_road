import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/ui.dart';
import '../../data/toolbox_catalog.dart';
import '../../data/toolbox_image_source.dart';
import '../../state/toolbox_image_controller.dart';
import 'tool_panel.dart';
import 'toolbox_samples.dart';

export 'toolbox_samples.dart';

/// 工具箱共享的入口加载状态及分析工具切换。
class ToolboxWorkspaceScope extends InheritedWidget {
  const ToolboxWorkspaceScope({
    required this.pending,
    required this.onSwitchTool,
    required super.child,
    super.key,
  });

  final bool pending;
  final ValueChanged<ArtTool> onSwitchTool;

  static ToolboxWorkspaceScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ToolboxWorkspaceScope>();

  @override
  bool updateShouldNotify(ToolboxWorkspaceScope oldWidget) =>
      oldWidget.pending != pending || oldWidget.onSwitchTool != onSwitchTool;
}

/// 工具页正文拿到的上下文：当前工具，以及 `AppPageBody` 给出的宽窄判断。
class ToolFrame extends InheritedWidget {
  const ToolFrame({
    required this.tool,
    required this.wide,
    required super.child,
    super.key,
  });

  final ArtTool tool;
  final bool wide;

  static ToolFrame? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ToolFrame>();

  @override
  bool updateShouldNotify(ToolFrame oldWidget) =>
      oldWidget.tool != tool || oldWidget.wide != wide;
}

/// 所有工具页共用的骨架（设计语言第八节）：`AppPageBody` 的边距，页头是返回、
/// 工具名、一句上下文（当前画作、练习设置）和靠右的操作，页头下 16 是正文。
/// 正文由工具提供，多数是 [ImageToolLayout]（画布加面板）。
class ToolPageScaffold extends StatelessWidget {
  const ToolPageScaffold({
    required this.tool,
    required this.onBack,
    required this.body,
    this.caption = '',
    this.actions = const <Widget>[],
    super.key,
  });

  final ArtTool tool;
  final VoidCallback onBack;
  final Widget body;
  final String caption;

  /// 靠右的操作：最多一个主按钮（`AppButton`），其余用 `AppPlainButton`。
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AppPageBody(
      scrollable: false,
      builder: (context, wide) => ToolFrame(
        tool: tool,
        wide: wide,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTitleBar(
              title: tool.label,
              caption: caption,
              onBack: onBack,
              actions: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpace.s4),
                  actions[i],
                ],
              ],
            ),
            const SizedBox(height: AppSpace.s16),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// 画布加面板（`AppCanvasLayout`）：画布在左，工具设置面板在右，宽屏 320、窄屏 280。
/// 画布下面一行是操作提示（默认是工具的用法）和画布自己的小操作。
class ImageToolLayout extends StatelessWidget {
  const ImageToolLayout({
    required this.stage,
    required this.panel,
    this.hint,
    this.canvasActions = const <Widget>[],
    this.panelWidth,
    this.canvasColor = AppColors.canvas,
    super.key,
  });

  final WidgetBuilder stage;
  final WidgetBuilder panel;

  /// 画布下面的一句提示；为空时用工具的用法。
  final String? hint;
  final List<Widget> canvasActions;
  final double? panelWidth;
  final Color canvasColor;

  @override
  Widget build(BuildContext context) {
    final frame = ToolFrame.of(context);
    final wide = frame?.wide ?? true;
    return AppCanvasLayout(
      wide: wide,
      canvas: stage(context),
      panel: panel(context),
      hint: hint ?? frame?.tool.help ?? '',
      canvasActions: canvasActions,
      panelWidth: panelWidth ?? (wide ? 320 : 280),
      canvasColor: canvasColor,
    );
  }
}

/// 图片类工具的骨架：未选图时显示选图（上传图片 / 示例画作），处理中显示加载，
/// 选好图后交给 [builder] 渲染工具本体；页头右侧可随时切换工具和换图。
class ImageToolScaffold extends ConsumerWidget {
  const ImageToolScaffold({
    required this.tool,
    required this.onBack,
    required this.builder,
    super.key,
  });

  final ArtTool tool;
  final VoidCallback onBack;
  final Widget Function(BuildContext context, ToolboxImage image) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(toolboxImageControllerProvider);
    final controller = ref.read(toolboxImageControllerProvider.notifier);
    final image = state.image;
    final workspace = ToolboxWorkspaceScope.of(context);

    Future<void> pickSample() async {
      final sample = await showToolboxSamplePicker(
        context,
        current: image?.label,
      );
      if (sample != null) {
        await controller.loadSample(sample);
      }
    }

    final Widget body;
    if (image == null) {
      body = ImageSourcePanel(
        tool: tool,
        loading: state.loading || (workspace?.pending ?? false),
        onUpload: controller.pickFromAlbum,
        onSample: controller.loadSample,
      );
    } else {
      body = Stack(
        children: [
          Positioned.fill(child: builder(context, image)),
          if (state.loading)
            const Positioned(
              top: AppSpace.s12,
              left: 0,
              right: 0,
              child: Center(child: _LoadingChip()),
            ),
        ],
      );
    }

    return ToolPageScaffold(
      tool: tool,
      onBack: onBack,
      caption: image?.label ?? '',
      actions: [
        if (workspace != null)
          Builder(
            builder: (anchor) => AppPlainButton(
              label: '切换工具',
              icon: Icons.swap_horiz_rounded,
              onTap: () async {
                final selected = await showAppMenu<ArtTool>(
                  context: anchor,
                  width: 180,
                  selected: tool,
                  items: [
                    for (final candidate in ArtToolGroup.analysis.tools)
                      AppMenuItem(
                        value: candidate,
                        label: candidate.label,
                        icon: candidate.icon,
                      ),
                  ],
                );
                if (anchor.mounted && selected != null && selected != tool) {
                  workspace.onSwitchTool(selected);
                }
              },
            ),
          ),
        if (image != null) ...[
          AppPlainButton(
            label: '上传图片',
            icon: Icons.upload_rounded,
            onTap: state.loading ? null : controller.pickFromAlbum,
          ),
          AppPlainButton(
            label: '示例画作',
            icon: Icons.photo_library_outlined,
            onTap: state.loading ? null : pickSample,
          ),
        ],
      ],
      body: body,
    );
  }
}

/// 还没有画时：画布里说明要做什么并给出上传，面板里直接点一张示例画作。
class ImageSourcePanel extends StatelessWidget {
  const ImageSourcePanel({
    required this.tool,
    required this.loading,
    required this.onUpload,
    required this.onSample,
    super.key,
  });

  final ArtTool tool;
  final bool loading;
  final VoidCallback onUpload;
  final ValueChanged<ToolboxSample> onSample;

  @override
  Widget build(BuildContext context) {
    return ImageToolLayout(
      stage: (context) => loading
          ? const _ProcessingHint()
          : AppEmptyState(
              title: '选一张画作，开始使用「${tool.label}」',
              description: '从相册选图，或点右边的示例画作。图片只在本机处理。',
              icon: Icons.add_photo_alternate_outlined,
              iconBackground: AppColors.surface,
              actionLabel: '上传图片',
              onAction: onUpload,
            ),
      panel: (context) => ToolPanelSection(
        title: '示例画作',
        note: '点一张直接使用',
        child: SampleGrid(
          samples: toolboxSamples,
          onTap: loading ? null : onSample,
        ),
      ),
    );
  }
}

class _ProcessingHint extends StatelessWidget {
  const _ProcessingHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppLoadingIndicator(size: 40),
          const SizedBox(height: AppSpace.s8),
          Text('正在处理图片…', style: AppText.caption12),
        ],
      ),
    );
  }
}

/// 换图时盖在画布上方的一枚提示（浮层），新图载入后消失。
class _LoadingChip extends StatelessWidget {
  const _LoadingChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.7),
        borderRadius: AppRadius.br8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.onBrand,
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          Text(
            '正在载入新图片…',
            style: AppText.caption12.copyWith(color: AppColors.onBrand),
          ),
        ],
      ),
    );
  }
}
