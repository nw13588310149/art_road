import 'dart:typed_data';

import 'video_cover_frame_extractor_io.dart'
    if (dart.library.html) 'video_cover_frame_extractor_web.dart';

export 'video_cover_frame_extractor_constants.dart';

/// 校圈视频默认封面：抽取指定帧（1-based，默认第 10 帧）。
///
/// - IO：走 [VideoThumbnail]，按 30fps 估算时间点取最近帧。
/// - Web：video + canvas 在同时间点截帧。
Future<Uint8List?> extractVideoCoverFrame({
  required String? filePath,
  required Uint8List? fileBytes,
  int frameIndex = 10,
}) =>
    extractVideoCoverFrameImpl(
      filePath: filePath,
      fileBytes: fileBytes,
      frameIndex: frameIndex,
    );
