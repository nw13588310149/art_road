/// 智慧校园演示作业：任课老师布置的作业与每名学生的提交、批改记录。
///
/// 联考冲刺1班的作业与学生端（林小雨）看到的作业一一对应：作业 id、标题、
/// 截止时间相同，林小雨的提交记录 id 即学生端的 `homeworkStudentId`。
library;

import '../../data/demo_campus_data.dart';
import '../../data/demo_marking_data.dart';
import '../../demo_store.dart';
import 'campus_b_common.dart';

const String cbHomeworkKey = 'campus_b:homework';
const String cbHomeworkRecordsKey = 'campus_b:homework_records';

const Map<String, int> _fileSizes = {
  'sketch-bust-1.jpg': 166190,
  'sketch-bust-2.jpg': 365757,
  'sketch-bust-3.jpg': 243544,
  'sketch-portrait-1.jpg': 252976,
  'sketch-still-1.jpg': 254511,
  'sketch-still-2.jpg': 351724,
  'sketch-still-3.jpg': 212730,
  'sketch-geometry-1.jpg': 227389,
  'color-still-1.jpg': 301071,
  'color-still-2.jpg': 308012,
  'color-still-3.jpg': 248128,
  'color-still-4.jpg': 297006,
  'color-still-5.jpg': 248669,
  'color-flower-1.jpg': 304874,
  'color-landscape-1.jpg': 295801,
  'speed-figure-1.jpg': 211438,
  'speed-figure-2.jpg': 232466,
  'speed-figure-3.jpg': 273576,
  'speed-figure-4.jpg': 326667,
  'speed-figure-5.jpg': 319907,
  'speed-group-1.jpg': 255930,
  'speed-scene-1.jpg': 325891,
  'detail-sketch.jpg': 372144,
  'detail-color.jpg': 383769,
  'hatching.mp4': 2121374,
  'place-paper.mp4': 571500,
};

const Map<String, List<String>> _notes = {
  '素描': [
    '这次重点调整了暗部层次，鼻底和眼窝的结构请老师看看是否准确。',
    '构图有点偏下，后面主要在深入五官。',
    '最后一天赶得有点急，头发的体积感还不够。',
    '用辅助线检查了透视，椭圆的弧度自己感觉还行。',
  ],
  '色彩': [
    '衬布的冷暖关系自己感觉还不够，请老师指点。',
    '这次尝试先铺大色调再深入，水果的固有色有点粉。',
    '背景画得有点闷，后面加了一些环境色。',
  ],
  '速写': ['全部完成了，蹲姿的比例总是画长。', '这次注意了重心线，手部还是画得比较弱。', '组合场景里人物的前后关系处理了好几遍。'],
  '美术常识': ['读书笔记结合了《溪山行旅图》来写。', '把六法和宋代山水的代表作品做了对照。'],
};

const Map<String, List<String>> _feedbacks = {
  '素描': [
    '构图饱满，结构交代清楚，暗部再整体一些。',
    '明暗交界线再肯定一些，反光不要画得过亮。',
    '五官比例准确，头发的体积感可以加强。',
    '整体关系不错，背景处理稍显单薄。',
  ],
  '色彩': ['色调统一，主体物塑造较充分。', '背景与衬布的冷暖关系可以再拉开。', '亮部颜色偏粉，注意固有色倾向。'],
  '速写': ['动态生动，重心稳定，手部再刻画一下。', '线条流畅，组合人物前后关系清楚。', '比例略长，注意头身比。'],
  '美术常识': ['论述清晰，举例恰当，继续保持。', '条理清楚，再补充一下作品的年代背景。'],
};

/// 林小雨在学生端看到的提交状态（与学生端演示数据一致）。
typedef _Own = ({
  int status,
  int submitDays,
  String file,
  String fileName,
  String note,
  int? score,
  String feedback,
});

/// 作业种子；mode：0 已截止多数已评 / 1 截止前后混合 / 2 刚布置 / 3 早已截止全部已评。
typedef _Seed = ({
  String id,
  String title,
  String desc,
  String classId,
  String subject,
  String teacher,
  String ext,
  int createdDays,
  int endDays,
  int mode,
  List<String> files,
  _Own? own,
});

const String _art = 'asset:assets/demo/art';

const List<_Seed> _seeds = [
  (
    id: '76101',
    title: '素描几何体组合（明暗）',
    desc: '4 开素描纸完成正方体、圆锥、球体组合写生，要求明暗交界线清晰、五大调子完整，时长 3 小时，拍照上传。',
    classId: '501',
    subject: '素描',
    teacher: 't-1',
    ext: 'image',
    createdDays: -1,
    endDays: 2,
    mode: 2,
    files: ['$_art/sketch-geometry-1.jpg', '$_art/sketch-still-3.jpg'],
    own: (
      status: 0,
      submitDays: 0,
      file: '',
      fileName: '',
      note: '',
      score: null,
      feedback: '',
    ),
  ),
  (
    id: '76104',
    title: '速写过程录制（10 分钟人物动态）',
    desc: '录制一段 10 分钟人物动态速写过程视频，展示起形—定动态—深入刻画的步骤，横屏拍摄。',
    classId: '501',
    subject: '速写',
    teacher: 't-4',
    ext: 'video',
    createdDays: -1,
    endDays: 3,
    mode: 2,
    files: [
      'asset:assets/demo/video/hatching.mp4',
      'asset:assets/demo/video/place-paper.mp4',
    ],
    own: (
      status: 0,
      submitDays: 0,
      file: '',
      fileName: '',
      note: '',
      score: null,
      feedback: '',
    ),
  ),
  (
    id: '76103',
    title: '名作临摹：伦勃朗自画像局部',
    desc: '临摹伦勃朗自画像头部局部，重点体会光影塑造与体积感，8 开纸，可用炭笔。',
    classId: '501',
    subject: '素描',
    teacher: 't-1',
    ext: 'image',
    createdDays: -2,
    endDays: 5,
    mode: 2,
    files: ['$_art/sketch-portrait-1.jpg', '$_art/detail-sketch.jpg'],
    own: (
      status: 0,
      submitDays: 0,
      file: '',
      fileName: '',
      note: '',
      score: null,
      feedback: '',
    ),
  ),
  (
    id: '76102',
    title: '色彩静物默写',
    desc: '默写一组冷色调静物（陶罐、苹果、蓝灰衬布），8 开水粉纸，注意色调统一与冷暖对比。',
    classId: '501',
    subject: '色彩',
    teacher: 't-3',
    ext: 'image',
    createdDays: -4,
    endDays: -1,
    mode: 1,
    files: [
      '$_art/color-still-1.jpg',
      '$_art/color-still-4.jpg',
      '$_art/color-still-5.jpg',
    ],
    own: (
      status: 0,
      submitDays: 0,
      file: '',
      fileName: '',
      note: '',
      score: null,
      feedback: '',
    ),
  ),
  (
    id: '76105',
    title: '色彩风景写生小稿',
    desc: '黄河岸边写生小稿 2 张，16 开，表现傍晚时分的光色变化。',
    classId: '501',
    subject: '色彩',
    teacher: 't-3',
    ext: 'image',
    createdDays: -6,
    endDays: -2,
    mode: 1,
    files: ['$_art/color-landscape-1.jpg', '$_art/color-flower-1.jpg'],
    own: (
      status: 1,
      submitDays: -3,
      file: '$_art/color-landscape-1.jpg',
      fileName: '黄河岸边写生小稿.jpg',
      note: '天空部分感觉有点灰，请老师指导一下。',
      score: null,
      feedback: '',
    ),
  ),
  (
    id: '76106',
    title: '速写组合人物 3 张',
    desc: '以画室同学为模特完成 3 张两人以上组合速写，注意人物之间的前后与呼应关系。',
    classId: '501',
    subject: '速写',
    teacher: 't-4',
    ext: 'image',
    createdDays: -5,
    endDays: -1,
    mode: 1,
    files: ['$_art/speed-group-1.jpg', '$_art/speed-scene-1.jpg'],
    own: (
      status: 1,
      submitDays: -2,
      file: '$_art/speed-group-1.jpg',
      fileName: '组合人物速写.jpg',
      note: '第三张画了画室一角的同学们。',
      score: null,
      feedback: '',
    ),
  ),
  (
    id: '76107',
    title: '石膏头像结构练习（大卫）',
    desc: '大卫石膏像结构素描，用线面结合的方式交代头骨结构与五官穿插关系。',
    classId: '501',
    subject: '素描',
    teacher: 't-1',
    ext: 'image',
    createdDays: -12,
    endDays: -9,
    mode: 3,
    files: [
      '$_art/sketch-bust-2.jpg',
      '$_art/sketch-bust-1.jpg',
      '$_art/sketch-bust-3.jpg',
    ],
    own: (
      status: 2,
      submitDays: -10,
      file: '$_art/sketch-bust-2.jpg',
      fileName: '大卫结构素描.jpg',
      note: '',
      score: 88,
      feedback: '结构交代清楚，暗部再整体一些，眼窝和鼻底的投影要统一在同一光源下。',
    ),
  ),
  (
    id: '76108',
    title: '静物色彩·冷暖对比',
    desc: '暖光源下的静物写生，重点表现亮部暖、暗部冷的色彩关系。',
    classId: '501',
    subject: '色彩',
    teacher: 't-3',
    ext: 'image',
    createdDays: -14,
    endDays: -11,
    mode: 3,
    files: [
      '$_art/color-still-3.jpg',
      '$_art/color-still-2.jpg',
      '$_art/color-still-4.jpg',
    ],
    own: (
      status: 2,
      submitDays: -12,
      file: '$_art/color-still-3.jpg',
      fileName: '冷暖对比静物.jpg',
      note: '',
      score: 85,
      feedback: '色调明确，冷暖对比到位；衬布转折处颜色再丰富些，高光不要用纯白。',
    ),
  ),
  (
    id: '76109',
    title: '人物动态速写 20 张',
    desc: '一周内完成 20 张 5 分钟人物动态速写，挑选 5 张最满意的拍照上传。',
    classId: '501',
    subject: '速写',
    teacher: 't-4',
    ext: 'image',
    createdDays: -16,
    endDays: -9,
    mode: 3,
    files: [
      '$_art/speed-figure-3.jpg',
      '$_art/speed-figure-1.jpg',
      '$_art/speed-figure-2.jpg',
      '$_art/speed-figure-4.jpg',
      '$_art/speed-figure-5.jpg',
    ],
    own: (
      status: 2,
      submitDays: -10,
      file: '$_art/speed-figure-3.jpg',
      fileName: '动态速写精选.jpg',
      note: '',
      score: 90,
      feedback: '动态抓得准，线条流畅；手脚的结构再交代清楚就更好了。',
    ),
  ),
  (
    id: '76110',
    title: '美术常识：中国画六法',
    desc: '阅读谢赫「六法论」，结合一幅宋代山水画作品写 800 字读书笔记。',
    classId: '501',
    subject: '美术常识',
    teacher: 't-7',
    ext: 'doc',
    createdDays: -18,
    endDays: -13,
    mode: 3,
    files: [],
    own: (
      status: 2,
      submitDays: -14,
      file: '',
      fileName: '中国画六法读书笔记.docx',
      note: '',
      score: 92,
      feedback: '论述清晰，「气韵生动」部分举例恰当，继续保持。',
    ),
  ),
  (
    id: '76111',
    title: '素描五官局部（眼睛）',
    desc: '眼睛局部写生 4 个角度，注意上下眼睑的厚度与眼球的球体感。',
    classId: '501',
    subject: '素描',
    teacher: 't-1',
    ext: 'image',
    createdDays: -21,
    endDays: -18,
    mode: 3,
    files: ['$_art/sketch-portrait-1.jpg', '$_art/detail-sketch.jpg'],
    own: (
      status: 2,
      submitDays: -19,
      file: '$_art/sketch-portrait-1.jpg',
      fileName: '五官局部-眼睛.jpg',
      note: '',
      score: 86,
      feedback: '眼球体积感塑造得不错，眼睑的厚度再表现出来，睫毛不要画成线。',
    ),
  ),
  (
    id: '76112',
    title: '色彩花卉写生',
    desc: '瓶花写生一张，8 开，注意花卉的纯度变化与背景的空间感。',
    classId: '501',
    subject: '色彩',
    teacher: 't-3',
    ext: 'image',
    createdDays: -26,
    endDays: -23,
    mode: 3,
    files: ['$_art/color-flower-1.jpg', '$_art/detail-color.jpg'],
    own: (
      status: 2,
      submitDays: -24,
      file: '$_art/color-flower-1.jpg',
      fileName: '瓶花写生.jpg',
      note: '',
      score: 89,
      feedback: '花卉颜色鲜活，背景处理得透气；花瓶的投影可以再冷一点。',
    ),
  ),
  (
    id: '3500001',
    title: '石膏头像长期作业',
    desc:
        '以「大卫」或「海盗」石膏像为对象完成一张 4 开长期作业（12 课时），要求构图饱满、'
        '结构准确、明暗层次完整，最后一天拍照上传全图。',
    classId: '502',
    subject: '素描',
    teacher: 't-1',
    ext: 'image',
    createdDays: -9,
    endDays: -2,
    mode: 0,
    files: [
      '$_art/sketch-bust-1.jpg',
      '$_art/sketch-bust-2.jpg',
      '$_art/sketch-bust-3.jpg',
      '$_art/sketch-portrait-1.jpg',
    ],
    own: null,
  ),
  (
    id: '3500002',
    title: '色彩静物写生三张',
    desc: '完成三张 4 开色彩静物写生（陶罐、水果、衬布组合），重点表现冷暖关系与色调统一，每张限时 3 小时，拍照时注意避免反光。',
    classId: '502',
    subject: '色彩',
    teacher: 't-5',
    ext: 'image',
    createdDays: -4,
    endDays: 3,
    mode: 1,
    files: [
      '$_art/color-still-1.jpg',
      '$_art/color-still-2.jpg',
      '$_art/color-still-3.jpg',
      '$_art/color-still-5.jpg',
    ],
    own: null,
  ),
  (
    id: '3500003',
    title: '几何体组合写生',
    desc: '完成一张几何体组合写生（立方体、圆柱、球体），重点检查透视与明暗五大调子。',
    classId: '502',
    subject: '素描',
    teacher: 't-1',
    ext: 'image',
    createdDays: -26,
    endDays: -20,
    mode: 3,
    files: ['$_art/sketch-geometry-1.jpg', '$_art/sketch-still-3.jpg'],
    own: null,
  ),
  (
    id: '3500004',
    title: '风景色彩小稿',
    desc: '根据写生照片完成 2 张 8 开风景色彩小稿，训练概括能力与整体色调。',
    classId: '502',
    subject: '色彩',
    teacher: 't-3',
    ext: 'image',
    createdDays: -16,
    endDays: -10,
    mode: 3,
    files: ['$_art/color-landscape-1.jpg', '$_art/color-flower-1.jpg'],
    own: null,
  ),
  (
    id: '3500005',
    title: '场景组合速写',
    desc: '以食堂或车站为场景完成 3 张组合速写，人物不少于 4 个，注意前后遮挡关系。',
    classId: '503',
    subject: '速写',
    teacher: 't-6',
    ext: 'image',
    createdDays: -12,
    endDays: -6,
    mode: 0,
    files: ['$_art/speed-scene-1.jpg', '$_art/speed-group-1.jpg'],
    own: null,
  ),
  (
    id: '3500006',
    title: '色彩静物写生三张',
    desc: '完成三张 4 开色彩静物写生（陶罐、水果、衬布组合），重点表现冷暖关系与色调统一，每张限时 3 小时。',
    classId: '503',
    subject: '色彩',
    teacher: 't-3',
    ext: 'image',
    createdDays: -3,
    endDays: 4,
    mode: 1,
    files: [
      '$_art/color-still-4.jpg',
      '$_art/color-still-5.jpg',
      '$_art/color-still-2.jpg',
    ],
    own: null,
  ),
  (
    id: '3500007',
    title: '素描头像写生',
    desc: '以模特头像为对象完成一张 4 开素描头像写生，注意五官比例与头部结构。',
    classId: '503',
    subject: '素描',
    teacher: 't-2',
    ext: 'image',
    createdDays: -2,
    endDays: 4,
    mode: 2,
    files: ['$_art/sketch-portrait-1.jpg', '$_art/sketch-bust-3.jpg'],
    own: null,
  ),
];

/// 学生在该科目的最近一次考试分，作为作业分的基准。
double _baseScore(DemoPerson p, String subject) {
  final entries = DemoMarkingData.instance
      .entriesOf(p.index)
      .where((e) => e.scored);
  for (final e in entries.toList().reversed) {
    for (final s in e.subjects!) {
      if (s.def.subjectName == subject) {
        return s.score;
      }
    }
  }
  return 78;
}

String _typeTag(String ext) => switch (ext) {
  'video' => '视频',
  'doc' => '文档',
  _ => '照片',
};

String _suffix(String ext) => switch (ext) {
  'video' => '.mp4',
  'doc' => '.docx',
  _ => '.jpg',
};

int? _sizeOf(String ref) =>
    ref.isEmpty ? null : _fileSizes[ref.split('/').last] ?? 260000;

List<Map<String, dynamic>> _seedHomework() => [
  for (final s in _seeds)
    <String, dynamic>{
      'id': s.id,
      'title': s.title,
      'description': s.desc,
      'classId': s.classId,
      'subjectId': cbSubjectIdOf(s.subject),
      'subjectName': s.subject,
      'teacherUserId': DemoCampusData.staffById(s.teacher)?.userId ?? '',
      'expectedExt': s.ext,
      'createTime': cbDateTime(cbRel(s.createdDays, '19:20')),
      'endTime': cbDateTime(cbRel(s.endDays, '21:00')),
    },
];

List<Map<String, dynamic>> _seedRecords() {
  final result = <Map<String, dynamic>>[];
  final now = DateTime.now();
  for (final s in _seeds) {
    final created = cbRel(s.createdDays, '19:20');
    final end = cbRel(s.endDays, '21:00');
    final last = end.isBefore(now) ? end : now;
    final window = last.difference(created).inMinutes;
    for (final sid in cbActiveStudents(s.classId)) {
      final p = cbPerson(sid)!;
      final own = p.index == 1 ? s.own : null;
      if (own != null) {
        result.add(_ownRecord(s, p, own));
        continue;
      }
      final roll = cbHash('${s.id}|${p.index}') % 100;
      final status = switch (s.mode) {
        0 => roll < 8 ? 0 : (roll < 22 ? 1 : 2),
        1 => roll < 28 ? 0 : (roll < 66 ? 1 : 2),
        2 => roll < 72 ? 0 : 1,
        _ => roll < 4 ? 0 : 2,
      };
      result.add(
        _recordFor(
          seed: s,
          person: p,
          status: status,
          roll: roll,
          submitAt: window <= 0
              ? created
              : created.add(
                  Duration(minutes: window * (30 + roll % 60) ~/ 100),
                ),
        ),
      );
    }
  }
  return result;
}

Map<String, dynamic> _ownRecord(_Seed s, DemoPerson p, _Own own) {
  final submitted = own.status > 0;
  final submitAt = cbRel(own.submitDays, '20:15');
  return <String, dynamic>{
    'id': s.id.substring(1),
    'homeworkId': s.id,
    'studentId': p.archiveId,
    'status': own.status,
    'submitTime': submitted ? cbDateTime(submitAt) : null,
    'studentParam1': submitted ? own.file : '',
    'studentParam2': submitted ? own.fileName : '',
    'studentParam3': submitted ? _typeTag(s.ext) : '',
    'description': own.note,
    'fileSize': submitted ? _sizeOf(own.file) : null,
    'score': own.score,
    'feedback': own.status == 2 ? own.feedback : null,
    'teacherParam1': '',
    'teacherParam2': '',
    'correctTime': own.status == 2
        ? cbDateTime(submitAt.add(const Duration(hours: 16)))
        : null,
  };
}

Map<String, dynamic> _recordFor({
  required _Seed seed,
  required DemoPerson person,
  required int status,
  required int roll,
  required DateTime submitAt,
}) {
  final submitted = status > 0;
  final file = seed.files.isEmpty ? '' : seed.files[roll % seed.files.length];
  final notes = _notes[seed.subject] ?? _notes['素描']!;
  final feedbacks = _feedbacks[seed.subject] ?? _feedbacks['素描']!;
  final base = seed.subject == '美术常识'
      ? 72 + roll % 24
      : _baseScore(person, seed.subject);
  final score = (base + (roll % 9) - 4).round().clamp(55, 98);
  return <String, dynamic>{
    'id': '${seed.id}${person.index.toString().padLeft(3, '0')}',
    'homeworkId': seed.id,
    'studentId': person.archiveId,
    'status': status,
    'submitTime': submitted ? cbDateTime(submitAt) : null,
    'studentParam1': submitted ? file : '',
    'studentParam2': submitted
        ? '${seed.title}-${person.name}${_suffix(seed.ext)}'
        : '',
    'studentParam3': submitted ? _typeTag(seed.ext) : '',
    'description': submitted && roll % 3 != 1 ? notes[roll % notes.length] : '',
    'fileSize': submitted ? _sizeOf(file) : null,
    'score': status == 2 ? score : null,
    'feedback': status == 2 ? feedbacks[roll % feedbacks.length] : null,
    'teacherParam1': '',
    'teacherParam2': '',
    'correctTime': status == 2
        ? cbDateTime(submitAt.add(Duration(hours: 10 + roll % 20)))
        : null,
  };
}

List<Map<String, dynamic>> cbHomework() =>
    DemoStore.list(cbHomeworkKey, _seedHomework);

List<Map<String, dynamic>> cbHomeworkRecords() =>
    DemoStore.list(cbHomeworkRecordsKey, _seedRecords);

void cbSaveHomework() {
  DemoStore.save(cbHomeworkKey);
  DemoStore.save(cbHomeworkRecordsKey);
}

Map<String, dynamic>? cbHomeworkById(Object? rawId) {
  final id = cbStr(rawId);
  for (final hw in cbHomework()) {
    if (cbStr(hw['id']) == id) {
      return hw;
    }
  }
  return null;
}

List<Map<String, dynamic>> cbRecordsOf(Object? homeworkId) {
  final id = cbStr(homeworkId);
  return [
    for (final r in cbHomeworkRecords())
      if (cbStr(r['homeworkId']) == id) r,
  ];
}

Map<String, dynamic>? cbRecordById(Object? rawId) {
  final id = cbStr(rawId);
  for (final r in cbHomeworkRecords()) {
    if (cbStr(r['id']) == id) {
      return r;
    }
  }
  return null;
}

/// 0 进行中 / 1 已截止。
int cbHomeworkStatus(Map<String, dynamic> hw) {
  final end = cbParse(hw['endTime']);
  return end != null && end.isAfter(DateTime.now()) ? 0 : 1;
}

({int unsubmitted, int pending, int reviewed}) cbHomeworkCounts(
  Map<String, dynamic> hw,
) {
  var unsubmitted = 0;
  var pending = 0;
  var reviewed = 0;
  for (final r in cbRecordsOf(hw['id'])) {
    switch (cbInt(r['status'])) {
      case 1:
        pending++;
      case 2:
        reviewed++;
      default:
        unsubmitted++;
    }
  }
  return (unsubmitted: unsubmitted, pending: pending, reviewed: reviewed);
}

/// 布置作业：每个班级一条作业记录，并为班级在籍学生建好待提交记录。
List<String> cbCreateHomework({
  required List<String> classIds,
  required String title,
  required String description,
  required String endTime,
  required int subjectId,
  required String subjectName,
  required String teacherUserId,
  required String expectedExt,
}) {
  final created = <String>[];
  final now = cbDateTime(DateTime.now());
  for (final classId in classIds) {
    final id = DemoStore.nextId();
    cbHomework().add(<String, dynamic>{
      'id': id,
      'title': title,
      'description': description,
      'classId': classId,
      'subjectId': subjectId,
      'subjectName': subjectName,
      'teacherUserId': teacherUserId,
      'expectedExt': expectedExt,
      'createTime': now,
      'endTime': endTime,
    });
    for (final sid in cbActiveStudents(classId)) {
      final p = cbPerson(sid);
      if (p == null) {
        continue;
      }
      cbHomeworkRecords().add(<String, dynamic>{
        'id': '$id${p.index.toString().padLeft(3, '0')}',
        'homeworkId': id,
        'studentId': p.archiveId,
        'status': 0,
        'submitTime': null,
        'studentParam1': '',
        'studentParam2': '',
        'studentParam3': '',
        'description': '',
        'fileSize': null,
        'score': null,
        'feedback': null,
        'teacherParam1': '',
        'teacherParam2': '',
        'correctTime': null,
      });
    }
    created.add(id);
  }
  cbSaveHomework();
  return created;
}

void cbDeleteHomework(String id) {
  cbHomework().removeWhere((hw) => cbStr(hw['id']) == id);
  cbHomeworkRecords().removeWhere((r) => cbStr(r['homeworkId']) == id);
  cbSaveHomework();
}

Map<String, dynamic> cbRecordJson(
  Map<String, dynamic> record,
  Map<String, dynamic> hw,
) {
  final p = cbPerson(record['studentId']);
  final file = cbStr(record['studentParam1']);
  final voice = cbStr(record['teacherParam1']);
  return <String, dynamic>{
    'id': cbStr(record['id']),
    'homeworkId': cbStr(record['homeworkId']),
    'studentId': cbStr(record['studentId']),
    'status': cbInt(record['status']),
    'studentInfo': <String, dynamic>{
      'id': cbStr(record['studentId']),
      'realname': p?.name ?? '',
      'nickname': p?.name ?? '',
      'headUrl': p == null ? '' : cbUrl(p.avatarRef),
      'studentNo': p == null ? '' : cbStudentNo(p),
    },
    'realname': p?.name ?? '',
    'submitTime': record['submitTime'],
    'createTime': hw['createTime'],
    'expectedExt': hw['expectedExt'],
    'subjectName': hw['subjectName'],
    if (file.isNotEmpty) 'fileUrl': cbUrl(file),
    if (file.isNotEmpty) 'studentParam1': cbUrl(file),
    if (file.isNotEmpty) 'fileName': record['studentParam2'],
    'studentParam2': cbStr(record['studentParam2']),
    'studentParam3': cbStr(record['studentParam3']),
    'description': cbStr(record['description']),
    'fileSize': record['fileSize'],
    'score': record['score'],
    'feedback': record['feedback'],
    'teacherParam1': voice.isEmpty ? '' : cbUrl(voice),
    'teacherParam2': cbStr(record['teacherParam2']),
    'teacherParam3': cbStr(record['teacherParam3']),
    'correctTime': record['correctTime'],
  };
}

Map<String, dynamic> cbHomeworkJson(
  Map<String, dynamic> hw, {
  bool withStudents = false,
}) {
  final counts = cbHomeworkCounts(hw);
  final total = counts.unsubmitted + counts.pending + counts.reviewed;
  final classId = cbStr(hw['classId']);
  final className = cbClassName(classId);
  final teacherName = cbStaffName(hw['teacherUserId']);
  final result = <String, dynamic>{
    'id': cbStr(hw['id']),
    'title': cbStr(hw['title']),
    'description': cbStr(hw['description']),
    'classId': classId,
    'classIds': [classId],
    'className': className,
    'classInfo': <String, dynamic>{'id': classId, 'name': className},
    'subjectId': cbInt(hw['subjectId'], 38),
    'subjectName': cbStr(hw['subjectName']),
    'expectedExt': cbStr(hw['expectedExt']),
    'teacherId': cbStr(hw['teacherUserId']),
    'teacherName': teacherName,
    'createTime': hw['createTime'],
    'endTime': hw['endTime'],
    'status': cbHomeworkStatus(hw),
    'homeworkCount': <String, dynamic>{
      'status0': counts.unsubmitted,
      'status1': counts.pending,
      'status2': counts.reviewed,
    },
    'totalCount': total,
    'submitCount': counts.pending + counts.reviewed,
    'pendingCount': counts.pending,
    'reviewedCount': counts.reviewed,
  };
  if (withStudents) {
    const order = {1: 0, 2: 1, 0: 2};
    final records = [...cbRecordsOf(hw['id'])]
      ..sort((a, b) {
        final byStatus = (order[cbInt(a['status'])] ?? 3).compareTo(
          order[cbInt(b['status'])] ?? 3,
        );
        if (byStatus != 0) {
          return byStatus;
        }
        return cbStr(a['submitTime']).compareTo(cbStr(b['submitTime']));
      });
    result['studentList'] = [for (final r in records) cbRecordJson(r, hw)];
  }
  return result;
}
