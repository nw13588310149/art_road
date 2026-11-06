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

/// 色块简化：把画面归纳成 3–12 种颜色，色卡列出每种颜色的面积占比。
class SimplifyTool extends StatelessWidget {
  const SimplifyTool({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ImageToolScaffold(
      tool: ArtTool.simplify,
      onBack: onBack,
      builder: (context, image) =>
          _SimplifyBody(key: ValueKey(image.version), image: image),
    );
  }
}

typedef _SimplifyParams = ({int colors, bool smooth});

class _SimplifyBody extends StatefulWidget {
  const _SimplifyBody({required this.image, super.key});

  final ToolboxImage image;

  @override
  State<_SimplifyBody> createState() => _SimplifyBodyState();
}

class _SimplifyBodyState extends State<_SimplifyBody>
    with
        DerivedImageState<_SimplifyBody, _SimplifyParams, List<PaletteSwatch>> {
  int _colors = 6;
  bool _smooth = true;
  bool _compare = false;

  @override
  _SimplifyParams get params => (colors: _colors, smooth: _smooth);

  @override
  Future<(ArtImageData, List<PaletteSwatch>)> process(
    _SimplifyParams params,
  ) async {
    final work = await widget.image.workData();
    final simplified = await compute(
      simplifyColors,
      SimplifyRequest(work, params.colors, smooth: params.smooth ? 2 : 0),
    );
    return (simplified.image, simplified.swatches);
  }

  @override
  Widget build(BuildContext context) {
    return ImageToolLayout(
      stage: (context, wide) => CompareStage(
        original: widget.image.image,
        processed: result?.image,
        label: '$_colors 色简化',
        compare: _compare,
        wide: wide,
        failed: failed,
        onRetry: reprocess,
      ),
      panel: _buildPanel,
    );
  }

  Widget _buildPanel(BuildContext context, bool wide) {
    final swatches = result?.info;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToolSliderRow(
          label: '颜色数',
          hint: '越少越概括',
          value: _colors.toDouble(),
          min: 3,
          max: 12,
          divisions: 9,
          valueLabel: '$_colors',
          onChanged: (v) {
            setState(() => _colors = v.round());
            reprocess();
          },
        ),
        ToolSwitchRow(
          label: '合并细碎色块',
          hint: '先轻微模糊再归纳，色块边缘更整',
          value: _smooth,
          onChanged: (v) {
            setState(() => _smooth = v);
            reprocess();
          },
        ),
        if (wide)
          ToolSwitchRow(
            label: '与原图并排对比',
            value: _compare,
            onChanged: (v) => setState(() => _compare = v),
          ),
        ToolPanelSection(
          title: '色块占比',
          trailing: const Text('点击复制 HEX'),
          child: swatches == null
              ? const AppSkeletonText(lines: 4, lineHeight: 20)
              : _SwatchList(swatches: swatches),
        ),
        const ToolTipCard(
          title: '先大色块，后细节',
          text:
              '把画面归纳成几块大色，看清主色调、色块的面积对比和位置。临摹色彩范画时，可以先调出占比较大的几块颜色铺大关系，'
              '再逐步增加颜色数，观察范画是怎样在大色块里做冷暖和明度变化的。',
        ),
      ],
    );
  }
}

class _SwatchList extends StatelessWidget {
  const _SwatchList({required this.swatches});

  final List<PaletteSwatch> swatches;

  @override
  Widget build(BuildContext context) {
    final percents = percentagesOf([for (final s in swatches) s.ratio]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RatioBar(
          colors: [for (final s in swatches) Color(s.color.argb)],
          ratios: [for (final s in swatches) s.ratio],
        ),
        const SizedBox(height: AppSpace.s8),
        for (var i = 0; i < swatches.length; i++)
          SwatchRow(
            color: Color(swatches[i].color.argb),
            hex: swatches[i].color.hex,
            caption: describeTemperature(swatches[i].color).label,
            trailing: '${percents[i]}%',
            onCopy: (hex) => copyHex(context, hex),
          ),
      ],
    );
  }
}
