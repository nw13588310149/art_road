import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData, Icons;

import '../../../app/router/route_paths.dart';
import '../../../core/art/art_tokens.dart';
import '../../artworks/data/artwork_models.dart';
import '../../smart_campus/state/campus_entry.dart';
import '../../teaching_overview/data/teaching_overview_repository.dart';
import '../data/today_models.dart';
import '../data/today_practice.dart';
import '../data/today_repository.dart' show todayTaskClock;

/// 一件事的轻重：超时、需要处理、普通、已完成。决定排序与标签颜色。
enum TodayLevel { urgent, attention, normal, done }

/// 点开一行后去哪里。
@immutable
sealed class TodayTarget {
  const TodayTarget();
}

/// 打开一个页面。
class TodayRouteTarget extends TodayTarget {
  const TodayRouteTarget(this.route, [this.arguments]);

  final String route;
  final Map<String, dynamic>? arguments;
}

/// 打开智慧校园里的一个视图。
class TodayCampusTarget extends TodayTarget {
  const TodayCampusTarget(this.entry);

  final CampusEntry entry;
}

/// 打开一份教学报表。
class TodayReportTarget extends TodayTarget {
  const TodayReportTarget(this.report, {this.parameter = '', this.campus = ''});

  final TeachingReport report;
  final String parameter;
  final String campus;
}

/// 打开上传作品的弹窗：交一份老师布置的作品（[taskId]），或按点评改画重交
/// （[parentId]）。
class TodayUploadTarget extends TodayTarget {
  const TodayUploadTarget({
    this.taskId = '',
    this.parentId = '',
    required this.title,
    required this.subject,
  });

  final String taskId;
  final String parentId;
  final String title;
  final String subject;
}

/// 打开本人的课表（管理员与校长打开排课与课表）。
class TodayScheduleTarget extends TodayTarget {
  const TodayScheduleTarget();
}

/// 「待处理」里的一行：一件事、一个数字、一个直达的操作。
@immutable
class TodayTask {
  const TodayTask({
    required this.id,
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.target,
    this.detail = '',
    this.count,
    this.unit = '',
    this.tag = '',
    this.subject = '',
    this.level = TodayLevel.attention,
    this.pending = true,
  });

  final String id;
  final IconData icon;
  final String title;
  final String detail;

  /// 右侧的数量（如 10 件）；为空时不显示数字。
  final int? count;
  final String unit;

  /// 标题旁的提醒（如「超时 2 件」「今日截止」）。
  final String tag;

  /// 所属科目，决定图标颜色；为空时按 [level] 取色。
  final String subject;
  final TodayLevel level;

  /// 需要本人处理，计入导航角标。已完成的行和只是入口的行为 false。
  final bool pending;
  final String actionLabel;
  final TodayTarget target;
}

/// 「今日日程」里的一行。
@immutable
class TodayAgendaItem {
  const TodayAgendaItem({
    required this.time,
    required this.title,
    required this.phase,
    this.endTime = '',
    this.subtitle = '',
    this.tag = '',
    this.note = '',
    this.target = const TodayScheduleTarget(),
  });

  /// `HH:mm`。
  final String time;
  final String endTime;
  final String title;
  final String subtitle;

  /// 「小课」这类标签。
  final String tag;

  /// 这一行现在要做的事（如「待签课」），为空时显示课程进行状态。
  final String note;
  final TodayCoursePhase phase;
  final TodayTarget target;
}

/// 「值得关注」里的一格：一个数字和一句依据，点开看详情。
@immutable
class TodaySignal {
  const TodaySignal({
    required this.label,
    required this.value,
    required this.target,
    this.unit = '',
    this.caption = '',
    this.level = TodayLevel.normal,
  });

  final String label;
  final String value;
  final String unit;
  final String caption;
  final TodayLevel level;
  final TodayTarget target;
}

/// 需要跟进的一条文字提醒（学生姓名与原因、教学跟进事项）。
@immutable
class TodayNote {
  const TodayNote({
    required this.title,
    required this.target,
    this.detail = '',
  });

  final String title;
  final String detail;
  final TodayTarget target;
}

/// 页面底部的常用入口。
@immutable
class TodayShortcut {
  const TodayShortcut(this.label, this.icon, this.target);

  final String label;
  final IconData icon;
  final TodayTarget target;
}

/// 一个身份当天的看板。所有身份同一个骨架：待处理、今日日程、值得关注、常用。
@immutable
class TodayBoard {
  const TodayBoard({
    required this.role,
    this.tasks = const <TodayTask>[],
    this.moreTasks = 0,
    this.moreTasksTarget,
    this.taskEmptyTitle = '今天没有待处理的事项',
    this.taskEmptyHint = '',
    this.practices = const <TodayPractice>[],
    this.latestReview,
    this.agendaTitle = '今日课程',
    this.agenda = const <TodayAgendaItem>[],
    this.agendaTotal = 0,
    this.agendaEmpty = '今天没有排课',
    this.signalsTitle = '值得关注',
    this.signals = const <TodaySignal>[],
    this.notesTitle = '',
    this.notes = const <TodayNote>[],
    this.notesEmpty = '',
    this.shortcuts = const <TodayShortcut>[],
  });

  final String role;

  /// 待处理的行在前（按轻重排序），已完成的行在后。
  final List<TodayTask> tasks;

  /// 没有列出来的待处理事项数，以及查看全部的去处。
  final int moreTasks;
  final TodayTarget? moreTasksTarget;
  final String taskEmptyTitle;
  final String taskEmptyHint;

  /// 学生：今日练习与最近点评。
  final List<TodayPractice> practices;
  final TodayLatestReview? latestReview;

  final String agendaTitle;
  final List<TodayAgendaItem> agenda;

  /// 今天一共有几节课（[agenda] 只列出一部分时大于它的长度）。
  final int agendaTotal;
  final String agendaEmpty;

  final String signalsTitle;
  final List<TodaySignal> signals;

  final String notesTitle;
  final List<TodayNote> notes;
  final String notesEmpty;

  final List<TodayShortcut> shortcuts;

  bool get isStudent => role == 'student';

  /// 需要本人处理的事项数：导航角标与页头小结都用它。
  int get pendingCount =>
      tasks.where((task) => task.pending).length + moreTasks;

  /// 页头的一句小结。
  String get summary {
    final pending = pendingCount;
    final lessons = agendaTotal;
    final agendaPart = switch (role) {
      'dormManager' => '',
      'admin' || 'principal' => lessons > 0 ? '全校今天 $lessons 节课' : '',
      _ => lessons > 0 ? '今天 $lessons 节课' : '今天没有排课',
    };
    final taskPart = pending > 0 ? '有 $pending 项待处理' : '暂时没有待处理的事项';
    return agendaPart.isEmpty ? taskPart : '$taskPart，$agendaPart';
  }
}

/// 页头问候语：按时间段。
String todayGreeting(DateTime now) {
  final hour = now.hour;
  if (hour < 5) return '夜深了';
  if (hour < 11) return '早上好';
  if (hour < 13) return '中午好';
  if (hour < 18) return '下午好';
  return '晚上好';
}

const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/// 页头日期：11月16日 周一。
String todayDateLabel(DateTime now) =>
    '${now.month}月${now.day}日 ${_weekdays[now.weekday - 1]}';

/// 按身份把原始数据整理成看板。
TodayBoard buildTodayBoard(TodaySnapshot snapshot) => switch (snapshot.role) {
  'student' => _student(snapshot),
  'teacher' => _teacher(snapshot),
  'headTeacher' => _headTeacher(snapshot),
  'admin' => _admin(snapshot),
  'principal' => _principal(snapshot),
  'dormManager' => _dormManager(snapshot),
  _ => TodayBoard(role: snapshot.role),
};

// ───────────────────────── 学生 ─────────────────────────

const _maxStudentTasks = 4;

TodayBoard _student(TodaySnapshot s) {
  final day = _date(todayTaskClock(s.now));
  final open = [
    for (final task in s.tasks)
      if (task.status == 'PENDING' || task.status == 'OVERDUE') task,
  ]..sort((a, b) => a.dueTime.compareTo(b.dueTime));
  final signs = [
    for (final course in s.courses)
      if (course.studentSignAction().isNotEmpty) course,
  ];
  final rows = _sorted(<TodayTask>[
    for (final course in signs)
      TodayTask(
        id: 'sign:${course.id}',
        icon: Icons.how_to_reg_outlined,
        title: '小课${course.studentSignAction()}',
        detail: _join([
          _range(course.start, course.end),
          course.subject,
          course.teacherName,
        ]),
        subject: course.subject,
        actionLabel: '去${course.studentSignAction().substring(2)}',
        target: const TodayCampusTarget(CampusEntry.checkIn),
      ),
    for (final task in open)
      TodayTask(
        id: 'task:${task.id}',
        icon: Icons.brush_outlined,
        title: task.title,
        detail: _join([
          task.subject,
          if (task.teacherName.isNotEmpty) '${task.teacherName}布置',
          _dueLabel(task.dueTime, day),
        ]),
        tag: task.status == 'OVERDUE'
            ? '已超时'
            : (task.dueTime.startsWith(day) ? '今日截止' : ''),
        level: task.status == 'OVERDUE'
            ? TodayLevel.urgent
            : (task.dueTime.startsWith(day)
                  ? TodayLevel.attention
                  : TodayLevel.normal),
        subject: task.subject,
        actionLabel: '去提交',
        target: TodayUploadTarget(
          taskId: task.id,
          title: task.title,
          subject: task.subject,
        ),
      ),
  ]);
  final shown = rows.take(_maxStudentTasks).toList();
  final done = [
    for (final task in s.tasks)
      if (task.dueTime.startsWith(day) &&
          (task.status == 'SUBMITTED' || task.status == 'REVIEWED'))
        TodayTask(
          id: 'task:${task.id}',
          icon: Icons.brush_outlined,
          title: task.title,
          detail: task.status == 'REVIEWED' ? '老师已点评' : '已提交，等待老师点评',
          subject: task.subject,
          level: TodayLevel.done,
          pending: false,
          actionLabel: '查看',
          target: const TodayRouteTarget(RoutePaths.artworks),
        ),
  ];

  final study = s.study;
  final weak = todayWeakSubject(snapshot: study);
  return TodayBoard(
    role: s.role,
    tasks: [...shown, ...done.take(2)],
    moreTasks: rows.length - shown.length,
    moreTasksTarget: const TodayCampusTarget(CampusEntry.myHomework),
    taskEmptyTitle: '今天没有要交的作品',
    taskEmptyHint: '可以按下面的练习建议画一张，或者上传一份日常作品请老师点评。',
    practices: s.practices,
    latestReview: s.latestReview,
    agenda: [
      for (final course in s.courses)
        TodayAgendaItem(
          time: course.start,
          endTime: course.end,
          title: course.subject,
          subtitle: _join([course.teacherName, course.room]),
          tag: course.isSmall ? '小课' : '',
          note: course.studentSignAction().isEmpty
              ? ''
              : '待${course.studentSignAction().substring(2)}',
          phase: course.phaseAt(s.now),
        ),
    ],
    agendaTotal: s.courses.length,
    signalsTitle: '学习情况',
    signals: [
      if (study != null && study.totalScore != null)
        TodaySignal(
          label: study.examName.isEmpty ? '最近一次月考' : study.examName,
          value: formatScore(study.totalScore),
          unit: '分',
          caption: _join([
            if (study.ranking != null)
              study.participants == null
                  ? '第 ${study.ranking} 名'
                  : '第 ${study.ranking} 名 / ${study.participants} 人',
            if (study.scoreChange != null && study.scoreChange != 0)
              '较上次 ${_signed(study.scoreChange!)} 分',
          ]),
          target: const TodayRouteTarget(RoutePaths.studyCenter),
        ),
      if (weak != null)
        TodaySignal(
          label: '需要加强的科目',
          value: weak.subject,
          caption: '三科里分数最低，看看老师点评里的具体问题',
          level: TodayLevel.attention,
          target: const TodayRouteTarget(
            RoutePaths.studyCenter,
            <String, dynamic>{'view': 'artworkGrowth'},
          ),
        ),
      if (study?.nextExamDays != null)
        TodaySignal(
          label: '下一次月考',
          value: '${study!.nextExamDays}',
          unit: '天后',
          caption: '按考试时间安排练习',
          target: const TodayRouteTarget(RoutePaths.studyCenter),
        ),
    ],
    shortcuts: const [
      TodayShortcut(
        '我的课表',
        Icons.calendar_month_outlined,
        TodayScheduleTarget(),
      ),
      TodayShortcut(
        '上传作品',
        Icons.add_photo_alternate_outlined,
        TodayRouteTarget(RoutePaths.artworks),
      ),
      TodayShortcut(
        '请假',
        Icons.event_busy_outlined,
        TodayCampusTarget(CampusEntry.studentLeave),
      ),
      TodayShortcut(
        '我的笔记',
        Icons.sticky_note_2_outlined,
        TodayRouteTarget(RoutePaths.myNotes),
      ),
      TodayShortcut(
        '我的收藏',
        Icons.favorite_border_rounded,
        TodayRouteTarget(RoutePaths.myCollection),
      ),
    ],
  );
}

// ───────────────────────── 任课老师、班主任 ─────────────────────────

/// 作品点评：有待点评时是一件要做的事，全部点评完时是一行已完成。
List<TodayTask> _reviewTasks(ArtworkStats? stats) {
  if (stats == null) return const <TodayTask>[];
  if (stats.pending > 0) {
    return [
      TodayTask(
        id: 'reviews',
        icon: Icons.rate_review_outlined,
        title: '待点评作品',
        detail: '已点评 ${stats.reviewed} 件，共 ${stats.total} 件',
        count: stats.pending,
        unit: '件',
        tag: stats.overdue > 0 ? '超时 ${stats.overdue} 件' : '',
        level: stats.overdue > 0 ? TodayLevel.urgent : TodayLevel.attention,
        actionLabel: '开始点评',
        target: const TodayRouteTarget(RoutePaths.artworks, <String, dynamic>{
          'startReview': true,
        }),
      ),
    ];
  }
  if (stats.total == 0) return const <TodayTask>[];
  return [
    TodayTask(
      id: 'reviews',
      icon: Icons.rate_review_outlined,
      title: '作品已全部点评',
      detail: '共 ${stats.total} 件',
      level: TodayLevel.done,
      pending: false,
      actionLabel: '查看',
      target: const TodayRouteTarget(RoutePaths.artworks),
    ),
  ];
}

/// 课堂签课：已经上课、还没有签课的课。
List<TodayTask> _signTasks(TodaySnapshot s) {
  final due = [
    for (final course in s.courses)
      if (course.teacherSignAction(s.now).isNotEmpty) course,
  ];
  if (due.isEmpty) return const <TodayTask>[];
  final first = due.first;
  return [
    TodayTask(
      id: 'sign',
      icon: Icons.how_to_reg_outlined,
      title: '课堂签课',
      detail: _join([
        '${first.start} ${first.subject}',
        first.className,
        '待${first.teacherSignAction(s.now)}',
      ]),
      count: due.length,
      unit: '节',
      actionLabel: '去签课',
      target: const TodayCampusTarget(CampusEntry.classAttendance),
    ),
  ];
}

List<TodayAgendaItem> _teachingAgenda(TodaySnapshot s) => [
  for (final course in s.courses)
    TodayAgendaItem(
      time: course.start,
      endTime: course.end,
      title: course.subject,
      subtitle: _join([course.className, course.room]),
      tag: course.isSmall ? '小课' : '',
      note: course.teacherSignAction(s.now).isEmpty ? '' : '待签课',
      phase: course.phaseAt(s.now),
    ),
];

List<TodayNote> _attentionNotes(TodaySnapshot s) => [
  for (final student in s.attention)
    TodayNote(
      title: student.name,
      detail: student.reason,
      target: TodayReportTarget(
        TeachingReport.myAttention,
        parameter: student.id,
      ),
    ),
];

TodayBoard _teacher(TodaySnapshot s) {
  final lead = s.leadStats;
  final tasks = <TodayTask>[
    ..._reviewTasks(s.reviewStats),
    if (lead != null && lead.pending > 0)
      TodayTask(
        id: 'lead',
        icon: Icons.fact_check_outlined,
        title: '待复核作品',
        detail: '本组老师点评完成后由组长复核',
        count: lead.pending,
        unit: '份',
        tag: lead.overdue > 0 ? '超时 ${lead.overdue} 份' : '',
        level: lead.overdue > 0 ? TodayLevel.urgent : TodayLevel.attention,
        actionLabel: '去复核',
        target: const TodayRouteTarget(RoutePaths.leadReviews),
      ),
    ..._signTasks(s),
  ];
  return TodayBoard(
    role: s.role,
    tasks: _sorted(tasks),
    taskEmptyHint: '作品已点评完，课也都签了。',
    agenda: _teachingAgenda(s),
    agendaTotal: s.courses.length,
    notesTitle: '需要关注的学生',
    notes: _attentionNotes(s),
    notesEmpty: '暂时没有需要关注的学生',
    shortcuts: [
      const TodayShortcut(
        '我的学生',
        Icons.groups_outlined,
        TodayReportTarget(TeachingReport.myStudents),
      ),
      const TodayShortcut(
        '我的履职',
        Icons.insights_outlined,
        TodayReportTarget(TeachingReport.myPerformance),
      ),
      const TodayShortcut(
        '授课课表',
        Icons.calendar_month_outlined,
        TodayScheduleTarget(),
      ),
      if (s.isGroupLeader) ...const [
        TodayShortcut(
          '本组老师',
          Icons.badge_outlined,
          TodayReportTarget(TeachingReport.groupTeachers),
        ),
        TodayShortcut(
          '本组学情',
          Icons.show_chart_rounded,
          TodayReportTarget(TeachingReport.groupClasses),
        ),
      ] else
        const TodayShortcut(
          '我的请假',
          Icons.event_busy_outlined,
          TodayCampusTarget(CampusEntry.myLeave),
        ),
    ],
  );
}

TodayBoard _headTeacher(TodaySnapshot s) {
  final index = s.headTeacher;
  final tasks = <TodayTask>[
    ..._reviewTasks(s.reviewStats),
    if (index != null && index.pendingLeaveCount > 0)
      TodayTask(
        id: 'leave',
        icon: Icons.event_busy_outlined,
        title: '学生请假待审批',
        detail: '家长已确认，等待班主任审批',
        count: index.pendingLeaveCount,
        unit: '条',
        actionLabel: '去审批',
        target: const TodayCampusTarget(CampusEntry.leaveApproval),
      ),
    if (index != null && index.pendingMakeupCount > 0)
      TodayTask(
        id: 'makeup',
        icon: Icons.edit_calendar_outlined,
        title: '查寝补卡待审核',
        detail: '学生提交的补卡申请',
        count: index.pendingMakeupCount,
        unit: '条',
        actionLabel: '去审核',
        target: const TodayCampusTarget(CampusEntry.dormPunchAudit),
      ),
    if (index != null && index.todayAbnormalDormCount > 0)
      TodayTask(
        id: 'dorm',
        icon: Icons.bedtime_outlined,
        title: '查寝异常',
        detail: '昨晚或今早没有正常打卡的学生',
        count: index.todayAbnormalDormCount,
        unit: '人',
        actionLabel: '去查看',
        target: const TodayCampusTarget(CampusEntry.dormDynamic),
      ),
    if (index != null && index.chatWaitingCount > 0)
      TodayTask(
        id: 'chat',
        icon: Icons.forum_outlined,
        title: '家长消息待回复',
        detail: '家校沟通里等待回复的会话',
        count: index.chatWaitingCount,
        unit: '个',
        actionLabel: '去回复',
        target: const TodayCampusTarget(CampusEntry.homeSchool),
      ),
    ..._signTasks(s),
  ];
  return TodayBoard(
    role: s.role,
    tasks: _sorted(tasks),
    taskEmptyHint: '作品、请假和查寝都已处理。',
    agenda: _teachingAgenda(s),
    agendaTotal: s.courses.length,
    notesTitle: '需要关注的学生',
    notes: _attentionNotes(s),
    notesEmpty: '暂时没有需要关注的学生',
    shortcuts: const [
      TodayShortcut(
        '班级工作台',
        Icons.dashboard_outlined,
        TodayCampusTarget(CampusEntry.classWorkbench),
      ),
      TodayShortcut(
        '我的学生',
        Icons.groups_outlined,
        TodayReportTarget(TeachingReport.myStudents),
      ),
      TodayShortcut(
        '家校沟通',
        Icons.forum_outlined,
        TodayCampusTarget(CampusEntry.homeSchool),
      ),
      TodayShortcut(
        '查寝动态',
        Icons.bedtime_outlined,
        TodayCampusTarget(CampusEntry.dormDynamic),
      ),
      TodayShortcut(
        '授课课表',
        Icons.calendar_month_outlined,
        TodayScheduleTarget(),
      ),
    ],
  );
}

// ───────────────────────── 管理员、校长 ─────────────────────────

/// 全校课程最多列出几节；没结束的排在前面。
const _maxSchoolAgenda = 6;

/// 管理端共有的审批：教职工请假、小课签课确认、小课申请、校圈举报。
List<TodayTask> _adminTasks(TodaySnapshot s) {
  final summary = s.admin;
  final applies = s.scheduleApplies ?? 0;
  return [
    if (summary != null && summary.leaveStatus0Count > 0)
      TodayTask(
        id: 'teacherLeave',
        icon: Icons.event_busy_outlined,
        title: '教职工请假待审批',
        detail: '老师和宿管提交的请假申请',
        count: summary.leaveStatus0Count,
        unit: '条',
        actionLabel: '去审批',
        target: const TodayCampusTarget(CampusEntry.teacherLeaveApproval),
      ),
    if (summary != null && summary.smallCourseSignStatus5Count > 0)
      TodayTask(
        id: 'signConfirm',
        icon: Icons.task_alt_rounded,
        title: '小课签课待确认',
        detail: '学生已评价，等待教务确认',
        count: summary.smallCourseSignStatus5Count,
        unit: '节',
        actionLabel: '去确认',
        target: const TodayCampusTarget(CampusEntry.signManagement),
      ),
    if (applies > 0)
      TodayTask(
        id: 'scheduleApply',
        icon: Icons.edit_calendar_outlined,
        title: '小课申请待审核',
        detail: '老师提交的小课排课申请',
        count: applies,
        unit: '条',
        actionLabel: '去审核',
        target: const TodayCampusTarget(CampusEntry.scheduleManagement),
      ),
    if (summary != null && summary.postStatus0Count > 0)
      TodayTask(
        id: 'circleReport',
        icon: Icons.flag_outlined,
        title: '校圈举报待处理',
        detail: '被举报的校圈内容',
        count: summary.postStatus0Count,
        unit: '条',
        actionLabel: '去处理',
        target: const TodayCampusTarget(CampusEntry.schoolCircle),
      ),
  ];
}

List<TodayAgendaItem> _schoolAgenda(TodaySnapshot s) {
  final active = [
    for (final course in s.courses)
      if (course.phaseAt(s.now) != TodayCoursePhase.ended) course,
  ];
  final ended = [
    for (final course in s.courses)
      if (course.phaseAt(s.now) == TodayCoursePhase.ended) course,
  ];
  return [
    for (final course in [...active, ...ended].take(_maxSchoolAgenda))
      TodayAgendaItem(
        time: course.start,
        endTime: course.end,
        title: course.subject,
        subtitle: _join([course.className, course.teacherName, course.room]),
        tag: course.isSmall ? '小课' : '',
        phase: course.phaseAt(s.now),
      ),
  ];
}

const _managementShortcuts = <TodayShortcut>[
  TodayShortcut(
    '学生管理',
    Icons.school_outlined,
    TodayCampusTarget(CampusEntry.studentManagement),
  ),
  TodayShortcut(
    '教师管理',
    Icons.badge_outlined,
    TodayCampusTarget(CampusEntry.teacherManagement),
  ),
  TodayShortcut(
    '班级管理',
    Icons.meeting_room_outlined,
    TodayCampusTarget(CampusEntry.classManagement),
  ),
  TodayShortcut(
    '排课与课表',
    Icons.calendar_month_outlined,
    TodayCampusTarget(CampusEntry.scheduleManagement),
  ),
  TodayShortcut(
    '通知管理',
    Icons.campaign_outlined,
    TodayCampusTarget(CampusEntry.notificationManagement),
  ),
];

TodayBoard _admin(TodaySnapshot s) {
  final summary = s.admin;
  return TodayBoard(
    role: s.role,
    tasks: _sorted(_adminTasks(s)),
    taskEmptyHint: '请假、签课和小课申请都已处理。',
    agendaTitle: '全校今日课程',
    agenda: _schoolAgenda(s),
    agendaTotal: s.courses.length,
    agendaEmpty: '今天全校没有排课',
    signalsTitle: '画室概况',
    signals: [
      if (summary != null) ...[
        TodaySignal(
          label: '在读学生',
          value: '${summary.studentCount}',
          unit: '人',
          caption: '${summary.classCount} 个班级',
          target: const TodayCampusTarget(CampusEntry.studentManagement),
        ),
        TodaySignal(
          label: '教职工',
          value: '${summary.teacherCount}',
          unit: '人',
          caption: '老师、班主任与宿管',
          target: const TodayCampusTarget(CampusEntry.teacherManagement),
        ),
        TodaySignal(
          label: '未录人脸',
          value: '${summary.userFaceNotRecordedCount}',
          unit: '人',
          caption: summary.userFaceNotRecordedCount > 0 ? '录入后才能刷脸签到' : '全部已录入',
          level: summary.userFaceNotRecordedCount > 0
              ? TodayLevel.attention
              : TodayLevel.normal,
          target: const TodayCampusTarget(CampusEntry.faceLibrary),
        ),
      ],
    ],
    shortcuts: const [
      ..._managementShortcuts,
      TodayShortcut(
        '人脸库',
        Icons.face_retouching_natural_outlined,
        TodayCampusTarget(CampusEntry.faceLibrary),
      ),
    ],
  );
}

TodayBoard _principal(TodaySnapshot s) {
  final overview = s.principal;
  final mailbox = s.mailboxPending ?? 0;
  final tasks = <TodayTask>[
    if (overview != null && overview.overdueReviews > 0)
      TodayTask(
        id: 'overdueReviews',
        icon: Icons.rate_review_outlined,
        title: '老师点评超时',
        detail: '超过时限还没有点评的作品，可以提醒对应老师',
        count: overview.overdueReviews,
        unit: '份',
        level: TodayLevel.urgent,
        tag: '需要督办',
        actionLabel: '去查看',
        target: const TodayReportTarget(
          TeachingReport.reviewChain,
          parameter: 'filter=overdue',
        ),
      ),
    if (overview != null && overview.overdueLeadReviews > 0)
      TodayTask(
        id: 'overdueLeadReviews',
        icon: Icons.fact_check_outlined,
        title: '组长复核超时',
        detail: '老师已点评、组长还没有复核的作品',
        count: overview.overdueLeadReviews,
        unit: '份',
        level: TodayLevel.urgent,
        tag: '需要督办',
        actionLabel: '去查看',
        target: const TodayReportTarget(
          TeachingReport.reviewChain,
          parameter: 'filter=leadOverdue',
        ),
      ),
    if (mailbox > 0)
      TodayTask(
        id: 'mailbox',
        icon: Icons.mail_outline_rounded,
        title: '校长信箱待回复',
        detail: '师生的来信与建议',
        count: mailbox,
        unit: '封',
        actionLabel: '去回复',
        target: const TodayCampusTarget(CampusEntry.principalMailbox),
      ),
    ..._adminTasks(s),
  ];
  String ratio(int? present, int? expected) =>
      present == null || expected == null ? '—' : '$present / $expected';
  return TodayBoard(
    role: s.role,
    tasks: _sorted(tasks),
    taskEmptyHint: '点评进度正常，信箱和审批都已处理。',
    agendaTitle: '全校今日课程',
    agenda: _schoolAgenda(s),
    agendaTotal: s.courses.length,
    agendaEmpty: '今天全校没有排课',
    signalsTitle: '在校情况',
    signals: [
      if (overview != null) ...[
        TodaySignal(
          label: '学生到校',
          value: ratio(overview.studentPresent, overview.studentExpected),
          unit: '人',
          caption: '今日已签到 / 应到',
          target: const TodayReportTarget(
            TeachingReport.attendance,
            parameter: 'students',
          ),
        ),
        TodaySignal(
          label: '老师在岗',
          value: ratio(overview.teacherPresent, overview.teacherExpected),
          unit: '人',
          caption: '今日已签课 / 有课老师',
          target: const TodayReportTarget(
            TeachingReport.attendance,
            parameter: 'teachers',
          ),
        ),
        TodaySignal(
          label: '需要关注的学生',
          value: '${overview.attentionCount}',
          unit: '人',
          caption: '成绩下滑、缺勤或长时间未交作品',
          level: overview.attentionCount > 0
              ? TodayLevel.attention
              : TodayLevel.normal,
          target: const TodayReportTarget(TeachingReport.attention),
        ),
      ],
    ],
    notesTitle: '教学跟进',
    notes: [
      for (final alert
          in (overview?.alerts ?? const <TodayPrincipalAlert>[]).take(3))
        TodayNote(title: alert.text, target: _alertTarget(alert)),
    ],
    notesEmpty: '暂时没有需要跟进的事项',
    shortcuts: const [
      TodayShortcut(
        '老师履职',
        Icons.fact_check_outlined,
        TodayReportTarget(TeachingReport.teachers),
      ),
      TodayShortcut(
        '作品点评链',
        Icons.account_tree_outlined,
        TodayReportTarget(TeachingReport.reviewChain),
      ),
      ..._managementShortcuts,
    ],
  );
}

TodayTarget _alertTarget(TodayPrincipalAlert alert) => switch (alert.target) {
  'attention' => TodayReportTarget(
    TeachingReport.attention,
    parameter: alert.id,
  ),
  'classes' => TodayReportTarget(TeachingReport.classes, campus: alert.id),
  _ => TodayReportTarget(
    TeachingReport.reviewChain,
    parameter:
        'filter=${alert.target}&teacherId=${Uri.encodeQueryComponent(alert.id)}',
  ),
};

// ───────────────────────── 宿管 ─────────────────────────

TodayBoard _dormManager(TodaySnapshot s) {
  final index = s.dorm;
  final check = s.dormCheck;
  final stat = check?.stat;
  final session = check == null || check.checkType.isEmpty
      ? '查寝'
      : check.checkType;
  final tasks = <TodayTask>[
    if (stat != null && stat.bedCount > 0)
      if (stat.notCheckedCount > 0)
        TodayTask(
          id: 'check',
          icon: Icons.bedtime_outlined,
          title: '$session未打卡',
          detail: _join([
            '应到 ${stat.bedCount} 人，已打卡 ${stat.normalCount + stat.lateCount} 人',
            if (check!.deadline.isNotEmpty) '规定时间 ${check.deadline}',
          ]),
          count: stat.notCheckedCount,
          unit: '人',
          actionLabel: '按宿舍查寝',
          target: const TodayCampusTarget(CampusEntry.dormCheckByRoom),
        )
      else
        TodayTask(
          id: 'check',
          icon: Icons.bedtime_outlined,
          title: '$session已全部打卡',
          detail: '应到 ${stat.bedCount} 人，其中晚归 ${stat.lateCount} 人',
          level: TodayLevel.done,
          pending: false,
          actionLabel: '查看',
          target: const TodayCampusTarget(CampusEntry.dormCheckByRoom),
        ),
    if (index != null && index.pendingMakeupCount > 0)
      TodayTask(
        id: 'makeup',
        icon: Icons.edit_calendar_outlined,
        title: '补卡待审核',
        detail: '学生提交的补卡申请',
        count: index.pendingMakeupCount,
        unit: '条',
        actionLabel: '去审核',
        target: const TodayCampusTarget(CampusEntry.dormMakeupAudit),
      ),
    if (index != null && index.unclosedExceptionCount > 0)
      TodayTask(
        id: 'exception',
        icon: Icons.report_gmailerrorred_outlined,
        title: '查寝异常未处理',
        detail: '晚归或缺勤还没有备注处理结果',
        count: index.unclosedExceptionCount,
        unit: '条',
        actionLabel: '去处理',
        target: const TodayCampusTarget(CampusEntry.dormHistory),
      ),
    const TodayTask(
      id: 'punch',
      icon: Icons.fingerprint_rounded,
      title: '到岗打卡',
      detail: '本人上下班打卡与记录',
      level: TodayLevel.normal,
      pending: false,
      actionLabel: '去打卡',
      target: TodayCampusTarget(CampusEntry.dormCheckIn),
    ),
  ];

  final duties = index?.todayDutyTasks ?? const [];
  final config = s.dormConfig;
  String clock(String raw) => raw.replaceAll('前', '').trim();
  final agenda = <TodayAgendaItem>[
    if (duties.isNotEmpty)
      for (final duty in duties)
        // 值班类型（晨查寝、午间巡查…）做标题，具体安排做说明。
        TodayAgendaItem(
          time: duty.timeFrom,
          endTime: duty.timeTo,
          title: duty.tag.isEmpty ? duty.title : duty.tag,
          subtitle: duty.tag.isEmpty ? '' : duty.title,
          phase: _phaseOf(duty.timeFrom, duty.timeTo, s.now),
          target: const TodayCampusTarget(CampusEntry.dormCheckByRoom),
        )
    else if (config != null) ...[
      if (clock(config.morningDeadline).isNotEmpty)
        TodayAgendaItem(
          time: clock(config.morningDeadline),
          title: '早查寝',
          subtitle: '学生起床后在此时间前签到',
          phase: _phaseOf(clock(config.morningDeadline), '', s.now),
          target: const TodayCampusTarget(CampusEntry.dormCheckByRoom),
        ),
      if (clock(config.eveningDeadline).isNotEmpty)
        TodayAgendaItem(
          time: clock(config.eveningDeadline),
          title: '晚查寝',
          subtitle: '学生在此时间前归寝打卡',
          phase: _phaseOf(clock(config.eveningDeadline), '', s.now),
          target: const TodayCampusTarget(CampusEntry.dormCheckByRoom),
        ),
    ],
  ];

  return TodayBoard(
    role: s.role,
    tasks: _sorted(tasks),
    taskEmptyHint: '本场查寝已完成，没有待审核的补卡。',
    agendaTitle: '今日值班',
    agenda: agenda,
    agendaTotal: agenda.length,
    agendaEmpty: '今天没有值班安排',
    signalsTitle: index == null || index.batchLabel.isEmpty
        ? '查寝情况'
        : '查寝情况 · ${index.batchLabel}',
    signals: [
      if (index != null) ...[
        TodaySignal(
          label: '正常',
          value: '${index.todayNormalCount}',
          unit: '人',
          caption: '共 ${index.bedCount} 个床位',
          target: const TodayCampusTarget(CampusEntry.dormHistory),
        ),
        TodaySignal(
          label: '晚归',
          value: '${index.todayLateCount}',
          unit: '人',
          caption: '超过规定时间打卡',
          level: index.todayLateCount > 0
              ? TodayLevel.attention
              : TodayLevel.normal,
          target: const TodayCampusTarget(CampusEntry.dormHistory),
        ),
        TodaySignal(
          label: '缺勤',
          value: '${index.todayAbsentCount}',
          unit: '人',
          caption: '没有打卡也没有请假',
          level: index.todayAbsentCount > 0
              ? TodayLevel.urgent
              : TodayLevel.normal,
          target: const TodayCampusTarget(CampusEntry.dormHistory),
        ),
      ],
    ],
    shortcuts: const [
      TodayShortcut(
        '查寝历史',
        Icons.history_rounded,
        TodayCampusTarget(CampusEntry.dormHistory),
      ),
      TodayShortcut(
        '补卡审核',
        Icons.edit_calendar_outlined,
        TodayCampusTarget(CampusEntry.dormMakeupAudit),
      ),
      TodayShortcut(
        '宿管请假',
        Icons.event_busy_outlined,
        TodayCampusTarget(CampusEntry.myLeave),
      ),
      TodayShortcut(
        '校长信箱',
        Icons.mail_outline_rounded,
        TodayCampusTarget(CampusEntry.principalMailbox),
      ),
    ],
  );
}

// ───────────────────────── 工具 ─────────────────────────

/// 待处理的在前（超时、需要处理、普通），已完成与入口行在后；同级保持原顺序。
List<TodayTask> _sorted(List<TodayTask> tasks) {
  int rank(TodayTask task) => (task.pending ? 0 : 10) + task.level.index;
  final indexed = [for (var i = 0; i < tasks.length; i++) (i, tasks[i])]
    ..sort((a, b) {
      final byRank = rank(a.$2).compareTo(rank(b.$2));
      return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
    });
  return [for (final item in indexed) item.$2];
}

String _join(Iterable<String> parts) =>
    parts.where((part) => part.trim().isNotEmpty).join(' · ');

String _range(String start, String end) => end.isEmpty ? start : '$start–$end';

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _signed(double value) =>
    value > 0 ? '+${formatScore(value)}' : formatScore(value);

/// 截止时间的说法：今天 18:00 截止 / 11月18日截止。
String _dueLabel(String dueTime, String today) {
  final due = DateTime.tryParse(dueTime.replaceFirst(' ', 'T'));
  if (due == null) return '';
  if (dueTime.startsWith(today)) {
    final minute = due.minute.toString().padLeft(2, '0');
    return '今天 ${due.hour}:$minute 截止';
  }
  return '${due.month}月${due.day}日截止';
}

TodayCoursePhase _phaseOf(String from, String to, DateTime now) {
  int? minutes(String clock) {
    final parts = clock.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    return hour == null || minute == null ? null : hour * 60 + minute;
  }

  final current = now.hour * 60 + now.minute;
  final begin = minutes(from);
  final finish = minutes(to) ?? begin;
  if (finish != null && current > finish) return TodayCoursePhase.ended;
  if (begin != null && current >= begin) return TodayCoursePhase.inProgress;
  return TodayCoursePhase.upcoming;
}
