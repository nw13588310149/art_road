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

/// 顶栏铃铛里的平台消息：学情、作品点评与系统消息。
///
/// 班级与学校通知属于智慧校园，不放在这里，避免两处未读数重复计算。
List<Map<String, dynamic>> _seedNotices(DemoAccount account) {
  final student = account.role == DemoRole.student;
  final reviewer =
      account.role == DemoRole.teacher || account.role == DemoRole.headTeacher;
  String at(Duration ago) => ContentDemo.dateTime(DemoClock.ago(ago));
  return <Map<String, dynamic>>[
    {
      'id': 1,
      'targetType': 1,
      'content': student
          ? '【学情】9 月月考的原卷与评分标准已上线，可在「我的学情」查看各科原卷和档位说明。'
          : '【学情】9 月月考的原卷已全部上线，可在「班级学情」查看分数分布与校区对比。',
      'createTime': at(const Duration(hours: 3)),
      'read': false,
    },
    if (student || reviewer)
      {
        'id': 2,
        'targetType': 2,
        'content': student
            ? '【作品】李静老师点评了你的《石膏头像结构练习》：结构交代清楚，暗部再整体一些。'
            : '【作品】有学生提交了新作品，可在「作品点评」查看并点评。',
        'createTime': at(const Duration(hours: 20)),
        'read': false,
      },
    {
      'id': 3,
      'targetType': 3,
      'content': '【系统】画室工具箱新增「考试倒计时」与「速写计时练习」，可在首页或侧栏打开。',
      'createTime': at(const Duration(days: 2, hours: 1)),
      'read': false,
    },
  ];
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
        'configValue': '22:10',
      },
      <String, dynamic>{
        'configKey': 'dormitoryMorningCheckTime',
        'configValue': '07:10',
      },
    ];
  });

  // ── 消息 ────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> notices(DemoRequest req) => DemoStore.list(
    'notices:${req.account.userId}',
    () => _seedNotices(req.account),
  );
  r.any('/app/msg/getUnReadMsgCount', (req) {
    final count = notices(req).where((n) => n['read'] != true).length;
    return <String, dynamic>{'unReadMsgCount': count};
  });
  r.any('/app/msg/list', (req) {
    return notices(req).where((n) => n['read'] != true).toList();
  });
  r.any('/app/msg/updateRead', (req) {
    final list = notices(req);
    for (final n in list) {
      n['read'] = true;
    }
    DemoStore.save('notices:${req.account.userId}');
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
