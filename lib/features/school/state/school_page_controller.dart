import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../../../core/network/snowflake_id.dart';
import '../data/school_repository.dart';
import 'school_page_state.dart';

final schoolPageControllerProvider =
    StateNotifierProvider.autoDispose<SchoolPageController, SchoolPageState>((
      ref,
    ) {
      final repository = ref.watch(schoolRepositoryProvider);
      return SchoolPageController(repository: repository);
    });

class SchoolPageController extends StateNotifier<SchoolPageState> {
  SchoolPageController({required SchoolRepository repository})
    : _repository = repository,
      super(SchoolPageState(quickActions: buildSchoolQuickActions())) {
    unawaited(refresh());
  }

  final SchoolRepository _repository;

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
    ]);

    if (!mounted) return;

    final bannerResponse = responses[0];
    final progressResponse = responses[1];
    final latestResponse = responses[2];

    var bannerItems = _parseBanners(bannerResponse.data);
    final learningItems = _parseLearning(progressResponse.data);
    var newsItems = _parseNews(latestResponse.data);

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
        newsItems.isNotEmpty;

    state = state.copyWith(
      loading: false,
      schoolId: schoolId,
      schoolName: schoolName,
      bannerItems: bannerItems,
      learningItems: learningItems,
      newsItems: newsItems,
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

  /// 解析 `/app/user/schoolHomeLearningProgress` 返回的 `LearningProgressRes`：
  /// `tx` 听写、`sc` 视唱、`yl` 乐理，每项含 completeCount / allCount / progress。
  List<SchoolLearningItem> _parseLearning(dynamic data) {
    final map = _asMap(data);
    if (map.isEmpty) {
      return const [];
    }

    final dictation = _parseProgressEntry(map['tx']);
    final sightSinging = _parseProgressEntry(map['sc']);
    final theory = _parseProgressEntry(map['yl']);

    return [
      _buildLearningItem('听写', dictation, const Color(0xFFB184FF)),
      _buildLearningItem('视唱', sightSinging, const Color(0xFF13E8BE)),
      _buildLearningItem('乐理', theory, const Color(0xFFFF5681)),
    ];
  }

  SchoolLearningItem _buildLearningItem(
    String text,
    ({int completeCount, int allCount, int progress}) entry,
    Color color,
  ) {
    return SchoolLearningItem(
      text: text,
      completeCount: entry.completeCount,
      allCount: entry.allCount,
      progress: entry.progress,
      color: color,
      background: const Color(0xFFF0EBFA),
    );
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
