/// 班主任端「家校沟通」API 数据模型与 JSON 解析。
library;

import 'dart:convert';

import '../../../core/network/media_url.dart';
import '../../../core/network/snowflake_id.dart';

class HomeSchoolChatStat {
  const HomeSchoolChatStat({
    required this.totalCount,
    required this.unreadCount,
    required this.waitingReplyCount,
  });

  final int totalCount;
  final int unreadCount;
  final int waitingReplyCount;

  static const zero = HomeSchoolChatStat(
    totalCount: 0,
    unreadCount: 0,
    waitingReplyCount: 0,
  );
}

class HomeSchoolConversation {
  const HomeSchoolConversation({
    required this.id,
    required this.studentId,
    required this.parentId,
    required this.studentName,
    required this.studentNo,
    required this.studentHeadUrl,
    required this.parentName,
    required this.parentMobile,
    required this.parentHeadUrl,
    required this.parentRelation,
    required this.teacherName,
    required this.tags,
    required this.lastSpeaker,
    required this.lastMessage,
    required this.timeText,
    required this.unreadCount,
    required this.replyPending,
  });

  final String id;
  final String studentId;
  final String parentId;
  final String studentName;
  final String studentNo;
  final String? studentHeadUrl;
  final String parentName;
  final String parentMobile;
  final String? parentHeadUrl;
  final String parentRelation;
  final String teacherName;
  final List<String> tags;
  final String lastSpeaker;
  final String lastMessage;
  final String timeText;
  final int unreadCount;
  final bool replyPending;

  /// 展示用学生名：优先 [studentName]，否则 [studentNo]。
  String get displayStudentName {
    if (studentName.isNotEmpty) return studentName;
    if (studentNo.isNotEmpty && studentNo != '—') return studentNo;
    return '未命名学生';
  }

  /// 展示用家长名：优先有效 [parentName]，否则 [parentMobile] / [parentRelation]。
  String get displayParentName {
    if (_isMeaningfulPersonName(parentName)) return parentName.trim();
    if (parentMobile.isNotEmpty) return parentMobile;
    if (parentRelation.isNotEmpty) return parentRelation;
    return '家长';
  }

  /// 列表卡片行：`姓名（关系）`。
  String get displayParentLine {
    final relation = parentRelation.isNotEmpty ? parentRelation : '家长';
    final name = _isMeaningfulPersonName(parentName) ? parentName.trim() : '';
    if (name.isNotEmpty) return '$name（$relation）';
    if (parentMobile.isNotEmpty) return '$parentMobile（$relation）';
    return relation;
  }

  /// 对话详情 / 气泡侧家长昵称：`关系-姓名`。
  String get displayParentChatLabel {
    final relation = parentRelation.isNotEmpty ? parentRelation : '家长';
    return '$relation-$displayParentName';
  }

  /// 班主任昵称：优先接口 [teacherName]，否则回退「老师」。
  String displayTeacherName([String fallback = '老师']) {
    if (teacherName.isNotEmpty) return teacherName;
    if (fallback.isNotEmpty) return fallback;
    return '老师';
  }

  bool get hasStudentName => studentName.isNotEmpty;
  bool get hasParentName => _isMeaningfulPersonName(parentName);
}

enum HomeSchoolMessageKind { text, image }

class HomeSchoolChatMessage {
  const HomeSchoolChatMessage({
    required this.id,
    required this.kind,
    required this.content,
    required this.imageUrl,
    required this.timeText,
    required this.fromTeacher,
  });

  final String id;
  final HomeSchoolMessageKind kind;
  final String content;
  final String? imageUrl;
  final String timeText;
  final bool fromTeacher;

  bool get isImage => kind == HomeSchoolMessageKind.image;

  String get displayText {
    if (isImage) return '[图片]';
    return content;
  }
}

HomeSchoolChatStat parseHomeSchoolChatStat(dynamic raw) {
  if (raw is! Map) return HomeSchoolChatStat.zero;
  var m = Map<String, dynamic>.from(raw);
  if (m['data'] is Map) {
    m = Map<String, dynamic>.from(m['data'] as Map);
  }
  return HomeSchoolChatStat(
    totalCount: _asInt(m['totalCount']) ?? 0,
    unreadCount: _asInt(m['unreadCount']) ?? 0,
    waitingReplyCount: _asInt(m['waitingReplyCount']) ?? 0,
  );
}

List<HomeSchoolConversation> parseHomeSchoolConversationList(dynamic raw) {
  final rows = _extractRecordMaps(raw);
  final parsed = <HomeSchoolConversation>[];
  for (final m in rows) {
    final id = readSnowflakeId(m['id']) ?? m['id']?.toString() ?? '';
    if (id.isEmpty) continue;
    final studentId =
        readSnowflakeId(m['studentId']) ?? m['studentId']?.toString() ?? '';
    final parentId =
        readSnowflakeId(m['parentId']) ?? m['parentId']?.toString() ?? '';
    final tagsRaw = _pickString(m, ['studentTags'], '');
    final tags = tagsRaw.isEmpty
        ? const <String>[]
        : tagsRaw
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
    final senderType = _pickString(m, ['lastSenderType'], '');
    final studentNoRaw = _pickString(m, ['studentNo'], '');
    final studentName = _pickString(m, ['studentName'], '');
    final parentMobile = _pickString(m, ['parentMobile'], '');
    final parentName = _pickString(m, ['parentName'], '');
    parsed.add(
      HomeSchoolConversation(
        id: id,
        studentId: studentId,
        parentId: parentId,
        studentName: studentName,
        studentNo: studentNoRaw.isNotEmpty ? studentNoRaw : '—',
        studentHeadUrl: _resolveOptionalUrl(m['studentHeadUrl']),
        parentName: parentName,
        parentMobile: parentMobile,
        parentHeadUrl: _resolveOptionalUrl(m['parentHeadUrl']),
        parentRelation: _pickString(m, ['parentRelation'], '家长'),
        teacherName: _pickString(m, ['teacherName'], ''),
        tags: tags,
        lastSpeaker: senderType == 'teacher' ? '老师' : '家长',
        lastMessage: _pickString(m, ['lastMessage'], ''),
        timeText: _formatDisplayTime(m['lastMessageTime']),
        unreadCount: _asInt(m['unreadCount']) ?? 0,
        replyPending: m['waitingReply'] == true ||
            m['waitingReply']?.toString() == 'true' ||
            m['waitingReply'] == 1,
      ),
    );
  }
  return parsed;
}

List<HomeSchoolChatMessage> parseHomeSchoolChatMessageList(dynamic raw) {
  final rows = _extractRecordMaps(raw);
  final parsed = <HomeSchoolChatMessage>[];
  for (final m in rows) {
    final id = readSnowflakeId(m['id']) ?? m['id']?.toString() ?? '';
    if (id.isEmpty) continue;
    final senderType = _pickString(m, ['senderType'], '');
    final content = _pickString(m, ['content'], '');
    final parsedImage = _parseHomeSchoolMessageImage(m, content);
    parsed.add(
      HomeSchoolChatMessage(
        id: id,
        kind: parsedImage.kind,
        content: parsedImage.kind == HomeSchoolMessageKind.text
            ? parsedImage.text
            : content,
        imageUrl: parsedImage.imageUrl,
        timeText: _formatBubbleTime(m['createTime']),
        fromTeacher: senderType == 'teacher',
      ),
    );
  }
  return parsed;
}

({HomeSchoolMessageKind kind, String text, String? imageUrl})
    _parseHomeSchoolMessageImage(
  Map<String, dynamic> json,
  String content,
) {
  final messageTypeRaw = json['messageType'] ?? json['msgType'] ?? json['type'];
  final messageType = _asInt(messageTypeRaw);
  final messageTypeText = messageTypeRaw?.toString().trim().toLowerCase() ?? '';
  final contentType =
      _pickString(json, ['contentType', 'msgContentType'], '').toLowerCase();
  final fileUrlRaw = _readRawFileUrl(json);
  final declaredImage = _isDeclaredImageMessage(
    messageType: messageType,
    messageTypeText: messageTypeText,
    contentType: contentType,
  );
  final resolvedUrl = _resolveHomeSchoolImageUrl(
    fileUrlRaw: fileUrlRaw,
    content: content,
    json: json,
  );

  if (resolvedUrl != null &&
      (declaredImage ||
          fileUrlRaw.isNotEmpty ||
          _looksLikeImageUrl(content) ||
          _extractEmbeddedImageUrl(content) != null)) {
    return (
      kind: HomeSchoolMessageKind.image,
      text: '',
      imageUrl: resolvedUrl,
    );
  }

  if (declaredImage || _isImagePreviewLabel(content)) {
    return (
      kind: HomeSchoolMessageKind.text,
      text: content.isNotEmpty ? content : '[图片]',
      imageUrl: null,
    );
  }

  return (
    kind: HomeSchoolMessageKind.text,
    text: content,
    imageUrl: null,
  );
}

bool _isDeclaredImageMessage({
  required int? messageType,
  required String messageTypeText,
  required String contentType,
}) {
  if (messageType == 2) return true;
  if (contentType == 'image') return true;
  return const {
    '2',
    'image',
    'img',
    'picture',
    'photo',
  }.contains(messageTypeText);
}

String _readRawFileUrl(Map<String, dynamic> json) {
  final direct = _pickString(
    json,
    [
      'fileUrl',
      'fileURL',
      'file_url',
      'imageUrl',
      'imgUrl',
      'mediaUrl',
      'picUrl',
      'url',
      'path',
      'contentUrl',
    ],
    '',
  );
  if (direct.isNotEmpty) return direct;

  final file = json['file'];
  if (file is Map) {
    final nested = _pickString(
      Map<String, dynamic>.from(file),
      ['fileUrl', 'url', 'path', 'imageUrl'],
      '',
    );
    if (nested.isNotEmpty) return nested;
  }

  for (final key in ['fileUrl', 'url', 'path']) {
    final raw = json[key];
    if (raw is Map) {
      final nested = _pickString(
        Map<String, dynamic>.from(raw),
        ['fileUrl', 'url', 'path', 'imageUrl'],
        '',
      );
      if (nested.isNotEmpty) return nested;
    }
    final text = raw?.toString().trim() ?? '';
    if (text.startsWith('{') || text.startsWith('[')) {
      final parsed = _extractEmbeddedImageUrl(text);
      if (parsed != null) {
        return parsed;
      }
    }
  }
  return '';
}

String? _resolveHomeSchoolImageUrl({
  required String fileUrlRaw,
  required String content,
  required Map<String, dynamic> json,
}) {
  for (final raw in <String>[
    fileUrlRaw,
    _pickString(
      json,
      ['imageUrl', 'imgUrl', 'mediaUrl', 'url', 'contentUrl', 'picUrl', 'path'],
      '',
    ),
    if (_looksLikeImageUrl(content)) content,
  ]) {
    if (raw.trim().isEmpty) continue;
    final resolved = _resolveOptionalUrl(raw);
    if (resolved != null) return resolved;
  }

  return _extractEmbeddedImageUrl(content);
}

bool _isImagePreviewLabel(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return false;
  return value == '[图片]' ||
      value == '[图片消息]' ||
      value == '[photo]' ||
      value == '[Photo]';
}

String? _extractEmbeddedImageUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('{') || value.startsWith('[')) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        final map = decoded.cast<String, dynamic>();
        final candidate = _pickString(
          map,
          ['fileUrl', 'url', 'imageUrl', 'imgUrl', 'mediaUrl', 'picUrl'],
          '',
        );
        return _resolveOptionalUrl(candidate);
      }
    } catch (_) {}
  }
  final match = RegExp(
    r'''(?:src|href)\s*=\s*["']([^"']+)["']''',
    caseSensitive: false,
  ).firstMatch(value);
  if (match != null) {
    return _resolveOptionalUrl(match.group(1));
  }
  return null;
}

bool _looksLikeImageUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty || _isImagePreviewLabel(value)) return false;
  if (value.startsWith('blob:')) return true;
  if (value.startsWith('http://') ||
      value.startsWith('https://') ||
      value.startsWith('//')) {
    return _hasImageExtension(value) ||
        value.contains('/upload/') ||
        value.contains('/tmp/');
  }
  if (value.startsWith('app/upload') || value.startsWith('/app/upload')) {
    return true;
  }
  return _hasImageExtension(value);
}

bool _hasImageExtension(String raw) {
  final cleaned = raw.trim().toLowerCase().split('?').first.split('#').first;
  final dot = cleaned.lastIndexOf('.');
  if (dot < 0 || dot == cleaned.length - 1) return false;
  final ext = cleaned.substring(dot + 1);
  return const {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'svg',
    'heic',
    'heif',
  }.contains(ext);
}

List<Map<String, dynamic>> _extractRecordMaps(dynamic raw) {
  if (raw is List) {
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }
  if (raw is Map) {
    final m = raw.cast<String, dynamic>();
    if (m['records'] is List) {
      return [
        for (final item in m['records'] as List)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
    }
    if (m['data'] is Map) {
      return _extractRecordMaps(m['data']);
    }
    if (m['data'] is List) {
      return _extractRecordMaps(m['data']);
    }
  }
  return const [];
}

String? _resolveOptionalUrl(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  if (s.isEmpty || s == 'null') return null;
  return MediaUrl.resolve(s);
}

String _pickString(
  Map<String, dynamic> json,
  List<String> keys, [
  String fallback = '',
]) {
  for (final key in keys) {
    final v = json[key];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty && s != 'null') return s;
  }
  return fallback;
}

int? _asInt(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '');
}

String _formatDisplayTime(dynamic raw) {
  if (raw == null) return '—';
  final s = raw.toString().trim();
  if (s.isEmpty) return '—';
  final dt = DateTime.tryParse(s);
  if (dt == null) return s;
  final local = dt.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  String two(int n) => n.toString().padLeft(2, '0');
  final hm = '${two(local.hour)}:${two(local.minute)}';
  if (day == today) return '今天 $hm';
  if (day == today.subtract(const Duration(days: 1))) return '昨天 $hm';
  return '${local.month}-${two(local.day)} $hm';
}

String _formatBubbleTime(dynamic raw) {
  if (raw == null) return '—';
  final s = raw.toString().trim();
  if (s.isEmpty) return '—';
  final dt = DateTime.tryParse(s);
  if (dt == null) return s;
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
}

bool _isMeaningfulPersonName(String raw) {
  final value = raw.trim();
  if (value.isEmpty || value == 'null') return false;
  if (RegExp(r'^[\.\。\-—_·]+$').hasMatch(value)) return false;
  return true;
}
