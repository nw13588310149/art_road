import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../logic/color_harmony.dart';
import '../../logic/geometry.dart';
import '../../logic/image_ops.dart';
import '../widgets/tool_swatches.dart';
import 'viewer_tools_controller.dart';

/// 看图页深色底上的一行说明。
class ViewerNote extends StatelessWidget {
  const ViewerNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.body13.copyWith(color: AppColors.onCanvasDarkMuted),
    );
  }
}

/// 取到的颜色：色块、HEX、明度（0–100）、纯度和冷暖，HEX 可以复制。
class ViewerColorReadout extends StatelessWidget {
  const ViewerColorReadout({required this.controller, super.key});

  final ViewerToolsController controller;

  @override
  Widget build(BuildContext context) {
    final color = controller.picked;
    if (color == null) {
      return ViewerNote(controller.pickAt == null ? '点画面任意一处取色' : '正在读取颜色');
    }
    final attributes = colorAttributesOf(color);
    final temperature = describeTemperature(color);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Color(color.argb),
            borderRadius: AppRadius.br4,
            border: Border.all(color: AppColors.onCanvasDarkLine),
          ),
        ),
        const SizedBox(width: AppSpace.s12),
        Text(
          color.hex,
          style: AppText.number(size: 16, color: AppColors.onCanvasDark),
        ),
        AppIconAction(
          icon: Icons.content_copy_rounded,
          semanticLabel: '复制 ${color.hex}',
          size: 16,
          color: AppColors.onCanvasDarkMuted,
          onTap: () => copyHex(context, color.hex),
        ),
        const SizedBox(width: AppSpace.s8),
        Flexible(
          child: ViewerNote(
            [
              '明度 ${attributes.value}',
              '纯度 ${attributes.chroma}',
              if (!temperature.family.contains(temperature.label))
                temperature.label,
              temperature.family,
            ].join(' · '),
          ),
        ),
      ],
    );
  }
}

/// 比例测量：A 段为 1，显示 B 段的倍数和接近的整数比。
class ViewerMeasureReadout extends StatelessWidget {
  const ViewerMeasureReadout({required this.controller, super.key});

  final ViewerToolsController controller;

  @override
  Widget build(BuildContext context) {
    final points = controller.measurePoints.length;
    final lengths = controller.segmentLengths;
    final Widget text;
    if (lengths.length < 2) {
      text = ViewerNote(switch (points) {
        0 => '依次点两个点量出 A 段，再点两个点量出 B 段',
        1 => '再点一个点完成 A 段',
        2 => '再点两个点量出 B 段',
        _ => '再点一个点完成 B 段',
      });
    } else {
      final ratio = ratioTo(lengths[0], lengths[1]);
      final simple = ratio == null ? null : simpleRatioLabel(ratio);
      text = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'A : B = ',
            style: AppText.body14.copyWith(color: AppColors.onCanvasDark),
          ),
          Text(
            ratio == null ? '—' : '1 : ${ratio.toStringAsFixed(2)}',
            style: AppText.number(size: 16, color: AppColors.onCanvasDark),
          ),
          const SizedBox(width: AppSpace.s12),
          Flexible(
            child: ViewerNote(
              [if (simple != null) '接近 $simple', '再点一次重新量'].join(' · '),
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: text),
        if (points > 0) ...[
          const SizedBox(width: AppSpace.s8),
          AppPressable(
            onTap: controller.clearMeasure,
            semanticLabel: '清除测量线',
            child: ExcludeSemantics(
              child: SizedBox(
                height: 44,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
                  child: Center(
                    child: Text(
                      '清除',
                      style: AppText.body14.copyWith(
                        color: AppColors.onCanvasDark,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
