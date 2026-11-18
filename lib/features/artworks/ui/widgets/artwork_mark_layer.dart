import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/ui/ui.dart';

/// 图上一处定点点评的编号点。
@immutable
class ArtworkMarkPin {
  const ArtworkMarkPin({
    required this.key,
    required this.position,
    required this.number,
    required this.semanticLabel,
  });

  final String key;

  /// 按图片宽高归一化的位置（0–1）。
  final Offset position;
  final int number;
  final String semanticLabel;
}

/// 作品图上的定点点评编号，放在 `ArtworkAnnotatedImage.overlay` 里，和图片
/// 一起缩放平移。编号点的大小不随缩放变化（传入 [zoom]）。
///
/// - [onTapPin]：点编号；
/// - [onMovePin]：传入时编号可以拖动，松手时回调新位置；
/// - [onTapBlank]：传入时点图上空白处回调那个位置（老师加一处点评）。
class ArtworkMarkLayer extends StatefulWidget {
  const ArtworkMarkLayer({
    required this.pins,
    this.selectedKey,
    this.onTapPin,
    this.onMovePin,
    this.onTapBlank,
    this.zoom,
    this.selectedLink,
    this.tapGroup,
    super.key,
  });

  final List<ArtworkMarkPin> pins;
  final String? selectedKey;
  final ValueChanged<String>? onTapPin;
  final void Function(String key, Offset position)? onMovePin;
  final ValueChanged<Offset>? onTapBlank;

  /// 图片所在的缩放变换；编号点按它的倍数反向缩放。
  final ValueListenable<Matrix4>? zoom;

  /// 选中的编号点挂在这个 [LayerLink] 上，浮层跟着它定位。
  final LayerLink? selectedLink;

  /// 编号点算作这个 [TapRegion] 组的一部分：点它们不会关掉同组的浮层。
  final Object? tapGroup;

  /// 编号点的点击区域；看得见的圆点更小。
  static const double hitExtent = 44;

  @override
  State<ArtworkMarkLayer> createState() => _ArtworkMarkLayerState();
}

class _ArtworkMarkLayerState extends State<ArtworkMarkLayer> {
  final _stackKey = GlobalKey();
  String? _dragKey;
  Offset _dragPosition = Offset.zero;
  Offset _grab = Offset.zero;

  RenderBox? get _box =>
      _stackKey.currentContext?.findRenderObject() as RenderBox?;

  static Offset _normalize(Offset local, Size size) => Offset(
    (local.dx / size.width).clamp(0.0, 1.0),
    (local.dy / size.height).clamp(0.0, 1.0),
  );

  void _startDrag(ArtworkMarkPin pin, DragStartDetails details) {
    final box = _box;
    if (box == null || !box.hasSize) {
      return;
    }
    final size = box.size;
    final center = Offset(
      pin.position.dx * size.width,
      pin.position.dy * size.height,
    );
    setState(() {
      _dragKey = pin.key;
      _dragPosition = pin.position;
      _grab = box.globalToLocal(details.globalPosition) - center;
    });
  }

  void _updateDrag(DragUpdateDetails details) {
    final box = _box;
    if (_dragKey == null || box == null || !box.hasSize) {
      return;
    }
    final local = box.globalToLocal(details.globalPosition) - _grab;
    setState(() => _dragPosition = _normalize(local, box.size));
  }

  void _endDrag() {
    final key = _dragKey;
    if (key == null) {
      return;
    }
    final position = _dragPosition;
    setState(() => _dragKey = null);
    widget.onMovePin?.call(key, position);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final onTapBlank = widget.onTapBlank;
        Widget layer = Stack(
          key: _stackKey,
          clipBehavior: Clip.none,
          children: [
            if (onTapBlank != null)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) =>
                      onTapBlank(_normalize(details.localPosition, size)),
                ),
              ),
            for (final pin in widget.pins) _buildPin(pin, size),
          ],
        );
        final group = widget.tapGroup;
        if (group != null) {
          layer = TapRegion(groupId: group, child: layer);
        }
        return layer;
      },
    );
  }

  Widget _buildPin(ArtworkMarkPin pin, Size size) {
    const half = ArtworkMarkLayer.hitExtent / 2;
    final dragging = pin.key == _dragKey;
    final position = dragging ? _dragPosition : pin.position;
    final selected = pin.key == widget.selectedKey || dragging;
    final onTapPin = widget.onTapPin;
    final movable = widget.onMovePin != null;
    Widget child = Semantics(
      container: true,
      button: onTapPin != null,
      selected: selected,
      label: pin.semanticLabel,
      onTap: onTapPin == null ? null : () => onTapPin(pin.key),
      child: MouseRegion(
        cursor: movable
            ? SystemMouseCursors.move
            : (onTapPin == null ? MouseCursor.defer : SystemMouseCursors.click),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onTap: onTapPin == null ? null : () => onTapPin(pin.key),
          onPanStart: movable ? (d) => _startDrag(pin, d) : null,
          onPanUpdate: movable ? _updateDrag : null,
          onPanEnd: movable ? (_) => _endDrag() : null,
          onPanCancel: movable ? _endDrag : null,
          child: Center(
            child: ExcludeSemantics(
              child: ArtworkMarkDot(number: pin.number, selected: selected),
            ),
          ),
        ),
      ),
    );
    final zoom = widget.zoom;
    if (zoom != null) {
      child = ValueListenableBuilder<Matrix4>(
        valueListenable: zoom,
        builder: (context, matrix, child) => Transform.scale(
          scale: 1 / matrix.getMaxScaleOnAxis().clamp(1.0, 10.0),
          child: child,
        ),
        child: child,
      );
    }
    final link = widget.selectedLink;
    if (link != null && pin.key == widget.selectedKey) {
      child = CompositedTransformTarget(link: link, child: child);
    }
    return Positioned(
      key: ValueKey<String>('mark-pin-${pin.key}'),
      left: position.dx * size.width - half,
      top: position.dy * size.height - half,
      width: ArtworkMarkLayer.hitExtent,
      height: ArtworkMarkLayer.hitExtent,
      child: child,
    );
  }
}

/// 编号圆点：墨色实底、白色细边、白字，浅色和深色的画上都看得清。选中时
/// 换成品牌紫并放大一圈（选中的是这一处点评本身）。列表里的编号也用它。
class ArtworkMarkDot extends StatelessWidget {
  const ArtworkMarkDot({
    required this.number,
    this.selected = false,
    this.size,
    super.key,
  });

  final int number;
  final bool selected;

  /// 不传时图上 24、选中 28。
  final double? size;

  @override
  Widget build(BuildContext context) {
    final extent = size ?? (selected ? 28.0 : 24.0);
    return Container(
      width: extent,
      height: extent,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.brand : AppColors.ink,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.onBrand, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        '$number',
        maxLines: 1,
        softWrap: false,
        style: AppText.number(
          size: 12,
          color: AppColors.onBrand,
        ).copyWith(height: 1),
      ),
    );
  }
}
