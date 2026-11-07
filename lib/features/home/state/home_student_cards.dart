import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData, Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_paths.dart';
import '../../../core/art/art_subject.dart';
import '../../../core/art/art_tokens.dart';
import '../../art_toolbox/data/toolbox_catalog.dart';
import '../../artworks/data/artwork_models.dart';
import '../../artworks/data/artwork_repository.dart';
import '../ui/widgets/home_study_snapshot.dart';

/// 今日练习的来源：老师点评里的高频问题、最近一次考试的弱项科目、没有数据时的基本功。
enum HomePracticeSource { problem, weakSubject, basics }

/// 首页「今日练习」的一条建议：点开直达画室工具箱的某个工具或范画库的某个科目。
@immutable
class HomePractice {
  const HomePractice({
    required this.source,
    required this.title,
    required this.reason,
    required this.icon,
    required this.route,
    this.arguments = const <String, dynamic>{},
    this.tag = '',
    this.subject = '',
  });

  final HomePracticeSource source;
  final String title;
  final String reason;
  final IconData icon;

  /// 标题旁的标签：问题名（如「结构错误」）或科目名。
  final String tag;

  /// 所属科目，决定图标颜色；为空时用品牌色。
  final String subject;
  final String route;
  final Map<String, dynamic> arguments;
}

/// 生成 1–3 条今日练习：先取高频问题（最多 2 条，问题对应的工具直达，没有工具时
/// 打开对应科目的范画），再补最近一次月考得分最低的科目；都没有数据时给两项基本功。
List<HomePractice> buildHomePractices({
  ArtworkInsights? insights,
  HomeStudySnapshot? snapshot,
  int limit = 3,
}) {
  final result = <HomePractice>[];
  final usedTools = <String>{};
  for (final suggestion in insights?.suggestions ?? const <ArtworkSuggestion>[]) {
    if (result.length >= 2 || result.length >= limit) {
      break;
    }
    final reason = suggestion.count > 1
        ? '老师点评中出现 ${suggestion.count} 次。${suggestion.text}'
        : suggestion.text;
    final tool = ArtTool.tryParse(suggestion.tool);
    if (tool != null) {
      if (!usedTools.add(tool.key)) {
        continue;
      }
      result.add(
        HomePractice(
          source: HomePracticeSource.problem,
          title: tool.label,
          reason: reason,
          icon: tool.icon,
          tag: suggestion.tag,
          subject: suggestion.gallerySubject.isNotEmpty
              ? suggestion.gallerySubject
              : (tool.subject?.label ?? ''),
          route: RoutePaths.artToolbox,
          arguments: <String, dynamic>{'tool': tool.key},
        ),
      );
      continue;
    }
    final subject = suggestion.gallerySubject;
    result.add(
      HomePractice(
        source: HomePracticeSource.problem,
        title: '$subject范画对照',
        reason: reason,
        icon: Icons.photo_library_outlined,
        tag: suggestion.tag,
        subject: subject,
        route: RoutePaths.gallery,
        arguments: <String, dynamic>{
          if (subject.isNotEmpty) 'subject': subject,
          if (suggestion.galleryKeyword.isNotEmpty)
            'keyword': suggestion.galleryKeyword,
        },
      ),
    );
  }

  final weak = _weakSubject(insights, snapshot);
  final weakCovered =
      weak != null &&
      result.any(
        (p) => p.route == RoutePaths.gallery && p.subject == weak.subject,
      );
  if (weak != null && !weakCovered && result.length < limit) {
    result.add(
      HomePractice(
        source: HomePracticeSource.weakSubject,
        title: '${weak.subject}范画对照',
        reason: weak.reason,
        icon: Icons.photo_library_outlined,
        tag: weak.subject,
        subject: weak.subject,
        route: RoutePaths.gallery,
        arguments: <String, dynamic>{'subject': weak.subject},
      ),
    );
  }

  if (result.isEmpty) {
    for (final tool in const [ArtTool.valueOrder, ArtTool.figure]) {
      result.add(
        HomePractice(
          source: HomePracticeSource.basics,
          title: tool.label,
          reason: '还没有点评与成绩记录，先从基本功练起：${tool.description}。',
          icon: tool.icon,
          tag: '基本功',
          subject: tool.subject?.label ?? '',
          route: RoutePaths.artToolbox,
          arguments: <String, dynamic>{'tool': tool.key},
        ),
      );
    }
  }
  return result.take(limit).toList();
}

/// 弱项科目：优先最近一次已出分考试里分数最低的一科，没有考试时取日常作品的「有待加强」。
({String subject, String reason})? _weakSubject(
  ArtworkInsights? insights,
  HomeStudySnapshot? snapshot,
) {
  if (snapshot != null && !snapshot.staff) {
    ({String name, double? score, String grade})? weakest;
    for (final subject in snapshot.subjects) {
      final score = subject.score;
      if (ArtSubject.tryParse(subject.name) == null || score == null) {
        continue;
      }
      if (weakest == null || score < weakest.score!) {
        weakest = subject;
      }
    }
    if (weakest != null) {
      final grade = weakest.grade.isEmpty ? '' : '（${weakest.grade} 档）';
      return (
        subject: weakest.name,
        reason:
            '${snapshot.examName}${weakest.name} ${formatScore(weakest.score)} 分$grade，'
            '是三科中分数最低的一科，挑一张同类范画对照着练。',
      );
    }
  }
  final subject = insights?.weakestSubject ?? '';
  if (ArtSubject.tryParse(subject) != null) {
    return (
      subject: subject,
      reason: '日常作品里$subject的点评得分偏低，挑一张同类范画对照着练。',
    );
  }
  return null;
}

/// 点评意见的第一句，首页卡片只放一句。
String homeCommentLine(String text) {
  final clause = text.split(RegExp('[。；;！？]')).first.trim();
  return clause.isEmpty ? text.trim() : clause;
}

/// 首页「最近点评」：最近一份全部老师点评完成的作品。
@immutable
class HomeLatestReview {
  const HomeLatestReview({
    required this.artworkId,
    required this.title,
    this.subject = '',
    this.coverUrl = '',
    this.drawingDate = '',
    this.score,
    this.maxScore = 100,
    this.teacherName = '',
    this.comment = '',
    this.reviewedTime = '',
  });

  /// 评语取最近一位写了评语的老师；都只打了分时取最近一位点评的老师。
  factory HomeLatestReview.from(ArtworkSummary work, ArtworkDetail? detail) {
    ArtworkReview? pick;
    for (final review in detail?.reviews ?? const <ArtworkReview>[]) {
      if (!review.visible) {
        continue;
      }
      final better =
          pick == null ||
          (review.content.isNotEmpty && pick.content.isEmpty) ||
          (review.content.isNotEmpty == pick.content.isNotEmpty &&
              review.reviewedTime.compareTo(pick.reviewedTime) > 0);
      if (better) {
        pick = review;
      }
    }
    return HomeLatestReview(
      artworkId: work.id,
      title: work.title,
      subject: work.subject,
      coverUrl: work.coverUrl,
      drawingDate: work.drawingDate,
      score: work.finalScore,
      maxScore: work.maxScore,
      teacherName: pick?.teacherName ?? '',
      comment: homeCommentLine(pick?.content ?? ''),
      reviewedTime: pick?.reviewedTime ?? '',
    );
  }

  final String artworkId;
  final String title;
  final String subject;
  final String coverUrl;
  final String drawingDate;
  final double? score;
  final double maxScore;
  final String teacherName;
  final String comment;
  final String reviewedTime;
}

/// 今日练习：高频问题来自作品点评小结（`GET /app/artworks/insights`），弱项科目来自学情速览。
/// 任一接口失败都不报错，按已有数据给建议。
final homePracticeProvider = FutureProvider.autoDispose<List<HomePractice>>((
  ref,
) async {
  final repository = ref.watch(artworkRepositoryProvider);
  ArtworkInsights? insights;
  try {
    final response = await repository.getInsights();
    if (response.isSuccess) {
      insights = ArtworkInsights.fromJson(response.data);
    }
  } catch (_) {
    insights = null;
  }
  HomeStudySnapshot? snapshot;
  try {
    snapshot = await ref.watch(homeStudySnapshotProvider.future);
  } catch (_) {
    snapshot = null;
  }
  return buildHomePractices(insights: insights, snapshot: snapshot);
});

/// 最近点评：已点评作品按绘画日期倒序取第一份，再取详情拿到老师评语。
final homeLatestReviewProvider =
    FutureProvider.autoDispose<HomeLatestReview?>((ref) async {
      final repository = ref.watch(artworkRepositoryProvider);
      final response = await repository.getArtworks(
        status: ArtworkStatusFilter.reviewed,
        page: 1,
        size: 1,
      );
      if (!response.isSuccess) {
        throw StateError(response.errorOr('最近点评加载失败'));
      }
      final records = ArtworkPage.fromJson(response.data).records;
      if (records.isEmpty) {
        return null;
      }
      final work = records.first;
      final detail = await repository.getArtwork(work.id);
      return HomeLatestReview.from(
        work,
        detail.isSuccess ? ArtworkDetail.fromJson(detail.data) : null,
      );
    });
