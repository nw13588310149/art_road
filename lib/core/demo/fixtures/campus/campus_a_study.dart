import '../../data/demo_marking_data.dart';
import '../../demo_accounts.dart';
import '../../demo_backend.dart';
import '../../demo_store.dart';
import 'campus_a_common.dart';
import 'campus_a_courses.dart';

/// 学生考试、成绩与作业：`myExamList` / `myExamDetail` / `examSeat` /
/// `examSubmit` / `examOverview` / `examRecordList` / `studentHomework*`。
///
/// 成绩与排名直接取自 [DemoMarkingData]（4–10 月七场月考），与学情中心一致；
/// 另有下一场月考（未开始）与当天的线上阶段测评（进行中，可自录上传）。
abstract final class CampusAStudy {
  static const upcomingExamId = '28';
  static const onlineExamId = '29';
  static const _maxOnlineSubmits = 2;
  static const _autoReviewDelay = Duration(minutes: 2);

  static const _statusText = <String, String>{
    'NOT_STARTED': '未开始',
    'ONGOING': '进行中',
    'PENDING_SCORE': '待出成绩',
    'SCORED': '已出成绩',
  };

  /// 月考一天考完，三科时间与校级通知一致（见 `cbMonthlyExamTimes`）。
  static const _subjectTimes = <String, (String, String)>{
    '素描': ('08:30', '11:30'),
    '色彩': ('14:00', '17:00'),
    '速写': ('19:00', '20:00'),
  };

  static double _round1(double v) => (v * 10).round() / 10;

  static List<DemoExamEntry> _entries(DemoAccount account) =>
      CampusA.data.entriesOf(CampusA.personIndexOf(account));

  static List<DemoExamEntry> _scored(DemoAccount account) =>
      _entries(account).where((e) => e.scored).toList();

  static int _seatNo(int personIndex, String examId, int subject) =>
      (personIndex * 7 + (int.tryParse(examId) ?? 0) * 3 + subject * 11) % 60 +
      1;

  static String _hall(int personIndex, int subject) =>
      '${CampusA.person(personIndex).organizationName} · 考试大厅 ${const ['A', 'B', 'C'][subject % 3]} 区';

  // ── 考试列表 ────────────────────────────────────────────────────────

  static String _submitKey(DemoAccount account) =>
      'campusA:examSubmits:${account.userId}';

  static List<Map<String, dynamic>> _submits(DemoAccount account) =>
      DemoStore.list(_submitKey(account), () => <Map<String, dynamic>>[]);

  static Map<String, dynamic> _offlineSubject({
    required int personIndex,
    required String examId,
    required String date,
    required String subjectName,
    required int subjectId,
    required int order,
    double? score,
    String comment = '',
  }) {
    final times = _subjectTimes[subjectName] ?? ('08:30', '11:30');
    return <String, dynamic>{
      'subjectId': subjectId,
      'subjectName': subjectName,
      'evaluateType': 2,
      'examStartTime': '$date ${times.$1}:00',
      'examEndTime': '$date ${times.$2}:00',
      'classroomName': _hall(personIndex, order),
      'seatNo': _seatNo(personIndex, examId, order),
      'maxSubmitCount': 0,
      'submitCount': 0,
      'canSubmit': false,
      'score': score,
      'comment': comment,
      'submitFiles': const <Object>[],
    };
  }

  static Map<String, dynamic> _entryItem(DemoExamEntry e) {
    final index = e.person.index;
    final status = e.exam.reviewed ? 'SCORED' : 'PENDING_SCORE';
    final subjects = <Map<String, dynamic>>[];
    for (var i = 0; i < e.exam.subjects.length; i++) {
      final def = e.exam.subjects[i];
      final s = e.subject(def.subjectId);
      subjects.add(
        _offlineSubject(
          personIndex: index,
          examId: e.exam.examId,
          date: e.exam.examDate,
          subjectName: def.subjectName,
          subjectId: int.parse(def.subjectId),
          order: i,
          score: s?.score,
          comment: s == null ? '' : _commentOf(s, index),
        ),
      );
    }
    final scores = e.subjects?.map((s) => s.score).toList() ?? const <double>[];
    return <String, dynamic>{
      'examId': e.exam.examId,
      'examName': e.exam.examName,
      'examDate': e.exam.examDate,
      'examStatus': status,
      'examStatusText': _statusText[status],
      'uploadProgress': '',
      'remark': e.scored
          ? '成绩已发布，可在学情中心查看原卷与评分标准'
          : (e.exam.reviewed ? '本场缺考，无成绩' : '阅卷中，预计一周内出分'),
      'totalScore': scores.isEmpty
          ? null
          : _round1(scores.reduce((a, b) => a + b) / scores.length),
      'publishStatus': e.scored ? 1 : 0,
      'subjects': subjects,
    };
  }

  static Map<String, dynamic> _upcomingItem(int personIndex) {
    final day = CampusA.nextMonthlyExamDay();
    final date = CampusA.date(day);
    return <String, dynamic>{
      'examId': upcomingExamId,
      'examName': '${day.year} 年 ${day.month} 月月考',
      'examDate': date,
      'examStatus': 'NOT_STARTED',
      'examStatusText': _statusText['NOT_STARTED'],
      'uploadProgress': '',
      'remark': '请携带准考证提前 30 分钟入场；画板、画具自备，颜料不得提前调和，速写本统一发放。',
      'totalScore': null,
      'publishStatus': 0,
      'subjects': [
        for (final (i, name) in const ['素描', '色彩', '速写'].indexed)
          _offlineSubject(
            personIndex: personIndex,
            examId: upcomingExamId,
            date: date,
            subjectName: name,
            subjectId: 38 + i,
            order: i,
          ),
      ],
    };
  }

  static Map<String, dynamic> _onlineItem(DemoAccount account) {
    final date = CampusA.date(CampusA.today());
    final submits = _submits(account);
    Map<String, dynamic> subject(int subjectId, String name) {
      final files = [
        for (final s in submits)
          if (s['examId'] == onlineExamId &&
              s['date'] == date &&
              s['subjectId'] == subjectId)
            <String, dynamic>{
              'path': CampusA.media(s['path'].toString()),
              'fileType': s['fileType'],
              'fileName': s['fileName'],
              'uploadTime': s['uploadTime'],
            },
      ];
      return <String, dynamic>{
        'subjectId': subjectId,
        'subjectName': name,
        'evaluateType': 1,
        'examStartTime': '$date 00:00:00',
        'examEndTime': '$date 23:59:59',
        'classroomName': '',
        'seatNo': null,
        'maxSubmitCount': _maxOnlineSubmits,
        'submitCount': files.length,
        'canSubmit': files.length < _maxOnlineSubmits,
        'score': null,
        'comment': '',
        'submitFiles': files,
      };
    }

    final subjects = [subject(40, '速写'), subject(39, '色彩小稿')];
    final done = subjects.where((s) => (s['submitCount'] as int) > 0).length;
    return <String, dynamic>{
      'examId': onlineExamId,
      'examName': '速写 · 色彩线上阶段测评',
      'examDate': date,
      'examStatus': 'ONGOING',
      'examStatusText': _statusText['ONGOING'],
      'uploadProgress': '已上传 $done/${subjects.length} 科',
      'remark': '拍照提交作品：速写拍摄完整画面（可附过程视频），色彩小稿拍照上传；每科最多提交 2 次，以最后一次为准。',
      'totalScore': null,
      'publishStatus': 0,
      'subjects': subjects,
    };
  }

  static List<Map<String, dynamic>> examItems(DemoAccount account) {
    final index = CampusA.personIndexOf(account);
    final history = _entries(account).reversed.map(_entryItem).toList();
    return [_onlineItem(account), _upcomingItem(index), ...history];
  }

  static int pendingExamCount(DemoAccount account) => examItems(account)
      .where(
        (e) => e['examStatus'] == 'NOT_STARTED' || e['examStatus'] == 'ONGOING',
      )
      .length;

  static Map<String, dynamic> _examById(DemoAccount account, String id) {
    for (final item in examItems(account)) {
      if (item['examId'] == id) {
        return item;
      }
    }
    throw const DemoApiException('考试不存在');
  }

  // ── 成绩 ────────────────────────────────────────────────────────────

  static String _commentOf(DemoSubjectScore s, int personIndex) =>
      s.result.comments.isNotEmpty
      ? s.result.comments.join('；')
      : DemoMarkingData.commentFor(s.def.subjectName, personIndex, 0);

  static String _shortExamName(String name) =>
      name.replaceFirst(RegExp(r'^\d{4} 年 '), '');

  /// 学期均分（本学期有成绩的考试，按单科平均）。
  static double semesterAverage(DemoAccount account) {
    final scored = _scored(account);
    if (scored.isEmpty) {
      return 0;
    }
    final latest = DateTime.parse(scored.last.exam.examDate);
    bool sameTerm(DateTime d) {
      int term(DateTime x) => x.month >= 8
          ? x.year * 2 + 1
          : (x.month == 1 ? (x.year - 1) * 2 + 1 : x.year * 2);
      return term(d) == term(latest);
    }

    final scores = [
      for (final e in scored)
        if (sameTerm(DateTime.parse(e.exam.examDate)))
          for (final s in e.subjects!) s.score,
    ];
    return scores.isEmpty
        ? 0
        : _round1(scores.reduce((a, b) => a + b) / scores.length);
  }

  static Map<String, dynamic> _overview(DemoAccount account, String? subjectId) {
    final scored = _scored(account);
    double valueOf(DemoExamEntry e) =>
        subjectId == null ? e.total! : (e.subject(subjectId)?.score ?? 0);
    final subjectScores = [
      for (final e in scored)
        for (final s in e.subjects!)
          if (subjectId == null || s.def.subjectId == subjectId) s.score,
    ];
    DemoExamEntry? best;
    for (final e in scored) {
      if (best == null || valueOf(e) > valueOf(best)) {
        best = e;
      }
    }
    final latest = scored.isEmpty ? null : scored.last;
    const bands = <(String, double, double)>[
      ('90-100', 90, 101),
      ('80-89', 80, 90),
      ('70-79', 70, 80),
      ('60-69', 60, 70),
      ('60以下', 0, 60),
    ];
    return <String, dynamic>{
      'avgScore': subjectScores.isEmpty
          ? 0
          : _round1(
              subjectScores.reduce((a, b) => a + b) / subjectScores.length,
            ),
      'bestExam': best == null
          ? null
          : <String, dynamic>{
              'examId': best.exam.examId,
              'examName': best.exam.examName,
              'score': valueOf(best),
            },
      'latestClassRank': latest == null
          ? null
          : <String, dynamic>{
              'rank': latest.organizationRanking,
              'total': CampusA.data.participantCount(
                latest.exam.examId,
                latest.person.organizationName,
              ),
            },
      'latestSchoolRank': latest == null
          ? null
          : <String, dynamic>{
              'rank': latest.totalRanking,
              'total': CampusA.data.participantCount(latest.exam.examId),
            },
      'distribution': [
        for (final band in bands)
          () {
            final count = subjectScores
                .where((v) => v >= band.$2 && v < band.$3)
                .length;
            return <String, dynamic>{
              'range': band.$1,
              'count': count,
              'percent': subjectScores.isEmpty
                  ? 0
                  : (count * 100 / subjectScores.length).round(),
            };
          }(),
      ],
      'trendList': [
        for (final e in scored)
          <String, dynamic>{
            'examId': e.exam.examId,
            'examName': _shortExamName(e.exam.examName),
            'examDate': e.exam.examDate,
            'totalScore': valueOf(e),
            'classRank': subjectId == null
                ? e.organizationRanking
                : e.subject(subjectId)?.organizationRanking,
            'schoolRank': subjectId == null
                ? e.totalRanking
                : e.subject(subjectId)?.ranking,
            'subjectScores': [
              for (final s in e.subjects!)
                <String, dynamic>{
                  'subjectId': int.parse(s.def.subjectId),
                  'subjectName': s.def.subjectName,
                  'score': s.score,
                  'classRank': s.organizationRanking,
                  'schoolRank': s.ranking,
                },
            ],
          },
      ],
    };
  }

  static Map<String, dynamic> _record(DemoExamEntry e) {
    final index = e.person.index;
    final subjects = e.subjects!;
    final avg = subjects.map((s) => s.score).reduce((a, b) => a + b) /
        subjects.length;
    return <String, dynamic>{
      'examId': e.exam.examId,
      'examName': e.exam.examName,
      'examDate': e.exam.examDate,
      'totalScore': _round1(avg),
      'sumScore': e.total,
      'passSubjectCount': subjects.where((s) => s.score >= 60).length,
      'excellentSubjectCount': subjects.where((s) => s.score >= 85).length,
      'classRank': e.organizationRanking,
      'schoolRank': e.totalRanking,
      'subjectScores': [
        for (final s in subjects)
          <String, dynamic>{
            'subjectId': int.parse(s.def.subjectId),
            'subjectName': s.def.subjectName,
            'score': s.score,
            'grade': s.grade,
            'classRank': s.organizationRanking,
            'schoolRank': s.ranking,
            'comment': _commentOf(s, index),
            'path': s.result.judges.isEmpty
                ? ''
                : CampusA.media(
                    DemoMarkingData.paperRef(
                      s.def.subjectName,
                      index,
                      e.exam.examId,
                    ),
                  ),
            'headUrl': '',
            'nickname': DemoMarkingData.teacherOf(s.def.subjectName, index, 0),
          },
      ],
    };
  }

  // ── 作业 ────────────────────────────────────────────────────────────

  static const _feedbackPool = <String, List<String>>{
    '素描': [
      '形体结构交代清楚，明暗交界线再肯定一些，暗部注意整体。',
      '构图饱满，五大调子完整；亮部层次可以再丰富，避免画花。',
    ],
    '色彩': [
      '色调统一，冷暖关系到位；衬布转折处颜色再丰富些，高光不要用纯白。',
      '主体物塑造充分，背景可以适当降低纯度，让画面更透气。',
    ],
    '速写': [
      '动态抓得准，线条流畅；手脚结构再交代清楚会更好。',
      '组合人物前后关系清楚，注意头身比例，重心再稳一些。',
    ],
  };

  static String _feedbackFor(String subject, int seed) {
    for (final entry in _feedbackPool.entries) {
      if (subject.contains(entry.key)) {
        return entry.value[seed % entry.value.length];
      }
    }
    return '完成认真，论述清晰，继续保持。';
  }

  static String _homeworkKey(DemoAccount account) =>
      'campusA:homework:${account.userId}';

  static List<Map<String, dynamic>> homework(DemoAccount account) {
    final key = _homeworkKey(account);
    final list = DemoStore.list(key, () => _seedHomework(account));
    final now = DateTime.now().millisecondsSinceEpoch;
    var changed = false;
    for (final item in list) {
      final submitted = (item['submittedAtMs'] as num?)?.toInt();
      if (item['status'] == 1 &&
          submitted != null &&
          now - submitted >= _autoReviewDelay.inMilliseconds) {
        final seed = CampusA.hash('${item['homeworkStudentId']}');
        item['status'] = 2;
        item['score'] = 82 + seed % 12;
        item['feedback'] = _feedbackFor(item['subjectName'].toString(), seed);
        item['reviewTime'] = CampusA.dateTime(
          DateTime.fromMillisecondsSinceEpoch(
            submitted + _autoReviewDelay.inMilliseconds,
          ),
        );
        item.remove('submittedAtMs');
        changed = true;
      }
    }
    if (changed) {
      DemoStore.save(key);
    }
    return list;
  }

  static bool _overdue(Map<String, dynamic> item) {
    final end = CampusA.parseDateTime(item['endTime'].toString());
    return item['status'] == 0 && end != null && DateTime.now().isAfter(end);
  }

  static int pendingHomeworkCount(DemoAccount account) =>
      homework(account).where((e) => e['status'] == 0).length;

  static List<Map<String, dynamic>> _seedHomework(DemoAccount account) {
    final c = CampusA.classOf(CampusA.personIndexOf(account));
    String day(int offset, String clock) =>
        CampusA.dateTime(CampusA.at(CampusA.today().add(Duration(days: offset)), clock));
    Map<String, dynamic> hw({
      required String id,
      required String title,
      required String subject,
      required String teacherId,
      required String ext,
      required String desc,
      required int created,
      required int due,
      int status = 0,
      int? submitted,
      String? file,
      String? fileName,
      String note = '',
      int? score,
      String feedback = '',
    }) {
      final teacher = CampusA.staff(teacherId);
      return <String, dynamic>{
        'id': '7$id',
        'homeworkStudentId': id,
        'title': title,
        'description': desc,
        'subjectName': subject,
        'subjectId': CampusACourses.subjectIdOf(subject),
        'teacherId': teacher.userId,
        'teacherName': teacher.name,
        'classId': c.id,
        'className': c.name,
        'expectedExt': ext,
        'createTime': day(created, '19:20'),
        'endTime': day(due, '21:00'),
        'status': status,
        'submitTime': submitted == null ? '' : day(submitted, '20:15'),
        'score': score,
        'feedback': feedback,
        'studentParam1': file ?? '',
        'studentParam2': fileName ?? '',
        'studentParam3': submitted == null
            ? ''
            : (ext == 'video' ? '视频' : (ext == 'doc' ? '文档' : '照片')),
        'studentDescription': note,
      };
    }

    return [
      hw(
        id: '6101',
        title: '素描几何体组合（明暗）',
        subject: '素描',
        teacherId: 't-1',
        ext: 'image',
        desc: '4 开素描纸完成正方体、圆锥、球体组合写生，要求明暗交界线清晰、五大调子完整，时长 3 小时，拍照上传。',
        created: -1,
        due: 2,
      ),
      hw(
        id: '6104',
        title: '速写过程录制（10 分钟人物动态）',
        subject: '速写',
        teacherId: 't-4',
        ext: 'video',
        desc: '录制一段 10 分钟人物动态速写过程视频，展示起形—定动态—深入刻画的步骤，横屏拍摄。',
        created: -1,
        due: 3,
      ),
      hw(
        id: '6103',
        title: '名作临摹：伦勃朗自画像局部',
        subject: '素描',
        teacherId: 't-1',
        ext: 'image',
        desc: '临摹伦勃朗自画像头部局部，重点体会光影塑造与体积感，8 开纸，可用炭笔。',
        created: -2,
        due: 5,
      ),
      hw(
        id: '6102',
        title: '色彩静物默写',
        subject: '色彩',
        teacherId: 't-3',
        ext: 'image',
        desc: '默写一组冷色调静物（陶罐、苹果、蓝灰衬布），8 开水粉纸，注意色调统一与冷暖对比。',
        created: -4,
        due: -1,
      ),
      hw(
        id: '6105',
        title: '色彩风景写生小稿',
        subject: '色彩',
        teacherId: 't-3',
        ext: 'image',
        desc: '黄河岸边写生小稿 2 张，16 开，表现傍晚时分的光色变化。',
        created: -6,
        due: -2,
        status: 1,
        submitted: -3,
        file: 'asset:assets/demo/art/color-landscape-1.jpg',
        fileName: '黄河岸边写生小稿.jpg',
        note: '天空部分感觉有点灰，请老师指导一下。',
      ),
      hw(
        id: '6106',
        title: '速写组合人物 3 张',
        subject: '速写',
        teacherId: 't-4',
        ext: 'image',
        desc: '以画室同学为模特完成 3 张两人以上组合速写，注意人物之间的前后与呼应关系。',
        created: -5,
        due: -1,
        status: 1,
        submitted: -2,
        file: 'asset:assets/demo/art/speed-group-1.jpg',
        fileName: '组合人物速写.jpg',
        note: '第三张画了画室一角的同学们。',
      ),
      hw(
        id: '6107',
        title: '石膏头像结构练习（大卫）',
        subject: '素描',
        teacherId: 't-1',
        ext: 'image',
        desc: '大卫石膏像结构素描，用线面结合的方式交代头骨结构与五官穿插关系。',
        created: -12,
        due: -9,
        status: 2,
        submitted: -10,
        file: 'asset:assets/demo/art/sketch-bust-2.jpg',
        fileName: '大卫结构素描.jpg',
        score: 88,
        feedback: '结构交代清楚，暗部再整体一些，眼窝和鼻底的投影要统一在同一光源下。',
      ),
      hw(
        id: '6108',
        title: '静物色彩·冷暖对比',
        subject: '色彩',
        teacherId: 't-3',
        ext: 'image',
        desc: '暖光源下的静物写生，重点表现亮部暖、暗部冷的色彩关系。',
        created: -14,
        due: -11,
        status: 2,
        submitted: -12,
        file: 'asset:assets/demo/art/color-still-3.jpg',
        fileName: '冷暖对比静物.jpg',
        score: 85,
        feedback: '色调明确，冷暖对比到位；衬布转折处颜色再丰富些，高光不要用纯白。',
      ),
      hw(
        id: '6109',
        title: '人物动态速写 20 张',
        subject: '速写',
        teacherId: 't-4',
        ext: 'image',
        desc: '一周内完成 20 张 5 分钟人物动态速写，挑选 5 张最满意的拍照上传。',
        created: -16,
        due: -9,
        status: 2,
        submitted: -10,
        file: 'asset:assets/demo/art/speed-figure-3.jpg',
        fileName: '动态速写精选.jpg',
        score: 90,
        feedback: '动态抓得准，线条流畅；手脚的结构再交代清楚就更好了。',
      ),
      hw(
        id: '6110',
        title: '美术常识：中国画六法',
        subject: '美术常识',
        teacherId: 't-7',
        ext: 'doc',
        desc: '阅读谢赫「六法论」，结合一幅宋代山水画作品写 800 字读书笔记。',
        created: -18,
        due: -13,
        status: 2,
        submitted: -14,
        fileName: '中国画六法读书笔记.docx',
        score: 92,
        feedback: '论述清晰，「气韵生动」部分举例恰当，继续保持。',
      ),
      hw(
        id: '6111',
        title: '素描五官局部（眼睛）',
        subject: '素描',
        teacherId: 't-1',
        ext: 'image',
        desc: '眼睛局部写生 4 个角度，注意上下眼睑的厚度与眼球的球体感。',
        created: -21,
        due: -18,
        status: 2,
        submitted: -19,
        file: 'asset:assets/demo/art/sketch-portrait-1.jpg',
        fileName: '五官局部-眼睛.jpg',
        score: 86,
        feedback: '眼球体积感塑造得不错，眼睑的厚度再表现出来，睫毛不要画成线。',
      ),
      hw(
        id: '6112',
        title: '色彩花卉写生',
        subject: '色彩',
        teacherId: 't-3',
        ext: 'image',
        desc: '瓶花写生一张，8 开，注意花卉的纯度变化与背景的空间感。',
        created: -26,
        due: -23,
        status: 2,
        submitted: -24,
        file: 'asset:assets/demo/art/color-flower-1.jpg',
        fileName: '瓶花写生.jpg',
        score: 89,
        feedback: '花卉颜色鲜活，背景处理得透气；花瓶的投影可以再冷一点。',
      ),
    ];
  }

  static Map<String, dynamic> _homeworkRow(Map<String, dynamic> item) {
    final status = item['status'] as int;
    return <String, dynamic>{
      'id': item['id'],
      'homeworkId': item['id'],
      'homeworkStudentId': item['homeworkStudentId'],
      'title': item['title'],
      'description': item['description'],
      'createTime': item['createTime'],
      'endTime': item['endTime'],
      'teacherName': item['teacherName'],
      'subjectName': item['subjectName'],
      'subjectId': item['subjectId'],
      'expectedExt': item['expectedExt'],
      'classId': item['classId'],
      'className': item['className'],
      'homeworkStudentStatus': status,
      'status': status,
      'submitTime': item['submitTime'],
      'score': status == 2 ? item['score'] : null,
      'feedback': status == 2 ? item['feedback'] : '',
      'fileName': item['studentParam2'],
      'studentParam2': item['studentParam2'],
    };
  }

  static Map<String, dynamic> _homeworkDetail(Map<String, dynamic> item) {
    final status = item['status'] as int;
    return <String, dynamic>{
      'homework': <String, dynamic>{
        'id': item['id'],
        'title': item['title'],
        'description': item['description'],
        'createTime': item['createTime'],
        'endTime': item['endTime'],
        'teacherName': item['teacherName'],
        'expectedExt': item['expectedExt'],
        'subjectName': item['subjectName'],
        'subjectId': item['subjectId'],
      },
      'homeworkStudent': <String, dynamic>{
        'id': item['homeworkStudentId'],
        'status': status,
        'submitTime': item['submitTime'],
        'score': status == 2 ? item['score'] : null,
        'feedback': status == 2 ? item['feedback'] : '',
        'studentParam1': CampusA.media(item['studentParam1'].toString()),
        'studentParam2': item['studentParam2'],
        'studentParam3': item['studentParam3'],
        'description': item['studentDescription'],
        'teacherParam1': '',
        'teacherParam2': '',
      },
      'subject': <String, dynamic>{
        'id': item['subjectId'],
        'name': item['subjectName'],
      },
      'classInfo': <String, dynamic>{
        'id': item['classId'],
        'name': item['className'],
      },
      'teacherName': item['teacherName'],
    };
  }

  static Map<String, dynamic> _homeworkSummary(DemoAccount account) {
    final list = homework(account);
    final reviewed = list.where((e) => e['status'] == 2).toList();
    List<Map<String, dynamic>> averages(String key) {
      final groups = <String, List<num>>{};
      for (final item in reviewed) {
        groups
            .putIfAbsent(item[key].toString(), () => <num>[])
            .add(item['score'] as num);
      }
      return [
        for (final entry in groups.entries)
          <String, dynamic>{
            key: entry.key,
            'avgScore': _round1(
              entry.value.reduce((a, b) => a + b) / entry.value.length,
            ),
          },
      ];
    }

    const ranges = <(String, int, int)>[
      ('90-100', 90, 101),
      ('80-89', 80, 90),
      ('70-79', 70, 80),
      ('70以下', 0, 70),
    ];
    return <String, dynamic>{
      'subjectAvgScores': averages('subjectName'),
      'teacherAvgScores': averages('teacherName'),
      'scoreRanges': [
        for (final range in ranges)
          () {
            final count = reviewed.where((e) {
              final score = e['score'] as num;
              return score >= range.$2 && score < range.$3;
            }).length;
            return <String, dynamic>{
              'range': range.$1,
              'count': count,
              'percent': reviewed.isEmpty
                  ? 0
                  : (count * 100 / reviewed.length).round(),
            };
          }(),
      ],
      'total': list.length,
      'pending': list.where((e) => e['status'] == 0).length,
      'submitted': list.where((e) => e['status'] == 1).length,
      'reviewed': reviewed.length,
      'overdue': list.where(_overdue).length,
    };
  }

  // ── 接口 ────────────────────────────────────────────────────────────

  static void register(DemoRouter r) {
    const base = '/app/school/v2/student';

    r.post('$base/myExamList', (req) {
      final tab = req.intOf('tab');
      return [
        for (final item in examItems(req.account))
          if (tab == 0 ||
              (tab == 1 &&
                  (item['examStatus'] == 'NOT_STARTED' ||
                      item['examStatus'] == 'ONGOING')) ||
              (tab == 2 &&
                  (item['examStatus'] == 'PENDING_SCORE' ||
                      item['examStatus'] == 'SCORED')))
            item,
      ];
    });

    r.post('$base/myExamDetail', (req) => _examById(req.account, req.str('id')));

    r.post('$base/examSeat', (req) {
      final exam = _examById(req.account, req.str('id'));
      final subjects = (exam['subjects'] as List).cast<Map<String, dynamic>>();
      final online = subjects.every((s) => s['evaluateType'] == 1);
      return <String, dynamic>{
        'examName': exam['examName'],
        'examDate': exam['examDate'],
        'remark': online
            ? '本场为线上测评，无需到考场，请在规定时间内自录上传。'
            : '请凭准考证按座位号就座，考前 15 分钟停止入场。',
        'seats': [
          for (final s in subjects)
            <String, dynamic>{
              'subjectName': s['subjectName'],
              'classroomName': s['classroomName'],
              'seatNo': s['seatNo'],
            },
        ],
      };
    });

    r.post('$base/examSubmit', (req) {
      final account = req.account;
      if (req.str('examId') != onlineExamId) {
        throw const DemoApiException('该科目为线下考试，无需在线提交');
      }
      final subjectId = req.intOf('subjectId');
      final exam = _onlineItem(account);
      Map<String, dynamic>? subject;
      for (final s in (exam['subjects'] as List).cast<Map<String, dynamic>>()) {
        if (s['subjectId'] == subjectId) {
          subject = s;
        }
      }
      if (subject == null) {
        throw const DemoApiException('科目不存在');
      }
      if (subject['canSubmit'] != true) {
        throw const DemoApiException('已达到最多提交次数');
      }
      final path = req.str('filePath');
      if (path.isEmpty) {
        throw const DemoApiException('请先上传文件');
      }
      final now = DateTime.now();
      _submits(account).add(<String, dynamic>{
        'examId': onlineExamId,
        'date': CampusA.date(now),
        'subjectId': subjectId,
        'path': CampusA.toRef(path),
        'fileType': req.str('fileType', 'image'),
        'fileName': CampusA.fileNameOf(path),
        'uploadTime': CampusA.dateTime(now),
      });
      DemoStore.save(_submitKey(account));
      return true;
    });

    r.post('$base/examOverview', (req) {
      final raw = req.value('subjectId');
      return _overview(req.account, raw == null ? null : req.str('subjectId'));
    });

    r.post('$base/examRecordList', (req) {
      return [
        for (final e in _scored(req.account).reversed) _record(e),
      ];
    });

    r.post('$base/studentHomeworkList', (req) {
      final status = req.value('status') == null ? null : req.intOf('status');
      final list = [
        for (final item in homework(req.account))
          if (status == null || item['status'] == status) _homeworkRow(item),
      ]..sort(CampusA.compareTimeDesc);
      return CampusA.page(list, req);
    });

    r.post('$base/studentHomeworkSum', (req) => _homeworkSummary(req.account));

    r.post('$base/studentHomeworkDetail', (req) {
      final id = req.str('id');
      for (final item in homework(req.account)) {
        if (item['homeworkStudentId'] == id || item['id'] == id) {
          return _homeworkDetail(item);
        }
      }
      throw const DemoApiException('作业不存在');
    });

    r.post('$base/studentHomeworkSubmit', (req) {
      final account = req.account;
      final id = req.str('id');
      Map<String, dynamic>? target;
      for (final item in homework(account)) {
        if (item['homeworkStudentId'] == id) {
          target = item;
        }
      }
      if (target == null) {
        throw const DemoApiException('作业不存在');
      }
      if (target['status'] != 0) {
        throw const DemoApiException('作业已提交，请等待老师批阅');
      }
      final now = DateTime.now();
      target
        ..['status'] = 1
        ..['submitTime'] = CampusA.dateTime(now)
        ..['studentParam1'] = CampusA.toRef(req.str('studentParam1'))
        ..['studentParam2'] = req.str('studentParam2')
        ..['studentParam3'] = req.str('studentParam3')
        ..['studentDescription'] = req.str('description')
        ..['submittedAtMs'] = now.millisecondsSinceEpoch;
      DemoStore.save(_homeworkKey(account));
      return true;
    });
  }
}
