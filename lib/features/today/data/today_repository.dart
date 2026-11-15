import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/demo/demo_clock.dart';
import '../../../core/demo/demo_config.dart';
import '../../../core/network/api_response.dart';
import '../../artworks/data/artwork_models.dart';
import '../../artworks/data/artwork_repository.dart';
import '../../school/data/school_config_data.dart';
import '../../school/data/school_repository.dart';
import '../../smart_campus/data/admin_home_data.dart';
import '../../smart_campus/data/admin_repository.dart';
import '../../smart_campus/data/dormitory_check_data.dart';
import '../../smart_campus/data/dormitory_repository.dart';
import '../../smart_campus/data/head_teacher_index_data.dart';
import '../../smart_campus/data/principal_inbox_data.dart';
import '../../smart_campus/data/principal_mailbox_repository.dart';
import '../../smart_campus/data/student_repository.dart';
import '../../smart_campus/data/teacher_repository.dart';
import '../../study_center/data/study_center_repository.dart';
import '../../study_center/data/study_models.dart';
import '../../teaching_overview/data/teaching_overview_repository.dart';
import 'today_models.dart';
import 'today_practice.dart';

final todayRepositoryProvider = Provider<TodayRepository>((ref) {
  return TodayRepository(
    artworks: ref.watch(artworkRepositoryProvider),
    study: ref.watch(studyCenterRepositoryProvider),
    student: ref.watch(studentRepositoryProvider),
    teacher: ref.watch(teacherRepositoryProvider),
    admin: ref.watch(adminRepositoryProvider),
    dormitory: ref.watch(dormitoryRepositoryProvider),
    mailbox: ref.watch(principalMailboxRepositoryProvider),
    school: ref.watch(schoolRepositoryProvider),
    teaching: ref.watch(teachingOverviewRepositoryProvider),
  );
});

/// 今日看板的数据：只读取各模块已有的接口，按身份并行请求。
///
/// 每个来源单独容错，一个接口失败不影响其他内容。
class TodayRepository {
  TodayRepository({
    required this.artworks,
    required this.study,
    required this.student,
    required this.teacher,
    required this.admin,
    required this.dormitory,
    required this.mailbox,
    required this.school,
    required this.teaching,
  });

  final ArtworkRepository artworks;
  final StudyCenterRepository study;
  final StudentRepository student;
  final TeacherRepository teacher;
  final AdminRepository admin;
  final DormitoryRepository dormitory;
  final PrincipalMailboxRepository mailbox;
  final SchoolRepository school;
  final TeachingOverviewRepository teaching;

  /// [now] 用来判断课程进行到哪一步；作品任务的「今天」在演示版按 [DemoClock]
  /// 取，和任务的截止时间同一个基准。
  Future<TodaySnapshot> load({
    required String role,
    bool isGroupLeader = false,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final sources = _Sources();
    return switch (role.trim()) {
      'student' => _student(at, sources),
      'teacher' => _teacher(at, sources, isGroupLeader: isGroupLeader),
      'headTeacher' => _headTeacher(at, sources),
      'admin' => _admin(at, sources),
      'principal' => _principal(at, sources),
      'dormManager' => _dormManager(at, sources),
      _ => Future.value(TodaySnapshot.empty(role.trim())),
    };
  }

  Future<TodaySnapshot> _student(DateTime now, _Sources sources) async {
    final day = _date(now);
    final (tasks, insights, review, snapshot, courses) = await (
      sources.run(() async {
        final data = _data(await artworks.getTasks());
        return [
          if (data is List)
            for (final item in data) ArtworkTask.fromJson(item),
        ];
      }),
      sources.run(
        () async =>
            ArtworkInsights.fromJson(_data(await artworks.getInsights())),
      ),
      sources.run(_latestReview),
      sources.run(_studySnapshot),
      sources.run(
        () async => parseTodayCourses(
          _data(await student.courseList(beginDate: day, endDate: day)),
          day,
        ),
      ),
    ).wait;
    return TodaySnapshot(
      role: 'student',
      now: now,
      sources: sources.total,
      failedSources: sources.failed,
      tasks: tasks ?? const <ArtworkTask>[],
      practices: buildTodayPractices(insights: insights, snapshot: snapshot),
      latestReview: review,
      study: snapshot,
      courses: courses ?? const <TodayCourse>[],
    );
  }

  Future<TodaySnapshot> _teacher(
    DateTime now,
    _Sources sources, {
    required bool isGroupLeader,
  }) async {
    final (stats, courses, attention, lead) = await (
      sources.run(_reviewStats),
      sources.run(() => _teacherCourses(now)),
      sources.run(_attention),
      isGroupLeader
          ? sources.run(() async {
              final raw = _data(await artworks.getLeadReviewStatistics());
              int read(String key) {
                final value = raw is Map ? raw[key] : null;
                return value is num ? value.toInt() : 0;
              }

              return (pending: read('pending'), overdue: read('overdue'));
            })
          : Future<({int pending, int overdue})?>.value(),
    ).wait;
    return TodaySnapshot(
      role: 'teacher',
      now: now,
      isGroupLeader: isGroupLeader,
      sources: sources.total,
      failedSources: sources.failed,
      reviewStats: stats,
      leadStats: lead,
      courses: courses ?? const <TodayCourse>[],
      attention: attention ?? const <TodayAttentionStudent>[],
    );
  }

  Future<TodaySnapshot> _headTeacher(DateTime now, _Sources sources) async {
    final (stats, courses, attention, index) = await (
      sources.run(_reviewStats),
      sources.run(() => _teacherCourses(now)),
      sources.run(_attention),
      sources.run(
        () async =>
            parseHeadTeacherIndexRes(_data(await teacher.headTeacherIndex())),
      ),
    ).wait;
    return TodaySnapshot(
      role: 'headTeacher',
      now: now,
      sources: sources.total,
      failedSources: sources.failed,
      reviewStats: stats,
      courses: courses ?? const <TodayCourse>[],
      attention: attention ?? const <TodayAttentionStudent>[],
      headTeacher: index,
    );
  }

  Future<TodaySnapshot> _admin(DateTime now, _Sources sources) async {
    final (summary, applies, courses) = await (
      sources.run(_adminSummary),
      sources.run(_scheduleApplies),
      sources.run(() => _schoolCourses(now)),
    ).wait;
    return TodaySnapshot(
      role: 'admin',
      now: now,
      sources: sources.total,
      failedSources: sources.failed,
      admin: summary,
      scheduleApplies: applies,
      courses: courses ?? const <TodayCourse>[],
    );
  }

  Future<TodaySnapshot> _principal(DateTime now, _Sources sources) async {
    final (summary, applies, courses, pending, overview) = await (
      sources.run(_adminSummary),
      sources.run(_scheduleApplies),
      sources.run(() => _schoolCourses(now)),
      sources.run(() async {
        final raw = _data(
          await mailbox.headmasterPrincipalMailboxList(size: 1),
        );
        return parsePrincipalInboxTotal(raw) ??
            parsePrincipalInboxPendingCount(raw);
      }),
      sources.run(
        () async => TodayPrincipalOverview.fromJson(
          _data(
            await teaching.load((
              report: TeachingReport.overview,
              campus: '',
              parameter: '',
            )),
          ),
        ),
      ),
    ).wait;
    return TodaySnapshot(
      role: 'principal',
      now: now,
      sources: sources.total,
      failedSources: sources.failed,
      admin: summary,
      scheduleApplies: applies,
      courses: courses ?? const <TodayCourse>[],
      mailboxPending: pending,
      principal: overview,
    );
  }

  Future<TodaySnapshot> _dormManager(DateTime now, _Sources sources) async {
    final (index, check, config) = await (
      sources.run(
        () async => parseDormitoryIndexOverview(_data(await dormitory.index())),
      ),
      sources.run(
        () async => TodayDormCheck.fromJson(
          _data(await dormitory.dormitoryCheckStat()),
        ),
      ),
      sources.run(
        () async => parseSchoolDormitoryCheckConfig(
          _data(await school.schoolConfigList()),
        ),
      ),
    ).wait;
    return TodaySnapshot(
      role: 'dormManager',
      now: now,
      sources: sources.total,
      failedSources: sources.failed,
      dorm: index,
      dormCheck: check,
      dormConfig: config,
    );
  }

  Future<ArtworkStats> _reviewStats() async =>
      ArtworkStats.fromJson(_data(await artworks.getTeacherStatistics()));

  Future<List<TodayCourse>> _teacherCourses(DateTime now) async {
    final day = _date(now);
    return parseTodayCourses(
      _data(await teacher.courseList(beginDate: day, endDate: day)),
      day,
    );
  }

  Future<List<TodayCourse>> _schoolCourses(DateTime now) async {
    final day = _date(now);
    return parseTodayCourses(
      _data(await admin.courseList(beginDate: day, endDate: day)),
      day,
    );
  }

  Future<AdminHomeSummary> _adminSummary() async =>
      AdminHomeSummary.fromJson(_data(await admin.indexSum()));

  Future<int> _scheduleApplies() async {
    final raw = _data(
      await admin.schoolSmallCourseApplyList(size: 1, status: 0),
    );
    return parseAdminPageTotal(raw) ?? 0;
  }

  /// 老师名下需要关注的学生，最多三名。
  Future<List<TodayAttentionStudent>> _attention() async {
    final rows = teachingRows(
      _data(
        await teaching.load((
          report: TeachingReport.myAttention,
          campus: '',
          parameter: '',
        )),
      ),
    );
    return [
      for (final row in rows.take(3))
        TodayAttentionStudent(
          id: teachingText(row['id']),
          name: teachingText(row['name']),
          reason: teachingText((row['reasons'] as List?)?.firstOrNull),
        ),
    ];
  }

  /// 已点评作品按绘画日期倒序取第一份，再取详情拿到老师评语。
  Future<TodayLatestReview?> _latestReview() async {
    final records = ArtworkPage.fromJson(
      _data(
        await artworks.getArtworks(
          status: ArtworkStatusFilter.reviewed,
          page: 1,
          size: 1,
        ),
      ),
    ).records;
    if (records.isEmpty) return null;
    final work = records.first;
    final detail = await artworks.getArtwork(work.id);
    return TodayLatestReview.from(
      work,
      detail.isSuccess ? ArtworkDetail.fromJson(detail.data) : null,
    );
  }

  /// 最近一次已出分考试。
  Future<TodayStudySnapshot?> _studySnapshot() async {
    final raw = _data(await study.overview());
    final stage = StudyOverview.fromJson(raw).recentStage;
    if (stage == null) return null;
    final exam = stage.exam;
    final next = raw is Map
        ? DateTime.tryParse('${raw['nextExamDate']}')
        : null;
    final today = raw is Map ? DateTime.tryParse('${raw['today']}') : null;
    return TodayStudySnapshot(
      examName: exam.examName,
      examDate: exam.examTime.length >= 10
          ? exam.examTime.substring(0, 10)
          : exam.examTime,
      totalScore: exam.totalScore,
      maxScore: exam.maxScore,
      ranking: exam.totalRanking,
      participants: exam.participantCount,
      scoreChange: stage.scoreChange,
      rankingChange: stage.rankingChange,
      nextExamDays: next == null || today == null
          ? null
          : next.difference(today).inDays.clamp(0, 365),
      subjects: [
        for (final subject in exam.subjects)
          (
            name: subject.subjectName,
            score: subject.score,
            grade: subject.grade,
          ),
      ],
    );
  }
}

/// 作品任务用的「今天」：演示版与任务截止时间同一个基准。
DateTime todayTaskClock([DateTime? real]) =>
    kDemoMode ? DemoClock.now(real) : (real ?? DateTime.now());

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 取出回包里的数据；业务失败时抛出，由 [_Sources.run] 记为这个来源失败。
dynamic _data(ApiResponse response) {
  if (!response.isSuccess) {
    throw StateError(response.displayMsg);
  }
  return response.data;
}

/// 统计请求了几个来源、失败了几个。
class _Sources {
  int total = 0;
  int failed = 0;

  Future<T?> run<T>(Future<T?> Function() task) async {
    total++;
    try {
      return await task();
    } catch (_) {
      failed++;
      return null;
    }
  }
}
