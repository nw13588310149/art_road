/// 视频卡片上的发布者（授课老师）展示信息。
///
/// 后端返回 `teacherName` / `teacherAvatar` 时直接使用；缺失时按视频 id 稳定地
/// 落到画室教研组的一位老师上，保证同一视频每次进入页面看到的发布者一致。
/// 头像为空时由 `ArtAvatar` 按姓名首字生成彩色圆形头像。
class VideoPublisherInfo {
  const VideoPublisherInfo({required this.nickname, this.avatarUrl = ''});

  final String nickname;
  final String avatarUrl;
}

VideoPublisherInfo videoPublisherFor(
  String videoId, {
  String name = '',
  String avatarUrl = '',
}) {
  final trimmed = name.trim();
  if (trimmed.isNotEmpty) {
    return VideoPublisherInfo(nickname: trimmed, avatarUrl: avatarUrl.trim());
  }
  final id = videoId.trim();
  final index = id.isEmpty ? 0 : _stableHash(id) % _fallbackTeachers.length;
  return VideoPublisherInfo(
    nickname: _fallbackTeachers[index],
    avatarUrl: avatarUrl.trim(),
  );
}

/// 32-bit FNV-1a，跨平台稳定（不依赖会随 isolate 变化的 hashCode）。
int _stableHash(String s) {
  int h = 0x811c9dc5;
  for (int i = 0; i < s.length; i++) {
    h = (h ^ s.codeUnitAt(i)) & 0xFFFFFFFF;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

const List<String> _fallbackTeachers = <String>[
  '李静',
  '张明远',
  '刘芳',
  '王海波',
  '赵雪',
  '周强',
  '吴雨桐',
];
