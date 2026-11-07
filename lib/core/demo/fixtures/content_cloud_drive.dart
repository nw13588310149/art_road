import 'dart:convert';

import '../demo_backend.dart';
import '../demo_store.dart';
import 'content_common.dart';

/// 「我的云盘」演示数据（按用户隔离）。
///
/// 分类 `{id, name, createTime}`；文件夹 `{id, categoryId, name, createTime}`；
/// 文件 `{id, categoryId, folderId, title, type, file, images, size, createTime}`，
/// type：1 音频 / 2 图片（或带讲解音频的图文）/ 3 课件（PDF、视频等单文件），
/// file / images 为 `asset:` 或上传引用。
abstract final class _CloudKeys {
  static String categories(String uid) => 'cloud_categories:$uid';
  static String folders(String uid) => 'cloud_folders:$uid';
  static String files(String uid) => 'cloud_files:$uid';
}

const int _quotaBytes = 5 * 1024 * 1024 * 1024;

/// 演示账号在本次演示前已用的空间（历史资料），让存储条不至于接近 0。
const int _historyBytes = 612 * 1024 * 1024;

List<Map<String, dynamic>> _seedCategories() => <Map<String, dynamic>>[
  {'id': 3101, 'name': '素描资料', 'createTime': '2026-09-01 10:00:00'},
  {'id': 3102, 'name': '色彩资料', 'createTime': '2026-09-01 10:02:00'},
  {'id': 3103, 'name': '速写资料', 'createTime': '2026-09-01 10:04:00'},
  {'id': 3104, 'name': '联考模拟题', 'createTime': '2026-09-01 10:06:00'},
  {'id': 3105, 'name': '我的临摹', 'createTime': '2026-09-01 10:08:00'},
];

List<Map<String, dynamic>> _seedFolders() {
  Map<String, dynamic> folder(
    int id,
    int categoryId,
    String name,
    String time,
  ) => <String, dynamic>{
    'id': id,
    'categoryId': categoryId,
    'name': name,
    'createTime': time,
  };
  return <Map<String, dynamic>>[
    folder(3201, 3101, '石膏几何体', '2026-09-02 19:00:00'),
    folder(3202, 3101, '静物结构', '2026-09-08 19:00:00'),
    folder(3203, 3101, '石膏头像范画', '2026-09-20 19:00:00'),
    folder(3204, 3102, '静物色彩', '2026-09-03 19:00:00'),
    folder(3205, 3102, '风景写生', '2026-10-13 19:00:00'),
    folder(3206, 3102, '色调与配色', '2026-09-25 19:00:00'),
    folder(3207, 3103, '人物动态', '2026-09-04 19:00:00'),
    folder(3208, 3103, '场景速写', '2026-10-15 19:00:00'),
    folder(3209, 3103, '组合速写', '2026-10-02 19:00:00'),
    folder(3210, 3104, '2026 联考模拟', '2026-09-05 19:00:00'),
    folder(3211, 3104, '2025 联考模拟', '2026-09-05 19:10:00'),
    folder(3212, 3104, '评分标准与考场', '2026-09-06 19:00:00'),
    folder(3213, 3105, '本周临摹', '2026-11-02 19:00:00'),
    folder(3214, 3105, '临摹对照', '2026-10-20 19:00:00'),
  ];
}

Map<String, dynamic> _imageFile(
  int id,
  int categoryId,
  int folderId,
  String title,
  List<String> images,
  String time,
) {
  return <String, dynamic>{
    'id': id,
    'categoryId': categoryId,
    'folderId': folderId,
    'title': title,
    'type': 2,
    'file': '',
    'images': images,
    'size': images.fold<int>(0, (sum, ref) => sum + ContentDemo.bytesOf(ref)),
    'createTime': time,
  };
}

Map<String, dynamic> _singleFile(
  int id,
  int categoryId,
  int folderId,
  String title,
  String file,
  String time,
) {
  return <String, dynamic>{
    'id': id,
    'categoryId': categoryId,
    'folderId': folderId,
    'title': title,
    'type': 3,
    'file': file,
    'images': const <String>[],
    'size': ContentDemo.bytesOf(file),
    'createTime': time,
  };
}

List<Map<String, dynamic>> _seedFiles() {
  final art = ContentDemo.art;
  final paper = ContentDemo.paper;
  final scene = ContentDemo.scene;
  final clip = ContentDemo.clip;
  return <Map<String, dynamic>>[
    // 素描资料
    _imageFile(3301, 3101, 3201, '立方体结构步骤图', [
      paper('sketch'),
      art('sketch-geometry-1'),
    ], '2026-09-03 20:10:00'),
    _imageFile(3302, 3101, 3201, '几何体组合明暗范画', [
      art('sketch-geometry-1'),
    ], '2026-09-10 20:30:00'),
    _singleFile(
      3303,
      3101,
      3201,
      '排线练习示范视频',
      clip('hatching'),
      '2026-09-12 21:00:00',
    ),
    _imageFile(3304, 3101, 3202, '瓶罐衬布静物', [
      art('sketch-still-1'),
    ], '2026-09-15 19:40:00'),
    _imageFile(3305, 3101, 3202, '玻璃器皿质感', [
      art('sketch-still-2'),
    ], '2026-09-18 19:50:00'),
    _imageFile(3306, 3101, 3202, '陶罐与水果组合', [
      art('sketch-still-3'),
    ], '2026-09-22 20:05:00'),
    _imageFile(3307, 3101, 3203, '大卫石膏像', [
      art('sketch-bust-1'),
    ], '2026-09-24 20:00:00'),
    _imageFile(3308, 3101, 3203, '石膏五官写生', [
      art('sketch-bust-3'),
    ], '2026-10-06 20:20:00'),
    _imageFile(3309, 3101, 3203, '长期素描头像（含局部）', [
      art('sketch-portrait-1'),
      art('detail-sketch'),
      art('sketch-bust-2'),
    ], '2026-10-16 21:10:00'),
    // 色彩资料
    _imageFile(3310, 3102, 3204, '水粉静物步骤图', [
      paper('color'),
      art('color-still-1'),
    ], '2026-09-06 20:00:00'),
    _imageFile(3311, 3102, 3204, '秋日静物', [
      art('color-still-2'),
    ], '2026-10-08 20:15:00'),
    _imageFile(3312, 3102, 3204, '陶罐与水果', [
      art('color-still-5'),
    ], '2026-10-11 20:30:00'),
    _imageFile(3313, 3102, 3205, '村落秋色写生', [
      art('color-landscape-1'),
    ], '2026-10-14 18:40:00'),
    _singleFile(
      3314,
      3102,
      3205,
      '写生周现场实录',
      clip('studio'),
      '2026-10-16 21:30:00',
    ),
    _imageFile(3315, 3102, 3206, '花卉色彩', [
      art('color-flower-1'),
    ], '2026-09-27 20:00:00'),
    _imageFile(3316, 3102, 3206, '蔬果色彩细节', [
      art('detail-color'),
    ], '2026-09-29 20:10:00'),
    _imageFile(3317, 3102, 3206, '冷暖对比练习', [
      art('color-still-3'),
      art('color-still-4'),
    ], '2026-10-03 20:20:00'),
    // 速写资料
    _imageFile(3318, 3103, 3207, '站姿坐姿比例示意', [
      paper('speed'),
    ], '2026-09-05 21:00:00'),
    _imageFile(3319, 3103, 3207, '人物动态速写一组', [
      art('speed-figure-1'),
      art('speed-figure-2'),
      art('speed-figure-5'),
    ], '2026-10-09 21:20:00'),
    _imageFile(3320, 3103, 3207, '坐姿人物', [
      art('speed-figure-3'),
    ], '2026-10-12 21:10:00'),
    _imageFile(3321, 3103, 3208, '街市场景', [
      art('speed-scene-1'),
    ], '2026-10-17 21:00:00'),
    _imageFile(3322, 3103, 3209, '三人组合', [
      art('speed-group-1'),
    ], '2026-10-04 21:30:00'),
    _imageFile(3323, 3103, 3209, '双人互动', [
      art('speed-figure-4'),
    ], '2026-10-07 21:15:00'),
    // 联考模拟题
    _imageFile(3324, 3104, 3210, '素描模拟题：几何体组合', [
      paper('sketch'),
    ], '2026-09-05 19:20:00'),
    _imageFile(3325, 3104, 3210, '色彩模拟题：静物写生', [
      paper('color'),
    ], '2026-09-05 19:22:00'),
    _imageFile(3326, 3104, 3210, '速写模拟题：人物动态', [
      paper('speed'),
    ], '2026-09-05 19:24:00'),
    _imageFile(3327, 3104, 3211, '素描模拟题：静物组合', [
      art('sketch-still-3'),
    ], '2026-09-05 19:30:00'),
    _imageFile(3328, 3104, 3211, '色彩模拟题：风景', [
      art('color-landscape-1'),
    ], '2026-09-05 19:32:00'),
    _imageFile(3329, 3104, 3212, '素描评分档次对照', [
      art('sketch-portrait-1'),
      art('sketch-bust-3'),
    ], '2026-09-06 19:10:00'),
    _imageFile(3330, 3104, 3212, '考场实景', [
      scene('exam-hall'),
    ], '2026-09-06 19:20:00'),
    // 我的临摹
    _imageFile(3331, 3105, 3213, '眼睛结构临摹', [
      art('detail-sketch'),
    ], '2026-11-03 20:40:00'),
    _imageFile(3332, 3105, 3213, '花卉色彩临摹', [
      art('color-flower-1'),
    ], '2026-11-04 20:50:00'),
    _singleFile(
      3333,
      3105,
      3213,
      '铺纸与固定画纸',
      clip('place-paper'),
      '2026-11-02 19:30:00',
    ),
    _imageFile(3334, 3105, 3214, '石膏头像：原作与临摹对照', [
      art('sketch-bust-1'),
      art('sketch-bust-2'),
    ], '2026-10-21 20:00:00'),
  ];
}

List<String> _stringList(Object? raw) {
  if (raw is List) {
    return raw
        .map((e) => e?.toString() ?? '')
        .where((e) => !ContentDemo.isPlaceholder(e))
        .toList();
  }
  final text = raw?.toString().trim() ?? '';
  if (ContentDemo.isPlaceholder(text)) {
    return const <String>[];
  }
  if (text.startsWith('[')) {
    try {
      return _stringList(jsonDecode(text));
    } catch (_) {
      return const <String>[];
    }
  }
  return <String>[text];
}

void registerContentCloudDriveFixtures(DemoRouter r) {
  List<Map<String, dynamic>> categories(DemoRequest req) => DemoStore.list(
    _CloudKeys.categories(req.account.userId),
    _seedCategories,
  );
  List<Map<String, dynamic>> folders(DemoRequest req) =>
      DemoStore.list(_CloudKeys.folders(req.account.userId), _seedFolders);
  List<Map<String, dynamic>> files(DemoRequest req) =>
      DemoStore.list(_CloudKeys.files(req.account.userId), _seedFiles);

  void saveAll(DemoRequest req) {
    final uid = req.account.userId;
    DemoStore.save(_CloudKeys.categories(uid));
    DemoStore.save(_CloudKeys.folders(uid));
    DemoStore.save(_CloudKeys.files(uid));
  }

  int idOf(Map<String, dynamic> item) => ContentDemo.toInt(item['id']);
  int sizeOf(Map<String, dynamic> file) => ContentDemo.toInt(file['size']);

  Map<String, dynamic> fileJson(Map<String, dynamic> f) {
    final images = _stringList(f['images']);
    final file = f['file']?.toString() ?? '';
    final primary = file.isNotEmpty
        ? file
        : (images.isEmpty ? '' : images.first);
    return <String, dynamic>{
      'id': idOf(f),
      'categoryId': ContentDemo.toInt(f['categoryId']),
      'folderId': ContentDemo.toInt(f['folderId']),
      'title': f['title'],
      'param1': '${ContentDemo.toInt(f['type'], 3)}',
      'param2': ContentDemo.url(file),
      'param3': images.map(ContentDemo.url).toList(),
      'filePath': ContentDemo.url(primary),
      'fileSize': sizeOf(f),
      'createTime': f['createTime'],
    };
  }

  Map<String, dynamic> requireCategory(DemoRequest req, int id) {
    for (final category in categories(req)) {
      if (idOf(category) == id) {
        return category;
      }
    }
    throw const DemoApiException('分类不存在，请刷新后重试');
  }

  // ── 分类 ──────────────────────────────────────────────────────────────
  r.any('/app/courseware/v2/coursewareCategoryList', (req) {
    final all = files(req);
    return <Map<String, dynamic>>[
      for (final c in categories(req))
        <String, dynamic>{
          'id': idOf(c),
          'name': c['name'],
          'count': all
              .where((f) => ContentDemo.toInt(f['categoryId']) == idOf(c))
              .length,
          'createTime': c['createTime'],
        },
    ];
  });

  r.any('/app/courseware/v2/usage', (req) {
    final used = files(
      req,
    ).fold<int>(_historyBytes, (sum, f) => sum + sizeOf(f));
    return <String, dynamic>{
      'coursewareMaxCapacity': _quotaBytes,
      'coursewareUsageCapacity': used.clamp(0, _quotaBytes),
    };
  });

  r.any('/app/courseware/v2/coursewareCategorySave', (req) {
    final name = req.str('name');
    if (name.isEmpty) {
      throw const DemoApiException('请输入分类名称');
    }
    final list = categories(req);
    final id = req.intOf('id');
    if (list.any((c) => c['name'] == name && idOf(c) != id)) {
      throw const DemoApiException('已存在同名分类');
    }
    if (id > 0) {
      requireCategory(req, id)['name'] = name;
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

  r.any('/app/courseware/v2/coursewareCategoryDelete', (req) {
    final id = req.intOf('id');
    categories(req).removeWhere((c) => idOf(c) == id);
    folders(req).removeWhere((f) => ContentDemo.toInt(f['categoryId']) == id);
    files(req).removeWhere((f) => ContentDemo.toInt(f['categoryId']) == id);
    saveAll(req);
    return true;
  });

  // ── 文件夹 ────────────────────────────────────────────────────────────
  r.any('/app/courseware/v2/coursewareFolderList', (req) {
    final categoryId = req.intOf('categoryId');
    final all = files(req);
    final result = <Map<String, dynamic>>[];
    for (final folder in folders(req)) {
      if (ContentDemo.toInt(folder['categoryId']) != categoryId) {
        continue;
      }
      final inFolder = all
          .where((f) => ContentDemo.toInt(f['folderId']) == idOf(folder))
          .toList();
      result.add(<String, dynamic>{
        'id': idOf(folder),
        'categoryId': categoryId,
        'name': folder['name'],
        'count': inFolder.length,
        'totalFileSize': inFolder.fold<int>(0, (s, f) => s + sizeOf(f)),
        'createTime': folder['createTime'],
      });
    }
    return demoPage(result, req);
  });

  r.any('/app/courseware/v2/coursewareFolderSave', (req) {
    final name = req.str('name');
    if (name.isEmpty) {
      throw const DemoApiException('请输入文件夹名称');
    }
    final categoryId = req.intOf('categoryId');
    requireCategory(req, categoryId);
    final list = folders(req);
    final id = req.intOf('id');
    if (id > 0) {
      final folder = list.where((f) => idOf(f) == id).firstOrNull;
      if (folder == null) {
        throw const DemoApiException('文件夹不存在，请刷新后重试');
      }
      folder['name'] = name;
    } else {
      list.add(<String, dynamic>{
        'id': ContentDemo.newId(),
        'categoryId': categoryId,
        'name': name,
        'createTime': ContentDemo.now(),
      });
    }
    saveAll(req);
    return true;
  });

  r.any('/app/courseware/v2/coursewareFolderDelete', (req) {
    final id = req.intOf('id');
    folders(req).removeWhere((f) => idOf(f) == id);
    files(req).removeWhere((f) => ContentDemo.toInt(f['folderId']) == id);
    saveAll(req);
    return true;
  });

  // ── 文件 ──────────────────────────────────────────────────────────────
  r.any('/app/courseware/v2/coursewareList', (req) {
    final categoryId = req.intOf('categoryId');
    final folderId = req.intOf('folderId');
    final matched = demoSearch<Map<String, dynamic>>(
      files(req)
          .where(
            (f) =>
                ContentDemo.toInt(f['categoryId']) == categoryId &&
                ContentDemo.toInt(f['folderId']) == folderId,
          )
          .toList(),
      req.str('keyword'),
      (f) => <String>[f['title']?.toString() ?? ''],
    )..sort((a, b) => '${b['createTime']}'.compareTo('${a['createTime']}'));
    return demoPage(matched.map(fileJson).toList(), req);
  });

  r.any('/app/courseware/v2/coursewareSave', (req) {
    final title = req.str('title');
    if (title.isEmpty) {
      throw const DemoApiException('请输入资料标题');
    }
    final categoryId = req.intOf('categoryId');
    requireCategory(req, categoryId);
    final type = req.intOf('param1', 3);
    final audioOrFile = ContentDemo.refOf(req.str('param2'));
    final filePath = ContentDemo.refOf(req.str('filePath'));
    var file = ContentDemo.isPlaceholder(audioOrFile) ? '' : audioOrFile;
    var images = _stringList(
      req.value('param3'),
    ).map(ContentDemo.refOf).toList();
    if (type == 2) {
      if (images.isEmpty && !ContentDemo.isPlaceholder(filePath)) {
        images = <String>[filePath];
      }
      if (images.isEmpty) {
        throw const DemoApiException('请先选择图片并上传');
      }
    } else {
      if (file.isEmpty && !ContentDemo.isPlaceholder(filePath)) {
        file = filePath;
      }
      if (file.isEmpty) {
        throw const DemoApiException('请先选择文件并上传');
      }
    }
    final size =
        images.fold<int>(0, (s, ref) => s + ContentDemo.bytesOf(ref)) +
        (file.isEmpty ? 0 : ContentDemo.bytesOf(file));
    final record = <String, dynamic>{
      'id': ContentDemo.newId(),
      'categoryId': categoryId,
      'folderId': req.intOf('folderId'),
      'title': title,
      'type': type,
      'file': file,
      'images': images,
      'size': size,
      'createTime': ContentDemo.now(),
    };
    files(req).add(record);
    saveAll(req);
    return fileJson(record);
  });

  r.any('/app/courseware/v2/coursewareUpdateTitle', (req) {
    final title = req.str('title');
    if (title.isEmpty) {
      throw const DemoApiException('请输入新的标题');
    }
    final id = req.intOf('id');
    final file = files(req).where((f) => idOf(f) == id).firstOrNull;
    if (file == null) {
      throw const DemoApiException('资料不存在，请刷新后重试');
    }
    file['title'] = title;
    saveAll(req);
    return true;
  });

  r.any('/app/courseware/v2/coursewareDelete', (req) {
    final id = req.intOf('id');
    files(req).removeWhere((f) => idOf(f) == id);
    saveAll(req);
    return true;
  });
}
