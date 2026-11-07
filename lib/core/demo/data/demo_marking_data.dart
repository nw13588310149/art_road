/// 阅卷系统演示数据（移植自艺考网学情小程序的演示适配器，学生、分数、
/// 评委、仲裁与排名保持一致）：示范画室三校区、2026 年 4–10 月七场月考、
/// 40 名学生，每科多位老师独立评阅，最终分按算术 / 截尾平均。
///
/// 学情中心、作品点评、智慧校园成绩等演示接口共用这一份数据。
library;

class DemoSubjectDef {
  const DemoSubjectDef({
    required this.subjectId,
    required this.subjectName,
    required this.fullScore,
    required this.trimmed,
    required this.diffThreshold,
    required this.judgeCount,
  });

  final String subjectId;
  final String subjectName;
  final double fullScore;

  /// true：截尾平均（去掉一个最高、一个最低）；false：算术平均。
  final bool trimmed;
  final double diffThreshold;
  final int judgeCount;
}

class DemoExamDef {
  const DemoExamDef({
    required this.examId,
    required this.examName,
    required this.examDate,
    required this.reviewed,
    required this.subjects,
  });

  final String examId;
  final String examName;
  final String examDate;

  /// false：阅卷中，还没有成绩。
  final bool reviewed;
  final List<DemoSubjectDef> subjects;

  String get examCode => 'E${examDate.replaceAll('-', '')}';
  double get fullScore => subjects.fold(0, (sum, s) => sum + s.fullScore);
}

class DemoArbitration {
  const DemoArbitration({required this.grade, required this.finalScore});

  final String grade;
  final double finalScore;
}

class DemoSubjectResult {
  const DemoSubjectResult({
    required this.subjectId,
    required this.judges,
    this.arbitration,
    this.manualScore,
    this.comments = const <String>[],
  });

  final String subjectId;

  /// 各老师分数，顺序即分配顺序；空列表表示手工录入。
  final List<double> judges;
  final DemoArbitration? arbitration;
  final double? manualScore;
  final List<String> comments;
}

class DemoRegistration {
  const DemoRegistration({required this.examId, this.results});

  final String examId;

  /// null：报了名但没有成绩（缺考 / 阅卷中）。
  final List<DemoSubjectResult>? results;
}

class DemoPerson {
  const DemoPerson({
    required this.index,
    required this.name,
    required this.gender,
    required this.idCard,
    required this.phone,
    required this.organizationName,
    required this.registrations,
  });

  final int index;
  final String name;
  final String gender;
  final String idCard;
  final String phone;
  final String organizationName;
  final List<DemoRegistration> registrations;

  /// 学生档案 id（字符串承载），只在接口里用，不给老师和学生看。
  String get archiveId => '${900000 + index}';

  /// 画室学号，与智慧校园学生名册一致（2027 届 + 三位序号）。
  String get studentNo => '2027${index.toString().padLeft(3, '0')}';

  String get idCardMasked => idCard.length == 18
      ? '${idCard.substring(0, 6)}********${idCard.substring(14)}'
      : idCard;

  String get phoneMasked => phone.length == 11
      ? '${phone.substring(0, 3)}****${phone.substring(7)}'
      : phone;

  /// 演示档案照：前两位用设计稿头像，其余由前端按姓名首字渲染。
  String get avatarRef => switch (index) {
    1 => 'asset:assets/demo/avatars/student_female.png',
    2 => 'asset:assets/demo/avatars/student_male.png',
    _ => '',
  };
}

class DemoSubjectScore {
  DemoSubjectScore({
    required this.def,
    required this.result,
    required this.score,
  });

  final DemoSubjectDef def;
  final DemoSubjectResult result;
  final double score;
  int ranking = 0;
  int organizationRanking = 0;

  String get grade =>
      result.arbitration?.grade ??
      DemoMarkingData.gradeOf(score, DemoMarkingData.bandsFor(def));
}

class DemoExamEntry {
  DemoExamEntry({
    required this.person,
    required this.exam,
    required this.registration,
    required this.subjects,
    required this.total,
  });

  final DemoPerson person;
  final DemoExamDef exam;
  final DemoRegistration registration;
  final List<DemoSubjectScore>? subjects;
  final double? total;
  int? totalRanking;
  int? organizationRanking;

  /// 本场报名 id（考生 id）。
  String get studentId =>
      '${exam.examId}${person.index.toString().padLeft(3, '0')}';

  String get admissionNo =>
      'A${exam.examId}${person.index.toString().padLeft(4, '0')}';

  bool get scored => total != null;

  DemoSubjectScore? subject(String subjectId) {
    for (final s in subjects ?? const <DemoSubjectScore>[]) {
      if (s.def.subjectId == subjectId) {
        return s;
      }
    }
    return null;
  }
}

class DemoGradeBand {
  const DemoGradeBand({
    required this.grade,
    required this.min,
    required this.max,
    required this.description,
    required this.imageRef,
  });

  final String grade;
  final double min;
  final double max;
  final String description;

  /// 档位样图（`asset:` 引用）；空串表示该档无样图。
  final String imageRef;
}

class DemoTeacher {
  const DemoTeacher({
    required this.id,
    required this.name,
    required this.subject,
  });

  final String id;
  final String name;
  final String subject;
}

/// mulberry32：与小程序演示数据同一伪随机序列，保证两端演示数据一致。
class _Mulberry32 {
  _Mulberry32(int seed) : _a = seed & 0xFFFFFFFF;

  int _a;

  double next() {
    _a = (_a + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _a;
    t = _imul(t ^ (t >>> 15), t | 1);
    t = (t ^ ((t + _imul(t ^ (t >>> 7), t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    return ((t ^ (t >>> 14)) & 0xFFFFFFFF) / 4294967296;
  }

  static int _imul(int a, int b) {
    final ah = (a >>> 16) & 0xFFFF;
    final al = a & 0xFFFF;
    final bh = (b >>> 16) & 0xFFFF;
    final bl = b & 0xFFFF;
    return ((al * bl) + ((((ah * bl + al * bh) & 0xFFFF) << 16))) & 0xFFFFFFFF;
  }
}

class DemoMarkingData {
  DemoMarkingData._() {
    _build();
  }

  static final DemoMarkingData instance = DemoMarkingData._();

  static const schoolId = '1';
  static const schoolName = '示范画室';
  static const organizations = <String>['城东校区', '城西校区', '安宁校区'];
  static const subjectIds = <String, String>{'素描': '38', '色彩': '39', '速写': '40'};

  static const teachersBySubject = <String, List<String>>{
    '素描': ['张明远', '李静', '王海波', '赵雪', '陈立'],
    '色彩': ['刘芳', '周强', '吴雨桐', '孙磊', '郑可'],
    '速写': ['何佳', '高峰', '罗敏', '马骏', '朱琳'],
  };

  /// 作品点评老师（李静为演示任课老师账号）。
  static const reviewTeachers = <DemoTeacher>[
    DemoTeacher(id: 't-1', name: '李静', subject: '素描'),
    DemoTeacher(id: 't-2', name: '张明远', subject: '素描'),
    DemoTeacher(id: 't-3', name: '刘芳', subject: '色彩'),
    DemoTeacher(id: 't-4', name: '赵雪', subject: '速写'),
  ];

  /// 演示任课老师关联的学生（[DemoPerson.index]）。
  static const teacherPersonIndices = <int>[
    1, 2, 4, 6, 9, 12, 15, 18, 21, 25, 30, 34,
  ];

  late final List<DemoExamDef> exams;
  late final List<DemoPerson> persons;
  late final List<DemoExamEntry> entries;

  static List<DemoSubjectDef> _subjectDefs(int judgeCount) => [
    for (final name in const ['素描', '色彩', '速写'])
      DemoSubjectDef(
        subjectId: subjectIds[name]!,
        subjectName: name,
        fullScore: 100,
        trimmed: judgeCount >= 5,
        diffThreshold: 10,
        judgeCount: judgeCount,
      ),
  ];

  void _build() {
    exams = [
      DemoExamDef(examId: '21', examName: '2026 年 4 月月考', examDate: '2026-04-19', reviewed: true, subjects: _subjectDefs(2)),
      DemoExamDef(examId: '22', examName: '2026 年 5 月月考', examDate: '2026-05-17', reviewed: true, subjects: _subjectDefs(2)),
      DemoExamDef(examId: '23', examName: '2026 年 6 月月考', examDate: '2026-06-21', reviewed: true, subjects: _subjectDefs(2)),
      DemoExamDef(examId: '24', examName: '暑期集训阶段考', examDate: '2026-07-26', reviewed: true, subjects: _subjectDefs(5)),
      DemoExamDef(examId: '25', examName: '2026 年 8 月月考', examDate: '2026-08-23', reviewed: true, subjects: _subjectDefs(2)),
      DemoExamDef(examId: '26', examName: '2026 年 9 月月考', examDate: '2026-09-20', reviewed: true, subjects: _subjectDefs(2)),
      DemoExamDef(examId: '27', examName: '2026 年 10 月月考', examDate: '2026-10-18', reviewed: false, subjects: _subjectDefs(2)),
    ];
    persons = [
      ..._featured(),
      for (var i = 3; i <= 40; i++) _generated(i),
    ];
    entries = [];
    for (final person in persons) {
      for (final reg in person.registrations) {
        final exam = exams.firstWhere((e) => e.examId == reg.examId);
        final subjects = reg.results?.map((result) {
          final def = exam.subjects.firstWhere(
            (s) => s.subjectId == result.subjectId,
          );
          return DemoSubjectScore(
            def: def,
            result: result,
            score: finalScoreOf(result, def),
          );
        }).toList();
        final total = subjects == null
            ? null
            : _round(subjects.fold<double>(0, (sum, s) => sum + s.score), 2);
        entries.add(
          DemoExamEntry(
            person: person,
            exam: exam,
            registration: reg,
            subjects: subjects,
            total: total,
          ),
        );
      }
    }
    for (final exam in exams) {
      final scored = entries.where((e) => e.exam == exam && e.scored).toList();
      final totals = scored.map((e) => e.total!).toList();
      for (final e in scored) {
        e.totalRanking = _rankOf(e.total!, totals);
        final sameOrg = scored
            .where((x) => x.person.organizationName == e.person.organizationName)
            .map((x) => x.total!)
            .toList();
        e.organizationRanking = _rankOf(e.total!, sameOrg);
        for (final s in e.subjects!) {
          final peers = scored
              .map((x) => x.subject(s.def.subjectId)?.score ?? -1)
              .toList();
          s.ranking = _rankOf(s.score, peers);
          final orgPeers = scored
              .where(
                (x) => x.person.organizationName == e.person.organizationName,
              )
              .map((x) => x.subject(s.def.subjectId)?.score ?? -1)
              .toList();
          s.organizationRanking = _rankOf(s.score, orgPeers);
        }
      }
    }
  }

  // ── 查询 ──────────────────────────────────────────────────────────────

  DemoPerson person(int index) => persons.firstWhere((p) => p.index == index);

  DemoPerson? personByArchiveId(String archiveId) {
    for (final p in persons) {
      if (p.archiveId == archiveId) {
        return p;
      }
    }
    return null;
  }

  DemoExamDef? exam(String examId) {
    for (final e in exams) {
      if (e.examId == examId) {
        return e;
      }
    }
    return null;
  }

  /// 某学生全部报名，考试时间正序。
  List<DemoExamEntry> entriesOf(int personIndex) =>
      entries.where((e) => e.person.index == personIndex).toList()
        ..sort((a, b) => a.exam.examDate.compareTo(b.exam.examDate));

  DemoExamEntry? entryOf(int personIndex, String examId) {
    for (final e in entries) {
      if (e.person.index == personIndex && e.exam.examId == examId) {
        return e;
      }
    }
    return null;
  }

  List<DemoExamEntry> entriesOfExam(String examId) =>
      entries.where((e) => e.exam.examId == examId).toList();

  int participantCount(String examId, [String? organizationName]) => entries
      .where(
        (e) =>
            e.exam.examId == examId &&
            e.scored &&
            (organizationName == null ||
                e.person.organizationName == organizationName),
      )
      .length;

  /// 同一学生在 [examId] 之前最近一次有成绩的考试。
  DemoExamEntry? previousScoredEntry(int personIndex, String examId) {
    final list = entriesOf(personIndex);
    final idx = list.indexWhere((e) => e.exam.examId == examId);
    for (var i = idx - 1; i >= 0; i--) {
      if (list[i].scored) {
        return list[i];
      }
    }
    return null;
  }

  // ── 评分规则 ──────────────────────────────────────────────────────────

  static double finalScoreOf(DemoSubjectResult result, DemoSubjectDef def) {
    if (result.manualScore != null) {
      return result.manualScore!;
    }
    if (result.arbitration != null) {
      return result.arbitration!.finalScore;
    }
    final sorted = [...result.judges]..sort();
    final used = def.trimmed && sorted.length >= 3
        ? sorted.sublist(1, sorted.length - 1)
        : sorted;
    return _round(used.fold<double>(0, (a, b) => a + b) / used.length, 1);
  }

  static const _bandText = <String, List<String>>{
    '素描': [
      '构图饱满完整，形体结构准确，明暗层次丰富，空间感与质感表现突出，画面整体生动。',
      '构图合理，形体比例基本准确，明暗关系清楚，有一定空间感，局部刻画略欠深入。',
      '构图基本完整，形体比例有偏差，明暗层次较少，画面略显平淡。',
      '构图欠完整，形体结构问题较多，明暗关系混乱，刻画不充分。',
      '未完成作答，或基本造型能力明显不足。',
    ],
    '色彩': [
      '色调明确统一，色彩关系准确生动，冷暖对比恰当，塑造充分，画面有感染力。',
      '色调基本统一，色彩关系较准确，塑造较充分，局部色彩略显生硬。',
      '有一定色调倾向，色彩关系基本正确，塑造一般，画面略显灰或花。',
      '色调不明确，色彩关系混乱，塑造不足。',
      '未完成作答，或色彩表现能力明显不足。',
    ],
    '速写': [
      '人物动态生动自然，比例结构准确，线条流畅有表现力，组织关系合理。',
      '动态较准确，比例基本正确，线条较流畅，细节处理略显不足。',
      '动态基本合理，比例有偏差，线条较生硬。',
      '动态不合理，比例结构问题明显，线条缺乏组织。',
      '未完成作答，或基本造型能力明显不足。',
    ],
  };

  static const _bandSamples = <String, List<String>>{
    '素描': [
      'asset:assets/demo/art/sketch-bust-2.jpg',
      'asset:assets/demo/papers/sketch.jpg',
    ],
    '色彩': [
      'asset:assets/demo/art/color-still-1.jpg',
      'asset:assets/demo/papers/color.jpg',
    ],
    '速写': [
      'asset:assets/demo/art/speed-figure-2.jpg',
      'asset:assets/demo/papers/speed.jpg',
    ],
  };

  /// 档位按满分的 90% / 80% / 70% / 60% 切分，与机构端打分规则常见配置一致。
  static List<DemoGradeBand> bandsFor(DemoSubjectDef def) =>
      bands(def.subjectName, def.fullScore);

  static List<DemoGradeBand> bands(String subjectName, double fullScore) {
    final text = _bandText[subjectName] ?? _bandText['素描']!;
    final samples = _bandSamples[subjectName] ?? _bandSamples['素描']!;
    final cut = [0.9, 0.8, 0.7, 0.6, 0.0]
        .map((p) => (fullScore * p * 2).round() / 2)
        .toList();
    return [
      for (var i = 0; i < 5; i++)
        DemoGradeBand(
          grade: const ['A', 'B', 'C', 'D', 'E'][i],
          min: cut[i],
          max: i == 0 ? fullScore : cut[i - 1] - 0.5,
          description: text[i],
          imageRef: i < samples.length ? samples[i] : '',
        ),
    ];
  }

  static String gradeOf(double score, List<DemoGradeBand> bands) {
    final sorted = [...bands]..sort((a, b) => b.min.compareTo(a.min));
    for (final band in sorted) {
      if (score >= band.min) {
        return band.grade;
      }
    }
    return sorted.isEmpty ? '' : sorted.last.grade;
  }

  static String teacherOf(String subjectName, int personIndex, int i) {
    final pool = teachersBySubject[subjectName] ?? const <String>[];
    return pool.isEmpty ? '评委 ${i + 1}' : pool[(personIndex + i) % pool.length];
  }

  /// 原卷轮换用的写生作品（示意线稿 `papers/*.jpg` 不当作考卷，避免高分卷是一张示意图）。
  static const _papers = <String, List<String>>{
    '素描': [
      'asset:assets/demo/art/sketch-bust-1.jpg',
      'asset:assets/demo/art/sketch-bust-3.jpg',
      'asset:assets/demo/art/sketch-still-1.jpg',
      'asset:assets/demo/art/sketch-still-2.jpg',
      'asset:assets/demo/art/sketch-geometry-1.jpg',
    ],
    '色彩': [
      'asset:assets/demo/art/color-still-2.jpg',
      'asset:assets/demo/art/color-still-3.jpg',
      'asset:assets/demo/art/color-still-4.jpg',
      'asset:assets/demo/art/color-still-5.jpg',
    ],
    '速写': [
      'asset:assets/demo/art/speed-figure-3.jpg',
      'asset:assets/demo/art/speed-figure-4.jpg',
      'asset:assets/demo/art/speed-figure-5.jpg',
      'asset:assets/demo/art/speed-figure-1.jpg',
    ],
  };

  /// 某次考试某科的原卷图（演示：按学生与考试轮换示例画作）。
  static String paperRef(String subjectName, int personIndex, String examId) {
    final pool = _papers[subjectName] ?? _papers['素描']!;
    final seed = personIndex + (int.tryParse(examId) ?? 0);
    return pool[seed % pool.length];
  }

  static const _commentPool = <String, List<String>>{
    '素描': [
      '形体结构交代清楚，明暗交界线再肯定一些',
      '暗部层次可以再丰富，注意反光不要过亮',
      '构图偏上，下方留白过多',
      '五官比例准确，头发体积感可以加强',
    ],
    '色彩': [
      '色调统一，主体物塑造较充分',
      '背景与衬布冷暖关系可以拉开',
      '亮部颜色偏粉，注意固有色倾向',
      '笔触有力，暗部颜色略闷',
    ],
    '速写': [
      '动态生动，重心稳定',
      '手部刻画略弱，注意关节结构',
      '线条流畅，组合人物前后关系清楚',
      '比例略长，注意头身比',
    ],
  };

  static String commentFor(String subjectName, int personIndex, int judgeIndex) {
    final pool = _commentPool[subjectName] ?? _commentPool['素描']!;
    return pool[(personIndex * 3 + judgeIndex) % pool.length];
  }

  // ── 生成 ──────────────────────────────────────────────────────────────

  static double _round(double value, int digits) {
    final factor = digits == 1 ? 10 : 100;
    return (value * factor).round() / factor;
  }

  /// 并列同分同名次（1, 2, 2, 4）。
  static int _rankOf(double value, List<double> all) =>
      1 + all.where((v) => v > value).length;

  static const _weights = [7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2];

  static String _makeIdCard(String region, String birth, int seq) {
    final body = '$region$birth${seq.toString().padLeft(3, '0')}';
    var sum = 0;
    for (var i = 0; i < body.length; i++) {
      sum += int.parse(body[i]) * _weights[i];
    }
    return body + '10X98765432'[sum % 11];
  }

  static const _surnames = '王李张刘陈杨赵黄周吴徐孙马朱胡郭何高罗郑梁谢宋唐许韩冯邓曹彭';
  static const _given = <(String, String)>[
    ('子涵', '女'), ('浩然', '男'), ('欣怡', '女'), ('宇轩', '男'), ('梓萱', '女'), ('俊熙', '男'), ('语桐', '女'),
    ('明哲', '男'), ('思彤', '女'), ('嘉懿', '男'), ('若曦', '女'), ('一航', '男'), ('诗琪', '女'), ('博文', '男'),
    ('佳怡', '女'), ('睿泽', '男'), ('可馨', '女'), ('天佑', '男'), ('雨萱', '女'), ('梓豪', '男'), ('安琪', '女'),
    ('沐阳', '男'), ('书瑶', '女'), ('景行', '男'), ('清妍', '女'), ('子墨', '男'), ('婉清', '女'), ('俊辰', '男'),
    ('静怡', '女'), ('泽宇', '男'), ('晓彤', '女'), ('昊天', '男'), ('一诺', '女'), ('铭轩', '男'), ('欣然', '女'),
    ('弘毅', '男'), ('梦琪', '女'), ('逸凡', '男'),
  ];

  static double _clamp(double v, double lo, double hi) =>
      v < lo ? lo : (v > hi ? hi : v);

  DemoPerson _generated(int index) {
    final rand = _Mulberry32(index * 7919);
    final (given, gender) = _given[(index - 3) % _given.length];
    final name = _surnames[(index * 7) % _surnames.length] + given;
    final ability = 64 + (rand.next() * 24).round();
    final growth = rand.next() * 1.6;
    final registrations = <DemoRegistration>[];
    for (var e = 0; e < exams.length; e++) {
      final exam = exams[e];
      if (e < index % 4) {
        continue;
      }
      if (!exam.reviewed || (index + e) % 17 == 0) {
        registrations.add(DemoRegistration(examId: exam.examId));
        continue;
      }
      final results = <DemoSubjectResult>[];
      for (var k = 0; k < exam.subjects.length; k++) {
        final s = exam.subjects[k];
        final base = _clamp(
          ability + growth * e + (k - 1) * 2 + (rand.next() - 0.5) * 8,
          45,
          97,
        );
        final judges = [
          for (var j = 0; j < s.judgeCount; j++)
            _clamp((base + (rand.next() - 0.5) * 6).roundToDouble(), 40, 99),
        ];
        results.add(DemoSubjectResult(subjectId: s.subjectId, judges: judges));
      }
      registrations.add(DemoRegistration(examId: exam.examId, results: results));
    }
    final month = (1 + index % 12).toString().padLeft(2, '0');
    final dd = (1 + (index * 3) % 27).toString().padLeft(2, '0');
    final phoneTail = (10000000 + index * 7654321).toString();
    return DemoPerson(
      index: index,
      name: name,
      gender: gender,
      idCard: _makeIdCard('620102', '2009$month$dd', 100 + index),
      phone: '139${phoneTail.substring(phoneTail.length - 8)}',
      organizationName: organizations[index % organizations.length],
      registrations: registrations,
    );
  }

  static List<DemoSubjectResult> _results(
    Map<String, List<double>> judges, [
    Map<String, DemoSubjectResult Function(String id, List<double> j)>? extra,
  ]) => [
    for (final entry in judges.entries)
      extra?[entry.key]?.call(subjectIds[entry.key]!, entry.value) ??
          DemoSubjectResult(
            subjectId: subjectIds[entry.key]!,
            judges: entry.value,
          ),
  ];

  /// 手工设计的两名学生：覆盖仲裁、截尾平均、老师评语、手工录入、阅卷中。
  List<DemoPerson> _featured() => [
    DemoPerson(
      index: 1,
      name: '林小雨',
      gender: '女',
      idCard: '620102200903150027',
      phone: '13893150027',
      organizationName: organizations[0],
      registrations: [
        DemoRegistration(examId: '21', results: _results({'素描': [79, 81], '色彩': [75, 77], '速写': [74, 76]})),
        DemoRegistration(examId: '22', results: _results({'素描': [83, 84], '色彩': [78, 80], '速写': [77, 79]})),
        DemoRegistration(examId: '23', results: _results({'素描': [85, 87], '色彩': [82, 83], '速写': [79, 81]})),
        DemoRegistration(examId: '24', results: _results({'素描': [84, 86, 85, 90, 82], '色彩': [81, 79, 80, 86, 78], '速写': [82, 80, 84, 81, 76]})),
        DemoRegistration(examId: '25', results: _results({'素描': [89, 90], '色彩': [83, 85], '速写': [82, 84]})),
        DemoRegistration(
          examId: '26',
          results: _results(
            {'素描': [92, 93], '色彩': [91, 76], '速写': [87, 89]},
            {
              '素描': (id, j) => DemoSubjectResult(
                subjectId: id,
                judges: j,
                comments: const ['构图饱满，石膏像结构交代清楚', '暗部层次可以再丰富一些'],
              ),
              '色彩': (id, j) => DemoSubjectResult(
                subjectId: id,
                judges: j,
                arbitration: const DemoArbitration(grade: 'B', finalScore: 85),
              ),
            },
          ),
        ),
        const DemoRegistration(examId: '27'),
      ],
    ),
    DemoPerson(
      index: 2,
      name: '林小舟',
      gender: '男',
      idCard: '620102201106080139',
      phone: '13993060813',
      organizationName: organizations[1],
      registrations: [
        DemoRegistration(
          examId: '25',
          results: _results(
            {'素描': [77, 79], '色彩': [80, 82], '速写': const <double>[]},
            {
              '速写': (id, j) => DemoSubjectResult(
                subjectId: id,
                judges: j,
                manualScore: 70.5,
              ),
            },
          ),
        ),
        DemoRegistration(examId: '26', results: _results({'素描': [80, 82], '色彩': [82, 84], '速写': [73, 75]})),
        const DemoRegistration(examId: '27'),
      ],
    ),
  ];
}
