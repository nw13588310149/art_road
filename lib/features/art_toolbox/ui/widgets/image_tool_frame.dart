import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/ui/ui.dart';
import '../../data/toolbox_catalog.dart';
import '../../data/toolbox_image_source.dart';
import '../../state/toolbox_image_controller.dart';

/// 页面带 `imageUrl` 参数进入、但下载尚未发起的那一帧，让工具直接显示处理中，
/// 避免选图引导一闪而过。
class ToolboxImagePending extends InheritedWidget {
  const ToolboxImagePending({
    required this.pending,
    required super.child,
    super.key,
  });

  final bool pending;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ToolboxImagePending>()
          ?.pending ??
      false;

  @override
  bool updateShouldNotify(ToolboxImagePending oldWidget) =>
      oldWidget.pending != pending;
}

/// 所有工具页共用返回、用法说明与操作按钮，绘画和控制区域由工具提供。
class ToolPageScaffold extends StatelessWidget {
  const ToolPageScaffold({
    required this.tool,
    required this.onBack,
    required this.body,
    this.subtitle,
    this.actions = const <Widget>[],
    super.key,
  });

  final ArtTool tool;
  final VoidCallback onBack;
  final Widget body;
  final String? subtitle;
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
            AppIconButton.asset(
              asset: AppAssets.shellV2Help,
              semanticLabel: '工具用法',
              size: AppButtonSize.sm,
              onTap: () => showAppDialog<void>(
                context: context,
                builder: (_) =>
                    AppDialog(title: tool.label, message: tool.help),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s12),
        Expanded(child: body),
      ],
    );
  }
}

/// 详情工具栏沿用预览页的返回、对象名称和操作布局。
class ToolDetailHeader extends StatelessWidget {
  const ToolDetailHeader({
    required this.title,
    required this.actions,
    this.subtitle,
    this.onBack,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s12,
        vertical: AppSpace.s8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
      ),
      alignment: Alignment.center,
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            if (onBack != null) AppIconButton.back(onTap: onBack),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title16,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption12,
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.s12),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * .55),
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpace.s8,
                runSpacing: AppSpace.s8,
                children: actions,
              ),
            ),
          ],
        ),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(toolboxImageControllerProvider);
    final controller = ref.read(toolboxImageControllerProvider.notifier);
    final image = state.image;

    Future<void> pickSample() async {
      final sample = await showToolboxSamplePicker(context);
      if (sample != null) {
        await controller.loadSample(sample);
      }
    }

    Widget body;
    if (image == null) {
      body = state.loading || ToolboxImagePending.of(context)
          ? const _ProcessingHint()
          : ImageSourcePanel(
              tool: tool,
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

    return ToolPageScaffold(
      tool: tool,
      onBack: onBack,
      subtitle: image?.label,
      actions: image == null
          ? const <Widget>[]
          : [
              AppButton(
                label: '上传图片',
                icon: Icons.upload_rounded,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                onTap: state.loading ? null : controller.pickFromAlbum,
              ),
              AppButton(
                label: '使用示例画作',
                icon: Icons.collections_outlined,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                onTap: state.loading ? null : pickSample,
              ),
            ],
      body: body,
    );
  }
}

/// 画面 + 控制面板：宽屏左右排列（面板 320 宽），窄屏上下排列；面板内容可滚动。
class ImageToolLayout extends StatelessWidget {
  const ImageToolLayout({
    required this.stage,
    required this.panel,
    this.panelWidth = 320,
    super.key,
  });

  final WidgetBuilder stage;
  final WidgetBuilder panel;
  final double panelWidth;

  static const wideBreakpoint = 760.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= wideBreakpoint;
        final panelBox = DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.br12,
            border: Border.all(color: AppColors.lineSoft),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.card),
            child: panel(context),
          ),
        );
        if (wide) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              0,
              AppSpace.page,
              AppSpace.page,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: stage(context)),
                const SizedBox(width: AppSpace.s16),
                SizedBox(width: panelWidth, child: panelBox),
              ],
            ),
          );
        }
        final panelHeight = (constraints.maxHeight * 0.42)
            .clamp(0.0, 320.0)
            .toDouble();
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            0,
            AppSpace.page,
            AppSpace.s16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: stage(context)),
              const SizedBox(height: AppSpace.s12),
              SizedBox(height: panelHeight, child: panelBox),
            ],
          ),
        );
      },
    );
  }
}

/// 选图区：上传图片，或直接点一张示例画作。
class ImageSourcePanel extends StatelessWidget {
  const ImageSourcePanel({
    required this.tool,
    required this.onUpload,
    required this.onSample,
    super.key,
  });

  final ArtTool tool;
  final VoidCallback onUpload;
  final ValueChanged<ToolboxSample> onSample;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s24,
          0,
          AppSpace.s24,
          AppSpace.s24,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.tint(tool.accent),
                  borderRadius: AppRadius.br12,
                ),
                child: Icon(tool.icon, color: tool.accent, size: 28),
              ),
              const SizedBox(height: AppSpace.s12),
              Text('选一张画作，开始使用「${tool.label}」', style: AppText.title16),
              const SizedBox(height: AppSpace.s4),
              Text(
                '可以上传自己作业的照片，也可以先用示例画作体验；图片只在本机处理，不会上传到服务器',
                textAlign: TextAlign.center,
                style: AppText.body13,
              ),
              const SizedBox(height: AppSpace.s20),
              AppButton(
                label: '上传图片',
                icon: Icons.upload_rounded,
                onTap: onUpload,
              ),
              const SizedBox(height: AppSpace.s24),
              Text('或直接选一张示例画作', style: AppText.caption12),
              const SizedBox(height: AppSpace.s12),
              Wrap(
                spacing: AppSpace.s12,
                runSpacing: AppSpace.s12,
                alignment: WrapAlignment.center,
                children: [
                  for (final sample in toolboxSamples)
                    SampleThumb(
                      sample: sample,
                      size: 88,
                      showLabel: true,
                      onTap: () => onSample(sample),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
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
  final VoidCallback onTap;
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
              const SizedBox(height: AppSpace.s4),
              Text(
                sample.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption12.copyWith(
                  color: AppColors.textSecondary,
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
          Text('正在处理图片…', style: AppText.body13),
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
