/// 今日看板（今日学习 / 今日工作）的演示接口。
///
/// - `/app/today/board`：按登录身份返回当天的清单、进度、下一步与图表；
/// - `/app/today/step/*`：打勾、取消、今天不做、推迟到晚上、添加和删除自己的安排；
/// - `/app/today/practice/log`：记录练习时长；
/// - `/app/today/people/follow`：标记一名学生或一件事已经跟进；
/// - `/app/today/tip/dismiss`：不再显示用法提示。
///
/// 写操作都返回更新后的看板。课表、作品、点评、审批、查寝这些数量取自各模块
/// 自己的演示接口，和对应页面上的数字一致；历史序列是按账号和日期生成的稳定数。
library;

import '../../demo_accounts.dart';
import '../../demo_backend.dart';
import '../../demo_store.dart';
import 'today_management.dart';
import 'today_student.dart';
import 'today_support.dart';
import 'today_teaching.dart';

void registerTodayFixtures(DemoRouter r) {
  r.any('/app/today/board', (req) => buildTodayBoard(TodayContext(req)));

  r.post('/app/today/step/complete', (req) => _toggle(req, done: true));
  r.post('/app/today/step/reopen', (req) => _toggle(req, done: false));

  r.post('/app/today/step/skip', (req) async {
    final ctx = TodayContext(req);
    final step = await _find(ctx, req.str('id'));
    if (step['required'] == true) {
      throw const DemoApiException('这是必做的事，不能跳过');
    }
    final id = todayText(step['id']);
    TodayDemoState.toggle(ctx.state, 'skipped', id, true);
    TodayDemoState.toggle(ctx.state, 'done', id, false);
    TodayDemoState.save();
    return buildTodayBoard(TodayContext(req));
  });

  r.post('/app/today/step/restore', (req) {
    final ctx = TodayContext(req);
    TodayDemoState.toggle(ctx.state, 'skipped', req.str('id'), false);
    TodayDemoState.save();
    return buildTodayBoard(TodayContext(req));
  });

  r.post('/app/today/step/snooze', (req) async {
    final ctx = TodayContext(req);
    final step = await _find(ctx, req.str('id'));
    if (todayText(step['kind']) == 'lesson') {
      throw const DemoApiException('课程按课表时间进行，不能推迟');
    }
    TodayDemoState.toggle(
      ctx.state,
      'snoozed',
      todayText(step['id']),
      req.boolOf('on', true),
    );
    TodayDemoState.save();
    return buildTodayBoard(TodayContext(req));
  });

  r.post('/app/today/step/save', (req) {
    final ctx = TodayContext(req);
    final title = req.str('title');
    if (title.isEmpty) {
      throw const DemoApiException('请填写要做的事');
    }
    if (title.length > 30) {
      throw const DemoApiException('内容不超过 30 个字');
    }
    final slot = req.str('slot', 'anytime');
    if (!const ['morning', 'afternoon', 'evening', 'anytime'].contains(slot)) {
      throw const DemoApiException('时段不正确');
    }
    final custom = TodayDemoState.ids(ctx.state, 'custom');
    if (custom.length >= 10) {
      throw const DemoApiException('自己添加的安排不超过 10 件');
    }
    custom.add(<String, dynamic>{
      'id': DemoStore.nextId('custom-'),
      'title': title,
      'detail': req.str('detail'),
      'slot': slot,
      'time': todayClock(req.str('time')),
    });
    TodayDemoState.save();
    return buildTodayBoard(TodayContext(req));
  });

  r.post('/app/today/step/delete', (req) {
    final ctx = TodayContext(req);
    final id = req.str('id');
    final custom = TodayDemoState.ids(ctx.state, 'custom');
    final before = custom.length;
    custom.removeWhere((item) => item is Map && item['id'] == id);
    if (custom.length == before) {
      throw const DemoApiException('只能删除自己添加的安排');
    }
    for (final key in const ['done', 'skipped', 'snoozed']) {
      TodayDemoState.toggle(ctx.state, key, id, false);
    }
    TodayDemoState.save();
    return buildTodayBoard(TodayContext(req));
  });

  r.post('/app/today/practice/log', (req) {
    final ctx = TodayContext(req);
    final minutes = req.intOf('minutes');
    if (minutes < 1 || minutes > 240) {
      throw const DemoApiException('练习时长在 1 到 240 分钟之间');
    }
    ctx.state['practice'] = todayInt(ctx.state['practice']) + minutes;
    TodayDemoState.save();
    return buildTodayBoard(TodayContext(req));
  });

  r.post('/app/today/people/follow', (req) {
    final ctx = TodayContext(req);
    final id = req.str('id');
    if (id.isEmpty) {
      throw const DemoApiException('缺少要标记的对象');
    }
    TodayDemoState.toggle(
      ctx.state,
      'followed',
      id,
      req.boolOf('followed', true),
    );
    TodayDemoState.save();
    return buildTodayBoard(TodayContext(req));
  });

  r.post('/app/today/tip/dismiss', (req) {
    final ctx = TodayContext(req);
    ctx.state['tipSeen'] = true;
    TodayDemoState.save();
    return buildTodayBoard(TodayContext(req));
  });
}

/// 按身份生成当天的看板。
Future<Json> buildTodayBoard(TodayContext ctx) => switch (ctx.account.role) {
  DemoRole.student => buildStudentToday(ctx),
  DemoRole.teacher => buildTeacherToday(ctx, leader: false),
  DemoRole.groupLeader => buildTeacherToday(ctx, leader: true),
  DemoRole.headTeacher => buildHeadTeacherToday(ctx),
  DemoRole.admin => buildAdminToday(ctx),
  DemoRole.principal => buildPrincipalToday(ctx),
  DemoRole.dormManager => buildDormManagerToday(ctx),
};

Future<Json> _find(TodayContext ctx, String id) async {
  final board = await buildTodayBoard(ctx);
  for (final group in todayRows(board['groups'])) {
    for (final step in todayRows(group['steps'])) {
      if (step['id'] == id) return step;
    }
  }
  throw const DemoApiException('这件事已经不在今天的清单里');
}

/// 打勾或取消。只有需要本人确认的事可以手动打勾；练习类的事打勾时把建议时长
/// 记到当天的练习时长里，取消时扣回。
Future<Json> _toggle(DemoRequest req, {required bool done}) async {
  final ctx = TodayContext(req);
  final step = await _find(ctx, req.str('id'));
  if (step['manual'] != true) {
    throw const DemoApiException('完成对应的操作后会自动打勾');
  }
  final id = todayText(step['id']);
  final was = ctx.isDone(id);
  TodayDemoState.toggle(ctx.state, 'done', id, done);
  TodayDemoState.toggle(ctx.state, 'snoozed', id, false);
  if (todayText(step['kind']) == 'practice' && was != done) {
    final minutes = todayInt(step['minutes']);
    final total = todayInt(ctx.state['practice']) + (done ? minutes : -minutes);
    ctx.state['practice'] = total < 0 ? 0 : total;
  }
  TodayDemoState.save();
  return buildTodayBoard(TodayContext(req));
}
