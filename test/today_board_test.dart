// 今日（今日学习 / 今日工作）：各身份的看板内容、排序与页面版式。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_road_of_art_flutter/app/router/route_paths.dart';
import 'package:the_road_of_art_flutter/core/providers/app_providers.dart';
import 'package:the_road_of_art_flutter/core/storage/app_storage.dart';
import 'package:the_road_of_art_flutter/core/ui/ui.dart';
import 'package:the_road_of_art_flutter/features/art_toolbox/data/toolbox_catalog.dart';
import 'package:the_road_of_art_flutter/features/artworks/data/artwork_models.dart';
import 'package:the_road_of_art_flutter/features/school/data/school_config_data.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/data/admin_home_data.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/data/dormitory_check_data.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/data/head_teacher_index_data.dart';
import 'package:the_road_of_art_flutter/features/smart_campus/state/campus_entry.dart';
import 'package:the_road_of_art_flutter/features/teaching_overview/data/teaching_overview_repository.dart';
import 'package:the_road_of_art_flutter/features/today/data/today_models.dart';
import 'package:the_road_of_art_flutter/features/today/data/today_practice.dart';
import 'package:the_road_of_art_flutter/features/today/state/today_board.dart';
import 'package:the_road_of_art_flutter/features/today/state/today_controller.dart';
import 'package:the_road_of_art_flutter/features/today/ui/today_page.dart';

/// 周一上午十点：上午的课在上，下午和晚上的课还没开始。
final _now = DateTime(2026, 11, 16, 10);

const _study = TodayStudySnapshot(
  examName: '2026 年 9 月月考',
  examDate: '2026-09-20',
  totalScore: 265.5,
  maxScore: 300,
  ranking: 7,
  participants: 38,
  scoreChange: 9,
  nextExamDays: 12,
  subjects: [
    (name: '素描', score: 92.5, grade: 'A'),
    (name: '色彩', score: 85, grade: 'B'),
    (name: '速写', score: 88, grade: 'B'),
  ],
);

/// 与演示数据林小雨的点评小结一致：结构错误 3 次（镜像）、线条生硬 2 次（速写计时）。
const _insights = ArtworkInsights(
  reviewedCount: 6,
  weakestSubject: '色彩',
  suggestions: [
    ArtworkSuggestion(
      tag: '结构错误',
      text: '起形时用辅助线核对比例和骨点，完成后镜像翻转检查形准。',
      count: 3,
      gallerySubject: '素描',
      galleryKeyword: '结构',
      tool: '镜像',
    ),
    ArtworkSuggestion(
      tag: '线条生硬',
      text: '多练长线条的轻重虚实，衣纹注意疏密与节奏。',
      count: 2,
      gallerySubject: '速写',
      galleryKeyword: '线条',
      tool: '速写计时',
    ),
    ArtworkSuggestion(
      tag: '明暗层次弱',
      text: '眯眼概括黑白灰三大关系。',
      count: 1,
      gallerySubject: '素描',
      galleryKeyword: '明暗',
      tool: '明度检查',
    ),
  ],
);

const _morning = TodayCourse(
  id: 'c1',
  start: '08:30',
  end: '11:30',
  subject: '素描',
  className: '联考冲刺1班',
  room: '301 画室',
  teacherName: '李静',
);

const _afternoonSmall = TodayCourse(
  id: 'c2',
  start: '14:00',
  end: '17:00',
  subject: '色彩',
  className: '色彩精进小班',
  room: '302 画室',
  teacherName: '王海波',
  isSmall: true,
);

TodaySnapshot _student() => TodaySnapshot(
  role: 'student',
  now: _now,
  sources: 5,
  tasks: const [
    ArtworkTask(
      id: 't1',
      title: '色彩静物写生',
      subject: '色彩',
      teacherName: '李静',
      dueTime: '2026-11-16 18:00:00',
      status: 'PENDING',
    ),
    ArtworkTask(
      id: 't2',
      title: '速写动态十张',
      subject: '速写',
      teacherName: '王海波',
      dueTime: '2026-11-14 18:00:00',
      status: 'OVERDUE',
    ),
    ArtworkTask(
      id: 't3',
      title: '素描石膏头像',
      subject: '素描',
      dueTime: '2026-11-16 12:00:00',
      status: 'SUBMITTED',
    ),
  ],
  practices: buildTodayPractices(insights: _insights, snapshot: _study),
  latestReview: const TodayLatestReview(
    artworkId: 'aw-1006',
    title: '石膏头像结构练习',
    subject: '素描',
    score: 87,
    teacherName: '李静',
    comment: '结构交代清楚，暗部再整体一些',
    canRevise: true,
  ),
  study: _study,
  courses: const [
    _morning,
    TodayCourse(
      id: 'c2',
      start: '14:00',
      end: '17:00',
      subject: '色彩',
      teacherName: '王海波',
      room: '302 画室',
      isSmall: true,
      signStatus: 1,
    ),
  ],
);

TodaySnapshot _teacher({bool leader = false, int pending = 10}) =>
    TodaySnapshot(
      role: 'teacher',
      now: _now,
      isGroupLeader: leader,
      sources: 3,
      reviewStats: ArtworkStats(
        total: 263,
        reviewed: 263 - pending,
        pending: pending,
        overdue: pending > 0 ? 2 : 0,
      ),
      leadStats: leader ? (pending: 3, overdue: 0) : null,
      courses: const [_morning, _afternoonSmall],
      attention: const [
        TodayAttentionStudent(id: 's1', name: '刘语桐', reason: '近两次素描分数下滑'),
        TodayAttentionStudent(id: 's2', name: '罗沐阳', reason: '三天没有提交作品'),
      ],
    );

TodaySnapshot _headTeacher() => TodaySnapshot(
  role: 'headTeacher',
  now: _now,
  sources: 4,
  reviewStats: const ArtworkStats(total: 30, reviewed: 26, pending: 4),
  headTeacher: const HeadTeacherIndexRes(
    chatUnreadCount: 2,
    chatWaitingCount: 1,
    classList: [],
    pendingLeaveCount: 2,
    pendingMakeupCount: 1,
    todayAbnormalDormCount: 3,
    todoList: [],
    recentList: [],
  ),
);

TodaySnapshot _admin() => TodaySnapshot(
  role: 'admin',
  now: _now,
  sources: 3,
  admin: const AdminHomeSummary(
    studentCount: 40,
    teacherCount: 9,
    classCount: 4,
    leaveStatus0Count: 4,
    smallCourseSignStatus5Count: 1,
    userFaceNotRecordedCount: 5,
  ),
  scheduleApplies: 2,
  courses: [
    for (var i = 0; i < 8; i++)
      TodayCourse(
        id: 'sc$i',
        start: i < 3 ? '08:30' : (i < 6 ? '14:00' : '19:00'),
        end: i < 3 ? '09:30' : (i < 6 ? '17:00' : '21:00'),
        subject: const ['素描', '色彩', '速写'][i % 3],
        className: '联考冲刺${i + 1}班',
        teacherName: '李静',
      ),
  ],
);

TodaySnapshot _principal() => TodaySnapshot(
  role: 'principal',
  now: _now,
  sources: 5,
  admin: const AdminHomeSummary(leaveStatus0Count: 1),
  scheduleApplies: 0,
  mailboxPending: 3,
  principal: const TodayPrincipalOverview(
    overdueReviews: 8,
    overdueLeadReviews: 2,
    attentionCount: 20,
    studentPresent: 36,
    studentExpected: 38,
    teacherPresent: 5,
    teacherExpected: 6,
    alerts: [
      TodayPrincipalAlert(target: 'overdue', id: 't-2', text: '王海波 · 6份作品待点评'),
      TodayPrincipalAlert(target: 'attention', id: 'a-9', text: '刘语桐成绩连续下滑'),
    ],
  ),
  courses: const [_morning],
);

TodaySnapshot _dorm({int notChecked = 6}) => TodaySnapshot(
  role: 'dormManager',
  now: _now,
  sources: 3,
  dorm: const DormitoryIndexOverview(
    bedCount: 38,
    todayNormalCount: 30,
    todayLateCount: 2,
    todayAbsentCount: 1,
    pendingMakeupCount: 2,
    unclosedExceptionCount: 1,
    batchLabel: '11-16 晨查寝',
  ),
  dormCheck: TodayDormCheck(
    stat: DormitoryCheckStat(
      bedCount: 38,
      normalCount: 36 - notChecked,
      lateCount: 2,
      notCheckedCount: notChecked,
    ),
    checkType: '晚查寝',
    deadline: '22:30',
  ),
  dormConfig: const SchoolDormitoryCheckConfig(
    eveningDeadline: '22:30前',
    morningDeadline: '07:20前',
  ),
);

Future<List<RouteSettings>> _pumpToday(
  WidgetTester tester,
  TodaySnapshot snapshot, {
  Size content = const Size(950, 732),
}) async {
  tester.view.physicalSize = const Size(1180, 820);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final storage = AppStorage(await SharedPreferences.getInstance());
  final pushed = <RouteSettings>[];
  await tester.pumpWidget(
    ProviderScope(
      // 同一个测试里换一份数据重新加载页面时用新的容器。
      key: UniqueKey(),
      overrides: [
        appStorageProvider.overrideWithValue(storage),
        todayRoleProvider.overrideWith((ref) => snapshot.role),
        todaySnapshotProvider.overrideWith((ref) async => snapshot),
      ],
      child: MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name == '/') {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => Scaffold(
                backgroundColor: AppColors.page,
                body: Center(
                  child: SizedBox(
                    width: content.width,
                    height: content.height,
                    child: const TodayPage(),
                  ),
                ),
              ),
            );
          }
          pushed.add(settings);
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('目标页')),
          );
        },
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 300));
  return pushed;
}

void main() {
  setUpAll(() async {
    for (final font in {
      'Barlow': 'assets/fonts/Barlow-SemiBold.ttf',
      'Manrope': 'assets/fonts/Manrope Medium.ttf',
      'PingFang SC': 'assets/fonts/ttf/PingFangSC-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  test('role falls back to the demo token before /myInfo returns', () {
    expect(resolveTodayRole('teacher', token: ''), 'teacher');
    expect(
      resolveTodayRole(
        '',
        token: 'demo.dormManager.13809310004',
        demoMode: true,
      ),
      'dormManager',
    );
    // 教学组长的后端身份仍是任课老师。
    expect(
      resolveTodayRole(
        '',
        token: 'demo.groupLeader.13809310012',
        demoMode: true,
      ),
      'teacher',
    );
    expect(
      resolveTodayRole('', token: 'demo.principal.13809310006', demoMode: true),
      'principal',
    );
    expect(resolveTodayRole('', token: '', demoMode: true), '');
    expect(resolveTodayRole('', token: 'real-token', demoMode: false), '');
  });

  group('buildTodayPractices', () {
    test(
      'two frequent problems open their tools, the weak subject opens the gallery',
      () {
        final items = buildTodayPractices(
          insights: _insights,
          snapshot: _study,
        );
        expect(items, hasLength(3));
        expect(items[0].route, RoutePaths.artToolbox);
        expect(items[0].arguments, {'tool': ArtTool.mirror.key});
        expect(items[0].tag, '结构错误');
        expect(items[0].reason, startsWith('老师点评中出现 3 次'));
        expect(items[1].arguments, {'tool': ArtTool.quickSketch.key});
        expect(items[2].source, TodayPracticeSource.weakSubject);
        expect(items[2].route, RoutePaths.gallery);
        expect(items[2].arguments, {'subject': '色彩'});
        expect(items[2].reason, contains('色彩 85 分（B 档）'));
        expect(items[2].reason, endsWith('挑一张同类范画对照着练。'));
        for (final item in items.where(
          (i) => i.route == RoutePaths.artToolbox,
        )) {
          expect(
            ArtTool.tryParse('${item.arguments['tool']}')?.key,
            item.arguments['tool'],
          );
        }
      },
    );

    test('without exam data the weak subject comes from daily artworks', () {
      final items = buildTodayPractices(
        insights: const ArtworkInsights(weakestSubject: '色彩'),
      );
      expect(items.single.arguments, {'subject': '色彩'});
      expect(items.single.reason, contains('日常作品'));
    });

    test('with no data at all it suggests two basics', () {
      final items = buildTodayPractices();
      expect(items.map((i) => i.arguments['tool']), [
        ArtTool.valueOrder.key,
        ArtTool.figure.key,
      ]);
      expect(
        items.every((i) => i.source == TodayPracticeSource.basics),
        isTrue,
      );
    });

    test('suggestions without a tool open the gallery with a keyword', () {
      final items = buildTodayPractices(
        insights: const ArtworkInsights(
          suggestions: [
            ArtworkSuggestion(
              tag: '空间感弱',
              text: '拉开前后虚实。',
              gallerySubject: '色彩',
              galleryKeyword: '空间',
            ),
          ],
        ),
        snapshot: _study,
      );
      expect(items.first.arguments, {'subject': '色彩', 'keyword': '空间'});
      // 弱项科目与上一条同为色彩范画，不重复推荐。
      expect(items, hasLength(1));
    });
  });

  test(
    'latest review keeps the newest comment and only its first sentence',
    () {
      final review = TodayLatestReview.from(
        const ArtworkSummary(
          id: 'aw-1006',
          title: '石膏头像结构练习',
          subject: '素描',
          finalScore: 87,
        ),
        const ArtworkDetail(
          work: ArtworkSummary(id: 'aw-1006', title: '石膏头像结构练习'),
          reviews: [
            ArtworkReview(
              teacherId: 't-2',
              teacherName: '张明远',
              reviewed: true,
              score: 86,
              content: '暗部笔触偏平，反光和投影的层次可以再拉开。',
              reviewedTime: '2026-11-05 20:51:00',
            ),
            ArtworkReview(
              teacherId: 't-1',
              teacherName: '李静',
              reviewed: true,
              score: 88,
              content: '结构交代清楚，暗部再整体一些；五官位置略有偏差。',
              reviewedTime: '2026-11-06 09:10:00',
            ),
          ],
        ),
      );
      expect(review.teacherName, '李静');
      expect(review.comment, '结构交代清楚，暗部再整体一些');
      expect(review.score, 87);
      expect(todayCommentLine('只有一句'), '只有一句');
    },
  );

  group('TodayCourse', () {
    test('parses grouped rows of one day in time order', () {
      final courses = parseTodayCourses({
        '2026-11-16': [
          {
            'id': 'b',
            'date': '2026-11-16',
            'timeBegin': '14:00:00',
            'timeEnd': '17:00:00',
            'subjectName': '色彩',
            'className': '联考冲刺1班',
            'classroomName': '302 画室',
            'teacherRealname': '王海波',
            'type': 1,
            'signStatus': 2,
          },
          {
            'id': 'a',
            'date': '2026-11-16',
            'timeBegin': '08:30',
            'timeEnd': '11:30',
            'courseName': '素描',
            'type': 0,
          },
          {'id': 'broken'},
        ],
        '2026-11-17': [
          {'id': 'c', 'timeBegin': '08:30', 'subjectName': '速写'},
        ],
      }, '2026-11-16');
      expect(courses.map((c) => c.id), ['a', 'b']);
      expect(courses.first.subject, '素描');
      expect(courses.last.isSmall, isTrue);
      expect(courses.last.room, '302 画室');
      expect(courses.last.teacherName, '王海波');
      expect(parseTodayCourses(null, '2026-11-16'), isEmpty);
    });

    test(
      'a teacher signs in after class starts and signs small classes out',
      () {
        expect(_morning.phaseAt(_now), TodayCoursePhase.inProgress);
        expect(_morning.teacherSignAction(_now), '上课签到');
        // 还没上课的课不算待办。
        expect(_afternoonSmall.phaseAt(_now), TodayCoursePhase.upcoming);
        expect(_afternoonSmall.teacherSignAction(_now), '');

        const signedIn = TodayCourse(
          id: 'c',
          start: '08:30',
          end: '09:30',
          subject: '速写',
          isSmall: true,
          signStatus: 2,
        );
        expect(signedIn.phaseAt(_now), TodayCoursePhase.ended);
        expect(signedIn.teacherSignAction(_now), '下课签退');
        const done = TodayCourse(
          id: 'd',
          start: '08:30',
          end: '09:30',
          subject: '速写',
          signStatus: 2,
        );
        expect(done.teacherSignAction(_now), '');
      },
    );

    test('a student only acts on small classes', () {
      expect(_morning.studentSignAction(), '');
      TodayCourse small(int status) => TodayCourse(
        id: 's',
        start: '14:00',
        end: '17:00',
        subject: '色彩',
        isSmall: true,
        signStatus: status,
      );
      expect(small(0).studentSignAction(), '');
      expect(small(1).studentSignAction(), '上课签到');
      expect(small(3).studentSignAction(), '下课签退');
      expect(small(4).studentSignAction(), '课后评价');
      expect(small(5).studentSignAction(), '');
    });
  });

  group('buildTodayBoard', () {
    test('student: overdue first, then today, submitted work last', () {
      final board = buildTodayBoard(_student());
      expect(board.tasks.map((t) => t.title), [
        '速写动态十张',
        '小课上课签到',
        '色彩静物写生',
        '素描石膏头像',
      ]);
      expect(board.tasks.first.tag, '已超时');
      expect(board.tasks.first.level, TodayLevel.urgent);
      expect(board.tasks[1].actionLabel, '去签到');
      expect(board.tasks[1].target, isA<TodayCampusTarget>());
      expect(board.tasks[2].tag, '今日截止');
      expect(board.tasks[2].detail, contains('今天 18:00 截止'));
      final upload = board.tasks[2].target as TodayUploadTarget;
      expect(upload.taskId, 't1');
      expect(board.tasks.last.pending, isFalse);
      expect(board.tasks.last.level, TodayLevel.done);
      expect(board.pendingCount, 3);
      expect(board.summary, '有 3 项待处理，今天 2 节课');
      expect(board.practices, hasLength(3));
      expect(board.latestReview?.canRevise, isTrue);
      expect(board.agenda.map((a) => a.time), ['08:30', '14:00']);
      expect(board.agenda.last.tag, '小课');
      expect(board.agenda.last.note, '待签到');
      expect(board.signals.map((s) => s.label), [
        '2026 年 9 月月考',
        '需要加强的科目',
        '下一次月考',
      ]);
      expect(board.signals.first.value, '265.5');
      expect(board.signals.first.caption, '第 7 名 / 38 人 · 较上次 +9 分');
      expect(board.signals[1].value, '色彩');
      expect(board.shortcuts.map((s) => s.label), contains('我的笔记'));
      expect(board.notesTitle, isEmpty);
    });

    test('student with many tasks lists four and counts the rest', () {
      final board = buildTodayBoard(
        TodaySnapshot(
          role: 'student',
          now: _now,
          tasks: [
            for (var i = 0; i < 6; i++)
              ArtworkTask(
                id: 'm$i',
                title: '作品 $i',
                subject: '素描',
                dueTime: '2026-11-1${7 + (i % 3)} 18:00:00',
                status: 'PENDING',
              ),
          ],
        ),
      );
      expect(board.tasks, hasLength(4));
      expect(board.moreTasks, 2);
      expect(board.pendingCount, 6);
      expect(board.tasks.first.detail, contains('11月17日截止'));
      expect(board.summary, '有 6 项待处理，今天没有排课');
    });

    test('student with nothing due gets a calm empty state', () {
      final board = buildTodayBoard(TodaySnapshot(role: 'student', now: _now));
      expect(board.tasks, isEmpty);
      expect(board.pendingCount, 0);
      expect(board.taskEmptyTitle, '今天没有要交的作品');
      expect(board.summary, '暂时没有待处理的事项，今天没有排课');
    });

    test('teacher: overdue reviews lead, classes in session need signing', () {
      final board = buildTodayBoard(_teacher());
      expect(board.tasks.map((t) => t.title), ['待点评作品', '课堂签课']);
      final reviews = board.tasks.first;
      expect(reviews.count, 10);
      expect(reviews.tag, '超时 2 件');
      expect(reviews.level, TodayLevel.urgent);
      expect(reviews.actionLabel, '开始点评');
      final route = reviews.target as TodayRouteTarget;
      expect(route.route, RoutePaths.artworks);
      expect(route.arguments, {'startReview': true});
      expect(board.tasks.last.count, 1);
      expect(board.tasks.last.detail, '08:30 素描 · 联考冲刺1班 · 待上课签到');
      expect(board.pendingCount, 2);
      expect(board.summary, '有 2 项待处理，今天 2 节课');
      expect(board.agenda.first.note, '待签课');
      expect(board.agenda.last.note, isEmpty);
      expect(board.notesTitle, '需要关注的学生');
      expect(board.notes.map((n) => n.title), ['刘语桐', '罗沐阳']);
      final report = board.notes.first.target as TodayReportTarget;
      expect(report.report, TeachingReport.myAttention);
      expect(report.parameter, 's1');
      expect(board.shortcuts.map((s) => s.label), [
        '我的学生',
        '我的履职',
        '授课课表',
        '我的请假',
      ]);
    });

    test('group leader also gets the review pool and group reports', () {
      final board = buildTodayBoard(_teacher(leader: true));
      expect(board.tasks.map((t) => t.title), ['待点评作品', '待复核作品', '课堂签课']);
      final lead = board.tasks[1];
      expect(lead.count, 3);
      expect((lead.target as TodayRouteTarget).route, RoutePaths.leadReviews);
      expect(
        board.shortcuts.map((s) => s.label),
        containsAll(['本组老师', '本组学情']),
      );
    });

    test('teacher with every artwork reviewed has nothing pending', () {
      final board = buildTodayBoard(
        TodaySnapshot(
          role: 'teacher',
          now: _now,
          reviewStats: const ArtworkStats(total: 20, reviewed: 20),
        ),
      );
      expect(board.tasks.single.title, '作品已全部点评');
      expect(board.tasks.single.pending, isFalse);
      expect(board.pendingCount, 0);
      expect(board.summary, '暂时没有待处理的事项，今天没有排课');
    });

    test('head teacher: reviews, leave, punch audits, dorm and parents', () {
      final board = buildTodayBoard(_headTeacher());
      expect(board.tasks.map((t) => t.title), [
        '待点评作品',
        '学生请假待审批',
        '查寝补卡待审核',
        '查寝异常',
        '家长消息待回复',
      ]);
      expect(board.tasks.map((t) => t.count), [4, 2, 1, 3, 1]);
      expect(
        (board.tasks[1].target as TodayCampusTarget).entry,
        CampusEntry.leaveApproval,
      );
      expect(
        (board.tasks[2].target as TodayCampusTarget).entry,
        CampusEntry.dormPunchAudit,
      );
      expect(board.pendingCount, 5);
      expect(board.shortcuts.first.label, '班级工作台');
    });

    test('admin: approvals, the school timetable and management entries', () {
      final board = buildTodayBoard(_admin());
      expect(board.tasks.map((t) => t.title), [
        '教职工请假待审批',
        '小课签课待确认',
        '小课申请待审核',
      ]);
      expect(board.pendingCount, 3);
      expect(board.agendaTitle, '全校今日课程');
      expect(board.agendaTotal, 8);
      expect(board.agenda, hasLength(6));
      // 上午九点半下课的三节已结束，排在还没结束的课后面。
      expect(board.agenda.first.time, '14:00');
      expect(board.agenda.last.phase, TodayCoursePhase.ended);
      expect(board.summary, '有 3 项待处理，全校今天 8 节课');
      expect(board.signals.map((s) => '${s.label}${s.value}'), [
        '在读学生40',
        '教职工9',
        '未录人脸5',
      ]);
      expect(board.signals.last.level, TodayLevel.attention);
      expect(
        board.shortcuts.map((s) => s.label),
        containsAll(['学生管理', '教师管理', '班级管理', '排课与课表', '通知管理', '人脸库']),
      );
    });

    test(
      'principal: overdue supervision first, then mailbox and approvals',
      () {
        final board = buildTodayBoard(_principal());
        expect(board.tasks.map((t) => t.title), [
          '老师点评超时',
          '组长复核超时',
          '校长信箱待回复',
          '教职工请假待审批',
        ]);
        final overdue = board.tasks.first.target as TodayReportTarget;
        expect(overdue.report, TeachingReport.reviewChain);
        expect(overdue.parameter, 'filter=overdue');
        expect(board.pendingCount, 4);
        expect(board.signalsTitle, '在校情况');
        expect(board.signals.map((s) => s.value), ['36 / 38', '5 / 6', '20']);
        expect(board.notesTitle, '教学跟进');
        expect(board.notes.map((n) => n.title), ['王海波 · 6份作品待点评', '刘语桐成绩连续下滑']);
        final chain = board.notes.first.target as TodayReportTarget;
        expect(chain.parameter, 'filter=overdue&teacherId=t-2');
        final attention = board.notes.last.target as TodayReportTarget;
        expect(attention.report, TeachingReport.attention);
        expect(attention.parameter, 'a-9');
      },
    );

    test('dorm manager: the current check, audits and duty times', () {
      final board = buildTodayBoard(_dorm());
      expect(board.tasks.map((t) => t.title), [
        '晚查寝未打卡',
        '补卡待审核',
        '查寝异常未处理',
        '到岗打卡',
      ]);
      expect(board.tasks.first.count, 6);
      expect(board.tasks.first.detail, '应到 38 人，已打卡 32 人 · 规定时间 22:30');
      expect(board.tasks.first.actionLabel, '按宿舍查寝');
      // 到岗打卡没有状态接口，只是入口，不计入待处理。
      expect(board.tasks.last.pending, isFalse);
      expect(board.tasks.last.count, isNull);
      expect(board.pendingCount, 3);
      expect(board.summary, '有 3 项待处理');
      expect(board.agendaTitle, '今日值班');
      expect(board.agenda.map((a) => '${a.time}${a.title}'), [
        '07:20早查寝',
        '22:30晚查寝',
      ]);
      expect(board.agenda.first.phase, TodayCoursePhase.ended);
      expect(board.agenda.last.phase, TodayCoursePhase.upcoming);
      expect(board.signalsTitle, '查寝情况 · 11-16 晨查寝');
      expect(board.signals.map((s) => s.value), ['30', '2', '1']);
      expect(board.signals.last.level, TodayLevel.urgent);

      final cleared = buildTodayBoard(_dorm(notChecked: 0));
      expect(cleared.tasks.map((t) => t.title), contains('晚查寝已全部打卡'));
      expect(cleared.pendingCount, 2);
    });

    test('copy has no banned wording', () {
      final banned = RegExp(
        r'最好|最佳|最优|最强|最大|最全|最快|唯一|首选|顶级|独家|保证|绝对|永久|万能|'
        r'保过|包过|必过|提分|涨分|上岸|逆袭|升学率|录取率|\bAI\b|人工智能|智能评分|自动评分|'
        r'第一(?!次|场|眼|步|张|位|天|个|批|份|轮|遍|笔|课|道|站|页|印象)|[!！]',
      );
      for (final snapshot in [
        _student(),
        _teacher(leader: true),
        _headTeacher(),
        _admin(),
        _principal(),
        _dorm(),
        _dorm(notChecked: 0),
        TodaySnapshot(role: 'student', now: _now),
      ]) {
        final board = buildTodayBoard(snapshot);
        final text = [
          board.summary,
          board.taskEmptyTitle,
          board.taskEmptyHint,
          board.agendaTitle,
          board.agendaEmpty,
          board.signalsTitle,
          board.notesTitle,
          board.notesEmpty,
          for (final t in board.tasks)
            '${t.title}${t.detail}${t.tag}${t.actionLabel}',
          for (final s in board.signals) '${s.label}${s.caption}',
          for (final s in board.shortcuts) s.label,
        ].join('\n');
        expect(banned.hasMatch(text), isFalse, reason: text);
      }
    });
  });

  group('TodayPage', () {
    // 1180 × 820 与 1024 × 768 两种横屏下的内容区。
    for (final content in [const Size(950, 732), const Size(794, 680)]) {
      testWidgets('student page at $content', (tester) async {
        await _pumpToday(tester, _student(), content: content);
        expect(tester.takeException(), isNull);
        expect(find.text('待处理'), findsOneWidget);
        expect(find.text('3 项'), findsOneWidget);
        expect(find.text('速写动态十张'), findsOneWidget);
        expect(find.text('已超时'), findsOneWidget);
        expect(find.text('今日截止'), findsOneWidget);
        expect(find.text('去提交'), findsNWidgets(2));
        expect(find.text('今日练习'), findsOneWidget);
        expect(find.text('镜像翻转'), findsOneWidget);
        expect(find.text('今日课程'), findsOneWidget);
        expect(find.text('待签到'), findsOneWidget);
        expect(find.text('最近点评'), findsOneWidget);
        expect(find.text('按点评改画重交'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('我的笔记'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('学习情况'), findsOneWidget);
        expect(find.text('常用'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('teacher page at $content', (tester) async {
        final pushed = await _pumpToday(
          tester,
          _teacher(leader: true),
          content: content,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('待点评作品'), findsOneWidget);
        expect(find.text('超时 2 件'), findsOneWidget);
        expect(find.text('待复核作品'), findsOneWidget);
        expect(find.text('课堂签课'), findsOneWidget);
        expect(find.text('今日课程'), findsOneWidget);
        expect(find.text('进行中'), findsNothing);
        expect(find.text('待签课'), findsOneWidget);
        expect(find.text('需要关注的学生'), findsOneWidget);
        expect(find.text('刘语桐'), findsOneWidget);
        // 学生的卡片不出现在老师的页面上。
        expect(find.text('今日练习'), findsNothing);
        expect(find.text('最近点评'), findsNothing);

        await tester.tap(find.text('开始点评'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(pushed.single.name, RoutePaths.artworks);
        expect(pushed.single.arguments, {'startReview': true});
      });
    }

    testWidgets('only the most urgent row uses the primary button', (
      tester,
    ) async {
      await _pumpToday(tester, _headTeacher());
      final buttons = tester.widgetList<AppButton>(find.byType(AppButton));
      expect(
        buttons.where((b) => b.variant == AppButtonVariant.primary),
        hasLength(1),
      );
      expect(
        buttons.firstWhere((b) => b.variant == AppButtonVariant.primary).label,
        '开始点评',
      );
      expect(tester.takeException(), isNull);
    });

    for (final entry in <String, TodaySnapshot Function()>{
      'admin': _admin,
      'principal': _principal,
      'dormManager': _dorm,
    }.entries) {
      testWidgets('${entry.key} page fits both landscape sizes', (
        tester,
      ) async {
        for (final content in [const Size(950, 732), const Size(794, 680)]) {
          await _pumpToday(tester, entry.value(), content: content);
          expect(tester.takeException(), isNull, reason: '$content');
          expect(find.text('待处理'), findsOneWidget);
          expect(find.text('今日练习'), findsNothing);
        }
        switch (entry.key) {
          case 'admin':
            expect(find.text('全校今日课程'), findsOneWidget);
            expect(find.text('还有 2 节，查看全部课表'), findsOneWidget);
            expect(find.text('画室概况'), findsOneWidget);
          case 'principal':
            expect(find.text('老师点评超时'), findsOneWidget);
            expect(find.text('需要督办'), findsNWidgets(2));
            expect(find.text('在校情况'), findsOneWidget);
            expect(find.text('教学跟进'), findsOneWidget);
          case 'dormManager':
            expect(find.text('晚查寝未打卡'), findsOneWidget);
            expect(find.text('按宿舍查寝'), findsOneWidget);
            expect(find.text('今日值班'), findsOneWidget);
            expect(find.text('排课'), findsNothing);
        }
      });
    }

    testWidgets('nothing pending shows the calm empty state', (tester) async {
      await _pumpToday(tester, TodaySnapshot(role: 'student', now: _now));
      expect(tester.takeException(), isNull);
      expect(find.text('今天没有要交的作品'), findsOneWidget);
      expect(find.text('今天没有排课'), findsOneWidget);
      expect(find.textContaining('暂时没有待处理的事项'), findsOneWidget);
    });

    testWidgets('a partial failure keeps the page and offers a retry', (
      tester,
    ) async {
      await _pumpToday(
        tester,
        TodaySnapshot(
          role: 'teacher',
          now: _now,
          sources: 3,
          failedSources: 1,
          reviewStats: const ArtworkStats(total: 5, reviewed: 3, pending: 2),
        ),
      );
      expect(find.textContaining('有 1 项内容暂时没有取到'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(find.text('待点评作品'), findsOneWidget);

      await _pumpToday(
        tester,
        TodaySnapshot(role: 'teacher', now: _now, sources: 3, failedSources: 3),
      );
      expect(find.text('今日内容加载失败'), findsOneWidget);
      expect(find.text('待处理'), findsNothing);
    });
  });
}
