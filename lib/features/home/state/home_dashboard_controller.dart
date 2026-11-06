import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../../../core/network/media_url.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/storage/app_storage.dart';
import '../../../core/widgets/dashboard_course_notice_card.dart';
import '../data/home_repository.dart';
import 'home_dashboard_state.dart';

final homeDashboardControllerProvider =
    StateNotifierProvider.autoDispose<HomeDashboardController, HomeDashboardState>((ref) {
      final repository = ref.watch(homeRepositoryProvider);
      final storage = ref.watch(appStorageProvider);
      return HomeDashboardController(
        repository: repository,
        storage: storage,
      );
    });

class HomeDashboardController extends StateNotifier<HomeDashboardState> {
  HomeDashboardController({
    required HomeRepository repository,
    required AppStorage storage,
  }) : _repository = repository,
       _storage = storage,
       super(
         HomeDashboardState(
           quickActions: buildQuickActions(storage.showMemberContent),
         ),
       ) {
    unawaited(refresh());
  }

  final HomeRepository _repository;
  final AppStorage _storage;
  bool _refreshInFlight = false;

  Future<void> refresh() async {
    if (_refreshInFlight) {
      return;
    }
    _refreshInFlight = true;
    try {
      if (!mounted) return;
      state = state.copyWith(
        loading: true,
        quickActions: buildQuickActions(_storage.showMemberContent),
        errorMessage: '',
      );

      final responses = await Future.wait<ApiResponse>([
        _safeRequest(_repository.getMyInfo),
        _safeRequest(_repository.getBannerList),
        _safeRequest(_repository.getLatestInfo),
        _safeRequest(_repository.getNextSchoolCourse),
      ]);
      if (!mounted) return;

      final myInfoResponse = responses[0];
      final bannerResponse = responses[1];
      final latestResponse = responses[2];
      final nextCourseResponse = responses[3];

      final weekItems = await _buildWeekItems(myInfoResponse.data);
      if (!mounted) return;

      final banners = _parseBanners(bannerResponse.data);
      final newsItems = _parseNews(latestResponse.data);
      final notices = _parseCourseNotices(nextCourseResponse.data);

      final hasAnyData =
          banners.isNotEmpty ||
          newsItems.isNotEmpty ||
          weekItems.isNotEmpty ||
          notices.isNotEmpty;

      state = state.copyWith(
        loading: false,
        bannerItems: banners,
        newsItems: newsItems,
        weekItems: weekItems,
        courseNotices: notices,
        errorMessage: hasAnyData
            ? ''
            : _firstApiError([
                myInfoResponse,
                bannerResponse,
                latestResponse,
                nextCourseResponse,
              ]),
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        loading: false,
        weekItems: state.weekItems.isEmpty
            ? _emptyWeekItems()
            : state.weekItems,
        errorMessage: '',
      );
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<ApiResponse> _safeRequest(Future<ApiResponse> Function() request) {
    return request()
        .timeout(const Duration(seconds: 8))
        .catchError((_) => const ApiResponse(code: -1, msg: '', data: null));
  }

  List<HomeBannerItem> _parseBanners(dynamic data) {
    if (data is! List) {
      return const [];
    }

    final result = <HomeBannerItem>[];
    for (final item in data) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final image = item['img']?.toString() ?? '';
      if (image.isEmpty) {
        continue;
      }
      result.add(HomeBannerItem(imageUrl: image));
    }
    return result;
  }

  List<HomeNewsItem> _parseNews(dynamic data) {
    // 兼容两种接口结构：
    //   直接数组：data = [{...}, ...]
    //   嵌套对象：data = {list: [...]} 或 {records: [...]} 或 {data: [...]}
    List<dynamic> list;
    if (data is List) {
      list = data;
    } else if (data is Map<String, dynamic>) {
      final inner =
          data['list'] ?? data['records'] ?? data['data'] ?? data['rows'];
      if (inner is List) {
        list = inner;
      } else {
        return const [];
      }
    } else {
      return const [];
    }

    final result = <HomeNewsItem>[];
    for (final item in list) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final rawTags = item['shortText2']?.toString() ?? '';
      final normalized = rawTags
          .replaceAll('\uFF0C', ',')
          .replaceAll('\u3001', ',')
          .replaceAll('\uFF1B', ',')
          .replaceAll(';', ',');
      final tags = normalized
          .split(RegExp(r'[\s,]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final created = DateTime.tryParse(item['createTime']?.toString() ?? '');

      result.add(
        HomeNewsItem(
          id: _toInt(item['id']),
          title: item['title']?.toString() ?? '',
          shortTitle:
              item['shortText1']?.toString() ?? '\u6700\u65b0\u8d44\u8baf',
          tags: tags,
          viewCount: _toInt(item['viewCount']),
          createTime: created,
        ),
      );
    }
    return result;
  }

  List<HomeCourseNotice> _parseCourseNotices(dynamic data) {
    final items = <Map<String, dynamic>>[];
    if (data is Map<String, dynamic>) {
      items.add(data);
    } else if (data is List) {
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          items.add(item);
        }
      }
    }
    if (items.isEmpty) {
      return const [];
    }

    final result = <HomeCourseNotice>[];
    for (final item in items) {
      final subject = _extractMap(item['subject']);
      final teacher = _extractMap(item['teacher']);
      final schoolClass = _extractMap(item['schoolClass']);
      final beginTime = _toTimeText(item['timeBegin']?.toString() ?? '');
      final endTime = _toTimeText(item['timeEnd']?.toString() ?? '');
      final subjectName = subject['name']?.toString() ?? '';
      final teacherName =
          teacher['realname']?.toString().trim().isNotEmpty == true
          ? teacher['realname'].toString().trim()
          : teacher['nickname']?.toString().trim() ?? '';
      final className = schoolClass['name']?.toString().trim() ?? '';

      if (subjectName.isEmpty || teacherName.isEmpty) {
        continue;
      }

      // 从 timeBegin/timeEnd 计算真实课时时长
      final durationMinutes = _calcDurationMinutes(
        item['timeBegin']?.toString() ?? '',
        item['timeEnd']?.toString() ?? '',
      );
      final classLabel = className.isNotEmpty ? className : '课程';
      final durationText = durationMinutes > 0
          ? '$durationMinutes分钟·$classLabel'
          : '45分钟·$classLabel';

      // 接口 color 字段作为卡片彩色标记（如 "#fed7aa"）
      final colorHex = item['color']?.toString();
      final typeRaw = item['type'] ?? item['courseType'] ?? item['classType'];
      final type = typeRaw is int
          ? typeRaw
          : (int.tryParse(typeRaw?.toString() ?? '') ?? 0);
      final isSmallCourse = type == 1;
      final avatarRaw = teacher['headUrl']?.toString().trim() ?? '';
      final logoRaw = item['logo']?.toString().trim().isNotEmpty == true
          ? item['logo'].toString().trim()
          : schoolClass['logo']?.toString().trim() ?? '';

      result.add(
        HomeCourseNotice(
          startTime: beginTime,
          endTime: endTime,
          subjectName: subjectName,
          teacherName: teacherName,
          teacherAvatar: MediaUrl.resolve(
            avatarRaw.isNotEmpty ? avatarRaw : logoRaw,
          ),
          description: durationText,
          status: _resolveCourseStatus(item),
          isSmallCourse: isSmallCourse,
          cardColorHex:
              (colorHex != null &&
                  colorHex.isNotEmpty &&
                  colorHex != '#ffffff' &&
                  colorHex != '#FFFFFF')
              ? colorHex
              : null,
        ),
      );
    }

    return result;
  }

  HomeCourseStatus _resolveCourseStatus(Map<String, dynamic> item) {
    final date = item['date']?.toString() ?? '';
    final beginTime = _toTimeText(item['timeBegin']?.toString() ?? '');
    final endTime = _toTimeText(item['timeEnd']?.toString() ?? '');
    return switch (resolveDashboardCourseRunStateFromIsoDate(
      DateTime.now(),
      date,
      beginTime,
      endTime,
    )) {
      DashboardCourseRunState.ended => HomeCourseStatus.ended,
      DashboardCourseRunState.inProgress => HomeCourseStatus.inProgress,
      DashboardCourseRunState.upcoming => HomeCourseStatus.upcoming,
    };
  }

  String _toTimeText(String value) {
    if (value.length >= 5) {
      return value.substring(0, 5);
    }
    return value;
  }

  Future<List<HomeWeekDayItem>> _buildWeekItems(dynamic myInfoData) async {
    final userMap = _extractUser(myInfoData);
    final role = userMap['role']?.toString() ?? '';
    if (role != 'teacher' && role != 'student') {
      return _emptyWeekItems();
    }

    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final beginDate = _formatDate(monday);
    final endDate = _formatDate(sunday);

    final courseResponse = await _safeRequest(() {
      if (role == 'teacher') {
        return _repository.getTeacherCourseList(
          beginDate: beginDate,
          endDate: endDate,
        );
      }
      return _repository.getStudentCourseList(
        beginDate: beginDate,
        endDate: endDate,
      );
    });

    if (courseResponse.code != 0 || courseResponse.data == null) {
      return _emptyWeekItems();
    }

    final countsByDate = _courseCountsByDate(courseResponse.data);
    const weeks = [
      '\u5468\u4e00',
      '\u5468\u4e8c',
      '\u5468\u4e09',
      '\u5468\u56db',
      '\u5468\u4e94',
      '\u5468\u516d',
      '\u5468\u65e5',
    ];
    final items = <HomeWeekDayItem>[];
    for (var i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      final dateText = _formatDate(date);
      final count = countsByDate[dateText] ?? 0;

      items.add(
        HomeWeekDayItem(
          weekText: weeks[i],
          dayText: '${date.day}',
          dateText: dateText,
          courseCount: count,
          isToday:
              date.year == now.year &&
              date.month == now.month &&
              date.day == now.day,
        ),
      );
    }
    return items;
  }

  Map<String, int> _courseCountsByDate(dynamic data) {
    final counts = <String, int>{};
    if (data is Map) {
      for (final entry in data.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        counts[key] = value is List ? value.length : 0;
      }
      return counts;
    }

    if (data is List) {
      for (final item in data) {
        if (item is! Map) {
          continue;
        }
        final date = item['date']?.toString() ?? '';
        if (date.isEmpty) {
          continue;
        }
        counts[date] = (counts[date] ?? 0) + 1;
      }
    }
    return counts;
  }

  List<HomeWeekDayItem> _emptyWeekItems() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    const weeks = [
      '\u5468\u4e00',
      '\u5468\u4e8c',
      '\u5468\u4e09',
      '\u5468\u56db',
      '\u5468\u4e94',
      '\u5468\u516d',
      '\u5468\u65e5',
    ];

    return List.generate(7, (index) {
      final date = monday.add(Duration(days: index));
      return HomeWeekDayItem(
        weekText: weeks[index],
        dayText: '${date.day}',
        dateText: _formatDate(date),
        courseCount: 0,
        isToday:
            date.year == now.year &&
            date.month == now.month &&
            date.day == now.day,
      );
    });
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Map<String, dynamic> _extractUser(dynamic data) {
    if (data is Map<String, dynamic> && data['user'] is Map<String, dynamic>) {
      return data['user'] as Map<String, dynamic>;
    }
    return const {};
  }

  Map<String, dynamic> _extractMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    return const {};
  }

  String _firstApiError(List<ApiResponse> responses) {
    for (final response in responses) {
      if (!response.isSuccess && response.displayMsg.isNotEmpty) {
        return response.displayMsg;
      }
    }
    return '';
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  /// 从 "HH:MM:SS" 或 "HH:MM" 格式计算两个时间点之间的分钟数
  int _calcDurationMinutes(String begin, String end) {
    try {
      final bParts = begin.split(':').map(int.parse).toList();
      final eParts = end.split(':').map(int.parse).toList();
      final bMin = bParts[0] * 60 + bParts[1];
      final eMin = eParts[0] * 60 + eParts[1];
      return (eMin - bMin).clamp(0, 480);
    } catch (_) {
      return 0;
    }
  }
}
