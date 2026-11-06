// iOS / Android / 桌面：相册选图后进入证件照裁切页；摄像头走取景页 + 裁切页。

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/widgets/app_toast.dart';
import '../../../shell/ui/shell_layout.dart';
import 'face_camera_registry.dart';
import 'face_id_camera_page.dart';
import 'face_id_photo_flow.dart';
import 'face_image_picker.dart';

bool get isCameraCaptureSupportedImpl =>
    !kIsWeb && (Platform.isIOS || Platform.isAndroid);

Future<FaceCapturedPhoto?> pickFacePhotoFromFileImpl(
  BuildContext context,
) async {
  // 移动端正传 path，尽快弹出裁切页；解码在裁切页 isolate 中完成。
  final usePathOnly = Platform.isIOS || Platform.isAndroid;
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: !usePathOnly,
  );
  if (result == null || result.files.isEmpty) return null;
  final f = result.files.first;
  if (!context.mounted) return null;

  final name = f.name.isNotEmpty ? f.name : 'album.jpg';
  if (usePathOnly && f.path != null && f.path!.isNotEmpty) {
    return openFaceIdPhotoCropFlow(
      context,
      sourcePath: f.path,
      sourceName: name,
      title: '调整证件照',
      hint: '拖动或双指缩放图片，将面部对准框内后确认',
    );
  }

  Uint8List? bytes = f.bytes;
  if ((bytes == null || bytes.isEmpty) && f.path != null) {
    try {
      bytes = await File(f.path!).readAsBytes();
    } catch (_) {
      return null;
    }
  }
  if (bytes == null || bytes.isEmpty) return null;
  if (!context.mounted) return null;

  return openFaceIdPhotoCropFlow(
    context,
    sourceBytes: bytes,
    sourceName: name,
    title: '调整证件照',
    hint: '拖动或双指缩放图片，将面部对准框内后确认',
  );
}

Future<FaceCapturedPhoto?> captureFacePhotoFromCameraImpl(
  BuildContext context,
) async {
  if (!isCameraCaptureSupportedImpl) return null;

  var status = await Permission.camera.status;
  if (!status.isGranted) {
    status = await Permission.camera.request();
  }
  if (!status.isGranted) {
    if (context.mounted) {
      AppToast.show(context, '需要相机权限才能拍摄，请在系统设置中开启');
    }
    return null;
  }

  if (!context.mounted) return null;
  FaceCameraRegistry.warmUp();
  final scale = DashboardScaleScope.of(context);
  return Navigator.of(context).push<FaceCapturedPhoto>(
    MaterialPageRoute<FaceCapturedPhoto>(
      fullscreenDialog: true,
      builder: (ctx) => DashboardScaleScope(
        data: scale,
        child: const FaceIdCameraPage(),
      ),
    ),
  );
}
