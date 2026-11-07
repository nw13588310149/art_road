import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/toolbox_catalog.dart';
import '../../data/toolbox_image_source.dart';
import '../../logic/color_analysis.dart';
import '../../logic/image_ops.dart';
import '../widgets/image_job.dart';
import '../widgets/image_tool_frame.dart';
import '../widgets/tool_panel.dart';

/// 冷暖分布：暖色显示为橙、冷色为蓝、中性灰为灰，统计面积占比。
class TemperatureTool extends StatelessWidget {
  const TemperatureTool({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ImageToolScaffold(
      tool: ArtTool.temperature,
      onBack: onBack,
      builder: (context, image) =>
          _TemperatureBody(key: ValueKey(image.version), image: image),
    );
  }
}

typedef _TemperatureParams = ({int neutralChroma, bool keepShading});
typedef _TemperatureShares = ({double warm, double cool, double neutral});

class _TemperatureBody extends StatefulWidget {
  const _TemperatureBody({required this.image, super.key});

  final ToolboxImage image;

  @override
  State<_TemperatureBody> createState() => _TemperatureBodyState();
}

class _TemperatureBodyState extends State<_TemperatureBody>
    with
        DerivedImageState<
          _TemperatureBody,
          _TemperatureParams,
          _TemperatureShares
        > {
  int _neutralChroma = kDefaultNeutralChroma;
  bool _keepShading = true;
  bool _compare = true;

  @override
  _TemperatureParams get params =>
      (neutralChroma: _neutralChroma, keepShading: _keepShading);

  @override
  Future<(ArtImageData, _TemperatureShares)> process(
    _TemperatureParams params,
  ) async {
    final work = await widget.image.workData();
    final map = await compute(
      temperatureMap,
      TemperatureRequest(
        work,
        neutralChroma: params.neutralChroma,
        keepShading: params.keepShading,
      ),
    );
    return (map.image, (warm: map.warm, cool: map.cool, neutral: map.neutral));
  }

  @override
  Widget build(BuildContext context) {
    return ImageToolLayout(
      stage: (context) => CompareStage(
        original: widget.image.image,
        processed: result?.image,
        label: '冷暖分布',
        compare: _compare,
        failed: failed,
        onRetry: reprocess,
      ),
      panel: _buildPanel,
    );
  }

  Widget _buildPanel(BuildContext context) {
    final shares = result?.info;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToolPanelSection(
          title: '冷暖占比',
          child: shares == null
              ? const AppSkeletonText(lines: 3, lineHeight: 20)
              : _TemperatureShareView(shares: shares),
        ),
        ToolSliderRow(
          label: '中性灰范围',
          hint: '越大越多低纯度的颜色算作中性灰',
          value: _neutralChroma.toDouble(),
          min: 8,
          max: 64,
          divisions: 56,
          valueLabel: '$_neutralChroma',
          onChanged: (v) {
            setState(() => _neutralChroma = v.round());
            reprocess();
          },
        ),
        ToolSwitchRow(
          label: '保留明暗',
          hint: '颜色随原图明暗深浅变化，便于对照形体',
          value: _keepShading,
          onChanged: (v) {
            setState(() => _keepShading = v);
            reprocess();
          },
        ),
        ToolSwitchRow(
          label: '与原图并排对比',
          value: _compare,
          onChanged: (v) => setState(() => _compare = v),
        ),
        const ToolTipCard(
          title: '怎样看冷暖',
          text:
              '冷暖是相对的，同一块颜色挨着更冷的颜色会显得暖。写生时受光面与背光面的冷暖往往相反：'
              '暖光下亮部偏暖，暗部和投影偏冷；环境色也会让暗部带上周围颜色的倾向。'
              '建议画面有明确的主色调，冷暖一方占主导，另一方作对比。',
        ),
        const SizedBox(height: AppSpace.s12),
        const ToolTipCard(
          title: '判断标准',
          icon: Icons.rule_rounded,
          text: '暖：红、橙、黄、黄绿、紫红；冷：绿、青、蓝、蓝紫；纯度很低或很暗的颜色算中性灰。',
        ),
      ],
    );
  }
}

class _TemperatureShareView extends StatelessWidget {
  const _TemperatureShareView({required this.shares});

  final _TemperatureShares shares;

  @override
  Widget build(BuildContext context) {
    final ratios = [shares.warm, shares.cool, shares.neutral];
    final percents = percentagesOf(ratios);
    final colors = [
      Color(kWarmMapColor.argb),
      Color(kCoolMapColor.argb),
      Color(kNeutralMapColor.argb),
    ];
    const names = ['暖色', '冷色', '中性灰'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RatioBar(colors: colors, ratios: ratios),
        const SizedBox(height: AppSpace.s12),
        Row(
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: colors[i],
                            borderRadius: AppRadius.br4,
                          ),
                        ),
                        const SizedBox(width: AppSpace.s4),
                        Text(names[i], style: AppText.caption12),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${percents[i]}%', style: AppText.number(size: 20)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.s8),
        Text(
          temperatureSummary(shares.warm, shares.cool, shares.neutral),
          style: AppText.body13,
        ),
      ],
    );
  }
}
