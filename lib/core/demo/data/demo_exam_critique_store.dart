/// 月考原卷讲评的演示数据：按「考试 + 科目」一份讲评，里面是老师挑的代表卷和
/// 给个别学生录的个人点评，以及读过的学生。
///
/// 卷子、分数和档位都取自 [DemoMarkingData]；这里只存讲评本身。整份存在
/// [DemoStore] 的 `exam_critiques:v1` 下，种子在代码里生成，重置演示数据后恢复。
///
/// 一份讲评：`{examId, subjectId, published, showNames, publishTime, teacherId,
/// teacherName, updatedTime, readBy[personIndex], papers[]}`；一张卷子：`{id,
/// archiveId, shared, summary, voiceRef, voiceSeconds, marks[], updatedTime,
/// teacherId, teacherName, notified}`，marks 与作品定点点评同一结构。
library;

import '../demo_clock.dart';
import '../demo_store.dart';
import 'demo_marking_data.dart';

/// 一张考过的卷子：讲评工作台的候选卷，也是讲评卷上显示的出处。
class DemoCritiqueCandidate {
  const DemoCritiqueCandidate({
    required this.person,
    required this.score,
    required this.grade,
    required this.imageRef,
  });

  final DemoPerson person;
  final double score;
  final String grade;
  final String imageRef;
}

abstract final class DemoExamCritiqueStore {
  static const key = 'exam_critiques:v1';

  static Map<String, dynamic> _all() => DemoStore.map(key, _seed);

  static String keyOf(String examId, String subjectId) => '$examId:$subjectId';

  static Map<String, dynamic>? critique(String examId, String subjectId) {
    final value = _all()[keyOf(examId, subjectId)];
    return value is Map<String, dynamic> ? value : null;
  }

  /// 取出一份讲评，没有时建一份空草稿（不落盘，等第一次写入时一起保存）。
  static Map<String, dynamic> ensure(String examId, String subjectId) {
    final all = _all();
    final existing = all[keyOf(examId, subjectId)];
    if (existing is Map<String, dynamic>) {
      return existing;
    }
    final created = <String, dynamic>{
      'examId': examId,
      'subjectId': subjectId,
      'published': false,
      'showNames': false,
      'publishTime': '',
      'teacherId': '',
      'teacherName': '',
      'updatedTime': '',
      'readBy': <dynamic>[],
      'papers': <dynamic>[],
    };
    all[keyOf(examId, subjectId)] = created;
    return created;
  }

  static void save() => DemoStore.save(key);

  /// 可以直接增删的卷子列表。
  static List<dynamic> rawPapers(Map<String, dynamic> critique) {
    final raw = critique['papers'];
    if (raw is List) {
      return raw;
    }
    final list = <dynamic>[];
    critique['papers'] = list;
    return list;
  }

  static List<Map<String, dynamic>> papersOf(Map<String, dynamic> critique) => [
    for (final item in rawPapers(critique))
      if (item is Map<String, dynamic>) item,
  ];

  static bool hasContent(Map<String, dynamic> paper) {
    final marks = paper['marks'];
    return '${paper['summary'] ?? ''}'.trim().isNotEmpty ||
        '${paper['voiceRef'] ?? ''}'.isNotEmpty ||
        (marks is List && marks.isNotEmpty);
  }

  /// 学生 [personIndex] 在这份讲评里能看到的卷子：有内容的代表卷，加上自己的个人点评。
  static List<Map<String, dynamic>> visiblePapers(
    Map<String, dynamic> critique,
    int personIndex,
  ) {
    final archiveId = '${900000 + personIndex}';
    return [
      for (final paper in papersOf(critique))
        if (hasContent(paper) &&
            (paper['shared'] == true || '${paper['archiveId']}' == archiveId))
          paper,
    ];
  }

  /// 学情接口里每一科的两个字段：这一科有没有给这位学生看的讲评、看过没有。
  static ({bool available, bool unread}) flagsFor(
    String examId,
    String subjectId,
    int personIndex,
  ) {
    final value = critique(examId, subjectId);
    if (value == null ||
        value['published'] != true ||
        visiblePapers(value, personIndex).isEmpty) {
      return (available: false, unread: false);
    }
    final readBy = value['readBy'];
    final read = readBy is List && readBy.contains('$personIndex');
    return (available: true, unread: !read);
  }

  static void markRead(Map<String, dynamic> critique, int personIndex) {
    final readBy = critique['readBy'];
    final list = readBy is List ? readBy : <dynamic>[];
    if (!list.contains('$personIndex')) {
      list.add('$personIndex');
    }
    critique['readBy'] = list;
    save();
  }

  // ── 卷子 ──────────────────────────────────────────────────────────────

  /// 这一科有成绩的全部卷子，分数从高到低。手工录入（没有扫描原卷）的不算。
  static List<DemoCritiqueCandidate> candidates(
    String examId,
    String subjectId,
  ) {
    final data = DemoMarkingData.instance;
    final exam = data.exam(examId);
    if (exam == null) {
      return const <DemoCritiqueCandidate>[];
    }
    final list = <DemoCritiqueCandidate>[];
    for (final entry in data.entriesOfExam(examId)) {
      final score = entry.subject(subjectId);
      if (score == null || score.result.judges.isEmpty) {
        continue;
      }
      list.add(
        DemoCritiqueCandidate(
          person: entry.person,
          score: score.score,
          grade: score.grade,
          imageRef: DemoMarkingData.paperRef(
            score.def.subjectName,
            entry.person.index,
            examId,
          ),
        ),
      );
    }
    list.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.person.index.compareTo(b.person.index);
    });
    return list;
  }

  /// 每一档建议的那一张：分数最接近这一档中间分的卷子（同样接近时取序号小的）。
  static Map<String, String> suggestedArchiveIds(
    List<DemoCritiqueCandidate> candidates,
    List<DemoGradeBand> bands,
  ) {
    final result = <String, String>{};
    for (final band in bands) {
      final best = _closestToMiddle(
        candidates.where((c) => c.grade == band.grade),
        band,
      );
      if (best != null) {
        result[band.grade] = best.person.archiveId;
      }
    }
    return result;
  }

  static DemoCritiqueCandidate? _closestToMiddle(
    Iterable<DemoCritiqueCandidate> pool,
    DemoGradeBand band,
  ) {
    final middle = (band.min + band.max) / 2;
    final sorted = pool.toList()
      ..sort((a, b) {
        final byDistance = (a.score - middle).abs().compareTo(
          (b.score - middle).abs(),
        );
        return byDistance != 0
            ? byDistance
            : a.person.index.compareTo(b.person.index);
      });
    return sorted.firstOrNull;
  }

  static String fmt(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  // ── 种子 ──────────────────────────────────────────────────────────────

  static Map<String, dynamic> _seed() {
    final result = <String, dynamic>{};
    final color = _seedColor();
    if (color != null) {
      result[keyOf('26', '39')] = color;
    }
    final sketch = _seedSketch();
    if (sketch != null) {
      result[keyOf('26', '38')] = sketch;
    }
    return result;
  }

  /// 依次为 [grades] 每一档挑一张：先挑最接近中间分的，和已挑的图重复时往下顺延。
  static List<DemoCritiqueCandidate> _pick(
    String examId,
    String subjectId,
    List<String> grades, {
    Set<int> exclude = const <int>{},
    Set<String> usedImages = const <String>{},
  }) {
    final def = DemoMarkingData.instance
        .exam(examId)
        ?.subjects
        .where((s) => s.subjectId == subjectId)
        .firstOrNull;
    if (def == null) {
      return const <DemoCritiqueCandidate>[];
    }
    final bands = DemoMarkingData.bandsFor(def);
    final pool = candidates(examId, subjectId);
    final used = <String>{...usedImages};
    final picked = <DemoCritiqueCandidate>[];
    for (final grade in grades) {
      final band = bands.firstWhere((b) => b.grade == grade);
      final middle = (band.min + band.max) / 2;
      final options =
          pool
              .where(
                (c) =>
                    c.grade == grade &&
                    !exclude.contains(c.person.index) &&
                    !used.contains(c.imageRef),
              )
              .toList()
            ..sort((a, b) {
              final byDistance = (a.score - middle).abs().compareTo(
                (b.score - middle).abs(),
              );
              return byDistance != 0
                  ? byDistance
                  : a.person.index.compareTo(b.person.index);
            });
      final choice = options.firstOrNull;
      if (choice != null) {
        picked.add(choice);
        used.add(choice.imageRef);
      }
    }
    return picked;
  }

  static Map<String, dynamic> _mark(int n, double x, double y, String text) =>
      <String, dynamic>{
        'id': 'mk-$n',
        'imageIndex': 0,
        'x': x,
        'y': y,
        'text': text,
        'voiceRef': '',
        'voiceSeconds': 0,
      };

  static Map<String, dynamic> _paper({
    required String id,
    required String archiveId,
    required bool shared,
    required String summary,
    required List<Map<String, dynamic>> marks,
    required String teacherId,
    required String teacherName,
    required String time,
    bool notified = false,
  }) => <String, dynamic>{
    'id': id,
    'archiveId': archiveId,
    'shared': shared,
    'summary': summary,
    'voiceRef': '',
    'voiceSeconds': 0,
    'marks': marks,
    'updatedTime': time,
    'teacherId': teacherId,
    'teacherName': teacherName,
    'notified': notified,
  };

  /// 色彩代表卷的讲评：四张静物写生构图相同（左陶罐、中间果盘、右白衬布、左下蓝衬布），
  /// 所以每一档的几处位置对哪一张都成立。
  static const _colorShared = <String, (String, List<(double, double, String)>)>{
    'A': (
      '色调统一，冷暖关系拉得开，主体刻画充分。可以把这一张当作本次的参照：先看大色调，再看陶罐和水果的塑造。',
      [
        (0.27, 0.45, '陶罐暗部带着蓝衬布反上来的冷灰，固有色没有画死，体积感出来了。'),
        (0.62, 0.52, '水果组是画面里刻画最深入的地方，亮部暖、暗部偏冷，冷暖对比清楚。'),
        (0.86, 0.38, '白衬布亮部带一点暖、暗部带一点蓝灰，白而不粉。'),
        (0.52, 0.12, '背景笔触放松、明度统一，往后退，空间拉开了。'),
      ],
    ),
    'B': (
      '色调基本统一，物体关系交代清楚，问题集中在局部颜色偏生、衬布和背景偏平。对照 A 档那张，先把冷暖拉开。',
      [
        (0.6, 0.72, '盘子亮面颜色偏粉，加一点环境里的暖色，和桌面统一起来。'),
        (0.28, 0.48, '陶罐暗部颜色偏闷，反光处可以透出蓝衬布的冷色。'),
        (0.18, 0.82, '蓝衬布前后颜色一样，近处纯度提高、远处灰下去，空间才出来。'),
      ],
    ),
    'C': (
      '画面有色调倾向，但冷暖对比弱，整体偏灰，主体刻画不够深入。先解决大关系，再往下画细节。',
      [
        (0.64, 0.5, '主体水果和背景明度太接近，亮部再提亮、暗部压下去，主体才站得出来。'),
        (0.5, 0.14, '背景和桌面用的是同一种灰，可以一冷一暖分开。'),
        (0.86, 0.5, '白衬布画成了一块平涂的灰，亮暗面要有明度和冷暖变化。'),
      ],
    ),
  };

  static const _colorPersonal = (
    '两位老师给分差得较多，经仲裁定为 B 档。和 A 档的差距主要在冷暖对比和环境色，下面几处是这次最需要改的地方。',
    <(double, double, String)>[
      (0.68, 0.6, '苹果暗部直接用了深红加黑，颜色发闷，试试加一点衬布的蓝紫。'),
      (0.27, 0.36, '陶罐高光太跳，和整体色调不统一，降一点纯度。'),
      (0.86, 0.42, '白衬布亮部可以再暖一点，和蓝衬布形成冷暖对比。'),
      (0.5, 0.1, '背景处理得比较放松，这一点保持。'),
    ],
  );

  static Map<String, dynamic>? _seedColor() {
    const examId = '26';
    const subjectId = '39';
    final data = DemoMarkingData.instance;
    final mine = data.entryOf(1, examId)?.subject(subjectId);
    if (mine == null) {
      return null;
    }
    final ownImage = DemoMarkingData.paperRef('色彩', 1, examId);
    final shared = _pick(
      examId,
      subjectId,
      const ['A', 'B', 'C'],
      exclude: const {1},
      usedImages: {ownImage},
    );
    final published = DemoClock.ago(const Duration(hours: 3, minutes: 5));
    final edited = fmt(DemoClock.ago(const Duration(hours: 3, minutes: 20)));
    const teacherId = 't-5';
    const teacherName = '王海波';
    List<Map<String, dynamic>> marks(List<(double, double, String)> items) => [
      for (var i = 0; i < items.length; i++)
        _mark(i + 1, items[i].$1, items[i].$2, items[i].$3),
    ];
    return <String, dynamic>{
      'examId': examId,
      'subjectId': subjectId,
      'published': true,
      'showNames': false,
      'publishTime': fmt(published),
      'teacherId': teacherId,
      'teacherName': teacherName,
      'updatedTime': edited,
      'readBy': <dynamic>[],
      'papers': <dynamic>[
        for (final candidate in shared)
          _paper(
            id: 'cp-$examId-$subjectId-${candidate.grade.toLowerCase()}',
            archiveId: candidate.person.archiveId,
            shared: true,
            summary: _colorShared[candidate.grade]!.$1,
            marks: marks(_colorShared[candidate.grade]!.$2),
            teacherId: teacherId,
            teacherName: teacherName,
            time: edited,
          ),
        _paper(
          id: 'cp-$examId-$subjectId-p1',
          archiveId: data.person(1).archiveId,
          shared: false,
          summary: _colorPersonal.$1,
          marks: marks(_colorPersonal.$2),
          teacherId: teacherId,
          teacherName: teacherName,
          time: edited,
          notified: true,
        ),
      ],
    };
  }

  /// 素描草稿：几张写生图的内容各不相同，每一张单独写位置。
  static const _sketchMarks = <String, List<(double, double, String)>>{
    'asset:assets/demo/art/sketch-bust-1.jpg': [
      (0.36, 0.36, '眼窝和眉弓的转折交代清楚，暗部透气。'),
      (0.64, 0.38, '耳朵的位置和朝向准确，和头部的透视一致。'),
      (0.5, 0.62, '颈部明暗交界线肯定，胸锁乳突肌的方向画出来了。'),
    ],
    'asset:assets/demo/art/sketch-bust-3.jpg': [
      (0.5, 0.22, '头发分组概括得好，没有一根一根地抠。'),
      (0.42, 0.37, '眼睛刻画偏平，眼窝的暗部可以再压一些。'),
      (0.62, 0.66, '颈部和肩部的衔接偏弱，交界线要肯定。'),
    ],
    'asset:assets/demo/art/sketch-still-1.jpg': [
      (0.43, 0.3, '陶罐结构准确，明暗层次丰富，高光留得干净。'),
      (0.24, 0.55, '苹果的暗部和投影连成一片，要分出反光。'),
      (0.6, 0.75, '衬布的褶皱画得太碎，抓住几条主要的走向。'),
    ],
    'asset:assets/demo/art/sketch-still-2.jpg': [
      (0.29, 0.45, '瓶子的透明质感表现到位，反光和高光区分清楚。'),
      (0.56, 0.48, '陶碗口的椭圆透视略平，前后的弧度要拉开。'),
      (0.82, 0.68, '格子布的条纹要跟着褶皱起伏走，现在画得太直。'),
    ],
    'asset:assets/demo/art/sketch-geometry-1.jpg': [
      (0.28, 0.42, '立方体三大面区分清楚，暗面再整体一些。'),
      (0.36, 0.62, '球体明暗交界线位置准确，反光不要过亮。'),
      (0.75, 0.6, '圆柱顶面的椭圆和底面的弧度要一致。'),
    ],
  };

  static const _sketchSummary = <String, String>{
    'A': '构图饱满，结构和明暗关系都交代得清楚，可以作为本次素描的参照卷。重点看形体转折和暗部的处理。',
    'B': '比例基本准确，问题在明暗层次偏少、局部刻画不够深入。和 A 档那张对照着看。',
  };

  static Map<String, dynamic>? _seedSketch() {
    const examId = '26';
    const subjectId = '38';
    final shared = _pick(
      examId,
      subjectId,
      const ['A', 'B'],
      exclude: const {1},
    );
    if (shared.isEmpty) {
      return null;
    }
    final edited = fmt(DemoClock.ago(const Duration(hours: 20)));
    const teacherId = 't-1';
    const teacherName = '李静';
    return <String, dynamic>{
      'examId': examId,
      'subjectId': subjectId,
      'published': false,
      'showNames': false,
      'publishTime': '',
      'teacherId': teacherId,
      'teacherName': teacherName,
      'updatedTime': edited,
      'readBy': <dynamic>[],
      'papers': <dynamic>[
        for (final candidate in shared)
          _paper(
            id: 'cp-$examId-$subjectId-${candidate.grade.toLowerCase()}',
            archiveId: candidate.person.archiveId,
            shared: true,
            summary: _sketchSummary[candidate.grade] ?? '',
            marks: [
              for (final (i, item)
                  in (_sketchMarks[candidate.imageRef] ??
                          const <(double, double, String)>[])
                      .indexed)
                _mark(i + 1, item.$1, item.$2, item.$3),
            ],
            teacherId: teacherId,
            teacherName: teacherName,
            time: edited,
          ),
      ],
    };
  }
}
