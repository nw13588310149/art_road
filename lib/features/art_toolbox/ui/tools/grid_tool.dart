import 'package:flutter/material.dart';

import '../../../../core/art/art_tokens.dart';
import '../../../../core/widgets/art_widgets.dart';
import '../../data/toolbox_catalog.dart';
import '../../data/toolbox_image_source.dart';
import '../widgets/image_tool_frame.dart';
import '../widgets/tool_panel.dart';

/// 构图网格：九宫格 / 4×4 / 自定义行列，可叠加对角线与格子编号，双指缩放时网格随画面同步。
class GridTool extends StatelessWidget {
  const GridTool({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ImageToolScaffold(
      tool: ArtTool.grid,
      onBack: onBack,
      builder: (context, image) =>
          _GridBody(key: ValueKey(image.version), image: image),
    );
  }
}

enum _GridPreset {
  thirds('九宫格'),
  four('4×4'),
  custom('自定义');

  const _GridPreset(this.label);

  final String label;
}

enum _LineColor {
  white('白', Colors.white),
  black('黑', Color(0xFF16141C)),
  red('红', Color(0xFFE5484D)),
  purple('紫', ArtColors.brand);

  const _LineColor(this.label, this.color);

  final String label;
  final Color color;
}

class _GridBody extends StatefulWidget {
  const _GridBody({required this.image, super.key});

  final ToolboxImage image;

  @override
  State<_GridBody> createState() => _GridBodyState();
}

class _GridBodyState extends State<_GridBody> {
  final TransformationController _transform = TransformationController();
  _GridPreset _preset = _GridPreset.thirds;
  int _rows = 6;
  int _cols = 6;
  bool _diagonal = false;
  bool _labels = false;
  _LineColor _lineColor = _LineColor.white;
  double _opacity = 0.85;

  int get _rowCount => switch (_preset) {
    _GridPreset.thirds => 3,
    _GridPreset.four => 4,
    _GridPreset.custom => _rows,
  };

  int get _colCount => switch (_preset) {
    _GridPreset.thirds => 3,
    _GridPreset.four => 4,
    _GridPreset.custom => _cols,
  };

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ImageToolLayout(stage: _buildStage, panel: _buildPanel);
  }

  Widget _buildStage(BuildContext context, bool wide) {
    final image = widget.image;
    return ToolStage(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fitted = applyBoxFit(
            BoxFit.contain,
            Size(image.width.toDouble(), image.height.toDouble()),
            Size(
              (constraints.maxWidth - 24).clamp(1.0, double.infinity),
              (constraints.maxHeight - 24).clamp(1.0, double.infinity),
            ),
          ).destination;
          return Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _transform,
                  maxScale: 8,
                  child: Center(
                    child: SizedBox(
                      width: fitted.width,
                      height: fitted.height,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          RawImage(
                            image: image.image,
                            fit: BoxFit.fill,
                            filterQuality: FilterQuality.medium,
                          ),
                          CustomPaint(
                            painter: _GridPainter(
                              rows: _rowCount,
                              cols: _colCount,
                              diagonal: _diagonal,
                              labels: _labels,
                              thirdsPoints: _preset == _GridPreset.thirds,
                              color: _lineColor.color,
                              opacity: _opacity,
                              transform: _transform,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: StageLabel('$_rowCount × $_colCount 网格'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPanel(BuildContext context, bool wide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToolPanelSection(
          title: '网格',
          child: ArtSegmentTabs<_GridPreset>(
            items: _GridPreset.values,
            value: _preset,
            labelOf: (p) => p.label,
            onChanged: (p) => setState(() => _preset = p),
          ),
        ),
        if (_preset == _GridPreset.custom) ...[
          ToolSliderRow(
            label: '行数',
            value: _rows.toDouble(),
            min: 2,
            max: 12,
            divisions: 10,
            valueLabel: '$_rows',
            onChanged: (v) => setState(() => _rows = v.round()),
          ),
          ToolSliderRow(
            label: '列数',
            value: _cols.toDouble(),
            min: 2,
            max: 12,
            divisions: 10,
            valueLabel: '$_cols',
            onChanged: (v) => setState(() => _cols = v.round()),
          ),
          const SizedBox(height: 8),
        ],
        ToolSwitchRow(
          label: '对角线',
          hint: '检查主体是否落在对角构图线上',
          value: _diagonal,
          onChanged: (v) => setState(() => _diagonal = v),
        ),
        ToolSwitchRow(
          label: '格子编号',
          hint: '列 A、B、C…，行 1、2、3…，方便对照临摹',
          value: _labels,
          onChanged: (v) => setState(() => _labels = v),
        ),
        ToolPanelSection(
          title: '线条颜色',
          child: Row(
            children: [
              for (final color in _LineColor.values) ...[
                _ColorDot(
                  color: color.color,
                  label: color.label,
                  selected: color == _lineColor,
                  onTap: () => setState(() => _lineColor = color),
                ),
                const SizedBox(width: 12),
              ],
            ],
          ),
        ),
        ToolSliderRow(
          label: '不透明度',
          value: _opacity,
          min: 0.2,
          max: 1,
          valueLabel: '${(_opacity * 100).round()}%',
          onChanged: (v) => setState(() => _opacity = v),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: ArtButton(
            label: '复位缩放',
            icon: Icons.zoom_out_map_rounded,
            primary: false,
            height: 34,
            onTap: () => _transform.value = Matrix4.identity(),
          ),
        ),
        const SizedBox(height: 18),
        const ToolTipCard(
          title: '临摹小技巧',
          text:
              '在画纸上画出同样行列的网格，按格子对位找关键点：先定大的比例与位置，再深入细节。'
              '双指缩放查看局部时，网格始终与画面对齐。',
        ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final light = color.computeLuminance() > 0.5;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? ArtColors.brandDeep : ArtColors.ink4,
                width: selected ? 2.5 : 1,
              ),
            ),
            child: selected
                ? Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: light ? ArtColors.ink : Colors.white,
                  )
                : null,
          ),
          const SizedBox(height: 4),
          Text(label, style: ArtText.caption(size: 11)),
        ],
      ),
    );
  }
}

/// 网格画在与图片等大的区域上；线宽与文字按当前缩放倍数反向补偿，放大后仍保持细线。
class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.rows,
    required this.cols,
    required this.diagonal,
    required this.labels,
    required this.thirdsPoints,
    required this.color,
    required this.opacity,
    required this.transform,
  }) : super(repaint: transform);

  final int rows;
  final int cols;
  final bool diagonal;
  final bool labels;
  final bool thirdsPoints;
  final Color color;
  final double opacity;
  final TransformationController transform;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = transform.value.getMaxScaleOnAxis().clamp(1.0, 100.0);
    final lineColor = color.withValues(alpha: opacity);
    final haloColor =
        (color.computeLuminance() > 0.5 ? Colors.black : Colors.white)
            .withValues(alpha: opacity * 0.28);
    final line = Paint()
      ..color = lineColor
      ..strokeWidth = 1.4 / scale
      ..style = PaintingStyle.stroke;
    final halo = Paint()
      ..color = haloColor
      ..strokeWidth = 3.2 / scale
      ..style = PaintingStyle.stroke;

    void drawLine(Offset a, Offset b) {
      canvas
        ..drawLine(a, b, halo)
        ..drawLine(a, b, line);
    }

    for (var i = 1; i < cols; i++) {
      final x = size.width * i / cols;
      drawLine(Offset(x, 0), Offset(x, size.height));
    }
    for (var j = 1; j < rows; j++) {
      final y = size.height * j / rows;
      drawLine(Offset(0, y), Offset(size.width, y));
    }
    canvas.drawRect(Offset.zero & size, line);
    if (diagonal) {
      drawLine(Offset.zero, Offset(size.width, size.height));
      drawLine(Offset(size.width, 0), Offset(0, size.height));
    }
    if (thirdsPoints && rows == 3 && cols == 3) {
      final dot = Paint()..color = lineColor;
      final dotHalo = Paint()..color = haloColor;
      for (var i = 1; i <= 2; i++) {
        for (var j = 1; j <= 2; j++) {
          final center = Offset(size.width * i / 3, size.height * j / 3);
          canvas
            ..drawCircle(center, 6 / scale, dotHalo)
            ..drawCircle(center, 4 / scale, dot);
        }
      }
    }
    if (labels) {
      _paintLabels(canvas, size, scale, lineColor, haloColor);
    }
  }

  void _paintLabels(
    Canvas canvas,
    Size size,
    double scale,
    Color textColor,
    Color haloColor,
  ) {
    final style = TextStyle(
      color: textColor,
      fontSize: 11 / scale,
      fontWeight: FontWeight.w500,
      fontFamily: 'Manrope',
      shadows: [Shadow(color: haloColor, blurRadius: 3 / scale)],
    );
    void paintText(String text, Offset Function(Size textSize) position) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, position(painter.size));
      painter.dispose();
    }

    final margin = 4 / scale;
    for (var c = 0; c < cols; c++) {
      final x = size.width * (c + 0.5) / cols;
      paintText(
        String.fromCharCode(65 + c),
        (s) => Offset(x - s.width / 2, margin),
      );
    }
    for (var r = 0; r < rows; r++) {
      final y = size.height * (r + 0.5) / rows;
      paintText('${r + 1}', (s) => Offset(margin, y - s.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.rows != rows ||
      old.cols != cols ||
      old.diagonal != diagonal ||
      old.labels != labels ||
      old.thirdsPoints != thirdsPoints ||
      old.color != color ||
      old.opacity != opacity ||
      old.transform != transform;
}
