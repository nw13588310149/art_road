/// 管理员、校长、宿管的「今日工作」：审批与督办、全校课程与出勤、查寝与值班。
library;

import 'today_support.dart';

// ───────────────────────── 管理端共用 ─────────────────────────

/// 教职工请假、课堂补签、校圈举报：管理员与校长都要处理。
List<Json> _approvalSteps(TodayContext ctx, Json summary) => [
  ?todayCountStep(
    ctx,
    id: 'teacherLeave',
    kind: 'approval',
    title: '审批教职工请假',
    detail: '老师和宿管提交的请假申请',
    doneDetail: '教职工请假都审批完了',
    unit: '条',
    current: todayInt(summary['leaveStatus0Count']),
    source: '智慧校园 · 教师请假审批',
    guide: const [
      '点「去审批」查看请假时间、事由和代课安排。',
      '确认课程有人代上后再通过。',
      '驳回时写明原因，申请人会收到通知。',
    ],
    action: actionCampus('去审批', 'teacherLeaveApproval'),
  ),
  ?todayCountStep(
    ctx,
    id: 'signMakeup',
    kind: 'approval',
    title: '审核课堂补签',
    detail: '学生对缺勤记录提交的补签申请',
    doneDetail: '课堂补签都审核完了',
    unit: '条',
    current: todayInt(summary['courseSignMakeupStatus0Count']),
    source: '智慧校园 · 签课管理',
    guide: const [
      '点「去审核」打开签课管理，再点右上角的补签审核。',
      '向任课老师核实情况，属实就通过，这节课改记为出勤。',
      '不属实的驳回并写明原因，学生会收到通知。',
    ],
    action: actionCampus('去审核', 'signManagement'),
  ),
  ?todayCountStep(
    ctx,
    id: 'circleReport',
    kind: 'approval',
    title: '处理校圈举报',
    detail: '被举报的校圈内容',
    doneDetail: '校圈举报都处理完了',
    unit: '条',
    current: todayInt(summary['postStatus0Count']),
    source: '校圈治理',
    guide: const ['点「去处理」查看被举报的内容和举报原因。', '违规的内容下架，并提醒发布人。'],
    action: actionCampus('去处理', 'schoolCircle'),
  ),
];

/// 全校今天的课：已结束、进行中、未开始各有几节。
({int ended, int running, int upcoming, List<Json> rows}) _courses(
  TodayContext ctx,
  Object? raw,
) {
  final rows = todayRows(todayMap(raw)[ctx.date]);
  var ended = 0;
  var running = 0;
  for (final row in rows) {
    final begin = todayMinutes(todayText(row['timeBegin']));
    final finish = todayMinutes(todayText(row['timeEnd']));
    if (finish != null && ctx.nowMinutes >= finish) {
      ended++;
    } else if (begin != null && ctx.nowMinutes >= begin) {
      running++;
    }
  }
  return (
    ended: ended,
    running: running,
    upcoming: rows.length - ended - running,
    rows: rows,
  );
}

Json _courseParts(
  ({int ended, int running, int upcoming, List<Json> rows}) c,
) => chartParts(
  'courses',
  '全校今日课程',
  subtitle: '按进行情况',
  unit: '节',
  headline: chartHeadline('${c.rows.length}', unit: '节', label: '今天共'),
  empty: '今天全校没有排课',
  action: actionCampus('排课与课表', 'scheduleManagement'),
  parts: c.rows.isEmpty
      ? const <Json>[]
      : [
          partItem('已结束', c.ended, 'good'),
          partItem('进行中', c.running, 'brand'),
          partItem('未开始', c.upcoming, 'neutral'),
        ],
);

/// 巡课：每个时段看一眼课堂，自己打勾。
List<Json> _patrolSteps(
  ({int ended, int running, int upcoming, List<Json> rows}) c,
) {
  final slots = <String, ({String time, String end, int count})>{};
  for (final row in c.rows) {
    final time = todayClock(row['timeBegin']);
    final end = todayClock(row['timeEnd']);
    if (time.isEmpty) continue;
    final slot = todaySlotOf(time);
    final current = slots[slot];
    slots[slot] = (
      time: current == null || time.compareTo(current.time) < 0
          ? time
          : current.time,
      end: current == null || end.compareTo(current.end) > 0
          ? end
          : current.end,
      count: (current?.count ?? 0) + 1,
    );
  }
  const names = {'morning': '上午', 'afternoon': '下午', 'evening': '晚上'};
  return [
    for (final entry in slots.entries)
      todayStep(
        id: 'patrol:${entry.key}',
        kind: 'patrol',
        title: '${names[entry.key]}巡课',
        detail: '${entry.value.count} 节课在上，看到课、纪律和教室状况',
        time: entry.value.time,
        endTime: entry.value.end,
        required: false,
        manual: true,
        minutes: 20,
        source: '教务日常',
        guide: const [
          '点「看课表」确认这个时段哪些教室有课。',
          '到教室看到课情况和课堂纪律，缺勤多的班告诉班主任。',
          '巡完回到这里打勾。',
        ],
        action: actionCampus('看课表', 'scheduleManagement'),
      ),
  ];
}

// ───────────────────────── 管理员 ─────────────────────────

Future<Json> buildAdminToday(TodayContext ctx) async {
  final results = await Future.wait<Object?>([
    ctx.platform('/app/school/v2/manager/indexSum'),
    ctx.platform('/app/school/v2/manager/courseList', {
      'beginDate': ctx.date,
      'endDate': ctx.date,
    }),
    ctx.platform('/app/school/v2/manager/classList'),
    ctx.platform('/app/school/v2/manager/schoolUserFaceSum'),
  ]);
  final summary = todayMap(results[0]);
  final courses = _courses(ctx, results[1]);
  final classes = todayRows(results[2]);
  final face = todayMap(results[3]);
  final faceAudit = todayInt(face['status0Count']);
  final recorded = todayInt(face['status1Count']);
  final missing = todayInt(face['userFaceNotRecordedCount']);

  final steps = <Json>[
    ..._approvalSteps(ctx, summary),
    ?todayCountStep(
      ctx,
      id: 'faceAudit',
      kind: 'approval',
      title: '审核人脸照片',
      detail: '师生上传的人脸照片等待审核',
      doneDetail: '人脸照片都审核完了',
      unit: '张',
      current: faceAudit,
      source: '智慧校园 · 人脸库',
      guide: const ['点「去审核」逐张查看照片是否清晰、是否本人。', '通过后才能刷脸签到和查寝。'],
      action: actionCampus('去审核', 'faceLibrary'),
    ),
    ..._patrolSteps(courses),
    todayStep(
      id: 'notice',
      kind: 'note',
      title: '发布今日通知',
      detail: '把明天的调课、活动和注意事项通知到班级',
      time: '17:00',
      endTime: '21:30',
      required: false,
      manual: true,
      minutes: 10,
      source: '智慧校园 · 通知管理',
      guide: const ['点「去发布」进入通知管理。', '选择全校或指定班级，可以定时发布或先存草稿。', '发布后回到这里打勾。'],
      action: actionCampus('去发布', 'notificationManagement'),
    ),
  ];

  final charts = <Json>[
    _courseParts(courses),
    chartMeters(
      'classAttendance',
      '各班到课率',
      subtitle: '今天已上的课',
      empty: '上课后显示各班到课情况',
      action: actionCampus('签课管理', 'signManagement'),
      rows: courses.ended + courses.running == 0
          ? const <Json>[]
          : [
              for (final cls in classes.take(5))
                () {
                  final total = todayInt(cls['studentCount']);
                  final absent = ctx.seeded('absent:${cls['id']}', 0, 2);
                  final present = (total - absent).clamp(0, total);
                  return meterRow(
                    todayText(cls['name']),
                    present,
                    total == 0 ? 1 : total,
                    text: '$present / $total 人',
                    caption: [
                      todayText(cls['campusName']),
                      absent == 0 ? '全员到课' : '$absent 人未到',
                    ].join(' · '),
                    tone: absent >= 2 ? 'caution' : 'brand',
                  );
                }(),
            ],
    ),
    chartColumns(
      'handled',
      '审批处理量',
      subtitle: '近 7 天',
      unit: '条',
      headline: chartHeadline('${ctx.handledToday}', unit: '条', label: '今天已处理'),
      items: [
        for (var offset = -6; offset <= 0; offset++)
          () {
            final day = ctx.now.add(Duration(days: offset));
            final value = offset == 0
                ? ctx.handledToday
                : ctx.seeded('handled', 3, 12, dayOffset: offset);
            return columnItem(
              todayShortDate(day),
              value,
              emphasis: offset == 0,
              note: '${todayShortDate(day)} 处理 $value 条',
            );
          }(),
      ],
    ),
    chartMeters(
      'face',
      '人脸录入',
      action: actionCampus('人脸库', 'faceLibrary'),
      rows: [
        if (recorded + missing > 0)
          meterRow(
            '已录入',
            recorded,
            recorded + missing,
            text: '$recorded / ${recorded + missing} 人',
            caption: missing == 0 ? '全部已录入' : '还有 $missing 人没有录入，录入后才能刷脸签到',
            tone: missing > 0 ? 'caution' : 'brand',
          ),
      ],
    ),
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
        '${todayInt(summary['leaveStatus0Count']) + todayInt(summary['courseSignMakeupStatus0Count']) + faceAudit}',
        unit: '条',
        caption: '教职工请假、课堂补签与人脸照片',
        icon: 'approval',
        tone: 'pink',
        action: actionCampus('教师请假审批', 'teacherLeaveApproval'),
      ),
      todayHighlight(
        'courses',
        '今日课程',
        '${courses.rows.length}',
        unit: '节',
        caption: '已结束 ${courses.ended} 节，进行中 ${courses.running} 节',
        icon: 'lesson',
        tone: 'purple',
        ratio: courses.rows.isEmpty
            ? null
            : courses.ended / courses.rows.length,
        action: actionCampus('排课与课表', 'scheduleManagement'),
      ),
      todayHighlight(
        'students',
        '在读学生',
        '${todayInt(summary['studentCount'])}',
        unit: '人',
        caption:
            '${todayInt(summary['classCount'])} 个班级，'
            '教职工 ${todayInt(summary['teacherCount'])} 人',
        icon: 'students',
        tone: 'teal',
        action: actionCampus('学生管理', 'studentManagement'),
      ),
      todayHighlight(
        'face',
        '未录人脸',
        '$missing',
        unit: '人',
        caption: missing == 0 ? '全部已录入' : '录入后才能刷脸签到',
        icon: 'face',
        tone: 'amber',
        ratio: recorded + missing == 0 ? null : recorded / (recorded + missing),
        action: actionCampus('人脸库', 'faceLibrary'),
      ),
    ],
    streakLabel: '连续完成',
    streakDays: ctx.seeded('streak', 3, 9),
    shortcuts: _managementShortcuts(includeFace: true),
  );
}

List<Json> _managementShortcuts({required bool includeFace}) => [
  todayShortcut('学生管理', 'students', actionCampus('学生管理', 'studentManagement')),
  todayShortcut('教师管理', 'teachers', actionCampus('教师管理', 'teacherManagement')),
  todayShortcut('班级管理', 'classes', actionCampus('班级管理', 'classManagement')),
  todayShortcut(
    '排课与课表',
    'schedule',
    actionCampus('排课与课表', 'scheduleManagement'),
  ),
  todayShortcut(
    '通知管理',
    'notice',
    actionCampus('通知管理', 'notificationManagement'),
  ),
  if (includeFace)
    todayShortcut('人脸库', 'face', actionCampus('人脸库', 'faceLibrary')),
];

// ───────────────────────── 校长 ─────────────────────────

Future<Json> buildPrincipalToday(TodayContext ctx) async {
  final results = await Future.wait<Object?>([
    ctx.platform('/app/school/v2/manager/indexSum'),
    ctx.platform('/app/school/v2/manager/courseList', {
      'beginDate': ctx.date,
      'endDate': ctx.date,
    }),
    ctx.marking('/school/principal/overview'),
    ctx.marking('/school/principal/trend', {'metric': 'timely'}),
    ctx.marking('/school/principal/classes'),
    ctx.marking('/school/principal/review-chain'),
    ctx.platform('/app/school/v2/headmaster/principalMailboxList', {
      'current': 1,
      'size': 1,
      'status': 0,
    }),
  ]);
  final summary = todayMap(results[0]);
  final courses = _courses(ctx, results[1]);
  final overview = todayMap(results[2]);
  final trend = todayRows(results[3]);
  final classes = todayRows(results[4]);
  final chain = todayMap(results[5]);
  final mailbox = todayInt(todayMap(results[6])['total']);
  final attendance = todayMap(overview['attendance']);
  final alerts = todayRows(overview['alerts']);
  final overdue = todayInt(overview['overdueReviews']);
  final leadOverdue = todayInt(overview['overdueLeadReviews']);

  final steps = <Json>[
    ?todayCountStep(
      ctx,
      id: 'overdueReviews',
      kind: 'supervise',
      title: '督办老师点评超时',
      detail: '超过时限还没有点评的作品，提醒对应老师',
      doneDetail: '没有超时未点评的作品了',
      unit: '份',
      current: overdue,
      overdue: overdue,
      source: '作品点评链',
      guide: const [
        '点「去查看」，看是哪几位老师、各有几份超时。',
        '在群聊或当面提醒老师今天内点评完。',
        '连续超时的老师，在「老师履职」里看原因。',
      ],
      action: actionReport('去查看', 'reviewChain', parameter: 'filter=overdue'),
    ),
    ?todayCountStep(
      ctx,
      id: 'overdueLeadReviews',
      kind: 'supervise',
      title: '督办组长复核超时',
      detail: '老师已点评、组长还没有复核的作品',
      doneDetail: '没有超时未复核的作品了',
      unit: '份',
      current: leadOverdue,
      overdue: leadOverdue,
      source: '作品点评链',
      guide: const ['点「去查看」，看是哪位组长的复核超时。', '提醒组长今天内复核，学生才能看到最终得分。'],
      action: actionReport(
        '去查看',
        'reviewChain',
        parameter: 'filter=leadOverdue',
      ),
    ),
    ?todayCountStep(
      ctx,
      id: 'mailbox',
      kind: 'message',
      title: '回复校长信箱',
      detail: '师生的来信与建议',
      doneDetail: '校长信箱都回复了',
      unit: '封',
      current: mailbox,
      source: '校长信箱',
      guide: const ['点「去回复」逐封查看来信。', '能当场答复的直接回复；需要处理的转给对应老师并回复进展。'],
      action: actionCampus('去回复', 'principalMailbox'),
    ),
    ..._approvalSteps(ctx, summary),
    ..._patrolSteps(courses),
    todayStep(
      id: 'attention',
      kind: 'follow',
      title: '查看需要关注的学生',
      detail:
          '成绩下滑、缺勤或长时间未交作品，共 '
          '${todayInt(overview['attentionCount'])} 人',
      slot: 'anytime',
      required: false,
      manual: true,
      minutes: 15,
      source: '全校学情',
      guide: const [
        '点「去查看」，按原因看需要关注的学生名单。',
        '情况集中的班级，和班主任、任课老师约时间沟通。',
        '看完回到这里打勾。',
      ],
      action: actionReport('去查看', 'attention'),
    ),
  ];

  final submitted = todayInt(chain['total']);
  final reviewed = todayInt(chain['reviewed']);
  final leadDone = todayInt(chain['done']);
  int? percent(Object? present, Object? expected) {
    final total = todayInt(expected);
    return total == 0 ? null : (todayInt(present) * 100 / total).round();
  }

  final charts = <Json>[
    chartMeters(
      'chain',
      '作品点评链',
      subtitle: '近两周',
      action: actionReport('点评链', 'reviewChain'),
      rows: [
        if (submitted > 0) ...[
          meterRow('学生提交', submitted, submitted, text: '$submitted 份'),
          meterRow(
            '老师已点评',
            reviewed,
            submitted,
            text: '$reviewed 份',
            caption: overdue > 0 ? '还有 ${submitted - reviewed} 份没点评' : '没有超时',
            tag: overdue > 0 ? '超时 $overdue 份' : '',
          ),
          meterRow(
            '组长已复核',
            leadDone,
            submitted,
            text: '$leadDone 份',
            caption: '抽查与有争议的作品由组长复核',
            tag: leadOverdue > 0 ? '超时 $leadOverdue 份' : '',
          ),
        ],
      ],
    ),
    <String, dynamic>{
      'id': 'campus',
      'type': 'compare',
      'title': '校区对比',
      'subtitle': '最近一次月考与本周',
      'caption': '',
      'empty': '暂无校区数据',
      'action': actionReport('班级学情', 'classes'),
      'columns': const ['月考均分', '点评及时率', '出勤率'],
      'rows': [
        for (final cls in classes)
          () {
            final exams = todayRows(cls['exams']);
            final mean = exams.isEmpty ? null : todayNum(exams.last['mean']);
            final timely = ctx.seeded('timely:${cls['id']}', 80, 97);
            final present = ctx.seeded('present:${cls['id']}', 93, 100);
            return <String, dynamic>{
              'label': todayText(cls['campus']),
              'cells': [
                <String, dynamic>{
                  'value': mean ?? 0,
                  'max': 300,
                  'text': mean == null ? '—' : todayScore(mean.roundToDouble()),
                },
                <String, dynamic>{
                  'value': timely,
                  'max': 100,
                  'text': '$timely%',
                },
                <String, dynamic>{
                  'value': present,
                  'max': 100,
                  'text': '$present%',
                },
              ],
            };
          }(),
      ],
    },
    chartLine(
      'timely',
      '点评及时率',
      subtitle: '近 7 天 · 全校',
      unit: '%',
      headline: todayNum(overview['timelyReviewRate']) == null
          ? null
          : chartHeadline(
              '${todayNum(overview['timelyReviewRate'])!.round()}',
              unit: '%',
              label: '近 7 天',
            ),
      empty: '近 7 天没有到期的点评',
      action: actionReport('老师履职', 'teachers'),
      points: [
        for (final point in trend)
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
    ),
    chartMeters(
      'presence',
      '在校情况',
      subtitle: '今天',
      action: actionReport('到校与在岗', 'attendance', parameter: 'students'),
      rows: [
        meterRow(
          '学生到校',
          todayInt(attendance['studentPresent']),
          todayInt(attendance['studentExpected']) == 0
              ? 1
              : todayInt(attendance['studentExpected']),
          text: todayInt(attendance['studentExpected']) == 0
              ? '待签课'
              : '${todayInt(attendance['studentPresent'])} / '
                    '${todayInt(attendance['studentExpected'])} 人',
          caption:
              percent(
                    attendance['studentPresent'],
                    attendance['studentExpected'],
                  ) ==
                  null
              ? '上课签课后更新'
              : (todayInt(attendance['studentPresent']) == 0
                    ? '今天的课还没有签到记录'
                    : '到校率 ${percent(attendance['studentPresent'], attendance['studentExpected'])}%'),
        ),
        meterRow(
          '老师在岗',
          todayInt(attendance['teacherPresent']),
          todayInt(attendance['teacherExpected']) == 0
              ? 1
              : todayInt(attendance['teacherExpected']),
          text:
              '${todayInt(attendance['teacherPresent'])} / '
              '${todayInt(attendance['teacherExpected'])} 人',
          caption: '今天有课的老师',
        ),
      ],
    ),
    _courseParts(courses),
  ];

  return todayAssemble(
    ctx,
    title: '今日工作',
    steps: steps,
    charts: charts,
    highlights: [
      todayHighlight(
        'overdue',
        '需要督办',
        '${overdue + leadOverdue}',
        unit: '份',
        caption: '点评超时 $overdue 份，复核超时 $leadOverdue 份',
        icon: 'supervise',
        tone: 'pink',
        action: actionReport(
          '作品点评链',
          'reviewChain',
          parameter: 'filter=overdue',
        ),
      ),
      todayHighlight(
        'mailbox',
        '校长信箱',
        '$mailbox',
        unit: '封',
        caption: mailbox == 0 ? '都回复了' : '等待回复',
        icon: 'mail',
        tone: 'purple',
        action: actionCampus('校长信箱', 'principalMailbox'),
      ),
      todayHighlight(
        'present',
        '学生到校',
        todayInt(attendance['studentExpected']) == 0
            ? '—'
            : '${todayInt(attendance['studentPresent'])}',
        unit: todayInt(attendance['studentExpected']) == 0
            ? ''
            : '/ ${todayInt(attendance['studentExpected'])} 人',
        caption: todayInt(attendance['studentExpected']) == 0
            ? '第一节课签课后更新'
            : '老师在岗 ${todayInt(attendance['teacherPresent'])} / '
                  '${todayInt(attendance['teacherExpected'])} 人',
        icon: 'students',
        tone: 'teal',
        ratio: todayInt(attendance['studentExpected']) == 0
            ? null
            : todayInt(attendance['studentPresent']) /
                  todayInt(attendance['studentExpected']),
        action: actionReport('到校与在岗', 'attendance', parameter: 'students'),
      ),
      todayHighlight(
        'attention',
        '需要关注的学生',
        '${todayInt(overview['attentionCount'])}',
        unit: '人',
        caption: '成绩下滑、缺勤或长时间未交作品',
        icon: 'follow',
        tone: 'amber',
        action: actionReport('需要关注的学生', 'attention'),
      ),
    ],
    streakLabel: '连续完成',
    streakDays: ctx.seeded('streak', 3, 9),
    people: <String, dynamic>{
      'title': '教学跟进',
      'empty': '暂时没有需要跟进的事项',
      'followLabel': '已督办',
      'rows': [
        for (final alert in alerts.take(5))
          <String, dynamic>{
            'id': '${alert['target']}:${alert['id']}',
            'name': todayText(alert['name']).isEmpty
                ? todayText(alert['label'])
                : todayText(alert['name']),
            'detail': todayText(alert['detail']).isEmpty
                ? todayText(alert['label'])
                : todayText(alert['detail']),
            'value': switch (todayText(alert['target'])) {
              'overdue' => '点评超时',
              'leadOverdue' => '复核超时',
              'attention' => '学生',
              _ => '班级',
            },
            'followed': ctx.isFollowed('${alert['target']}:${alert['id']}'),
            'action': switch (todayText(alert['target'])) {
              'attention' => actionReport(
                '查看',
                'attention',
                parameter: todayText(alert['id']),
              ),
              'classes' => actionReport(
                '查看',
                'classes',
                campus: todayText(alert['id']),
              ),
              _ => actionReport(
                '查看',
                'reviewChain',
                parameter:
                    'filter=${alert['target']}&teacherId=${Uri.encodeQueryComponent(todayText(alert['id']))}',
              ),
            },
          },
      ],
    },
    shortcuts: [
      todayShortcut('老师履职', 'performance', actionReport('老师履职', 'teachers')),
      todayShortcut('作品点评链', 'chain', actionReport('作品点评链', 'reviewChain')),
      ..._managementShortcuts(includeFace: false),
    ],
  );
}

// ───────────────────────── 宿管 ─────────────────────────

Future<Json> buildDormManagerToday(TodayContext ctx) async {
  final results = await Future.wait<Object?>([
    ctx.platform('/app/school/v2/dormitory/index'),
    ctx.platform('/app/school/v2/dormitory/dormitoryCheckStat'),
    ctx.platform('/app/school/v2/dormitory/dormitoryCheckRoomList', {
      'date': ctx.date,
    }),
  ]);
  final index = todayMap(results[0]);
  final stat = todayMap(results[1]);
  final rooms = todayRows(results[2]);
  final duties = todayRows(index['todayDutyList']);
  final session = todayText(stat['checkType']);
  final beds = todayInt(stat['bedCount']);
  final unchecked = todayInt(stat['notCheckedCount']);
  final normal = todayInt(stat['normalCount']);
  final late = todayInt(stat['lateCount']);

  final steps = <Json>[
    for (final duty in duties)
      () {
        final type = todayText(duty['checkType']);
        final from = todayClock(duty['timeFrom']);
        final to = todayClock(duty['timeTo']);
        final isCheck = type.contains('查寝');
        final current = isCheck && type == session;
        final end = todayMinutes(to);
        final begin = todayMinutes(from);
        if (current && beds > 0) {
          // 当前这一场查寝：进度跟着打卡人数走。
          final finished = unchecked == 0;
          return todayStep(
            id: 'duty:$type',
            kind: 'dorm',
            title: type,
            detail: finished
                ? '应到 $beds 人，全部已打卡${late > 0 ? '，其中晚归 $late 人' : ''}'
                : '还有 $unchecked 人没有打卡，规定时间 ${todayText(stat['checkDeadline'])}',
            time: from,
            endTime: to,
            status: finished
                ? 'done'
                : (end != null && ctx.nowMinutes > end
                      ? 'overdue'
                      : (begin != null && ctx.nowMinutes >= begin
                            ? 'doing'
                            : 'todo')),
            tag: finished ? '' : '未打卡 $unchecked 人',
            tagTone: 'warning',
            progress: todayProgress(normal + late, beds, '人'),
            source: '今日值班',
            guide: [
              '点「按宿舍查寝」，一间一间核对在寝人数。',
              '人不在的先确认有没有请假，再登记晚归或缺勤。',
              todayText(duty['title']),
            ],
            action: actionCampus('按宿舍查寝', 'dormCheckByRoom'),
          );
        }
        return todayStep(
          id: 'duty:$type',
          kind: isCheck ? 'dorm' : 'patrol',
          title: type,
          detail: todayText(duty['title']),
          time: from,
          endTime: to,
          manual: true,
          minutes: 20,
          source: '今日值班',
          guide: [
            todayText(duty['title']),
            if (isCheck) '到时间后点「按宿舍查寝」开始登记。' else '按路线走一遍，发现问题当场处理并记下来。',
            '完成后回到这里打勾。',
          ],
          // 巡查没有对应的页面，做完直接打勾。
          action: isCheck ? actionCampus('按宿舍查寝', 'dormCheckByRoom') : null,
        );
      }(),
    todayStep(
      id: 'punch',
      kind: 'punch',
      title: '到岗打卡',
      detail: '本人上下班打卡',
      time: '06:30',
      slot: 'morning',
      manual: true,
      source: '宿管考勤',
      guide: const ['点「去打卡」进入到岗打卡页。', '上班和下班各打一次卡。', '打完卡回到这里打勾。'],
      action: actionCampus('去打卡', 'dormCheckIn'),
    ),
    ?todayCountStep(
      ctx,
      id: 'makeup',
      kind: 'approval',
      title: '审核补卡申请',
      detail: '学生提交的查寝补卡申请',
      doneDetail: '补卡申请都审核完了',
      unit: '条',
      current: todayInt(index['pendingMakeupCount']),
      source: '补卡审核',
      guide: const ['点「去审核」查看补卡原因和时间。', '情况属实点通过，这次查寝改记为正常。'],
      action: actionCampus('去审核', 'dormMakeupAudit'),
    ),
    ?todayCountStep(
      ctx,
      id: 'exception',
      kind: 'approval',
      title: '处理查寝异常',
      detail: '晚归或缺勤还没有备注处理结果',
      doneDetail: '查寝异常都处理完了',
      unit: '条',
      current: todayInt(index['unhandledExceptionCount']),
      source: '查寝历史',
      guide: const ['点「去处理」找到标着异常的记录。', '联系学生或班主任问清原因，写上处理结果。'],
      action: actionCampus('去处理', 'dormHistory'),
    ),
  ];

  String roomState(Json room) {
    final statuses = [
      for (final user in todayRows(room['userList'])) todayText(user['status']),
    ];
    if (statuses.any((s) => s == '缺勤' || s == '晚归')) return 'issue';
    if (statuses.any((s) => s == '未打卡')) return 'pending';
    return 'done';
  }

  final abnormalToday =
      todayInt(index['todayLateCount']) + todayInt(index['todayAbsentCount']);
  final charts = <Json>[
    chartParts(
      'check',
      session.isEmpty ? '本场查寝' : '本场$session',
      subtitle: beds == 0 ? '' : '应到 $beds 人',
      unit: '人',
      empty: '当前没有查寝场次',
      action: actionCampus('按宿舍查寝', 'dormCheckByRoom'),
      parts: beds == 0
          ? const <Json>[]
          : [
              partItem('正常', normal, 'good'),
              partItem('晚归', late, 'caution'),
              partItem('未打卡', unchecked, 'neutral'),
            ],
    ),
    <String, dynamic>{
      'id': 'rooms',
      'type': 'rooms',
      'title': '宿舍状态',
      'subtitle':
          '${rooms.where((r) => roomState(r) == 'done').length} / '
          '${rooms.length} 间已查完',
      'caption': '',
      'empty': '没有管辖的宿舍',
      'action': actionCampus('按宿舍查寝', 'dormCheckByRoom'),
      'rooms': [
        for (final room in rooms)
          () {
            final users = todayRows(room['userList']);
            return <String, dynamic>{
              'building': todayText(room['buildingName']),
              'name': todayText(room['roomName']),
              'total': users.length,
              'checked': users
                  .where((u) => todayText(u['status']) != '未打卡')
                  .length,
              'state': roomState(room),
            };
          }(),
      ],
    },
    chartColumns(
      'abnormal',
      '晚归与缺勤',
      subtitle: '近 7 天',
      unit: '人',
      headline: chartHeadline('$abnormalToday', unit: '人', label: '今天'),
      action: actionCampus('查寝历史', 'dormHistory'),
      items: [
        for (var offset = -6; offset <= 0; offset++)
          () {
            final day = ctx.now.add(Duration(days: offset));
            final value = offset == 0
                ? abnormalToday
                : ctx.seeded('abnormal', 0, 4, dayOffset: offset);
            return columnItem(
              todayShortDate(day),
              value,
              emphasis: offset == 0,
              note: '${todayShortDate(day)} 晚归与缺勤 $value 人',
            );
          }(),
      ],
    ),
  ];

  return todayAssemble(
    ctx,
    title: '今日工作',
    steps: steps,
    charts: charts,
    highlights: [
      todayHighlight(
        'unchecked',
        session.isEmpty ? '未打卡' : '$session未打卡',
        '$unchecked',
        unit: '人',
        caption: beds == 0 ? '当前没有查寝场次' : '应到 $beds 人，已打卡 ${normal + late} 人',
        icon: 'dorm',
        tone: 'pink',
        ratio: beds == 0 ? null : (normal + late) / beds,
        action: actionCampus('按宿舍查寝', 'dormCheckByRoom'),
      ),
      todayHighlight(
        'normal',
        '今日正常',
        '${todayInt(index['todayNormalCount'])}',
        unit: '人',
        caption:
            '晚归 ${todayInt(index['todayLateCount'])} 人，'
            '缺勤 ${todayInt(index['todayAbsentCount'])} 人',
        icon: 'students',
        tone: 'teal',
        action: actionCampus('查寝历史', 'dormHistory'),
      ),
      todayHighlight(
        'makeup',
        '补卡待审',
        '${todayInt(index['pendingMakeupCount'])}',
        unit: '条',
        caption: '审核后查寝记录会更新',
        icon: 'approval',
        tone: 'purple',
        action: actionCampus('补卡审核', 'dormMakeupAudit'),
      ),
      todayHighlight(
        'exception',
        '异常未处理',
        '${todayInt(index['unhandledExceptionCount'])}',
        unit: '条',
        caption: '晚归或缺勤还没有写处理结果',
        icon: 'supervise',
        tone: 'amber',
        action: actionCampus('查寝历史', 'dormHistory'),
      ),
    ],
    streakLabel: '连续完成',
    streakDays: ctx.seeded('streak', 3, 9),
    shortcuts: [
      todayShortcut('查寝历史', 'history', actionCampus('查寝历史', 'dormHistory')),
      todayShortcut('补卡审核', 'audit', actionCampus('补卡审核', 'dormMakeupAudit')),
      todayShortcut('宿管请假', 'leave', actionCampus('宿管请假', 'myLeave')),
      todayShortcut('校长信箱', 'mail', actionCampus('校长信箱', 'principalMailbox')),
    ],
  );
}
