import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_font.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/scaled_dialog.dart';
import '../../../shell/ui/shell_layout.dart';
import 'face_camera_registry.dart';
import 'face_id_frame_overlay.dart';
import 'face_id_photo_flow.dart';
import 'face_id_photo_spec.dart';

/// 证件照取景相机：全屏预览 + 标准一寸框；仅标准前/后摄切换，变焦独立按钮。
class FaceIdCameraPage extends StatefulWidget {
  const FaceIdCameraPage({super.key});

  @override
  State<FaceIdCameraPage> createState() => _FaceIdCameraPageState();
}

class _FaceIdCameraPageState extends State<FaceIdCameraPage> {
  FaceCameraPair _cameraPair = const FaceCameraPair();
  bool _useFront = true;
  CameraController? _controller;
  String? _initError;
  bool _busy = false;
  bool _switchingCamera = false;

  double _zoom = 1;
  double _minZoom = 1;
  double _maxZoom = 1;
  bool _zoomReady = false;

  Size _previewLayoutSize = Size.zero;
  Rect _frameRect = Rect.zero;

  @override
  void initState() {
    super.initState();
    unawaited(_initCameras());
  }

  Future<void> _initCameras() async {
    try {
      final cameras = await FaceCameraRegistry.getCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _initError = '未检测到可用摄像头');
        return;
      }
      _cameraPair = FaceCameraRegistry.resolvePair(cameras);
      await _bindCamera(_cameraPair.indexFor(useFront: _useFront));
    } catch (e) {
      if (mounted) setState(() => _initError = '无法打开摄像头：$e');
    }
  }

  Future<void> _bindCamera(int index) async {
    final cameras = await FaceCameraRegistry.getCameras();
    if (cameras.isEmpty) return;

    final safeIndex = index.clamp(0, cameras.length - 1);
    final previous = _controller;
    if (mounted) {
      setState(() {
        _controller = null;
        _switchingCamera = true;
        _initError = null;
        _zoomReady = false;
      });
    }

    try {
      await previous?.dispose();
    } catch (_) {}

    try {
      final controller = CameraController(
        cameras[safeIndex],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (Platform.isIOS) {
        await controller.lockCaptureOrientation(DeviceOrientation.landscapeLeft);
      }

      var minZ = 1.0;
      var maxZ = 1.0;
      try {
        minZ = await controller.getMinZoomLevel();
        maxZ = await controller.getMaxZoomLevel();
      } catch (_) {}

      final startZoom = 1.0.clamp(minZ, maxZ);
      if (startZoom != 1.0) {
        await controller.setZoomLevel(startZoom);
      }

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _switchingCamera = false;
        _initError = null;
        _minZoom = minZ;
        _maxZoom = maxZ;
        _zoom = startZoom;
        _zoomReady = maxZ > minZ;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _switchingCamera = false;
        _initError = '无法打开摄像头：$e';
      });
    }
  }

  Future<void> _switchCamera() async {
    if (!_cameraPair.canSwitch || _busy || _switchingCamera) return;
    _useFront = !_useFront;
    await _bindCamera(_cameraPair.indexFor(useFront: _useFront));
  }

  Future<void> _applyZoom(double target) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || !_zoomReady) {
      return;
    }
    final next = target.clamp(_minZoom, _maxZoom);
    try {
      await controller.setZoomLevel(next);
      if (!mounted) return;
      setState(() => _zoom = next);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, '变焦失败：$e');
    }
  }

  void _zoomIn() => _applyZoom(_zoom + 0.2);
  void _zoomOut() => _applyZoom(_zoom - 0.2);

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onPreviewLayout(Size size) {
    if (size == _previewLayoutSize) return;
    _previewLayoutSize = size;
    _frameRect = FaceIdPhotoSpec.frameRectInPreview(size);
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _busy) {
      return;
    }

    setState(() => _busy = true);
    try {
      final file = await controller.takePicture();
      final raw = await File(file.path).readAsBytes();
      try {
        await File(file.path).delete();
      } catch (_) {}

      if (!mounted) return;
      final cropped = await openFaceIdPhotoCropFlow(
        context,
        sourceBytes: raw,
        sourceName: 'camera.jpg',
        title: '确认证件照',
        hint: '可拖动或缩放微调，将面部对准框内后确认',
      );
      if (!mounted) return;
      if (cropped != null) {
        Navigator.of(context).pop(cropped);
      } else {
        setState(() => _busy = false);
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, '拍摄失败：$e');
      setState(() => _busy = false);
    }
  }

  String get _cameraSwitchLabel => _useFront ? '后置' : '前置';

  String get _zoomLabel => '${_zoom.toStringAsFixed(1)}×';

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final canSwitch = _cameraPair.canSwitch;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(8)),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: Colors.white, size: ui(24)),
                  ),
                  Expanded(
                    child: Text(
                      '拍摄证件照',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: ui(17),
                        color: Colors.white,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w600,
                      ),
                    ),
                  ),
                  if (canSwitch)
                    TextButton.icon(
                      onPressed: (_busy || _switchingCamera) ? null : _switchCamera,
                      icon: Icon(Icons.cameraswitch_rounded, color: Colors.white, size: ui(20)),
                      label: Text(
                        _cameraSwitchLabel,
                        style: TextStyle(
                          fontSize: ui(13),
                          color: Colors.white,
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w500,
                        ),
                      ),
                    )
                  else
                    SizedBox(width: ui(48)),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(24)),
              child: Text(
                '请将面部置于框内，保持正面免冠、光线均匀，露出额头与双耳',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: ui(13),
                  color: Colors.white70,
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.5,
                ),
              ),
            ),
            SizedBox(height: ui(12)),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: ui(20)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(ui(12)),
                  child: _initError != null
                      ? _ErrorPane(message: _initError!)
                      : _switchingCamera
                      ? const Center(child: AppLoadingIndicator(color: Colors.white))
                      : _controller?.value.isInitialized == true
                      ? LayoutBuilder(
                          builder: (context, constraints) {
                            final size = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            _onPreviewLayout(size);
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                _CoverCameraPreview(controller: _controller!),
                                CustomPaint(
                                  painter: FaceIdFramePainter(
                                    frameRect: _frameRect,
                                    previewSize: size,
                                  ),
                                ),
                              ],
                            );
                          },
                        )
                      : const Center(
                          child: AppLoadingIndicator(color: Colors.white),
                        ),
                ),
              ),
            ),
            if (_zoomReady) ...[
              SizedBox(height: ui(10)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ZoomButton(
                    ui: ui,
                    icon: Icons.remove_rounded,
                    label: '缩小',
                    enabled: !_busy && !_switchingCamera && _zoom > _minZoom + 0.05,
                    onPressed: _zoomOut,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: ui(16)),
                    child: Text(
                      _zoomLabel,
                      style: TextStyle(
                        fontSize: ui(14),
                        color: Colors.white,
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w500,
                      ),
                    ),
                  ),
                  _ZoomButton(
                    ui: ui,
                    icon: Icons.add_rounded,
                    label: '放大',
                    enabled: !_busy && !_switchingCamera && _zoom < _maxZoom - 0.05,
                    onPressed: _zoomIn,
                  ),
                ],
              ),
            ],
            SizedBox(height: ui(12)),
            Padding(
              padding: EdgeInsets.fromLTRB(ui(24), 0, ui(24), ui(20)),
              child: AppDialogActionBar(
                cancelLabel: '取消',
                confirmLabel: _busy ? '处理中…' : '拍摄',
                confirmEnabled: !_busy && !_switchingCamera,
                onCancel: _busy ? () {} : () => Navigator.of(context).pop(),
                onConfirm: _capture,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.ui,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final double Function(num) ui;
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: TextButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, color: Colors.white, size: ui(22)),
        label: Text(
          label,
          style: TextStyle(
            fontSize: ui(13),
            color: Colors.white,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
          ),
        ),
        style: TextButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.12),
          padding: EdgeInsets.symmetric(horizontal: ui(14), vertical: ui(8)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ui(8)),
          ),
        ),
      ),
    );
  }
}

/// 与裁切算法一致的 [BoxFit.cover] 相机预览。
class _CoverCameraPreview extends StatelessWidget {
  const _CoverCameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewSize = controller.value.previewSize;
        if (previewSize == null) {
          return CameraPreview(controller);
        }
        var camW = previewSize.width.toDouble();
        var camH = previewSize.height.toDouble();
        final viewW = constraints.maxWidth;
        final viewH = constraints.maxHeight;
        final viewAspect = viewW / viewH;
        final camAspect = camW / camH;
        if (camAspect > viewAspect) {
          camH = viewH;
          camW = camH * camAspect;
        } else {
          camW = viewW;
          camH = camW / camAspect;
        }
        return ClipRect(
          child: OverflowBox(
            maxWidth: camW,
            maxHeight: camH,
            alignment: Alignment.center,
            child: SizedBox(
              width: camW,
              height: camH,
              child: CameraPreview(controller),
            ),
          ),
        );
      },
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ),
    );
  }
}
