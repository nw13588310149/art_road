import 'dart:typed_data';

import 'courseware_file_picker_io.dart'
    if (dart.library.html) 'courseware_file_picker_web.dart';

/// 文件选择类型，用于在弹出系统选择器时按场景过滤：
/// - [any]   ：任意文件，默认行为；
/// - [image] ：图片资源 —— Web 走 `accept="image/*"`、IO 走
///   `FilePicker.FileType.image`，移动端通常会直接拉起系统相册；
/// - [video] ：视频资源 —— Web 走 `accept="video/*"`、IO 走
///   `FilePicker.FileType.video`，iOS 会直接拉起相册；
/// - [audio] ：音频资源 —— Web `accept="audio/*"`；IO 在 iOS 上走
///   `FileType.custom`（文件选择器），其它平台走 `FileType.audio`。
enum CoursewarePickType { any, image, video, audio }

/// Picked file data.
class CoursewarePickedFile {
  const CoursewarePickedFile({
    required this.name,
    this.bytes,
    this.path,
    this.size,
  });

  final String name;
  final Uint8List? bytes;
  final String? path;
  final int? size;

  bool get hasBytes => bytes != null && bytes!.isNotEmpty;
  bool get hasPath => path != null && path!.isNotEmpty;
  bool get canUpload => hasBytes || hasPath;
}

/// 是否已有一次选择请求在途。用来串行化系统选择器调用。
bool _pickInFlight = false;

/// Picks files and returns filename + either bytes (web) or a local path (native).
///
/// - [allowMultiple]：是否允许多选（仅在 web / 图片选择上有意义）。
/// - [type]：限定可选文件类型。默认 [CoursewarePickType.any] —— 等价
///   于历史行为；显式传 [CoursewarePickType.image] 时移动端会直接进相册。
///
/// 全局串行化：iOS 的 file_picker 在上一次选择（尤其是大视频，系统仍在
/// 后台拷贝/转码）尚未结束时再次拉起，会触发原生 `multiple_request`，随后
/// 首次选择的异步回调调用已被置空的 result block，造成 `EXC_BAD_ACCESS`
/// 闪退。这里在前一次完成前，把新的选择请求按「未选择」返回空列表，避免
/// 任何并发拉起。
Future<List<CoursewarePickedFile>> pickCoursewareFiles({
  required bool allowMultiple,
  CoursewarePickType type = CoursewarePickType.any,
}) async {
  if (_pickInFlight) return const <CoursewarePickedFile>[];
  _pickInFlight = true;
  try {
    return await pickCoursewareFilesImpl(
      allowMultiple: allowMultiple,
      type: type,
    );
  } finally {
    _pickInFlight = false;
  }
}
