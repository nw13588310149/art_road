/// 学生的「今日学习」：课程、打卡、作品、改画、练习与阅读，加上学习情况的图表。
library;

import '../campus/campus_today_courses.dart';
import 'today_support.dart';

Future<Json> buildStudentToday(TodayContext ctx) async {
  final results = await Future.wait<Object?>([
    ctx.marking('/app/tasks'),
    ctx.marking('/app/artworks/insights'),
    ctx.marking('/app/artworks', {
      'status': 'REVIEWED',
      'current': 1,
      'size': 8,
    }),
    ctx.marking('/app/study/overview'),
    ctx.platform('/app/school/v2/student/index'),
    ctx.platform('/app/school/v2/student/dormitoryCheckHistory', {
      'beginDate': ctx.date,
      'endDate': ctx.date,
      'current': 1,
      'size': 10,
    }),
    ctx.platform('/app/school/v2/user/schoolConfigList'),
    ctx.platformGet('/app/ebooks/shelf'),
  ]);
  final tasks = todayRows(results[0]);
  final insights = todayMap(results[1]);
  final works = todayRows(todayMap(results[2])['records']);
  final overview = todayMap(results[3]);
  final index = todayMap(results[4]);
  final dormRecords = todayRows(todayMap(results[5])['records']);
  final config = todayRows(results[6]);
  final shelf = todayRows(todayMap(results[7])['records']);

  final exam = todayMap(todayMap(overview['recentStage'])['exam']);
  final subjects = todayRows(exam['subjects']);
  Json? weakest;
  for (final subject in subjects) {
    final score = todayNum(subject['score']);
    if (score == null) continue;
    if (weakest == null || score < todayNum(weakest['score'])!) {
      weakest = subject;
    }
  }

  final steps = <Json>[
    ..._lessons(ctx),
    ..._dormSteps(ctx, dormRecords, config),
    ...await _critiqueSteps(ctx, exam),
    ..._taskSteps(ctx, tasks),
    ...await _reviseStep(ctx, works),
    ..._practiceSteps(insights, weakest),
    ..._readingStep(shelf),
  ];

  final practiced = todayInt(ctx.state['practice']);
  const target = 60;
  final unified = DateTime.tryParse(todayText(index['unifiedExamDate']));
  final daysToExam = unified
      ?.difference(DateTime(ctx.now.year, ctx.now.month, ctx.now.day))
      .inDays;

  final scored = [
    for (final work in works.reversed) ?todayNum(work['finalScore']),
  ];
  final lessons = steps.where((s) => s['kind'] == 'lesson').toList();
  final lessonsDone = lessons.where((s) => s['status'] == 'done').length;
  final practiceSeries = todayWeekSeries(
    ctx,
    'practice',
    min: 25,
    max: 80,
    today: practiced,
    unit: ' 分钟',
  );
  final openTasks = [
    for (final task in tasks)
      if (task['status'] == 'PENDING' || task['status'] == 'OVERDUE') task,
  ];
  final overdueTasks = openTasks.where((t) => t['status'] == 'OVERDUE').length;
  final highlights = <Json>[
    todayHighlight(
      'lessons',
      '今日课程',
      '${lessons.length}',
      unit: '节',
      caption: lessons.isEmpty ? '今天没有排课' : '已上完 $lessonsDone 节',
      icon: 'lesson',
      tone: 'purple',
      ratio: lessons.isEmpty ? null : lessonsDone / lessons.length,
      action: actionSchedule('我的课表'),
    ),
    todayHighlight(
      'tasks',
      '待交作品',
      '${openTasks.length}',
      unit: '件',
      caption: openTasks.isEmpty
          ? '老师布置的都交齐了'
          : (overdueTasks > 0 ? '其中 $overdueTasks 件已超时' : '按截止时间提交'),
      icon: 'homework',
      tone: 'pink',
      action: actionCampus('我的作品', 'myHomework'),
    ),
    todayHighlight(
      'practice',
      '今日练习',
      '$practiced',
      unit: '分钟',
      caption: practiced >= target
          ? '已达到每天 $target 分钟的目标'
          : '目标 $target 分钟，还差 ${target - practiced} 分钟',
      icon: 'practice',
      tone: 'teal',
      trend: [
        for (final point in practiceSeries) todayNum(point['value']) ?? 0,
      ],
      action: actionPracticeLog('记录练习'),
    ),
    if (daysToExam != null && daysToExam >= 0)
      todayHighlight(
        'exam',
        '距离联考',
        '$daysToExam',
        unit: '天',
        caption: '${todayText(index['unifiedExamDate'])} 开考',
        icon: 'exam',
        tone: 'amber',
        action: actionRoute('成绩报告', '/study'),
      )
    else
      todayHighlight(
        'submitted',
        '近 7 天提交',
        '${todayInt(insights['recentSubmitCount'])}',
        unit: '份',
        caption: '已点评 ${todayInt(insights['reviewedCount'])} 份',
        icon: 'exam',
        tone: 'amber',
        action: actionRoute('作品成长', '/study', {'view': 'artworkGrowth'}),
      ),
  ];

  final charts = <Json>[
    chartLine(
      'practice',
      '练习时长',
      subtitle: '近 7 天',
      unit: '分钟',
      target: target,
      targetLabel: '每天 $target 分钟',
      headline: chartHeadline('$practiced', unit: '分钟', label: '今天已练'),
      caption: practiced >= target
          ? '今天已练 $practiced 分钟，达到目标'
          : '今天已练 $practiced 分钟，离目标还差 ${target - practiced} 分钟',
      action: actionPracticeLog('记录练习'),
      points: practiceSeries,
    ),
    chartMeters(
      'subjects',
      '三科成绩',
      subtitle: todayText(exam['examName']),
      empty: '还没有出分的考试',
      action: actionRoute('看成绩报告', '/study'),
      rows: [
        for (final subject in subjects)
          if (todayNum(subject['score']) != null)
            meterRow(
              todayText(subject['subjectName']),
              todayNum(subject['score'])!,
              todayNum(subject['maxScore']) ?? 100,
              text: '${todayScore(todayNum(subject['score']))} 分',
              caption: [
                if (todayText(subject['grade']).isNotEmpty)
                  '${subject['grade']} 档',
                if (todayInt(subject['ranking']) > 0)
                  '全画室第 ${todayInt(subject['ranking'])} 名',
              ].join(' · '),
              tag: identical(subject, weakest) && subjects.length > 1
                  ? '需要加强'
                  : '',
            ),
      ],
    ),
    chartLine(
      'works',
      '最近作品得分',
      subtitle: '老师点评过的 ${works.length} 份作品',
      unit: '分',
      empty: '作品被老师点评后，这里会显示得分走势',
      headline: scored.isEmpty
          ? null
          : chartHeadline(
              todayScore(scored.last),
              unit: '分',
              label: '最近一份',
              delta:
                  scored.length < 2 || scored.last == scored[scored.length - 2]
                  ? ''
                  : '较上一份 ${scored.last > scored[scored.length - 2] ? '+' : ''}'
                        '${todayScore(scored.last - scored[scored.length - 2])}',
              deltaGood:
                  scored.length < 2 || scored.last >= scored[scored.length - 2],
            ),
      action: actionRoute('作品档案', '/artworks'),
      points: [
        for (final work in works.reversed)
          if (todayNum(work['finalScore']) != null)
            linePoint(
              todayText(work['drawingDate']).length >= 10
                  ? todayText(work['drawingDate']).substring(5, 10)
                  : '',
              todayNum(work['finalScore']),
              '${work['title']} · ${work['subject']} · '
              '${todayScore(todayNum(work['finalScore']))} 分',
            ),
      ],
    ),
  ];

  return todayAssemble(
    ctx,
    title: '今日学习',
    steps: steps,
    charts: charts,
    highlights: highlights,
    streakLabel: '连续练习',
    streakDays: todayInt(insights['streakDays']),
    shortcuts: [
      todayShortcut('我的课表', 'schedule', actionSchedule('我的课表')),
      todayShortcut('上传作品', 'upload', actionRoute('上传作品', '/artworks')),
      todayShortcut('请假', 'leave', actionCampus('请假', 'studentLeave')),
      todayShortcut('我的笔记', 'notes', actionRoute('我的笔记', '/my-notes')),
      todayShortcut('我的收藏', 'favorite', actionRoute('我的收藏', '/my-collection')),
    ],
  );
}

/// 今天的课：到点上课，由任课老师签课，下课后自动完成。
List<Json> _lessons(TodayContext ctx) {
  final steps = <Json>[];
  for (final row in demoTodayCoursesFor(ctx.account, now: ctx.now)) {
    final start = todayClock(row['timeBegin']);
    final end = todayClock(row['timeEnd']);
    final begin = todayMinutes(start);
    final finish = todayMinutes(end);
    if (begin == null) continue;
    final ended = finish != null && ctx.nowMinutes >= finish;
    final started = ctx.nowMinutes >= begin;
    final subject = todayText(row['subjectName']);
    steps.add(
      todayStep(
        id: 'lesson:${row['id']}',
        kind: 'lesson',
        title: '$subject课',
        detail: [
          todayText(row['teacherRealname']),
          todayText(row['classroomName']),
        ].where((t) => t.isNotEmpty).join(' · '),
        time: start,
        endTime: end,
        status: ended ? 'done' : (started ? 'doing' : 'todo'),
        subject: subject,
        source: '今天的课表',
        guide: const [
          '提前 5 分钟到教室，带好画具。',
          '上课由任课老师签课，不用自己签到。',
          '下课后把课堂作品拍照上传，方便老师点评。',
        ],
        action: actionSchedule('看课表'),
      ),
    );
  }
  return steps;
}

/// 住校生的早晚查寝打卡，状态取当天的查寝记录。
List<Json> _dormSteps(TodayContext ctx, List<Json> records, List<Json> config) {
  String configured(String key) {
    for (final item in config) {
      if (item['configKey'] == key) return todayClock(item['configValue']);
    }
    return '';
  }

  final morning = configured('dormitoryMorningCheckTime');
  final evening = configured('dormitoryNightCheckTime');
  if (records.isEmpty && morning.isEmpty && evening.isEmpty) {
    return const <Json>[];
  }
  Json step(String id, String type, String title, String deadline) {
    Json? record;
    for (final item in records) {
      if (item['checkType'] == type) record = item;
    }
    final status = todayText(record?['status']);
    final time = todayText(record?['checkTime']);
    final limit = todayMinutes(deadline);
    final checked = record != null && time.isNotEmpty;
    return todayStep(
      id: id,
      kind: 'dorm',
      title: title,
      detail: checked
          ? '$time 已打卡${status.isEmpty || status == '正常' ? '' : '，$status'}'
          : '$deadline 前在宿舍完成打卡',
      time: deadline,
      status: checked
          ? 'done'
          : (limit != null && ctx.nowMinutes > limit ? 'overdue' : 'todo'),
      tag: checked && status.isNotEmpty && status != '正常' ? status : '',
      tagTone: 'warning',
      source: '宿舍查寝',
      guide: const [
        '在规定时间前回到宿舍。',
        '由宿管老师查寝登记，或在「查寝」里刷脸打卡。',
        '错过时间可以在「查寝」里申请补卡。',
      ],
      action: actionCampus(checked ? '看记录' : '去打卡', 'dormCheck'),
    );
  }

  return [
    if (morning.isNotEmpty) step('dorm:morning', '晨查寝', '晨查寝打卡', morning),
    if (evening.isNotEmpty) step('dorm:evening', '晚查寝', '晚查寝打卡', evening),
  ];
}

/// 最近一次月考里老师发布了讲评、还没听的科目，各一件「听讲评」。今天听过的显示为
/// 已完成；今天之前就听过的不再出现。
Future<List<Json>> _critiqueSteps(TodayContext ctx, Json exam) async {
  final examId = todayText(exam['examId']);
  if (examId.isEmpty) return const <Json>[];
  final examName = todayText(
    exam['examName'],
  ).replaceFirst(RegExp(r'^\d{4}\s*年\s*'), '');
  final steps = <Json>[];
  for (final subject in todayRows(exam['subjects'])) {
    if (subject['critiqueAvailable'] != true) continue;
    final subjectId = todayText(subject['subjectId']);
    final unread = subject['critiqueUnread'] == true;
    final id = 'critique:$examId:$subjectId';
    if (ctx.baseline(id, unread ? 1 : 0) == 0) continue;
    final critique = todayMap(
      await ctx.marking(
        '/app/study/exams/${Uri.encodeComponent(examId)}'
        '/subjects/${Uri.encodeComponent(subjectId)}/critique',
      ),
    );
    final papers = todayRows(critique['papers']);
    final shared = papers.where((p) => p['shared'] == true).length;
    final mine = papers.any((p) => p['mine'] == true);
    final teacher = todayText(critique['teacherName']);
    final name = todayText(subject['subjectName']);
    steps.add(
      todayStep(
        id: id,
        kind: 'critique',
        title: '听讲评：$examName $name',
        detail: unread
            ? [
                if (teacher.isNotEmpty) '$teacher老师',
                if (shared > 0) '讲评了 $shared 张代表卷',
                if (mine) '还看了你的原卷',
              ].join('，')
            : '已经听过，可以随时回看',
        slot: 'anytime',
        status: unread ? 'todo' : 'done',
        required: false,
        minutes: 15,
        tag: mine && unread ? '有你的原卷' : '',
        subject: name,
        source: teacher.isEmpty ? '月考讲评' : '$teacher老师的月考讲评',
        guide: [
          if (mine) '先看「我的原卷」上老师标出的几处，点编号听这一处的讲评。',
          '再对照「我这一档」和「上一档」的代表卷，看差距在哪里。',
          '把要改的地方记到笔记里，下次作画时注意。',
        ],
        action: actionRoute('听讲评', '/study', {
          'examId': examId,
          'view': 'critique',
          'subjectId': subjectId,
        }),
      ),
    );
  }
  return steps;
}

/// 老师布置的作品：没交的排在前面，今天到期、已经交了的也列出来。
List<Json> _taskSteps(TodayContext ctx, List<Json> tasks) {
  final open = [
    for (final task in tasks)
      if (task['status'] == 'PENDING' || task['status'] == 'OVERDUE') task,
  ]..sort((a, b) => todayText(a['dueTime']).compareTo(todayText(b['dueTime'])));
  final doneToday = [
    for (final task in tasks)
      if (todayText(task['dueTime']).startsWith(ctx.date) &&
          (task['status'] == 'SUBMITTED' || task['status'] == 'REVIEWED'))
        task,
  ];
  Json step(Json task) {
    final due = todayText(task['dueTime']);
    final dueToday = due.startsWith(ctx.date);
    final status = todayText(task['status']);
    final overdue = status == 'OVERDUE';
    final done = status == 'SUBMITTED' || status == 'REVIEWED';
    final dueDay = DateTime.tryParse(due.replaceFirst(' ', 'T'));
    final deadline = dueToday
        ? '今天 ${todayClock(due)} 截止'
        : (dueDay == null ? '' : '${dueDay.month}月${dueDay.day}日截止');
    return todayStep(
      id: 'task:${task['id']}',
      kind: 'homework',
      title: '交作品：${task['title']}',
      detail: done
          ? (status == 'REVIEWED' ? '已提交，老师已点评' : '已提交，等待老师点评')
          : [
              todayText(task['subject']),
              '${task['teacherName']}布置',
              deadline,
            ].where((t) => t.isNotEmpty).join(' · '),
      slot: 'anytime',
      deadline: due,
      status: done ? 'done' : (overdue ? 'overdue' : 'todo'),
      tag: done ? '' : (overdue ? '已超时' : (dueToday ? '今日截止' : '')),
      tagTone: overdue ? 'danger' : 'warning',
      subject: todayText(task['subject']),
      source: '${task['teacherName']}布置的作品',
      guide: [
        if (todayText(task['requirement']).isNotEmpty)
          '要求：${task['requirement']}',
        '画完后把作品平放，在光线均匀的地方拍照。',
        '点「去提交」上传照片，选择点评老师。',
      ],
      action: done
          ? actionRoute('看作品', '/artworks')
          : actionUpload(
              '去提交',
              taskId: todayText(task['id']),
              title: todayText(task['title']),
              subject: todayText(task['subject']),
            ),
    );
  }

  return [
    for (final task in open.take(4)) step(task),
    for (final task in doneToday.take(2)) step(task),
  ];
}

/// 最近一份被点评的作品如果指出了问题，建议按点评改一版。
Future<List<Json>> _reviseStep(TodayContext ctx, List<Json> works) async {
  if (works.isEmpty) return const <Json>[];
  final work = works.first;
  // 已经改过一版的不再提醒。
  if (todayInt(work['versionCount']) > 1) return const <Json>[];
  final detail = todayMap(
    await ctx.marking(
      '/app/artworks/${Uri.encodeComponent(todayText(work['id']))}',
    ),
  );
  final review = todayMap(detail['review']);
  final tags = todayRows(review['tags']);
  if (tags.isEmpty) return const <Json>[];
  final comment = todayText(review['content']).split(RegExp('[。；;！？]')).first;
  final teacher = todayText(review['teacherName']);
  return [
    todayStep(
      id: 'revise:${work['id']}',
      kind: 'revise',
      title: '按点评改画：${work['title']}',
      detail: comment.isEmpty ? '老师指出了需要改进的地方' : '$teacher：$comment',
      slot: 'anytime',
      required: false,
      manual: true,
      minutes: 40,
      tag: todayText(tags.first['name']),
      tagTone: 'warning',
      subject: todayText(work['subject']),
      source: '$teacher的点评',
      guide: [
        for (final tag in tags.take(2)) '${tag['name']}：${tag['explanation']}',
        '对照老师在图上的批注，改完后重新拍照。',
        '点「改画重交」上传新的一版，老师会再看一次。',
      ],
      action: actionUpload(
        '改画重交',
        parentId: todayText(work['id']),
        title: todayText(work['title']),
        subject: todayText(work['subject']),
      ),
    ),
  ];
}

/// 今日练习：老师点评里出现次数多的问题各练一项，再对照一张弱项科目的范画。
List<Json> _practiceSteps(Json insights, Json? weakest) {
  final steps = <Json>[];
  final used = <String>{};
  for (final suggestion in todayRows(insights['suggestions'])) {
    if (steps.length >= 2) break;
    final tool = todayText(suggestion['tool']);
    if (tool.isEmpty || !used.add(tool)) continue;
    final count = todayInt(suggestion['count']);
    steps.add(
      todayStep(
        id: 'practice:$tool',
        kind: 'practice',
        title: '练习：$tool',
        detail: [
          if (count > 1) '老师点评里出现 $count 次',
          todayText(suggestion['text']),
        ].join('。'),
        slot: 'anytime',
        required: false,
        manual: true,
        minutes: 20,
        tag: todayText(suggestion['tag']),
        tagTone: 'warning',
        subject: todayText(suggestion['gallerySubject']),
        source: '老师点评里的高频问题',
        guide: [
          '点「去练习」打开$tool。',
          '导入一张自己最近的作品，或者用示例画作。',
          '按提示找出问题，在画面上改一遍。',
          '练完回到这里打勾，练习时长会记到今天。',
        ],
        action: actionTool('去练习', tool),
      ),
    );
  }
  if (steps.isEmpty) {
    for (final tool in const ['明度检查', '速写计时']) {
      steps.add(
        todayStep(
          id: 'practice:$tool',
          kind: 'practice',
          title: '练习：$tool',
          detail: '还没有点评记录，先从基本功练起',
          slot: 'anytime',
          required: false,
          manual: true,
          minutes: 20,
          tag: '基本功',
          source: '基本功练习',
          guide: ['点「去练习」打开$tool。', '按工具里的提示完成一组练习。', '练完回到这里打勾。'],
          action: actionTool('去练习', tool),
        ),
      );
    }
  }
  if (weakest != null) {
    final subject = todayText(weakest['subjectName']);
    steps.add(
      todayStep(
        id: 'practice:gallery:$subject',
        kind: 'practice',
        title: '对照范画：$subject',
        detail:
            '最近月考$subject ${todayScore(todayNum(weakest['score']))} 分，'
            '是三科里分数最低的一科',
        slot: 'anytime',
        required: false,
        manual: true,
        minutes: 20,
        tag: subject,
        subject: subject,
        source: '最近一次月考成绩',
        guide: [
          '点「看范画」，挑一张和自己近期作品同类的范画。',
          '对照着看构图、大关系和细节处理的差别。',
          '把看到的差别记到笔记里，下次作画时注意。',
        ],
        action: actionGallery('看范画', subject),
      ),
    );
  }
  return steps;
}

/// 接着上次读的书刊读一会儿；书架为空时不安排。
List<Json> _readingStep(List<Json> shelf) {
  if (shelf.isEmpty) return const <Json>[];
  Json book = shelf.first;
  for (final item in shelf) {
    if (item['progress'] is Map) {
      book = item;
      break;
    }
  }
  final progress = todayMap(book['progress']);
  final page = todayInt(progress['page'] ?? progress['lastPage']);
  final pages = todayInt(book['pageCount']);
  return [
    todayStep(
      id: 'read:${book['id']}',
      kind: 'reading',
      title: '阅读：${book['title']}',
      detail: page > 0 && pages > 0
          ? '上次读到第 $page / $pages 页，接着读一讲'
          : todayText(book['subtitle']),
      slot: 'evening',
      required: false,
      manual: true,
      minutes: 15,
      tag: todayText(book['categoryLabel']),
      source: '我的书架',
      guide: const ['点「去阅读」打开这本书刊，进度会自动保存。', '读一讲，把有用的方法记到笔记里。', '读完回到这里打勾。'],
      action: actionRoute('去阅读', '/ebooks', {'bookId': todayText(book['id'])}),
    ),
  ];
}
