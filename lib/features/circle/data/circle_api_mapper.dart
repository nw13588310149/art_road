import 'dart:convert' show jsonDecode;

import '../../../core/network/media_url.dart';
import '../state/circle_state.dart';

List<CirclePost> mapPostsListData(dynamic data) {
  final list = _asList(data);
  return list
      .map((e) {
        if (e is! Map) return null;
        return _mapPost(Map<String, dynamic>.from(e));
      })
      .whereType<CirclePost>()
      .toList();
}

List<CircleComment> mapCommentsListData(dynamic data) {
  final list = _asList(data);
  return list
      .map((e) {
        if (e is! Map) return null;
        return _mapComment(Map<String, dynamic>.from(e));
      })
      .whereType<CircleComment>()
      .toList();
}

CirclePost? mapSinglePostData(dynamic data) {
  if (data is! Map) return null;
  return _mapPost(Map<String, dynamic>.from(data));
}

CirclePost _mapPost(Map<String, dynamic> m) {
  final id = _pickString(m, const ['id', 'postsId', 'postId']);

  // v2 接口把作者放进 `user` 对象；老接口字段平铺在最外层，两套都兼容。
  final userObj = m['user'];
  final user = userObj is Map ? Map<String, dynamic>.from(userObj) : const <String, dynamic>{};
  final authorId = _pickString({...user, ...m}, const [
    'userId',
    'authorId',
    'createUserId',
    'publisherId',
    'id', // user.id
  ]);
  final name = _pickString({...m, ...user}, const [
    'nickname',
    'realname',
    'realName',
    'userName',
    'userNickname',
    'name',
  ]);
  final avatarRaw = _pickString({...m, ...user}, const [
    'headUrl',
    'avatar',
    'avatarUrl',
    'userHeadUrl',
  ]);
  final role = _pickString({...m, ...user}, const [
    'identity',
    'roleName',
    'userRole',
    'role',
  ]);

  final content = _pickString(m, const ['content', 'text', 'postsContent', 'body']);
  final description = _pickString(m, const ['description', 'desc', 'summary']);
  final composedText = _composePostText(
    content: content,
    description: description,
  );

  // 后端 `type`：1=图片 / 2=视频 / 3=音乐；0（文章）当成图片处理。
  final type = _asInt(m['type']);
  final mediaKind = switch (type) {
    2 => PostMediaKind.video,
    3 => PostMediaKind.audio,
    _ => PostMediaKind.image,
  };

  // `medias` 是 JSON 字符串数组，里面装相对 path；coverImg 视频/音频帖里
  // 单独存的封面 path。两者都需要 resolve 一下域名。
  final mediasRaw = _parseMediasField(m['medias']);
  final coverImgRaw = _pickString(m, const ['coverImg', 'cover', 'coverUrl']);
  final mediaUrls = <String>[
    for (final p in mediasRaw)
      if (p.isNotEmpty) MediaUrl.resolve(p),
  ];
  final coverUrl = coverImgRaw.isNotEmpty ? MediaUrl.resolve(coverImgRaw) : '';

  // imageUrl 给列表卡片当封面用：
  //   图片帖 → 第一张原图（也是 medias[0]）
  //   视频/音频帖 → coverImg；没有 cover 时退回 medias[0]（视频可能给的就是个截图）
  String firstImage;
  switch (mediaKind) {
    case PostMediaKind.image:
      firstImage = mediaUrls.isNotEmpty ? mediaUrls.first : coverUrl;
      break;
    case PostMediaKind.video:
    case PostMediaKind.audio:
      firstImage = coverUrl.isNotEmpty
          ? coverUrl
          : (mediaUrls.isNotEmpty ? mediaUrls.first : '');
      break;
  }
  // 兜底：传统 images / pic 字段（老接口）。
  if (firstImage.isEmpty) {
    final legacy = _pickLegacyImageUrls(m);
    if (legacy.isNotEmpty) firstImage = MediaUrl.resolve(legacy.first);
  }

  final videoW = _asDouble(m['videoWidth']);
  final videoH = _asDouble(m['videoHeight']);
  final imageW = _asDouble(m['imageWidth'] ?? m['width'] ?? m['imgWidth']);
  final imageH = _asDouble(m['imageHeight'] ?? m['height'] ?? m['imgHeight']);
  final hasExplicitAspectRatio =
      mediaKind == PostMediaKind.video && videoW > 0 && videoH > 0;
  double aspect;
  if (hasExplicitAspectRatio) {
    aspect = videoW / videoH;
  } else if (mediaKind != PostMediaKind.video && imageW > 0 && imageH > 0) {
    aspect = imageW / imageH;
  } else {
    // 视频真实比例由播放器加载后识别；列表封面无视频宽高时先按竖图占位。
    aspect = switch (mediaKind) {
      PostMediaKind.video => 9 / 16,
      PostMediaKind.audio => 1.0,
      PostMediaKind.image => 3 / 4,
    };
  }
  aspect = aspect.clamp(0.45, 1.6);

  final badges = <CircleBadge>[];
  if (_truthy(m['isTop']) || _truthy(m['top'])) {
    badges.add(CircleBadge.pinned);
  }
  if (_truthy(m['isHot']) || _truthy(m['hot'])) {
    badges.add(CircleBadge.hot);
  }

  final likeCount = _asInt(m['likeCount'] ?? m['likes'] ?? m['thumbCount']);
  final commentCount = _asInt(m['commentCount'] ?? m['comments'] ?? m['replyCount']);
  final favoriteCount = _asInt(m['favoriteCount'] ?? m['collectCount'] ?? m['starCount']);
  final liked = _truthy(m['isLike'] ?? m['liked'] ?? m['thumbUp']);
  final favorited = _truthy(m['isFavorite'] ?? m['favorited'] ?? m['collected']);

  final embedded = _parseEmbeddedComments(m);

  return CirclePost(
    id: id.isNotEmpty ? id : 'unknown_${composedText.hashCode}',
    author: CircleAuthor(
      id: authorId,
      name: name.isNotEmpty ? name : '用户',
      role: role,
      avatarUrl: avatarRaw.isNotEmpty ? MediaUrl.resolve(avatarRaw) : '',
    ),
    badges: badges,
    text: composedText,
    timeLabel: _pickString(m, const ['createTime', 'time', 'publishTime', 'createdAt']),
    imageUrl: firstImage,
    imageAspectRatio: aspect,
    hasExplicitAspectRatio: hasExplicitAspectRatio,
    likeCount: likeCount,
    commentCount: commentCount,
    favoriteCount: favoriteCount,
    liked: liked,
    favorited: favorited,
    comments: embedded,
    mediaKind: mediaKind,
    mediaUrls: mediaUrls,
  );
}

/// 卡片展示用正文：优先 `content`，否则退回 `description`。
String _composePostText({
  required String content,
  required String description,
}) {
  final c = content.trim();
  final d = description.trim();
  return c.isNotEmpty ? c : d;
}

List<CircleComment> _parseEmbeddedComments(Map<String, dynamic> m) {
  final raw = m['comments'] ?? m['commentList'] ?? m['replyList'];
  if (raw is! List || raw.isEmpty) return const <CircleComment>[];
  return raw
      .map((e) {
        if (e is! Map) return null;
        return _mapComment(Map<String, dynamic>.from(e));
      })
      .whereType<CircleComment>()
      .toList();
}

CircleComment _mapComment(Map<String, dynamic> m) {
  // v2 评论作者信息在嵌套 `user` 里；顶层 userId / comment 等字段平铺。
  final userObj = m['user'];
  final user = userObj is Map
      ? Map<String, dynamic>.from(userObj)
      : const <String, dynamic>{};

  final id = _pickString(m, const ['id', 'commentId']);
  final authorId = _pickString({...user, ...m}, const [
    'userId',
    'createUserId',
    'authorId',
    'id',
  ]);
  final name = _pickString({...m, ...user}, const [
    'nickname',
    'realname',
    'realName',
    'userName',
    'userNickname',
    'name',
  ]);
  final avatarRaw = _pickString({...m, ...user}, const [
    'headUrl',
    'avatar',
    'avatarUrl',
    'userHeadUrl',
  ]);
  final role = _pickString({...m, ...user}, const [
    'identity',
    'roleName',
    'userRole',
    'role',
  ]);
  final text = _pickString(m, const ['comment', 'content', 'text', 'body']);
  final likeCount = _asInt(m['likeCount'] ?? m['likes']);
  final liked = _truthy(m['isLike'] ?? m['liked'] ?? m['thumbUp']);

  return CircleComment(
    id: id.isNotEmpty ? id : 'c_${text.hashCode}',
    author: CircleAuthor(
      id: authorId,
      name: name.isNotEmpty ? name : '用户',
      role: role,
      avatarUrl: avatarRaw.isNotEmpty ? MediaUrl.resolve(avatarRaw) : '',
    ),
    text: text,
    timeLabel: _pickString(m, const ['createTime', 'time', 'createdAt']),
    likeCount: likeCount,
    liked: liked,
  );
}

List<String> _parseMediasField(dynamic raw) {
  if (raw == null) return const <String>[];
  if (raw is List) {
    return [
      for (final e in raw)
        if (e != null && e.toString().trim().isNotEmpty) e.toString().trim(),
    ];
  }
  if (raw is String) {
    final s = raw.trim();
    if (s.isEmpty) return const <String>[];
    final parsed = _tryParseJsonStringArray(s);
    if (parsed != null) return parsed;
    if (s.contains(',')) {
      return [
        for (final part in s.split(','))
          if (part.trim().isNotEmpty) part.trim(),
      ];
    }
    return <String>[s];
  }
  return const <String>[];
}

/// 老接口图片字段兜底（images / imageList / pics / photos / 单字段 image / pic
/// / 单字段 imageUrl / 多字段 attachments-CSV）。仅在新接口的 medias /
/// coverImg 都拿不到时回退。
List<String> _pickLegacyImageUrls(Map<String, dynamic> m) {
  final urls = <String>[];
  final raw = m['images'] ?? m['imageList'] ?? m['pics'] ?? m['photos'];
  if (raw is List) {
    for (final e in raw) {
      final s = e?.toString().trim() ?? '';
      if (s.isNotEmpty && s != 'null') urls.add(s);
    }
  }
  final single = _pickString(m, const [
    'image',
    'imageUrl',
    'pic',
    'photo',
    'imgUrl',
  ]);
  if (single.isNotEmpty) urls.add(single);
  final csv = _pickString(m, const ['attachments', 'attachment', 'picsUrl']);
  if (csv.contains(',')) {
    for (final part in csv.split(',')) {
      final s = part.trim();
      if (s.isNotEmpty) urls.add(s);
    }
  }
  return urls;
}

/// 兼容 `'["a", "b"]'` 这种 JSON 字符串数组；解析失败返回 null。
List<String>? _tryParseJsonStringArray(String s) {
  if (!(s.startsWith('[') && s.endsWith(']'))) return null;
  try {
    final decoded = jsonDecode(s);
    if (decoded is! List) return null;
    return [
      for (final e in decoded)
        if (e != null && e.toString().trim().isNotEmpty) e.toString().trim(),
    ];
  } catch (_) {
    return null;
  }
}

List<dynamic> _asList(dynamic data) {
  if (data is List) return data;
  if (data is Map) {
    for (final key in const ['records', 'list', 'rows', 'data', 'items']) {
      final v = data[key];
      if (v is List) return v;
    }
  }
  return const <dynamic>[];
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  if (v is bool) return v ? 1 : 0;
  return 0;
}

double _asDouble(dynamic v) {
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

String _pickString(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty && s != 'null') return s;
  }
  return '';
}

bool _truthy(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }
  return false;
}
