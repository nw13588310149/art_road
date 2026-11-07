import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/art/art_subject.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/media_url.dart';
import '../../../core/network/snowflake_id.dart';
import '../../video_tutorial/data/video_tutorial_repository.dart';
import '../data/school_repository.dart';
import 'school_page_state.dart';

final schoolPageControllerProvider =
    StateNotifierProvider.autoDispose<SchoolPageController, SchoolPageState>((
      ref,
    ) {
      final repository = ref.watch(schoolRepositoryProvider);
      final videos = ref.watch(videoTutorialRepositoryProvider);
      return SchoolPageController(repository: repository, videos: videos);
    });

class SchoolPageController extends StateNotifier<SchoolPageState> {
  SchoolPageController({
    required SchoolRepository repository,
    required VideoTutorialRepository videos,
  }) : _repository = repository,
       _videos = videos,
       super(SchoolPageState(quickActions: buildSchoolQuickActions())) {
    unawaited(refresh());
  }

  final SchoolRepository _repository;
  final VideoTutorialRepository _videos;

  Future<void> refresh() async {
    if (!mounted) return;
    state = state.copyWith(loading: true, errorMessage: '');

    final schoolResponse = await _repository.getSchoolInfo();

    // 页面已退出（autoDispose）→ 不再写 state，避免 "after dispose" 异常。
    if (!mounted) return;

    final schoolMap = _asMap(schoolResponse.data);
    final schoolId = readSnowflakeId(schoolMap['id']) ?? '0';
    final schoolName = schoolMap['name']?.toString() ?? '';

    final responses = await Future.wait([
      _repository.getBannerList(schoolId: schoolId),
      _repository.getLearningProgress(),
      _repository.getSchoolHomeLatestInfo(),
      _videos.getSchoolVideoList(current: 1, size: 6),
    ]);

    if (!mounted) return;

    final bannerResponse = responses[0];
    final progressResponse = responses[1];
    final latestResponse = responses[2];
    final videoResponse = responses[3];

    var bannerItems = _parseBanners(bannerResponse.data);
    final learningItems = _parseLearning(progressResponse.data);
    var newsItems = _parseNews(latestResponse.data);
    final courseVideos = _parseVideos(videoResponse.data);

    if (bannerItems.isEmpty && schoolId != '0') {
      final fallbackBanner = await _repository.getBannerList(schoolId: '0');
      if (!mounted) return;
      bannerItems = _parseBanners(fallbackBanner.data);
    }

    if (newsItems.isEmpty) {
      final fallbackNews = await _repository.getHomeLatestInfo();
      if (!mounted) return;
      newsItems = _parseNews(fallbackNews.data);
    }

    final hasAnyData =
        schoolName.isNotEmpty ||
        bannerItems.isNotEmpty ||
        learningItems.isNotEmpty ||
        newsItems.isNotEmpty ||
        courseVideos.isNotEmpty;

    state = state.copyWith(
      loading: false,
      schoolId: schoolId,
      schoolName: schoolName,
      bannerItems: bannerItems,
      learningItems: learningItems,
      newsItems: newsItems,
      courseVideos: courseVideos,
      errorMessage: hasAnyData
          ? ''
          : _firstApiError([
              schoolResponse,
              bannerResponse,
              progressResponse,
              latestResponse,
            ]),
    );
  }

  List<SchoolBannerItem> _parseBanners(dynamic data) {
    if (data is! List) {
      return const [];
    }

    final result = <SchoolBannerItem>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final image = item['img']?.toString() ?? '';
      if (image.isEmpty) {
        continue;
      }
      result.add(SchoolBannerItem(imageUrl: image));
    }
    return result;
  }

  /// 解析 `/app/user/schoolHomeLearningProgress`：`sketch` 素描、`color` 色彩、
  /// `speed` 速写，每项含 completeCount / allCount（课时）/ progress。
  List<SchoolLearningItem> _parseLearning(dynamic data) {
    final map = _asMap(data);
    if (map.isEmpty) {
      return const [];
    }

    return [
      _buildLearningItem(ArtSubject.sketch, _parseProgressEntry(map['sketch'])),
      _buildLearningItem(ArtSubject.color, _parseProgressEntry(map['color'])),
      _buildLearningItem(ArtSubject.speed, _parseProgressEntry(map['speed'])),
    ];
  }

  SchoolLearningItem _buildLearningItem(
    ArtSubject subject,
    ({int completeCount, int allCount, int progress}) entry,
  ) {
    return SchoolLearningItem(
      text: subject.label,
      completeCount: entry.completeCount,
      allCount: entry.allCount,
      progress: entry.progress,
      color: subject.accent,
      background: subject.accentSoft,
    );
  }

  List<SchoolCourseVideo> _parseVideos(dynamic data) {
    final list = _asNewsList(data);
    final result = <SchoolCourseVideo>[];
    for (final item in list) {
      final map = _asMap(item);
      final id = map['id']?.toString() ?? '';
      final title = (map['name'] ?? map['title'])?.toString().trim() ?? '';
      if (id.isEmpty || title.isEmpty) {
        continue;
      }
      result.add(
        SchoolCourseVideo(
          id: id,
          title: title,
          coverUrl: MediaUrl.resolve(map['coverImg']?.toString() ?? ''),
          duration: map['duration']?.toString() ?? '',
          teacherName: map['teacherName']?.toString() ?? '',
          category: map['category']?.toString() ?? '',
        ),
      );
    }
    return result;
  }

  ({int completeCount, int allCount, int progress}) _parseProgressEntry(
    dynamic raw,
  ) {
    final map = _asMap(raw);
    if (map.isNotEmpty) {
      return (
        completeCount: _toInt(map['completeCount']),
        allCount: _toInt(map['allCount']),
        progress: _toInt(map['progress']).clamp(0, 100),
      );
    }

    // 兼容旧版直接返回 0–100 整数的结构。
    if (raw is num) {
      return (
        completeCount: 0,
        allCount: 0,
        progress: raw.toInt().clamp(0, 100),
      );
    }

    return (completeCount: 0, allCount: 0, progress: 0);
  }

  List<SchoolNewsItem> _parseNews(dynamic data) {
    final list = _asNewsList(data);
    if (list.isEmpty) {
      return const [];
    }

    final result = <SchoolNewsItem>[];
    for (final item in list) {
      final map = _asMap(item);
      if (map.isEmpty) {
        continue;
      }

      final normalizedTags = (map['shortText2']?.toString() ?? '').replaceAll(
        RegExp(r'[、；;|，]'),
        ',',
      );

      final tags = normalizedTags
          .split(RegExp(r'[,\s]+'))
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toList();

      result.add(
        SchoolNewsItem(
          id: _toInt(map['id']),
          title: map['title']?.toString() ?? '',
          shortTitle: map['shortText1']?.toString() ?? '最新资讯',
          tags: tags,
          viewCount: _toInt(map['viewCount']),
          createTime: DateTime.tryParse(map['createTime']?.toString() ?? ''),
        ),
      );
    }

    return result;
  }

  List<dynamic> _asNewsList(dynamic data) {
    if (data is List) {
      return data;
    }
    if (data is Map<String, dynamic>) {
      final inner =
          data['list'] ?? data['records'] ?? data['data'] ?? data['rows'];
      if (inner is List) {
        return inner;
      }
    }
    if (data is Map) {
      return _asNewsList(data.map((k, v) => MapEntry(k.toString(), v)));
    }
    return const [];
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    // v2 `schoolList` 接口返回学校数组：取首项作为「当前学校」即可，
    // 与旧版 `mySchool`（单 Map）行为对齐。
    if (value is List && value.isNotEmpty) {
      return _asMap(value.first);
    }
    return const {};
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _firstApiError(List<ApiResponse> responses) {
    for (final response in responses) {
      if (!response.isSuccess && response.displayMsg.isNotEmpty) {
        return response.displayMsg;
      }
    }
    return '';
  }
}
