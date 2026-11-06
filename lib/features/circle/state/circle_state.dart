import 'package:flutter/foundation.dart';

/// 校圈删除权限（前端展示用；最终以后端校验为准）。
///
/// 管理员判定：`myInfo` 的 role/identity + `/teacher/teacherRole` 返回的
/// roles CSV（含 `headmaster` / `manager` / `principal` / `admin` 任一即
/// 视为最高权限管理员）。
///
/// - 删帖：管理员任意删；普通用户仅删自己发布的帖子。
/// - 删评论：管理员任意删；评论作者删自己的评论；**帖子作者**可删自己
///   帖子下的任意评论（普通用户管理自己动态下的评论）。
@immutable
class CirclePermissions {
  const CirclePermissions({required this.currentUserId, required this.isAdmin});

  final String currentUserId;
  final bool isAdmin;

  bool canDeletePost(CirclePost post) {
    if (isAdmin) return true;
    if (currentUserId.isEmpty) return false;
    return currentUserId == post.author.id;
  }

  bool canDeleteComment(CirclePost post, CircleComment comment) {
    if (isAdmin) return true;
    if (currentUserId.isEmpty) return false;
    return currentUserId == comment.author.id ||
        currentUserId == post.author.id;
  }

  static bool shellUserIsAdmin({required String role, required String identity}) {
    if (role.trim().toLowerCase() == 'admin') return true;
    if (identity.contains('教务老师') || identity.contains('管理员')) return true;
    if (identity.contains('校长')) return true;
    return false;
  }

  /// `teacherRole` 接口 `roles` CSV 里表示管理员/校长的 token。
  /// 与 [SmartCampusController._teacherRoleTokenToCampus] 对齐。
  static const Set<String> _teacherRoleAdminTokens = {
    'headmaster',
    'manager',
    'principal',
    'admin',
  };

  static bool teacherRoleTokenIsAdmin(String token) {
    return _teacherRoleAdminTokens.contains(token.trim().toLowerCase());
  }

  /// 解析 `/app/school/v2/teacher/teacherRole` 返回体，判断身份集合中是否
  /// 包含管理员。多重身份时只要含 admin 类 token，即视为最高权限管理员。
  static bool teacherRoleDataHasAdmin(dynamic data) {
    if (data is! List) return false;
    for (final item in data) {
      if (item is! Map) continue;
      final raw = item['roles'];
      if (raw is! String || raw.isEmpty) continue;
      for (final token in raw.split(',')) {
        if (teacherRoleTokenIsAdmin(token)) return true;
      }
    }
    return false;
  }

  /// 是否应调用 `teacherRole` 以补全校圈管理员判定。
  ///
  /// 已从 myInfo 判定为管理员 / 学生时跳过；其余身份（如 `teacher`、
  /// `headTeacher`）仍可能通过 teacherRole 携带 `headmaster` 等管理员 token。
  static bool shouldFetchTeacherRole({
    required String role,
    required String identity,
  }) {
    if (shellUserIsAdmin(role: role, identity: identity)) return false;
    final normalized = role.trim().toLowerCase().replaceAll(RegExp(r'[_\-]'), '');
    if (normalized == 'student' || normalized == 'stu' || normalized == 'pupil') {
      return false;
    }
    if (identity.contains('学生') || identity.contains('同学')) return false;
    return true;
  }
}

/// 校圈帖子列表的排序方式（与后端 `PostsListReq.sortType` 一一对应）。
///   0-最新发布 / 1-热门推荐 / 2-为你推荐
enum CircleSortType { latest, hot, recommended }

extension CircleSortTypeApi on CircleSortType {
  int get apiCode => switch (this) {
    CircleSortType.latest => 0,
    CircleSortType.hot => 1,
    CircleSortType.recommended => 2,
  };

  String get label => switch (this) {
    CircleSortType.latest => '最新发布',
    CircleSortType.hot => '热门推荐',
    CircleSortType.recommended => '为你推荐',
  };
}

/// 校圈帖子按内容形态过滤（与后端 `PostsListReq.type` 一一对应）。
///   0-文章 / 1-图片 / 2-视频 / 3-音乐；`null` 代表不限。
enum CirclePostType { article, image, video, music }

extension CirclePostTypeApi on CirclePostType {
  int get apiCode => switch (this) {
    CirclePostType.article => 0,
    CirclePostType.image => 1,
    CirclePostType.video => 2,
    CirclePostType.music => 3,
  };

  String get label => switch (this) {
    CirclePostType.article => '文章',
    CirclePostType.image => '图片',
    CirclePostType.video => '视频',
    CirclePostType.music => '音乐',
  };
}

/// 校圈页面的两种展示模式：沉浸（抖音风全屏单帖）/ 列表（瀑布流多帖）。
enum CircleMode { immersive, list }

/// 帖子标签：置顶 / 热门。
enum CircleBadge { pinned, hot }

/// 校圈发布动态时支持的媒体类型：图片 / 视频 / 音频，均可附带文本。
enum PostMediaKind { image, video, audio }

@immutable
class CircleAuthor {
  const CircleAuthor({
    required this.id,
    required this.name,
    required this.role,
    required this.avatarUrl,
  });

  final String id;
  final String name;
  final String role;
  final String avatarUrl;
}

@immutable
class CircleComment {
  const CircleComment({
    required this.id,
    required this.author,
    required this.text,
    required this.timeLabel,
    required this.likeCount,
    this.liked = false,
  });

  final String id;
  final CircleAuthor author;
  final String text;
  final String timeLabel;
  final int likeCount;
  final bool liked;

  CircleComment copyWith({int? likeCount, bool? liked}) => CircleComment(
    id: id,
    author: author,
    text: text,
    timeLabel: timeLabel,
    likeCount: likeCount ?? this.likeCount,
    liked: liked ?? this.liked,
  );
}

@immutable
class CirclePost {
  const CirclePost({
    required this.id,
    required this.author,
    required this.badges,
    required this.text,
    required this.timeLabel,
    required this.imageUrl,
    required this.imageAspectRatio,
    required this.likeCount,
    required this.commentCount,
    required this.favoriteCount,
    required this.liked,
    required this.favorited,
    required this.comments,
    this.mediaKind = PostMediaKind.image,
    this.mediaUrls = const <String>[],
    this.hasExplicitAspectRatio = false,
  });

  final String id;
  final CircleAuthor author;
  final List<CircleBadge> badges;
  final String text;
  final String timeLabel;

  /// 列表卡片用的封面 URL（已经过 [MediaUrl.resolve] 拼好域名）。
  ///
  /// - 图片帖：等于第一张原图
  /// - 视频帖：等于 `coverImg`（视频封面），可能为空
  /// - 音频帖：等于 `coverImg`（专辑封面），可能为空
  final String imageUrl;

  /// 列表瀑布流所需的图片宽高比（width / height），用于决定卡片高度。
  final double imageAspectRatio;

  /// [imageAspectRatio] 是否来自接口给出的真实宽高，而不是前端兜底值。
  final bool hasExplicitAspectRatio;

  final int likeCount;
  final int commentCount;
  final int favoriteCount;
  final bool liked;
  final bool favorited;
  final List<CircleComment> comments;

  /// 内容形态：image / video / audio。来自后端 `type` 字段：
  /// 1=图片 / 2=视频 / 3=音乐；`type==0`（文章）暂按图片处理。
  final PostMediaKind mediaKind;

  /// 与 `mediaKind` 配套的资源地址列表，已 resolve 过域名。
  /// - 图片帖：可能多张
  /// - 视频帖：通常 1 个
  /// - 音频帖：通常 1 个
  final List<String> mediaUrls;

  /// 主资源地址（首项），便于内联播放器直接拿来用。
  String get primaryMediaUrl => mediaUrls.isEmpty ? '' : mediaUrls.first;

  CirclePost copyWith({
    int? likeCount,
    int? commentCount,
    int? favoriteCount,
    bool? liked,
    bool? favorited,
    List<CircleComment>? comments,
  }) {
    return CirclePost(
      id: id,
      author: author,
      badges: badges,
      text: text,
      timeLabel: timeLabel,
      imageUrl: imageUrl,
      imageAspectRatio: imageAspectRatio,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      liked: liked ?? this.liked,
      favorited: favorited ?? this.favorited,
      comments: comments ?? this.comments,
      mediaKind: mediaKind,
      mediaUrls: mediaUrls,
      hasExplicitAspectRatio: hasExplicitAspectRatio,
    );
  }
}

@immutable
class CircleState {
  const CircleState({
    required this.mode,
    required this.posts,
    required this.searchKeyword,
    required this.unreadCount,
    required this.immersiveIndex,
    required this.commentPanelOpen,
    required this.commentTargetPostId,
    required this.listLoading,
    required this.sortType,
    this.typeFilter,
    this.commentsLoadingPostId,
    this.mediaStopEpoch = 0,
  });

  factory CircleState.initial() {
    return const CircleState(
      mode: CircleMode.list,
      posts: [],
      searchKeyword: '',
      unreadCount: 0,
      immersiveIndex: 0,
      commentPanelOpen: false,
      commentTargetPostId: '',
      listLoading: true,
      sortType: CircleSortType.latest,
      typeFilter: null,
      commentsLoadingPostId: null,
    );
  }

  final CircleMode mode;
  final List<CirclePost> posts;
  final String searchKeyword;
  final int unreadCount;
  final int immersiveIndex;
  final bool commentPanelOpen;
  final String commentTargetPostId;

  /// 首次拉取帖子列表时为 true；下拉刷新时同样走 [CircleController.refreshPosts]。
  final bool listLoading;

  /// 列表排序：与 `postsList` 的 `sortType` 一致。
  final CircleSortType sortType;

  /// 按内容形态过滤：`null` 表示不限；与 `postsList` 的 `type` 一致。
  final CirclePostType? typeFilter;

  /// 非 null 表示正在为该 `postsId` 拉取评论列表（评论面板内展示 loading）。
  final String? commentsLoadingPostId;

  /// 递增后通知沉浸播放器立即停止（退出页面 / 离开沉浸模式）。
  final int mediaStopEpoch;

  /// 搜索关键字过滤后的帖子（列表 / 沉浸共用）。
  List<CirclePost> get visiblePosts {
    final k = searchKeyword.trim();
    if (k.isEmpty) return posts;
    return [
      for (final p in posts)
        if (p.text.contains(k) ||
            p.author.name.contains(k) ||
            (p.author.role.isNotEmpty && p.author.role.contains(k)))
          p,
    ];
  }

  CirclePost? get currentImmersivePost {
    final list = visiblePosts;
    if (list.isEmpty) return null;
    final i = immersiveIndex.clamp(0, list.length - 1);
    return list[i];
  }

  CirclePost? get commentTargetPost {
    if (commentTargetPostId.isEmpty) return null;
    for (final p in posts) {
      if (p.id == commentTargetPostId) return p;
    }
    return null;
  }

  CircleState copyWith({
    CircleMode? mode,
    List<CirclePost>? posts,
    String? searchKeyword,
    int? unreadCount,
    int? immersiveIndex,
    bool? commentPanelOpen,
    String? commentTargetPostId,
    bool? listLoading,
    CircleSortType? sortType,
    CirclePostType? typeFilter,
    bool clearTypeFilter = false,
    String? commentsLoadingPostId,
    bool clearCommentsLoading = false,
    int? mediaStopEpoch,
  }) {
    return CircleState(
      mode: mode ?? this.mode,
      posts: posts ?? this.posts,
      searchKeyword: searchKeyword ?? this.searchKeyword,
      unreadCount: unreadCount ?? this.unreadCount,
      immersiveIndex: immersiveIndex ?? this.immersiveIndex,
      commentPanelOpen: commentPanelOpen ?? this.commentPanelOpen,
      commentTargetPostId: commentTargetPostId ?? this.commentTargetPostId,
      listLoading: listLoading ?? this.listLoading,
      sortType: sortType ?? this.sortType,
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      commentsLoadingPostId: clearCommentsLoading
          ? null
          : (commentsLoadingPostId ?? this.commentsLoadingPostId),
      mediaStopEpoch: mediaStopEpoch ?? this.mediaStopEpoch,
    );
  }
}

/// 把数字格式化为 "12.3w" 这样的展示形式。
String formatCircleCount(int count) {
  if (count < 10000) return count.toString();
  final value = count / 10000;
  if (value >= 100) return '${value.toStringAsFixed(0)}w';
  return '${value.toStringAsFixed(1)}w';
}

/// 列表卡片作者身份展示：英文 role 映射为中文，其余原样返回。
String formatCircleAuthorRole(String role) {
  switch (role.trim().toLowerCase()) {
    case 'teacher':
      return '教师';
    case 'student':
    case 'stu':
    case 'pupil':
      return '学生';
    default:
      return role;
  }
}
