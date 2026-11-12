part of 'interaction_circle.dart';

const _reportsKey = 'circle:reports';
const _managerBase = '/app/school/v2/manager';

/// 举报处理结果 `result`：0 未处理 / 1 保留（举报不成立）/ 2 删除。
const _resultKept = 1;
const _resultDeleted = 2;

const _otherReason = '其他';

/// 校圈待处理的举报数（按动态计）。管理员工作台 `indexSum.postStatus0Count`
/// 与「校圈治理」的「待处理」页签都取这个数，处理一条就少一条。
int circlePendingReportCount() => _reports().where(_isPending).length;

/// 举报（所有登录用户）与治理（仅管理员，`/manager/*`）接口。
///
/// 同一条动态的多次举报合并成一条记录：`{id, postId, reports: [{userId, reason,
/// remark, createTime}], status, result, handleReason, handleRemark,
/// handlerUserId, handleTime, post?}`。`status` 0 待处理 / 1 已处理；删除时把
/// 动态快照存进 `post`，「已处理」里仍能看到原文。
void _registerCircleGovernance(DemoRouter r) {
  r.post('$_base/postsReport', _reportPost);
  r.post('$_managerBase/postsReportList', _reportList);
  r.post('$_managerBase/postsReportHandle', _handleReport);
  r.post('$_managerBase/postsDelete', _managerDeletePost);
}

List<Map<String, dynamic>> _reports() =>
    DemoStore.list(_reportsKey, () => demoCloneSeed(_seed.reports));

void _saveReports() {
  _reports();
  DemoStore.save(_reportsKey);
}

bool _isPending(Map<String, dynamic> record) =>
    _int(record['status']) == 0 && _findPost('${record['postId']}') != null;

Map<String, dynamic>? _pendingRecordOf(Object? postId) => _reports()
    .where((r) => r['postId'] == postId && _int(r['status']) == 0)
    .firstOrNull;

List<Map<String, dynamic>> _entriesOf(Map<String, dynamic> record) {
  final raw = record['reports'];
  return [
    if (raw is List)
      for (final e in raw)
        if (e is Map) Map<String, dynamic>.from(e),
  ];
}

String _lastReportTime(Map<String, dynamic> record) {
  var latest = '';
  for (final e in _entriesOf(record)) {
    final time = '${e['createTime']}';
    if (time.compareTo(latest) > 0) {
      latest = time;
    }
  }
  return latest;
}

Map<String, dynamic> _newReportRecord(String postId) => <String, dynamic>{
  'id': DemoStore.nextId('399'),
  'postId': postId,
  'reports': <Map<String, dynamic>>[],
  'status': 0,
  'result': 0,
  'handleReason': '',
  'handleRemark': '',
  'handlerUserId': '',
  'handleTime': '',
};

void _requireManager(DemoAccount viewer) {
  if (!viewer.role.managesSchool) {
    throw const DemoApiException('只有管理员可以处理校圈举报');
  }
}

/// 传了 [missing] 时原因必填；选「其他」必须写说明；说明不超过 200 字。
({String reason, String remark}) _reasonOf(
  DemoRequest req, {
  String? missing,
}) {
  final reason = req.str('reason');
  final remark = req.str('remark');
  if (reason.isEmpty && missing != null) {
    throw DemoApiException(missing);
  }
  if (reason == _otherReason && remark.isEmpty) {
    throw const DemoApiException('选择「其他」时请写明原因');
  }
  if (remark.length > 200) {
    throw const DemoApiException('补充说明不能超过 200 字');
  }
  return (reason: reason, remark: remark);
}

void _closeReport(
  Map<String, dynamic> record,
  DemoAccount viewer, {
  required int result,
  required String reason,
  String remark = '',
}) {
  record
    ..['status'] = 1
    ..['result'] = result
    ..['handleReason'] = reason
    ..['handleRemark'] = remark
    ..['handlerUserId'] = viewer.userId
    ..['handleTime'] = demoTimeText(DateTime.now());
}

/// 动态被删除后，它的每条举报记录（含早先已保留的）都留一份快照。
void _keepRemovedPostInReports(Map<String, dynamic> post) {
  var changed = false;
  for (final record in _reports()) {
    if (record['postId'] == post['id'] && record['post'] == null) {
      record['post'] = jsonDecode(jsonEncode(post));
      changed = true;
    }
  }
  if (changed) {
    _saveReports();
  }
}

/// 作者或管理员走普通删除时，这条动态还没处理的举报一起结案。
void _closeReportsOnDelete(Map<String, dynamic> post, DemoAccount viewer) {
  final byAuthor = post['userId'] == viewer.userId;
  var changed = false;
  for (final record in _reports()) {
    if (record['postId'] == post['id'] && _int(record['status']) == 0) {
      _closeReport(
        record,
        viewer,
        result: _resultDeleted,
        reason: byAuthor ? '作者已自行删除' : '管理员已删除',
      );
      changed = true;
    }
  }
  if (changed) {
    _saveReports();
  }
}

Object? _reportPost(DemoRequest req) {
  final viewer = req.account;
  final post = _requirePost(req.str('postsId'));
  if (post['userId'] == viewer.userId) {
    throw const DemoApiException('不能举报自己发布的动态');
  }
  final picked = _reasonOf(req, missing: '请选择举报原因');
  var record = _pendingRecordOf(post['id']);
  final entries = record == null
      ? <Map<String, dynamic>>[]
      : _entriesOf(record);
  if (entries.any((e) => e['userId'] == viewer.userId)) {
    throw const DemoApiException('你已经举报过这条动态，请等待管理员处理');
  }
  if (record == null) {
    record = _newReportRecord('${post['id']}');
    _reports().add(record);
  }
  record['reports'] = [
    ...entries,
    <String, dynamic>{
      'userId': viewer.userId,
      'reason': picked.reason,
      'remark': picked.remark,
      'createTime': demoTimeText(DateTime.now()),
    },
  ];
  _saveReports();
  return true;
}

/// `status` 0 待处理 / 1 已处理 / 不传为全部。待处理按举报人数、再按最近举报时间
/// 倒序；已处理按处理时间倒序。
Object? _reportList(DemoRequest req) {
  final viewer = req.account;
  _requireManager(viewer);
  final status = req.str('status');
  final pending = [if (status != '1') ..._reports().where(_isPending)]
    ..sort((a, b) {
      final byCount = _entriesOf(b).length.compareTo(_entriesOf(a).length);
      return byCount != 0
          ? byCount
          : _lastReportTime(b).compareTo(_lastReportTime(a));
    });
  final handled = [
    if (status != '0') ..._reports().where((r) => _int(r['status']) == 1),
  ]..sort((a, b) => '${b['handleTime']}'.compareTo('${a['handleTime']}'));
  final page = demoPage([...pending, ...handled], req);
  page['records'] = [
    for (final r in (page['records'] as List).cast<Map<String, dynamic>>())
      _reportJson(r, viewer),
  ];
  return page;
}

Object? _handleReport(DemoRequest req) {
  final viewer = req.account;
  _requireManager(viewer);
  final id = req.str('id');
  final record = _reports().where((r) => r['id'] == id).firstOrNull;
  if (record == null) {
    throw const DemoApiException('举报记录不存在');
  }
  if (_int(record['status']) != 0) {
    throw const DemoApiException('这条举报已经处理过了');
  }
  final result = req.intOf('result');
  if (result != _resultKept && result != _resultDeleted) {
    throw const DemoApiException('处理结果不正确');
  }
  final post = _requirePost('${record['postId']}');
  if (result == _resultDeleted) {
    final picked = _reasonOf(req, missing: '请选择删除原因');
    _removePost(post);
    _closeReport(
      record,
      viewer,
      result: _resultDeleted,
      reason: picked.reason,
      remark: picked.remark,
    );
  } else {
    final picked = _reasonOf(req);
    _closeReport(
      record,
      viewer,
      result: _resultKept,
      reason: picked.reason.isEmpty ? '举报不成立' : picked.reason,
      remark: picked.remark,
    );
  }
  _saveReports();
  return _reportJson(record, viewer);
}

/// 管理员在「全部动态」里删除任意动态：必须写明原因，记录进入「已处理」；
/// 这条动态有待处理的举报时一并结案。
Object? _managerDeletePost(DemoRequest req) {
  final viewer = req.account;
  _requireManager(viewer);
  final post = _requirePost(req.str('id'));
  final picked = _reasonOf(req, missing: '请选择删除原因');
  var record = _pendingRecordOf(post['id']);
  if (record == null) {
    record = _newReportRecord('${post['id']}');
    _reports().add(record);
  }
  _removePost(post);
  _closeReport(
    record,
    viewer,
    result: _resultDeleted,
    reason: picked.reason,
    remark: picked.remark,
  );
  _saveReports();
  return _reportJson(record, viewer);
}

/// 举报人只给出数量、原因和说明，不返回身份。
Map<String, dynamic> _reportJson(
  Map<String, dynamic> record,
  DemoAccount viewer,
) {
  final live = _findPost('${record['postId']}');
  final snapshot = record['post'];
  final post =
      live ?? (snapshot is Map ? Map<String, dynamic>.from(snapshot) : null);
  final entries = _entriesOf(record)
    ..sort((a, b) => '${b['createTime']}'.compareTo('${a['createTime']}'));
  final counts = <String, int>{};
  for (final e in entries) {
    final reason = '${e['reason']}';
    counts[reason] = (counts[reason] ?? 0) + 1;
  }
  final reasons = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final handlerId = '${record['handlerUserId'] ?? ''}';
  return <String, dynamic>{
    'id': record['id'],
    'postsId': record['postId'],
    'status': _int(record['status']),
    'result': _int(record['result']),
    'reportCount': entries.length,
    'reasons': [
      for (final e in reasons)
        <String, dynamic>{'reason': e.key, 'count': e.value},
    ],
    'reports': [
      for (final e in entries)
        <String, dynamic>{
          'reason': e['reason'],
          'remark': e['remark'] ?? '',
          'createTime': e['createTime'],
        },
    ],
    'lastReportTime': entries.isEmpty ? '' : entries.first['createTime'],
    'handleReason': record['handleReason'] ?? '',
    'handleRemark': record['handleRemark'] ?? '',
    'handlerName': handlerId.isEmpty
        ? ''
        : (demoAuthorByUserId(handlerId)?.name ?? ''),
    'handleTime': record['handleTime'] ?? '',
    'postDeleted': live == null ? 1 : 0,
    if (post != null) 'post': _postJson(post, viewer),
  };
}

// ── 种子 ──────────────────────────────────────────────────────────────

class _SeedReport {
  const _SeedReport(
    this.reporter,
    this.reason,
    this.minutesAfter, [
    this.remark = '',
  ]);

  /// `s:<学生序号>` 或 `t:<教职工 id>`。
  final String reporter;
  final String reason;

  /// 动态发布后多少分钟收到这条举报。
  final int minutesAfter;
  final String remark;
}

class _SeedReportCase {
  const _SeedReportCase({
    required this.post,
    required this.reports,
    this.result = 0,
    this.handleReason = '',
    this.handleRemark = '',
    this.handledAfter = 0,
  });

  /// 对应 [_SeedPost.ref]。
  final String post;
  final List<_SeedReport> reports;

  /// 0 待处理 / 1 保留 / 2 删除；已处理的都由教务王敏处理。
  final int result;
  final String handleReason;
  final String handleRemark;

  /// 最后一条举报之后多少分钟处理。
  final int handledAfter;
}

const _seedReportCases = <_SeedReportCase>[
  _SeedReportCase(
    post: 'ghost-drawing',
    reports: [
      _SeedReport('s:7', '代画作业', 45),
      _SeedReport('t:t-4', '代画作业', 160, '速写、色彩作业要求本人完成，代画会影响老师判断真实水平。'),
      _SeedReport('s:20', '广告营销', 1500),
    ],
  ),
  _SeedReportCase(
    post: 'exam-rumor',
    reports: [
      _SeedReport('s:12', '不实考试信息', 35, '月考题目考前保密，这条是谣言。'),
      _SeedReport('s:21', '不实考试信息', 90),
    ],
  ),
  _SeedReportCase(
    post: 'studio-wall',
    reports: [_SeedReport('s:27', '未经同意发布他人照片或作品', 300, '照片里有我的作业。')],
  ),
  _SeedReportCase(
    post: 'milk-tea',
    reports: [
      _SeedReport('s:3', '广告营销', 30),
      _SeedReport('s:9', '广告营销', 55),
      _SeedReport('s:15', '与画室学习无关', 80),
      _SeedReport('s:22', '广告营销', 120),
    ],
    result: _resultDeleted,
    handleReason: '广告营销',
    handleRemark: '与画室学习无关的商业推广，已提醒发帖同学。',
    handledAfter: 40,
  ),
  _SeedReportCase(
    post: 'sketch-video',
    reports: [_SeedReport('s:18', '未经同意发布他人照片或作品', 120, '视频里拍到了我。')],
    result: _resultKept,
    handleReason: '举报不成立',
    handleRemark: '课堂示范视频拍摄前已告知全班同学，内容与教学相关。',
    handledAfter: 60,
  ),
];

List<Map<String, dynamic>> _buildSeedReports(
  Map<String, Map<String, dynamic>> postsByRef,
  DateTime now,
) {
  final handler = DemoCampusData.staffById('t-9')!;
  final latest = now.subtract(const Duration(minutes: 1));
  final records = <Map<String, dynamic>>[];
  for (var i = 0; i < _seedReportCases.length; i++) {
    final spec = _seedReportCases[i];
    final post = postsByRef[spec.post]!;
    final created = DateTime.parse('${post['createTime']}');
    var last = created;
    final entries = <Map<String, dynamic>>[];
    for (final r in spec.reports) {
      final time = _seedTimeAfter(created, r.minutesAfter, latest);
      if (time.isAfter(last)) {
        last = time;
      }
      entries.add(<String, dynamic>{
        'userId': _seedAuthor(r.reporter).userId,
        'reason': r.reason,
        'remark': r.remark,
        'createTime': demoTimeText(time),
      });
    }
    final handled = spec.result != 0;
    records.add(<String, dynamic>{
      'id': '3990000000${100101 + i}',
      'postId': post['id'],
      'reports': entries,
      'status': handled ? 1 : 0,
      'result': spec.result,
      'handleReason': spec.handleReason,
      'handleRemark': spec.handleRemark,
      'handlerUserId': handled ? handler.userId : '',
      'handleTime': handled
          ? demoTimeText(_seedTimeAfter(last, spec.handledAfter, latest))
          : '',
      if (spec.result == _resultDeleted) 'post': post,
    });
  }
  return records;
}

/// [base] 之后 [minutes] 分钟；落在夜里（21:30 以后、08:30 以前）顺延到下一个
/// 上午，且不晚于 [latest]。
DateTime _seedTimeAfter(DateTime base, int minutes, DateTime latest) {
  var time = base.add(Duration(minutes: minutes));
  final morning = DateTime(time.year, time.month, time.day, 8, 30);
  final evening = DateTime(time.year, time.month, time.day, 21, 30);
  if (time.isAfter(evening)) {
    time = morning.add(Duration(days: 1, minutes: minutes % 50));
  } else if (time.isBefore(morning)) {
    time = morning.add(Duration(minutes: minutes % 50));
  }
  return time.isAfter(latest) ? latest : time;
}
