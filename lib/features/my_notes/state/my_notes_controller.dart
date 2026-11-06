import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../../../core/network/media_url.dart';
import '../../../core/network/upload_result.dart';
import '../data/my_notes_repository.dart';
import 'my_notes_state.dart';
import 'note_drawing_codec.dart';

final myNotesControllerProvider =
    StateNotifierProvider.autoDispose<MyNotesController, MyNotesState>((ref) {
      final repository = ref.watch(myNotesRepositoryProvider);
      return MyNotesController(repository: repository);
    });

class MyNotesController extends StateNotifier<MyNotesState> {
  MyNotesController({required MyNotesRepository repository})
    : _repository = repository,
      super(const MyNotesState()) {
    unawaited(refresh());
  }

  final MyNotesRepository _repository;

  /// Android 笔迹历史：add 存单笔；erase 存被删多笔，供 undo/redo。
  final List<_StrokeHistoryOp> _undoOps = <_StrokeHistoryOp>[];
  final List<_StrokeHistoryOp> _redoOps = <_StrokeHistoryOp>[];

  Future<void> refresh() async {
    try {
      state = state.copyWith(loading: true, clearError: true);

      // `/app/user/noteCategoryList` 在 v2 数据里已经直接给每个分类带上了
      // `count` 字段（左侧导航的「（数字）」就是用它），不再需要额外请求一次
      // `/app/user/noteCount`，那是旧接口、且返回值在这里也不会被使用。
      final categoriesResponse = await _repository.getCategories();
      final categories = _parseCategories(categoriesResponse.data);

      final selectedCategoryId = _resolveInitialCategoryId(
        categories,
        state.selectedCategoryId,
      );
      final notesResponse = selectedCategoryId > 0
          ? await _repository
                .getNotes(categoryId: selectedCategoryId)
                .timeout(
                  const Duration(seconds: 8),
                  onTimeout: () =>
                      const ApiResponse(code: -1, msg: '加载笔记超时', data: null),
                )
          : const ApiResponse(code: 0, msg: '', data: <dynamic>[]);
      final notes = _parseNotes(notesResponse.data);

      state = state.copyWith(
        loading: false,
        categories: categories,
        selectedCategoryId: selectedCategoryId,
        notes: notes,
        errorMessage: notesResponse.isSuccess
            ? null
            : notesResponse.displayMsg,
      );
    } catch (_) {
      state = state.copyWith(loading: false, errorMessage: '');
    }
  }

  Future<void> selectCategory(int categoryId) async {
    if (categoryId == state.selectedCategoryId &&
        state.view == MyNotesView.list) {
      return;
    }

    try {
      state = state.copyWith(
        selectedCategoryId: categoryId,
        loading: true,
        view: MyNotesView.list,
        clearError: true,
      );

      final response = categoryId > 0
          ? await _repository
                .getNotes(categoryId: categoryId)
                .timeout(
                  const Duration(seconds: 8),
                  onTimeout: () =>
                      const ApiResponse(code: -1, msg: '加载笔记超时', data: null),
                )
          : const ApiResponse(code: 0, msg: '', data: <dynamic>[]);
      state = state.copyWith(
        loading: false,
        notes: _parseNotes(response.data),
        errorMessage: response.isSuccess
            ? null
            : response.displayMsg,
        clearEditingNote: true,
        clearEditorBackgroundImageUrl: true,
        clearPendingPencilKitData: true,
        strokes: const <NoteStroke>[],
        redoStrokes: const <NoteStroke>[],
        toolMode: NoteToolMode.pen,
        editorHasVectorLayer: false,
      );
      _clearStrokeHistory();
    } catch (_) {
      state = state.copyWith(loading: false, errorMessage: '');
    }
  }

  void selectFilter(MyNotesFilter filter) {
    if (filter == state.activeFilter) {
      return;
    }
    state = state.copyWith(activeFilter: filter);
  }

  Future<String?> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '请输入笔记分类名称';
    }

    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.addCategory(trimmed);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return response.displayMsg;
    }
    await refresh();
    return null;
  }

  Future<String?> deleteCategory(int id) async {
    if (id <= 0) {
      return '默认分类不能删除';
    }
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.deleteCategory(id);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return response.displayMsg;
    }
    await refresh();
    return null;
  }

  /// 重命名笔记分类。沿用 `noteCategorySave` 接口：传入既有 id + 新名称，
  /// 后端按 id 更新分类名。成功后会重新拉取分类列表，让左侧导航即时刷新。
  Future<String?> renameCategory(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '请输入笔记分类名称';
    }
    if (id <= 0) {
      return '默认分类不能重命名';
    }
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.updateCategory(id: id, name: trimmed);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return response.displayMsg;
    }
    await refresh();
    return null;
  }

  Future<String?> deleteNote(int id) async {
    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.deleteNote(id);
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return response.displayMsg;
    }
    await refresh();
    return null;
  }

  Future<String?> renameNote(NoteEntry note, String newTitle) async {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) {
      return '请输入笔记名称';
    }
    if (trimmed == note.title) {
      return null;
    }
    if (note.id <= 0) {
      return '笔记 id 缺失，无法重命名';
    }

    state = state.copyWith(busy: true, clearError: true);
    final response = await _repository.updateNote(
      id: note.id,
      categoryId: note.categoryId > 0 ? note.categoryId : _writeCategoryId,
      paperType: note.paperType.value,
      title: trimmed,
      imageUrl: note.imageUrl,
      param2: note.drawingData.isEmpty ? 'string' : note.drawingData,
    );
    state = state.copyWith(busy: false);
    if (!response.isSuccess) {
      return response.displayMsg;
    }
    await refresh();
    return null;
  }

  String? validateCanCreateNote() {
    if (_writeCategoryId <= 0) {
      return '请先新增笔记分类';
    }
    return null;
  }

  String? beginCreateNote({String? title}) {
    if (_writeCategoryId <= 0) {
      return '请先新增笔记分类';
    }
    final trimmed = title?.trim() ?? '';
    state = state.copyWith(
      view: MyNotesView.template,
      draftTitle: trimmed.isEmpty ? '笔记名称' : trimmed,
      paperType: NotePaperType.staff,
      strokes: const <NoteStroke>[],
      redoStrokes: const <NoteStroke>[],
      toolMode: NoteToolMode.pen,
      clearEditingNote: true,
      clearEditorBackgroundImageUrl: true,
      clearPendingPencilKitData: true,
      editorHasVectorLayer: false,
      clearError: true,
    );
    _clearStrokeHistory();
    return null;
  }

  void backToList() {
    state = state.copyWith(
      view: MyNotesView.list,
      strokes: const <NoteStroke>[],
      redoStrokes: const <NoteStroke>[],
      toolMode: NoteToolMode.pen,
      clearEditingNote: true,
      clearEditorBackgroundImageUrl: true,
      clearPendingPencilKitData: true,
      editorHasVectorLayer: false,
      clearError: true,
    );
    _clearStrokeHistory();
  }

  void chooseTemplate(NotePaperType type) {
    state = state.copyWith(
      view: MyNotesView.editor,
      paperType: type,
      draftTitle: state.draftTitle.isEmpty ? '笔记名称' : state.draftTitle,
      strokes: const <NoteStroke>[],
      redoStrokes: const <NoteStroke>[],
      toolMode: NoteToolMode.pen,
      clearEditingNote: true,
      clearEditorBackgroundImageUrl: true,
      clearPendingPencilKitData: true,
      editorHasVectorLayer: false,
    );
    _clearStrokeHistory();
  }

  Future<void> openExistingNote(NoteEntry note) async {
    _clearStrokeHistory();
    state = state.copyWith(
      view: MyNotesView.editor,
      draftTitle: note.title,
      paperType: note.paperType,
      editingNote: note,
      editorBackgroundImageUrl: note.imageUrl.isEmpty ? null : note.imageUrl,
      strokes: const <NoteStroke>[],
      redoStrokes: const <NoteStroke>[],
      toolMode: NoteToolMode.pen,
      clearPendingPencilKitData: true,
      editorHasVectorLayer: false,
      clearError: true,
      busy: true,
    );

    final payload = await _resolveDrawingPayload(note.drawingData);
    if (payload == null) {
      // 旧笔记：保留 param1 底图叠画。
      state = state.copyWith(busy: false, editorHasVectorLayer: false);
      return;
    }

    switch (payload.kind) {
      case NoteDrawingKind.pencilKit:
        state = state.copyWith(
          busy: false,
          editorHasVectorLayer: true,
          clearEditorBackgroundImageUrl: true,
          pendingPencilKitData: payload.pencilKitBase64,
        );
        break;
      case NoteDrawingKind.strokes:
        _clearStrokeHistory();
        for (final stroke in payload.strokes) {
          _undoOps.add(_StrokeHistoryOp.add(stroke));
        }
        state = state.copyWith(
          busy: false,
          editorHasVectorLayer: true,
          clearEditorBackgroundImageUrl: true,
          strokes: payload.strokes,
          redoStrokes: const <NoteStroke>[],
          clearPendingPencilKitData: true,
        );
        break;
      case NoteDrawingKind.remotePath:
        state = state.copyWith(busy: false, editorHasVectorLayer: false);
        break;
    }
  }

  Future<NoteDrawingPayload?> _resolveDrawingPayload(String raw) async {
    final initial = NoteDrawingCodec.parsePayload(raw);
    if (initial == null) {
      return null;
    }
    if (initial.kind != NoteDrawingKind.remotePath) {
      return initial;
    }
    final path = initial.remotePath?.trim() ?? '';
    if (path.isEmpty) {
      return null;
    }
    try {
      final url = MediaUrl.resolve(path);
      final bytes = await _repository.downloadBytes(url);
      return NoteDrawingCodec.parseFileBody(bytes);
    } catch (_) {
      return null;
    }
  }

  void clearPendingPencilKitData() {
    if (state.pendingPencilKitData == null) {
      return;
    }
    state = state.copyWith(clearPendingPencilKitData: true);
  }

  void updateDraftTitle(String title) {
    state = state.copyWith(draftTitle: title);
  }

  void setToolMode(NoteToolMode mode) {
    if (mode == state.toolMode) {
      return;
    }
    state = state.copyWith(toolMode: mode);
  }

  void setSelectedColor(Color color) {
    state = state.copyWith(
      selectedColor: color,
      toolMode: NoteToolMode.pen,
    );
  }

  void setStrokeWidth(double width) {
    state = state.copyWith(strokeWidth: width.clamp(2, 32));
  }

  void addStroke(List<Offset> points) {
    if (points.length < 2) {
      return;
    }
    if (state.toolMode == NoteToolMode.eraser) {
      _eraseStrokesAlong(points);
      return;
    }
    final stroke = NoteStroke(
      color: state.selectedColor,
      width: state.strokeWidth,
      points: points,
    );
    _redoOps.clear();
    _undoOps.add(_StrokeHistoryOp.add(stroke));
    state = state.copyWith(
      strokes: <NoteStroke>[...state.strokes, stroke],
      redoStrokes: const <NoteStroke>[],
    );
  }

  void _eraseStrokesAlong(List<Offset> eraserPoints) {
    if (state.strokes.isEmpty) {
      return;
    }
    final threshold = math.max(12.0, state.strokeWidth);
    final kept = <NoteStroke>[];
    final removed = <NoteStroke>[];
    for (final stroke in state.strokes) {
      if (_strokeHitsEraser(stroke, eraserPoints, threshold)) {
        removed.add(stroke);
      } else {
        kept.add(stroke);
      }
    }
    if (removed.isEmpty) {
      return;
    }
    _redoOps.clear();
    _undoOps.add(_StrokeHistoryOp.erase(removed));
    state = state.copyWith(
      strokes: kept,
      redoStrokes: const <NoteStroke>[],
    );
  }

  bool _strokeHitsEraser(
    NoteStroke stroke,
    List<Offset> eraserPoints,
    double threshold,
  ) {
    final hitRadius = threshold + stroke.width * 0.5;
    for (final eraser in eraserPoints) {
      for (var i = 0; i < stroke.points.length; i++) {
        if ((stroke.points[i] - eraser).distance <= hitRadius) {
          return true;
        }
        if (i > 0 &&
            _distanceToSegment(
                  eraser,
                  stroke.points[i - 1],
                  stroke.points[i],
                ) <=
                hitRadius) {
          return true;
        }
      }
    }
    return false;
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final length2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (length2 <= 0.0001) {
      return (p - a).distance;
    }
    final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / length2)
        .clamp(0.0, 1.0);
    final projection = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - projection).distance;
  }

  bool get canUndoFlutter => _undoOps.isNotEmpty;

  bool get canRedoFlutter => _redoOps.isNotEmpty;

  void undoStroke() {
    if (_undoOps.isEmpty) {
      return;
    }
    final op = _undoOps.removeLast();
    _redoOps.add(op);
    switch (op.kind) {
      case _StrokeHistoryKind.add:
        final next = <NoteStroke>[...state.strokes];
        if (next.isNotEmpty) {
          next.removeLast();
        }
        state = state.copyWith(
          strokes: next,
          redoStrokes: _redoOps
              .where((item) => item.kind == _StrokeHistoryKind.add)
              .map((item) => item.stroke!)
              .toList(),
        );
        break;
      case _StrokeHistoryKind.erase:
        state = state.copyWith(
          strokes: <NoteStroke>[...state.strokes, ...op.removed],
          redoStrokes: const <NoteStroke>[],
        );
        break;
    }
  }

  void redoStroke() {
    if (_redoOps.isEmpty) {
      return;
    }
    final op = _redoOps.removeLast();
    _undoOps.add(op);
    switch (op.kind) {
      case _StrokeHistoryKind.add:
        state = state.copyWith(
          strokes: <NoteStroke>[...state.strokes, op.stroke!],
          redoStrokes: const <NoteStroke>[],
        );
        break;
      case _StrokeHistoryKind.erase:
        final removeSet = op.removed.toSet();
        state = state.copyWith(
          strokes: state.strokes
              .where((stroke) => !removeSet.contains(stroke))
              .toList(),
          redoStrokes: const <NoteStroke>[],
        );
        break;
    }
  }

  void clearCanvas() {
    if (state.strokes.isEmpty && _undoOps.isEmpty) {
      return;
    }
    _clearStrokeHistory();
    state = state.copyWith(
      strokes: const <NoteStroke>[],
      redoStrokes: const <NoteStroke>[],
    );
  }

  void _clearStrokeHistory() {
    _undoOps.clear();
    _redoOps.clear();
  }

  /// [pngBytes] 预览图；[drawingExport] 为矢量正文（pk base64 或 strokes JSON，
  /// 不含前缀时由 [drawingKind] 指定）。
  Future<String?> saveCurrentNote({
    required Uint8List pngBytes,
    String? drawingExport,
    NoteDrawingKind? drawingKind,
  }) async {
    final categoryId = _writeCategoryId;
    if (categoryId <= 0) {
      return '请先新增笔记分类';
    }

    state = state.copyWith(busy: true, clearError: true);
    final uploadResponse = await _repository.uploadNoteImage(
      bytes: pngBytes,
      filename: 'note_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    if (!uploadResponse.isSuccess) {
      state = state.copyWith(busy: false);
      return uploadResponse.displayMsg;
    }

    final imagePath = parseUploadResult(uploadResponse.data).savable;
    if (imagePath.isEmpty) {
      state = state.copyWith(busy: false);
      return uploadResponse.displayMsg;
    }

    final param2 = await _encodeParam2(
      drawingExport: drawingExport,
      drawingKind: drawingKind,
    );

    final title = state.draftTitle.trim().isEmpty
        ? '笔记名称'
        : state.draftTitle.trim();
    final editingId = state.editingNote?.id ?? 0;
    final saveResponse = editingId > 0
        ? await _repository.updateNote(
            id: editingId,
            categoryId: categoryId,
            paperType: state.paperType.value,
            title: title,
            imageUrl: imagePath,
            param2: param2,
          )
        : await _repository.saveNote(
            categoryId: categoryId,
            paperType: state.paperType.value,
            title: title,
            imageUrl: imagePath,
            param2: param2,
          );
    if (!saveResponse.isSuccess) {
      state = state.copyWith(busy: false);
      return saveResponse.displayMsg;
    }

    state = state.copyWith(busy: false);
    await refresh();
    return null;
  }

  Future<String> _encodeParam2({
    required String? drawingExport,
    required NoteDrawingKind? drawingKind,
  }) async {
    final kind = drawingKind ?? NoteDrawingKind.strokes;
    var body = drawingExport?.trim() ?? '';
    if (body.isEmpty) {
      if (kind == NoteDrawingKind.strokes && state.strokes.isNotEmpty) {
        body = NoteDrawingCodec.encodeStrokesJson(state.strokes);
      } else {
        return 'string';
      }
    }

    final resolvedInline = switch (kind) {
      NoteDrawingKind.pencilKit => NoteDrawingCodec.encodePkInline(
          body.startsWith(NoteDrawingCodec.pkPrefix)
              ? body.substring(NoteDrawingCodec.pkPrefix.length)
              : body,
        ),
      NoteDrawingKind.strokes => () {
          if (body.startsWith(NoteDrawingCodec.strokesPrefix) ||
              body.startsWith('[')) {
            final jsonText = body.startsWith(NoteDrawingCodec.strokesPrefix)
                ? body.substring(NoteDrawingCodec.strokesPrefix.length)
                : body;
            return '${NoteDrawingCodec.strokesPrefix}$jsonText';
          }
          return NoteDrawingCodec.encodeStrokesInline(state.strokes);
        }(),
      NoteDrawingKind.remotePath => body,
    };

    if (resolvedInline.length <= NoteDrawingCodec.inlineMaxChars) {
      return resolvedInline;
    }

    final filename = kind == NoteDrawingKind.pencilKit
        ? 'note_draw_${DateTime.now().millisecondsSinceEpoch}.pk.txt'
        : 'note_draw_${DateTime.now().millisecondsSinceEpoch}.json.txt';
    final upload = await _repository.uploadNoteImage(
      bytes: Uint8List.fromList(utf8.encode(resolvedInline)),
      filename: filename,
    );
    if (!upload.isSuccess) {
      // 上传失败时仍尽量内联（可能被后端截断，但优于丢失）。
      return resolvedInline;
    }
    final path = parseUploadResult(upload.data).savable;
    return path.isEmpty ? resolvedInline : path;
  }

  int get _writeCategoryId {
    if (state.selectedCategoryId > 0) {
      return state.selectedCategoryId;
    }
    final fallback = state.categories.where((item) => item.id > 0).firstOrNull;
    return fallback?.id ?? 0;
  }

  List<NoteCategoryItem> _parseCategories(dynamic data) {
    final result = <NoteCategoryItem>[];
    if (data is! List) {
      return result;
    }
    for (final raw in data) {
      if (raw is! Map) {
        continue;
      }
      final item = raw.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), value),
      );
      final id = _toInt(item['id']);
      final name = item['name']?.toString().trim() ?? '';
      if (id <= 0 || name.isEmpty) {
        continue;
      }
      result.add(
        NoteCategoryItem(id: id, name: name, count: _toInt(item['count'])),
      );
    }
    return result;
  }

  int _resolveInitialCategoryId(
    List<NoteCategoryItem> categories,
    int currentId,
  ) {
    final positiveCategories = categories.where((item) => item.id > 0).toList();
    if (positiveCategories.isEmpty) {
      return 0;
    }
    if (positiveCategories.any((item) => item.id == currentId)) {
      return currentId;
    }
    return positiveCategories.first.id;
  }

  List<NoteEntry> _parseNotes(dynamic data) {
    if (data is! List) {
      return const <NoteEntry>[];
    }
    final result = <NoteEntry>[];
    for (final item in data) {
      if (item is! Map) {
        continue;
      }
      final map = item is Map<String, dynamic>
          ? item
          : item.map<String, dynamic>(
              (key, value) => MapEntry(key.toString(), value),
            );
      final drawingRaw = map['param2']?.toString() ?? '';
      result.add(
        NoteEntry(
          id: _toInt(map['id']),
          categoryId: _toInt(map['categoryId']),
          title: map['title']?.toString().trim().isNotEmpty == true
              ? map['title'].toString().trim()
              : '未命名笔记',
          imageUrl: map['param1']?.toString() ?? '',
          drawingData: NoteDrawingCodec.isPlaceholder(drawingRaw)
              ? ''
              : drawingRaw,
          createdAt: _parseDate(map['createTime']),
          paperType: NotePaperType.fromValue(map['paperType']),
          isFavorite: _toBool(map['favorite']) || _toBool(map['isFavorite']),
        ),
      );
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  DateTime _parseDate(dynamic value) {
    final raw = value?.toString() ?? '';
    return DateTime.tryParse(raw) ?? DateTime.now();
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final text = value?.toString().toLowerCase() ?? '';
    return text == 'true' || text == '1';
  }
}

enum _StrokeHistoryKind { add, erase }

class _StrokeHistoryOp {
  const _StrokeHistoryOp.add(this.stroke)
      : kind = _StrokeHistoryKind.add,
        removed = const <NoteStroke>[];

  const _StrokeHistoryOp.erase(this.removed)
      : kind = _StrokeHistoryKind.erase,
        stroke = null;

  final _StrokeHistoryKind kind;
  final NoteStroke? stroke;
  final List<NoteStroke> removed;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
