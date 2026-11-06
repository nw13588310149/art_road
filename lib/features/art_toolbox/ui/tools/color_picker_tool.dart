import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/theme/app_font.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../data/toolbox_catalog.dart';
import '../../data/toolbox_image_source.dart';
import '../../logic/image_ops.dart';
import '../widgets/image_tool_frame.dart';
import '../widgets/tool_panel.dart';

/// 取色与色卡：点击画面取色（HEX / RGB / HSB / 冷暖），自动提取 6 色主色卡。
class ColorPickerTool extends StatelessWidget {
  const ColorPickerTool({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ImageToolScaffold(
      tool: ArtTool.color,
      onBack: onBack,
      builder: (context, image) =>
          _ColorPickerBody(key: ValueKey(image.version), image: image),
    );
  }
}

class _ColorPickerBody extends StatefulWidget {
  const _ColorPickerBody({required this.image, super.key});

  final ToolboxImage image;

  @override
  State<_ColorPickerBody> createState() => _ColorPickerBodyState();
}

class _ColorPickerBodyState extends State<_ColorPickerBody> {
  final TransformationController _transform = TransformationController();
  ({int x, int y})? _picked;
  RgbColor? _color;
  List<PaletteSwatch>? _palette;

  @override
  void initState() {
    super.initState();
    _computePalette();
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Future<void> _computePalette() async {
    try {
      final palette = await compute(extractPalette, widget.image.data);
      if (mounted) {
        setState(() => _palette = palette);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _palette = const <PaletteSwatch>[]);
      }
    }
  }

  /// 点击位置是 InteractiveViewer 子组件坐标系（未缩放），按 contain 留白换算到像素。
  void _pick(Offset local, Size box) {
    final image = widget.image;
    final pixel = containPointToPixel(
      dx: local.dx,
      dy: local.dy,
      boxWidth: box.width,
      boxHeight: box.height,
      imageWidth: image.width,
      imageHeight: image.height,
    );
    if (pixel == null) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _picked = pixel;
      _color = pixelAt(image.data, pixel.x, pixel.y);
    });
  }

  Future<void> _copy(String hex) async {
    await Clipboard.setData(ClipboardData(text: hex));
    if (mounted) {
      AppToast.show(context, '已复制 $hex');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ImageToolLayout(stage: _buildStage, panel: _buildPanel);
  }

  Widget _buildStage(BuildContext context, bool wide) {
    return ToolStage(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final box = constraints.biggest;
            return Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    transformationController: _transform,
                    maxScale: 10,
                    child: SizedBox(
                      width: box.width,
                      height: box.height,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: RawImage(
                              image: widget.image.image,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (details) =>
                                  _pick(details.localPosition, box),
                            ),
                          ),
                          if (_picked != null && _color != null)
                            _buildMarker(box),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_picked == null)
                  const Positioned(
                    left: 0,
                    top: 0,
                    child: StageLabel('点击画面任意位置取色，双指放大可精确取色'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMarker(Size box) {
    final image = widget.image;
    final picked = _picked!;
    final point = pixelToContainPoint(
      x: picked.x,
      y: picked.y,
      boxWidth: box.width,
      boxHeight: box.height,
      imageWidth: image.width,
      imageHeight: image.height,
    );
    return AnimatedBuilder(
      animation: _transform,
      builder: (context, _) {
        final scale = _transform.value.getMaxScaleOnAxis().clamp(1.0, 100.0);
        final size = 30 / scale;
        return Positioned(
          left: point.dx - size / 2,
          top: point.dy - size / 2,
          width: size,
          height: size,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(_color!.argb),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3 / scale),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 6 / scale,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPanel(BuildContext context, bool wide) {
    final color = _color;
    final palette = _palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToolPanelSection(
          title: '取色结果',
          child: color == null
              ? Container(
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ArtColors.line),
                  ),
                  child: Text('点击画面取色', style: ArtText.caption(size: 13)),
                )
              : _PickedColorCard(
                  color: color,
                  position: _picked!,
                  onCopy: _copy,
                ),
        ),
        ToolPanelSection(
          title: '画面主色',
          trailing: Text('点击色块复制 HEX', style: ArtText.caption(size: 11)),
          child: palette == null
              ? const SizedBox(
                  height: 80,
                  child: Center(child: AppLoadingIndicator(size: 28)),
                )
              : palette.isEmpty
              ? Text('未能提取主色，请换一张图片试试', style: ArtText.caption())
              : _PaletteView(palette: palette, onCopy: _copy),
        ),
        const ToolTipCard(
          title: '用色卡读懂画面',
          text:
              '先看主色之间的冷暖与明度关系，再看点缀色如何与主色形成对比。'
              '临摹色彩范画时，可以先调出这几块主色，再开始铺大色块。',
        ),
      ],
    );
  }
}

class _PickedColorCard extends StatelessWidget {
  const _PickedColorCard({
    required this.color,
    required this.position,
    required this.onCopy,
  });

  final RgbColor color;
  final ({int x, int y}) position;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final hsb = color.toHsb();
    final temperature = describeTemperature(color);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ArtColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => onCopy(color.hex),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Color(color.argb),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ArtColors.line),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onCopy(color.hex),
                      child: Row(
                        children: [
                          Text(color.hex, style: ArtText.number(size: 18)),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.content_copy_rounded,
                            size: 14,
                            color: ArtColors.ink3,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RGB  ${color.r}, ${color.g}, ${color.b}',
                      style: ArtText.caption(color: ArtColors.ink2),
                    ),
                    Text(
                      'HSB  ${hsb.hue.round()}°, ${(hsb.saturation * 100).round()}%, '
                      '${(hsb.brightness * 100).round()}%',
                      style: ArtText.caption(color: ArtColors.ink2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _TemperatureChip(info: temperature),
              const Spacer(),
              Text(
                '像素 ${position.x}, ${position.y}',
                style: ArtText.caption(size: 11, color: ArtColors.ink4),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TemperatureChip extends StatelessWidget {
  const _TemperatureChip({required this.info});

  final ColorTemperatureInfo info;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, icon) = switch (info.temperature) {
      ColorTemperature.warm => (
        const Color(0xFFFFF0E5),
        const Color(0xFFD0651E),
        Icons.wb_sunny_outlined,
      ),
      ColorTemperature.cool => (
        const Color(0xFFE8F0FD),
        const Color(0xFF3F6BC9),
        Icons.ac_unit_rounded,
      ),
      ColorTemperature.neutral => (
        ArtColors.subtle,
        ArtColors.ink2,
        Icons.contrast_rounded,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(
            '${info.label} · ${info.family}',
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              color: foreground,
              fontWeight: AppFont.w500,
              fontFamily: 'PingFang SC',
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteView extends StatelessWidget {
  const _PaletteView({required this.palette, required this.onCopy});

  final List<PaletteSwatch> palette;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 28,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final swatch in palette)
                  Expanded(
                    flex: (swatch.ratio * 1000).round().clamp(1, 1000),
                    child: GestureDetector(
                      onTap: () => onCopy(swatch.color.hex),
                      child: ColoredBox(color: Color(swatch.color.argb)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        for (final swatch in palette)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onCopy(swatch.color.hex),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Color(swatch.color.argb),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ArtColors.line),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(swatch.color.hex, style: ArtText.number(size: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      describeTemperature(swatch.color).label,
                      style: ArtText.caption(size: 11),
                    ),
                  ),
                  Text(
                    '${(swatch.ratio * 100).toStringAsFixed(1)}%',
                    style: ArtText.number(size: 13, color: ArtColors.ink2),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
