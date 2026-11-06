import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import 'group_chat_media_saver.dart';

Future<GroupChatMediaSaveResult> saveGroupChatMediaItemImpl(
  GroupChatMediaDownloadItem item,
) async {
  try {
    if (item.bytes != null) {
      return saveGroupChatMediaBytesImpl(
        bytes: item.bytes!,
        suggestedFileName: item.suggestedFileName,
        kind: item.kind,
      );
    }
    final url = item.url?.trim() ?? '';
    if (url.isEmpty) {
      return const GroupChatMediaSaveResult(ok: false, error: '文件地址无效');
    }
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 10),
        responseType: ResponseType.bytes,
        followRedirects: true,
      ),
    );
    final response = await dio.get<List<int>>(url);
    final data = response.data;
    if (data == null || data.isEmpty) {
      return const GroupChatMediaSaveResult(ok: false, error: '下载内容为空');
    }
    return saveGroupChatMediaBytesImpl(
      bytes: Uint8List.fromList(data),
      suggestedFileName: item.suggestedFileName,
      kind: item.kind,
    );
  } catch (error) {
    return GroupChatMediaSaveResult(ok: false, error: '下载失败：$error');
  }
}

Future<GroupChatMediaSaveResult> saveGroupChatMediaBytesImpl({
  required Uint8List bytes,
  required String suggestedFileName,
  required GroupChatMediaKind kind,
}) async {
  final isMobile = Platform.isIOS || Platform.isAndroid;
  final fileName = sanitizeChatDownloadFileName(suggestedFileName);
  final pickerType = kind == GroupChatMediaKind.image
      ? FileType.image
      : FileType.custom;
  final allowedExtensions = pickerType == FileType.custom
      ? <String>[_extensionFromName(fileName)]
      : null;
  final dialogTitle = switch (kind) {
    GroupChatMediaKind.image => '保存图片',
    GroupChatMediaKind.audio => '保存音频',
    GroupChatMediaKind.video => '保存视频',
    GroupChatMediaKind.file => '保存文件',
  };

  try {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: pickerType,
      allowedExtensions: allowedExtensions,
      bytes: isMobile ? bytes : null,
    );
    if (path == null || path.isEmpty) {
      return GroupChatMediaSaveResult.cancelledByUser;
    }
    if (!isMobile) {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
    }
    return GroupChatMediaSaveResult(ok: true, path: path);
  } on UnimplementedError {
    return const GroupChatMediaSaveResult(
      ok: false,
      error: '当前平台暂不支持保存该文件',
    );
  } catch (error) {
    return GroupChatMediaSaveResult(ok: false, error: '保存失败：$error');
  }
}

String _extensionFromName(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot <= 0 || dot >= fileName.length - 1) {
    return 'bin';
  }
  return fileName.substring(dot + 1).toLowerCase();
}
