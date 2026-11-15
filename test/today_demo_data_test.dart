// 今日看板接演示后端：七个演示账号都能取到数据，内容与各模块自己的页面一致。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_store.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/demo_fixtures.dart';
import 'package:the_road_of_art_flutter/core/providers/app_providers.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';
import 'package:the_road_of_art_flutter/features/artworks/data/artwork_models.dart';
import 'package:the_road_of_art_flutter/features/artworks/data/artwork_repository.dart';
import 'package:the_road_of_art_flutter/features/today/data/today_models.dart';
import 'package:the_road_of_art_flutter/features/today/data/today_repository.dart';
import 'package:the_road_of_art_flutter/features/today/state/today_board.dart';

Future<(TodaySnapshot, ProviderContainer)> _load(
  DemoAccount account, {
  DateTime? now,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'token': account.token,
    'schoolId': '1',
    'mobile': account.mobile,
  });
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [appStorageProvider.overrideWithValue(AppStorage(prefs))],
  );
  addTearDown(container.dispose);
  final snapshot = await container
      .read(todayRepositoryProvider)
      .load(
        role: account.roleKey,
        isGroupLeader: account.role == DemoRole.groupLeader,
        now: now,
      );
  return (snapshot, container);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await DemoStore.init();
    await DemoStore.reset();
    registerDemoFixtures();
  });

  test('every demo account loads its board without a failed source', () async {
    for (final account in [
      DemoAccounts.student,
      DemoAccounts.teacher,
      DemoAccounts.groupLeader,
      DemoAccounts.headTeacher,
      DemoAccounts.dormManager,
      DemoAccounts.admin,
      DemoAccounts.principal,
    ]) {
      final (snapshot, _) = await _load(account);
      final name = account.role.name;
      expect(snapshot.role, account.roleKey, reason: name);
      expect(snapshot.sources, greaterThanOrEqualTo(3), reason: name);
      expect(snapshot.failedSources, 0, reason: name);

      final board = buildTodayBoard(snapshot);
      expect(board.role, account.roleKey, reason: name);
      expect(board.shortcuts, isNotEmpty, reason: name);
      expect(board.summary, isNotEmpty, reason: name);
      // 每一行都有标题、操作和去处。
      for (final task in board.tasks) {
        expect(task.title, isNotEmpty, reason: name);
        expect(task.actionLabel, isNotEmpty, reason: '$name ${task.title}');
      }
    }
  });

  test('student: practices, the latest review and the last exam', () async {
    final (snapshot, _) = await _load(DemoAccounts.student);
    expect(snapshot.practices, isNotEmpty);
    expect(snapshot.practices.length, lessThanOrEqualTo(3));
    expect(snapshot.latestReview, isNotNull);
    expect(snapshot.latestReview!.title, isNotEmpty);
    expect(snapshot.study, isNotNull);
    expect(snapshot.study!.subjects.map((s) => s.name), ['素描', '色彩', '速写']);
    final board = buildTodayBoard(snapshot);
    expect(board.signals.map((s) => s.label), contains('需要加强的科目'));
    expect(board.latestReview, isNotNull);
    expect(board.notesTitle, isEmpty);
  });

  test('student lessons carry times, teacher and room', () async {
    // 周三上午十点：按演示课表当天有课。
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final (snapshot, _) = await _load(
      DemoAccounts.student,
      now: monday.add(const Duration(days: 2, hours: 10)),
    );
    expect(snapshot.courses, isNotEmpty);
    for (final course in snapshot.courses) {
      expect(course.start, matches(r'^\d{2}:\d{2}$'));
      expect(course.subject, isNotEmpty);
      expect(course.teacherName, isNotEmpty);
    }
    final board = buildTodayBoard(snapshot);
    expect(board.agendaTotal, snapshot.courses.length);
    expect(board.summary, contains('今天 ${snapshot.courses.length} 节课'));
  });

  test('teacher: the pending count is the artwork review queue', () async {
    final (snapshot, container) = await _load(DemoAccounts.teacher);
    final stats = ArtworkStats.fromJson(
      (await container.read(artworkRepositoryProvider).getTeacherStatistics())
          .data,
    );
    expect(snapshot.reviewStats!.pending, stats.pending);
    expect(snapshot.reviewStats!.overdue, stats.overdue);
    expect(snapshot.leadStats, isNull);

    final board = buildTodayBoard(snapshot);
    final reviews = board.tasks.firstWhere((task) => task.id == 'reviews');
    if (stats.pending > 0) {
      expect(reviews.count, stats.pending);
      expect(reviews.actionLabel, '开始点评');
    } else {
      expect(reviews.pending, isFalse);
    }
    expect(board.notesTitle, '需要关注的学生');
    expect(snapshot.attention.length, lessThanOrEqualTo(3));
  });

  test('group leader also loads the lead review pool', () async {
    final (snapshot, _) = await _load(DemoAccounts.groupLeader);
    expect(snapshot.isGroupLeader, isTrue);
    expect(snapshot.leadStats, isNotNull);
    final board = buildTodayBoard(snapshot);
    expect(board.shortcuts.map((s) => s.label), contains('本组老师'));
    if (snapshot.leadStats!.pending > 0) {
      expect(board.tasks.map((t) => t.title), contains('待复核作品'));
    }
  });

  test('head teacher: class work bench counts come through', () async {
    final (snapshot, _) = await _load(DemoAccounts.headTeacher);
    expect(snapshot.headTeacher, isNotNull);
    expect(snapshot.reviewStats, isNotNull);
    final board = buildTodayBoard(snapshot);
    final index = snapshot.headTeacher!;
    expect(
      board.tasks.any((t) => t.id == 'leave'),
      index.pendingLeaveCount > 0,
    );
    expect(
      board.tasks.any((t) => t.id == 'dorm'),
      index.todayAbnormalDormCount > 0,
    );
  });

  test('admin and principal: approvals and the school timetable', () async {
    final (admin, _) = await _load(DemoAccounts.admin);
    expect(admin.admin, isNotNull);
    expect(admin.admin!.studentCount, greaterThan(0));
    expect(admin.scheduleApplies, isNotNull);
    expect(admin.principal, isNull);
    final adminBoard = buildTodayBoard(admin);
    expect(adminBoard.agendaTitle, '全校今日课程');
    expect(adminBoard.agendaTotal, admin.courses.length);
    expect(adminBoard.signals.first.label, '在读学生');

    final (principal, _) = await _load(DemoAccounts.principal);
    expect(principal.principal, isNotNull);
    expect(principal.mailboxPending, isNotNull);
    final board = buildTodayBoard(principal);
    expect(board.signalsTitle, '在校情况');
    expect(board.notesTitle, '教学跟进');
    final overview = principal.principal!;
    expect(
      board.tasks.any((t) => t.id == 'overdueReviews'),
      overview.overdueReviews > 0,
    );
    expect(
      board.tasks.any((t) => t.id == 'mailbox'),
      principal.mailboxPending! > 0,
    );
    // 校长看三个校区，课程不少于管理员看到的。
    expect(
      principal.courses.length,
      greaterThanOrEqualTo(admin.courses.length),
    );
  });

  test('dorm manager: the current check and the duty list', () async {
    final (snapshot, _) = await _load(DemoAccounts.dormManager);
    expect(snapshot.dorm, isNotNull);
    expect(snapshot.dormCheck, isNotNull);
    expect(snapshot.dormCheck!.stat.bedCount, greaterThan(0));
    expect(snapshot.dormCheck!.checkType, anyOf('晚查寝', '晨查寝'));
    expect(snapshot.dormConfig!.eveningDeadline, isNotEmpty);
    // 宿管不取成绩与作品。
    expect(snapshot.reviewStats, isNull);
    expect(snapshot.study, isNull);

    final board = buildTodayBoard(snapshot);
    expect(board.agendaTitle, '今日值班');
    expect(board.agenda, isNotEmpty);
    expect(board.tasks.map((t) => t.id), containsAll(['check', 'punch']));
    expect(board.signals.map((s) => s.label), ['正常', '晚归', '缺勤']);
  });

  test('an unknown role asks for nothing', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [appStorageProvider.overrideWithValue(AppStorage(prefs))],
    );
    addTearDown(container.dispose);
    final snapshot = await container
        .read(todayRepositoryProvider)
        .load(role: '');
    expect(snapshot.isEmpty, isTrue);
    expect(snapshot.sources, 0);
    expect(buildTodayBoard(snapshot).tasks, isEmpty);
  });
}
