// 今日看板的演示接口：七个账号的看板内容、与各模块数据的一致性，以及打勾、
// 推迟、今天不做、添加安排、记录练习这些写操作的规则。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_accounts.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_backend.dart';
import 'package:the_road_of_art_flutter/core/demo/demo_store.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/demo_fixtures.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/today/today_fixtures.dart';
import 'package:the_road_of_art_flutter/core/demo/fixtures/today/today_support.dart';
import 'package:the_road_of_art_flutter/features/today/data/today_models.dart';

DemoRequest _request(
  DemoAccount account,
  String path, [
  Map<String, dynamic> body = const {},
]) => DemoRequest(
  method: 'POST',
  path: path,
  query: const <String, dynamic>{},
  body: body,
  headers: <String, dynamic>{'app-token': account.token},
);

/// 周三上午十点：上午的课在上，下午和晚上的课还没开始。
DateTime _wednesday() {
  final now = DateTime.now();
  final monday = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: now.weekday - 1));
  return monday.add(const Duration(days: 2, hours: 10));
}

Future<TodayBoard> _board(DemoAccount account, {DateTime? now}) async {
  final raw = await buildTodayBoard(
    TodayContext(_request(account, '/app/today/board'), now: now),
  );
  return TodayBoard.fromJson(raw);
}

Future<TodayBoard> _post(
  DemoAccount account,
  String path, [
  Map<String, dynamic> body = const {},
]) async {
  final match = DemoBackend.platform.match('POST', path)!;
  return TodayBoard.fromJson(
    await match.handler(_request(account, path, body)),
  );
}

Future<Object?> _marking(DemoAccount account, String path) {
  final match = DemoBackend.marking.match('GET', path)!;
  return Future.value(
    match.handler(
      DemoRequest(
        method: 'GET',
        path: path,
        query: const <String, dynamic>{},
        body: const <String, dynamic>{},
        headers: <String, dynamic>{'app-token': account.token},
        pathParams: match.params,
      ),
    ),
  );
}

const _accounts = [
  DemoAccounts.student,
  DemoAccounts.teacher,
  DemoAccounts.groupLeader,
  DemoAccounts.headTeacher,
  DemoAccounts.dormManager,
  DemoAccounts.admin,
  DemoAccounts.principal,
];

final _banned = RegExp(
  r'最好|最佳|最优|最强|最大|最全|最快|唯一|首选|顶级|独家|保证|绝对|永久|万能|'
  r'保过|包过|必过|提分|涨分|上岸|逆袭|升学率|录取率|\bAI\b|人工智能|智能评分|自动评分|'
  r'第一(?!次|场|眼|步|张|位|天|个|批|份|轮|遍|笔|课|道|站|页|印象)|[!！]',
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await DemoStore.init();
    await DemoStore.reset();
    registerDemoFixtures();
  });

  group('board', () {
    test('every demo account gets a complete, consistent board', () async {
      for (final account in _accounts) {
        final name = account.role.name;
        final board = await _board(account, now: _wednesday());
        expect(board.role, account.roleKey, reason: name);
        expect(
          board.title,
          account.role == DemoRole.student ? '今日学习' : '今日工作',
          reason: name,
        );

        final steps = board.steps.toList();
        expect(steps.length, greaterThanOrEqualTo(4), reason: name);
        expect(
          steps.map((s) => s.id).toSet().length,
          steps.length,
          reason: '$name ids are unique',
        );
        // 进度与清单一致。
        final active = steps.where((s) => s.status != TodayStepStatus.skipped);
        expect(board.summary.total, active.length, reason: name);
        expect(
          board.summary.done,
          active.where((s) => s.done).length,
          reason: name,
        );
        expect(
          board.summary.remaining,
          active.where((s) => s.status.open).length,
          reason: name,
        );
        expect(
          board.summary.overdue,
          active.where((s) => s.status == TodayStepStatus.overdue).length,
          reason: name,
        );

        // 每件事都说得清：标题、来源、怎么做；没有按钮的事必须能自己打勾。
        for (final step in steps) {
          expect(step.title, isNotEmpty, reason: name);
          expect(step.source, isNotEmpty, reason: '$name ${step.title}');
          expect(step.guide, isNotEmpty, reason: '$name ${step.title}');
          if (step.action == null) {
            expect(step.manual, isTrue, reason: '$name ${step.title}');
          } else {
            expect(
              step.action!.label,
              isNotEmpty,
              reason: '$name ${step.title}',
            );
          }
        }

        // 还有没做的事时，一定指出下一步，并且指向清单里的一件。
        if (board.summary.remaining > 0) {
          expect(board.focus, isNotNull, reason: name);
          expect(board.focus!.status.open, isTrue, reason: name);
          expect(board.focusReason, isNotEmpty, reason: name);
        }

        // 超时的事排在「优先处理」里。
        for (final group in board.groups) {
          for (final step in group.steps) {
            expect(
              step.status == TodayStepStatus.overdue,
              group.id == 'urgent',
              reason: '$name ${step.title}',
            );
          }
        }

        // 图表：至少四张，第一张是近 7 天完成，文字版和图同一份数。
        expect(board.charts.length, greaterThanOrEqualTo(4), reason: name);
        final week = board.charts.first as TodayColumnsChart;
        expect(week.id, 'week', reason: name);
        expect(week.items, hasLength(7), reason: name);
        expect(week.items.last.emphasis, isTrue, reason: name);
        expect(week.items.last.value, board.summary.done, reason: name);
        expect(week.items.last.total, board.summary.total, reason: name);
        for (final chart in board.charts) {
          expect(chart.title, isNotEmpty, reason: name);
          if (!chart.isEmpty) {
            expect(chart.table, isNotEmpty, reason: '$name ${chart.title}');
          } else {
            expect(chart.empty, isNotEmpty, reason: '$name ${chart.title}');
          }
        }
        expect(board.shortcuts, isNotEmpty, reason: name);
        // 每个身份四张数字卡，都有图标、数字和去处。
        expect(board.highlights, hasLength(4), reason: name);
        for (final item in board.highlights) {
          expect(item.label, isNotEmpty, reason: name);
          expect(item.value, isNotEmpty, reason: '$name ${item.label}');
          expect(item.icon, isNotEmpty, reason: '$name ${item.label}');
          expect(item.action, isNotNull, reason: '$name ${item.label}');
        }
      }
    });

    test('copy has no banned wording', () async {
      for (final account in _accounts) {
        final board = await _board(account, now: _wednesday());
        final text = [
          board.focusReason,
          for (final group in board.groups) '${group.title}${group.caption}',
          for (final step in board.steps)
            '${step.title}${step.detail}${step.tag}${step.source}'
                '${step.action?.label ?? ''}${step.guide.join()}',
          for (final chart in board.charts)
            '${chart.title}${chart.subtitle}${chart.caption}${chart.empty}'
                '${chart.table.join()}',
          for (final row in board.people?.rows ?? const <TodayPerson>[])
            '${row.name}${row.detail}${row.value}',
          for (final shortcut in board.shortcuts) shortcut.label,
          for (final item in board.highlights) '${item.label}${item.caption}',
        ].join('\n');
        expect(_banned.hasMatch(text), isFalse, reason: account.role.name);
      }
    });

    test('student: lessons, check-ins, practices and study charts', () async {
      final board = await _board(DemoAccounts.student, now: _wednesday());
      final kinds = board.steps.map((s) => s.kind).toSet();
      expect(kinds, containsAll(['lesson', 'dorm', 'practice', 'reading']));

      final lessons = board.steps.where((s) => s.kind == 'lesson').toList();
      expect(lessons, isNotEmpty);
      // 十点：上午的课进行中，下午和晚上的还没开始。
      expect(lessons.first.status, TodayStepStatus.doing);
      expect(lessons.last.status, TodayStepStatus.todo);
      expect(lessons.every((s) => s.required && !s.manual), isTrue);

      final practices = board.steps.where((s) => s.kind == 'practice').toList();
      expect(practices.length, inInclusiveRange(2, 3));
      for (final practice in practices) {
        expect(practice.required, isFalse);
        expect(practice.manual, isTrue);
        expect(practice.minutes, greaterThan(0));
        expect(practice.action!.type, anyOf('tool', 'gallery'));
      }

      expect(board.charts.map((c) => c.id), [
        'week',
        'practice',
        'subjects',
        'works',
      ]);
      // 头图下面的四张数字卡。
      expect(board.highlights.map((h) => h.label), [
        '今日课程',
        '待交作品',
        '今日练习',
        '距离联考',
      ]);
      expect(board.highlights.first.value, '${lessons.length}');
      // 今日课程带进度环；今日练习带近 7 天的小柱子，最后一根是今天。
      expect(board.highlights.first.ratio, isNotNull);
      expect(board.highlights[2].ratio, isNull);
      expect(board.highlights[2].trend, hasLength(7));
      expect(board.highlights[2].trend.last, 0);
      expect(board.highlights[2].trend, [
        for (final point in (board.chart('practice')! as TodayLineChart).points)
          point.value,
      ]);
      expect(board.charts.first.headline!.label, '完成率');
      final practice = board.chart('practice')! as TodayLineChart;
      expect(practice.target, 60);
      expect(practice.points, hasLength(7));
      expect(practice.points.last.value, 0);
      expect(practice.action!.type, 'practiceLog');

      // 三科成绩与学情里最近一次月考一致，分数最低的一科标出来。
      final overview = await _marking(
        DemoAccounts.student,
        '/app/study/overview',
      );
      final subjects =
          (((overview as Map)['recentStage'] as Map)['exam'] as Map)['subjects']
              as List;
      final meters = board.chart('subjects')! as TodayMetersChart;
      expect(meters.rows.map((r) => r.label), [
        for (final s in subjects) (s as Map)['subjectName'],
      ]);
      expect(meters.rows.map((r) => r.value), [
        for (final s in subjects) (s as Map)['score'],
      ]);
      final weakest = meters.rows.reduce((a, b) => a.value <= b.value ? a : b);
      expect(meters.rows.where((r) => r.tag.isNotEmpty).single, weakest);
      expect(board.people, isNull);
    });

    test('teacher: the review step is the artwork review queue', () async {
      final stats =
          await _marking(
                DemoAccounts.teacher,
                '/school/teacher/artworks/statistics',
              )
              as Map;
      final board = await _board(DemoAccounts.teacher, now: _wednesday());
      final review = board.steps.firstWhere((s) => s.id == 'reviews');
      final pending = stats['pending'] as int;
      final overdue = stats['overdue'] as int;
      expect(review.manual, isFalse);
      expect(review.progress!.total - review.progress!.done, pending);
      if (overdue > 0) {
        expect(review.status, TodayStepStatus.overdue);
        expect(review.tag, '超时 $overdue 件');
        expect(board.focusStepId, 'reviews');
      }
      expect(review.action!.route, '/artworks');
      expect(review.action!.arguments, {'startReview': true});

      final meters = board.chart('review')! as TodayMetersChart;
      expect(meters.rows.first.label, '今日点评');
      expect(meters.rows.first.value, review.progress!.done);
      expect(board.people!.title, '需要关注的学生');
      expect(board.people!.rows.length, inInclusiveRange(1, 5));
      expect(board.steps.any((s) => s.id == 'lead'), isFalse);
    });

    test(
      'group leader also gets the review pool and the group chart',
      () async {
        final board = await _board(DemoAccounts.groupLeader, now: _wednesday());
        final lead = board.steps.firstWhere((s) => s.id == 'lead');
        expect(lead.action!.route, '/artworks/lead-reviews');
        expect(board.chart('group'), isA<TodayMetersChart>());
        expect(board.shortcuts.map((s) => s.label), contains('本组老师'));
      },
    );

    test(
      'head teacher, admin and principal: approvals carry real counts',
      () async {
        final head = await _board(DemoAccounts.headTeacher, now: _wednesday());
        expect(
          head.steps.map((s) => s.id),
          containsAll(['reviews', 'leave', 'makeup', 'chat']),
        );
        expect(head.chart('classAttendance'), isA<TodayPartsChart>());
        expect(head.chart('classDorm'), isA<TodayPartsChart>());

        final admin = await _board(DemoAccounts.admin, now: _wednesday());
        expect(
          admin.steps.map((s) => s.id),
          containsAll(['teacherLeave', 'signConfirm', 'scheduleApply']),
        );
        for (final id in ['teacherLeave', 'signConfirm', 'scheduleApply']) {
          final step = admin.steps.firstWhere((s) => s.id == id);
          expect(step.progress!.total, greaterThan(0), reason: id);
          expect(step.manual, isFalse, reason: id);
        }
        final courses = admin.chart('courses')! as TodayPartsChart;
        expect(courses.parts.map((p) => p.label), ['已结束', '进行中', '未开始']);
        expect(admin.people, isNull);

        final principal = await _board(
          DemoAccounts.principal,
          now: _wednesday(),
        );
        expect(
          principal.steps.map((s) => s.id),
          containsAll(['overdueReviews', 'mailbox', 'teacherLeave']),
        );
        final compare = principal.chart('campus')! as TodayCompareChart;
        expect(compare.columns, ['月考均分', '点评及时率', '出勤率']);
        expect(compare.rows.map((r) => r.label), ['城东校区', '城西校区', '安宁校区']);
        expect(principal.chart('chain'), isA<TodayMetersChart>());
        expect(principal.people!.title, '教学跟进');
        expect(principal.people!.followLabel, '已督办');
      },
    );

    test(
      'dorm manager: duty steps follow the timetable and the room grid',
      () async {
        final board = await _board(DemoAccounts.dormManager, now: _wednesday());
        final duties = board.steps
            .where((s) => s.id.startsWith('duty:'))
            .toList();
        expect(duties.map((s) => s.title), containsAll(['晨查寝', '晚查寝']));
        expect(board.steps.any((s) => s.id == 'punch'), isTrue);
        // 巡查没有对应的页面，做完直接打勾。
        final patrol = board.steps.firstWhere((s) => s.kind == 'patrol');
        expect(patrol.action, isNull);
        expect(patrol.manual, isTrue);

        final rooms = board.chart('rooms')! as TodayRoomsChart;
        expect(rooms.rooms, isNotEmpty);
        expect(
          rooms.rooms.every((r) => r.checked <= r.total && r.total > 0),
          isTrue,
        );
        expect(board.chart('check'), isA<TodayPartsChart>());
        // 宿管不看成绩与作品。
        expect(board.steps.any((s) => s.kind == 'review'), isFalse);
      },
    );

    test(
      'a count is remembered for the day and shrinks into progress',
      () async {
        final account = DemoAccounts.admin;
        final ctx = TodayContext(_request(account, '/app/today/board'));
        expect(ctx.baseline('demo', 4), 4);
        // 处理掉两条后，还是按当天第一次看到的 4 条算进度。
        expect(ctx.baseline('demo', 2), 4);
        final step = todayCountStep(
          ctx,
          id: 'demo',
          kind: 'approval',
          title: '示例',
          detail: '待处理',
          doneDetail: '都处理完了',
          unit: '条',
          current: 2,
          source: '示例',
          guide: const ['处理'],
          action: actionCampus('去处理', 'signManagement'),
        )!;
        expect(step['status'], 'doing');
        expect(step['progress'], {'done': 2, 'total': 4, 'unit': '条'});
        final cleared = todayCountStep(
          ctx,
          id: 'demo',
          kind: 'approval',
          title: '示例',
          detail: '待处理',
          doneDetail: '都处理完了',
          unit: '条',
          current: 0,
          source: '示例',
          guide: const ['处理'],
          action: actionCampus('去处理', 'signManagement'),
        )!;
        expect(cleared['status'], 'done');
        expect(cleared['detail'], '都处理完了');
        // 当天一直没有的事不出现。
        expect(
          todayCountStep(
            ctx,
            id: 'none',
            kind: 'approval',
            title: '示例',
            detail: '',
            doneDetail: '',
            unit: '条',
            current: 0,
            source: '示例',
            guide: const ['处理'],
            action: actionCampus('去处理', 'signManagement'),
          ),
          isNull,
        );
      },
    );
  });

  group('writes', () {
    test(
      'ticking a practice logs its minutes; unticking takes them back',
      () async {
        final account = DemoAccounts.student;
        final before = await _post(account, '/app/today/board');
        final practice = before.steps.firstWhere((s) => s.kind == 'practice');
        expect(practice.status, TodayStepStatus.todo);

        final ticked = await _post(account, '/app/today/step/complete', {
          'id': practice.id,
        });
        expect(
          ticked.steps.firstWhere((s) => s.id == practice.id).status,
          TodayStepStatus.done,
        );
        expect(ticked.summary.done, before.summary.done + 1);
        expect(ticked.summary.remaining, before.summary.remaining - 1);
        final line = ticked.chart('practice')! as TodayLineChart;
        expect(line.points.last.value, practice.minutes);
        expect(line.caption, contains('今天已练 ${practice.minutes} 分钟'));
        expect(
          (ticked.charts.first as TodayColumnsChart).items.last.value,
          ticked.summary.done,
        );

        final undone = await _post(account, '/app/today/step/reopen', {
          'id': practice.id,
        });
        expect(undone.summary.done, before.summary.done);
        expect(
          (undone.chart('practice')! as TodayLineChart).points.last.value,
          0,
        );
      },
    );

    test('only steps the person confirms can be ticked by hand', () async {
      final account = DemoAccounts.student;
      final board = await _post(account, '/app/today/board');
      final lesson = board.steps.firstWhere((s) => s.kind == 'lesson');
      await expectLater(
        _post(account, '/app/today/step/complete', {'id': lesson.id}),
        throwsA(
          isA<DemoApiException>().having(
            (e) => e.message,
            'message',
            contains('自动打勾'),
          ),
        ),
      );
      await expectLater(
        _post(account, '/app/today/step/complete', {'id': 'missing'}),
        throwsA(isA<DemoApiException>()),
      );
    });

    test('suggested steps can be skipped or pushed to the evening', () async {
      final account = DemoAccounts.student;
      final board = await _post(account, '/app/today/board');
      final practice = board.steps.firstWhere((s) => s.kind == 'practice');
      final lesson = board.steps.firstWhere((s) => s.kind == 'lesson');

      final skipped = await _post(account, '/app/today/step/skip', {
        'id': practice.id,
      });
      expect(
        skipped.steps.firstWhere((s) => s.id == practice.id).status,
        TodayStepStatus.skipped,
      );
      // 今天不做的事不计入进度。
      expect(skipped.summary.total, board.summary.total - 1);
      final restored = await _post(account, '/app/today/step/restore', {
        'id': practice.id,
      });
      expect(restored.summary.total, board.summary.total);

      await expectLater(
        _post(account, '/app/today/step/skip', {'id': lesson.id}),
        throwsA(isA<DemoApiException>()),
      );
      await expectLater(
        _post(account, '/app/today/step/snooze', {'id': lesson.id}),
        throwsA(isA<DemoApiException>()),
      );

      final snoozed = await _post(account, '/app/today/step/snooze', {
        'id': practice.id,
      });
      final evening = snoozed.groups.firstWhere((g) => g.id == 'evening');
      expect(evening.steps.map((s) => s.id), contains(practice.id));
      expect(
        snoozed.steps.firstWhere((s) => s.id == practice.id).snoozed,
        isTrue,
      );
      final back = await _post(account, '/app/today/step/snooze', {
        'id': practice.id,
        'on': false,
      });
      expect(
        back.steps.firstWhere((s) => s.id == practice.id).snoozed,
        isFalse,
      );
    });

    test('a personal step can be added, ticked and deleted', () async {
      final account = DemoAccounts.teacher;
      final before = await _post(account, '/app/today/board');
      final added = await _post(account, '/app/today/step/save', {
        'title': '整理素描范画',
        'slot': 'afternoon',
        'detail': '为周五的讲评挑三张',
      });
      final custom = added.steps.firstWhere((s) => s.custom);
      expect(custom.title, '整理素描范画');
      expect(custom.manual, isTrue);
      expect(custom.required, isFalse);
      expect(
        added.groups.firstWhere((g) => g.id == 'afternoon').steps,
        contains(custom),
      );
      expect(added.summary.total, before.summary.total + 1);

      final ticked = await _post(account, '/app/today/step/complete', {
        'id': custom.id,
      });
      expect(ticked.summary.done, before.summary.done + 1);

      final deleted = await _post(account, '/app/today/step/delete', {
        'id': custom.id,
      });
      expect(deleted.steps.any((s) => s.custom), isFalse);
      expect(deleted.summary.total, before.summary.total);
      expect(deleted.summary.done, before.summary.done);

      await expectLater(
        _post(account, '/app/today/step/save', {
          'title': ' ',
          'slot': 'anytime',
        }),
        throwsA(isA<DemoApiException>()),
      );
      await expectLater(
        _post(account, '/app/today/step/save', {'title': '一' * 31}),
        throwsA(isA<DemoApiException>()),
      );
      await expectLater(
        _post(account, '/app/today/step/delete', {'id': 'reviews'}),
        throwsA(isA<DemoApiException>()),
      );
    });

    test('practice minutes, follow-ups and the tip are remembered', () async {
      final student = DemoAccounts.student;
      final logged = await _post(student, '/app/today/practice/log', {
        'minutes': 35,
      });
      expect(
        (logged.chart('practice')! as TodayLineChart).points.last.value,
        35,
      );
      await expectLater(
        _post(student, '/app/today/practice/log', {'minutes': 0}),
        throwsA(isA<DemoApiException>()),
      );

      expect(logged.tipSeen, isFalse);
      final dismissed = await _post(student, '/app/today/tip/dismiss');
      expect(dismissed.tipSeen, isTrue);

      final teacher = DemoAccounts.teacher;
      final board = await _post(teacher, '/app/today/board');
      final person = board.people!.rows.first;
      expect(person.followed, isFalse);
      final followed = await _post(teacher, '/app/today/people/follow', {
        'id': person.id,
        'followed': true,
      });
      expect(followed.people!.rows.first.followed, isTrue);
      // 每个账号各记各的。
      expect(
        (await _post(student, '/app/today/board')).steps.any((s) => s.custom),
        isFalse,
      );
    });

    test(
      'yesterday\'s ticks do not carry over; the tip stays dismissed',
      () async {
        final account = DemoAccounts.student;
        await _post(account, '/app/today/tip/dismiss');
        final today = await _post(account, '/app/today/board');
        final practice = today.steps.firstWhere((s) => s.kind == 'practice');
        await _post(account, '/app/today/step/complete', {'id': practice.id});

        final tomorrow = await _board(
          account,
          now: DateTime.now().add(const Duration(days: 1)),
        );
        expect(
          tomorrow.steps
              .where((s) => s.kind == 'practice')
              .every((s) => s.status != TodayStepStatus.done),
          isTrue,
        );
        expect(tomorrow.tipSeen, isTrue);
      },
    );
  });
}
