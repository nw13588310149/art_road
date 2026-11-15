import 'package:flutter/foundation.dart';

import '../../artworks/data/artwork_models.dart';
import '../../school/data/school_config_data.dart';
import '../../smart_campus/data/admin_home_data.dart';
import '../../smart_campus/data/dormitory_check_data.dart';
import '../../smart_campus/data/head_teacher_index_data.dart';
import 'today_practice.dart';

/// 学生最近一次已出分考试的概况，用来给出弱项科目和「值得关注」里的成绩。
@immutable
class TodayStudySnapshot {
  const TodayStudySnapshot({
    required this.examName,
    required this.examDate,
    this.totalScore,
    this.maxScore,
    this.ranking,
    this.participants,
    this.scoreChange,
    this.rankingChange,
    this.subjects = const <({String name, double? score, String grade})>[],
    this.nextExamDays,
  });

  final String examName;
  final String examDate;
  final double? totalScore;
  final double? maxScore;
  final int? ranking;
  final int? participants;
  final double? scoreChange;

  /// 名次变化：正数表示名次上升。
  final int? rankingChange;

  /// 距下一次考试的天数；接口未给出时为空。
  final int? nextExamDays;

  /// 各科分数与档位。
  final List<({String name, double? score, String grade})> subjects;
}

/// 课程进行到哪一步。
enum TodayCoursePhase { ended, inProgress, upcoming }

/// 今天的一节课，来自学生 / 老师 / 管理端的 `courseList`（三者同一套字段）。
@immutable
class TodayCourse {
  const TodayCourse({
    required this.id,
    required this.start,
    required this.end,
    required this.subject,
    this.className = '',
    this.room = '',
    this.teacherName = '',
    this.isSmall = false,
    this.signStatus = 0,
  });

  /// 解析一行课程；缺少科目或开始时间的行返回 null。
  static TodayCourse? tryParse(Object? raw) {
    if (raw is! Map) return null;
    String text(List<String> keys) {
      for (final key in keys) {
        final value = raw[key]?.toString().trim() ?? '';
        if (value.isNotEmpty && value != 'null') return value;
      }
      return '';
    }

    String clock(String value) =>
        value.length >= 5 ? value.substring(0, 5) : '';
    final start = clock(text(const ['timeBegin']));
    final subject = text(const ['subjectName', 'courseName']);
    if (start.isEmpty || subject.isEmpty) return null;
    return TodayCourse(
      id: text(const ['courseId', 'id']),
      start: start,
      end: clock(text(const ['timeEnd'])),
      subject: subject,
      className: text(const ['className']),
      room: text(const ['classroomName', 'room']),
      teacherName: text(const ['teacherRealname', 'teacherName']),
      isSmall: text(const ['type']) == '1',
      signStatus:
          int.tryParse(text(const ['signStatus', 'courseSignStatus'])) ?? 0,
    );
  }

  final String id;

  /// `HH:mm`。
  final String start;
  final String end;
  final String subject;
  final String className;
  final String room;
  final String teacherName;
  final bool isSmall;

  /// 签课流程：0 未签到，1 老师上课签到，2 学生上课签到，3 老师下课签到，
  /// 4 学生下课签到，5 及以上已完成。
  final int signStatus;

  static int? _minutes(String clock) {
    final parts = clock.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    return hour == null || minute == null ? null : hour * 60 + minute;
  }

  bool startedAt(DateTime now) {
    final begin = _minutes(start);
    return begin != null && now.hour * 60 + now.minute >= begin;
  }

  bool endedAt(DateTime now) {
    final finish = _minutes(end);
    return finish != null && now.hour * 60 + now.minute >= finish;
  }

  TodayCoursePhase phaseAt(DateTime now) {
    if (endedAt(now)) return TodayCoursePhase.ended;
    return startedAt(now)
        ? TodayCoursePhase.inProgress
        : TodayCoursePhase.upcoming;
  }

  /// 老师这节课现在要做的签课动作；不需要操作时为空。
  /// 大课：上课后一键签到。小课：上课后签到，下课后签退。
  String teacherSignAction(DateTime now) {
    if (!startedAt(now)) return '';
    if (signStatus == 0) return '上课签到';
    if (isSmall && signStatus == 2 && endedAt(now)) return '下课签退';
    return '';
  }

  /// 学生这节小课现在要做的动作；不需要操作时为空。
  String studentSignAction() {
    if (!isSmall) return '';
    return switch (signStatus) {
      1 => '上课签到',
      3 => '下课签退',
      4 => '课后评价',
      _ => '',
    };
  }
}

/// 解析某一天的课程，按开始时间排序。接口按日期分组返回
/// `{ 'yyyy-MM-dd': [课程...] }`，也兼容直接返回列表。
List<TodayCourse> parseTodayCourses(Object? data, String date) {
  final Object? rows = data is Map ? data[date] : data;
  if (rows is! List) return const <TodayCourse>[];
  final courses = <TodayCourse>[
    for (final row in rows)
      // 直接返回列表时可能带别的日期，只留当天的。
      if (row is Map && (row['date']?.toString() ?? date).startsWith(date))
        ?TodayCourse.tryParse(row),
  ];
  courses.sort((a, b) => a.start.compareTo(b.start));
  return courses;
}

/// 老师名下需要关注的一名学生。
@immutable
class TodayAttentionStudent {
  const TodayAttentionStudent({
    required this.id,
    required this.name,
    this.reason = '',
  });

  final String id;
  final String name;
  final String reason;
}

/// 校长教学概况里与当天工作有关的部分（`GET /school/principal/overview`）。
@immutable
class TodayPrincipalOverview {
  const TodayPrincipalOverview({
    this.overdueReviews = 0,
    this.overdueLeadReviews = 0,
    this.attentionCount = 0,
    this.todaySubmissions,
    this.timelyReviewRate,
    this.studentPresent,
    this.studentExpected,
    this.teacherPresent,
    this.teacherExpected,
    this.alerts = const <TodayPrincipalAlert>[],
  });

  factory TodayPrincipalOverview.fromJson(Object? raw) {
    final json = raw is Map ? raw : const <String, dynamic>{};
    int count(Object? value) => value is num ? value.toInt() : 0;
    int? optional(Object? value) => value is num ? value.toInt() : null;
    final attendance = json['attendance'];
    final attendanceMap = attendance is Map
        ? attendance
        : const <String, dynamic>{};
    final alerts = json['alerts'];
    return TodayPrincipalOverview(
      overdueReviews: count(json['overdueReviews']),
      overdueLeadReviews: count(json['overdueLeadReviews']),
      attentionCount: count(json['attentionCount']),
      todaySubmissions: optional(json['todaySubmissions']),
      timelyReviewRate: json['timelyReviewRate'] is num
          ? (json['timelyReviewRate'] as num).toDouble()
          : null,
      studentPresent: optional(attendanceMap['studentPresent']),
      studentExpected: optional(attendanceMap['studentExpected']),
      teacherPresent: optional(attendanceMap['teacherPresent']),
      teacherExpected: optional(attendanceMap['teacherExpected']),
      alerts: [
        if (alerts is List)
          for (final alert in alerts)
            if (alert is Map) TodayPrincipalAlert.fromJson(alert),
      ],
    );
  }

  /// 老师超时未点评的作品数。
  final int overdueReviews;

  /// 组长超时未复核的作品数。
  final int overdueLeadReviews;
  final int attentionCount;
  final int? todaySubmissions;
  final double? timelyReviewRate;
  final int? studentPresent;
  final int? studentExpected;
  final int? teacherPresent;
  final int? teacherExpected;
  final List<TodayPrincipalAlert> alerts;
}

/// 教学跟进的一条提醒：[target] 为 overdue / leadOverdue / classes / attention。
@immutable
class TodayPrincipalAlert {
  const TodayPrincipalAlert({
    required this.target,
    required this.id,
    required this.text,
  });

  factory TodayPrincipalAlert.fromJson(Map<dynamic, dynamic> json) {
    String text(String key) => json[key]?.toString().trim() ?? '';
    final name = text('name');
    final detail = text('detail');
    return TodayPrincipalAlert(
      target: text('target'),
      id: text('id'),
      text: detail.isEmpty || name.isEmpty ? text('label') : '$name · $detail',
    );
  }

  final String target;
  final String id;
  final String text;
}

/// 宿管当前这一场查寝的进度（`dormitory/dormitoryCheckStat`）。
@immutable
class TodayDormCheck {
  const TodayDormCheck({
    required this.stat,
    this.checkType = '',
    this.deadline = '',
  });

  factory TodayDormCheck.fromJson(Object? raw) {
    var json = raw is Map ? raw : const <String, dynamic>{};
    if (json['data'] is Map) json = json['data'] as Map;
    String text(String key) => json[key]?.toString().trim() ?? '';
    return TodayDormCheck(
      stat: parseDormitoryCheckStat(raw),
      checkType: text('checkType'),
      deadline: text('checkDeadline'),
    );
  }

  final DormitoryCheckStat stat;

  /// 「晚查寝」或「晨查寝」。
  final String checkType;
  final String deadline;
}

/// 今日看板的全部原始数据。每个来源单独请求、单独容错：取不到的字段为空，
/// 页面按已有数据显示，[failedSources] 记录失败的来源数。
@immutable
class TodaySnapshot {
  const TodaySnapshot({
    required this.role,
    required this.now,
    this.isGroupLeader = false,
    this.sources = 0,
    this.failedSources = 0,
    this.tasks = const <ArtworkTask>[],
    this.practices = const <TodayPractice>[],
    this.latestReview,
    this.study,
    this.courses = const <TodayCourse>[],
    this.reviewStats,
    this.leadStats,
    this.attention = const <TodayAttentionStudent>[],
    this.headTeacher,
    this.admin,
    this.scheduleApplies,
    this.mailboxPending,
    this.principal,
    this.dorm,
    this.dormCheck,
    this.dormConfig,
  });

  /// 身份未知时的空看板。
  TodaySnapshot.empty([String role = ''])
    : this(role: role, now: DateTime.fromMillisecondsSinceEpoch(0));

  /// `/myInfo` 的 role：student / teacher / headTeacher / dormManager / admin / principal。
  final String role;
  final DateTime now;

  /// 任课老师兼教学组长。
  final bool isGroupLeader;

  /// 请求的数据来源数与失败数。
  final int sources;
  final int failedSources;

  /// 学生：老师布置的作品任务（含已提交）。
  final List<ArtworkTask> tasks;
  final List<TodayPractice> practices;
  final TodayLatestReview? latestReview;
  final TodayStudySnapshot? study;

  /// 今天的课程：学生与带课老师是本人的课，管理员与校长是全校的课。
  final List<TodayCourse> courses;

  /// 任课老师、班主任：作品点评统计。
  final ArtworkStats? reviewStats;

  /// 教学组长：复核统计（total / pending / overdue）。
  final ({int pending, int overdue})? leadStats;
  final List<TodayAttentionStudent> attention;
  final HeadTeacherIndexRes? headTeacher;

  /// 管理员、校长：管理端首页统计。
  final AdminHomeSummary? admin;

  /// 管理员、校长：待审核的小课申请数。
  final int? scheduleApplies;

  /// 校长：校长信箱待回复数。
  final int? mailboxPending;
  final TodayPrincipalOverview? principal;

  /// 宿管：今日查寝概况、当前场次进度与查寝时间配置。
  final DormitoryIndexOverview? dorm;
  final TodayDormCheck? dormCheck;
  final SchoolDormitoryCheckConfig? dormConfig;

  bool get isEmpty => role.isEmpty;

  /// 全部来源都失败：页面显示加载失败与重试。
  bool get allFailed => sources > 0 && failedSources >= sources;
}
