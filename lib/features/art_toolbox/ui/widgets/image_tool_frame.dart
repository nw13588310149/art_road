import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_font.dart';
import '../../../../core/ui/ui.dart';
import '../../../gallery/ui/widgets/library_controls.dart';
import '../../data/toolbox_catalog.dart';
import '../../data/toolbox_image_source.dart';
import '../../state/toolbox_image_controller.dart';
import 'tool_panel.dart';

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

/// 所有工具页共用返回、用法说明与操作按钮，绘画和控制区域由工具提供。
class ToolPageScaffold extends StatelessWidget {
  const ToolPageScaffold({
    required this.tool,
    required this.onBack,
    required this.body,
    this.subtitle,
    this.bodyTopInset = AppSpace.s16,
    this.actions = const <Widget>[],
    super.key,
  });

  final ArtTool tool;
  final VoidCallback onBack;
  final Widget body;
  final String? subtitle;
  final double bodyTopInset;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToolDetailHeader(
          title: tool.label,
          subtitle: subtitle,
          onBack: onBack,
          actions: [
            ...actions,
            LibraryIconButton(
              icon: Icons.help_outline_rounded,
              iconSize: 20,
              semanticLabel: '工具用法',
              onTap: () => showAppDialog<void>(
                context: context,
                builder: (_) =>
                    AppDialog(title: tool.label, message: tool.help),
              ),
            ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: bodyTopInset),
            child: body,
          ),
        ),
      ],
    );
  }
}

/// 详情工具栏：资料预览页的顶部工具栏（56 高、返回、居中标题、右侧操作）。
///
/// 没有 [subtitle] 时就是 [LibraryPreviewHeader]；有 [subtitle]（当前画作、练习
/// 设置）时在标题右侧用 12 号浅灰字接着写，其余数值不变。[prominent] 用于全屏
/// 练习页：标题换成原版录制详情的 16 号粗体。
class ToolDetailHeader extends StatelessWidget {
  const ToolDetailHeader({
    required this.title,
    required this.actions,
    this.subtitle,
    this.onBack,
    this.prominent = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final note = subtitle ?? '';
    if (note.isEmpty && !prominent) {
      return LibraryPreviewHeader(
        title: title,
        onBack: onBack,
        actions: actions,
      );
    }
    final titleText = Semantics(
      header: true,
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: libraryText(
          size: prominent ? 16 : 15,
          weight: prominent ? AppFont.w600 : AppFont.w500,
          color: AppColors.ink,
        ),
      ),
    );
    return Container(
      height: LibraryPreviewHeader.height,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            LibraryIconButton.back(onTap: onBack),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: note.isEmpty
                ? Center(child: titleText)
                : LayoutBuilder(
                    // 标题按自身宽度排，最多占六成；画作名占余下的位置，放不下时省略。
                    builder: (context, constraints) => Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth * 0.6,
                            ),
                            child: titleText,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              note,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: libraryText(
                                size: 12,
                                color: AppColors.textPlaceholder,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          for (var i = 0; i < actions.length; i++) ...[
            SizedBox(width: i == 0 ? 12 : 8),
            actions[i],
          ],
        ],
      ),
    );
  }
}

/// 图片类工具的骨架：未选图时显示选图区（上传图片 / 示例画作），处理中显示加载，
/// 选好图后交给 [builder] 渲染工具本体；页头右侧可随时换图。
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

  /// 工具栏窄于这个宽度时，操作胶囊只留图标。
  static const double compactBreakpoint = 640;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(toolboxImageControllerProvider);
    final controller = ref.read(toolboxImageControllerProvider.notifier);
    final image = state.image;
    final workspace = ToolboxWorkspaceScope.of(context);

    Future<void> pickSample() async {
      final sample = await showToolboxSamplePicker(context);
      if (sample != null) {
        await controller.loadSample(sample);
      }
    }

    Widget body;
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
              top: AppSpace.s8,
              left: 0,
              right: 0,
              child: Center(child: _LoadingChip()),
            ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactBreakpoint;
        return ToolPageScaffold(
          tool: tool,
          onBack: onBack,
          subtitle: image?.label,
          bodyTopInset: 0,
          actions: [
            if (workspace != null)
              Builder(
                builder: (anchor) => LibraryActionPill(
                  label: '切换工具',
                  icon: Icons.swap_horiz_rounded,
                  iconSize: 18,
                  compact: compact,
                  onTap: () async {
                    final selected = await showAppMenu<ArtTool>(
                      context: anchor,
                      width: 180,
                      items: [
                        for (final candidate in ArtToolGroup.analysis.tools)
                          AppMenuItem(
                            value: candidate,
                            label: candidate.label,
                            icon: candidate.icon,
                            enabled: candidate != tool,
                          ),
                      ],
                    );
                    if (anchor.mounted && selected != null) {
                      workspace.onSwitchTool(selected);
                    }
                  },
                ),
              ),
            if (image != null) ...[
              LibraryActionPill(
                label: '上传图片',
                iconAsset: AppAssets.coursewareUploadFab,
                compact: compact,
                onTap: state.loading ? null : controller.pickFromAlbum,
              ),
              LibraryActionPill(
                label: '使用示例画作',
                icon: Icons.collections_outlined,
                iconSize: 18,
                compact: compact,
                onTap: state.loading ? null : pickSample,
              ),
            ],
          ],
          body: body,
        );
      },
    );
  }
}

/// 预览主体沿用 16px 内嵌画布和白底侧栏。窄屏时将侧栏放到画布下。
class ImageToolLayout extends StatelessWidget {
  const ImageToolLayout({
    required this.stage,
    required this.panel,
    this.panelFooter,
    this.panelWidth = 320,
    super.key,
  });

  final WidgetBuilder stage;
  final WidgetBuilder panel;

  /// 侧栏底部固定的主操作（如「开始练习」）：宽屏时固定在侧栏底部，不随参数
  /// 滚动；窄屏侧栏很矮，改为接在参数后面一起滚动。
  final WidgetBuilder? panelFooter;
  final double panelWidth;

  static const wideBreakpoint = 760.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= wideBreakpoint;
        final canvas = Padding(
          padding: const EdgeInsets.all(AppSpace.s16),
          child: stage(context),
        );
        const divider = BorderSide(color: AppColors.lineSoft);
        final footer = panelFooter;
        Widget panelBody = SingleChildScrollView(
          primary: false,
          padding: const EdgeInsets.all(AppSpace.card),
          child: footer == null || wide
              ? panel(context)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    panel(context),
                    const SizedBox(height: AppSpace.s16),
                    footer(context),
                  ],
                ),
        );
        if (footer != null && wide) {
          panelBody = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: panelBody),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.card,
                  10,
                  AppSpace.card,
                  AppSpace.card,
                ),
                child: footer(context),
              ),
            ],
          );
        }
        final panelBox = DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: wide
                ? const Border(left: divider)
                : const Border(top: divider),
          ),
          child: panelBody,
        );
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: canvas),
              SizedBox(width: panelWidth, child: panelBox),
            ],
          );
        }
        final panelHeight = (constraints.maxHeight * 0.42)
            .clamp(0.0, 320.0)
            .toDouble();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: canvas),
            SizedBox(height: panelHeight, child: panelBox),
          ],
        );
      },
    );
  }
}

/// 选图区：上传图片，或直接点一张示例画作。
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
      stage: (context) => ToolStage(
        child: loading
            ? const _ProcessingHint()
            : LibraryEmptyState(
                message: '选一张画作，开始使用「${tool.label}」',
                description: '从相册选图，或使用示例画作。图片只在本机处理。',
                actionLabel: '上传图片',
                onAction: onUpload,
              ),
      ),
      panel: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LibrarySectionTitle('示例画作'),
          const SizedBox(height: AppSpace.s12),
          SampleGrid(
            samples: toolboxSamples,
            onTap: loading ? null : onSample,
          ),
        ],
      ),
    );
  }
}

/// 示例画作网格：每张约 128 宽、间距 12，按可用宽度排满。
class SampleGrid extends StatelessWidget {
  const SampleGrid({required this.samples, required this.onTap, super.key});

  final List<ToolboxSample> samples;
  final ValueChanged<ToolboxSample>? onTap;

  static const double _gap = AppSpace.s12;
  static const double _target = 128;

  @override
  Widget build(BuildContext context) {
    final tap = onTap;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = ((constraints.maxWidth + _gap) / (_target + _gap))
            .floor()
            .clamp(1, samples.length);
        final size =
            ((constraints.maxWidth - _gap * (columns - 1)) / columns)
                .floorToDouble();
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final sample in samples)
              SampleThumb(
                sample: sample,
                size: size,
                showLabel: true,
                onTap: tap == null ? null : () => tap(sample),
              ),
          ],
        );
      },
    );
  }
}

class SampleThumb extends StatelessWidget {
  const SampleThumb({
    required this.sample,
    required this.size,
    required this.onTap,
    this.showLabel = false,
    super.key,
  });

  final ToolboxSample sample;
  final double size;
  final VoidCallback? onTap;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    // 横图按 cover 裁成方形时，解码宽度需大于显示宽度才不发虚。
    final decodeWidth = (size * MediaQuery.devicePixelRatioOf(context) * 1.5)
        .round();
    return AppPressable(
      onTap: onTap,
      semanticLabel: sample.label,
      child: SizedBox(
        width: size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: AppRadius.br8,
              child: Image.asset(
                sample.asset,
                width: size,
                height: size,
                fit: BoxFit.cover,
                cacheWidth: decodeWidth,
                filterQuality: FilterQuality.medium,
              ),
            ),
            if (showLabel) ...[
              const SizedBox(height: 6),
              Text(
                sample.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: libraryText(
                  size: 12,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ],
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
          Text(
            '正在处理图片…',
            style: libraryText(size: 12, color: AppColors.textPlaceholder),
          ),
        ],
      ),
    );
  }
}

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

/// 示例画作选择弹窗；返回选中的示例，取消返回 null。
Future<ToolboxSample?> showToolboxSamplePicker(BuildContext context) {
  return showAppDialog<ToolboxSample>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: '选择示例画作',
      width: AppSize.dialogWide,
      child: Wrap(
        spacing: AppSpace.s12,
        runSpacing: AppSpace.s12,
        children: [
          for (final sample in toolboxSamples)
            SampleThumb(
              sample: sample,
              size: 112,
              showLabel: true,
              onTap: () => Navigator.of(dialogContext).pop(sample),
            ),
        ],
      ),
    ),
  );
}
