import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/toolbox_catalog.dart';
import '../data/toolbox_image_source.dart';

final toolboxImageLoaderProvider = Provider<ToolboxImageLoader>(
  (ref) => ToolboxImageLoader(),
);

/// 明度、镜像、网格、取色四个工具共用的当前图片（换工具不用重新选图）。
final toolboxImageControllerProvider =
    StateNotifierProvider.autoDispose<
      ToolboxImageController,
      ToolboxImageState
    >((ref) => ToolboxImageController(ref.watch(toolboxImageLoaderProvider)));

class ToolboxImageState {
  const ToolboxImageState({
    this.image,
    this.loading = false,
    this.errorMessage = '',
  });

  final ToolboxImage? image;
  final bool loading;
  final String errorMessage;

  ToolboxImageState copyWith({
    ToolboxImage? image,
    bool? loading,
    String? errorMessage,
  }) {
    return ToolboxImageState(
      image: image ?? this.image,
      loading: loading ?? this.loading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ToolboxImageController extends StateNotifier<ToolboxImageState> {
  ToolboxImageController(this._loader) : super(const ToolboxImageState());

  final ToolboxImageLoader _loader;
  int _version = 0;

  Future<void> pickFromAlbum() async {
    PickedImageBytes? picked;
    try {
      picked = await _loader.pickFromAlbum();
    } catch (_) {
      if (mounted) {
        state = state.copyWith(errorMessage: '无法打开相册，请检查相册访问权限');
      }
      return;
    }
    if (picked == null) {
      return;
    }
    final bytes = picked.bytes;
    await _load(() async => bytes, '相册图片');
  }

  Future<void> loadSample(ToolboxSample sample) =>
      _load(() => _loader.loadAsset(sample.asset), sample.label);

  Future<void> loadUrl(String url, {String label = '范画'}) {
    final value = url.trim();
    if (value.isEmpty) {
      return Future<void>.value();
    }
    return _load(() => _loader.download(value), label);
  }

  void clearError() {
    if (state.errorMessage.isNotEmpty) {
      state = state.copyWith(errorMessage: '');
    }
  }

  Future<void> _load(Future<Uint8List> Function() fetch, String label) async {
    if (!mounted) {
      return;
    }
    final version = ++_version;
    state = state.copyWith(loading: true, errorMessage: '');
    ToolboxImage? image;
    var message = '';
    try {
      image = await decodeToolboxImage(
        await fetch(),
        label: label,
        version: version,
      );
      if (image == null) {
        message = '无法识别这张图片，请换一张试试';
      }
    } catch (_) {
      message = '图片加载失败，请稍后重试';
    }
    if (!mounted || version != _version) {
      image?.dispose();
      return;
    }
    if (image == null) {
      state = state.copyWith(loading: false, errorMessage: message);
      return;
    }
    final previous = state.image;
    state = ToolboxImageState(image: image);
    _disposeLater(previous);
  }

  /// 旧图在下一帧之后再释放，避免本帧仍在绘制它的组件访问已释放的图片。
  void _disposeLater(ToolboxImage? image) {
    if (image == null) {
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) => image.dispose());
  }

  @override
  void dispose() {
    _disposeLater(state.image);
    super.dispose();
  }
}
