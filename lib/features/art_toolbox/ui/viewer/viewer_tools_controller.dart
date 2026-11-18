import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import '../../../../core/widgets/image_viewer_tools.dart';
import '../../data/toolbox_image_source.dart';
import '../../logic/geometry.dart';
import '../../logic/image_filters.dart';
import '../../logic/image_ops.dart';
import '../widgets/image_job.dart';

/// 看图页底部的工具，顺序就是工具栏上的顺序。
enum ViewerTool { original, gray, levels, blur, mirror, grid, color, measure }

/// 换掉画面像素的处理，同一时间只有一种。
enum ViewerFilter { none, gray, levels, blur }

/// 点画面时做的事，同一时间只有一种。
enum ViewerTapMode { color, measure }

/// 构图线，可以同时打开几种。
enum ViewerGridLine { nine, quarters, diagonal }

/// 看图页的工具状态。
///
/// - 灰度、明度色阶、眯眼模糊互斥，「原图」把所有工具都关掉；
/// - 镜像和构图网格可以和它们叠加；
/// - 取色和比例测量都靠点画面，同一时间只开一个；
/// - 翻到别的图时工具保持打开，取色点和测量线清掉（它们属于那一张图）。
///
/// 色阶和模糊在后台算，只算最后一次请求，结果按「哪张图 + 哪种处理」缓存。
class ViewerToolsController extends ChangeNotifier {
  ViewerToolsController() {
    _job = LatestImageJob<_FilterRequest, void>(
      run: (request) async => (await _process(request), null),
      onResult: (request, result) {
        _store(request.key, result.image);
        if (_pending == request.key) {
          _pending = null;
        }
        _notify();
      },
      onError: (_) {
        _pending = null;
        _failed = true;
        _notify();
      },
    );
  }

  static const levelOptions = <int>[2, 3, 5];
  static const blurOptions = <int>[3, 6, 9];
  static const _cacheSize = 8;

  late final LatestImageJob<_FilterRequest, void> _job;
  bool _disposed = false;

  ViewerFilter _filter = ViewerFilter.none;
  int _levels = 3;
  int _blurLevel = 6;
  bool _mirrorX = false;
  bool _mirrorY = false;
  final Set<ViewerGridLine> _grid = <ViewerGridLine>{};
  ViewerTapMode? _tapMode;
  ViewerTool? _focus;

  ImageViewerItem? _item;
  ui.Image? _source;
  int _imageVersion = 0;
  Future<ArtImageData?>? _data;
  Future<ArtImageData?>? _work;
  bool _failed = false;
  String? _pending;
  final LinkedHashMap<String, ui.Image> _results =
      LinkedHashMap<String, ui.Image>();

  Offset? _pickAt;
  RgbColor? _picked;
  final List<Offset> _measure = <Offset>[];

  ViewerFilter get filter => _filter;
  int get levels => _levels;
  int get blurLevel => _blurLevel;
  bool get mirrorX => _mirrorX;
  bool get mirrorY => _mirrorY;
  Set<ViewerGridLine> get grid => UnmodifiableSetView(_grid);
  ViewerTapMode? get tapMode => _tapMode;

  /// 设置行当前显示哪个工具的选项。
  ViewerTool? get focus => _focus;
  ImageViewerItem? get item => _item;

  /// 当前这张图的像素尺寸，加载完成前为 null。
  ui.Size? get imageSize => _source == null
      ? null
      : ui.Size(_source!.width.toDouble(), _source!.height.toDouble());

  /// 正在后台处理当前图。
  bool get processing => _pending != null;

  /// 当前图读不出像素（色阶、模糊、取色用不了）。
  bool get failed => _failed;

  /// 取色点（相对图片 0–1，未镜像时的位置）与取到的颜色。
  Offset? get pickAt => _pickAt;
  RgbColor? get picked => _picked;

  /// 测量点（相对图片 0–1，未镜像时的位置），每两个点一段：A 段、B 段。
  List<Offset> get measurePoints => List<Offset>.unmodifiable(_measure);

  bool isActive(ViewerTool tool) => switch (tool) {
    ViewerTool.original =>
      _filter == ViewerFilter.none &&
          !_mirrorX &&
          !_mirrorY &&
          _grid.isEmpty &&
          _tapMode == null,
    ViewerTool.gray => _filter == ViewerFilter.gray,
    ViewerTool.levels => _filter == ViewerFilter.levels,
    ViewerTool.blur => _filter == ViewerFilter.blur,
    ViewerTool.mirror => _mirrorX || _mirrorY,
    ViewerTool.grid => _grid.isNotEmpty,
    ViewerTool.color => _tapMode == ViewerTapMode.color,
    ViewerTool.measure => _tapMode == ViewerTapMode.measure,
  };

  /// 当前最相关的工具，「更多工具」据此打开工具箱里对应的那一个。
  ViewerTool? get leadTool {
    final focus = _focus;
    if (focus != null && isActive(focus)) {
      return focus;
    }
    for (final tool in ViewerTool.values.skip(1)) {
      if (isActive(tool)) {
        return tool;
      }
    }
    return null;
  }

  /// 点工具栏上的一项：没打开就打开并显示它的选项；打开着但选项没显示就显示选项；
  /// 选项正显示着就关掉它。
  void tap(ViewerTool tool) {
    if (tool == ViewerTool.original) {
      _filter = ViewerFilter.none;
      _mirrorX = false;
      _mirrorY = false;
      _grid.clear();
      _tapMode = null;
      _focus = null;
      _clearMarks();
      _refresh();
      return;
    }
    final active = isActive(tool);
    if (active && _focus != tool && tool != ViewerTool.gray) {
      _focus = tool;
      _notify();
      return;
    }
    if (active) {
      _turnOff(tool);
      _focus = null;
    } else {
      _turnOn(tool);
      _focus = tool == ViewerTool.gray ? null : tool;
    }
    _refresh();
  }

  void _turnOn(ViewerTool tool) {
    switch (tool) {
      case ViewerTool.gray:
        _filter = ViewerFilter.gray;
      case ViewerTool.levels:
        _filter = ViewerFilter.levels;
      case ViewerTool.blur:
        _filter = ViewerFilter.blur;
      case ViewerTool.mirror:
        _mirrorX = true;
      case ViewerTool.grid:
        _grid.add(ViewerGridLine.nine);
      case ViewerTool.color:
        _tapMode = ViewerTapMode.color;
        _measure.clear();
      case ViewerTool.measure:
        _tapMode = ViewerTapMode.measure;
        _pickAt = null;
        _picked = null;
      case ViewerTool.original:
        break;
    }
  }

  void _turnOff(ViewerTool tool) {
    switch (tool) {
      case ViewerTool.gray || ViewerTool.levels || ViewerTool.blur:
        _filter = ViewerFilter.none;
      case ViewerTool.mirror:
        _mirrorX = false;
        _mirrorY = false;
      case ViewerTool.grid:
        _grid.clear();
      case ViewerTool.color || ViewerTool.measure:
        _tapMode = null;
        _clearMarks();
      case ViewerTool.original:
        break;
    }
  }

  void setLevels(int value) {
    _levels = value;
    _refresh();
  }

  void setBlurLevel(int value) {
    _blurLevel = value;
    _refresh();
  }

  void toggleMirror({required bool horizontal}) {
    if (horizontal) {
      _mirrorX = !_mirrorX;
    } else {
      _mirrorY = !_mirrorY;
    }
    _notify();
  }

  void toggleGrid(ViewerGridLine line) {
    if (!_grid.remove(line)) {
      _grid.add(line);
    }
    _notify();
  }

  void clearMeasure() {
    _measure.clear();
    _notify();
  }

  /// 点在画面上（相对图片 0–1，看到的位置，镜像后的）。
  void tapImage(Offset visible) {
    final point = Offset(
      _mirrorX ? 1 - visible.dx : visible.dx,
      _mirrorY ? 1 - visible.dy : visible.dy,
    );
    switch (_tapMode) {
      case ViewerTapMode.color:
        _pickAt = point;
        _focus = ViewerTool.color;
        _notify();
        unawaited(_sample(point));
      case ViewerTapMode.measure:
        if (_measure.length >= 4) {
          _measure.clear();
        }
        _measure.add(point);
        _focus = ViewerTool.measure;
        _notify();
      case null:
        break;
    }
  }

  /// 看到的位置（考虑镜像），用来画取色点和测量线。
  Offset visible(Offset point) => Offset(
    _mirrorX ? 1 - point.dx : point.dx,
    _mirrorY ? 1 - point.dy : point.dy,
  );

  Future<void> _sample(Offset point) async {
    final version = _imageVersion;
    final data = await _ensureData();
    if (_disposed || version != _imageVersion || _pickAt != point) {
      return;
    }
    if (data == null) {
      _failed = true;
      _notify();
      return;
    }
    _picked = pixelAt(
      data,
      (point.dx * data.width).floor(),
      (point.dy * data.height).floor(),
    );
    _notify();
  }

  /// A 段和 B 段的长度（按图片像素），还没量完的段不在里面。
  List<double> get segmentLengths {
    final size = imageSize;
    if (size == null) {
      return const <double>[];
    }
    final points = [
      for (final p in _measure) Offset(p.dx * size.width, p.dy * size.height),
    ];
    return [for (final (a, b) in segmentsOf(points)) segmentLength(a, b)];
  }

  /// 切到 [item]，或这张图刚加载完。
  void show(ImageViewerItem item, ui.Image? image) {
    final previous = _item;
    final same =
        previous != null &&
        previous.index == item.index &&
        previous.src == item.src;
    if (!same) {
      _imageVersion++;
      _source?.dispose();
      _source = null;
      _data = null;
      _work = null;
      _failed = false;
      _pending = null;
      _clearMarks();
    }
    _item = item;
    if (image != null && _source == null) {
      _source = image.clone();
    }
    _refresh();
  }

  /// [item] 这张图在当前处理下的结果；还没算好或不需要处理时为 null，显示原图。
  ui.Image? resultFor(ImageViewerItem item) {
    final key = _resultKey(item);
    return key == null ? null : _results[key];
  }

  String? _resultKey(ImageViewerItem item) => switch (_filter) {
    ViewerFilter.levels => '${item.index}|${item.src}|levels|$_levels',
    ViewerFilter.blur => '${item.index}|${item.src}|blur|$_blurLevel',
    _ => null,
  };

  void _refresh() {
    final item = _item;
    final key = item == null ? null : _resultKey(item);
    if (key == null || _results.containsKey(key) || _source == null) {
      _pending = null;
      _notify();
      return;
    }
    if (_pending == key) {
      _notify();
      return;
    }
    _pending = key;
    _notify();
    final filter = _filter;
    final levels = _levels;
    final blurLevel = _blurLevel;
    final version = _imageVersion;
    final data = filter == ViewerFilter.blur ? _ensureWork() : _ensureData();
    unawaited(
      data.then((data) {
        if (_disposed || version != _imageVersion || _pending != key) {
          return;
        }
        if (data == null) {
          _pending = null;
          _failed = true;
          _notify();
          return;
        }
        _job.request(_FilterRequest(key, filter, levels, blurLevel, data));
      }),
    );
  }

  Future<ArtImageData?> _ensureData() {
    final source = _source;
    if (source == null) {
      return Future<ArtImageData?>.value();
    }
    return _data ??= artImageFromUiImage(source).catchError((Object _) => null);
  }

  Future<ArtImageData?> _ensureWork() => _work ??= _downscaleForWork();

  Future<ArtImageData?> _downscaleForWork() async {
    final data = await _ensureData();
    return data == null ? null : compute(downscaleForWork, data);
  }

  static Future<ArtImageData> _process(_FilterRequest request) {
    return switch (request.filter) {
      ViewerFilter.blur => compute(
        blurImage,
        BlurRequest(
          request.data,
          blurRadiusForLevel(
            request.blurLevel,
            request.data.width > request.data.height
                ? request.data.width
                : request.data.height,
          ),
        ),
      ),
      _ => compute(_posterize, PosterizeRequest(request.data, request.levels)),
    };
  }

  void _store(String key, ui.Image image) {
    final previous = _results.remove(key);
    disposeImageLater(previous);
    if (_disposed) {
      image.dispose();
      return;
    }
    _results[key] = image;
    while (_results.length > _cacheSize) {
      final oldest = _results.keys.first;
      disposeImageLater(_results.remove(oldest));
    }
  }

  void _clearMarks() {
    _pickAt = null;
    _picked = null;
    _measure.clear();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _job.dispose();
    _source?.dispose();
    for (final image in _results.values) {
      disposeImageLater(image);
    }
    _results.clear();
    super.dispose();
  }
}

class _FilterRequest {
  const _FilterRequest(
    this.key,
    this.filter,
    this.levels,
    this.blurLevel,
    this.data,
  );

  final String key;
  final ViewerFilter filter;
  final int levels;
  final int blurLevel;
  final ArtImageData data;
}

ArtImageData _posterize(PosterizeRequest request) =>
    posterize(request.image, request.levels);
