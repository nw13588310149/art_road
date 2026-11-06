import '../demo_backend.dart';
import '../demo_store.dart';
import 'content_common.dart';

/// 「我的笔记」演示数据（按用户隔离）。
///
/// 笔记 `{id, categoryId, title, paperType, image, drawing, base, param4,
/// param5, favorite, createTime, updateTime}`，对应接口字段：
/// image → param1（整页预览图）、drawing → param2（矢量笔迹，内联或文件引用）、
/// base → param3（底图，打开笔记时垫在笔迹下方）。paperType：0 网格纸 / 1 笔记本 / 2 白纸。
abstract final class _NoteKeys {
  static String categories(String uid) => 'note_categories:$uid';
  static String notes(String uid) => 'notes:$uid';
}

List<Map<String, dynamic>> _seedNoteCategories() => <Map<String, dynamic>>[
  {'id': 4001, 'name': '素描笔记', 'createTime': '2026-09-02 19:00:00'},
  {'id': 4002, 'name': '色彩笔记', 'createTime': '2026-09-02 19:01:00'},
  {'id': 4003, 'name': '速写笔记', 'createTime': '2026-09-02 19:02:00'},
  {'id': 4004, 'name': '美术常识', 'createTime': '2026-09-02 19:03:00'},
];

Map<String, dynamic> _seedNote(
  int id,
  int categoryId,
  String title,
  int paperType,
  String base,
  String time, {
  bool favorite = false,
}) {
  return <String, dynamic>{
    'id': id,
    'categoryId': categoryId,
    'title': title,
    'paperType': paperType,
    'image': base.isEmpty ? 'string' : base,
    'drawing': 'string',
    'base': base.isEmpty ? 'string' : base,
    'param4': 'string',
    'param5': 'string',
    'favorite': favorite,
    'createTime': time,
    'updateTime': time,
  };
}

List<Map<String, dynamic>> _seedNotes() => <Map<String, dynamic>>[
  _seedNote(
    4101,
    4001,
    '素描头像五大调子笔记',
    0,
    ContentDemo.art('sketch-portrait-1'),
    '2026-11-05 21:40:00',
    favorite: true,
  ),
  _seedNote(
    4102,
    4001,
    '几何体明暗交界线',
    0,
    ContentDemo.paper('sketch'),
    '2026-10-28 20:10:00',
  ),
  _seedNote(
    4103,
    4001,
    '眼睛结构刻画要点',
    2,
    ContentDemo.art('detail-sketch'),
    '2026-10-19 21:05:00',
  ),
  _seedNote(
    4104,
    4002,
    '色彩冷暖关系',
    2,
    ContentDemo.art('color-still-5'),
    '2026-11-03 20:30:00',
    favorite: true,
  ),
  _seedNote(
    4105,
    4002,
    '风景色彩的空间层次',
    2,
    ContentDemo.art('color-landscape-1'),
    '2026-10-16 19:50:00',
  ),
  _seedNote(
    4106,
    4003,
    '速写人体比例',
    0,
    ContentDemo.paper('speed'),
    '2026-11-01 21:20:00',
  ),
  _seedNote(
    4107,
    4003,
    '人物动态线与重心',
    2,
    ContentDemo.art('speed-figure-1'),
    '2026-10-22 21:30:00',
  ),
  _seedNote(
    4108,
    4004,
    '印象派色彩笔记',
    1,
    ContentDemo.art('color-flower-1'),
    '2026-10-15 20:00:00',
  ),
  _seedNote(4109, 4004, '联考考前清单', 1, '', '2026-11-06 22:00:00'),
];

bool _isInlineDrawing(String raw) =>
    raw.startsWith('pk:') || raw.startsWith('strokes:') || raw.startsWith('[');

/// 媒体字段：占位保持原样，引用转成可加载地址。
String _mediaOut(Object? raw) {
  final value = raw?.toString() ?? '';
  return ContentDemo.isPlaceholder(value) ? 'string' : ContentDemo.url(value);
}

String _drawingOut(Object? raw) {
  final value = raw?.toString() ?? '';
  if (ContentDemo.isPlaceholder(value) || _isInlineDrawing(value)) {
    return value.isEmpty ? 'string' : value;
  }
  return ContentDemo.url(value);
}

Map<String, dynamic> _noteJson(Map<String, dynamic> n) => <String, dynamic>{
  'id': ContentDemo.toInt(n['id']),
  'categoryId': ContentDemo.toInt(n['categoryId']),
  'title': n['title'],
  'paperType': ContentDemo.toInt(n['paperType'], 2),
  'param1': _mediaOut(n['image']),
  'param2': _drawingOut(n['drawing']),
  'param3': _mediaOut(n['base']),
  'param4': n['param4'] ?? 'string',
  'param5': n['param5'] ?? 'string',
  'favorite': n['favorite'] == true,
  'createTime': n['createTime'],
  'updateTime': n['updateTime'] ?? n['createTime'],
};

void registerContentNoteFixtures(DemoRouter r) {
  List<Map<String, dynamic>> categories(DemoRequest req) => DemoStore.list(
    _NoteKeys.categories(req.account.userId),
    _seedNoteCategories,
  );
  List<Map<String, dynamic>> notes(DemoRequest req) =>
      DemoStore.list(_NoteKeys.notes(req.account.userId), _seedNotes);

  void saveAll(DemoRequest req) {
    DemoStore.save(_NoteKeys.categories(req.account.userId));
    DemoStore.save(_NoteKeys.notes(req.account.userId));
  }

  int idOf(Map<String, dynamic> item) => ContentDemo.toInt(item['id']);

  /// 把请求里的笔记字段写入 [note]；占位值不覆盖已有内容。
  void applyBody(DemoRequest req, Map<String, dynamic> note) {
    final categoryId = req.intOf('categoryId');
    if (!categories(req).any((c) => idOf(c) == categoryId)) {
      throw const DemoApiException('请先新增笔记分类');
    }
    final title = req.str('title');
    note['categoryId'] = categoryId;
    note['title'] = title.isEmpty ? (note['title'] ?? '未命名笔记') : title;
    note['paperType'] = req.intOf(
      'paperType',
      ContentDemo.toInt(note['paperType'], 2),
    );

    void put(String key, String field, {bool drawing = false}) {
      final raw = req.str(field);
      if (ContentDemo.isPlaceholder(raw)) {
        note.putIfAbsent(key, () => 'string');
        return;
      }
      note[key] = drawing && _isInlineDrawing(raw)
          ? raw
          : ContentDemo.refOf(raw);
    }

    put('image', 'param1');
    put('drawing', 'param2', drawing: true);
    put('base', 'param3');
    put('param4', 'param4');
    put('param5', 'param5');
    note['updateTime'] = ContentDemo.now();
  }

  // ── 分类 ──────────────────────────────────────────────────────────────
  r.any('/app/user/noteCategoryList', (req) {
    final all = notes(req);
    return <Map<String, dynamic>>[
      for (final c in categories(req))
        <String, dynamic>{
          'id': idOf(c),
          'name': c['name'],
          'count': all
              .where((n) => ContentDemo.toInt(n['categoryId']) == idOf(c))
              .length,
          'createTime': c['createTime'],
          'userId': req.account.userId,
        },
    ];
  });

  r.any('/app/user/noteCategorySave', (req) {
    final name = req.str('name');
    if (name.isEmpty) {
      throw const DemoApiException('请输入笔记分类名称');
    }
    final list = categories(req);
    final id = req.intOf('id');
    if (list.any((c) => c['name'] == name && idOf(c) != id)) {
      throw const DemoApiException('已存在同名分类');
    }
    if (id > 0) {
      final category = list.where((c) => idOf(c) == id).firstOrNull;
      if (category == null) {
        throw const DemoApiException('分类不存在，请刷新后重试');
      }
      category['name'] = name;
    } else {
      list.add(<String, dynamic>{
        'id': ContentDemo.newId(),
        'name': name,
        'createTime': ContentDemo.now(),
      });
    }
    saveAll(req);
    return true;
  });

  r.any('/app/user/noteCategoryDelete', (req) {
    final id = req.intOf('id');
    categories(req).removeWhere((c) => idOf(c) == id);
    notes(req).removeWhere((n) => ContentDemo.toInt(n['categoryId']) == id);
    saveAll(req);
    return true;
  });

  // ── 笔记 ──────────────────────────────────────────────────────────────
  r.any('/app/user/noteList', (req) {
    final categoryId = req.intOf('categoryId');
    final matched = demoSearch<Map<String, dynamic>>(
      notes(req)
          .where(
            (n) =>
                categoryId <= 0 ||
                ContentDemo.toInt(n['categoryId']) == categoryId,
          )
          .toList(),
      req.str('keyword'),
      (n) => <String>[n['title']?.toString() ?? ''],
    )..sort((a, b) => '${b['createTime']}'.compareTo('${a['createTime']}'));
    return ContentDemo.slice(matched.map(_noteJson).toList(), req);
  });

  r.any(
    '/app/user/noteCount',
    (req) => <String, dynamic>{'count': notes(req).length},
  );

  r.any('/app/user/noteDetail', (req) {
    final id = req.intOf('id');
    final note = notes(req).where((n) => idOf(n) == id).firstOrNull;
    if (note == null) {
      throw const DemoApiException('笔记不存在或已删除');
    }
    return _noteJson(note);
  });

  r.any('/app/user/noteSave', (req) {
    final note = <String, dynamic>{
      'id': ContentDemo.newId(),
      'favorite': false,
      'createTime': ContentDemo.now(),
    };
    applyBody(req, note);
    notes(req).add(note);
    saveAll(req);
    return _noteJson(note);
  });

  r.any('/app/user/noteUpdate', (req) {
    final id = req.intOf('id');
    final note = notes(req).where((n) => idOf(n) == id).firstOrNull;
    if (note == null) {
      throw const DemoApiException('笔记不存在或已删除');
    }
    applyBody(req, note);
    saveAll(req);
    return _noteJson(note);
  });

  r.any('/app/user/noteDelete', (req) {
    final id = req.intOf('id');
    notes(req).removeWhere((n) => idOf(n) == id);
    saveAll(req);
    return true;
  });
}
