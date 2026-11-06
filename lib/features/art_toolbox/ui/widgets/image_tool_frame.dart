import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/theme/app_font.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../../../core/widgets/art_widgets.dart';
import '../../../../core/widgets/scaled_dialog.dart';
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

/// 图片类工具的骨架：页头（返回 + 换图）、未选图时的选图引导、处理中状态，
/// 选好图后交给 [builder] 渲染工具本体。
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
          : _ImageSourcePrompt(
              tool: tool,
              onPickAlbum: controller.pickFromAlbum,
              onPickSample: pickSample,
              onSample: controller.loadSample,
            );
    } else {
      body = Stack(
        children: [
          Positioned.fill(child: builder(context, image)),
          if (state.loading)
            const Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(child: _LoadingChip()),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArtPageHeader(
          title: tool.label,
          subtitle: image == null
              ? tool.description
              : '${tool.description} · 当前：${image.label}',
          onBack: onBack,
          actions: image == null
              ? const <Widget>[]
              : [
                  ArtButton(
                    label: '相册',
                    icon: Icons.photo_library_outlined,
                    primary: false,
                    height: 34,
                    onTap: state.loading ? null : controller.pickFromAlbum,
                  ),
                  const SizedBox(width: 8),
                  ArtButton(
                    label: '示例',
                    icon: Icons.collections_outlined,
                    primary: false,
                    height: 34,
                    onTap: state.loading ? null : pickSample,
                  ),
                ],
        ),
        Expanded(child: body),
      ],
    );
  }
}

/// 画面 + 控制面板：宽屏左右排列，窄屏上下排列（面板可滚动）。
class ImageToolLayout extends StatelessWidget {
  const ImageToolLayout({required this.stage, required this.panel, super.key});

  final Widget Function(BuildContext context, bool wide) stage;
  final Widget Function(BuildContext context, bool wide) panel;

  static const wideBreakpoint = 760.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= wideBreakpoint;
        final panelBox = Container(
          decoration: BoxDecoration(
            color: ArtColors.subtle,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: panel(context, wide),
          ),
        );
        if (wide) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: stage(context, wide)),
                const SizedBox(width: 16),
                SizedBox(width: 300, child: panelBox),
              ],
            ),
          );
        }
        final panelHeight = (constraints.maxHeight * 0.42)
            .clamp(170.0, 300.0)
            .toDouble();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: stage(context, wide)),
              const SizedBox(height: 12),
              SizedBox(height: panelHeight, child: panelBox),
            ],
          ),
        );
      },
    );
  }
}

class _ImageSourcePrompt extends StatelessWidget {
  const _ImageSourcePrompt({
    required this.tool,
    required this.onPickAlbum,
    required this.onPickSample,
    required this.onSample,
  });

  final ArtTool tool;
  final VoidCallback onPickAlbum;
  final VoidCallback onPickSample;
  final ValueChanged<ToolboxSample> onSample;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: tool.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(tool.icon, color: tool.accent, size: 36),
            ),
            const SizedBox(height: 14),
            Text('选择一张画作开始${tool.label}', style: ArtText.title(size: 17)),
            const SizedBox(height: 6),
            Text(
              '可以拍下自己的作业，也可以先用示例画作体验；图片只在本机处理',
              textAlign: TextAlign.center,
              style: ArtText.caption(size: 13),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                ArtButton(
                  label: '从相册选择',
                  icon: Icons.photo_library_outlined,
                  height: 42,
                  onTap: onPickAlbum,
                ),
                ArtButton(
                  label: '使用示例画作',
                  icon: Icons.collections_outlined,
                  primary: false,
                  height: 42,
                  onTap: onPickSample,
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text('或直接选一张示例', style: ArtText.caption()),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final sample in toolboxSamples.take(6))
                  _SampleThumb(
                    sample: sample,
                    size: 72,
                    onTap: () => onSample(sample),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SampleThumb extends StatelessWidget {
  const _SampleThumb({
    required this.sample,
    required this.size,
    required this.onTap,
    this.showLabel = false,
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
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
                style: ArtText.caption(size: 12, color: ArtColors.ink2),
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
          const SizedBox(height: 10),
          Text('正在处理图片…', style: ArtText.caption(size: 13)),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Text('正在载入新图片…', style: ArtText.caption(color: Colors.white)),
        ],
      ),
    );
  }
}

/// 示例画作选择弹窗；返回选中的示例，取消返回 null。
Future<ToolboxSample?> showToolboxSamplePicker(BuildContext context) {
  return showScaledDialog<ToolboxSample>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.3),
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '选择示例画作',
                      style: TextStyle(
                        fontSize: 17,
                        color: ArtColors.ink,
                        fontWeight: AppFont.w600,
                        fontFamily: 'PingFang SC',
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(dialogContext).pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: ArtColors.ink3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      for (final sample in toolboxSamples)
                        _SampleThumb(
                          sample: sample,
                          size: 112,
                          showLabel: true,
                          onTap: () => Navigator.of(dialogContext).pop(sample),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
