import 'package:flutter/foundation.dart';

/// 「我的收藏」接入书刊：收藏类型、页签名称、卡片字段与打开方式。
///
/// 书刊收藏由书刊模块写入（`POST /app/ebooks/{id}/favorite`），在
/// `/app/user/favoriteList` 中以 `type == EbookCollection.type` 返回，
/// `target` 是收藏时的快照：`{id, bookId, title, subtitle, coverImg, editor,
/// categoryLabel, pageCount}`。取消收藏沿用通用的 `favoriteSave`（favorite: 0）。
abstract final class EbookCollection {
  /// 与视频 6、资讯 9、范画 11 并列的收藏类型。
  static const int type = 12;
  static const String label = '书刊';

  /// 打开书刊页的路由参数：直接进入详情，详情返回即回到收藏页。
  static Map<String, dynamic> routeArgs(String targetId) => <String, dynamic>{
    'bookId': targetId,
    'fromMyCollection': true,
  };

  /// 收藏记录（`favoriteList` 的一条 record）→ 卡片数据；不是书刊时返回 null。
  static EbookCollectionItem? itemOf(Map<dynamic, dynamic> record) {
    if (_toInt(record['type']) != type) {
      return null;
    }
    final target = record['target'] is Map
        ? record['target'] as Map
        : const <String, dynamic>{};
    final bookId = _firstNonEmpty([
      record['targetId'],
      target['bookId'],
      target['id'],
    ]);
    if (bookId.isEmpty) {
      return null;
    }
    return EbookCollectionItem(
      bookId: bookId,
      title: _firstNonEmpty([target['title'], record['title']]),
      subtitle: _firstNonEmpty([target['subtitle'], target['categoryLabel']]),
      coverUrl: _firstNonEmpty([
        target['coverImg'],
        target['cover'],
        target['coverUrl'],
      ]),
      pageCount: _toInt(target['pageCount']),
    );
  }
}

@immutable
class EbookCollectionItem {
  const EbookCollectionItem({
    required this.bookId,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.pageCount,
  });

  final String bookId;
  final String title;

  /// 如「色彩教程 · 刘芳」。
  final String subtitle;

  /// 3:4 封面。
  final String coverUrl;
  final int pageCount;

  Map<String, dynamic> get routeArgs => EbookCollection.routeArgs(bookId);
}

String _firstNonEmpty(List<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && text != 'null') {
      return text;
    }
  }
  return '';
}

int _toInt(Object? value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
