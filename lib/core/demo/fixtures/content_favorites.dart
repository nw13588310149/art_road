import '../data/demo_favorites.dart';
import '../demo_backend.dart';
import '../demo_store.dart';
import 'content_common.dart';
import 'content_news.dart';
import 'content_videos.dart';

const _seededKey = 'content_favorites_seeded';

/// 收藏快照里需要转成可加载地址的媒体字段。
const _mediaKeys = <String>{
  'cover',
  'coverImg',
  'img',
  'imgUrl',
  'image',
  'imageUrl',
  'thumb',
  'shortText3',
};

/// 「我的收藏」演示数据：首次访问时为账号预置几条视频、资讯与范画收藏。
abstract final class DemoContentFavorites {
  static void ensureSeeded(String userId) {
    final seeded = DemoStore.map(_seededKey, () => <String, dynamic>{});
    if (seeded[userId] == true) {
      return;
    }
    // DemoFavorites.set 新收藏插在最前，按展示顺序倒序写入。
    _seedGallery(
      userId,
      'g-2',
      '秋日静物 · 水粉色彩范画',
      ContentDemo.art('color-still-2'),
      '色彩',
      '刘芳',
    );
    _seedGallery(
      userId,
      'g-1',
      '石膏像大卫 · 结构素描范画',
      ContentDemo.art('sketch-bust-1'),
      '素描',
      '李静',
    );
    for (final id in const [9005, 9002]) {
      final info = DemoContentNews.favoriteInfo(id);
      if (info != null &&
          !DemoFavorites.contains(userId, DemoFavorites.typeNews, '$id')) {
        DemoFavorites.set(
          userId,
          type: DemoFavorites.typeNews,
          targetId: '$id',
          favorite: true,
          title: info.title,
          cover: info.cover,
          subtitle: info.subtitle,
          payload: info.payload,
        );
      }
    }
    for (final id in const ['6013', '6008', '6010']) {
      final info = DemoContentVideos.favoriteInfo(id);
      if (info != null &&
          !DemoFavorites.contains(userId, DemoFavorites.typeVideo, id)) {
        DemoFavorites.set(
          userId,
          type: DemoFavorites.typeVideo,
          targetId: id,
          favorite: true,
          title: info.title,
          cover: info.cover,
          subtitle: info.subtitle,
          payload: info.payload,
        );
      }
    }
    seeded[userId] = true;
    DemoStore.save(_seededKey);
  }

  static void _seedGallery(
    String userId,
    String id,
    String title,
    String cover,
    String subject,
    String author,
  ) {
    if (DemoFavorites.contains(userId, DemoFavorites.typeGallery, id)) {
      return;
    }
    DemoFavorites.set(
      userId,
      type: DemoFavorites.typeGallery,
      targetId: id,
      favorite: true,
      title: title,
      cover: cover,
      subtitle: '$subject · $author',
      payload: <String, dynamic>{
        'title': title,
        'subject': subject,
        'author': author,
      },
    );
  }

  static Map<String, dynamic> _snapshot(Map<String, dynamic> entry) {
    final payload = entry['payload'];
    final result = <String, dynamic>{};
    if (payload is Map) {
      for (final item in payload.entries) {
        final key = item.key.toString();
        final value = item.value;
        result[key] = _mediaKeys.contains(key) && value is String
            ? ContentDemo.url(value)
            : value;
      }
    }
    return result;
  }

  /// 收藏记录中的 `target`：视频 / 资讯取最新数据，范画等取收藏时的快照。
  static Map<String, dynamic> _target(
    Map<String, dynamic> entry,
    String userId,
  ) {
    final type = ContentDemo.toInt(entry['type']);
    final targetId = entry['targetId']?.toString() ?? '';
    final subtitle = entry['subtitle']?.toString() ?? '';
    if (type == DemoFavorites.typeVideo) {
      final video = DemoContentVideos.find(targetId, userId);
      if (video != null) {
        return <String, dynamic>{
          ...video,
          'title': video['name'],
          'subtitle': subtitle,
        };
      }
    }
    if (type == DemoFavorites.typeNews) {
      final news = DemoContentNews.find(ContentDemo.toInt(targetId));
      if (news != null) {
        return <String, dynamic>{
          ...news,
          'coverImg': news['shortText3'],
          'subtitle': subtitle,
        };
      }
    }
    final snapshot = _snapshot(entry);
    return <String, dynamic>{
      ...snapshot,
      'id': snapshot['id'] ?? targetId,
      'title': entry['title']?.toString().isNotEmpty == true
          ? entry['title']
          : (snapshot['title'] ?? snapshot['name'] ?? ''),
      'coverImg': ContentDemo.url(entry['cover']?.toString() ?? ''),
      'subtitle': subtitle,
    };
  }
}

void registerContentFavoriteFixtures(DemoRouter r) {
  r.any('/app/user/customFavoriteCategoryList', (req) {
    DemoContentFavorites.ensureSeeded(req.account.userId);
    return <Map<String, dynamic>>[
      {'id': 0, 'name': '全部'},
      {'id': DemoFavorites.typeGallery, 'name': '范画'},
      {'id': DemoFavorites.typeVideo, 'name': '视频'},
      {'id': DemoFavorites.typeNews, 'name': '资讯'},
    ];
  });

  r.any('/app/user/favoriteList', (req) {
    final userId = req.account.userId;
    DemoContentFavorites.ensureSeeded(userId);
    final type = req.intOf('type');
    final entries = DemoFavorites.of(
      userId,
    ).where((f) => type == 0 || ContentDemo.toInt(f['type']) == type).toList();
    final records = <Map<String, dynamic>>[
      for (final entry in entries)
        <String, dynamic>{
          'id': entry['id'],
          'type': ContentDemo.toInt(entry['type']),
          'targetId': entry['targetId'],
          'createTime': entry['createTime'],
          'target': DemoContentFavorites._target(entry, userId),
        },
    ];
    return ContentDemo.slice(records, req);
  });

  r.any('/app/user/favoriteSave', (req) {
    final userId = req.account.userId;
    final type = req.intOf('type');
    final targetId = req.str('targetId');
    if (type <= 0 || targetId.isEmpty) {
      throw const DemoApiException('收藏参数不完整');
    }
    if (!req.boolOf('favorite', true)) {
      DemoFavorites.set(
        userId,
        type: type,
        targetId: targetId,
        favorite: false,
      );
      return true;
    }
    final info = switch (type) {
      DemoFavorites.typeVideo => DemoContentVideos.favoriteInfo(targetId),
      DemoFavorites.typeNews => DemoContentNews.favoriteInfo(
        ContentDemo.toInt(targetId),
      ),
      _ => null,
    };
    if (info != null) {
      DemoFavorites.set(
        userId,
        type: type,
        targetId: targetId,
        favorite: true,
        title: info.title,
        cover: info.cover,
        subtitle: info.subtitle,
        payload: info.payload,
      );
      return true;
    }
    if (type == DemoFavorites.typeVideo || type == DemoFavorites.typeNews) {
      throw const DemoApiException('内容不存在或已下架');
    }
    // 范画等由其它模块提供数据：优先用请求里的快照字段，缺省时沿用已有记录。
    final existing = DemoFavorites.of(userId)
        .where(
          (f) =>
              ContentDemo.toInt(f['type']) == type &&
              f['targetId']?.toString() == targetId,
        )
        .firstOrNull;
    String pick(List<String> keys, String fallback) {
      for (final key in keys) {
        final value = req.str(key);
        if (value.isNotEmpty) {
          return value;
        }
      }
      return fallback;
    }

    final title = pick(const [
      'title',
      'name',
    ], existing?['title']?.toString() ?? '');
    DemoFavorites.set(
      userId,
      type: type,
      targetId: targetId,
      favorite: true,
      title: title.isEmpty ? '范画作品' : title,
      cover: ContentDemo.refOf(
        pick(const [
          'cover',
          'coverImg',
          'imageUrl',
        ], existing?['cover']?.toString() ?? ''),
      ),
      subtitle: pick(const [
        'subtitle',
      ], existing?['subtitle']?.toString() ?? ''),
      payload: existing?['payload'] is Map
          ? Map<String, dynamic>.from(existing!['payload'] as Map)
          : const <String, dynamic>{},
    );
    return true;
  });
}
