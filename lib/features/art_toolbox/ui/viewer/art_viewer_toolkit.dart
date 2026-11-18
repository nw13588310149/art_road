import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/widgets/image_viewer_tools.dart';
import 'viewer_image_layer.dart';
import 'viewer_tool_bar.dart';
import 'viewer_tools_controller.dart';

/// 看图页的看画工具：原图、灰度、明度色阶、眯眼模糊、镜像、构图网格、取色、比例测量，
/// 以及「更多工具」打开画室工具箱。`main.dart` 用它覆盖 [imageViewerToolkitProvider]。
class ArtImageViewerToolkit extends ImageViewerToolkit {
  const ArtImageViewerToolkit();

  @override
  ImageViewerToolSession createSession() => _ArtViewerSession();
}

class _ArtViewerSession extends ImageViewerToolSession {
  _ArtViewerSession() {
    _controller.addListener(notifyListeners);
  }

  final _controller = ViewerToolsController();

  @override
  void show(ImageViewerItem item, ui.Image? image) =>
      _controller.show(item, image);

  @override
  Widget buildImage(
    BuildContext context,
    ImageViewerItem item,
    ui.Image image,
    ValueListenable<double> scale,
  ) => ViewerImageLayer(
    controller: _controller,
    item: item,
    image: image,
    scale: scale,
  );

  @override
  Widget buildBar(BuildContext context, ImageViewerItem item) =>
      ViewerToolBar(controller: _controller, item: item);

  @override
  void tapImage(ImageViewerItem item, Offset position) {
    if (_controller.item?.index == item.index) {
      _controller.tapImage(position);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(notifyListeners)
      ..dispose();
    super.dispose();
  }
}
