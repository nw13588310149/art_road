// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:dio/dio.dart';

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
  try {
    final fileName = sanitizeChatDownloadFileName(suggestedFileName);
    final mime = switch (kind) {
      GroupChatMediaKind.image => 'image/jpeg',
      GroupChatMediaKind.audio => 'audio/mp4',
      GroupChatMediaKind.video => 'video/mp4',
      GroupChatMediaKind.file => 'application/octet-stream',
    };
    final blob = html.Blob(<dynamic>[bytes], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    Timer(const Duration(seconds: 5), () {
      anchor.remove();
      html.Url.revokeObjectUrl(url);
    });
    return GroupChatMediaSaveResult(ok: true, path: fileName);
  } catch (error) {
    return GroupChatMediaSaveResult(ok: false, error: '下载失败：$error');
  }
}
