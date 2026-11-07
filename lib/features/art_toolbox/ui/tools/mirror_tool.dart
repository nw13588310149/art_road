import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';
import '../../data/toolbox_catalog.dart';
import '../../data/toolbox_image_source.dart';
import '../../logic/image_filters.dart';
import '../widgets/image_tool_frame.dart';
import '../widgets/tool_panel.dart';

/// 镜像翻转：左右 / 上下翻转与反相，借「新鲜的眼睛」检查比例、透视与明暗。
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
  bool _invert = false;
  bool _compare = false;
  Timer? _alternate;
  ui.Image? _inverted;
  bool _invertBusy = false;
  bool _failed = false;

  @override
  void dispose() {
    _alternate?.cancel();
    _inverted?.dispose();
    super.dispose();
  }

  Future<void> _computeInverted() async {
    if (_inverted != null || _invertBusy) {
      return;
    }
    _invertBusy = true;
    try {
      final data = await compute(invert, widget.image.data);
      final image = await artImageToUiImage(data);
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _inverted = image);
    } catch (_) {
      if (mounted) {
        setState(() => _failed = true);
      }
    } finally {
      _invertBusy = false;
    }
  }

  void _setInvert(bool value) {
    setState(() {
      _invert = value;
      _failed = false;
    });
    if (value) {
      _computeInverted();
    }
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

  void _stopAlternate() {
    _alternate?.cancel();
    _alternate = null;
  }

  void _reset() {
    _stopAlternate();
    setState(() {
      _horizontal = false;
      _vertical = false;
      _invert = false;
    });
  }

  String get _label {
    final parts = <String>[
      if (_horizontal && _vertical)
        '上下左右翻转'
      else if (_horizontal)
        '左右镜像'
      else if (_vertical)
        '上下翻转',
      if (_invert) '反相',
    ];
    return parts.isEmpty ? '原图' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return ImageToolLayout(stage: _buildStage, panel: _buildPanel);
  }

  Widget _buildStage(BuildContext context) {
    final shown = _invert ? _inverted : widget.image.image;
    final mirrored = ToolStage(
      child: Stack(
        children: [
          Positioned.fill(
            child: shown == null
                ? StageImagePane(
                    image: null,
                    failed: _failed,
                    onRetry: () => _setInvert(true),
                  )
                : Padding(
                    padding: const EdgeInsets.all(AppSpace.s12),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(
                        _horizontal ? -1 : 1,
                        _vertical ? -1 : 1,
                        1,
                      ),
                      child: RawImage(
                        image: shown,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
          ),
          Positioned(
            left: AppSpace.s12,
            top: AppSpace.s12,
            child: StageLabel(_label),
          ),
        ],
      ),
    );
    if (!_compare) {
      return mirrored;
    }
    return Row(
      children: [
        Expanded(
          child: ToolStage(
            child: StageImagePane(image: widget.image.image, label: '原图'),
          ),
        ),
        const SizedBox(width: AppSpace.s12),
        Expanded(child: mirrored),
      ],
    );
  }

  Widget _buildPanel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToolSwitchRow(
          label: '左右镜像',
          hint: '常用：检查中轴线、五官与形体是否对称',
          value: _horizontal,
          onChanged: (v) {
            _stopAlternate();
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
          label: '反相',
          hint: '黑白颠倒、颜色取补，单独检查明暗与形状',
          value: _invert,
          onChanged: _setInvert,
        ),
        ToolSwitchRow(
          label: '自动交替',
          hint: '每 2 秒左右翻转一次，来回对照',
          value: _alternate != null,
          onChanged: _setAlternate,
        ),
        ToolSwitchRow(
          label: '与原图并排对比',
          value: _compare,
          onChanged: (v) => setState(() => _compare = v),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            label: '恢复原图',
            icon: Icons.restart_alt_rounded,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.sm,
            onTap: _horizontal || _vertical || _invert || _alternate != null
                ? _reset
                : null,
          ),
        ),
        const SizedBox(height: AppSpace.s20),
        const ToolTipCard(
          title: '翻转后更容易发现问题',
          text:
              '画久了眼睛会适应错误。把画面翻转过来，相当于换一双新鲜的眼睛：歪斜的中轴线、'
              '不对称的五官、不统一的透视和偏向一侧的构图会立刻显现。建议每画半小时翻转检查一次。'
              '反相后亮暗互换，适合检查剪影外形和明暗块面是否清楚。',
        ),
      ],
    );
  }
}
