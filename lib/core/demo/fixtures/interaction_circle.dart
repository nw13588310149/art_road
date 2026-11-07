import 'dart:convert';

import '../data/demo_campus_data.dart';
import '../demo_accounts.dart';
import '../demo_backend.dart';
import '../demo_clock.dart';
import '../demo_store.dart';
import '../media/demo_media.dart';
import 'interaction_common.dart';

const _postsKey = 'circle:posts';
const _commentsKey = 'circle:comments';
const _base = '/app/school/v2/posts';

/// 校圈：全校共享一份帖子 / 评论数据，点赞按用户记录，删除校验作者或管理员。
void registerCircleFixtures(DemoRouter r) {
  r.post('$_base/postsList', (req) {
    final viewer = req.account;
    var posts = [..._posts()];
    final type = req.value('type');
    if (type != null && '$type'.isNotEmpty) {
      final code = req.intOf('type', -1);
      posts = posts.where((p) => _int(p['type']) == code).toList();
    }
    posts = demoSearch(posts, req.str('keyword'), (p) {
      final author = _postAuthor(p);
      return [p['content']?.toString() ?? '', author.name, author.identity];
    });
    _sortPosts(posts, req.intOf('sortType'), viewer);
    return _postPage(posts, req, viewer);
  });

  r.post('$_base/postsDetail', (req) {
    return _postJson(
      _requirePost(req.str('id')),
      req.account,
      withComments: true,
    );
  });

  r.post('$_base/myPostsList', (req) {
    final viewer = req.account;
    final mine = _posts().where((p) => p['userId'] == viewer.userId).toList()
      ..sort(_byTimeDesc);
    return _postPage(mine, req, viewer);
  });

  r.post('$_base/myPostsDetail', (req) {
    final post = _requirePost(req.str('id'));
    if (post['userId'] != req.account.userId) {
      throw const DemoApiException('只能查看自己发布的动态详情');
    }
    return _postJson(post, req.account, withComments: true);
  });

  r.post('$_base/myPostsSave', (req) {
    final viewer = req.account;
    final content = req.str('content');
    if (content.isEmpty) {
      throw const DemoApiException('请填写动态内容');
    }
    if (content.length > 1000) {
      throw const DemoApiException('动态内容不能超过 1000 字');
    }
    final medias = _parseMedias(req.value('medias'));
    final author = demoAccountAuthor(viewer);
    final post = <String, dynamic>{
      'id': DemoStore.nextId('199'),
      'userId': viewer.userId,
      'authorName': author.name,
      'authorIdentity': author.identity,
      'authorAvatar': author.avatarRef,
      'content': content,
      'type': req.intOf('type', medias.isEmpty ? 0 : 1),
      'medias': medias,
      'coverImg': demoMediaRefOf(req.str('coverImg')),
      'createTime': demoTimeText(DateTime.now()),
      'likeUserIds': <String>[],
      'baseLikes': 0,
      'favoriteCount': 0,
      'isTop': false,
      'isHot': false,
    };
    _posts().insert(0, post);
    _persist();
    return _postJson(post, viewer);
  });

  r.post('$_base/postsDelete', (req) {
    final viewer = req.account;
    final post = _requirePost(req.str('id'));
    if (post['userId'] != viewer.userId && viewer.role != DemoRole.admin) {
      throw const DemoApiException('只能删除自己发布的动态');
    }
    final id = post['id'];
    _posts().removeWhere((p) => p['id'] == id);
    _comments().removeWhere((c) => c['postId'] == id);
    _persist();
    return true;
  });

  r.post('$_base/postsLike', (req) {
    _setLiked(_requirePost(req.str('postsId')), req.account, liked: true);
    _persist();
    return true;
  });

  r.post('$_base/postsUnlike', (req) {
    _setLiked(_requirePost(req.str('postsId')), req.account, liked: false);
    _persist();
    return true;
  });

  r.post('$_base/postsCommentList', (req) {
    final viewer = req.account;
    final postId = req.str('postsId');
    final list = _comments().where((c) => c['postId'] == postId).toList()
      ..sort(_byTimeDesc);
    final offsetId = req.str('offsetId', '0');
    var start = 0;
    if (offsetId != '0') {
      final index = list.indexWhere((c) => c['id'] == offsetId);
      start = index < 0 ? 0 : index + 1;
    }
    final size = req.intOf('size', 20);
    return [
      for (final c in list.skip(start).take(size)) _commentJson(c, viewer),
    ];
  });

  r.post('$_base/postsCommentSave', (req) {
    final viewer = req.account;
    final post = _requirePost(req.str('postsId'));
    final text = req.str('comment');
    if (text.isEmpty) {
      throw const DemoApiException('请输入评论内容');
    }
    if (text.length > 500) {
      throw const DemoApiException('评论不能超过 500 字');
    }
    final author = demoAccountAuthor(viewer);
    final comment = <String, dynamic>{
      'id': DemoStore.nextId('299'),
      'postId': post['id'],
      'userId': viewer.userId,
      'authorName': author.name,
      'authorIdentity': author.identity,
      'authorAvatar': author.avatarRef,
      'comment': text,
      'replyId': req.str('replyId', '0'),
      'createTime': demoTimeText(DateTime.now()),
      'likeUserIds': <String>[],
      'baseLikes': 0,
    };
    _comments().add(comment);
    _persist();
    return _commentJson(comment, viewer);
  });

  r.post('$_base/postsCommentDelete', (req) {
    final viewer = req.account;
    final comment = _requireComment(req.str('id'));
    final post = _findPost('${comment['postId']}');
    final allowed =
        comment['userId'] == viewer.userId ||
        post?['userId'] == viewer.userId ||
        viewer.role == DemoRole.admin;
    if (!allowed) {
      throw const DemoApiException('只能删除自己的评论或自己动态下的评论');
    }
    _comments().removeWhere((c) => c['id'] == comment['id']);
    _persist();
    return true;
  });

  r.post('$_base/postsCommentLike', (req) {
    _setLiked(_requireComment(req.str('commentId')), req.account, liked: true);
    _persist();
    return true;
  });

  r.post('$_base/postsCommentUnlike', (req) {
    _setLiked(_requireComment(req.str('commentId')), req.account, liked: false);
    _persist();
    return true;
  });
}

List<Map<String, dynamic>> _posts() =>
    DemoStore.list(_postsKey, () => demoCloneSeed(_seed.posts));

List<Map<String, dynamic>> _comments() =>
    DemoStore.list(_commentsKey, () => demoCloneSeed(_seed.comments));

/// 帖子与评论来自同一份种子（id、时间互相对应），任何一边改动都一起落盘。
void _persist() {
  _posts();
  _comments();
  DemoStore.save(_postsKey);
  DemoStore.save(_commentsKey);
}

Map<String, dynamic>? _findPost(String id) =>
    _posts().where((p) => p['id'] == id).firstOrNull;

Map<String, dynamic> _requirePost(String id) {
  final post = _findPost(id);
  if (post == null) {
    throw const DemoApiException('动态不存在或已被删除');
  }
  return post;
}

Map<String, dynamic> _requireComment(String id) {
  final comment = _comments().where((c) => c['id'] == id).firstOrNull;
  if (comment == null) {
    throw const DemoApiException('评论不存在或已被删除');
  }
  return comment;
}

void _setLiked(
  Map<String, dynamic> target,
  DemoAccount viewer, {
  required bool liked,
}) {
  final ids = _stringList(target['likeUserIds'])..remove(viewer.userId);
  if (liked) {
    ids.add(viewer.userId);
  }
  target['likeUserIds'] = ids;
}

int _byTimeDesc(Map<String, dynamic> a, Map<String, dynamic> b) {
  final byTime = '${b['createTime']}'.compareTo('${a['createTime']}');
  return byTime != 0 ? byTime : '${b['id']}'.compareTo('${a['id']}');
}

void _sortPosts(
  List<Map<String, dynamic>> posts,
  int sortType,
  DemoAccount viewer,
) {
  final commentCounts = <String, int>{};
  for (final c in _comments()) {
    final key = '${c['postId']}';
    commentCounts[key] = (commentCounts[key] ?? 0) + 1;
  }
  int heat(Map<String, dynamic> p) =>
      _likeCount(p) +
      (commentCounts['${p['id']}'] ?? 0) * 3 +
      _int(p['favoriteCount']);
  final now = DateTime.now();
  double recommendScore(Map<String, dynamic> p) {
    final time = DateTime.tryParse('${p['createTime']}') ?? now;
    final hours = now.difference(time).inMinutes / 60;
    final jitter = '${viewer.userId}${p['id']}'.hashCode.abs() % 40;
    return heat(p) + jitter - hours * 0.6;
  }

  int pinnedFirst(Map<String, dynamic> a, Map<String, dynamic> b) {
    final pinned = (b['isTop'] == true ? 1 : 0) - (a['isTop'] == true ? 1 : 0);
    return pinned != 0 ? pinned : _byTimeDesc(a, b);
  }

  if (sortType == 1) {
    posts.sort((a, b) {
      final byHeat = heat(b).compareTo(heat(a));
      return byHeat != 0 ? byHeat : _byTimeDesc(a, b);
    });
  } else if (sortType == 2) {
    posts.sort((a, b) => recommendScore(b).compareTo(recommendScore(a)));
  } else {
    posts.sort(pinnedFirst);
  }
}

Map<String, dynamic> _postPage(
  List<Map<String, dynamic>> posts,
  DemoRequest req,
  DemoAccount viewer,
) {
  final page = demoPage(posts, req);
  page['records'] = [
    for (final p in (page['records'] as List).cast<Map<String, dynamic>>())
      _postJson(p, viewer),
  ];
  return page;
}

DemoAuthorCard _postAuthor(Map<String, dynamic> p) =>
    demoAuthorByUserId('${p['userId']}') ??
    DemoAuthorCard(
      userId: '${p['userId']}',
      name: p['authorName']?.toString() ?? '同学',
      identity: p['authorIdentity']?.toString() ?? '',
      avatarRef: p['authorAvatar']?.toString() ?? '',
    );

Map<String, dynamic> _postJson(
  Map<String, dynamic> p,
  DemoAccount viewer, {
  bool withComments = false,
}) {
  final author = _postAuthor(p);
  final medias = _stringList(p['medias']);
  final comments = _comments().where((c) => c['postId'] == p['id']).toList()
    ..sort(_byTimeDesc);
  final likeCount = _likeCount(p);
  final type = _int(p['type']);
  final firstMedia = medias.isEmpty ? '' : medias.first;
  final imageSize =
      _assetSizes[_assetPath('${p['coverImg']}')] ??
      _assetSizes[_assetPath(firstMedia)];
  final videoSize = _videoSizes[_assetPath(firstMedia)];
  return <String, dynamic>{
    'id': p['id'],
    'userId': author.userId,
    'user': author.toUserJson(),
    'content': p['content'],
    'description': p['content'],
    'type': type,
    'medias': jsonEncode([for (final m in medias) DemoMedia.url(m)]),
    'coverImg': DemoMedia.url('${p['coverImg'] ?? ''}'),
    if (imageSize != null && type != 2) ...<String, dynamic>{
      'imageWidth': imageSize.$1,
      'imageHeight': imageSize.$2,
    },
    if (videoSize != null && type == 2) ...<String, dynamic>{
      'videoWidth': videoSize.$1,
      'videoHeight': videoSize.$2,
    },
    'createTime': p['createTime'],
    'likeCount': likeCount,
    'commentCount': comments.length,
    'favoriteCount': _int(p['favoriteCount']),
    'isLike': _stringList(p['likeUserIds']).contains(viewer.userId),
    'isFavorite': false,
    'isTop': p['isTop'] == true ? 1 : 0,
    'isHot': p['isHot'] == true || likeCount >= 120 ? 1 : 0,
    if (withComments)
      'comments': [for (final c in comments.take(20)) _commentJson(c, viewer)],
  };
}

Map<String, dynamic> _commentJson(Map<String, dynamic> c, DemoAccount viewer) {
  final author =
      demoAuthorByUserId('${c['userId']}') ??
      DemoAuthorCard(
        userId: '${c['userId']}',
        name: c['authorName']?.toString() ?? '同学',
        identity: c['authorIdentity']?.toString() ?? '',
        avatarRef: c['authorAvatar']?.toString() ?? '',
      );
  final likeIds = _stringList(c['likeUserIds']);
  return <String, dynamic>{
    'id': c['id'],
    'postsId': c['postId'],
    'userId': author.userId,
    'user': author.toUserJson(),
    'comment': c['comment'],
    'replyId': c['replyId'] ?? '0',
    'createTime': c['createTime'],
    'likeCount': _int(c['baseLikes']) + likeIds.length,
    'isLike': likeIds.contains(viewer.userId),
  };
}

int _likeCount(Map<String, dynamic> p) =>
    _int(p['baseLikes']) + _stringList(p['likeUserIds']).length;

List<String> _parseMedias(Object? raw) {
  final values = <String>[];
  if (raw is List) {
    values.addAll(raw.map((e) => '$e'));
  } else {
    final text = raw?.toString().trim() ?? '';
    if (text.startsWith('[')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is List) {
          values.addAll(decoded.map((e) => '$e'));
        }
      } on FormatException {
        values.add(text);
      }
    } else if (text.isNotEmpty) {
      values.addAll(text.split(','));
    }
  }
  return [
    for (final v in values)
      if (v.trim().isNotEmpty && v.trim() != 'null') demoMediaRefOf(v),
  ];
}

List<String> _stringList(Object? raw) =>
    raw is List ? [for (final e in raw) '$e'] : <String>[];

int _int(Object? raw) =>
    raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}') ?? 0;

String _assetPath(String ref) =>
    ref.startsWith('asset:') ? ref.substring('asset:'.length) : '';

const _art = 'asset:assets/demo/art/';
const _scene = 'asset:assets/demo/scene/';
const _video = 'asset:assets/demo/video/';

const _assetSizes = <String, (int, int)>{
  'assets/demo/art/color-flower-1.jpg': (1152, 864),
  'assets/demo/art/color-landscape-1.jpg': (1152, 864),
  'assets/demo/art/color-still-1.jpg': (1152, 864),
  'assets/demo/art/color-still-2.jpg': (1152, 864),
  'assets/demo/art/color-still-3.jpg': (1152, 864),
  'assets/demo/art/color-still-4.jpg': (1152, 864),
  'assets/demo/art/color-still-5.jpg': (1152, 864),
  'assets/demo/art/detail-color.jpg': (1024, 1024),
  'assets/demo/art/detail-sketch.jpg': (1024, 1024),
  'assets/demo/art/sketch-bust-1.jpg': (729, 1017),
  'assets/demo/art/sketch-bust-2.jpg': (864, 1152),
  'assets/demo/art/sketch-bust-3.jpg': (864, 1152),
  'assets/demo/art/sketch-geometry-1.jpg': (864, 1152),
  'assets/demo/art/sketch-portrait-1.jpg': (864, 1152),
  'assets/demo/art/sketch-still-1.jpg': (1152, 864),
  'assets/demo/art/sketch-still-2.jpg': (1152, 864),
  'assets/demo/art/sketch-still-3.jpg': (1152, 864),
  'assets/demo/art/speed-figure-1.jpg': (864, 1152),
  'assets/demo/art/speed-figure-2.jpg': (864, 1152),
  'assets/demo/art/speed-figure-3.jpg': (1152, 864),
  'assets/demo/art/speed-figure-4.jpg': (1152, 864),
  'assets/demo/art/speed-figure-5.jpg': (864, 1152),
  'assets/demo/art/speed-group-1.jpg': (1152, 864),
  'assets/demo/art/speed-scene-1.jpg': (1152, 864),
  'assets/demo/scene/exam-hall.jpg': (1280, 720),
  'assets/demo/scene/studio-wall.jpg': (1280, 720),
};

const _videoSizes = <String, (int, int)>{
  'assets/demo/video/hatching.mp4': (960, 600),
  'assets/demo/video/place-paper.mp4': (720, 1270),
  'assets/demo/video/studio.mp4': (1280, 726),
};

class _SeedComment {
  const _SeedComment(this.author, this.text, this.minutesAfter);

  /// `s:<学生序号>` 或 `t:<教职工 id>`。
  final String author;
  final String text;
  final int minutesAfter;
}

class _SeedPost {
  const _SeedPost({
    required this.author,
    required this.minutesAgo,
    required this.content,
    required this.images,
    this.video = '',
    required this.likes,
    required this.favorites,
    this.top = false,
    this.hot = false,
    this.likedByStudent = false,
    this.comments = const <_SeedComment>[],
  });

  final String author;
  final int minutesAgo;
  final String content;

  /// 图片帖的配图；视频帖只放一张封面。
  final List<String> images;
  final String video;
  final int likes;
  final int favorites;
  final bool top;
  final bool hot;
  final bool likedByStudent;
  final List<_SeedComment> comments;
}

class _CircleSeed {
  _CircleSeed(this.posts, this.comments);

  final List<Map<String, dynamic>> posts;
  final List<Map<String, dynamic>> comments;
}

final _CircleSeed _seed = _buildSeed();

DemoAuthorCard _seedAuthor(String spec) {
  if (spec.startsWith('s:')) {
    return demoStudentAuthor(int.parse(spec.substring(2)));
  }
  return demoStaffAuthor(DemoCampusData.staffById(spec.substring(2))!);
}

_CircleSeed _buildSeed() {
  final now = DemoClock.now();
  final posts = <Map<String, dynamic>>[];
  final comments = <Map<String, dynamic>>[];
  for (var i = 0; i < _seedPosts.length; i++) {
    final spec = _seedPosts[i];
    final id = '1990000000${100101 + i}';
    final author = _seedAuthor(spec.author);
    // 错开分钟数，避免整小时倒推出一串同分钟的发帖时间。
    final created = DemoClock.ago(
      Duration(minutes: spec.minutesAgo + (i * 17) % 50),
    );
    final isVideo = spec.video.isNotEmpty;
    posts.add(<String, dynamic>{
      'id': id,
      'userId': author.userId,
      'authorName': author.name,
      'authorIdentity': author.identity,
      'authorAvatar': author.avatarRef,
      'content': spec.content,
      'type': isVideo ? 2 : 1,
      'medias': isVideo ? <String>[spec.video] : spec.images,
      'coverImg': spec.images.first,
      'createTime': demoTimeText(created),
      'likeUserIds': <String>[
        if (spec.likedByStudent) DemoAccounts.student.userId,
      ],
      'baseLikes': spec.likes - (spec.likedByStudent ? 1 : 0),
      'favoriteCount': spec.favorites,
      'isTop': spec.top,
      'isHot': spec.hot,
    });
    for (var j = 0; j < spec.comments.length; j++) {
      final c = spec.comments[j];
      final commenter = _seedAuthor(c.author);
      var time = created.add(Duration(minutes: c.minutesAfter));
      final latest = now.subtract(const Duration(minutes: 1));
      if (time.isAfter(latest)) {
        time = latest;
      }
      comments.add(<String, dynamic>{
        'id': '$id${(j + 1).toString().padLeft(2, '0')}',
        'postId': id,
        'userId': commenter.userId,
        'authorName': commenter.name,
        'authorIdentity': commenter.identity,
        'authorAvatar': commenter.avatarRef,
        'comment': c.text,
        'replyId': '0',
        'createTime': demoTimeText(time),
        'likeUserIds': <String>[],
        'baseLikes': (c.text.length * 7 + j * 5) % 23,
      });
    }
  }
  return _CircleSeed(posts, comments);
}

const _seedPosts = <_SeedPost>[
  _SeedPost(
    author: 't:t-9',
    minutesAgo: 26 * 60,
    content:
        '【考务通知】11 月月考定于 11 月 15 日（周日）三校区同步进行，一天考完：'
        '08:30 素描、14:00 色彩、19:00 速写。请携带准考证提前 20 分钟入场，按考号就座，'
        '画板画架由画室提供，其余画具自备，考场内禁止使用手机。',
    images: ['${_scene}exam-hall.jpg'],
    likes: 86,
    favorites: 41,
    top: true,
    comments: [
      _SeedComment('s:7', '收到！色彩考静物还是风景呀？', 12),
      _SeedComment('t:t-3', '以静物组合为主，大家按平时的作画流程准备即可。', 30),
      _SeedComment('s:12', '速写是考单人还是组合？', 46),
      _SeedComment('t:t-4', '人物组合，注意时间分配，构图阶段不要超过 5 分钟。', 70),
    ],
  ),
  _SeedPost(
    author: 't:t-1',
    minutesAgo: 3 * 60,
    content:
        '本周素描范画讲评：大卫石膏像。重点看三处——头发的大体积归纳、眉弓到鼻底的结构转折、'
        '颈部胸锁乳突肌的穿插。先画大块面再处理卷发，不要一上来就一缕一缕地抠细节。',
    images: ['${_art}sketch-bust-1.jpg'],
    likes: 132,
    favorites: 58,
    hot: true,
    comments: [
      _SeedComment('s:1', '老师，大卫的卷发暗部总是画得很腻，有什么办法吗？', 15),
      _SeedComment(
        't:t-1',
        '先把卷发按团块分出明暗两大面，暗部用侧锋整体铺，最后只挑几组靠前的卷发刻画，其余的概括掉。',
        40,
      ),
      _SeedComment('s:9', '收藏了，下周就画这个', 65),
      _SeedComment('s:15', '颈部那一块终于看懂了', 90),
    ],
  ),
  _SeedPost(
    author: 's:1',
    minutesAgo: 5 * 60,
    content:
        '写生日记｜周末跟着刘芳老师去城郊画白杨和土坯房。秋天的黄真的好难调，第一次试着用'
        '柠檬黄加一点土黄压住火气，远山用群青加白再带一点紫，终于有了空间感。',
    images: ['${_art}color-landscape-1.jpg'],
    likes: 64,
    favorites: 12,
    comments: [
      _SeedComment('t:t-3', '远山和中景的冷暖拉得不错，前景的土路可以再暖一点、笔触再放松一些。', 20),
      _SeedComment('s:4', '这个黄好舒服！求调色方法', 35),
      _SeedComment('s:1', '柠檬黄加少量土黄和白，暗部再加一点熟褐～', 50),
    ],
  ),
  _SeedPost(
    author: 't:t-3',
    minutesAgo: 8 * 60,
    content:
        '色彩静物三种色调对比：暖黄调、蓝灰调、高级灰调。同一组陶罐和水果，背景与衬布的颜色'
        '决定了整张画的气氛。考前一定要确定自己最拿手的色调方案，考场上不要临时改。',
    images: [
      '${_art}color-still-2.jpg',
      '${_art}color-still-4.jpg',
      '${_art}color-still-3.jpg',
    ],
    likes: 158,
    favorites: 96,
    hot: true,
    likedByStudent: true,
    comments: [
      _SeedComment('s:6', '高级灰那张好有质感！', 18),
      _SeedComment('s:1', '我一直画不出蓝灰调里橙子的暖，原来是背景的冷没压够。', 42),
      _SeedComment('t:t-3', '对，冷暖是相对的，背景冷下去了，橙子自然就跳出来了。', 60),
      _SeedComment('s:21', '老师能出一期调色步骤视频吗？', 95),
    ],
  ),
  _SeedPost(
    author: 't:t-4',
    minutesAgo: 10 * 60,
    content:
        '晚自习速写课 40 分钟限时：三人组合写生。大家的动态越来越准了，下一步要解决的是'
        '人物之间的前后遮挡和场景交代。',
    images: ['${_art}speed-group-1.jpg'],
    video: '${_video}studio.mp4',
    likes: 97,
    favorites: 30,
    comments: [
      _SeedComment('s:2', '原来我们画画的时候是这个样子哈哈', 25),
      _SeedComment('s:18', '赵老师今天的示范太快了，没跟上', 48),
      _SeedComment('t:t-4', '示范步骤已经整理到视频中心了，可以回看。', 80),
    ],
  ),
  _SeedPost(
    author: 's:2',
    minutesAgo: 14 * 60,
    content:
        '模考心得｜速写这次只拿了 75 分，问题主要出在手和脚，老师说我一画到手就慌。'
        '接下来每天打卡 20 个手部速写，下次月考见分晓。',
    images: ['${_art}speed-figure-5.jpg'],
    likes: 45,
    favorites: 6,
    comments: [
      _SeedComment('t:t-5', '能正视问题就是进步，这张蹲姿的重心处理得不错，加油！', 30),
      _SeedComment('s:11', '一起打卡！', 55),
      _SeedComment('s:1', '画手可以先画成连指手套的形状，再分出手指，会快很多。', 75),
    ],
  ),
  _SeedPost(
    author: 't:t-2',
    minutesAgo: 26 * 60 + 40,
    content:
        '排线基本功：手腕放松，线条两头轻中间重；第二层排线和第一层的夹角不要接近 90°，'
        '否则会出现网格感。几何体阶段把排线练扎实，后面画头像会轻松很多。',
    images: ['${_art}sketch-still-3.jpg'],
    video: '${_video}hatching.mp4',
    likes: 176,
    favorites: 112,
    hot: true,
    likedByStudent: true,
    comments: [
      _SeedComment('s:3', '原来我的网格感是这么来的', 22),
      _SeedComment('s:24', '老师示范用的是几 B 的铅笔？', 40),
      _SeedComment('t:t-2', '亮部 2H 到 HB，暗部 2B 到 4B，最重的地方再用炭笔。', 66),
    ],
  ),
  _SeedPost(
    author: 's:5',
    minutesAgo: 29 * 60,
    content:
        '作品分享｜第一次画完整的长期素描，酒瓶的玻璃质感画了三个多小时，洋葱的纹理也一条条'
        '找了结构。暗部感觉还是有点闷，求老师们指点～',
    images: ['${_art}sketch-still-2.jpg'],
    likes: 38,
    favorites: 9,
    comments: [
      _SeedComment(
        't:t-1',
        '酒瓶的高光和反光留得很准，玻璃质感出来了。暗部闷是因为桌面和背景的重色太接近，'
            '把背景稍微提亮、桌面投影压实，空间就出来了。',
        35,
      ),
      _SeedComment('s:5', '谢谢李老师！明天就改', 50),
    ],
  ),
  _SeedPost(
    author: 's:10',
    minutesAgo: 33 * 60,
    content: '画室日常｜作品墙又更新了，从几何体到石膏头像，再到色彩静物。翻到四月份画的立方体，真想把它悄悄藏起来。',
    images: ['${_scene}studio-wall.jpg'],
    likes: 72,
    favorites: 15,
    comments: [
      _SeedComment('s:1', '每次看作品墙都有种升级打怪的感觉', 26),
      _SeedComment('t:t-9', '作品墙会一直保留到联考结束，见证大家的成长。', 58),
    ],
  ),
  _SeedPost(
    author: 't:t-5',
    minutesAgo: 2 * 24 * 60,
    content:
        '色彩小课堂：橙子的暗部不是加黑，而是加入它的补色和环境色。看这张局部，亮部偏柠檬黄，'
        '暗部带一点紫灰，盘子里映着衬布的蓝。笔触顺着形体走，体积感自然就出来了。',
    images: ['${_art}detail-color.jpg'],
    likes: 121,
    favorites: 77,
    likedByStudent: true,
    comments: [
      _SeedComment('s:13', '原来暗部可以画得这么透！', 16),
      _SeedComment('s:2', '王老师，我暗部一加紫就脏，是怎么回事？', 38),
      _SeedComment('t:t-5', '紫色要少量，颜色调准后一次画上去，反复涂改才会脏。', 52),
    ],
  ),
  _SeedPost(
    author: 's:16',
    minutesAgo: 2 * 24 * 60 + 4 * 60,
    content:
        '速写打卡第 37 天：坐姿看书的同学。先找重心线和动态线，再定四肢长度，最后刻画手和书本。'
        '这张用了 15 分钟，比上个月快了一倍。',
    images: ['${_art}speed-figure-2.jpg'],
    likes: 56,
    favorites: 8,
    comments: [_SeedComment('t:t-4', '坐姿的比例很准，小腿和脚的透视还可以再推敲一下。', 44)],
  ),
  _SeedPost(
    author: 's:1',
    minutesAgo: 2 * 24 * 60 + 20 * 60,
    content:
        '模考心得｜九月月考素描进了 A 档！总结三点：动笔前先画构图小稿；大关系一定要先拉开；'
        '最后半小时只做整理，不再加新的细节。下一个目标是色彩也稳定在 85 分以上。',
    images: ['${_art}sketch-still-1.jpg'],
    likes: 143,
    favorites: 34,
    comments: [
      _SeedComment('t:t-1', '这次的作品整体感很好，继续保持！', 30),
      _SeedComment('s:8', '学霸带带我', 46),
      _SeedComment('s:20', '最后半小时只做整理这条太有用了', 70),
      _SeedComment('t:t-3', '色彩那张的问题我们周六一起复盘。', 120),
    ],
  ),
  _SeedPost(
    author: 't:t-6',
    minutesAgo: 3 * 24 * 60,
    content:
        '场景速写示范：街道场景先定视平线，人物按近大远小安排在视平线附近，前景人物刻画完整，'
        '远景人物只画动态和外形。自行车、推车这类道具也要注意透视。',
    images: ['${_art}speed-scene-1.jpg'],
    likes: 88,
    favorites: 52,
    comments: [
      _SeedComment('s:19', '视平线定在人物腰部附近，画面一下就稳了', 36),
      _SeedComment('s:27', '周老师的线条太帅了', 64),
    ],
  ),
  _SeedPost(
    author: 's:14',
    minutesAgo: 3 * 24 * 60 + 6 * 60,
    content: '作品分享｜菊花静物，第一次画玻璃花瓶。蓝色瓶身里的花茎折射好难画，最后用偏紫的蓝加几笔亮色提出了透明感。',
    images: ['${_art}color-flower-1.jpg'],
    likes: 49,
    favorites: 11,
    comments: [_SeedComment('t:t-3', '花瓶的透明感处理得很聪明，白菊花的冷暖变化再丰富一点会更好。', 40)],
  ),
  _SeedPost(
    author: 't:t-7',
    minutesAgo: 4 * 24 * 60,
    content:
        '美术常识小课堂：画室里常见的石膏像大多翻制自古希腊、古罗马和文艺复兴时期的雕塑，'
        '例如米开朗基罗的《大卫》、古希腊的《米洛斯的维纳斯》。画之前了解人物背景，更容易'
        '抓住神态。首页题库已更新 60 道美术常识题，欢迎来刷！',
    images: ['${_art}sketch-bust-3.jpg'],
    likes: 67,
    favorites: 39,
    comments: [
      _SeedComment('s:22', '刷了一轮，外国美术史错了好多', 50),
      _SeedComment('t:t-7', '错题会自动进入错题集，考前再过一遍就好。', 75),
    ],
  ),
  _SeedPost(
    author: 's:17',
    minutesAgo: 4 * 24 * 60 + 3 * 60,
    content: '考前演练｜3 分钟内完成固定画纸、削笔、摆好画具。考场上省下来的每一分钟，都能多用在画面上。',
    images: ['${_art}sketch-geometry-1.jpg'],
    video: '${_video}place-paper.mp4',
    likes: 41,
    favorites: 18,
    comments: [
      _SeedComment('s:1', '学到了，胶带先贴四个角再补边', 28),
      _SeedComment('t:t-9', '考前一周画室会组织一次全流程模拟，大家提前熟悉。', 90),
    ],
  ),
  _SeedPost(
    author: 's:23',
    minutesAgo: 5 * 24 * 60,
    content: '写生日记｜周末去菜市场画速写，大爷和摊主讨价还价的样子太生动了。现场只来得及画动态，回来凭记忆又补了衣纹和道具。',
    images: ['${_art}speed-figure-4.jpg'],
    likes: 58,
    favorites: 13,
    comments: [_SeedComment('t:t-6', '默写补充是很好的习惯，组合人物之间的呼应关系抓得不错。', 55)],
  ),
  _SeedPost(
    author: 't:t-1',
    minutesAgo: 5 * 24 * 60 + 5 * 60,
    content:
        '眼睛的刻画要点：上眼睑有厚度，会在眼球上投下阴影；瞳孔的高光要提前留出来，不要最后'
        '用橡皮硬擦；眉毛按生长方向分组画，不是一根根描。',
    images: ['${_art}detail-sketch.jpg'],
    likes: 104,
    favorites: 71,
    comments: [
      _SeedComment('s:25', '原来上眼睑有厚度！我一直画成一条线', 24),
      _SeedComment('s:1', '收藏，明天石膏五官练习就用', 60),
    ],
  ),
  _SeedPost(
    author: 's:26',
    minutesAgo: 6 * 24 * 60,
    content: '作品分享｜大胡子石膏像 6 小时长期作业。胡子的卷曲按组归纳，先分大的明暗，再挑前面几组刻画，其余的概括掉，这次终于没有画花。',
    images: ['${_art}sketch-bust-2.jpg'],
    likes: 77,
    favorites: 20,
    comments: [_SeedComment('t:t-2', '整体关系很好，额头的结构可以再肯定一些。', 48)],
  ),
  _SeedPost(
    author: 's:28',
    minutesAgo: 6 * 24 * 60 + 8 * 60,
    content: '速写打卡｜放学路上画了两个边走边聊的同学，抓动态比抓细节重要，双肩包的重量感也要画出来。',
    images: ['${_art}speed-figure-3.jpg'],
    likes: 33,
    favorites: 4,
  ),
  _SeedPost(
    author: 's:31',
    minutesAgo: 7 * 24 * 60,
    content:
        '色彩静物｜同一组陶罐和水果的两张作业，一张浅灰背景，一张深褐背景。对比下来，深背景'
        '更容易把白衬布衬亮，但暗部更难画透。',
    images: ['${_art}color-still-5.jpg', '${_art}color-still-1.jpg'],
    likes: 52,
    favorites: 17,
    comments: [
      _SeedComment('t:t-3', '对比练习很有价值，深背景那张白衬布的冷暖画得更好。', 66),
      _SeedComment('s:1', '第二张的陶罐好有分量感', 90),
    ],
  ),
  _SeedPost(
    author: 's:35',
    minutesAgo: 8 * 24 * 60,
    content: '速写打卡｜站姿男青年 10 分钟，手插口袋时肩线和胯线的对比特别明显，正好练一下对立平衡。',
    images: ['${_art}speed-figure-1.jpg'],
    likes: 29,
    favorites: 5,
    comments: [_SeedComment('t:t-4', '重心线落点准确，裤子的衣纹可以再概括一些。', 80)],
  ),
];
