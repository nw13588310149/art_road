import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/ui/ui.dart';
import '../../data/toolbox_catalog.dart';
import '../../state/page_tools_controller.dart';

const pageQuickTools = [
  ArtTool.grid,
  ArtTool.value,
  ArtTool.mirror,
  ArtTool.measure,
  ArtTool.color,
  ArtTool.quickSketch,
];

class PageToolOptions extends ConsumerWidget {
  const PageToolOptions({required this.state, super.key});
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
                AppChip(
                  label: n == 3 ? '九宫格' : '$n × $n',
                  selected: state.grid == n,
                  onTap: () => c.grid(n),
                ),
            ],
          ),
          toggle('浅色网格线', state.lightLines, c.lightLines),
          Text(
            '线条强度 ${(state.opacity * 100).round()}%',
            style: AppText.caption12,
          ),
          SizedBox(
            height: 44,
            child: Overlay.wrap(
              child: SliderTheme(
                data: SliderTheme.of(
                  context,
                ).copyWith(showValueIndicator: ShowValueIndicator.never),
                child: Slider(
                  value: state.opacity,
                  min: .15,
                  max: 1,
                  divisions: 17,
                  label: '${(state.opacity * 100).round()}%',
                  onChangeStart: (_) => c.checkpoint(),
                  onChanged: c.opacity,
                ),
              ),
            ),
          ),
        ],
        ArtTool.value => [
          note('将当前页面转为灰度，观察明暗关系。收起参数可以查看完整画面。'),
          const SizedBox(height: 12),
          toggle('显示原页面', state.original, c.original),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Expanded(
                  child: Container(
                    height: 44,
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
          note('轻点画面取色；取色期间不会触发页面按钮。点击箭头工具可恢复页面操作。'),
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
                    child: AppPressable(
                      onTap: () => c.sample(color),
                      child: Container(
                        width: 44,
                        height: 44,
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
                AppChip(
                  label: seconds < 60 ? '30 秒' : '${seconds ~/ 60} 分钟',
                  selected: state.duration == seconds,
                  onTap: () => c.setDuration(seconds),
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
          note(state.seconds == 0 ? '本轮结束，休息一下再继续。' : '收起参数后继续计时，页面底部显示剩余时间。'),
        ],
        _ => <Widget>[],
      },
    );
  }
}
