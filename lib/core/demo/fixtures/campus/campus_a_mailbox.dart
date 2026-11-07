import '../../demo_accounts.dart';
import '../../demo_backend.dart';
import '../../demo_store.dart';
import 'campus_a_common.dart';

/// 校长信箱（`user/principalMailbox*` 提交与查看、`headmaster/principalMailbox*`
/// 校长收件箱与回复）与意见反馈（`/app/user/feedback*`）。
///
/// 信件存同一张表：学生 / 老师看到自己提交的，校长端看到全部；校长回复后
/// 提交人刷新即可看到回复。意见反馈提交约 45 秒后由产品团队自动回复。
abstract final class CampusAMailbox {
  static const _mailKey = 'campusA:mailbox';
  static const _feedbackReplyDelay = Duration(seconds: 45);

  static List<Map<String, dynamic>> _letters() =>
      DemoStore.list(_mailKey, _seedLetters);

  static List<Map<String, dynamic>> _seedLetters() {
    Map<String, dynamic> student(
      String id,
      int index, {
      required String type,
      required String content,
      required int hoursAgo,
      int status = 0,
      bool anonymous = false,
      String attachments = '',
      String reply = '',
      int replyHoursAgo = 0,
    }) {
      final p = CampusA.person(index);
      return <String, dynamic>{
        'id': id,
        'submitterUserId': CampusA.studentUserId(index),
        'submitterName': p.name,
        'submitterHeadRef': p.avatarRef,
        'studentNo': CampusA.studentNo(index),
        'submitterRole': 'student',
        'msgType': type,
        'content': content,
        'isAnonymous': anonymous ? 1 : 0,
        'attachments': attachments,
        'status': status,
        'createTime': CampusA.ago(hours: hoursAgo, minutes: int.parse(id) % 47),
        'replyContent': reply,
        'replyTime': reply.isEmpty
            ? ''
            : CampusA.ago(hours: replyHoursAgo, minutes: int.parse(id) % 29),
      };
    }

    Map<String, dynamic> teacher(
      String id,
      String staffId, {
      required String type,
      required String content,
      required int hoursAgo,
      int status = 0,
      String attachments = '',
      String reply = '',
      int replyHoursAgo = 0,
    }) {
      final s = CampusA.staff(staffId);
      return <String, dynamic>{
        'id': id,
        'submitterUserId': s.userId,
        'submitterName': s.name,
        'submitterHeadRef': '',
        'studentNo': '',
        'submitterRole': 'teacher',
        'msgType': type,
        'content': content,
        'isAnonymous': 0,
        'attachments': attachments,
        'status': status,
        'createTime': CampusA.ago(hours: hoursAgo, minutes: int.parse(id) % 47),
        'replyContent': reply,
        'replyTime': reply.isEmpty
            ? ''
            : CampusA.ago(hours: replyHoursAgo, minutes: int.parse(id) % 29),
      };
    }

    return [
      student(
        '4108',
        15,
        type: '建议',
        content: '每次模考后希望能展示更多高分卷，并附上阅卷老师的点评，方便我们对照找差距。',
        hoursAgo: 5,
        anonymous: true,
        attachments: 'asset:assets/demo/papers/color.jpg',
      ),
      student(
        '4107',
        1,
        type: '其他',
        content: '宿舍楼热水供应时间能否提前到 21:00？晚自习结束后排队洗漱的人太多了。',
        hoursAgo: 20,
      ),
      teacher(
        '4106',
        't-1',
        type: '建议',
        content: '素描教室的石膏像磨损比较严重，建议采购一批新的大卫、伏尔泰和小卫头像，冲刺阶段使用频率很高。',
        hoursAgo: 30,
        attachments: 'asset:assets/demo/scene/studio-wall.jpg',
      ),
      student(
        '4105',
        9,
        type: '其他',
        content: '食堂晚餐能否增加一个面食窗口？很多同学晚课前时间紧，想吃得快一点。',
        hoursAgo: 52,
      ),
      teacher(
        '4104',
        't-3',
        type: '建议',
        content: '色彩教室通风不太好，水粉颜料的味道比较大，希望加装排风扇。',
        hoursAgo: 76,
        status: 1,
        reply: '刘老师好，已安排后勤本周六为色彩教室 B 加装两台排风扇，感谢提醒。',
        replyHoursAgo: 60,
      ),
      student(
        '4103',
        6,
        type: '建议',
        content: '希望增加外出色彩写生的次数，室内静物画久了对风景色彩的感觉有点生疏。',
        hoursAgo: 120,
        status: 1,
        reply: '同学你好，色彩组已调整计划，冲刺阶段每两周安排一次外出写生，天气允许的周六下午出发。',
        replyHoursAgo: 100,
      ),
      student(
        '4102',
        1,
        type: '建议',
        content: '建议画室晚自习延长到 22:00，联考前素描加练时间不太够。',
        hoursAgo: 170,
        status: 1,
        reply: '同学你好，已与教学部商议，下周起城东校区开放 21:00—22:00 自习画室，请注意 22:30 前按时归寝。',
        replyHoursAgo: 150,
      ),
      student(
        '4101',
        20,
        type: '举报',
        content: '男生公寓 2 号楼有同学夜间使用大功率电器，存在安全隐患。',
        hoursAgo: 240,
        status: 2,
        anonymous: true,
        reply: '感谢反映，宿管老师已于当晚核实并收缴违规电器，后续将加强巡查。',
        replyHoursAgo: 220,
      ),
    ];
  }

  static Map<String, dynamic> _letterRow(Map<String, dynamic> m) {
    final anonymous = m['isAnonymous'] == 1;
    final attachments = [
      for (final ref in (m['attachments']?.toString() ?? '').split(','))
        if (ref.trim().isNotEmpty) CampusA.media(ref.trim()),
    ].join(',');
    return <String, dynamic>{
      'id': m['id'],
      'msgType': m['msgType'],
      'content': m['content'],
      'status': m['status'],
      'createTime': m['createTime'],
      'isAnonymous': m['isAnonymous'],
      'attachments': attachments,
      'replyContent': m['replyContent'],
      'replyTime': m['replyTime'],
      'schoolId': '1',
      'realname': anonymous ? '' : m['submitterName'],
      'studentNo': anonymous ? '' : m['studentNo'],
      'headUrl': anonymous ? '' : CampusA.media(m['submitterHeadRef'].toString()),
      'submitterRole': m['submitterRole'],
      'user': anonymous
          ? null
          : <String, dynamic>{
              'id': m['submitterUserId'],
              'realname': m['submitterName'],
              'nickname': m['submitterName'],
              'studentNo': m['studentNo'],
              'headUrl': CampusA.media(m['submitterHeadRef'].toString()),
            },
    };
  }

  // ── 意见反馈 ────────────────────────────────────────────────────────

  static String _feedbackKey(DemoAccount account) =>
      'campusA:feedback:${account.userId}';

  static List<Map<String, dynamic>> _feedback(DemoAccount account) {
    final key = _feedbackKey(account);
    final list = DemoStore.list(key, () => _seedFeedback(account));
    final now = DateTime.now().millisecondsSinceEpoch;
    var changed = false;
    for (final item in list) {
      final submitted = (item['submittedAtMs'] as num?)?.toInt();
      if (submitted != null &&
          now - submitted >= _feedbackReplyDelay.inMilliseconds) {
        item
          ..['replyContent'] = '已收到你的反馈，我们会在后续版本中评估。'
          ..['replyTime'] = CampusA.dateTime(
            DateTime.fromMillisecondsSinceEpoch(
              submitted + _feedbackReplyDelay.inMilliseconds,
            ),
          )
          ..remove('submittedAtMs');
        changed = true;
      }
    }
    if (changed) {
      DemoStore.save(key);
    }
    return list;
  }

  static List<Map<String, dynamic>> _seedFeedback(DemoAccount account) {
    final student = CampusA.isStudent(account);
    return [
      <String, dynamic>{
        'id': '4302',
        'content': student
            ? '希望学情中心的原卷可以放大后对比两次考试的同一科，方便看出进步。'
            : '作品点评希望支持在原图上直接圈画标注，语音点评再长一点就更好了。',
        'createTime': CampusA.ago(days: 2, hours: 3, minutes: 17),
        'replyContent': '',
        'replyTime': '',
      },
      <String, dynamic>{
        'id': '4301',
        'content': student
            ? '课堂签到页能不能显示离下课还有多久？经常不知道什么时候该签退。'
            : '查寝记录导出希望能按班级筛选，方便发给班主任。',
        'createTime': CampusA.ago(days: 9, hours: 1, minutes: 42),
        'replyContent': student
            ? '已在新版本中加入「距下课」倒计时，签到页右上角即可查看，感谢建议。'
            : '已支持按宿舍楼与楼层筛选导出，按班级导出正在开发中，感谢建议。',
        'replyTime': CampusA.ago(days: 7, hours: 4, minutes: 8),
      },
    ];
  }

  // ── 接口 ────────────────────────────────────────────────────────────

  static void register(DemoRouter r) {
    r.post('/app/school/v2/user/principalMailboxList', (req) {
      final account = req.account;
      final status = req.intOf('status');
      final list = [
        for (final m in _letters())
          if (m['submitterUserId'] == account.userId && m['status'] == status)
            _letterRow(m),
      ]..sort(CampusA.compareTimeDesc);
      return CampusA.page(list, req);
    });

    r.post('/app/school/v2/user/principalMailboxSubmit', (req) {
      final account = req.account;
      final content = req.str('content');
      if (content.isEmpty) {
        throw const DemoApiException('请填写信件内容');
      }
      final isStudent = CampusA.isStudent(account);
      final index = CampusA.personIndexOf(account);
      _letters().insert(0, <String, dynamic>{
        'id': DemoStore.nextId(),
        'submitterUserId': account.userId,
        'submitterName': CampusA.displayName(account),
        'submitterHeadRef': CampusA.headRefOf(account),
        'studentNo': isStudent ? CampusA.studentNo(index) : '',
        'submitterRole': isStudent ? 'student' : 'teacher',
        'msgType': req.str('msgType', '建议'),
        'content': content,
        'isAnonymous': req.intOf('isAnonymous'),
        'attachments': [
          for (final part in req.str('attachments').split(','))
            if (part.trim().isNotEmpty) CampusA.toRef(part.trim()),
        ].join(','),
        'status': 0,
        'createTime': CampusA.dateTime(DateTime.now()),
        'replyContent': '',
        'replyTime': '',
      });
      DemoStore.save(_mailKey);
      return true;
    });

    r.post('/app/school/v2/headmaster/principalMailboxList', (req) {
      final status = req.intOf('status');
      final list = [
        for (final m in _letters())
          if (m['status'] == status) _letterRow(m),
      ]..sort(CampusA.compareTimeDesc);
      return CampusA.page(list, req);
    });

    r.post('/app/school/v2/headmaster/principalMailboxReply', (req) {
      final letter = CampusA.findById(_letters(), req.str('id'));
      if (letter == null) {
        throw const DemoApiException('信件不存在');
      }
      final reply = req.str('replyContent');
      if (reply.isEmpty) {
        throw const DemoApiException('请填写回复内容');
      }
      letter
        ..['status'] = 1
        ..['replyContent'] = reply
        ..['replyTime'] = CampusA.dateTime(DateTime.now());
      DemoStore.save(_mailKey);
      return true;
    });

    r.post('/app/user/feedbackList', (req) {
      final list = [
        for (final item in _feedback(req.account))
          Map<String, dynamic>.from(item)..remove('submittedAtMs'),
      ]..sort(CampusA.compareTimeDesc);
      return CampusA.page(list, req);
    });

    r.post('/app/user/feedbackSave', (req) {
      final account = req.account;
      final content = req.str('content');
      if (content.isEmpty) {
        throw const DemoApiException('请填写反馈内容');
      }
      final now = DateTime.now();
      _feedback(account).insert(0, <String, dynamic>{
        'id': DemoStore.nextId(),
        'content': content,
        'createTime': CampusA.dateTime(now),
        'replyContent': '',
        'replyTime': '',
        'submittedAtMs': now.millisecondsSinceEpoch,
      });
      DemoStore.save(_feedbackKey(account));
      return true;
    });
  }
}
