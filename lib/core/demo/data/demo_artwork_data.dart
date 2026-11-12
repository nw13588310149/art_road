/// 作品档案 / 作品点评演示数据（移植自学情小程序的演示作品）：学生日常作品、
/// 多位老师的独立点评、老师私有的点评标签与批注，学生端与教师端共用一份。
///
/// 作品：`{id, personIndex, title, subject, drawingDate, createTime,
/// description, images: [{id, ref}], teacherIds, reviews}`；
/// 点评：`{teacherId, score|null, maxScore, content, reviewedTime,
/// tags: [{id, name, explanation, color}]}`，标签按点评当时的内容存快照。
/// 状态与最终分不落盘，读取时由 [DemoArtworkData.aggregate] 计算。
library;

import 'dart:math' as math;

import '../demo_accounts.dart';
import 'demo_campus_data.dart';
import 'demo_marking_data.dart';

class _SeedReview {
  const _SeedReview(
    this.teacherId,
    this.score,
    this.content, [
    this.tags = const <int>[],
    this.time = '',
  ]);

  final String teacherId;
  final double? score;
  final String content;

  /// 老师标签序号（从 1 开始；8 为该老师的专属标签）。
  final List<int> tags;

  /// 指定的点评时间 `yyyy-MM-dd HH:mm:ss`；为空时取绘画日期次日的晚自习时段。
  final String time;
}

class _SeedWork {
  const _SeedWork({
    required this.person,
    required this.title,
    required this.subject,
    required this.date,
    required this.images,
    required this.teachers,
    this.description = '',
    this.reviews = const <_SeedReview>[],
  });

  final int person;
  final String title;
  final String subject;
  final String date;

  /// `assets/demo/` 下的相对路径。
  final List<String> images;
  final List<String> teachers;
  final String description;
  final List<_SeedReview> reviews;
}

class _TagStat {
  _TagStat(this.name);

  final String name;
  int count = 0;
  String color = '';
  String explanation = '';
  String latest = '';
  final Map<String, int> subjects = <String, int>{};
}

typedef DemoArtworkAggregate = ({
  String status,
  double? finalScore,
  double maxScore,
  int teacherCount,
  int reviewedCount,
});

abstract final class DemoArtworkData {
  // v2：分数、提交时间、标签类型与批注颜色调整后，旧的本地演示数据不再沿用。
  static const worksKey = 'artworks:v3';
  static const annotationsKey = 'artwork_annotations:v2';
  static const uploadsKey = 'artwork_uploads:v2';

  static String tagsKey(String teacherId) => 'artwork_tags:v2:$teacherId';

  static const statusReviewed = 'REVIEWED';
  static const statusPending = 'PENDING';

  static String tagId(String teacherId, int index) => '$teacherId-tag-$index';

  static String teacherName(String teacherId) {
    for (final teacher in DemoMarkingData.reviewTeachers) {
      if (teacher.id == teacherId) {
        return teacher.name;
      }
    }
    return '老师';
  }

  static bool isReviewTeacher(String teacherId) =>
      DemoMarkingData.reviewTeachers.any((t) => t.id == teacherId);

  /// 学生新提交的作品：指派给演示任课老师李静，色彩 / 速写再加上对应科目老师。
  static List<String> teachersForNewWork(String subject) => switch (subject) {
    '色彩' => <String>['t-1', 't-3'],
    '速写' => <String>['t-1', 't-4'],
    _ => <String>['t-1'],
  };

  // ── 读取工具（兼容种子数据与 JSON 往返后的结构） ─────────────────────

  static List<String> teacherIdsOf(Map<String, dynamic> work) {
    final raw = work['teacherIds'];
    return raw is List
        ? raw.map((e) => e.toString()).toList()
        : const <String>[];
  }

  static List<Map<String, dynamic>> mapsOf(Object? raw) {
    if (raw is! List) {
      return const <Map<String, dynamic>>[];
    }
    return <Map<String, dynamic>>[
      for (final item in raw)
        if (item is Map) item.map((k, v) => MapEntry(k.toString(), v)),
    ];
  }

  static List<Map<String, dynamic>> reviewsOf(Map<String, dynamic> work) =>
      mapsOf(work['reviews']);

  static List<Map<String, dynamic>> imagesOf(Map<String, dynamic> work) =>
      mapsOf(work['images']);

  static List<Map<String, dynamic>> tagsOf(Map<String, dynamic> review) =>
      mapsOf(review['tags']);

  static Map<String, dynamic>? reviewOf(
    Map<String, dynamic> work,
    String teacherId,
  ) {
    for (final review in reviewsOf(work)) {
      if (review['teacherId']?.toString() == teacherId) {
        return review;
      }
    }
    return null;
  }

  /// 老师当前有效的点评：被组长退回、还没重新保存的不算。
  static Map<String, dynamic>? activeReviewOf(
    Map<String, dynamic> work,
    String teacherId,
  ) {
    final review = reviewOf(work, teacherId);
    return isReturned(review) ? null : review;
  }

  static bool hasReviewed(Map<String, dynamic> work, String teacherId) =>
      activeReviewOf(work, teacherId) != null;

  static double round2(double value) => (value * 100).round() / 100;

  /// 全部指派老师都点评后为 REVIEWED；最终分为已打分点评的平均分（两位小数），
  /// 未全部点评或没有老师打分时为 null。
  static DemoArtworkAggregate aggregate(Map<String, dynamic> work) {
    final teacherIds = teacherIdsOf(work);
    final reviews = reviewsOf(work)
        .where(
          (r) =>
              teacherIds.contains(r['teacherId']?.toString()) && !isReturned(r),
        )
        .toList();
    final reviewedCount = teacherIds
        .where((id) => reviews.any((r) => r['teacherId']?.toString() == id))
        .length;
    final done = teacherIds.isNotEmpty && reviewedCount == teacherIds.length;
    final scored = <Map<String, dynamic>>[
      for (final review in reviews)
        if (review['score'] is num) review,
    ];
    final maxScore = scored.isEmpty
        ? 100.0
        : ((scored.first['maxScore'] as num?) ?? 100).toDouble();
    double? finalScore;
    if (done && scored.isNotEmpty) {
      final sum = scored.fold<double>(
        0,
        (total, r) => total + (r['score'] as num).toDouble(),
      );
      finalScore = round2(sum / scored.length);
    }
    // 组长复核时改定了分数，以组长的分数为准。
    final lead = leadReviewOf(work);
    if (done &&
        lead != null &&
        lead['action'] == leadApproved &&
        lead['score'] is num) {
      finalScore = round2((lead['score'] as num).toDouble());
    }
    return (
      status: done ? statusReviewed : statusPending,
      finalScore: finalScore,
      maxScore: maxScore,
      teacherCount: teacherIds.length,
      reviewedCount: reviewedCount,
    );
  }

  // ── 组长复核 ─────────────────────────────────────────────────────────

  static const leadApproved = 'APPROVED';
  static const leadReturned = 'RETURNED';

  /// 复核状态：不需要复核 / 等老师点评 / 待复核，以及上面的已通过、已退回。
  static const leadNone = 'NONE';
  static const leadWaiting = 'WAITING';
  static const leadPending = 'PENDING';

  /// 负责复核这份作品的科目组长（教职工 id）。科目没有科目组，或作品只指派给
  /// 组长本人时不需要复核，返回 null。
  static String? leadIdOf(Map<String, dynamic> work) {
    final leadId = DemoCampusData.groupOfSubject(
      work['subject']?.toString() ?? '',
    )?.leadId;
    if (leadId == null) {
      return null;
    }
    return teacherIdsOf(work).any((id) => id != leadId) ? leadId : null;
  }

  static Map<String, dynamic>? leadReviewOf(Map<String, dynamic> work) {
    final raw = work['leadReview'];
    return raw is Map ? raw.map((k, v) => MapEntry(k.toString(), v)) : null;
  }

  /// 被组长退回、等老师重新点评的点评。
  static bool isReturned(Map<String, dynamic>? review) =>
      review != null && review['returned'] == true;

  static String leadStatusOf(Map<String, dynamic> work) {
    if (leadIdOf(work) == null) {
      return leadNone;
    }
    final review = leadReviewOf(work);
    if (review != null) {
      return review['action'] == leadReturned ? leadReturned : leadApproved;
    }
    return aggregate(work).status == statusReviewed ? leadPending : leadWaiting;
  }

  /// 组长有体验账号时由本人登录复核；没有体验账号的组长在老师点评完成后自动通过。
  static bool leadHasAccount(String leadId) =>
      DemoAccounts.all.any((a) => a.teacherId == leadId);

  static Map<String, dynamic> autoLeadReview(String leadId, String time) =>
      <String, dynamic>{
        'leadId': leadId,
        'action': leadApproved,
        'content': '',
        'score': null,
        'exemplar': false,
        'attention': false,
        'reviewedTime': time,
      };

  // ── 高频问题 ─────────────────────────────────────────────────────────

  static const _advice = <String, (String, String, String, String)>{
    '结构错误': ('起形时用辅助线核对比例和骨点，完成后镜像翻转检查形准。', '素描', '结构', '镜像'),
    '明暗层次弱': ('眯眼概括黑白灰三大关系，先拉开明暗交界线两侧的对比。', '素描', '明暗', '明度检查'),
    '构图失衡': ('动笔前先画 2–3 个小构图，确定主体的位置与大小。', '素描', '构图', '构图网格'),
    '线条生硬': ('多练长线条的轻重虚实，衣纹注意疏密与节奏。', '速写', '线条', '速写计时'),
    '色调不统一': ('先定整体色调，再用环境色统一画面的冷暖关系。', '色彩', '色调', '取色色卡'),
    '透视错误': ('先确定视平线和消失点，椭圆注意近宽远窄的透视变化。', '素描', '透视', '透视辅助'),
    '环境色不足': ('暗部与投影里加入周围的环境色，让物体融入空间。', '色彩', '环境色', '取色色卡'),
    '暗部偏闷': ('暗部加入反光与冷暖变化，避免一遍平涂。', '素描', '暗部', '明度检查'),
    '动态僵硬': ('先用几根动态线确定重心与动势，再刻画细节。', '速写', '动态', '速写计时'),
  };

  /// 点评标签两类，接口以颜色区分：亮点绿色，问题琥珀色（与 `ArtworkRules` 一致）。
  static const highlightColor = '#3B9A6E';
  static const problemColor = '#B9770F';

  static bool _isHighlight(String name, String color) =>
      color.toUpperCase() == highlightColor || name == '细节出彩';

  /// 学生「我的高频问题」：只统计已完成点评（学生可见）的作品。
  static Map<String, dynamic> insightsOf(List<Map<String, dynamic>> works) {
    final stats = <String, _TagStat>{};
    final subjectScores = <String, List<double>>{};
    final finals = <double>[];
    var reviewedCount = 0;
    for (final work in works) {
      final summary = aggregate(work);
      if (summary.status != statusReviewed) {
        continue;
      }
      reviewedCount++;
      final subject = work['subject']?.toString() ?? '';
      final score = summary.finalScore;
      if (score != null) {
        finals.add(score);
        subjectScores.putIfAbsent(subject, () => <double>[]).add(score);
      }
      for (final review in reviewsOf(work)) {
        final time = review['reviewedTime']?.toString() ?? '';
        for (final tag in tagsOf(review)) {
          final name = tag['name']?.toString() ?? '';
          if (name.isEmpty) {
            continue;
          }
          final stat = stats.putIfAbsent(name, () => _TagStat(name));
          stat.count++;
          stat.subjects[subject] = (stat.subjects[subject] ?? 0) + 1;
          if (time.compareTo(stat.latest) >= 0) {
            stat.latest = time;
            stat.color = tag['color']?.toString() ?? '';
            stat.explanation = tag['explanation']?.toString() ?? '';
          }
        }
      }
    }
    final ranked = stats.values.toList()
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0 ? byCount : b.latest.compareTo(a.latest);
      });

    final means = <String, double>{
      for (final entry in subjectScores.entries)
        entry.key: round2(
          entry.value.reduce((a, b) => a + b) / entry.value.length,
        ),
    };
    final bySubject = means.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return <String, dynamic>{
      'reviewedCount': reviewedCount,
      'averageScore': finals.isEmpty
          ? null
          : round2(finals.reduce((a, b) => a + b) / finals.length),
      'bestSubject': bySubject.isEmpty ? '' : bySubject.first.key,
      'weakestSubject': bySubject.length < 2 ? '' : bySubject.last.key,
      'topTags': <Map<String, dynamic>>[
        for (final stat in ranked.take(5))
          <String, dynamic>{
            'name': stat.name,
            'color': stat.color,
            'count': stat.count,
            'explanation': stat.explanation,
            'positive': _isHighlight(stat.name, stat.color),
          },
      ],
      'suggestions': <Map<String, dynamic>>[
        for (final stat
            in ranked.where((s) => !_isHighlight(s.name, s.color)).take(3))
          _suggestionOf(stat),
      ],
    };
  }

  static Map<String, dynamic> _suggestionOf(_TagStat stat) {
    final advice = _advice[stat.name];
    final dominant =
        (stat.subjects.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .map((e) => e.key)
            .firstWhere(
              (s) => const {'素描', '色彩', '速写'}.contains(s),
              orElse: () => advice?.$2 ?? '素描',
            );
    return <String, dynamic>{
      'tag': stat.name,
      'color': stat.color,
      'count': stat.count,
      'text':
          advice?.$1 ??
          (stat.explanation.isNotEmpty
              ? stat.explanation
              : '对照老师的点评，挑选同类范画针对性练习。'),
      'gallerySubject': dominant,
      'galleryKeyword': advice?.$3 ?? stat.name,
      'tool': advice?.$4 ?? '',
    };
  }

  // ── 标签 ─────────────────────────────────────────────────────────────

  static const _standardTags = <(String, String, String)>[
    ('结构错误', '形体比例或透视关系不准确。先用辅助线核对大的比例和骨点位置，再深入刻画。', problemColor),
    ('明暗层次弱', '黑白灰关系没有拉开，暗部与亮部之间的过渡层次不足，画面显得发平。', problemColor),
    ('构图失衡', '主体位置或大小不合适，画面重心偏移。动笔前先用小构图推敲布局。', problemColor),
    ('线条生硬', '线条缺少轻重、虚实变化，转折处可以更有节奏，避免描边式的均匀线条。', problemColor),
    ('色调不统一', '画面冷暖倾向不明确，局部颜色跳出整体色调，注意环境色的相互影响。', problemColor),
    ('细节出彩', '局部刻画深入到位，质感与空间表现准确，值得在后续作品中保持。', highlightColor),
    ('透视错误', '近大远小和消失点不统一，先确定视平线和主要透视线再起形。', problemColor),
  ];

  static const _exclusiveTags = <String, (String, String, String)>{
    't-2': ('暗部偏闷', '暗部笔触过于平涂，缺少反光和细微变化。', problemColor),
    't-3': ('环境色不足', '物体暗部和投影缺少周围环境色的影响，颜色显得孤立。', problemColor),
    't-4': ('动态僵硬', '人物重心和动势不明确，动作像摆拍，先用几根动态线确定姿态。', problemColor),
  };

  /// 演示前的历史用量（这些老师此前点评过的作品不在演示列表里）。
  static const _historyUsage = <int>[12, 9, 5, 8, 4, 7, 3, 2];

  static List<(String, String, String)> _tagDefs(String teacherId) =>
      <(String, String, String)>[..._standardTags, ?_exclusiveTags[teacherId]];

  static List<Map<String, dynamic>> seedTags(String teacherId) {
    final defs = _tagDefs(teacherId);
    final history = isReviewTeacher(teacherId);
    final works = history ? seedWorks() : const <Map<String, dynamic>>[];
    int usage(String id) => works.where((work) {
      final review = reviewOf(work, teacherId);
      return review != null && tagsOf(review).any((t) => t['id'] == id);
    }).length;
    return <Map<String, dynamic>>[
      for (var i = 0; i < defs.length; i++)
        <String, dynamic>{
          'id': tagId(teacherId, i + 1),
          'name': defs[i].$1,
          'explanation': defs[i].$2,
          'color': defs[i].$3,
          'usageCount': history
              ? _historyUsage[i] + usage(tagId(teacherId, i + 1))
              : 0,
        },
    ];
  }

  // ── 作品 ─────────────────────────────────────────────────────────────

  static const _seeds = <_SeedWork>[
    // 学生演示账号林小雨：两份待点评（在李静的队列里），六份已完成点评。
    // 日常作品各科均分与学情中心月考一致：素描最高、速写次之、色彩有待加强。
    _SeedWork(
      person: 1,
      title: '石膏头像长期作业',
      subject: '素描',
      date: '2026-11-03',
      images: ['art/sketch-bust-1.jpg', 'art/detail-sketch.jpg'],
      description: '画了两个课时，重点练习头部结构和明暗交界线，耳朵的位置感觉没有画准。',
      teachers: ['t-1'],
    ),
    _SeedWork(
      person: 1,
      title: '花卉色彩写生',
      subject: '色彩',
      date: '2026-11-05',
      images: ['art/color-flower-1.jpg'],
      description: '尝试了偏暖的整体色调，花瓣的颜色不知道是不是太跳。',
      teachers: ['t-1', 't-3'],
      reviews: [
        _SeedReview('t-3', 83, '花卉的色彩倾向明确，花瓣边缘的虚实处理得不错，背景还可以再统一一些。', [6, 5]),
      ],
    ),
    _SeedWork(
      person: 1,
      title: '秋日静物色彩写生',
      subject: '色彩',
      date: '2026-10-25',
      images: ['art/color-still-2.jpg'],
      description: '尝试用补色处理暗部。',
      teachers: ['t-3'],
      reviews: [
        _SeedReview('t-3', 83, '画面完整，色彩关系清楚。继续关注边缘虚实与主次关系，暗部层次还可以更丰富。', [6, 8]),
      ],
    ),
    _SeedWork(
      person: 1,
      title: '人物动态速写',
      subject: '速写',
      date: '2026-10-22',
      images: [
        'art/speed-figure-1.jpg',
        'art/speed-figure-3.jpg',
        'art/speed-figure-4.jpg',
      ],
      teachers: ['t-1', 't-4'],
      reviews: [
        _SeedReview('t-1', 84, '人物重心稳定，外套的衣纹线条略显均匀，注意疏密与轻重变化。', [4]),
        _SeedReview('t-4', 86, '动态抓取比较准确，人物重心稳定。下一次加强手部的结构交代，让线条更有节奏。', [4, 1]),
      ],
    ),
    _SeedWork(
      person: 1,
      title: '几何体明暗关系',
      subject: '素描',
      date: '2026-10-18',
      images: ['art/sketch-geometry-1.jpg'],
      description: '练习投影和反光。',
      teachers: ['t-1'],
      reviews: [
        _SeedReview('t-1', 91, '明暗交界线处理肯定，投影的虚实关系得当，整体完成度高。', [6]),
      ],
    ),
    // 与平台消息「李静老师点评了你的《石膏头像结构练习》」保持一致。
    _SeedWork(
      person: 1,
      title: '石膏头像结构练习',
      subject: '素描',
      date: '2026-11-04',
      images: ['art/sketch-bust-3.jpg'],
      description: '这次重点练习头部结构和明暗交界线。',
      teachers: ['t-1', 't-2'],
      reviews: [
        _SeedReview(
          't-1',
          88,
          '结构交代清楚，暗部再整体一些；五官位置略有偏差，先用三庭五眼核对比例再刻画细节。',
          [2],
          '2026-11-06 09:10:00',
        ),
        _SeedReview('t-2', 86, '暗部笔触偏平，反光和投影的层次可以再拉开。', [8, 1]),
      ],
    ),
    _SeedWork(
      person: 1,
      title: '暖色调静物组合',
      subject: '色彩',
      date: '2026-09-26',
      images: ['art/color-still-4.jpg'],
      teachers: ['t-3'],
      reviews: [
        _SeedReview('t-3', 80, '色彩关系较协调，冷暖对比还可以拉开，背景用笔再概括一些。', [5]),
      ],
    ),
    _SeedWork(
      person: 1,
      title: '静物结构素描',
      subject: '素描',
      date: '2026-08-30',
      images: ['art/sketch-still-2.jpg'],
      description: '第一次画玻璃瓶，反光有点难。',
      teachers: ['t-1'],
      reviews: [
        _SeedReview('t-1', 82, '碗口的透视椭圆偏窄，瓶身中轴线要垂直；右侧衬布占比过大，画面重心偏右。', [
          7,
          1,
          3,
        ]),
      ],
    ),
    // 李静的待点评队列（另有林小雨的两份）。
    _SeedWork(
      person: 4,
      title: '秋日静物色彩写生',
      subject: '色彩',
      date: '2026-10-29',
      images: ['art/color-still-3.jpg'],
      description: '尝试了偏暖的整体色调。',
      teachers: ['t-1', 't-3'],
      reviews: [
        _SeedReview('t-3', 86, '色彩关系整体协调，暗部可以再加入一些环境色。', [8]),
      ],
    ),
    _SeedWork(
      person: 6,
      title: '人物动态速写',
      subject: '速写',
      date: '2026-10-28',
      images: ['art/speed-figure-2.jpg'],
      teachers: ['t-1', 't-4'],
    ),
    _SeedWork(
      person: 9,
      title: '静物组合明暗',
      subject: '素描',
      date: '2026-10-27',
      images: ['art/sketch-still-1.jpg'],
      description: '想请老师看一下投影的处理。',
      teachers: ['t-1'],
    ),
    _SeedWork(
      person: 12,
      title: '暖色调静物组合',
      subject: '色彩',
      date: '2026-10-26',
      images: ['art/color-still-5.jpg'],
      teachers: ['t-1'],
    ),
    _SeedWork(
      person: 30,
      title: '色彩风景写生',
      subject: '色彩',
      date: '2026-11-02',
      images: ['art/color-landscape-1.jpg'],
      description: '第一次画户外风景。',
      teachers: ['t-1'],
    ),
    // 李静已点评。
    _SeedWork(
      person: 15,
      title: '校园人物速写',
      subject: '速写',
      date: '2026-10-24',
      images: ['art/speed-figure-5.jpg'],
      description: '课间在操场画的。',
      teachers: ['t-1'],
      reviews: [
        _SeedReview('t-1', 84, '人物动态抓得准，衣纹线条略显均匀，注意疏密与轻重变化。', [4]),
      ],
    ),
    _SeedWork(
      person: 18,
      title: '石膏五官写生',
      subject: '素描',
      date: '2026-10-22',
      images: ['art/sketch-bust-2.jpg', 'art/detail-sketch.jpg'],
      teachers: ['t-1', 't-2'],
      reviews: [
        _SeedReview('t-1', 78, '五官位置偏差较大，建议先找准三庭五眼再刻画细节。', [1, 2]),
        _SeedReview('t-2', 80, '', [8]),
      ],
    ),
    _SeedWork(
      person: 21,
      title: '罐子与水果色彩',
      subject: '色彩',
      date: '2026-10-20',
      images: ['art/color-still-1.jpg'],
      teachers: ['t-1'],
      reviews: [
        _SeedReview('t-1', 88, '水果的质感表现很好，背景可以再概括一些。', [6]),
      ],
    ),
    _SeedWork(
      person: 2,
      title: '长期素描头像',
      subject: '素描',
      date: '2026-10-16',
      images: ['art/sketch-portrait-1.jpg'],
      description: '画了三个课时。',
      teachers: ['t-1'],
      reviews: [
        _SeedReview('t-1', 91, '整体完成度高，结构扎实，暗部层次丰富。', [6]),
      ],
    ),
    _SeedWork(
      person: 25,
      title: '街景速写',
      subject: '速写',
      date: '2026-10-15',
      images: ['art/speed-scene-1.jpg'],
      teachers: ['t-1'],
      reviews: [
        _SeedReview('t-1', null, '画面元素安排偏满，主体人物不够突出，下次先确定视觉中心。', [3]),
      ],
    ),
    _SeedWork(
      person: 34,
      title: '静物素描组合',
      subject: '素描',
      date: '2026-10-10',
      images: ['art/sketch-still-3.jpg'],
      teachers: ['t-1', 't-2'],
      reviews: [
        _SeedReview('t-2', 82, '形体塑造扎实，背景衬布的褶皱可以再概括。'),
        _SeedReview('t-1', 85, '物体之间的空间关系清楚，陶罐的高光略显生硬。', [6]),
      ],
    ),
    _SeedWork(
      person: 2,
      title: '静物色彩小稿',
      subject: '色彩',
      date: '2026-09-26',
      images: ['papers/color.jpg'],
      teachers: ['t-1'],
      reviews: [
        _SeedReview('t-1', 79, '色彩关系较协调，冷暖对比还可以拉开，背景用笔再概括一些。', [5]),
      ],
    ),
    _SeedWork(
      person: 4,
      title: '人物头像速写',
      subject: '速写',
      date: '2026-09-24',
      images: ['art/speed-figure-4.jpg'],
      teachers: ['t-1'],
      reviews: [
        _SeedReview('t-1', 85, '动态比较自然，线条有节奏，手脚的结构交代可以更清楚。', [4]),
      ],
    ),
    _SeedWork(
      person: 6,
      title: '几何体组合素描',
      subject: '素描',
      date: '2026-09-22',
      images: ['papers/sketch.jpg'],
      teachers: ['t-1'],
      reviews: [
        _SeedReview('t-1', 76, '形体基本准确，明暗交界线可以再肯定一些，立方体的透视要统一。', [2, 7]),
      ],
    ),
    _SeedWork(
      person: 9,
      title: '蔬菜静物写生',
      subject: '色彩',
      date: '2026-09-20',
      images: ['art/detail-color.jpg'],
      teachers: ['t-1'],
      reviews: [
        _SeedReview('t-1', 87, '固有色把握准确，蔬菜的质感表现生动。', [6]),
      ],
    ),
    _SeedWork(
      person: 12,
      title: '站姿与坐姿人物速写',
      subject: '速写',
      date: '2026-09-18',
      images: ['papers/speed.jpg'],
      teachers: ['t-1'],
      reviews: [
        _SeedReview('t-1', 72, '人物比例基本正确，但动态偏僵硬，两个人物在画面中的位置需要推敲。', [4, 3]),
      ],
    ),
    _SeedWork(
      person: 25,
      title: '立方体组合素描',
      subject: '素描',
      date: '2026-09-10',
      images: ['art/sketch-geometry-1.jpg'],
      teachers: ['t-1'],
      reviews: [
        _SeedReview('t-1', 90, '形体结构准确，明暗层次丰富，投影的虚实处理到位。', [6]),
      ],
    ),
    _SeedWork(
      person: 30,
      title: '石膏头像写生',
      subject: '素描',
      date: '2026-08-28',
      images: ['art/sketch-bust-1.jpg'],
      teachers: ['t-1'],
      reviews: [
        _SeedReview('t-1', 80, '头部转面的透视不统一，下颌与颈部的穿插关系需要交代。', [7]),
      ],
    ),
    // 其他老师的作品：赵雪（速写，演示班主任账号）、张明远。
    _SeedWork(
      person: 7,
      title: '组合人物速写',
      subject: '速写',
      date: '2026-11-01',
      images: ['art/speed-group-1.jpg'],
      description: '三个人物的前后关系不太会处理。',
      teachers: ['t-4'],
    ),
    _SeedWork(
      person: 10,
      title: '车站场景速写',
      subject: '速写',
      date: '2026-10-19',
      images: ['art/speed-scene-1.jpg'],
      teachers: ['t-4'],
      reviews: [
        _SeedReview('t-4', 83, '场景透视基本准确，人物与环境的比例关系清楚。', [7]),
      ],
    ),
    _SeedWork(
      person: 3,
      title: '构图小稿练习',
      subject: '素描',
      date: '2026-10-29',
      images: ['papers/sketch.jpg'],
      description: '刚加入画室，第一次提交作品。',
      teachers: ['t-2'],
    ),
  ];

  static List<Map<String, dynamic>> seedWorks() => <Map<String, dynamic>>[
    for (var i = 0; i < _seeds.length; i++)
      _buildWork(_seeds[i], 'aw-${1001 + i}', i),
  ];

  /// 学生提交作品的时间：当天晚自习（18:30–21:30）里分散开。
  static const _submitTimes = <String>[
    '18:42', '19:05', '20:16', '19:38', '21:07', '18:55', '20:48', '19:21',
    '20:33', '21:18', '19:52', '18:36', '20:04', '21:25', '19:14',
  ];

  /// 老师点评的时间：次日晚自习时段，与提交时间错开。
  static const _reviewTimes = <String>[
    '19:26', '20:12', '20:51', '19:48', '21:09', '18:58', '20:37',
  ];

  static Map<String, dynamic> _buildWork(_SeedWork seed, String id, int index) {
    final submitted = _submitTimes[index % _submitTimes.length];
    final work = <String, dynamic>{
      'id': id,
      'personIndex': seed.person,
      'title': seed.title,
      'subject': seed.subject,
      'drawingDate': seed.date,
      'createTime': '${seed.date} $submitted:00',
      'description': seed.description,
      'images': <Map<String, dynamic>>[
        for (var k = 0; k < seed.images.length; k++)
          <String, dynamic>{
            'id': '$id-${k + 1}',
            'ref': 'asset:assets/demo/${seed.images[k]}',
          },
      ],
      'teacherIds': <String>[...seed.teachers],
      'reviews': <Map<String, dynamic>>[
        for (var k = 0; k < seed.reviews.length; k++)
          _buildReview(seed.reviews[k], seed.date, index * 3 + k),
      ],
    };
    final lead = _seedLeadReview(work, seed.date, index);
    if (lead != null) {
      work['leadReview'] = lead;
    }
    return work;
  }

  /// 有体验账号的组长（素描组张明远）留下这一天及之后的作品待复核。
  static const _leadCutoff = '2026-10-21';

  static const _leadComments = <String>[
    '点评具体，问题指得清楚，学生照着改就行。',
    '同意老师的意见。下次点评可以再补一句怎么练。',
    '分数合适，评语清楚。',
    '',
  ];

  /// 种子数据里的组长复核：点评完成的作品才有。
  static Map<String, dynamic>? _seedLeadReview(
    Map<String, dynamic> work,
    String date,
    int index,
  ) {
    final leadId = leadIdOf(work);
    final summary = aggregate(work);
    if (leadId == null || summary.status != statusReviewed) {
      return null;
    }
    if (leadHasAccount(leadId) && date.compareTo(_leadCutoff) >= 0) {
      return null;
    }
    final score = summary.finalScore;
    final day = DateTime.parse(date).add(const Duration(days: 2));
    final minute = (20 + index % 30).toString().padLeft(2, '0');
    return <String, dynamic>{
      ...autoLeadReview(leadId, '${_ymd(day)} 08:$minute:00'),
      'content': _leadComments[index % _leadComments.length],
      'exemplar': score != null && score >= 90,
    };
  }

  static Map<String, dynamic> _buildReview(
    _SeedReview review,
    String date,
    int slot,
  ) {
    final defs = _tagDefs(review.teacherId);
    final day = DateTime.parse(date).add(const Duration(days: 1));
    final reviewedTime = review.time.isNotEmpty
        ? review.time
        : '${_ymd(day)} ${_reviewTimes[slot % _reviewTimes.length]}:00';
    return <String, dynamic>{
      'teacherId': review.teacherId,
      'score': review.score,
      'maxScore': 100.0,
      'content': review.content,
      'reviewedTime': reviewedTime,
      'tags': <Map<String, dynamic>>[
        for (final index in review.tags)
          if (index >= 1 && index <= defs.length)
            <String, dynamic>{
              'id': tagId(review.teacherId, index),
              'name': defs[index - 1].$1,
              'explanation': defs[index - 1].$2,
              'color': defs[index - 1].$3,
            },
      ],
    };
  }

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── 批注 ─────────────────────────────────────────────────────────────

  /// `{artworkId: {teacherId: [stroke]}}`；坐标按图片宽高归一化到 0–1。
  static Map<String, dynamic> seedAnnotations() {
    final works = seedWorks();
    String idOf(String title) => works
        .firstWhere((w) => w['personIndex'] == 1 && w['title'] == title)['id']
        .toString();
    // 与批注笔一致：红取色板危险色，蓝取素描科目色。
    const red = '#E5323B';
    const blue = '#4A74D6';
    return <String, dynamic>{
      idOf('几何体明暗关系'): <String, dynamic>{
        't-1': <Map<String, dynamic>>[
          _stroke(
            _curve([0.30, 0.52], [0.47, 0.60], [0.40, 0.72]),
            color: blue,
            width: 3,
          ),
          _stroke(_ellipse(0.46, 0.735, 0.16, 0.045), color: red),
          _stroke([
            [0.13, 0.33],
            [0.16, 0.36],
            [0.22, 0.30],
          ], color: red),
        ],
      },
      idOf('石膏头像结构练习'): <String, dynamic>{
        't-1': <Map<String, dynamic>>[
          _stroke(
            [
              [0.36, 0.327],
              [0.70, 0.327],
            ],
            color: blue,
            width: 2,
          ),
          _stroke(
            [
              [0.36, 0.449],
              [0.70, 0.449],
            ],
            color: blue,
            width: 2,
          ),
          _stroke(
            [
              [0.36, 0.557],
              [0.70, 0.557],
            ],
            color: blue,
            width: 2,
          ),
          _stroke(_ellipse(0.462, 0.356, 0.075, 0.032), color: red),
          _stroke(_ellipse(0.312, 0.43, 0.035, 0.055), color: red),
        ],
      },
      idOf('人物动态速写'): <String, dynamic>{
        't-4': <Map<String, dynamic>>[
          _stroke([
            [0.48, 0.07],
            [0.49, 0.17],
            [0.47, 0.32],
            [0.47, 0.46],
            [0.44, 0.58],
            [0.42, 0.68],
            [0.42, 0.80],
            [0.43, 0.90],
          ], color: blue),
          _stroke(_ellipse(0.33, 0.41, 0.06, 0.045), color: red),
        ],
      },
      idOf('静物结构素描'): <String, dynamic>{
        't-1': <Map<String, dynamic>>[
          _stroke(_ellipse(0.555, 0.518, 0.16, 0.06), color: red),
          _stroke(
            [
              [0.293, 0.04],
              [0.293, 0.80],
            ],
            color: blue,
            width: 2,
          ),
          _stroke([
            [0.94, 0.30],
            [0.86, 0.60],
          ], color: red),
          _stroke([
            [0.84, 0.53],
            [0.86, 0.60],
            [0.905, 0.555],
          ], color: red),
        ],
      },
    };
  }

  static Map<String, dynamic> _stroke(
    List<List<double>> points, {
    required String color,
    double width = 4,
    int imageIndex = 0,
  }) {
    double r4(double v) => (v * 10000).round() / 10000;
    return <String, dynamic>{
      'color': color,
      'width': width,
      'imageIndex': imageIndex,
      'points': <List<double>>[
        for (final p in points) <double>[r4(p[0]), r4(p[1])],
      ],
    };
  }

  static List<List<double>> _ellipse(
    double cx,
    double cy,
    double rx,
    double ry,
  ) {
    const segments = 48;
    return <List<double>>[
      for (var i = 0; i <= segments; i++)
        <double>[
          cx + rx * math.cos(2 * math.pi * i / segments),
          cy + ry * math.sin(2 * math.pi * i / segments),
        ],
    ];
  }

  /// 二次贝塞尔曲线：起点 [a]、控制点 [c]、终点 [b]。
  static List<List<double>> _curve(
    List<double> a,
    List<double> c,
    List<double> b,
  ) {
    const segments = 24;
    final points = <List<double>>[];
    for (var i = 0; i <= segments; i++) {
      final t = i / segments;
      final u = 1 - t;
      points.add(<double>[
        u * u * a[0] + 2 * u * t * c[0] + t * t * b[0],
        u * u * a[1] + 2 * u * t * c[1] + t * t * b[1],
      ]);
    }
    return points;
  }
}
