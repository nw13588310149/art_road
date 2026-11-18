import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/art/photo_rectify.dart';
import '../../../core/ui/ui.dart';
import '../data/artwork_rules.dart';
import 'widgets/photo_straighten_canvas.dart';

/// 打开「拉正裁边」，完成时返回拉正后的 JPG 字节，取消时返回 null。
///
/// 用整屏浮层而不是页面路由打开：浮层在上面时随页工具栏自动让开，和上传弹窗一样。
Future<Uint8List?> showArtworkPhotoStraighten(
  BuildContext context, {
  required Uint8List bytes,
  String caption = '',
}) {
  return showGeneralDialog<Uint8List>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierLabel: '拉正裁边',
    barrierColor: AppColors.canvas,
    transitionDuration: AppMotion.overlay,
    pageBuilder: (_, _, _) =>
        ArtworkPhotoStraightenPage(bytes: bytes, caption: caption),
    transitionBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// 沉浸的拉正裁边页（设计语言第九节）：白色顶栏放取消、名称和「完成」，下面是
/// 中性灰画布，画布下面一行是提示、旋转和复位。
class ArtworkPhotoStraightenPage extends StatefulWidget {
  const ArtworkPhotoStraightenPage({
    required this.bytes,
    this.caption = '',
    super.key,
  });

  final Uint8List bytes;

  /// 页头名称后面的一句说明，例如「第 2 张」。
  final String caption;

  @override
  State<ArtworkPhotoStraightenPage> createState() =>
      _ArtworkPhotoStraightenPageState();
}

class _ArtworkPhotoStraightenPageState
    extends State<ArtworkPhotoStraightenPage> {
  ui.Image? _image;
  bool _failed = false;
  bool _processing = false;
  int _turns = 0;
  List<PhotoPoint> _corners = defaultPhotoCorners();

  bool get _changed =>
      _turns != 0 || !listEquals(_corners, defaultPhotoCorners());

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _image = frame.image);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _rotate() => setState(() {
    _turns = (_turns + 1) % 4;
    _corners = rotatePhotoCornersClockwise(_corners);
  });

  void _reset() => setState(() {
    _turns = 0;
    _corners = defaultPhotoCorners();
  });

  Future<void> _cancel() async {
    if (_processing) return;
    if (_changed) {
      final discard = await showAppConfirm(
        context: context,
        title: '放弃这次调整？',
        message: '照片会保持原来的样子。',
        confirmLabel: '放弃',
        cancelLabel: '继续调整',
      );
      if (!discard || !mounted) return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _finish() async {
    if (_processing || _image == null) return;
    setState(() => _processing = true);
    // 网页端的 compute 和界面在同一个线程里跑：先把「正在拉正」画出来再开始算。
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Uint8List? result;
    try {
      result = await compute(
        rectifyPhoto,
        PhotoRectifyRequest(
          bytes: widget.bytes,
          corners: _corners,
          quarterTurns: _turns,
        ),
      );
    } catch (_) {
      result = null;
    }
    if (!mounted) return;
    final problem = result == null ? null : ArtworkRules.imageError(result);
    if (result == null || problem != null) {
      setState(() => _processing = false);
      AppToast.showError(context, problem ?? '这张照片暂时无法拉正，可以直接上传原图');
      return;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Material(
        color: AppColors.canvas,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 64,
                color: AppColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s24),
                alignment: Alignment.center,
                child: AppTitleBar(
                  title: '拉正裁边',
                  caption: widget.caption,
                  onBack: _cancel,
                  backLabel: '取消',
                  actions: [
                    AppButton(
                      label: '完成',
                      loading: _processing,
                      onTap: image == null ? null : _finish,
                    ),
                  ],
                ),
              ),
              const AppRule(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.s24,
                    AppSpace.s12,
                    AppSpace.s24,
                    0,
                  ),
                  child: _buildCanvas(image),
                ),
              ),
              _buildFooter(enabled: image != null && !_processing),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCanvas(ui.Image? image) {
    if (_failed) {
      return const Center(
        child: AppErrorState(
          title: '无法读取这张照片',
          description: '可以直接上传原图，或者换一张照片',
        ),
      );
    }
    if (image == null) return const Center(child: AppLoadingIndicator());
    return Stack(
      children: [
        Positioned.fill(
          child: PhotoStraightenCanvas(
            image: image,
            quarterTurns: _turns,
            corners: _corners,
            enabled: !_processing,
            onChanged: (corners) => setState(() => _corners = corners),
          ),
        ),
        if (_processing)
          Positioned.fill(
            child: ColoredBox(
              color: AppColors.canvas.withValues(alpha: 0.6),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s20,
                    vertical: AppSpace.s12,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.br8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppLoadingIndicator(size: 20),
                      const SizedBox(width: AppSpace.s12),
                      Text('正在拉正照片…', style: AppText.body14),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFooter({required bool enabled}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s24,
        AppSpace.s4,
        AppSpace.s12,
        AppSpace.s8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '拖动四个角对齐画纸的四个角，画纸以外的部分会被裁掉',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body13,
            ),
          ),
          AppPlainButton(
            label: '旋转 90°',
            icon: Icons.rotate_right_rounded,
            onTap: enabled ? _rotate : null,
          ),
          AppPlainButton(
            label: '复位',
            icon: Icons.restart_alt_rounded,
            semanticLabel: '复位四个角',
            onTap: enabled ? _reset : null,
          ),
        ],
      ),
    );
  }
}
