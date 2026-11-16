/// 任课老师、教学组长、班主任的「今日工作」：上课签课、作品点评、复核、
/// 班级事务与学生跟进。
library;

import '../campus/campus_today_courses.dart';
import 'today_support.dart';

Future<Json> buildTeacherToday(TodayContext ctx, {required bool leader}) async {
  final results = await Future.wait<Object?>([
    ctx.marking('/school/teacher/artworks/statistics'),
    ctx.marking('/school/teacher/attention-students'),
    ctx.marking('/school/teacher/performance'),
    ctx.platform('/app/school/v2/teacher/teacherHomeworkList', {
      'classId': '0',
      'current': 1,
      'size': 4,
      'status': '',
    }),
    ctx.platform('/app/school/v2/teacher/courseAttendanceStat', {
      'beginDate': ctx.date,
      'endDate': ctx.date,
    }),
    if (leader) ctx.marking('/school/leader/reviews/statistics'),
    if (leader) ctx.marking('/school/leader/teachers'),
  ]);
  final stats = todayMap(results[0]);
  final attention = todayRows(results[1]);
  final performance = todayMap(results[2]);
  final homework = todayRows(todayMap(results[3])['records']);
  final attendance = todayMap(results[4]);
  final lead = leader ? todayMap(results[5]) : const <String, dynamic>{};
  final groupTeachers = leader ? todayRows(results[6]) : const <Json>[];

  final steps = <Json>[
    ..._lessons(ctx),
    ..._reviewSteps(ctx, stats),
    if (leader) ..._leadSteps(lead),
    ..._followSteps(attention),
    _prepStep(ctx),
  ];

  final charts = <Json>[
    _reviewMeters(ctx, stats, performance),
    _timelyLine(performance),
    _homeworkMeters(homework),
    _attendanceParts(attendance),
    if (leader && groupTeachers.isNotEmpty)
      chartMeters(
        'group',
        '本组点评及时率',
        subtitle: '本周',
        action: actionReport('本组老师', 'groupTeachers'),
        rows: [
          for (final teacher in groupTeachers.take(4))
            meterRow(
              todayText(teacher['name']),
              todayNum(teacher['timely']) ?? 0,
              100,
              text: '${(todayNum(teacher['timely']) ?? 0).round()}%',
              caption:
                  '应评 ${todayInt(teacher['dueThisWeek'])} 份，'
                  '按时 ${todayInt(teacher['onTimeThisWeek'])} 份',
              tone: (todayNum(teacher['timely']) ?? 0) < 85
                  ? 'caution'
                  : 'brand',
            ),
        ],
      ),
  ];

  final lessons = steps.where((s) => s['kind'] == 'lesson').toList();
  final timely = todayNum(performance['timely']);
  return todayAssemble(
    ctx,
    title: '今日工作',
    steps: steps,
    charts: charts,
    highlights: [
      _reviewHighlight(ctx, stats),
      _lessonHighlight(lessons),
      todayHighlight(
        'timely',
        '本周点评及时率',
        timely == null ? '—' : '${timely.round()}',
        unit: '%',
        caption:
            '应评 ${todayInt(performance['dueThisWeek'])} 份，'
            '按时 ${todayInt(performance['onTimeThisWeek'])} 份',
        icon: 'timely',
        tone: 'teal',
        ratio: timely == null ? null : (timely / 100).clamp(0.0, 1.0),
        action: actionReport('我的履职', 'myPerformance'),
      ),
      _attentionHighlight(attention),
    ],
    streakLabel: '连续完成',
    streakDays: ctx.seeded('streak', 3, 9),
    people: _people(ctx, attention),
    shortcuts: [
      todayShortcut('我的学生', 'students', actionReport('我的学生', 'myStudents')),
      todayShortcut(
        '我的履职',
        'performance',
        actionReport('我的履职', 'myPerformance'),
      ),
      todayShortcut('授课课表', 'schedule', actionSchedule('授课课表')),
      if (leader) ...[
        todayShortcut(
          '本组老师',
          'teachers',
          actionReport('本组老师', 'groupTeachers'),
        ),
        todayShortcut('本组学情', 'chart', actionReport('本组学情', 'groupClasses')),
      ] else
        todayShortcut('我的请假', 'leave', actionCampus('我的请假', 'myLeave')),
    ],
  );
}

Future<Json> buildHeadTeacherToday(TodayContext ctx) async {
  final results = await Future.wait<Object?>([
    ctx.marking('/school/teacher/artworks/statistics'),
    ctx.marking('/school/teacher/attention-students'),
    ctx.marking('/school/teacher/performance'),
    ctx.platform('/app/school/v2/teacher/headTeacherIndex'),
    ctx.platform('/app/school/v2/teacher/teacherHomeworkList', {
      'classId': '0',
      'current': 1,
      'size': 4,
      'status': '',
    }),
  ]);
  final stats = todayMap(results[0]);
  final attention = todayRows(results[1]);
  final performance = todayMap(results[2]);
  final index = todayMap(results[3]);
  final homework = todayRows(todayMap(results[4])['records']);
  final cls = todayRows(index['classList']).firstOrNull;
  final classId = todayText(cls?['classId']);
  final dorm = classId.isEmpty
      ? const <String, dynamic>{}
      : todayMap(
          await ctx.platform('/app/school/v2/teacher/classDormitoryCheckStat', {
            'classId': classId,
            'beginDate': ctx.date,
            'endDate': ctx.date,
          }),
        );

  final leave = todayInt(index['pendingLeaveCount']);
  final makeup = todayInt(index['pendingMakeupCount']);
  final abnormal = todayInt(index['todayAbnormalDormCount']);
  final waiting = todayInt(index['chatWaitingCount']);
  final leaveTodo = [
    for (final item in todayRows(index['todoList']))
      if (item['tag'] == '请假') todayText(item['desc']),
  ];

  final steps = <Json>[
    ..._lessons(ctx),
    ..._reviewSteps(ctx, stats),
    ?todayCountStep(
      ctx,
      id: 'leave',
      kind: 'approval',
      title: '审批学生请假',
      detail: leaveTodo.isEmpty ? '家长已确认，等待班主任审批' : leaveTodo.first,
      doneDetail: '今天的请假都审批完了',
      unit: '条',
      current: leave,
      source: '班级工作台',
      guide: const [
        '点「去审批」查看请假时间和事由。',
        '确认家长已同意，再点通过或驳回。',
        '通过后学生和家长会收到通知，考勤按请假处理。',
      ],
      action: actionCampus('去审批', 'leaveApproval'),
    ),
    ?todayCountStep(
      ctx,
      id: 'makeup',
      kind: 'approval',
      title: '审核查寝补卡',
      detail: '学生提交的补卡申请',
      doneDetail: '补卡申请都审核完了',
      unit: '条',
      current: makeup,
      source: '查寝动态',
      guide: const ['点「去审核」看学生填写的补卡原因。', '情况属实点通过，补卡后当天查寝记为正常。'],
      action: actionCampus('去审核', 'dormPunchAudit'),
    ),
    if (abnormal > 0)
      todayStep(
        id: 'dorm',
        kind: 'dorm',
        title: '跟进查寝异常',
        detail: '昨晚或今早有 $abnormal 名学生没有正常打卡',
        slot: 'morning',
        time: '08:00',
        manual: true,
        source: '查寝动态',
        guide: const [
          '点「去查看」确认是哪几名学生、什么原因。',
          '联系学生或家长了解情况，需要时提醒补卡。',
          '处理完回到这里打勾。',
        ],
        action: actionCampus('去查看', 'dormDynamic'),
      ),
    ?todayCountStep(
      ctx,
      id: 'chat',
      kind: 'message',
      title: '回复家长消息',
      detail: '家校沟通里等待回复的会话',
      doneDetail: '家长消息都回复了',
      unit: '个',
      current: waiting,
      source: '家校沟通',
      guide: const ['点「去回复」打开等待回复的会话。', '涉及请假、成绩的问题尽量当天答复。'],
      action: actionCampus('去回复', 'homeSchool'),
    ),
    ..._followSteps(attention),
    todayStep(
      id: 'class-summary',
      kind: 'note',
      title: '发布今日班级小结',
      detail: '放学前把当天的出勤、作业和注意事项发到班级通知',
      time: '17:30',
      endTime: '21:30',
      required: false,
      manual: true,
      minutes: 10,
      source: '班级工作台',
      guide: const [
        '点「去发布」进入班级工作台。',
        '选「发布通知」，写上今天的出勤、作业和明天要带的画具。',
        '发布后回到这里打勾。',
      ],
      action: actionCampus('去发布', 'classWorkbench'),
    ),
  ];

  final students = todayInt(cls?['studentCount']);
  final onLeave = leave.clamp(0, students);
  final absent = students == 0 ? 0 : ctx.seeded('class-absent', 0, 1);
  final present = (students - onLeave - absent).clamp(0, students);
  final charts = <Json>[
    chartParts(
      'classAttendance',
      '班级到校',
      subtitle: todayText(cls?['className']),
      unit: '人',
      empty: '还没有绑定班级',
      action: actionCampus('班级工作台', 'classWorkbench'),
      parts: students == 0
          ? const <Json>[]
          : [
              partItem('到校', present, 'good'),
              partItem('请假', onLeave, 'neutral'),
              partItem('缺勤', absent, 'bad'),
            ],
    ),
    chartParts(
      'classDorm',
      '班级查寝',
      subtitle: '当前场次',
      unit: '人',
      empty: '当前没有查寝记录',
      action: actionCampus('查寝动态', 'dormDynamic'),
      parts: todayInt(dorm['studentCount']) == 0
          ? const <Json>[]
          : [
              partItem('正常', todayInt(dorm['normalCount']), 'good'),
              partItem('晚归', todayInt(dorm['lateCount']), 'caution'),
              partItem('缺勤', todayInt(dorm['absentCount']), 'bad'),
            ],
    ),
    chartLine(
      'attendance7',
      '班级出勤率',
      subtitle: '近 7 天',
      unit: '%',
      headline: students == 0
          ? null
          : chartHeadline(
              '${(present * 100 / students).round()}',
              unit: '%',
              label: '今天',
            ),
      points: todayWeekSeries(
        ctx,
        'attendance',
        min: 90,
        max: 100,
        today: students == 0 ? null : (present * 100 / students).round(),
        unit: '%',
      ),
    ),
    _reviewMeters(ctx, stats, performance),
    _homeworkMeters(homework),
  ];

  return todayAssemble(
    ctx,
    title: '今日工作',
    steps: steps,
    charts: charts,
    highlights: [
      todayHighlight(
        'approvals',
        '待审批',
        '${leave + makeup}',
        unit: '条',
        caption: '请假 $leave 条，补卡 $makeup 条',
        icon: 'approval',
        tone: 'pink',
        action: actionCampus('请假审批', 'leaveApproval'),
      ),
      todayHighlight(
        'present',
        '班级到校',
        students == 0 ? '—' : '$present',
        unit: students == 0 ? '' : '/ $students 人',
        caption: students == 0 ? '还没有绑定班级' : '请假 $onLeave 人，缺勤 $absent 人',
        icon: 'students',
        tone: 'teal',
        ratio: students == 0 ? null : present / students,
        action: actionCampus('班级工作台', 'classWorkbench'),
      ),
      _reviewHighlight(ctx, stats),
      todayHighlight(
        'dorm',
        '查寝异常',
        '$abnormal',
        unit: '人',
        caption: abnormal == 0 ? '昨晚和今早都正常' : '昨晚或今早没有正常打卡',
        icon: 'dorm',
        tone: 'amber',
        action: actionCampus('查寝动态', 'dormDynamic'),
      ),
    ],
    streakLabel: '连续完成',
    streakDays: ctx.seeded('streak', 3, 9),
    people: _people(ctx, attention),
    shortcuts: [
      todayShortcut(
        '班级工作台',
        'dashboard',
        actionCampus('班级工作台', 'classWorkbench'),
      ),
      todayShortcut('我的学生', 'students', actionReport('我的学生', 'myStudents')),
      todayShortcut('家校沟通', 'message', actionCampus('家校沟通', 'homeSchool')),
      todayShortcut('查寝动态', 'dorm', actionCampus('查寝动态', 'dormDynamic')),
      todayShortcut('授课课表', 'schedule', actionSchedule('授课课表')),
    ],
  );
}

Json _reviewHighlight(TodayContext ctx, Json stats) {
  final pending = todayInt(stats['pending']);
  final overdue = todayInt(stats['overdue']);
  final reviewed = _reviewedToday(ctx, pending);
  return todayHighlight(
    'reviews',
    '待点评作品',
    '$pending',
    unit: '件',
    caption: pending == 0
        ? '都点评完了'
        : (overdue > 0 ? '其中 $overdue 件已超时' : '尽量当天点评'),
    icon: 'review',
    tone: 'pink',
    ratio: pending + reviewed == 0 ? null : reviewed / (pending + reviewed),
    action: actionRoute('作品点评', '/artworks', {'startReview': pending > 0}),
  );
}

Json _lessonHighlight(List<Json> lessons) => todayHighlight(
  'lessons',
  '今日课程',
  '${lessons.length}',
  unit: '节',
  caption: lessons.isEmpty
      ? '今天没有排课'
      : '已上完 ${lessons.where((s) => s['status'] == 'done').length} 节',
  icon: 'lesson',
  tone: 'purple',
  ratio: lessons.isEmpty
      ? null
      : lessons.where((s) => s['status'] == 'done').length / lessons.length,
  action: actionSchedule('授课课表'),
);

Json _attentionHighlight(List<Json> attention) => todayHighlight(
  'attention',
  '需要关注的学生',
  '${attention.length}',
  unit: '人',
  caption: attention.isEmpty ? '暂时没有' : '成绩下滑、缺勤或作品问题反复出现',
  icon: 'follow',
  tone: 'amber',
  action: actionReport('需要关注的学生', 'myAttention'),
);

/// 今天要上的课：上课后签课。
List<Json> _lessons(TodayContext ctx) {
  final steps = <Json>[];
  for (final row in demoTodayCoursesFor(ctx.account, now: ctx.now)) {
    final start = todayClock(row['timeBegin']);
    final end = todayClock(row['timeEnd']);
    final begin = todayMinutes(start);
    final finish = todayMinutes(end);
    if (begin == null) continue;
    final sign = todayInt(row['signStatus']);
    final started = ctx.nowMinutes >= begin;
    final ended = finish != null && ctx.nowMinutes >= finish;
    final need = started && sign == 0;
    final subject = todayText(row['subjectName']);
    final count = todayInt(row['studentCount']);
    steps.add(
      todayStep(
        id: 'lesson:${row['id']}',
        kind: 'lesson',
        title: '上课：$subject',
        detail: [
          todayText(row['className']),
          todayText(row['classroomName']),
          if (count > 0) '$count 人',
        ].where((t) => t.isNotEmpty).join(' · '),
        time: start,
        endTime: end,
        // 下课了还没签课算超时；签过课、下课后算完成。
        status: need
            ? (ended ? 'overdue' : 'doing')
            : (ended ? 'done' : (started ? 'doing' : 'todo')),
        tag: need ? '待签课' : (sign > 0 && started ? '已签课' : ''),
        tagTone: need ? 'warning' : 'neutral',
        subject: subject,
        source: '授课课表',
        guide: const [
          '上课后点「去签课」，一键登记全班到课情况。',
          '有请假或缺勤的学生单独标出来，班主任会收到提醒。',
        ],
        action: need
            ? actionCampus('去签课', 'classAttendance')
            : actionSchedule('看课表'),
      ),
    );
  }
  return steps;
}

/// 今天已经点评了几件：每天第一次打开时记下待点评的件数，之后少掉的就是今天评完的。
int _reviewedToday(TodayContext ctx, int pending) {
  final baseline = todayMap(ctx.state['baseline']);
  if (baseline['pending'] == null) {
    baseline['pending'] = pending;
    baseline['done'] = ctx.seeded('reviewed-today', 2, 6);
    ctx.state['baseline'] = baseline;
    TodayDemoState.save();
  }
  final cleared = todayInt(baseline['pending']) - pending;
  return todayInt(baseline['done']) + (cleared > 0 ? cleared : 0);
}

List<Json> _reviewSteps(TodayContext ctx, Json stats) {
  final total = todayInt(stats['total']);
  if (total == 0) return const <Json>[];
  final pending = todayInt(stats['pending']);
  final overdue = todayInt(stats['overdue']);
  final reviewed = _reviewedToday(ctx, pending);
  return [
    todayStep(
      id: 'reviews',
      kind: 'review',
      title: '点评学生作品',
      detail: pending == 0
          ? '今天的作品都点评完了'
          : '还有 $pending 件待点评${overdue > 0 ? '，其中 $overdue 件已超时' : ''}',
      slot: 'anytime',
      status: pending == 0
          ? 'done'
          : (overdue > 0 ? 'overdue' : (reviewed > 0 ? 'doing' : 'todo')),
      tag: overdue > 0 ? '超时 $overdue 件' : '',
      tagTone: 'danger',
      progress: todayProgress(reviewed, reviewed + pending, '件'),
      source: '学生提交的日常作品',
      guide: const [
        '点「开始点评」，从等待时间久的作品开始。',
        '给出分数、选问题标签，写一两句具体的修改建议。',
        '可以直接在图上圈出问题，点「保存并下一份」继续。',
      ],
      action: pending == 0
          ? actionRoute('看已点评', '/artworks')
          : actionRoute('开始点评', '/artworks', {'startReview': true}),
    ),
  ];
}

List<Json> _leadSteps(Json lead) {
  final pending = todayInt(lead['pending']);
  final overdue = todayInt(lead['overdue']);
  final done = todayInt(lead['done']);
  if (pending + done == 0) return const <Json>[];
  return [
    todayStep(
      id: 'lead',
      kind: 'lead',
      title: '复核本组点评',
      detail: pending == 0
          ? '复核池已清空'
          : '还有 $pending 份待复核${overdue > 0 ? '，其中 $overdue 份已超时' : ''}',
      slot: 'anytime',
      status: pending == 0 ? 'done' : (overdue > 0 ? 'overdue' : 'todo'),
      tag: overdue > 0 ? '超时 $overdue 份' : '',
      tagTone: 'danger',
      progress: todayProgress(0, pending, '份'),
      source: '教学组长复核池',
      guide: const [
        '点「去复核」，看本组老师的打分和评语是否到位。',
        '分数偏差大的可以调分，并写明调整原因。',
        '复核后学生就能看到最终得分。',
      ],
      action: actionRoute(
        pending == 0 ? '看复核池' : '去复核',
        '/artworks/lead-reviews',
      ),
    ),
  ];
}

/// 需要关注的学生里最要紧的两名，当天找他们聊一次。
List<Json> _followSteps(List<Json> attention) => [
  for (final student in attention.take(2))
    todayStep(
      id: 'follow:${student['id']}',
      kind: 'follow',
      title: '跟进学生：${student['name']}',
      detail: todayText((student['reasons'] as List?)?.firstOrNull),
      slot: 'afternoon',
      time: '16:30',
      required: false,
      manual: true,
      minutes: 10,
      tag: todayText(student['className']),
      source: '需要关注的学生',
      guide: const [
        '点「看档案」了解近期成绩、出勤和作品情况。',
        '课间找学生聊几分钟，问清原因，约定下一步。',
        '把跟进情况记在档案里，再回到这里打勾。',
      ],
      action: actionReport(
        '看档案',
        'myAttention',
        parameter: todayText(student['id']),
      ),
    ),
];

Json _prepStep(TodayContext ctx) => todayStep(
  id: 'prep',
  kind: 'note',
  title: '准备明天的课',
  detail: '备好范画、示范步骤和要强调的问题',
  time: '19:30',
  required: false,
  manual: true,
  minutes: 30,
  source: '教学安排',
  guide: const [
    '点「看课表」确认明天上什么课、在哪个教室。',
    '从素材中心挑两三张范画，想好示范步骤。',
    '把这次点评里出现最多的问题放进课堂讲评。',
  ],
  action: actionSchedule('看课表'),
);

Json _reviewMeters(TodayContext ctx, Json stats, Json performance) {
  final pending = todayInt(stats['pending']);
  final reviewed = _reviewedToday(ctx, pending);
  final due = todayInt(performance['dueThisWeek']);
  final onTime = todayInt(performance['onTimeThisWeek']);
  final taskRate = todayNum(performance['taskReviewRate']);
  return chartMeters(
    'review',
    '点评进度',
    empty: '还没有需要点评的作品',
    action: actionRoute('作品点评', '/artworks'),
    rows: [
      if (reviewed + pending > 0)
        meterRow(
          '今日点评',
          reviewed,
          reviewed + pending,
          text: '$reviewed / ${reviewed + pending} 件',
          caption: pending == 0 ? '今天的都评完了' : '还剩 $pending 件',
        ),
      if (due > 0)
        meterRow(
          '本周按时点评',
          onTime,
          due,
          text: '$onTime / $due 份',
          caption: '及时率 ${(onTime * 100 / due).round()}%',
          tone: onTime * 100 / due < 85 ? 'caution' : 'brand',
        ),
      if (taskRate != null)
        meterRow(
          '布置的作品已点评',
          taskRate,
          100,
          text: '${taskRate.round()}%',
          caption: '共布置 ${todayInt(performance['taskCount'])} 次',
        ),
    ],
  );
}

Json _timelyLine(Json performance) => chartLine(
  'timely',
  '点评及时率',
  subtitle: '近 7 天',
  unit: '%',
  headline: todayNum(performance['timely']) == null
      ? null
      : chartHeadline(
          '${todayNum(performance['timely'])!.round()}',
          unit: '%',
          label: '本周',
        ),
  empty: '近 7 天没有到期的点评',
  action: actionReport('我的履职', 'myPerformance'),
  points: [
    for (final point in todayRows(performance['trend']))
      linePoint(
        todayText(point['date']).length >= 10
            ? todayText(point['date']).substring(5, 10)
            : todayText(point['date']),
        todayNum(point['value'])?.round(),
        todayNum(point['value']) == null
            ? ''
            : '${point['date']} 及时率 ${todayNum(point['value'])!.round()}%',
      ),
  ],
);

Json _homeworkMeters(List<Json> homework) => chartMeters(
  'homework',
  '作品提交情况',
  subtitle: '最近布置的 ${homework.length} 次',
  empty: '最近没有布置作品',
  action: actionCampus('作品批改', 'homeworkReview'),
  rows: [
    for (final item in homework)
      if (todayInt(item['totalCount']) > 0)
        meterRow(
          todayText(item['title']),
          todayInt(item['submitCount']),
          todayInt(item['totalCount']),
          text:
              '${todayInt(item['submitCount'])} / ${todayInt(item['totalCount'])} 人',
          caption: [
            todayText(item['className']),
            if (todayText(item['endTime']).length >= 16)
              '${todayText(item['endTime']).substring(5, 16)} 截止',
            if (todayInt(item['pendingCount']) > 0)
              '待批 ${todayInt(item['pendingCount'])} 份',
          ].join(' · '),
          tone: todayInt(item['submitCount']) < todayInt(item['totalCount'])
              ? 'caution'
              : 'brand',
        ),
  ],
);

Json _attendanceParts(Json attendance) {
  final total = todayInt(attendance['totalCount']);
  return chartParts(
    'attendance',
    '今日到课',
    subtitle: '我上的课',
    unit: '人次',
    empty: '上课签课后，这里显示到课情况',
    action: actionCampus('课堂签课', 'classAttendance'),
    parts: total == 0
        ? const <Json>[]
        : [
            partItem('正常', todayInt(attendance['normalCount']), 'good'),
            partItem('迟到', todayInt(attendance['lateCount']), 'caution'),
            partItem('请假', todayInt(attendance['leaveCount']), 'neutral'),
            partItem('缺勤', todayInt(attendance['absentCount']), 'bad'),
          ],
  );
}

Json _people(TodayContext ctx, List<Json> attention) => <String, dynamic>{
  'title': '需要关注的学生',
  'empty': '暂时没有需要关注的学生',
  'followLabel': '已跟进',
  'rows': [
    for (final student in attention.take(5))
      <String, dynamic>{
        'id': todayText(student['id']),
        'name': todayText(student['name']),
        'detail': todayText((student['reasons'] as List?)?.firstOrNull),
        'value': todayText(student['className']),
        'followed': ctx.isFollowed(todayText(student['id'])),
        'action': actionReport(
          '看档案',
          'myAttention',
          parameter: todayText(student['id']),
        ),
      },
  ],
};
