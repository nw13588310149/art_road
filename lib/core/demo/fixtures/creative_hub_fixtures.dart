import 'package:image/image.dart' as img;
import 'marketplace_fixtures.dart';
import '../data/demo_artwork_data.dart';
import '../data/demo_artwork_store.dart';
import '../demo_accounts.dart';
import '../demo_backend.dart';
import '../demo_clock.dart';
import '../demo_store.dart';
import '../media/demo_media.dart';

typedef _Row = Map<String, dynamic>;
const _topicsKey = 'creative:topics:v1';
const _resourcesKey = 'creative:resources:v1';
String _text(Object? raw) => raw?.toString().trim() ?? '';
String _now() => DemoArtworkData.fmt(DemoClock.now());
List<_Row> _resources() => DemoStore.list(_resourcesKey, _seedResources);
List<_Row> _topics() => DemoStore.list(_topicsKey, _seedTopics);
_Row _find(List<_Row> rows, String id) =>
    rows.where((row) => row['id'] == id).firstOrNull ??
    (throw const DemoApiException('内容已不存在，请返回刷新', code: 404));

void registerCreativeHubFixtures(DemoRouter router) {
  registerMarketplaceFixtures(
    router,
    seedListings: _seedListings,
    resources: _resources,
  );
  _Row readableResource(DemoRequest req) {
    final row = _find(_resources(), req.param('id'));
    final shared = _topics().any(
      (topic) => (topic['resourceIds'] as List? ?? []).contains(row['id']),
    );
    if (row['ownerId'] != null &&
        row['ownerId'] != req.account.userId &&
        !shared) {
      throw const DemoApiException('没有权限阅读这份资料', code: 403);
    }
    return row;
  }

  String progressKey(DemoRequest req) =>
      'creative:progress:${req.account.userId}:${req.param('id')}';
  router.get('/app/creative/resources/{id}/progress', (req) {
    readableResource(req);
    return DemoStore.map(progressKey(req), () => {'page': 0});
  });
  router.post('/app/creative/resources/{id}/progress', (req) {
    final row = readableResource(req);
    final count = (row['pages'] as List? ?? []).length;
    final page = req.bodyMap['page'];
    if (page is! int || page < 0 || page >= count) {
      throw const DemoApiException('阅读页码超出范围', code: 400);
    }
    final key = progressKey(req);
    DemoStore.map(key, () => {})
      ..['page'] = page
      ..['updatedAt'] = _now();
    DemoStore.save(key);
    return true;
  });
  router.get(
    '/app/micro-lessons',
    (req) => [for (final row in _topics()) _topic(row, req)],
  );
  router.get(
    '/app/micro-lessons/resources',
    (req) => [
      for (final row in _resources())
        if (row['ownerId'] == null || row['ownerId'] == req.account.userId)
          _resource(row),
    ],
  );
  router.post('/app/micro-lessons', (req) {
    final body = req.bodyMap;
    _validateText(body, 'title', '专题名称', 2, 40);
    _validateText(body, 'intro', '学习说明', 10, 600);
    _subject(body);
    final minutes = req.intOf('minutes');
    if (minutes < 1 || minutes > 120) {
      throw const DemoApiException('阅读时长须为 1 至 120 分钟', code: 400);
    }
    final ids = req.listOf('resourceIds').map(_text).toSet().toList();
    if (ids.isEmpty || ids.length > 12) {
      throw const DemoApiException('请选择 1 至 12 份阅读资料', code: 400);
    }
    final resources = [for (final id in ids) _find(_resources(), id)];
    if (resources.any(
      (row) => row['ownerId'] != null && row['ownerId'] != req.account.userId,
    )) {
      throw const DemoApiException('只能使用自己的上传资料', code: 403);
    }
    final row = <String, dynamic>{
      'id': DemoStore.nextId('topic-'),
      'ownerId': req.account.userId,
      'author': req.account.name,
      'title': req.str('title'),
      'intro': req.str('intro'),
      'subject': req.str('subject'),
      'tags': req
          .listOf('tags')
          .map(_text)
          .where((s) => s.isNotEmpty)
          .take(5)
          .toList(),
      'exercise': req.str('exercise'),
      'level': req.str('level', '基础'),
      'minutes': minutes,
      'resourceIds': ids,
      'cover': resources.first['cover'],
      'createdAt': _now(),
    };
    _topics().insert(0, row);
    DemoStore.save(_topicsKey);
    return {'id': row['id']};
  });
  router.get(
    '/app/market/samples',
    (req) => [
      for (final row in _resources())
        if (row['sample'] == true) _resource(row),
    ],
  );
  router.get(
    '/app/market/my-artworks',
    (req) => [
      for (final work in DemoArtworkStore.latestVersions(
        DemoArtworkStore.works(),
      ))
        if (DemoArtworkData.accessOf(req.account, work).owner)
          {
            'id': work['id'],
            'title': work['title'],
            'cover': DemoMedia.url(
              _text(DemoArtworkData.imagesOf(work).firstOrNull?['ref']),
            ),
          },
    ],
  );
  for (final kind in ['micro-lessons']) {
    router.post('/app/$kind/{id}/favorite', (req) {
      _find(_topics(), req.param('id'));
      final key = 'creative:favorites:${req.account.userId}';
      final saved = DemoStore.map(key, () => {});
      final id = '$kind:${req.param('id')}';
      saved[id] = saved[id] != true;
      DemoStore.save(key);
      return saved[id];
    });
    router.post('/app/$kind/{id}/remove', (req) {
      final rows = _topics();
      final row = _find(rows, req.param('id'));
      if (row['ownerId'] != req.account.userId) {
        throw const DemoApiException('只能撤下自己的发布', code: 403);
      }
      rows.remove(row);
      DemoStore.save(_topicsKey);
      return true;
    });
  }
  router.post('/app/creative/uploads', (req) async {
    final file = req.files.firstOrNull;
    if (file == null ||
        file.bytes.isEmpty ||
        file.bytes.length > 20 * 1024 * 1024) {
      throw const DemoApiException('请选择 20 MB 以内的 PDF 或图片', code: 400);
    }
    final pdf = file.fileName.toLowerCase().endsWith('.pdf');
    if (pdf) {
      if (file.bytes.length < 5 ||
          String.fromCharCodes(file.bytes.take(5)) != '%PDF-') {
        throw const DemoApiException('PDF 文件无效', code: 400);
      }
    } else if (img.decodeImage(file.bytes) == null) {
      throw const DemoApiException('请选择 JPG、PNG 或 WebP 图片', code: 400);
    }
    final url = await DemoMedia.host(file.bytes, file.fileName);
    final row = <String, dynamic>{
      'id': DemoStore.nextId('resource-'),
      'title': file.fileName,
      'kind': pdf ? 'pdf' : 'images',
      'url': pdf ? url : '',
      'pages': pdf ? <String>[] : [url],
      'cover': pdf ? 'asset:assets/demo/ebooks/eb-sketch-still-cover.jpg' : url,
      'ownerId': req.account.userId,
    };
    _resources().add(row);
    DemoStore.save(_resourcesKey);
    return _resource(row);
  });
  router.post('/app/creative/image-books', (req) {
    final ids = req.listOf('resourceIds').map(_text).toList();
    if (ids.isEmpty || ids.length > 24) {
      throw const DemoApiException('图片书籍须包含 1 至 24 页', code: 400);
    }
    final items = [for (final id in ids) _find(_resources(), id)];
    if (items.any(
      (item) =>
          item['ownerId'] != req.account.userId || item['kind'] != 'images',
    )) {
      throw const DemoApiException('只能使用自己上传的图片', code: 403);
    }
    final row = <String, dynamic>{
      'id': DemoStore.nextId('book-'),
      'title': '图片书籍 · ${items.length} 页',
      'kind': 'images',
      'cover': items.first['cover'],
      'pages': [for (final item in items) ...(item['pages'] as List)],
      'ownerId': req.account.userId,
    };
    _resources().add(row);
    DemoStore.save(_resourcesKey);
    return _resource(row);
  });
}

bool _favorite(String kind, String id, DemoRequest req) =>
    DemoStore.map(
      'creative:favorites:${req.account.userId}',
      () => {},
    )['$kind:$id'] ==
    true;
_Row _resource(_Row row) => {
  ...row,
  'cover': DemoMedia.url(_text(row['cover'])),
  'url': _text(row['url']).isEmpty ? '' : DemoMedia.url(_text(row['url'])),
  'pages': [
    for (final page in row['pages'] as List? ?? []) DemoMedia.url(_text(page)),
  ],
};
_Row _topic(_Row row, DemoRequest req) => {
  ...row,
  'mine': row['ownerId'] == req.account.userId,
  'cover': DemoMedia.url(_text(row['cover'])),
  'favorite': _favorite('micro-lessons', _text(row['id']), req),
  'resources': [
    for (final id in row['resourceIds'] as List)
      _resource(_find(_resources(), _text(id))),
  ],
};
void _validateText(_Row body, String key, String label, int min, int max) {
  final length = _text(body[key]).runes.length;
  if (length < min || length > max) {
    throw DemoApiException('$label须为 $min 至 $max 个字', code: 400);
  }
}

void _subject(_Row body) {
  if (!const ['素描', '色彩', '速写', '美术常识'].contains(body['subject'])) {
    throw const DemoApiException('请选择科目', code: 400);
  }
}

List<_Row> _seedResources() => [
  for (final book in [
    ('eb-sketch-still', '联考素描静物高分解析（示例）', 12),
    ('eb-color-warmcool', '色彩静物冷暖关系 30 讲（示例）', 10),
    ('eb-speed-figure', '人物速写动态与比例（示例）', 10),
    ('eb-cast-head', '石膏头像结构入门（示例）', 10),
  ]) ...[
    {
      'id': book.$1,
      'bookId': book.$1,
      'title': book.$2,
      'kind': 'images',
      'cover': 'asset:assets/demo/ebooks/${book.$1}-cover.jpg',
      'pages': <String>[],
    },
    if (book.$1 != 'eb-cast-head')
      {
        'id': '${book.$1}-pdf',
        'title': '${book.$2} · PDF',
        'kind': 'pdf',
        'cover': 'asset:assets/demo/ebooks/${book.$1}-cover.jpg',
        'url': 'asset:assets/demo/ebooks/${book.$1}.pdf',
      },
  ],
  for (var i = 0; i < _art.length; i++)
    {
      'id': 'sample-$i',
      'title': _art[i].$1,
      'kind': 'images',
      'cover': 'asset:assets/demo/art/${_art[i].$2}.jpg',
      'pages': ['asset:assets/demo/art/${_art[i].$2}.jpg'],
      'sample': true,
    },
];
const _art = [
  ('午后的静物', 'color-still-2', '色彩'),
  ('石膏像的光', 'sketch-bust-1', '素描'),
  ('人物动态研究', 'speed-figure-1', '速写'),
  ('静物与衬布', 'sketch-still-2', '素描'),
  ('暖色调练习', 'color-still-4', '色彩'),
  ('几何体的秩序', 'sketch-geometry-1', '素描'),
  ('灰调静物', 'color-still-1', '色彩'),
  ('头像习作', 'sketch-bust-3', '素描'),
];
List<_Row> _seedTopics() {
  const specs = [
    (
      '把明暗交界线画进体积里',
      '素描',
      '观察光源、分清暗部层次，再让明暗交界线跟随形体转折。',
      '明暗交界线,体积,反光',
      'eb-sketch-still',
      'eb-cast-head',
      12,
    ),
    (
      '一组静物，建立统一的色调',
      '色彩',
      '从主色调开始，理解冷暖对比与环境色如何共同组织画面。',
      '冷暖,环境色,色调',
      'eb-color-warmcool',
      'eb-color-warmcool-pdf',
      10,
    ),
    (
      '先找重心，再画人物动态',
      '速写',
      '用动态线概括人物姿态，观察支撑脚与身体重心之间的关系。',
      '动态线,重心,比例',
      'eb-speed-figure',
      'eb-speed-figure-pdf',
      8,
    ),
    (
      '静物构图的三次取舍',
      '素描',
      '通过主体、陪体与留白的安排，建立画面中清晰的视觉顺序。',
      '构图,留白,主次',
      'eb-sketch-still-pdf',
      'eb-sketch-still',
      15,
    ),
    (
      '暗部的颜色从哪里来',
      '色彩',
      '比较固有色与环境色，练习在暗部保留色相而非一味加黑。',
      '暗部,环境色,纯度',
      'eb-color-warmcool-pdf',
      'eb-color-warmcool',
      12,
    ),
    (
      '用线条表达衣褶与转折',
      '速写',
      '在线条的轻重和疏密中组织衣褶，让结构关系清楚可读。',
      '线条,衣褶,疏密',
      'eb-speed-figure',
      'eb-speed-figure-pdf',
      10,
    ),
    (
      '石膏头像的骨点与比例',
      '素描',
      '先确认头部的大形与中轴，再用骨点检查五官位置和透视。',
      '骨点,透视,比例',
      'eb-cast-head',
      'eb-sketch-still-pdf',
      18,
    ),
    (
      '从画面中读懂观察方法',
      '美术常识',
      '对照不同题材的学习图册，记录作者如何选择视角、构图和表现重点。',
      '观察,赏析,画面分析',
      'eb-sketch-still',
      'eb-color-warmcool',
      15,
    ),
  ];
  return [
    for (var i = 0; i < specs.length; i++)
      {
        'id': 'topic-${i + 1}',
        'title': specs[i].$1,
        'subject': specs[i].$2,
        'intro': specs[i].$3,
        'tags': specs[i].$4.split(','),
        'resourceIds': [specs[i].$5, specs[i].$6],
        'minutes': specs[i].$7,
        'cover': _find(_resources(), specs[i].$5)['cover'],
        'level': i < 3 ? '基础' : '进阶',
        'author': DemoAccounts.all[i % DemoAccounts.all.length].name,
        'ownerId': DemoAccounts.all[i % DemoAccounts.all.length].userId,
        'exercise': '阅读后选择一份自己的作品，对照本节知识点标出两处可以改进的位置，再完成一张局部练习。',
        'createdAt': _now(),
      },
  ];
}

List<_Row> _seedListings() => [
  for (var i = 0; i < _art.length; i++)
    {
      'id': 'market-${i + 1}',
      'title': _art[i].$1,
      'cover': 'asset:assets/demo/art/${_art[i].$2}.jpg',
      'subject': _art[i].$3,
      'author': DemoAccounts.all[(i + 1) % DemoAccounts.all.length].name,
      'ownerId': DemoAccounts.all[(i + 1) % DemoAccounts.all.length].userId,
      'description':
          '这份${_art[i].$3}习作记录了从观察到表现的过程。尝试把注意力放在画面整体关系上，在局部刻画中保留笔触与呼吸感。此条目为演示内容。',
      'forSale': i % 3 != 2,
      'priceCents': [1800, 2600, 0, 1200, 3200, 0, 2400, 1600][i],
      'license': i % 2 == 0 ? 'study' : 'teaching',
      'createdAt': _now(),
    },
];
