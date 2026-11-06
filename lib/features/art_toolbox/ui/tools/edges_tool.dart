import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/toolbox_catalog.dart';
import '../../data/toolbox_image_source.dart';
import '../../logic/image_filters.dart';
import '../../logic/image_ops.dart';
import '../widgets/image_job.dart';
import '../widgets/image_tool_frame.dart';
import '../widgets/tool_panel.dart';

/// 轮廓线稿：Sobel 边缘检测，白底深色线条，检查结构与比例。
class EdgesTool extends StatelessWidget {
  const EdgesTool({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ImageToolScaffold(
      tool: ArtTool.edges,
      onBack: onBack,
      builder: (context, image) =>
          _EdgesBody(key: ValueKey(image.version), image: image),
    );
  }
}

typedef _EdgeParams = ({int threshold, int smooth});

class _EdgesBody extends StatefulWidget {
  const _EdgesBody({required this.image, super.key});

  final ToolboxImage image;

  @override
  State<_EdgesBody> createState() => _EdgesBodyState();
}

class _EdgesBodyState extends State<_EdgesBody>
    with DerivedImageState<_EdgesBody, _EdgeParams, void> {
  int _threshold = 48;
  int _smooth = 1;
  bool _compare = false;

  @override
  _EdgeParams get params => (threshold: _threshold, smooth: _smooth);

  @override
  Future<(ArtImageData, void)> process(_EdgeParams params) async {
    final work = await widget.image.workData();
    final data = await compute(
      edgeSketch,
      EdgeRequest(work, params.threshold, smooth: params.smooth),
    );
    return (data, null);
  }

  @override
  Widget build(BuildContext context) {
    return ImageToolLayout(
      stage: (context, wide) => CompareStage(
        original: widget.image.image,
        processed: result?.image,
        label: '轮廓线稿',
        compare: _compare,
        wide: wide,
        failed: failed,
        onRetry: reprocess,
      ),
      panel: (context, wide) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ToolSliderRow(
            label: '线条阈值',
            hint: '越大线条越少，只留下明显的边缘',
            value: _threshold.toDouble(),
            min: 10,
            max: 160,
            divisions: 150,
            valueLabel: '$_threshold',
            onChanged: (v) {
              setState(() => _threshold = v.round());
              reprocess();
            },
          ),
          ToolSliderRow(
            label: '概括程度',
            hint: '越大越忽略纹理和笔触，只保留大的结构线',
            value: _smooth.toDouble(),
            min: 0,
            max: 4,
            divisions: 4,
            valueLabel: '$_smooth',
            onChanged: (v) {
              setState(() => _smooth = v.round());
              reprocess();
            },
          ),
          if (wide)
            ToolSwitchRow(
              label: '与原图并排对比',
              value: _compare,
              onChanged: (v) => setState(() => _compare = v),
            ),
          const ToolTipCard(
            title: '用线稿检查结构',
            text:
                '线稿只保留明暗变化明显的边缘，去掉调子后更容易看出外轮廓、结构线和比例是否准确。'
                '线条断断续续时调低阈值，杂线太多时调高阈值或加大概括程度。'
                '也可以和镜像翻转配合，检查左右是否对称。',
          ),
        ],
      ),
    );
  }
}
