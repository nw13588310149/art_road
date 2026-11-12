import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/ui/ui.dart';
import '../../data/toolbox_catalog.dart';
import '../../state/companion_controller.dart';
import '../../state/page_tools_controller.dart';
import 'art_companion_portrait.dart';

const pageQuickTools = [
  ArtTool.grid,
  ArtTool.value,
  ArtTool.mirror,
  ArtTool.measure,
  ArtTool.color,
  ArtTool.quickSketch,
];
const _hints = {
  ArtTool.grid: '叠加页面网格',
  ArtTool.value: '查看黑白灰',
  ArtTool.mirror: '翻转当前画面',
  ArtTool.measure: '比较长度角度',
  ArtTool.color: '拾取页面颜色',
  ArtTool.quickSketch: '就地开始计时',
};

/// Flutter 玻璃材质：实时取样背后页面，仅在抽屉边界内模糊，不宣称原生 UIGlassEffect。
class PageToolsDrawer extends ConsumerWidget {
  const PageToolsDrawer({
    required this.onClose,
    required this.onAllTools,
    required this.paint,
    super.key,
  });
  final VoidCallback onClose, onAllTools;
  final int paint;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pageToolsProvider);
    final controller = ref.read(pageToolsProvider.notifier);
    final contrast = MediaQuery.highContrastOf(context);
    return Container(
      key: const ValueKey('page-tools-drawer'),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: .14),
            blurRadius: 28,
            offset: const Offset(-8, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: contrast ? 0 : 22,
            sigmaY: contrast ? 0 : 22,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: contrast ? 1 : .90),
                  Colors.white.withValues(alpha: contrast ? 1 : .72),
                  AppColors.page.withValues(alpha: contrast ? 1 : .88),
                ],
              ),
              border: Border(
                left: BorderSide(color: Colors.white.withValues(alpha: .85)),
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: SafeArea(
                left: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                      child: Row(
                        children: [
                          ArtCompanionPortrait(
                            size: 40,
                            pose: CompanionPose(paint: paint),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('随手用画具', style: AppText.title20),
                                const SizedBox(height: 3),
                                Text(
                                  '小画陪你 · 当前页面即用',
                                  style: AppText.caption12.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AppIconButton(
                            icon: Icons.close_rounded,
                            semanticLabel: '收起画具抽屉',
                            filled: false,
                            onTap: onClose,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (MediaQuery.sizeOf(context).height < 600)
                              Row(
                                children: [
                                  for (final tool in pageQuickTools)
                                    Expanded(
                                      child: Semantics(
                                        button: true,
                                        selected: state.tool == tool,
                                        label: '在当前页面使用${tool.label}',
                                        child: Tooltip(
                                          message: tool.label,
                                          excludeFromSemantics: true,
                                          child: InkWell(
                                            onTap: () =>
                                                controller.select(tool),
                                            borderRadius: AppRadius.br12,
                                            child: Container(
                                              height: 48,
                                              decoration: BoxDecoration(
                                                borderRadius: AppRadius.br12,
                                                color: state.tool == tool
                                                    ? AppColors.brandWash
                                                    : Colors.transparent,
                                              ),
                                              child: Icon(
                                                tool.icon,
                                                size: 20,
                                                color: state.tool == tool
                                                    ? AppColors.brand
                                                    : AppColors.ink,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            else
                              GridView.count(
                                crossAxisCount: 2,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 1.85,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                children: [
                                  for (final tool in pageQuickTools)
                                    Semantics(
                                      button: true,
                                      selected: state.tool == tool,
                                      label: '在当前页面使用${tool.label}',
                                      child: InkWell(
                                        borderRadius: AppRadius.br12,
                                        onTap: () => controller.select(tool),
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            borderRadius: AppRadius.br12,
                                            color: state.tool == tool
                                                ? AppColors.brandWash
                                                : Colors.white.withValues(
                                                    alpha: .35,
                                                  ),
                                            border: Border.all(
                                              color: state.tool == tool
                                                  ? AppColors.brand.withValues(
                                                      alpha: .35,
                                                    )
                                                  : Colors.white.withValues(
                                                      alpha: .6,
                                                    ),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    tool.icon,
                                                    size: 18,
                                                    color: state.tool == tool
                                                        ? AppColors.brand
                                                        : AppColors.ink,
                                                  ),
                                                  const SizedBox(width: 7),
                                                  Expanded(
                                                    child: Text(
                                                      tool ==
                                                              ArtTool
                                                                  .quickSketch
                                                          ? '速写计时'
                                                          : tool.label,
                                                      style: AppText.body14,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 5),
                                              Text(
                                                _hints[tool]!,
                                                style: AppText.caption12
                                                    .copyWith(
                                                      color: AppColors
                                                          .textSecondary,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            const SizedBox(height: 24),
                            if (state.tool == null) ...[
                              Text('把画具放在眼前', style: AppText.title16),
                              const SizedBox(height: 8),
                              Text(
                                '打开范画、作品或笔记后，轻点上方画具，直接在当前页面观察和练习。',
                                style: AppText.body14.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.7,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '收起抽屉，画具继续留在页面上。',
                                style: AppText.caption12.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      state.tool == ArtTool.quickSketch
                                          ? '速写计时'
                                          : state.tool!.label,
                                      style: AppText.title16,
                                    ),
                                  ),
                                  AppButton(
                                    label: '结束工具',
                                    onTap: controller.end,
                                    variant: AppButtonVariant.text,
                                    size: AppButtonSize.sm,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _ToolControls(state: state),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '精灵动态',
                                  style: AppText.caption12.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              Semantics(
                                label: '精灵动态',
                                child: Switch(
                                  value: ref.watch(companionMotionProvider),
                                  onChanged: (v) => ref
                                      .read(companionMotionProvider.notifier)
                                      .setMotion(v),
                                ),
                              ),
                            ],
                          ),
                          AppButton(
                            label: '进入完整工具箱 · 17 个工具',
                            icon: Icons.arrow_forward_rounded,
                            onTap: onAllTools,
                            variant: AppButtonVariant.secondary,
                            expand: true,
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
    );
  }
}

class _ToolControls extends ConsumerWidget {
  const _ToolControls({required this.state});
  final PageToolsState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(pageToolsProvider.notifier);
    Widget note(String text) => Text(
      text,
      style: AppText.caption12.copyWith(
        color: AppColors.textSecondary,
        height: 1.6,
      ),
    );
    Widget toggle(String title, bool value, ValueChanged<bool> onChanged) =>
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title, style: AppText.body14),
          value: value,
          onChanged: onChanged,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: switch (state.tool) {
        ArtTool.grid => [
          note('网格覆盖当前画面，可继续滚动页面找构图。'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final n in [3, 4, 6])
                ChoiceChip(
                  label: Text(n == 3 ? '九宫格' : '$n × $n'),
                  selected: state.grid == n,
                  onSelected: (_) => c.grid(n),
                ),
            ],
          ),
          toggle('浅色网格线', state.lightLines, c.lightLines),
          Text(
            '线条强度 ${(state.opacity * 100).round()}%',
            style: AppText.caption12,
          ),
          Slider(
            value: state.opacity,
            min: .15,
            max: 1,
            divisions: 17,
            label: '${(state.opacity * 100).round()}%',
            onChanged: c.opacity,
          ),
        ],
        ArtTool.value => [
          note('将当前页面转为灰度，观察明暗关系。收起抽屉可以查看完整画面。'),
          const SizedBox(height: 12),
          toggle('显示原页面', state.original, c.original),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Expanded(
                  child: Container(
                    height: 40,
                    color: Color.lerp(Colors.black, Colors.white, i / 4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          note('五阶明度参考 · 从暗到亮'),
        ],
        ArtTool.mirror => [
          note('翻转页面寻找形体偏差，文字也会随画面翻转。'),
          const SizedBox(height: 8),
          toggle('水平镜像', state.mirrorX, c.mirrorX),
          toggle('垂直翻转', state.mirrorY, c.mirrorY),
          toggle('显示原页面', state.original, c.original),
        ],
        ArtTool.measure => [
          note('拖动页面上的四个端点，对齐要比较的两条边。A 为紫色，B 为深色。'),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final size = MediaQuery.sizeOf(context);
              double distance(int i) {
                final d = state.points[i + 1] - state.points[i];
                return Offset(d.dx * size.width, d.dy * size.height).distance;
              }

              final a = distance(0), b = distance(2);
              return Text(
                'A : B = ${b < .1 ? '—' : (a / b).toStringAsFixed(2)} : 1',
                style: AppText.title20,
              );
            },
          ),
          const SizedBox(height: 12),
          note('长度为页面逻辑像素，用于相对比例比较，不作为实物尺寸。'),
        ],
        ArtTool.color => [
          note('轻点左侧页面取色。收起抽屉可取右侧区域；取色期间点击不会触发页面按钮。'),
          const SizedBox(height: 16),
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: state.color ?? AppColors.surfaceSubtle,
              borderRadius: AppRadius.br12,
              border: Border.all(color: AppColors.lineSoft),
            ),
          ),
          const SizedBox(height: 12),
          Text(state.hex, style: AppText.title20),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: '复制色值',
                  onTap: state.color == null
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: state.hex),
                          );
                          if (context.mounted) AppToast.show(context, '色值已复制');
                        },
                  variant: AppButtonVariant.secondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: '存入色卡',
                  onTap: state.color == null ? null : c.saveColor,
                  variant: AppButtonVariant.quiet,
                ),
              ),
            ],
          ),
          if (state.palette.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in state.palette)
                  Semantics(
                    button: true,
                    label: '选择色卡 ${color.toARGB32().toRadixString(16)}',
                    child: InkWell(
                      onTap: () => c.sample(color),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: AppRadius.br8,
                          border: Border.all(color: AppColors.lineSoft),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
        ArtTool.quickSketch => [
          note('保留眼前的范画或笔记，开始一轮限时练习。'),
          const SizedBox(height: 16),
          Text(state.clock, style: AppText.display32),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final seconds in [30, 60, 120, 300])
                ChoiceChip(
                  label: Text(seconds < 60 ? '30 秒' : '${seconds ~/ 60} 分钟'),
                  selected: state.duration == seconds,
                  onSelected: (_) => c.setDuration(seconds),
                ),
            ],
          ),
          const SizedBox(height: 16),
          AppButton(
            label: state.running
                ? '暂停计时'
                : state.seconds == 0
                ? '再练一轮'
                : '开始计时',
            onTap: state.running ? c.pause : c.start,
          ),
          const SizedBox(height: 8),
          AppButton(
            label: '重置计时',
            onTap: () => c.setDuration(state.duration),
            variant: AppButtonVariant.text,
          ),
          note(state.seconds == 0 ? '本轮结束，休息一下再继续。' : '收起抽屉后继续计时，页面底部显示剩余时间。'),
        ],
        _ => <Widget>[],
      },
    );
  }
}
