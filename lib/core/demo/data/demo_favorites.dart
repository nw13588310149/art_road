import '../demo_store.dart';

/// 「我的收藏」演示存储，视频、资讯、范画等模块共用。
///
/// 收藏项：`{id, type, targetId, title, cover, subtitle, createTime, payload}`，
/// type：6 视频 / 9 资讯 / 11 范画；cover 为 `asset:` 引用或上传引用。
abstract final class DemoFavorites {
  static const typeVideo = 6;
  static const typeNews = 9;
  static const typeGallery = 11;

  static String _key(String userId) => 'favorites:$userId';

  static List<Map<String, dynamic>> of(String userId) =>
      DemoStore.list(_key(userId), () => <Map<String, dynamic>>[]);

  static bool contains(String userId, int type, String targetId) => of(userId)
      .any((f) => f['type'] == type && f['targetId']?.toString() == targetId);

  static void set(
    String userId, {
    required int type,
    required String targetId,
    required bool favorite,
    String title = '',
    String cover = '',
    String subtitle = '',
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) {
    final list = of(userId);
    list.removeWhere(
      (f) => f['type'] == type && f['targetId']?.toString() == targetId,
    );
    if (favorite) {
      final now = DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      list.insert(0, <String, dynamic>{
        'id': DemoStore.nextId('fav'),
        'type': type,
        'targetId': targetId,
        'title': title,
        'cover': cover,
        'subtitle': subtitle,
        'createTime':
            '${now.year}-${two(now.month)}-${two(now.day)} ${two(now.hour)}:${two(now.minute)}:${two(now.second)}',
        'payload': <String, dynamic>{'id': targetId, ...payload},
      });
    }
    DemoStore.save(_key(userId));
  }
}
