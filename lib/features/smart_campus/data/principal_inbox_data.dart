/// 校长端「校长信箱」收件箱：列表解析与状态枚举。
library;

import '../../../core/network/media_url.dart';
import '../../../core/network/snowflake_id.dart';

enum PrincipalInboxStatus {
  sent(0, '待回复'),
  replied(1, '已回复'),
  closed(2, '已关闭');

  const PrincipalInboxStatus(this.apiCode, this.label);

  final int apiCode;
  final String label;

  static PrincipalInboxStatus fromApi(dynamic raw) {
    final code = _asInt(raw);
    return switch (code) {
      1 => PrincipalInboxStatus.replied,
      2 => PrincipalInboxStatus.closed,
      _ => PrincipalInboxStatus.sent,
    };
  }
}

class PrincipalInboxItem {
  const PrincipalInboxItem({
    required this.id,
    required this.msgType,
    required this.content,
    required this.status,
    required this.createTime,
    required this.isAnonymous,
    required this.submitterName,
    required this.submitterHeadUrl,
    required this.studentNo,
    required this.attachments,
    required this.replyContent,
    required this.replyTime,
  });

  final String id;
  final String msgType;
  final String content;
  final PrincipalInboxStatus status;
  final String createTime;
  final bool isAnonymous;
  final String submitterName;
  final String submitterHeadUrl;
  final String studentNo;
  final List<String> attachments;
  final String replyContent;
  final String replyTime;

  String get submitterLabel {
    if (isAnonymous) return '匿名来信';
    if (submitterName.isNotEmpty) return submitterName;
    return '未登记姓名';
  }

  bool get canReply => status == PrincipalInboxStatus.sent;
}

class PrincipalInboxPage {
  const PrincipalInboxPage({required this.items, required this.total});

  final List<PrincipalInboxItem> items;
  final int total;
}

PrincipalInboxPage parsePrincipalInboxPage(dynamic raw) {
  final items = parsePrincipalInboxList(raw);
  final total = parsePrincipalInboxTotal(raw) ?? items.length;
  return PrincipalInboxPage(items: items, total: total);
}

/// 校长端待回复角标：`headmaster/principalMailboxList` 的 `data` 常为数组
///（无 `total`），此时以数组长度计数；分页对象则优先读 `total` 等字段。
int parsePrincipalInboxPendingCount(dynamic raw) {
  if (raw is List) return raw.length;
  final total = parsePrincipalInboxTotal(raw);
  if (total != null) return total;
  return parsePrincipalInboxList(raw).length;
}

int? parsePrincipalInboxTotal(dynamic raw) {
  if (raw is List) return raw.length;
  final map = _resolvePageMap(raw);
  if (map == null) return null;
  for (final key in const ['total', 'totalCount', 'recordsTotal', 'count']) {
    final value = map[key];
    if (value == null) continue;
    if (value is int) return value;
    final parsed = int.tryParse(value.toString());
    if (parsed != null) return parsed;
  }
  return null;
}

Map<String, dynamic>? _resolvePageMap(dynamic raw) {
  if (raw is List) return null;
  if (raw is! Map) return null;
  var map = Map<String, dynamic>.from(raw);
  if (map['data'] is Map) {
    map = Map<String, dynamic>.from(map['data'] as Map);
  }
  return map;
}

List<PrincipalInboxItem> parsePrincipalInboxList(dynamic raw) {
  return _asList(raw)
      .map((item) {
        if (item is! Map) return null;
        final map = Map<String, dynamic>.from(item);
        final attachmentsRaw = _pickString(map, const [
          'attachments',
          'attachment',
        ]);
        final user = _pickNestedUserMap(map);
        return PrincipalInboxItem(
          id: readSnowflakeId(map['id']) ?? map['id']?.toString() ?? '',
          msgType: _pickString(map, const ['msgType', 'type']),
          content: _pickString(map, const ['content', 'body']),
          status: PrincipalInboxStatus.fromApi(map['status']),
          createTime: _pickString(map, const [
            'createTime',
            'submitTime',
            'createdAt',
          ]),
          isAnonymous: _asInt(map['isAnonymous']) == 1,
          submitterName: _pickSubmitterName(map, user),
          submitterHeadUrl: _pickSubmitterHeadUrl(map, user),
          studentNo: _pickStudentNo(map, user),
          attachments: attachmentsRaw
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(),
          replyContent: _pickString(map, const [
            'replyContent',
            'reply',
            'replyMsg',
          ]),
          replyTime: _pickString(map, const ['replyTime', 'replyAt']),
        );
      })
      .whereType<PrincipalInboxItem>()
      .toList(growable: false);
}

List<dynamic> _asList(dynamic data) {
  if (data is List) return data;
  if (data is Map) {
    final map = data.cast<String, dynamic>();
    if (map['data'] is List) return map['data'] as List;
    if (map['data'] is Map) return _asList(map['data']);
    for (final key in const ['records', 'list', 'rows', 'data', 'items']) {
      final value = map[key];
      if (value is List) return value;
    }
  }
  return const [];
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  if (value is bool) return value ? 1 : 0;
  return 0;
}

String _pickString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty && text != 'null') return text;
  }
  return '';
}

Map<String, dynamic> _pickNestedUserMap(Map<String, dynamic> map) {
  final user = map['user'];
  if (user is Map) return Map<String, dynamic>.from(user);
  return const {};
}

String _pickSubmitterName(
  Map<String, dynamic> map,
  Map<String, dynamic> user,
) {
  final topLevel = _pickString(map, const [
    'studentName',
    'realname',
    'userName',
    'submitUserName',
  ]);
  if (topLevel.isNotEmpty) return topLevel;
  final realname = _pickString(user, const ['realname', 'realName']);
  if (realname.isNotEmpty) return realname;
  final nickname = _pickString(user, const ['nickname', 'nickName']);
  if (nickname.isNotEmpty) return nickname;
  return '';
}

String _pickStudentNo(Map<String, dynamic> map, Map<String, dynamic> user) {
  final no = _pickString(map, const ['studentNo', 'userNo']);
  if (no.isNotEmpty) return no;
  return _pickString(user, const ['studentNo', 'no', 'userNo']);
}

String _pickSubmitterHeadUrl(
  Map<String, dynamic> map,
  Map<String, dynamic> user,
) {
  final raw = _pickString(map, const ['studentHeadUrl', 'headUrl', 'avatar']);
  if (raw.isEmpty) {
    final fromUser = _pickString(user, const [
      'headUrl',
      'avatar',
      'avatarUrl',
    ]);
    if (fromUser.isEmpty) return '';
    return MediaUrl.resolve(fromUser);
  }
  return MediaUrl.resolve(raw);
}
