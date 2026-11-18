import 'package:flutter/widgets.dart';

import 'app_compare_controller.dart';

/// 可以缩放的一块画框：双指缩放、拖动、双击放大或复原，缩放由外面给（[zoom]）。
///
/// 手势改了缩放就通过 [onZoom] 报出去；外面给的 [zoom] 变了（另一侧锁定跟随、
/// 复位）就把画面摆过去。外面给回来的和手上的一样时不再重摆，两侧锁定时不会来回
/// 互相触发。[size] 是画框的大小，也是 [child] 的大小。
class AppCompareZoomBox extends StatefulWidget {
  const AppCompareZoomBox({
    required this.size,
    required this.zoom,
    required this.onZoom,
    required this.child,
    this.onTouch,
    super.key,
  });

  final Size size;
  final AppCompareZoom zoom;
  final ValueChanged<AppCompareZoom> onZoom;
  final Widget child;

  /// 手指或鼠标按下时调用（标记最后摸过的一侧）。
  final VoidCallback? onTouch;

  @override
  State<AppCompareZoomBox> createState() => _AppCompareZoomBoxState();
}

class _AppCompareZoomBoxState extends State<AppCompareZoomBox> {
  late final TransformationController _transform = TransformationController(
    widget.zoom.clamped().toMatrix(widget.size),
  );
  bool _applying = false;
  Offset _doubleTapAt = Offset.zero;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_changed);
  }

  @override
  void didUpdateWidget(AppCompareZoomBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = AppCompareZoom.fromMatrix(_transform.value, widget.size);
    if (!current.closeTo(widget.zoom)) {
      _applying = true;
      _transform.value = widget.zoom.clamped().toMatrix(widget.size);
      _applying = false;
    }
  }

  @override
  void dispose() {
    _transform
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  void _changed() {
    if (_applying || widget.size.isEmpty) {
      return;
    }
    widget.onZoom(AppCompareZoom.fromMatrix(_transform.value, widget.size));
  }

  void _doubleTap() => widget.onZoom(
    AppCompareController.doubleTapped(widget.zoom, _doubleTapAt, widget.size),
  );

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => widget.onTouch?.call(),
      child: GestureDetector(
        onDoubleTapDown: (details) => _doubleTapAt = details.localPosition,
        onDoubleTap: _doubleTap,
        child: SizedBox.fromSize(
          size: widget.size,
          child: InteractiveViewer(
            transformationController: _transform,
            minScale: 1,
            maxScale: AppCompareController.maxScale,
            child: SizedBox.expand(child: widget.child),
          ),
        ),
      ),
    );
  }
}
