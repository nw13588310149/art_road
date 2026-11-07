import 'dart:convert';

import '../../data/demo_campus_data.dart';
import '../../demo_accounts.dart';
import '../../demo_backend.dart';
import '../../demo_socket_bridge.dart';
import '../../demo_store.dart';
import 'campus_a_common.dart';
import 'campus_b_common.dart';

/// 群聊成员（教职工或学生）。
class CampusChatPerson {
  const CampusChatPerson({
    required this.userId,
    required this.name,
    required this.role,
    required this.gender,
    required this.mobile,
    this.headRef = '',
  });

  final String userId;
  final String name;

  /// teacher / student。
  final String role;
  final String gender;
  final String mobile;
  final String headRef;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': userId,
    'userId': userId,
    'realname': name,
    'nickname': name,
    'role': role,
    'headUrl': CampusA.media(headRef),
    'mobile': mobile,
    'gender': gender,
  };
}

/// 群聊：班级群 + 小课群 + 宿舍群 + 教职工群。
class CampusChatGroup {
  const CampusChatGroup({
    required this.id,
    required this.name,
    required this.type,
    required this.headUserId,
    required this.staffUserIds,
    required this.studentIndices,
    this.logoRef = 'asset:assets/demo/brand/school_logo.png',
  });

  final String id;
  final String name;

  /// 0 大班 / 1 小班 / 2 教职工 / 3 宿舍。
  final int type;
  final String headUserId;
  final List<String> staffUserIds;
  final List<int> studentIndices;
  final String logoRef;

  List<String> get memberIds => [
    ...staffUserIds,
    for (final index in studentIndices) CampusA.studentUserId(index),
  ];

  int get memberCount => staffUserIds.length + studentIndices.length;
}

/// 群聊接口 `/app/school/v2/chat/*`。
///
/// 发送消息后 2–4 秒由老师或同学自动回复：回复写入消息表（`syncMsg` 可拉到），
/// 同时经 [DemoSocketBridge] 下发与线上一致的 WS 帧，群聊页实时显示。
abstract final class CampusAChat {
  static const _messagesKey = 'campusA:chat:messages';
  static const _groupStateKey = 'campusA:chat:groups';

  static final List<CampusChatGroup> groups = _buildGroups();
  static final Map<String, CampusChatPerson> _people = _buildPeople();

  /// 每个账号最近一次拉取群列表的时间：此前已可见的消息已计入列表未读数，
  /// `syncMsg` 只补这之后出现的消息，避免会话未读被重复累加。
  static final Map<String, int> _listedAt = <String, int>{};

  static String _staffUid(String id) => CampusA.staff(id).userId;

  static List<CampusChatGroup> _buildGroups() {
    final admin = _staffUid('t-9');
    final dorm = _staffUid('d-1');
    final girls = [
      for (final p in CampusA.persons)
        if (p.gender == '女') p.index,
    ];
    final boys = [
      for (final p in CampusA.persons)
        if (p.gender == '男') p.index,
    ];
    return [
      for (final c in DemoCampusData.classes)
        CampusChatGroup(
          id: c.id,
          name: c.name,
          type: 0,
          headUserId: CampusA.headTeacherOf(c).userId,
          staffUserIds: [
            for (final s in CampusA.teachersOf(c)) s.userId,
            admin,
          ],
          studentIndices: [for (final p in c.students) p.index],
        ),
      CampusChatGroup(
        id: '511',
        name: '色彩周末提高组',
        type: 1,
        headUserId: _staffUid('t-3'),
        staffUserIds: [_staffUid('t-3')],
        studentIndices: const [1, 4, 6, 9, 12, 15],
        logoRef: 'asset:assets/demo/art/color-still-1.jpg',
      ),
      CampusChatGroup(
        id: '520',
        name: '女生公寓1号楼',
        type: 3,
        headUserId: dorm,
        staffUserIds: [dorm],
        studentIndices: girls,
      ),
      CampusChatGroup(
        id: '521',
        name: '男生公寓2号楼',
        type: 3,
        headUserId: dorm,
        staffUserIds: [dorm],
        studentIndices: boys,
      ),
      CampusChatGroup(
        id: '590',
        name: '示范画室教职工群',
        type: 2,
        headUserId: admin,
        staffUserIds: [for (final s in DemoCampusData.staff) s.userId],
        studentIndices: const [],
      ),
    ];
  }

  static Map<String, CampusChatPerson> _buildPeople() {
    final map = <String, CampusChatPerson>{};
    for (final s in DemoCampusData.staff) {
      map[s.userId] = CampusChatPerson(
        userId: s.userId,
        name: s.name,
        role: 'teacher',
        gender: s.gender,
        mobile: s.phone,
      );
    }
    for (final p in CampusA.persons) {
      final uid = CampusA.studentUserId(p.index);
      map[uid] = CampusChatPerson(
        userId: uid,
        name: p.name,
        role: 'student',
        gender: p.gender,
        mobile: p.phoneMasked,
        headRef: p.avatarRef,
      );
    }
    return map;
  }

  static CampusChatGroup? groupById(String id) {
    for (final g in groups) {
      if (g.id == id) {
        return g;
      }
    }
    return null;
  }

  static List<CampusChatGroup> groupsOf(DemoAccount account) {
    if (account.role == DemoRole.admin) {
      return groups;
    }
    if (CampusA.isStudent(account)) {
      final index = CampusA.personIndexOf(account);
      return [
        for (final g in groups)
          if (g.studentIndices.contains(index)) g,
      ];
    }
    return [
      for (final g in groups)
        if (g.staffUserIds.contains(account.userId)) g,
    ];
  }

  static CampusChatGroup _memberGroup(DemoAccount account, String classId) {
    for (final g in groupsOf(account)) {
      if (g.id == classId) {
        return g;
      }
    }
    throw const DemoApiException('你不在该群聊中');
  }

  static bool _canManage(DemoAccount account, CampusChatGroup group) =>
      account.role == DemoRole.admin || group.headUserId == account.userId;

  // ── 群状态（公告） ──────────────────────────────────────────────────

  static Map<String, dynamic> _groupState() =>
      DemoStore.map(_groupStateKey, _seedGroupState);

  static Map<String, dynamic> _seedGroupState() {
    Map<String, dynamic> notice(String text, String by, int hoursAgo) =>
        <String, dynamic>{
          'announcement': text,
          'announcementUserName': by,
          'announcementTime': CampusA.ago(hours: hoursAgo),
        };
    return <String, dynamic>{
      '501': notice(
        '本周六 08:30 素描模拟考试（城东校区考试大厅），请提前 15 分钟入场；晚查寝 22:30 前完成人脸打卡。',
        '赵雪',
        26,
      ),
      '502': notice('本周色彩写生分组名单已发在群里，请按小组准备工具，周六 13:30 校门口集合。', '王海波', 30),
      '503': notice('校考班本周加练速写默写，晚自习延长 30 分钟，请提前和家长说明。', '周强', 50),
      '511': notice('每周六 13:30 校门口集合外出写生，周日上午集中改画，写生工具自备。', '刘芳', 70),
      '520': notice('晚查寝 21:30—22:30，晨查寝 06:40—07:20；严禁使用电热毯、卷发棒等大功率电器。', '马红梅', 40),
      '521': notice('晚查寝 21:30—22:30，晨查寝 06:40—07:20；画具统一放在宿舍门后，过道保持畅通。', '马红梅', 40),
      '590': notice('冲刺阶段每周六模考、周日阅卷，请各教研组按排班参加；阅卷评分标准见群内消息。', '王敏', 20),
    };
  }

  static Map<String, dynamic> _stateOf(String classId) {
    final state = _groupState();
    final value = state[classId];
    if (value is Map<String, dynamic>) {
      return value;
    }
    final created = <String, dynamic>{};
    state[classId] = created;
    return created;
  }

  /// 班级群公告（「我的班级」信息卡底部展示）。
  static String announcementOf(String classId) =>
      _stateOf(classId)['announcement']?.toString() ?? '';

  // ── 消息 ────────────────────────────────────────────────────────────

  static List<Map<String, dynamic>> _messages() =>
      DemoStore.list(_messagesKey, _seedMessages);

  static int _idOf(Map<String, dynamic> m) =>
      int.tryParse(m['id']?.toString() ?? '') ?? 0;

  static bool _visible(Map<String, dynamic> m, int nowMs) {
    final at = (m['visibleAt'] as num?)?.toInt();
    return at == null || at <= nowMs;
  }

  /// 某群当前可见的消息，按 id 升序。
  static List<Map<String, dynamic>> _groupMessages(String classId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return [
      for (final m in _messages())
        if (m['classId'] == classId && _visible(m, now)) m,
    ]..sort((a, b) => _idOf(a).compareTo(_idOf(b)));
  }

  static String _uid(String ref) {
    if (ref.startsWith('s:')) {
      return _staffUid(ref.substring(2));
    }
    if (ref.startsWith('p:')) {
      return CampusA.studentUserId(int.parse(ref.substring(2)));
    }
    return '0';
  }

  static String _videoShare(String title, String video, String cover) =>
      jsonEncode(<String, dynamic>{
        'name': title,
        'title': title,
        'url': video,
        'coverImg': cover,
        'duration': '01:32',
      });

  static List<Map<String, dynamic>> _seedMessages() {
    final seeds = <(String, int, String, int, String, String)>[
      ('501', 2890, '0', 0, '入群通知 赵雪老师邀请 14 位同学和各科任课老师加入了群聊', ''),
      ('501', 2880, 's:t-4', 1, '各位同学，本周六上午 8:30 进行素描模拟考试，考场在城东校区考试大厅，请提前 15 分钟到场，自带画板和工具。', ''),
      ('501', 2870, 's:t-1', 1, '素描模考题目方向：石膏像或真人头像二选一，构图注意饱满，时间严格控制在 3 小时以内。', ''),
      ('501', 2862, 'p:3', 1, '收到，老师，铅笔需要准备哪几种型号？', ''),
      ('501', 2858, 's:t-1', 1, '2B 到 8B 都备齐，再带一块可塑橡皮和纸巾。暗部的大关系一定要整体，别画花了。', ''),
      ('501', 1500, 'p:1', 1, '李老师，昨天的头像作业我按您说的把暗部压重了，您有空帮我看看吗？', ''),
      ('501', 1499, 'p:1', 2, 'asset:assets/demo/art/sketch-portrait-1.jpg', ''),
      ('501', 1490, 's:t-1', 1, '比上次进步很多，明暗交界线再肯定一点，耳朵的结构交代清楚就更好了。', ''),
      ('501', 1320, 's:t-3', 1, '色彩组提醒：下周一开始静物写生，大家检查一下水粉颜料，白色和柠檬黄用得快的提前补。', ''),
      ('501', 1318, 's:t-3', 2, 'asset:assets/demo/art/color-still-2.jpg', ''),
      ('501', 1317, 's:t-3', 1, '这是今天的课堂示范，注意冷暖对比和衬布的转折。', ''),
      ('501', 1310, 'p:6', 1, '刘老师这张好好看，背景的灰色是怎么调的？', ''),
      ('501', 1302, 's:t-3', 1, '群青 + 熟褐 + 一点白，再根据环境色加一点紫，别调得太脏。', ''),
      ('501', 600, 's:t-4', 1, '今晚 19:00 速写课改到速写教室 C，记得带速写本，今晚画组合人物动态。', ''),
      ('501', 598, 's:t-4', 3, _videoShare('速写线条练习示范', 'asset:assets/demo/video/hatching.mp4', 'asset:assets/demo/art/speed-figure-2.jpg'), 'video'),
      ('501', 420, 'p:9', 2, 'asset:assets/demo/art/speed-group-1.jpg', ''),
      ('501', 419, 'p:9', 1, '赵老师，这是今晚的速写作业。', ''),
      ('501', 405, 's:t-4', 1, '画面组织得不错，人物之间的前后关系再拉开一些。', ''),
      ('501', 300, 's:t-7', 1, '美术常识小测周三晚自习进行，范围：中国美术史（隋唐—宋元）+ 西方印象派，复习资料已上传云盘。', ''),
      ('501', 296, 'p:12', 1, '收到。', ''),
      ('501', 180, 's:t-8', 1, '文化课同学注意：本周语文默写和英语单词抽查照常进行，专业和文化课都要兼顾。', ''),
      ('501', 60, 's:t-4', 1, '今天降温了，晚上回宿舍注意保暖，22:30 前按时归寝，宿管老师会准时查寝。', ''),
      ('502', 2400, 's:t-5', 1, '本周六下午色彩写生，分组名单已发群公告，请各组长带好集体颜料。', ''),
      ('502', 2390, 'p:4', 1, '王老师，写生地点是中山桥吗？', ''),
      ('502', 2385, 's:t-5', 1, '对，中山桥到白塔山一线，13:30 校门口集合乘车。', ''),
      ('502', 1200, 's:t-2', 2, 'asset:assets/demo/art/sketch-still-2.jpg', ''),
      ('502', 1199, 's:t-2', 1, '素描静物示范，重点看陶罐的高光和反光处理。', ''),
      ('502', 240, 'p:7', 1, '张老师，明天的素描课需要带石膏像吗？', ''),
      ('502', 150, 's:t-2', 1, '不用，明天画静物，画室里都准备好了。', ''),
      ('503', 2000, 's:t-6', 1, '校考班同学注意：中国美术学院、西安美术学院校考报名时间已公布，请在班会前确认报考院校。', ''),
      ('503', 1990, 'p:5', 1, '周老师，校考的创作题需要提前准备吗？', ''),
      ('503', 1980, 's:t-6', 1, '需要，每周交一张命题创作小稿，下周开始点评。', ''),
      ('503', 700, 's:t-6', 2, 'asset:assets/demo/art/speed-scene-1.jpg', ''),
      ('503', 699, 's:t-6', 1, '场景速写参考，注意透视和人物比例关系。', ''),
      ('503', 260, 'p:8', 1, '收到，周老师。', ''),
      ('511', 4300, 's:t-3', 1, '欢迎加入色彩周末提高组，每周六下午外出写生，周日上午集中改画。', ''),
      ('511', 4290, 's:t-3', 2, 'asset:assets/demo/art/color-landscape-1.jpg', ''),
      ('511', 4288, 's:t-3', 1, '上周五泉山写生的示范稿，大家感受一下天空和远山的冷暖变化。', ''),
      ('511', 1700, 'p:4', 1, '刘老师，这周还去五泉山吗？', ''),
      ('511', 1690, 's:t-3', 1, '这周去黄河边，记得带小马扎和水桶，13:30 校门口集合。', ''),
      ('511', 900, 'p:1', 2, 'asset:assets/demo/art/color-flower-1.jpg', ''),
      ('511', 899, 'p:1', 1, '老师，这是我上次的花卉写生，感觉画面有点灰。', ''),
      ('511', 320, 's:t-3', 1, '纯度对比不够，主体花朵的颜色再提一提，背景适当降低纯度，画面就透气了。', ''),
      ('511', 310, 'p:15', 1, '周日改画能带上次模考的色彩卷子吗？', ''),
      ('511', 305, 's:t-3', 1, '可以，把模考卷子都带来，我们逐张分析色调问题。', ''),
      ('520', 3000, 's:d-1', 1, '各位同学，本周宿舍卫生检查周三下午进行，请提前整理床铺和桌面，画具统一收纳。', ''),
      ('520', 2990, 's:d-1', 1, '晚查寝时间 21:30—22:30，请在 22:30 前完成人脸打卡，晚归需提前向班主任报备。', ''),
      ('520', 1600, 'p:7', 1, '马老师，101 宿舍的热水器有点问题，水一直不热。', ''),
      ('520', 1590, 's:d-1', 1, '收到，已经报修，明天上午维修师傅过来处理。', ''),
      ('520', 1585, 'p:7', 1, '谢谢马老师。', ''),
      ('520', 700, 's:d-1', 1, '提醒：严禁使用电热毯、卷发棒等大功率电器，周五会进行用电安全检查。', ''),
      ('520', 120, 's:d-1', 1, '今晚降温，大家把窗户关好，画板和画架不要堆在过道里。', ''),
      ('521', 2600, 's:d-1', 1, '男生公寓 2 号楼本周轮到 101、102 宿舍值日，请按值日表打扫公共区域。', ''),
      ('521', 1400, 'p:10', 1, '马老师，宿舍楼几点关门？', ''),
      ('521', 1395, 's:d-1', 1, '晚上 22:30 关门，22:30 之后回来要登记晚归并通知班主任。', ''),
      ('521', 640, 's:d-1', 1, '昨晚有同学晚归未报备，请大家遵守作息，冲刺阶段休息好才能画好。', ''),
      ('521', 200, 'p:2', 1, '收到，马老师。', ''),
      ('590', 2200, 's:t-9', 1, '各位老师，本周六素描模拟考试由李静老师统筹，阅卷安排在周日上午，请按分组参加。', ''),
      ('590', 2190, 's:t-1', 1, '收到，阅卷评分标准今晚发到群里。', ''),
      ('590', 2100, 's:t-1', 1, '素描评分标准：构图 20 分、造型 30 分、明暗与空间 30 分、整体效果 20 分；分差超过 10 分进入仲裁。', ''),
      ('590', 1800, 's:t-3', 1, '色彩组周日下午阅卷，需要两间画室摆放试卷。', ''),
      ('590', 1790, 's:t-9', 1, '已安排城东校区 2 楼 201、202 画室。', ''),
      ('590', 1000, 's:d-1', 1, '提醒各位班主任：近期有同学晚归较多，请在班级群里再强调一下归寝纪律。', ''),
      ('590', 990, 's:t-4', 1, '好的，1 班我今晚开班会再强调。', ''),
      ('590', 500, 's:t-6', 1, '校考班这周开始加练速写默写，晚自习延长 30 分钟。', ''),
      ('590', 260, 's:t-9', 1, '本月第三个周日进行月考，请各教研组本周内提交试题。', ''),
      ('590', 100, 's:t-9', 1, '下周二上午 10:00 召开教学研讨会，地点城东校区会议室，请各教研组长准备汇报。', ''),
    ];
    // 分钟数按白天时间往前数（跳过夜间），消息都落在 08:30–21:30 之间。
    final ordered = [...seeds]..sort((a, b) => b.$2.compareTo(a.$2));
    return [
      for (var i = 0; i < ordered.length; i++)
        <String, dynamic>{
          'id': '${50001 + i}',
          'classId': ordered[i].$1,
          'fromUserId': _uid(ordered[i].$3),
          'type': ordered[i].$4,
          'content': ordered[i].$5,
          'param1': ordered[i].$6,
          'param2': '',
          'createTime': CampusA.dateTime(
            cbAgo(Duration(minutes: ordered[i].$2)),
          ),
        },
    ];
  }

  static String _resolveContent(int type, String content) {
    if (type == 2) {
      return CampusA.media(content);
    }
    if (type == 3 && content.startsWith('{')) {
      try {
        final map = Map<String, dynamic>.from(jsonDecode(content) as Map);
        for (final key in const ['url', 'path', 'coverImg', 'fileUrl']) {
          final value = map[key];
          if (value is String && value.isNotEmpty) {
            map[key] = CampusA.media(value);
          }
        }
        return jsonEncode(map);
      } catch (_) {
        return content;
      }
    }
    return content;
  }

  static String _storeContent(int type, String content) {
    if (type == 2) {
      return CampusA.toRef(content);
    }
    if (type == 3 && content.startsWith('{')) {
      try {
        final map = Map<String, dynamic>.from(jsonDecode(content) as Map);
        for (final key in const ['url', 'path', 'coverImg', 'fileUrl']) {
          final value = map[key];
          if (value is String && value.isNotEmpty) {
            map[key] = CampusA.toRef(value);
          }
        }
        return jsonEncode(map);
      } catch (_) {
        return content;
      }
    }
    return content;
  }

  /// 接口 / WS 帧中的消息体。
  static Map<String, dynamic> _output(Map<String, dynamic> m) {
    final from = m['fromUserId']?.toString() ?? '0';
    final person = _people[from];
    final type = (m['type'] as num?)?.toInt() ?? 1;
    final content = _resolveContent(type, m['content']?.toString() ?? '');
    final head = CampusA.media(person?.headRef ?? '');
    return <String, dynamic>{
      'id': m['id'],
      'msgId': m['id'],
      'classId': m['classId'],
      'fromUserId': from,
      'userName': person?.name ?? '',
      'nickname': person?.name ?? '',
      'userHead': head,
      'headUrl': head,
      'type': type,
      'content': content,
      'text': type == 0 ? content : '',
      'param1': m['param1'] ?? '',
      'param2': m['param2'] ?? '',
      'param3': '',
      'param4': '',
      'param5': '',
      'createTime': m['createTime'],
    };
  }

  // ── 个人设置（已读 / 免打扰 / 置顶） ────────────────────────────────

  static String _prefsKey(DemoAccount account) =>
      'campusA:chat:prefs:${account.userId}';

  static const _seedUnread = <String, int>{
    '501': 0,
    '502': 1,
    '503': 0,
    '511': 2,
    '520': 1,
    '521': 2,
    '590': 3,
  };

  static Map<String, dynamic> _prefs(DemoAccount account) =>
      DemoStore.map(_prefsKey(account), () {
        final lastRead = <String, dynamic>{};
        for (final g in groups) {
          final list = _groupMessages(g.id);
          final unread = _seedUnread[g.id] ?? 0;
          final index = list.length - unread - 1;
          lastRead[g.id] = index >= 0 ? list[index]['id'] : '0';
        }
        return <String, dynamic>{
          'lastRead': lastRead,
          'mute': <String, dynamic>{},
          'pin': <String, dynamic>{'501': false},
        };
      });

  static Map<String, dynamic> _prefMap(DemoAccount account, String name) {
    final prefs = _prefs(account);
    final value = prefs[name];
    if (value is Map<String, dynamic>) {
      return value;
    }
    final created = <String, dynamic>{};
    prefs[name] = created;
    return created;
  }

  static void _markRead(DemoAccount account, String classId) {
    final list = _groupMessages(classId);
    if (list.isEmpty) {
      return;
    }
    _prefMap(account, 'lastRead')[classId] = list.last['id'];
    DemoStore.save(_prefsKey(account));
  }

  static int _unread(DemoAccount account, String classId) {
    final lastRead =
        int.tryParse(_prefMap(account, 'lastRead')[classId]?.toString() ?? '') ??
        0;
    return _groupMessages(classId)
        .where((m) => _idOf(m) > lastRead && m['fromUserId'] != account.userId)
        .length;
  }

  static bool _flag(DemoAccount account, String name, String classId) =>
      _prefMap(account, name)[classId] == true;

  // ── 群信息 ──────────────────────────────────────────────────────────

  static Map<String, dynamic> _summary(
    DemoAccount account,
    CampusChatGroup g,
  ) {
    final list = _groupMessages(g.id);
    final latest = list.isEmpty ? null : list.last;
    final mute = _flag(account, 'mute', g.id);
    final pin = _flag(account, 'pin', g.id);
    return <String, dynamic>{
      'id': g.id,
      'classId': g.id,
      'name': g.name,
      'groupName': g.name,
      'className': g.name,
      'type': g.type,
      'logo': CampusA.media(g.logoRef),
      'memberCount': g.memberCount,
      'unreadCount': _unread(account, g.id),
      'doNotDisturb': mute ? 1 : 0,
      'isPinned': pin ? 1 : 0,
      'latestMsg': latest == null ? null : _output(latest),
      'lastTime': latest?['createTime'],
      'announcement': announcementOf(g.id),
    };
  }

  static List<Map<String, dynamic>> _members(CampusChatGroup g) => [
    for (final id in g.memberIds) ?_people[id]?.toJson(),
  ];

  static Map<String, dynamic> _detail(DemoAccount account, CampusChatGroup g) {
    final state = _stateOf(g.id);
    final head = _people[g.headUserId];
    final mute = _flag(account, 'mute', g.id);
    final pin = _flag(account, 'pin', g.id);
    final manage = _canManage(account, g);
    return <String, dynamic>{
      'id': g.id,
      'classId': g.id,
      'name': g.name,
      'groupName': g.name,
      'logo': CampusA.media(g.logoRef),
      'schoolClass': <String, dynamic>{
        'id': g.id,
        'name': g.name,
        'groupName': g.name,
        'logo': CampusA.media(g.logoRef),
        'type': g.type,
        'announcement': state['announcement'] ?? '',
        'headTeacherId': g.headUserId,
      },
      'announcement': state['announcement'] ?? '',
      'announcementUserName': state['announcementUserName'] ?? '',
      'announcementTime': state['announcementTime'],
      'headTeacher': head?.toJson(),
      'teacherList': [
        for (final id in g.staffUserIds)
          if (id != g.headUserId) ?_people[id]?.toJson(),
      ],
      'studentList': [
        for (final index in g.studentIndices)
          ?_people[CampusA.studentUserId(index)]?.toJson(),
      ],
      'memberCount': g.memberCount,
      'doNotDisturb': mute,
      'isPinned': pin ? 1 : 0,
      'isHeadTeacher': g.headUserId == account.userId,
      'isAdmin': account.role == DemoRole.admin,
      'canEditAnnouncement': manage,
    };
  }

  // ── 自动回复 ────────────────────────────────────────────────────────

  static bool _has(String text, List<String> words) =>
      words.any(text.contains);

  static String? _subjectTeacher(CampusChatGroup g, String subject) {
    for (final id in g.staffUserIds) {
      final s = DemoCampusData.staffByUserId(id);
      if (s != null && s.subject == subject) {
        return id;
      }
    }
    return null;
  }

  static String _pick(List<String> pool, int seed) => pool[seed % pool.length];

  /// 选出回复人和回复内容；无合适回复人时返回 null。
  static (String, String)? _reply(
    CampusChatGroup g,
    DemoAccount sender,
    int type,
    String text,
  ) {
    final seed = CampusA.hash('${DateTime.now().millisecondsSinceEpoch}$text');
    final fromStudent = CampusA.isStudent(sender);
    final classmates = [
      for (final index in g.studentIndices)
        if (CampusA.studentUserId(index) != sender.userId)
          CampusA.studentUserId(index),
    ];
    if (!fromStudent) {
      if (g.type == 2) {
        final others = [
          for (final id in g.staffUserIds)
            if (id != sender.userId) id,
        ];
        if (others.isEmpty) return null;
        final responder = _has(text, ['查寝', '宿舍', '归寝'])
            ? _staffUid('d-1')
            : (_has(text, ['阅卷', '素描']) ? _staffUid('t-1') : _pick(others, seed));
        return (
          responder == sender.userId ? _pick(others, seed + 1) : responder,
          _pick(const [
            '收到，我这边马上安排。',
            '好的，没问题，会后同步给组里的老师。',
            '收到～我们组周日上午全员到岗。',
          ], seed),
        );
      }
      if (classmates.isEmpty) return null;
      return (
        _pick(classmates, seed),
        _pick(const ['收到，老师。', '好的老师，马上准备。', '明白了，谢谢老师。'], seed),
      );
    }

    if (g.type == 3) {
      return (
        g.headUserId,
        _has(text, ['坏', '修', '热水', '灯', '空调'])
            ? '收到，我这就联系维修师傅，今天之内处理好。'
            : '收到～宿舍有问题随时在群里说，记得 22:30 前按时归寝哦。',
      );
    }
    final head = g.headUserId;
    String teacherFor(String subject) => _subjectTeacher(g, subject) ?? head;
    if (type == 2) {
      return (
        g.type == 1 ? head : teacherFor('素描'),
        _pick(const [
          '收到作品了，整体关系不错，注意画面的主次，局部刻画再深入一点。',
          '这张进步很明显，形准了以后再把暗部整体压一压，画面会更有分量。',
        ], seed),
      );
    }
    if (_has(text, ['素描', '石膏', '头像', '明暗', '铅笔'])) {
      return (
        teacherFor('素描'),
        '这个问题问得好：先把明暗交界线找准，再往暗部整体过渡。晚自习带着画到素描教室 A，我当面帮你改。',
      );
    }
    if (_has(text, ['色彩', '颜料', '水粉', '色调', '写生'])) {
      return (
        teacherFor('色彩'),
        '色彩先看大关系，冷暖拉开了画面就不会灰。明天课上把画带来，我们一起分析色调。',
      );
    }
    if (_has(text, ['速写', '动态', '默写'])) {
      return (
        teacherFor('速写'),
        '速写先抓动态线和重心，比例对了再收拾细节。今晚速写课我再示范一次。',
      );
    }
    if (_has(text, ['常识', '美术史', '小测'])) {
      return (
        teacherFor('美术常识'),
        '复习资料在云盘「美术常识」文件夹里，重点看隋唐到宋元那一章，小测前我再划一次重点。',
      );
    }
    if (_has(text, ['请假', '宿舍', '查寝', '回家', '家长'])) {
      return (head, '收到。请假记得在「请假管理」里提交申请，家长同意后我会尽快审批。');
    }
    if (_has(text, ['作业', '交', '截止'])) {
      return (head, '作业在「我的作业」里按时提交就行，老师们批阅后会给你反馈。');
    }
    if (_has(text, ['考试', '模考', '月考', '联考', '统考'])) {
      return (head, '模考按联考标准计时，考前一晚把画具检查一遍，早点休息，保持状态。');
    }
    if (classmates.isNotEmpty && seed % 3 != 0) {
      return (
        _pick(classmates, seed),
        _pick(const [
          '同感，今晚一起去画室加练吧',
          '哈哈收到～',
          '我这有多的柠檬黄和白色，需要的话找我拿',
          '联考加油，一起冲刺。',
        ], seed),
      );
    }
    return (head, '好的，收到～有问题随时在群里问，老师们都会看。');
  }

  static void _scheduleReply(
    CampusChatGroup g,
    DemoAccount sender,
    int type,
    String text,
  ) {
    final reply = _reply(g, sender, type, text);
    if (reply == null || reply.$1 == sender.userId) {
      return;
    }
    final now = DateTime.now();
    final delay = Duration(milliseconds: 2200 + CampusA.hash(text) % 1800);
    final at = now.add(delay);
    final message = <String, dynamic>{
      'id': DemoStore.nextId(),
      'classId': g.id,
      'fromUserId': reply.$1,
      'type': 1,
      'content': reply.$2,
      'param1': '',
      'param2': '',
      'createTime': CampusA.dateTime(at),
      'visibleAt': at.millisecondsSinceEpoch,
      'live': true,
    };
    _messages().add(message);
    DemoStore.save(_messagesKey);
    DemoSocketBridge.instance.pushChatMessage(_output(message), delay: delay);
  }

  // ── 接口 ────────────────────────────────────────────────────────────

  static void register(DemoRouter r) {
    const base = '/app/school/v2/chat';

    r.post('$base/classList', (req) {
      final account = req.account;
      _listedAt[account.userId] = DateTime.now().millisecondsSinceEpoch;
      final list = [for (final g in groupsOf(account)) _summary(account, g)]
        ..sort(
          (a, b) => (b['lastTime']?.toString() ?? '').compareTo(
            a['lastTime']?.toString() ?? '',
          ),
        );
      return list;
    });

    r.post('$base/classDetail', (req) {
      final account = req.account;
      return _detail(account, _memberGroup(account, req.str('classId')));
    });

    r.post('$base/msgList', (req) {
      final account = req.account;
      final group = _memberGroup(account, req.str('classId'));
      final offset = int.tryParse(req.str('offsetMsgId', '0')) ?? 0;
      final size = req.intOf('size', 20).clamp(1, 100);
      final all = _groupMessages(group.id);
      final page = [
        for (final m in all.reversed)
          if (offset <= 0 || _idOf(m) < offset) m,
      ].take(size).toList();
      if (offset <= 0) {
        _markRead(account, group.id);
      }
      return <String, dynamic>{
        'offsetMsgId': page.isEmpty ? '0' : page.last['id'],
        'msgList': [for (final m in page) _output(m)],
        'userList': _members(group),
        'classList': [_summary(account, group)],
      };
    });

    r.post('$base/syncMsg', (req) {
      final account = req.account;
      final offset = int.tryParse(req.str('offsetMsgId', '0')) ?? 0;
      if (offset <= 0) {
        return <String, dynamic>{
          'offsetMsgId': '0',
          'msgList': const <Object>[],
          'userList': const <Object>[],
        };
      }
      final mine = {for (final g in groupsOf(account)) g.id: g};
      final now = DateTime.now().millisecondsSinceEpoch;
      final since = _listedAt[account.userId] ?? 0;
      final list = [
        for (final m in _messages())
          if (m['live'] == true &&
              mine.containsKey(m['classId']) &&
              _idOf(m) > offset &&
              _visible(m, now) &&
              ((m['visibleAt'] as num?)?.toInt() ?? 0) > since &&
              m['fromUserId'] != account.userId)
            m,
      ]..sort((a, b) => _idOf(a).compareTo(_idOf(b)));
      final page = list.take(req.intOf('size', 20).clamp(1, 100)).toList();
      final involved = {for (final m in page) m['classId'].toString()};
      return <String, dynamic>{
        'offsetMsgId': page.isEmpty ? '$offset' : page.last['id'],
        'msgList': [for (final m in page) _output(m)],
        'userList': [
          for (final id in involved)
            if (mine[id] != null) ..._members(mine[id]!),
        ],
      };
    });

    r.post('$base/sendMsg', (req) {
      final account = req.account;
      final group = _memberGroup(account, req.str('classId'));
      final type = req.intOf('type', 1);
      final content = req.str('content');
      if (content.isEmpty) {
        throw const DemoApiException('消息内容不能为空');
      }
      if (type < 1 || type > 3) {
        throw const DemoApiException('暂不支持该消息类型');
      }
      final now = DateTime.now();
      final message = <String, dynamic>{
        'id': DemoStore.nextId(),
        'classId': group.id,
        'fromUserId': account.userId,
        'type': type,
        'content': _storeContent(type, content),
        'param1': req.str('param1'),
        'param2': req.str('param2'),
        'createTime': CampusA.dateTime(now),
        'visibleAt': now.millisecondsSinceEpoch,
        'live': true,
      };
      _messages().add(message);
      DemoStore.save(_messagesKey);
      _markRead(account, group.id);
      _scheduleReply(group, account, type, type == 1 ? content : '');
      return <String, dynamic>{
        'msgId': message['id'],
        'id': message['id'],
        'createTime': message['createTime'],
      };
    });

    r.post('$base/deleteMsg', (req) {
      final account = req.account;
      final id = req.str('msgId');
      final message = CampusA.findById(_messages(), id);
      if (message == null) {
        throw const DemoApiException('消息不存在或已撤回');
      }
      final group = _memberGroup(account, message['classId'].toString());
      if (message['fromUserId'] != account.userId &&
          !_canManage(account, group)) {
        throw const DemoApiException('只能撤回自己发送的消息');
      }
      message
        ..['type'] = 100
        ..['content'] = ''
        ..['param2'] = account.userId;
      DemoStore.save(_messagesKey);
      return true;
    });

    r.post('$base/updateAnnouncement', (req) {
      final account = req.account;
      final group = _memberGroup(account, req.str('classId'));
      if (!_canManage(account, group)) {
        throw const DemoApiException('仅班主任或管理员可以编辑群公告');
      }
      final text = req.str('announcement');
      final name = CampusA.displayName(account);
      final now = DateTime.now();
      _groupState()[group.id] = <String, dynamic>{
        'announcement': text,
        'announcementUserName': name,
        'announcementTime': CampusA.dateTime(now),
      };
      DemoStore.save(_groupStateKey);
      _messages().add(<String, dynamic>{
        'id': DemoStore.nextId(),
        'classId': group.id,
        'fromUserId': '0',
        'type': 0,
        'content': text.isEmpty ? '群公告 $name清空了群公告' : '群公告 $name发布了最新群公告',
        'param1': '',
        'param2': '',
        'createTime': CampusA.dateTime(now),
        'visibleAt': now.millisecondsSinceEpoch,
        'live': true,
      });
      DemoStore.save(_messagesKey);
      return true;
    });

    r.post('$base/updateDoNotDisturb', (req) {
      final account = req.account;
      final group = _memberGroup(account, req.str('classId'));
      _prefMap(account, 'mute')[group.id] = req.boolOf('doNotDisturb');
      DemoStore.save(_prefsKey(account));
      return true;
    });

    r.post('$base/pinnedClass', (req) {
      final account = req.account;
      final group = _memberGroup(account, req.str('classId'));
      _prefMap(account, 'pin')[group.id] = req.intOf('isPinned') == 1;
      DemoStore.save(_prefsKey(account));
      return true;
    });
  }
}
