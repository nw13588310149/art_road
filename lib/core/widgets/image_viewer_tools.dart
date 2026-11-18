import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 全屏看图里的一张图。
@immutable
class ImageViewerItem {
  const ImageViewerItem({
    required this.index,
    required this.src,
    this.title = '',
  });

  final int index;

  /// 调用方传入的原始地址：网络地址、后端相对路径、`asset:` 引用或 `assets/` 路径。
  final String src;
  final String title;
}

/// 看图页底部的工具。core 只定义接口，具体工具（画室工具箱）由 App 启动时通过
/// [imageViewerToolkitProvider] 注入；没有注入时看图页只有缩放、旋转和翻页。
abstract class ImageViewerToolkit {
  const ImageViewerToolkit();

  /// 每打开一次看图页创建一个会话，关闭时由看图页调用 [ImageViewerToolSession.dispose]。
  ImageViewerToolSession createSession();
}

/// 一次看图的工具状态。状态变化时通知看图页重建画面和工具栏。
abstract class ImageViewerToolSession extends ChangeNotifier {
  /// 切到 [item]，或这张图刚加载完。[image] 是正在显示的解码图，加载完成前为 null；
  /// 它归看图页所有，会话要留用时自己 `clone()`。
  void show(ImageViewerItem item, ui.Image? image);

  /// 一张图的画面，坐标系就是这张图（大小等于 [image] 的像素尺寸），随缩放、平移、
  /// 旋转一起变化。[scale] 是当前每个图片像素在屏幕上的长度，叠加的线条除以它保持粗细不变。
  Widget buildImage(
    BuildContext context,
    ImageViewerItem item,
    ui.Image image,
    ValueListenable<double> scale,
  );

  /// 画面下方的工具区（设置行 + 工具栏）。
  Widget buildBar(BuildContext context, ImageViewerItem item);

  /// 点了一下画面。[position] 是图片上的相对位置（0–1，未旋转时的方向），点在图外不会调用。
  /// 双击放大仍归看图页，所以单击要等过了双击的判定时间才到这里。
  void tapImage(ImageViewerItem item, Offset position) {}
}

/// 默认没有工具；`main.dart` 用画室工具箱的实现覆盖。
final imageViewerToolkitProvider = Provider<ImageViewerToolkit?>((ref) => null);
