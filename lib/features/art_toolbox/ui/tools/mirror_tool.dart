import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/art_widgets.dart';
import '../../data/toolbox_catalog.dart';
import '../../data/toolbox_image_source.dart';
import '../widgets/image_tool_frame.dart';
import '../widgets/tool_panel.dart';

/// 镜像翻转：左右 / 上下翻转画面，借「新鲜的眼睛」检查比例与透视。
class MirrorTool extends StatelessWidget {
  const MirrorTool({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ImageToolScaffold(
      tool: ArtTool.mirror,
      onBack: onBack,
      builder: (context, image) =>
          _MirrorBody(key: ValueKey(image.version), image: image),
    );
  }
}

class _MirrorBody extends StatefulWidget {
  const _MirrorBody({required this.image, super.key});

  final ToolboxImage image;

  @override
  State<_MirrorBody> createState() => _MirrorBodyState();
}

class _MirrorBodyState extends State<_MirrorBody> {
  bool _horizontal = false;
  bool _vertical = false;
  bool _compare = false;
  Timer? _alternate;

  @override
  void dispose() {
    _alternate?.cancel();
    super.dispose();
  }

  void _setAlternate(bool enabled) {
    _alternate?.cancel();
    _alternate = enabled
        ? Timer.periodic(
            const Duration(seconds: 2),
            (_) => setState(() => _horizontal = !_horizontal),
          )
        : null;
    setState(() {});
  }

  void _reset() {
    _alternate?.cancel();
    _alternate = null;
    setState(() {
      _horizontal = false;
      _vertical = false;
    });
  }

  String get _label {
    if (_horizontal && _vertical) {
      return '上下左右翻转';
    }
    if (_horizontal) {
      return '左右镜像';
    }
    return _vertical ? '上下翻转' : '原图';
  }

  @override
  Widget build(BuildContext context) {
    return ImageToolLayout(stage: _buildStage, panel: _buildPanel);
  }

  Widget _buildStage(BuildContext context, bool wide) {
    final mirrored = ToolStage(
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TweenAnimationBuilder<Offset>(
                tween: Tween<Offset>(
                  end: Offset(_horizontal ? -1 : 1, _vertical ? -1 : 1),
                ),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeInOutCubic,
                builder: (context, scale, child) => Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.diagonal3Values(scale.dx, scale.dy, 1),
                  child: child,
                ),
                child: RawImage(
                  image: widget.image.image,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
          Positioned(left: 12, top: 12, child: StageLabel(_label)),
          const Positioned(
            right: 12,
            bottom: 12,
            child: StageLabel('镜像后更容易发现比例与透视问题'),
          ),
        ],
      ),
    );
    if (!wide || !_compare) {
      return mirrored;
    }
    return Row(
      children: [
        Expanded(
          child: ToolStage(
            child: StageImagePane(image: widget.image.image, label: '原图'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: mirrored),
      ],
    );
  }

  Widget _buildPanel(BuildContext context, bool wide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToolSwitchRow(
          label: '左右镜像',
          hint: '最常用：检查中轴线、五官与形体是否对称',
          value: _horizontal,
          onChanged: (v) {
            _alternate?.cancel();
            _alternate = null;
            setState(() => _horizontal = v);
          },
        ),
        ToolSwitchRow(
          label: '上下翻转',
          hint: '打破对内容的熟悉感，只看形状与明暗',
          value: _vertical,
          onChanged: (v) => setState(() => _vertical = v),
        ),
        ToolSwitchRow(
          label: '自动交替',
          hint: '每 2 秒左右翻转一次，来回对照',
          value: _alternate != null,
          onChanged: _setAlternate,
        ),
        if (wide)
          ToolSwitchRow(
            label: '与原图并排对比',
            value: _compare,
            onChanged: (v) => setState(() => _compare = v),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: ArtButton(
            label: '恢复原图',
            icon: Icons.restart_alt_rounded,
            primary: false,
            height: 34,
            onTap: _reset,
          ),
        ),
        const SizedBox(height: 18),
        const ToolTipCard(
          title: '镜像后更容易发现比例与透视问题',
          text:
              '画久了眼睛会「适应」错误。把画面翻转过来，相当于换一双新鲜的眼睛：歪斜的中轴线、'
              '不对称的五官、不统一的透视和偏向一侧的构图会立刻显现。建议每画半小时翻转检查一次。',
        ),
      ],
    );
  }
}
