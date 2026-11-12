import '../data/demo_artwork_data.dart';
import '../data/demo_campus_data.dart';
import '../data/demo_marking_data.dart';
import '../demo_accounts.dart';
import '../demo_backend.dart';
import '../demo_clock.dart';
import '../demo_store.dart';
import '../media/demo_media.dart';
import 'content_common.dart';

/// 账号所在校区：学生取阅卷演示数据里的校区，教职工取名册里的校区。
String demoCampusOf(DemoAccount account) {
  final index = account.personIndex;
  if (account.role == DemoRole.student && index != null) {
    return DemoMarkingData.instance.person(index).organizationName;
  }
  return DemoCampusData.staffByUserId(account.userId)?.organizationName ?? '';
}

/// 演示账号的平台资料（`/app/user/myInfo` 的 user）。
Map<String, dynamic> demoUserInfo(DemoAccount account) {
  final profile = DemoStore.map('profile:${account.userId}', () => {});
  final isStudent = account.role == DemoRole.student;
  return <String, dynamic>{
    'id': account.userId,
    'nickname': profile['nickname'] ?? account.name,
    'realname': account.name,
    'headUrl': DemoMedia.url(
      profile['headUrl']?.toString() ??
          (isStudent ? 'asset:assets/demo/avatars/student_female.png' : ''),
    ),
    'mobile': account.mobile,
    'email': profile['email'] ?? '',
    'birthday': profile['birthday'] ?? (isStudent ? '2009-03-15' : ''),
    'gender': profile['gender'] ?? account.gender,
    'province': profile['province'] ?? '甘肃',
    'role': account.roleKey,
    'identity': account.role.label,
    'primary': profile['primary'] ?? (isStudent ? '美术' : '美术教育'),
    'secondary': profile['secondary'] ?? (isStudent ? '素描' : '素描'),
    'school': '示范画室',
    'campus': demoCampusOf(account),
    'targetSchool': profile['targetSchool'] ?? (isStudent ? '西安美术学院' : ''),
    'introduce':
        profile['introduce'] ??
        (isStudent ? '目标：联考素描 90+，色彩稳定在 85 分以上。' : '示范画室教学团队'),
    'vipExpireDate': profile['vipExpireDate'] ?? '2027-12-31 23:59:59',
  };
}

Map<String, dynamic> demoSchool() => <String, dynamic>{
  'id': '1',
  'name': '示范画室',
  'logo': DemoMedia.asset('assets/demo/brand/school_logo.png'),
  'coursewareSwitch': 1,
  'province': '甘肃省',
  'city': '兰州市',
  'district': '城关区',
  'contactPhone': '0931-8888666',
  'introduction':
      '专注美术联考与校考培训，覆盖素描、色彩、速写全科教学。通过阶段测评、原卷复盘与专项训练，持续记录学生的成长。城东、城西、安宁三校区协同教学。',
};

const _provinces = <String>[
  '甘肃', '北京', '天津', '河北', '山西', '内蒙古', '辽宁', '吉林', '黑龙江', '上海', '江苏',
  '浙江', '安徽', '福建', '江西', '山东', '河南', '湖北', '湖南', '广东', '广西', '海南',
  '重庆', '四川', '贵州', '云南', '西藏', '陕西', '青海', '宁夏', '新疆',
];

/// 宿舍查寝时间：学校配置接口与宿管消息共用一处。
const _eveningCheckTime = '22:30';
const _morningCheckTime = '07:20';

/// 消息 targetType，与客户端 `ShellNoticeTargetType` 一致。
const _targetStudy = 1;
const _targetArtwork = 2;
const _targetEbook = 4;
const _targetCampus = 5;
const _targetToolbox = 6;

/// 最近一场已出分的考试（2026 年 9 月月考），与学情中心演示数据一致。
const _latestPublishedExamId = '26';

/// 最近上架的书刊，上架日期与书刊演示数据一致。
const _newBookId = 'eb-monthly-202611';
const _newBookTitle = '画室月刊 2026 年 11 月号（示例）';
final _newBookShelvedAt = DateTime(2026, 11, 1, 10);

DateTime? _parseTime(Object? raw) =>
    DateTime.tryParse((raw?.toString() ?? '').trim().replaceFirst(' ', 'T'));

/// 有对应事件的消息记在事件发生后片刻；事件晚于演示当前时刻（或没有事件）时，
/// 按 [fallback] 从 [DemoClock.now] 往前推。
String _noticeTime(DateTime? event, Duration fallback) {
  final at = event?.add(const Duration(minutes: 2));
  if (at != null && !at.isAfter(DemoClock.now())) {
    return ContentDemo.dateTime(at);
  }
  return ContentDemo.dateTime(DemoClock.ago(fallback));
}

String _personName(int? index) =>
    DemoMarkingData.instance.persons
        .where((p) => p.index == index)
        .firstOrNull
        ?.name ??
    '学生';

/// 点评意见的第一句（与作品详情里的评语同源）。
String _firstClause(String text) {
  final clause = text.split(RegExp('[。；;！？]')).first.trim();
  return clause.isEmpty ? text.trim() : clause;
}

List<Map<String, dynamic>> _artworks() =>
    DemoStore.list(DemoArtworkData.worksKey, DemoArtworkData.seedWorks);

/// 学生最近一份全部老师点评完成的作品：作品、最后一位点评的老师与完成时间。
({Map<String, dynamic> work, Map<String, dynamic> review, DateTime? at})?
_latestCompletedReview(int personIndex) {
  ({Map<String, dynamic> work, Map<String, dynamic> review, DateTime? at})?
  latest;
  for (final work in _artworks()) {
    if (work['personIndex'] != personIndex ||
        DemoArtworkData.aggregate(work).status !=
            DemoArtworkData.statusReviewed) {
      continue;
    }
    for (final review in DemoArtworkData.reviewsOf(work)) {
      final at = _parseTime(review['reviewedTime']);
      final current = latest?.at;
      if (latest == null ||
          (at != null && (current == null || at.isAfter(current)))) {
        latest = (work: work, review: review, at: at);
      }
    }
  }
  return latest;
}

/// 老师队列里最近提交、自己还没点评的作品，以及待点评总数。
({Map<String, dynamic> work, int pending})? _latestPendingFor(String teacherId) {
  final pending = _artworks()
      .where(
        (w) =>
            DemoArtworkData.teacherIdsOf(w).contains(teacherId) &&
            DemoArtworkData.reviewOf(w, teacherId) == null,
      )
      .toList();
  if (pending.isEmpty) {
    return null;
  }
  pending.sort(
    (a, b) => '${b['createTime']}'.compareTo('${a['createTime']}'),
  );
  return (work: pending.first, pending: pending.length);
}

Map<String, dynamic> _notice(
  int id,
  int targetType,
  String content,
  String createTime, {
  String targetId = '',
  bool read = false,
}) => <String, dynamic>{
  'id': id,
  'targetType': targetType,
  'targetId': targetId,
  'content': content,
  'createTime': createTime,
  'read': read,
};

/// 顶栏铃铛里的平台消息：学情、作品点评、书刊上新、工具上新，以及指向智慧校园的提醒。
///
/// 每条消息带跳转目标（targetType + targetId），作品与考试 id 与阅卷演示数据一致；
/// 班级与学校通知的正文仍在智慧校园，这里只放一条提醒，不重复计数。
List<Map<String, dynamic>> _seedNotices(DemoAccount account) {
  final role = account.role;
  final student = role == DemoRole.student;
  final staffStudy = role.teaches || role.managesSchool;
  final notices = <Map<String, dynamic>>[];

  final personIndex = account.personIndex;
  if (student && personIndex != null) {
    final latest = _latestCompletedReview(personIndex);
    if (latest != null) {
      final teacher = DemoArtworkData.teacherName(
        '${latest.review['teacherId']}',
      );
      final comment = _firstClause('${latest.review['content'] ?? ''}');
      notices.add(
        _notice(
          1,
          _targetArtwork,
          '【作品】$teacher老师点评了你的《${latest.work['title']}》'
          '${comment.isEmpty ? '，可以查看分数与评语。' : '：$comment。'}',
          _noticeTime(latest.at, const Duration(hours: 20)),
          targetId: '${latest.work['id']}',
        ),
      );
    }
  }
  final teacherId = account.teacherId;
  if (teacherId != null && role.teaches) {
    final queue = _latestPendingFor(teacherId);
    if (queue != null) {
      final work = queue.work;
      notices.add(
        _notice(
          1,
          _targetArtwork,
          '【作品】${_personName((work['personIndex'] as num?)?.toInt())}'
          '提交了《${work['title']}》，你还有 ${queue.pending} 件作品待点评。',
          _noticeTime(_parseTime(work['createTime']), const Duration(hours: 4)),
          targetId: '${work['id']}',
        ),
      );
    }
  }

  if (student || staffStudy) {
    notices.add(
      _notice(
        2,
        _targetStudy,
        student
            ? '【学情】9 月月考的原卷与评分标准已上线，可在「我的学情」查看各科原卷和档位说明。'
            : '【学情】9 月月考的原卷已全部上线，可在「班级学情」查看分数分布与校区对比。',
        _noticeTime(null, const Duration(hours: 3)),
        targetId: _latestPublishedExamId,
      ),
    );
  }

  final campus = switch (role) {
    DemoRole.student => '【校园】班主任发布了新的班级通知，可在「智慧校园」查看。',
    DemoRole.teacher => '【校园】学校发布了新的教学通知，可在「智慧校园」查看。',
    DemoRole.subjectLead => '【校园】学校发布了新的教学通知，本组老师的课表与签课可在「智慧校园」查看。',
    DemoRole.headTeacher => '【校园】班级有新的请假申请与考勤记录，可在「智慧校园」的班级工作台查看。',
    DemoRole.dormManager => '【校园】今晚晚查寝 21:30 开始、$_eveningCheckTime 截止，请按时到岗。',
    DemoRole.admin => '【校园】有新的请假审批与小课签课待处理，可在「智慧校园」查看。',
    DemoRole.principal => '【校园】校长信箱有新的来信，分管校区的出勤与请假可在「智慧校园」查看。',
  };
  notices.add(
    _notice(
      3,
      _targetCampus,
      campus,
      _noticeTime(null, const Duration(hours: 1, minutes: 20)),
    ),
  );

  if (role != DemoRole.dormManager && !role.managesSchool) {
    notices.add(
      _notice(
        4,
        _targetToolbox,
        '【系统】画室工具箱新增「综合分计算器」与「考场物品清单」，在「备考助手」分组中打开。',
        _noticeTime(null, const Duration(days: 2, hours: 1)),
        targetId: 'score',
        read: true,
      ),
    );
  }

  notices.add(
    _notice(
      5,
      _targetEbook,
      '【书刊】《$_newBookTitle》已上架：考前查漏补缺清单、场景速写透视。',
      _noticeTime(_newBookShelvedAt, const Duration(days: 3)),
      targetId: _newBookId,
      read: true,
    ),
  );

  notices.sort((a, b) => '${b['createTime']}'.compareTo('${a['createTime']}'));
  return notices;
}

void registerPlatformCoreFixtures(DemoRouter r) {
  // ── 账号 ────────────────────────────────────────────────────────────
  r.post('/app/user/mobileLogin', (req) {
    final mobile = req.str('mobile');
    if (req.str('password').isEmpty) {
      throw const DemoApiException('请输入密码');
    }
    final account = DemoAccounts.byMobile(mobile);
    return <String, dynamic>{
      'token': account.token,
      'user': demoUserInfo(account),
    };
  });
  r.post('/app/user/register', (req) {
    final account = DemoAccounts.byMobile(req.str('mobile'));
    return <String, dynamic>{'token': account.token};
  });
  r.post('/app/user/resetPassword', (req) => true);
  r.post('/app/user/sendSmsCode', (req) => true);
  r.post('/app/user/reportCid', (req) => true);
  r.any('/app/user/logout', (req) => true);
  r.any('/app/common/dict/check', (req) => false);
  r.post('/app/user/updatePassword', (req) => true);

  // ── 资料 ────────────────────────────────────────────────────────────
  r.any('/app/user/myInfo', (req) {
    return <String, dynamic>{'user': demoUserInfo(req.account)};
  });
  r.post('/app/user/userinfoUpdate', (req) {
    final account = req.account;
    final profile = DemoStore.map('profile:${account.userId}', () => {});
    for (final key in const [
      'nickname',
      'headUrl',
      'email',
      'birthday',
      'gender',
      'province',
      'primary',
      'secondary',
      'targetSchool',
      'introduce',
    ]) {
      final value = req.bodyMap[key];
      if (value != null) {
        profile[key] = value.toString();
      }
    }
    DemoStore.save('profile:${account.userId}');
    return true;
  });
  r.any('/app/common/provinceCityList', (req) {
    return [
      for (var i = 0; i < _provinces.length; i++)
        <String, dynamic>{'id': i + 1, 'name': _provinces[i]},
    ];
  });

  // ── 学校 ────────────────────────────────────────────────────────────
  r.any('/app/school/v2/user/schoolList', (req) => [demoSchool()]);
  // 科目 id 与课表、考试、作业演示数据一致（素描 38 / 色彩 39 / 速写 40）。
  r.any('/app/school/v2/user/subjectList', (req) {
    const names = ['素描', '色彩', '速写', '美术常识', '文化课', '模拟考试'];
    return [
      for (var i = 0; i < names.length; i++)
        <String, dynamic>{'id': 38 + i, 'name': names[i]},
    ];
  });
  r.any('/app/school/v2/user/schoolConfigList', (req) {
    return [
      <String, dynamic>{
        'configKey': 'dormitoryNightCheckTime',
        'configValue': _eveningCheckTime,
      },
      <String, dynamic>{
        'configKey': 'dormitoryMorningCheckTime',
        'configValue': _morningCheckTime,
      },
    ];
  });

  // ── 消息 ────────────────────────────────────────────────────────────
  // v2：消息带跳转目标（targetType + targetId），旧的本地消息不再沿用。
  String noticesKey(DemoRequest req) => 'notices:v2:${req.account.userId}';
  List<Map<String, dynamic>> notices(DemoRequest req) =>
      DemoStore.list(noticesKey(req), () => _seedNotices(req.account));
  r.any('/app/msg/getUnReadMsgCount', (req) {
    final count = notices(req).where((n) => n['read'] != true).length;
    return <String, dynamic>{'unReadMsgCount': count};
  });
  // 新消息在前，已读消息也返回（客户端置灰显示）。
  r.any('/app/msg/list', (req) {
    final list = [...notices(req)]
      ..sort((a, b) => '${b['createTime']}'.compareTo('${a['createTime']}'));
    return ContentDemo.slice(list, req);
  });
  // 传 ids 时只标这些消息，不传时全部标为已读。
  r.any('/app/msg/updateRead', (req) {
    final ids = req.listOf('ids').map((e) => e.toString()).toSet();
    for (final n in notices(req)) {
      if (ids.isEmpty || ids.contains('${n['id']}')) {
        n['read'] = true;
      }
    }
    DemoStore.save(noticesKey(req));
    return true;
  });

  // ── 公共 ────────────────────────────────────────────────────────────
  r.any('/app/common/v2/configList', (req) {
    return <String, dynamic>{'fileServerUrl': DemoMedia.fileBaseUrl};
  });
  r.post('/app/common/v2/fileUpload', (req) async {
    if (req.files.isEmpty) {
      throw const DemoApiException('请选择要上传的文件');
    }
    final file = req.files.first;
    final ref = await DemoMedia.host(file.bytes, file.fileName);
    return <String, dynamic>{
      'path': ref,
      'url': DemoMedia.url(ref),
      'name': file.fileName,
      'size': file.bytes.length,
    };
  });
}
