import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/toolbox_catalog.dart';
import '../../data/toolbox_image_source.dart';
import '../../logic/image_filters.dart';
import '../../logic/image_ops.dart';
import '../widgets/image_job.dart';
import '../widgets/image_tool_frame.dart';
import '../widgets/tool_panel.dart';

/// 眯眼模糊：模糊掉细节只看大的形和色块，可同时去色，与原图对比。
class BlurTool extends StatelessWidget {
  const BlurTool({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ImageToolScaffold(
      tool: ArtTool.blur,
      onBack: onBack,
      builder: (context, image) =>
          _BlurBody(key: ValueKey(image.version), image: image),
    );
  }
}

typedef _BlurParams = ({int level, bool grayscale});

class _BlurBody extends StatefulWidget {
  const _BlurBody({required this.image, super.key});

  final ToolboxImage image;

  @override
  State<_BlurBody> createState() => _BlurBodyState();
}

class _BlurBodyState extends State<_BlurBody>
    with DerivedImageState<_BlurBody, _BlurParams, void> {
  int _level = 5;
  bool _grayscale = false;
  bool _compare = true;
  bool _peek = false;

  @override
  _BlurParams get params => (level: _level, grayscale: _grayscale);

  @override
  Future<(ArtImageData, void)> process(_BlurParams params) async {
    final work = await widget.image.workData();
    final radius = blurRadiusForLevel(
      params.level,
      math.max(work.width, work.height),
    );
    final data = await compute(
      blurImage,
      BlurRequest(work, radius, grayscale: params.grayscale),
    );
    return (data, null);
  }

  @override
  Widget build(BuildContext context) {
    return ImageToolLayout(
      stage: (context, wide) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _peek = true),
        onTapUp: (_) => setState(() => _peek = false),
        onTapCancel: () => setState(() => _peek = false),
        child: CompareStage(
          original: widget.image.image,
          processed: _peek ? widget.image.image : result?.image,
          label: _peek ? '原图' : (_grayscale ? '模糊 · 去色' : '模糊'),
          compare: _compare,
          wide: wide,
          failed: failed,
          onRetry: reprocess,
        ),
      ),
      panel: (context, wide) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ToolSliderRow(
            label: '模糊程度',
            hint: '越大越只剩大的形和色块',
            value: _level.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            valueLabel: '$_level',
            onChanged: (v) {
              setState(() => _level = v.round());
              reprocess();
            },
          ),
          ToolSwitchRow(
            label: '同时去色',
            hint: '只看明暗的大关系',
            value: _grayscale,
            onChanged: (v) {
              setState(() => _grayscale = v);
              reprocess();
            },
          ),
          if (wide)
            ToolSwitchRow(
              label: '与原图并排对比',
              value: _compare,
              onChanged: (v) => setState(() => _compare = v),
            ),
          Text('按住画面可临时查看原图', style: AppText.caption12),
          const SizedBox(height: AppSpace.s16),
          const ToolTipCard(
            title: '为什么要眯眼看',
            text:
                '眯起眼睛时细节消失，只剩大的形状、明暗和色块。模糊后主体依然突出、黑白灰分得开，说明大关系成立；'
                '如果一片模糊、分不清主次，就先调整整体，再回到细节。',
          ),
        ],
      ),
    );
  }
}
