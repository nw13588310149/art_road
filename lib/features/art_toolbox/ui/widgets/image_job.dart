import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../data/toolbox_image_source.dart';
import '../../logic/image_ops.dart';

/// 在下一帧之后释放图片，避免本帧仍在绘制它的组件访问已释放的图片。
void disposeImageLater(ui.Image? image) {
  if (image == null) {
    return;
  }
  SchedulerBinding.instance.addPostFrameCallback((_) => image.dispose());
}

/// 一次处理的结果：显示用的图片 + 附带的统计数据。
class ProcessedImage<T> {
  const ProcessedImage(this.image, this.info);

  final ui.Image image;
  final T info;
}

/// 后台图片处理：同一时间只跑一个任务，拖动滑块期间只保留最后一次请求，
/// 每次完成都立即显示（拖动时也能看到中间结果）。页面销毁后完成的结果直接释放。
class LatestImageJob<Q, T> {
  LatestImageJob({required this.run, required this.onResult, this.onError});

  /// 在后台算出像素（通常是 `compute(...)`），返回像素与统计数据。
  final Future<(ArtImageData, T)> Function(Q request) run;

  /// 新结果；调用方负责用 [disposeImageLater] 释放被替换的旧图。
  final void Function(Q request, ProcessedImage<T> result) onResult;
  final void Function(Object error)? onError;

  Q? _pending;
  bool _hasPending = false;
  bool _running = false;
  bool _disposed = false;

  bool get busy => _running;

  void request(Q request) {
    if (_disposed) {
      return;
    }
    _pending = request;
    _hasPending = true;
    if (!_running) {
      unawaited(_drain());
    }
  }

  Future<void> _drain() async {
    _running = true;
    while (_hasPending && !_disposed) {
      final request = _pending as Q;
      _hasPending = false;
      try {
        final (data, info) = await run(request);
        if (_disposed) {
          break;
        }
        final image = await artImageToUiImage(data);
        if (_disposed) {
          image.dispose();
          break;
        }
        onResult(request, ProcessedImage(image, info));
      } catch (error) {
        if (!_disposed) {
          onError?.call(error);
        }
      }
    }
    _running = false;
  }

  void dispose() {
    _disposed = true;
    _pending = null;
    _hasPending = false;
  }
}

/// 只有一张处理结果的工具：参数一变就重新处理，处理失败且还没有结果时显示错误状态。
mixin DerivedImageState<W extends StatefulWidget, Q, T> on State<W> {
  ProcessedImage<T>? result;
  bool failed = false;

  late final LatestImageJob<Q, T> _job = LatestImageJob<Q, T>(
    run: process,
    onResult: (_, next) {
      disposeImageLater(result?.image);
      setState(() {
        result = next;
        failed = false;
      });
    },
    onError: (_) {
      if (result == null) {
        setState(() => failed = true);
      }
    },
  );

  /// 当前参数。
  Q get params;

  /// 后台处理，返回像素与统计数据。
  Future<(ArtImageData, T)> process(Q params);

  void reprocess() {
    if (failed) {
      setState(() => failed = false);
    }
    _job.request(params);
  }

  @override
  void initState() {
    super.initState();
    reprocess();
  }

  @override
  void dispose() {
    _job.dispose();
    result?.image.dispose();
    super.dispose();
  }
}
