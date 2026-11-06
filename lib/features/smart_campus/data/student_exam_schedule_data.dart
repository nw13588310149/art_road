/// 学生端「我的考试」——「全部考试」列表 + 我的科目安排（真实接口）。
///
/// 数据来源（`/app/school/v2/student/`）：
///   - `myExamList?tab=0/1/2`：全部 / 待考 / 已考 考试列表（见 [parseStudentExamList]）。
///   - `myExamDetail{id}`：单场考试详情，含各科 `classroomName`/`seatNo`、已上传
///     文件 `submitFiles[]`、`score`/`comment`（见 [parseStudentExamDetail]）。
///   - `examSubmit{examId,subjectId,filePath,fileType}`：在线科目自录上传。
///
/// 「在线 / 离线」按**科目**区分（`evaluateType`：1 在线自录上传 / 2 离线到考场）。
/// 一场考试可同时包含在线与离线科目。是否可提交以后端 `canSubmit` 为准。
library;

// =============================================================================
// 解析辅助
// =============================================================================

String _strOf(dynamic value) {
  final s = value?.toString().trim() ?? '';
  return s == 'null' ? '' : s;
}

int _intOf(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

int? _intOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

double? _doubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value'.trim());
}

int _maxSubmitOf(dynamic value) {
  final m = _intOf(value);
  return m <= 0 ? 2 : m;
}

/// `2026-06-20 08:00:00` → `08:00`。
String _hhmm(String raw) => raw.length >= 16 ? raw.substring(11, 16) : '';

/// `2026-06-20 08:00:00` → `06-20`。
String _mmdd(String raw) => raw.length >= 10 ? raw.substring(5, 10) : '';

/// 科目时间标签：`06-20 08:00-09:00`（缺失部分自动省略）。
String _subjectTimeLabel(String start, String end) {
  final md = _mmdd(start);
  final s = _hhmm(start);
  final e = _hhmm(end);
  final timePart = s.isEmpty ? e : (e.isEmpty ? s : '$s-$e');
  return [md, timePart].where((x) => x.isNotEmpty).join(' ');
}

/// 一场考试的时间跨度（卡片用）：最早开始 ~ 最晚结束（`08:00 - 13:00`）。
String _timeRangeFromSubjectMaps(dynamic subjectsRaw) {
  if (subjectsRaw is! List) return '';
  final starts = <String>[];
  final ends = <String>[];
  for (final s in subjectsRaw.whereType<Map>()) {
    final st = _hhmm(_strOf(s['examStartTime']));
    final en = _hhmm(_strOf(s['examEndTime']));
    if (st.isNotEmpty) starts.add(st);
    if (en.isNotEmpty) ends.add(en);
  }
  if (starts.isEmpty) return '';
  starts.sort();
  ends.sort();
  final first = starts.first;
  final last = ends.isNotEmpty ? ends.last : starts.last;
  return first == last ? first : '$first - $last';
}

String _fileNameFromPath(String path) {
  if (path.isEmpty) return '';
  final clean = path.split('?').first;
  final idx = clean.lastIndexOf('/');
  return idx >= 0 && idx < clean.length - 1 ? clean.substring(idx + 1) : clean;
}

/// `2026-06-17 13:20:30` → `06-17 13:20`。
String _shortTime(String raw) {
  if (raw.length >= 16) return raw.substring(5, 16);
  return raw;
}

String _examTypeFromName(String name) {
  if (name.contains('月考')) return '月考';
  if (name.contains('期中')) return '期中';
  if (name.contains('期末')) return '期末';
  if (name.contains('统考') || name.contains('联考')) return '统考';
  if (name.contains('摸底')) return '摸底考';
  if (name.contains('阶段')) return '阶段测评';
  if (name.contains('模拟')) return '模拟考';
  if (name.contains('测评') || name.contains('测试')) return '测评';
  return '考试';
}

const List<String> _kWeekdayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

String _weekdayLabelFromDate(String date) {
  final d = DateTime.tryParse(date.trim());
  if (d == null) return '';
  final idx = d.weekday - 1; // DateTime.monday == 1
  if (idx < 0 || idx >= _kWeekdayLabels.length) return '';
  return _kWeekdayLabels[idx];
}

// =============================================================================
// 枚举
// =============================================================================

/// 考试阶段（对齐后端 `examStatus`）。
enum StudentExamPhase {
  /// 报名 / 确认场次中（后端暂无对应状态，保留以兼容）。
  registering,

  /// 未开始（`NOT_STARTED`）。
  upcoming,

  /// 进行中（`ONGOING`）。
  ongoing,

  /// 待出成绩（`PENDING_SCORE`）。
  finished,

  /// 已出成绩（`SCORED`）。
  scored,
}

extension StudentExamPhaseX on StudentExamPhase {
  String get label => switch (this) {
    StudentExamPhase.registering => '报名中',
    StudentExamPhase.upcoming => '未开始',
    StudentExamPhase.ongoing => '进行中',
    StudentExamPhase.finished => '待出成绩',
    StudentExamPhase.scored => '已出成绩',
  };

  /// 待考（报名中 / 未开始 / 进行中）。
  bool get isPending =>
      this == StudentExamPhase.registering ||
      this == StudentExamPhase.upcoming ||
      this == StudentExamPhase.ongoing;

  /// 已考（待出成绩 / 已出成绩）。
  bool get isDone =>
      this == StudentExamPhase.finished || this == StudentExamPhase.scored;
}

StudentExamPhase _phaseFromStatus(String status) {
  switch (status.toUpperCase()) {
    case 'NOT_STARTED':
      return StudentExamPhase.upcoming;
    case 'ONGOING':
      return StudentExamPhase.ongoing;
    case 'PENDING_SCORE':
      return StudentExamPhase.finished;
    case 'SCORED':
      return StudentExamPhase.scored;
    default:
      return StudentExamPhase.upcoming;
  }
}

/// 科目考试形式：在线（自录上传）/ 离线（到考场）。
enum StudentExamMode { online, offline }

extension StudentExamModeX on StudentExamMode {
  String get label => this == StudentExamMode.online ? '在线' : '离线';
}

/// 在线提交的媒体类型。
enum StudentExamMediaKind { audio, video, image }

extension StudentExamMediaKindX on StudentExamMediaKind {
  String get label => switch (this) {
    StudentExamMediaKind.video => '视频',
    StudentExamMediaKind.audio => '音频',
    StudentExamMediaKind.image => '图片',
  };

  /// 提交接口 `fileType` 字段。
  String get fileType => switch (this) {
    StudentExamMediaKind.video => 'video',
    StudentExamMediaKind.audio => 'audio',
    StudentExamMediaKind.image => 'image',
  };
}

/// 在线科目的提交状态（用于状态徽章）。
enum StudentExamSubmitState {
  /// 离线科目（无提交状态）。
  notApplicable,

  /// 在线但未到提交窗口。
  notOpen,

  /// 可提交、尚未上传。
  pending,

  /// 已上传且仍可重传（次数未用完且在窗口内）。
  submittedRetryable,

  /// 已上传且次数已用完。
  submittedFull,

  /// 窗口已结束且未提交（错过）。
  missed,

  /// 窗口已结束、此前已提交（锁定查看）。
  submittedClosed,
}

// =============================================================================
// 模型
// =============================================================================

/// 一次在线科目提交记录（学生自录上传，来自 `submitFiles`）。
class StudentExamUpload {
  const StudentExamUpload({
    required this.kind,
    required this.fileName,
    required this.uploadedAt,
    this.path = '',
  });

  factory StudentExamUpload.fromMap(Map<dynamic, dynamic> map) {
    final path = _strOf(map['path'] ?? map['filePath']);
    final type = _strOf(map['fileType']).toLowerCase();
    final kind = switch (type) {
      'video' => StudentExamMediaKind.video,
      'audio' => StudentExamMediaKind.audio,
      'image' => StudentExamMediaKind.image,
      _ => _kindFromPath(path),
    };
    final name = _strOf(map['fileName']);
    return StudentExamUpload(
      kind: kind,
      fileName: name.isNotEmpty ? name : _fileNameFromPath(path),
      uploadedAt: _shortTime(_strOf(map['uploadTime'] ?? map['createTime'])),
      path: path,
    );
  }

  final StudentExamMediaKind kind;
  final String fileName;

  /// 形如 `06-17 14:30`。
  final String uploadedAt;

  /// 远端相对路径（用于预览 / 播放）。
  final String path;
}

StudentExamMediaKind _kindFromPath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.webm') ||
      lower.endsWith('.m4v') ||
      lower.endsWith('.avi') ||
      lower.endsWith('.mkv')) {
    return StudentExamMediaKind.video;
  }
  if (lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.bmp') ||
      lower.endsWith('.heic') ||
      lower.endsWith('.heif')) {
    return StudentExamMediaKind.image;
  }
  return StudentExamMediaKind.audio;
}

/// 单科考试安排（在线/离线 + 时间 + 考场座位 / 自录上传）。
class StudentExamSubjectPlan {
  const StudentExamSubjectPlan({
    required this.subjectName,
    required this.dateTimeLabel,
    this.subjectId = 0,
    this.durationLabel = '',
    this.mode = StudentExamMode.offline,
    this.classroomName = '',
    this.seatNo,
    this.maxUploads = 2,
    this.submitCount = 0,
    this.uploads = const [],
    this.score,
    this.comment = '',
    this.serverCanSubmit = false,
  });

  factory StudentExamSubjectPlan.fromMap(Map<dynamic, dynamic> map) {
    final start = _strOf(map['examStartTime']);
    final end = _strOf(map['examEndTime']);
    final files = map['submitFiles'];
    return StudentExamSubjectPlan(
      subjectId: _intOf(map['subjectId']),
      subjectName: _strOf(map['subjectName']),
      mode: _intOf(map['evaluateType']) == 1
          ? StudentExamMode.online
          : StudentExamMode.offline,
      dateTimeLabel: _subjectTimeLabel(start, end),
      classroomName: _strOf(map['classroomName']),
      seatNo: _intOrNull(map['seatNo']),
      maxUploads: _maxSubmitOf(map['maxSubmitCount']),
      submitCount: _intOf(map['submitCount']),
      uploads: files is List
          ? files
                .whereType<Map<dynamic, dynamic>>()
                .map(StudentExamUpload.fromMap)
                .toList(growable: false)
          : const [],
      score: _doubleOrNull(map['score']),
      comment: _strOf(map['comment']),
      serverCanSubmit: map['canSubmit'] == true,
    );
  }

  final int subjectId;
  final String subjectName;

  /// 该科目考试形式（在线 / 离线）。
  final StudentExamMode mode;

  /// 形如 `06-20 08:00-09:00`。
  final String dateTimeLabel;

  /// 备用时长标签（接口未提供时为空）。
  final String durationLabel;

  /// 离线：考场，形如 `致远楼1-101`；未编排为空串。
  final String classroomName;

  /// 离线：座位号；未编排为 null。
  final int? seatNo;

  /// 在线：最多可上传次数（`maxSubmitCount`）。
  final int maxUploads;

  /// 在线：已上传次数（`submitCount`，列表态也有；详情态等于 [uploads].length）。
  final int submitCount;

  /// 在线：已上传记录（详情接口 `submitFiles`）。
  final List<StudentExamUpload> uploads;

  /// 已出成绩时的分数；否则为 null。
  final double? score;

  /// 老师评语（成绩发布后）。
  final String comment;

  /// 后端权威「当前是否可提交」（在线 + 考试时间内 + 未超次数）。
  final bool serverCanSubmit;

  bool get isOnline => mode == StudentExamMode.online;

  /// 离线：是否已编排考场（教室 + 座位齐全）。
  bool get arranged => classroomName.trim().isNotEmpty && seatNo != null;

  int get uploadCount => submitCount;

  /// 在线：剩余可上传次数。
  int get remainingUploads {
    if (!isOnline) return 0;
    final left = maxUploads - submitCount;
    return left < 0 ? 0 : left;
  }

  /// 时间 / 时长合并标签。
  String get scheduleLabel => durationLabel.trim().isEmpty
      ? dateTimeLabel
      : '$dateTimeLabel · $durationLabel';

  /// 当前是否可上传（以后端 `canSubmit` 为准；[phase] 仅为兼容旧签名）。
  bool canSubmit(StudentExamPhase phase) => serverCanSubmit;

  /// 在线科目当前的提交状态。
  StudentExamSubmitState submitState(StudentExamPhase phase) {
    if (!isOnline) return StudentExamSubmitState.notApplicable;
    if (serverCanSubmit) {
      return submitCount == 0
          ? StudentExamSubmitState.pending
          : StudentExamSubmitState.submittedRetryable;
    }
    if (submitCount >= maxUploads) return StudentExamSubmitState.submittedFull;
    if (submitCount > 0) return StudentExamSubmitState.submittedClosed;
    if (phase == StudentExamPhase.finished ||
        phase == StudentExamPhase.scored) {
      return StudentExamSubmitState.missed;
    }
    return StudentExamSubmitState.notOpen;
  }
}

/// 一场考试（含我本人的全部科目安排）。
class StudentExamScheduleItem {
  const StudentExamScheduleItem({
    required this.examId,
    required this.name,
    required this.typeLabel,
    required this.dateLabel,
    required this.weekdayLabel,
    required this.timeRange,
    required this.phase,
    required this.subjects,
    this.statusText = '',
    this.uploadProgress = '',
    this.remark = '',
    this.totalScore,
    this.publishStatus = 0,
  });

  factory StudentExamScheduleItem.fromMap(Map<dynamic, dynamic> map) {
    final subjectsRaw = map['subjects'];
    final subjects = subjectsRaw is List
        ? subjectsRaw
              .whereType<Map<dynamic, dynamic>>()
              .map(StudentExamSubjectPlan.fromMap)
              .toList(growable: false)
        : const <StudentExamSubjectPlan>[];
    final name = _strOf(map['examName']);
    final date = _strOf(map['examDate']);
    return StudentExamScheduleItem(
      examId: _strOf(map['examId']),
      name: name.isEmpty ? '考试' : name,
      typeLabel: _examTypeFromName(name),
      dateLabel: date,
      weekdayLabel: _weekdayLabelFromDate(date),
      timeRange: _timeRangeFromSubjectMaps(subjectsRaw),
      phase: _phaseFromStatus(_strOf(map['examStatus'])),
      subjects: subjects,
      statusText: _strOf(map['examStatusText']),
      uploadProgress: _strOf(map['uploadProgress']),
      remark: _strOf(map['remark']),
      totalScore: _doubleOrNull(map['totalScore']),
      publishStatus: _intOf(map['publishStatus']),
    );
  }

  final String examId;
  final String name;

  /// `月考` / `统考` / `摸底考` 等（由名称推导）。
  final String typeLabel;

  /// 形如 `2026-06-20`。
  final String dateLabel;

  /// 形如 `周四`。
  final String weekdayLabel;

  /// 形如 `08:00 - 13:00`。
  final String timeRange;

  final StudentExamPhase phase;
  final List<StudentExamSubjectPlan> subjects;

  /// 后端状态文案（未开始 / 进行中 / 待出成绩 / 已出成绩）。
  final String statusText;

  /// 上传进度文案（如 `1/2科目上传`），离线考试为空。
  final String uploadProgress;

  /// 考务备注。
  final String remark;

  /// 已出成绩时的总均分；否则为 null。
  final double? totalScore;

  /// 成绩发布状态（0 未发布 / 1 已发布）。
  final int publishStatus;

  int get subjectCount => subjects.length;

  List<StudentExamSubjectPlan> get onlineSubjects =>
      subjects.where((s) => s.isOnline).toList(growable: false);

  List<StudentExamSubjectPlan> get offlineSubjects =>
      subjects.where((s) => !s.isOnline).toList(growable: false);

  bool get hasOnline => onlineSubjects.isNotEmpty;

  bool get hasOffline => offlineSubjects.isNotEmpty;

  /// 形式概览标签：全在线 → 在线；全离线 → 离线；混合 → 线上+线下。
  String get modeLabel {
    if (hasOnline && hasOffline) return '线上+线下';
    if (hasOnline) return '在线';
    return '离线';
  }

  /// 在线科目中当前还能上传的科目数。
  int get submittableOnlineCount =>
      onlineSubjects.where((s) => s.serverCanSubmit).length;

  /// 在线科目中已提交的科目数。
  int get submittedOnlineCount =>
      onlineSubjects.where((s) => s.submitCount > 0).length;

  /// 离线科目中已编排考场的科目数。
  int get arrangedOfflineCount =>
      offlineSubjects.where((s) => s.arranged).length;
}

/// 解析 `myExamList` 响应（`data` 为考试数组）。
List<StudentExamScheduleItem> parseStudentExamList(dynamic data) {
  if (data is! List) return const [];
  return data
      .whereType<Map<dynamic, dynamic>>()
      .map(StudentExamScheduleItem.fromMap)
      .toList(growable: false);
}

/// 解析 `myExamDetail` 响应（`data` 为单场考试，含考场座位与已上传文件）。
StudentExamScheduleItem? parseStudentExamDetail(dynamic data) {
  if (data is! Map) return null;
  return StudentExamScheduleItem.fromMap(data);
}
