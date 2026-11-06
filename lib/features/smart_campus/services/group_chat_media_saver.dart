import 'dart:typed_data';

import 'group_chat_media_saver_io.dart'
    if (dart.library.html) 'group_chat_media_saver_web.dart';

enum GroupChatMediaKind { image, audio, video, file }

class GroupChatMediaDownloadItem {
  GroupChatMediaDownloadItem({
    required this.label,
    required this.suggestedFileName,
    required this.kind,
    this.url,
    this.bytes,
  }) : assert(
         (url != null && url.trim().isNotEmpty) || bytes != null,
         'url or bytes required',
       );

  final String label;
  final String suggestedFileName;
  final GroupChatMediaKind kind;
  final String? url;
  final Uint8List? bytes;
}

class GroupChatMediaSaveResult {
  const GroupChatMediaSaveResult({
    required this.ok,
    this.cancelled = false,
    this.path,
    this.error,
  });

  final bool ok;
  final bool cancelled;
  final String? path;
  final String? error;

  static const cancelledByUser = GroupChatMediaSaveResult(
    ok: false,
    cancelled: true,
  );
}

Future<GroupChatMediaSaveResult> saveGroupChatMediaItem(
  GroupChatMediaDownloadItem item,
) {
  return saveGroupChatMediaItemImpl(item);
}

Future<GroupChatMediaSaveResult> saveGroupChatMediaBytes({
  required Uint8List bytes,
  required String suggestedFileName,
  required GroupChatMediaKind kind,
}) {
  return saveGroupChatMediaBytesImpl(
    bytes: bytes,
    suggestedFileName: suggestedFileName,
    kind: kind,
  );
}

String sanitizeChatDownloadFileName(String raw, {String fallback = 'download'}) {
  var name = raw.trim();
  if (name.isEmpty) return fallback;
  name = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  if (name.length > 120) {
    final dot = name.lastIndexOf('.');
    if (dot > 0 && dot < name.length - 1) {
      final ext = name.substring(dot);
      final stem = name.substring(0, dot);
      name = '${stem.substring(0, (120 - ext.length).clamp(1, stem.length))}$ext';
    } else {
      name = name.substring(0, 120);
    }
  }
  return name;
}

String fileNameFromUrl(String url, {required String fallback}) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return fallback;
  final segment = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
  if (segment.isEmpty) return fallback;
  return sanitizeChatDownloadFileName(segment, fallback: fallback);
}
