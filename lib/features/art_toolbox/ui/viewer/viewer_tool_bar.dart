import 'package:flutter/material.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/widgets/image_viewer_tools.dart';
import '../../data/toolbox_catalog.dart';
import 'viewer_readouts.dart';
import 'viewer_tools_controller.dart';

/// 看图页底部：上面一行是当前工具的选项或读数，下面是工具栏。
///
/// 深色底上，选中的工具是白色图标、粗体名称和一条短下划线，不用品牌紫；
/// 选项行始终占着位置，开关工具时画面大小不变。
class ViewerToolBar extends StatelessWidget {
  const ViewerToolBar({
    required this.controller,
    required this.item,
    super.key,
  });

  final ViewerToolsController controller;
  final ImageViewerItem item;

  static const double optionsHeight = 52;
  static const double barHeight = 64;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    Widget tool(ViewerTool t) => _ToolItem(
      icon: _iconOf(t),
      label: _labelOf(t),
      selected: c.isActive(t),
      onTap: () => c.tap(t),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: optionsHeight,
          child: _OptionsRow(controller: c),
        ),
        const ColoredBox(
          color: AppColors.onCanvasDarkLine,
          child: SizedBox(height: 1),
        ),
        SizedBox(
          height: barHeight,
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24),
              child: Row(
                children: [
                  tool(ViewerTool.original),
                  const _GroupRule(),
                  tool(ViewerTool.gray),
                  tool(ViewerTool.levels),
                  tool(ViewerTool.blur),
                  const _GroupRule(),
                  tool(ViewerTool.mirror),
                  tool(ViewerTool.grid),
                  const _GroupRule(),
                  tool(ViewerTool.color),
                  tool(ViewerTool.measure),
                  const _GroupRule(),
                  _ToolItem(
                    icon: Icons.apps_rounded,
                    label: '更多工具',
                    semanticLabel: '更多工具，在画室工具箱里打开这张图',
                    selected: false,
                    onTap: () => _openToolbox(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openToolbox(BuildContext context) {
    final tool = switch (controller.leadTool) {
      ViewerTool.gray || ViewerTool.levels => ArtTool.value,
      ViewerTool.blur => ArtTool.blur,
      ViewerTool.mirror => ArtTool.mirror,
      ViewerTool.grid => ArtTool.grid,
      ViewerTool.color => ArtTool.color,
      ViewerTool.measure => ArtTool.measure,
      _ => null,
    };
    Navigator.of(context).pushNamed(
      RoutePaths.artToolbox,
      arguments: <String, dynamic>{
        if (tool != null) 'tool': tool.key,
        'imageUrl': item.src,
        'title': item.title.isEmpty ? '当前图片' : item.title,
      },
    );
  }

  static String _labelOf(ViewerTool tool) => switch (tool) {
    ViewerTool.original => '原图',
    ViewerTool.gray => '灰度',
    ViewerTool.levels => '明度色阶',
    ViewerTool.blur => '眯眼模糊',
    ViewerTool.mirror => '镜像',
    ViewerTool.grid => '构图网格',
    ViewerTool.color => '取色',
    ViewerTool.measure => '比例测量',
  };

  static IconData _iconOf(ViewerTool tool) => switch (tool) {
    ViewerTool.original => Icons.image_outlined,
    ViewerTool.gray => Icons.filter_b_and_w_rounded,
    ViewerTool.levels => Icons.contrast_rounded,
    ViewerTool.blur => Icons.blur_on_rounded,
    ViewerTool.mirror => Icons.flip_rounded,
    ViewerTool.grid => Icons.grid_4x4_rounded,
    ViewerTool.color => Icons.colorize_rounded,
    ViewerTool.measure => Icons.straighten_rounded,
  };
}

/// 工具栏的一项：点击区域 72 × 64。
class _ToolItem extends StatelessWidget {
  const _ToolItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.semanticLabel,
  });

  final IconData icon;
  final String label;
  final String? semanticLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppColors.onCanvasDark
        : AppColors.onCanvasDarkMuted;
    return AppPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: semanticLabel ?? label,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 72,
          height: ViewerToolBar.barHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: AppSpace.s4),
              Text(
                label,
                maxLines: 1,
                style: (selected ? AppText.caption12Strong : AppText.caption12)
                    .copyWith(color: color),
              ),
              const SizedBox(height: AppSpace.s4),
              Container(
                width: 16,
                height: 2,
                color: selected ? AppColors.onCanvasDark : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupRule extends StatelessWidget {
  const _GroupRule();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
      color: AppColors.onCanvasDarkLine,
    );
  }
}

/// 选项行：当前工具的选项（档数、程度、方向、构图线）或读数（颜色、比例）。
class _OptionsRow extends StatelessWidget {
  const _OptionsRow({required this.controller});

  final ViewerToolsController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final focus = c.focus;
    final needsPixels =
        focus == ViewerTool.levels ||
        focus == ViewerTool.blur ||
        focus == ViewerTool.color;
    final Widget content = switch (focus) {
      ViewerTool.levels => _Choices(
        label: '档数',
        children: [
          for (final n in ViewerToolsController.levelOptions)
            _OptionChip(
              label: '$n 档',
              selected: c.levels == n,
              onTap: () => c.setLevels(n),
            ),
        ],
      ),
      ViewerTool.blur => _Choices(
        label: '程度',
        children: [
          for (final (i, level) in ViewerToolsController.blurOptions.indexed)
            _OptionChip(
              label: const ['轻', '中', '重'][i],
              selected: c.blurLevel == level,
              onTap: () => c.setBlurLevel(level),
            ),
        ],
      ),
      ViewerTool.mirror => _Choices(
        label: '方向',
        children: [
          _OptionChip(
            label: '左右',
            selected: c.mirrorX,
            onTap: () => c.toggleMirror(horizontal: true),
          ),
          _OptionChip(
            label: '上下',
            selected: c.mirrorY,
            onTap: () => c.toggleMirror(horizontal: false),
          ),
        ],
      ),
      ViewerTool.grid => _Choices(
        label: '构图线',
        children: [
          for (final line in ViewerGridLine.values)
            _OptionChip(
              label: switch (line) {
                ViewerGridLine.nine => '九宫格',
                ViewerGridLine.quarters => '四分',
                ViewerGridLine.diagonal => '对角线',
              },
              selected: c.grid.contains(line),
              onTap: () => c.toggleGrid(line),
            ),
        ],
      ),
      ViewerTool.color => ViewerColorReadout(controller: c),
      ViewerTool.measure => ViewerMeasureReadout(controller: c),
      _ => const ViewerNote('双指缩放 · 双击放大 · 工具只改变画面的显示，不改动原图'),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(child: content),
          if (needsPixels && c.processing) ...[
            const SizedBox(width: AppSpace.s16),
            const SizedBox(
              width: 16,
              height: 16,
              child: AppLoadingIndicator(
                size: 16,
                color: AppColors.onCanvasDarkMuted,
              ),
            ),
            const SizedBox(width: AppSpace.s8),
            const ViewerNote('处理中'),
          ] else if (needsPixels && c.failed) ...[
            const SizedBox(width: AppSpace.s16),
            const ViewerNote('这张图暂时无法处理，可以试试「更多工具」'),
          ],
        ],
      ),
    );
  }
}

class _Choices extends StatelessWidget {
  const _Choices({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ViewerNote(label),
        const SizedBox(width: AppSpace.s8),
        ...children,
      ],
    );
  }
}

/// 深色底上的选项：选中的垫一块浅色胶囊、白色粗体；看上去高 32，点击区域高 44。
class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: label,
      child: ExcludeSemantics(
        child: SizedBox(
          height: 44,
          child: Center(
            child: Container(
              height: 32,
              constraints: const BoxConstraints(minWidth: 44),
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.onCanvasDarkLine : null,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                label,
                style: (selected ? AppText.body14Strong : AppText.body14)
                    .copyWith(
                      color: selected
                          ? AppColors.onCanvasDark
                          : AppColors.onCanvasDarkMuted,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
