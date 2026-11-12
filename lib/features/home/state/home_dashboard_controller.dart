import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../../../core/network/media_url.dart';
import '../../../core/widgets/dashboard_course_notice_card.dart';
import '../../shell/state/shell_controller.dart';
import '../../shell/state/shell_state.dart';
import '../data/home_repository.dart';
import 'home_dashboard_state.dart';

final homeDashboardControllerProvider =
    StateNotifierProvider.autoDispose<
      HomeDashboardController,
      HomeDashboardState
    >((ref) {
      final repository = ref.watch(homeRepositoryProvider);
      final role = ref.read(shellControllerProvider).user.role;
      return HomeDashboardController(repository: repository, initialRole: role);
    });

const _weekdayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/// 周条与课程列表对齐：课程列表那天的节数取列表长度，两处显示同一个数。
List<HomeWeekDayItem> alignWeekWithCourses(
  List<HomeWeekDayItem> week,
  List<HomeCourseNotice> courses,
) {
  if (week.isEmpty || courses.isEmpty) {
    return week;
  }
  final date = courses.first.date;
  if (date.isEmpty || courses.any((course) => course.date != date)) {
    return week;
  }
  return [
    for (final day in week)
      day.dateText == date ? day.copyWith(courseCount: courses.length) : day,
  ];
}

/// 有个人课表的角色：学生、任课老师、班主任。
bool homeRoleHasTimetable(String role) => switch (homeRoleKind(role)) {
  'student' || 'teacher' || 'headTeacher' => true,
  _ => false,
};

class HomeDashboardController extends StateNotifier<HomeDashboardState> {
  HomeDashboardController({
    required HomeRepository repository,
    String initialRole = '',
  }) : _repository = repository,
       super(
         HomeDashboardState(
           role: initialRole,
           quickActions: buildQuickActions(
             isStaff: isStaffRole(initialRole),
             role: initialRole,
           ),
         ),
       ) {
    unawaited(refresh());
  }

  final HomeRepository _repository;
  bool _refreshInFlight = false;

  Future<void> refresh() async {
    if (_refreshInFlight) {
      return;
    }
    _refreshInFlight = true;
    try {
      if (!mounted) return;
      state = state.copyWith(loading: true, errorMessage: '');

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

      final role = _extractUser(myInfoResponse.data)['role']?.toString() ?? '';
      final now = DateTime.now();
      final weekItems = await _buildWeekItems(role, now);
      if (!mounted) return;

      final banners = _parseBanners(bannerResponse.data);
      final newsItems = _parseNews(latestResponse.data);
      // 宿管首页显示值班与查寝，不显示班级课程。
      final notices = role == 'dormManager'
          ? const <HomeCourseNotice>[]
          : _parseCourseNotices(nextCourseResponse.data, now);

      final next = HomeDashboardState(
        loading: false,
        role: role,
        bannerItems: banners,
        quickActions: buildQuickActions(isStaff: isStaffRole(role), role: role),
        newsItems: newsItems,
        weekItems: alignWeekWithCourses(weekItems, notices),
        courseNotices: notices,
      );
      final failed = responses.any((response) => !response.isSuccess);
      state = next.copyWith(
        errorMessage: next.hasContent || !failed
            ? ''
            : _firstApiError(responses),
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        loading: false,
        errorMessage: state.hasContent ? '' : '网络异常，请稍后重试',
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
      result.add(
        HomeBannerItem(
          imageUrl: image,
          title: item['title']?.toString().trim() ?? '',
        ),
      );
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

      final created = DateTime.tryParse(
        (item['createTime']?.toString() ?? '').replaceFirst(' ', 'T'),
      );

      result.add(
        HomeNewsItem(
          id: _toInt(item['id']),
          title: item['title']?.toString() ?? '',
          shortTitle: item['shortText1']?.toString() ?? '最新资讯',
          tags: tags,
          viewCount: _toInt(item['viewCount']),
          createTime: created,
        ),
      );
    }
    return result;
  }

  List<HomeCourseNotice> _parseCourseNotices(dynamic data, DateTime now) {
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

    final result = <HomeCourseNotice>[];
    for (final item in items) {
      final subject = _extractMap(item['subject']);
      final teacher = _extractMap(item['teacher']);
      final schoolClass = _extractMap(item['schoolClass']);
      final rawBegin = item['timeBegin']?.toString() ?? '';
      final rawEnd = item['timeEnd']?.toString() ?? '';
      final beginTime = _toTimeText(rawBegin);
      final endTime = _toTimeText(rawEnd);
      final subjectName = subject['name']?.toString().trim() ?? '';
      final realname = teacher['realname']?.toString().trim() ?? '';
      final teacherName = realname.isNotEmpty
          ? realname
          : teacher['nickname']?.toString().trim() ?? '';
      if (subjectName.isEmpty || teacherName.isEmpty) {
        continue;
      }

      final durationMinutes = _calcDurationMinutes(rawBegin, rawEnd);
      final className = schoolClass['name']?.toString().trim() ?? '';
      final room = item['room']?.toString().trim() ?? '';
      final description = [
        if (durationMinutes > 0) '$durationMinutes 分钟',
        if (className.isNotEmpty) className,
        if (room.isNotEmpty) room,
      ].join(' · ');

      // 接口 color 字段作为课程色（如 "#fed7aa"），白色视为未设置。
      final colorHex = item['color']?.toString() ?? '';
      final typeRaw = item['type'] ?? item['courseType'] ?? item['classType'];
      final type = typeRaw is int
          ? typeRaw
          : (int.tryParse(typeRaw?.toString() ?? '') ?? 0);
      final date = item['date']?.toString() ?? '';

      result.add(
        HomeCourseNotice(
          startTime: beginTime,
          endTime: endTime,
          subjectName: subjectName,
          teacherName: teacherName,
          // 没有教师头像时留空，由课程卡显示姓氏头像，不用班级 / 学校 logo 顶替。
          teacherAvatar: MediaUrl.resolve(
            teacher['headUrl']?.toString().trim() ?? '',
          ),
          description: description,
          status: _resolveCourseStatus(now, date, beginTime, endTime),
          date: date.length >= 10 ? date.substring(0, 10) : date,
          isSmallCourse: type == 1,
          cardColorHex: colorHex.isEmpty || colorHex.toLowerCase() == '#ffffff'
              ? null
              : colorHex,
        ),
      );
    }
    result.sort((a, b) => a.startTime.compareTo(b.startTime));
    return result;
  }

  HomeCourseStatus _resolveCourseStatus(
    DateTime now,
    String date,
    String beginTime,
    String endTime,
  ) {
    return switch (resolveDashboardCourseRunStateFromIsoDate(
      now,
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

  /// 本周七天的课程数。学生取学生课表，任课老师与班主任取本人授课课表；
  /// 宿管、管理员没有个人课表，返回空列表（首页不显示周条）。
  Future<List<HomeWeekDayItem>> _buildWeekItems(
    String role,
    DateTime now,
  ) async {
    if (!homeRoleHasTimetable(role)) {
      return const [];
    }

    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: now.weekday - 1));
    final beginDate = _formatDate(monday);
    final endDate = _formatDate(monday.add(const Duration(days: 6)));

    final courseResponse = await _safeRequest(() {
      if (role == 'student') {
        return _repository.getStudentCourseList(
          beginDate: beginDate,
          endDate: endDate,
        );
      }
      return _repository.getTeacherCourseList(
        beginDate: beginDate,
        endDate: endDate,
      );
    });

    final countsByDate = courseResponse.code == 0
        ? _courseCountsByDate(courseResponse.data)
        : const <String, int>{};
    return [
      for (var i = 0; i < 7; i++)
        _weekDay(monday.add(Duration(days: i)), today, countsByDate),
    ];
  }

  HomeWeekDayItem _weekDay(
    DateTime date,
    DateTime today,
    Map<String, int> counts,
  ) {
    final dateText = _formatDate(date);
    return HomeWeekDayItem(
      weekText: _weekdayLabels[date.weekday - 1],
      dayText: '${date.day}',
      dateText: dateText,
      courseCount: counts[dateText] ?? 0,
      isToday: date == today,
    );
  }

  Map<String, int> _courseCountsByDate(dynamic data) {
    final counts = <String, int>{};
    if (data is Map) {
      for (final entry in data.entries) {
        final value = entry.value;
        counts[entry.key.toString()] = value is List ? value.length : 0;
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
        final day = date.length >= 10 ? date.substring(0, 10) : date;
        counts[day] = (counts[day] ?? 0) + 1;
      }
    }
    return counts;
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
    return '请检查网络后重试';
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
