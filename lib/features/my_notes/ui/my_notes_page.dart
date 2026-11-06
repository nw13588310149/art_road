import 'dart:async';

import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/network/media_url.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/anchored_popup_menu.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import '../state/my_notes_controller.dart';
import '../state/my_notes_state.dart';
import '../state/note_drawing_codec.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';
import 'note_drawing_surface.dart';

class MyNotesPage extends ConsumerStatefulWidget {
  const MyNotesPage({super.key});

  @override
  ConsumerState<MyNotesPage> createState() => _MyNotesPageState();
}

class _MyNotesPageState extends ConsumerState<MyNotesPage> {
  final GlobalKey<NoteDrawingSurfaceState> _drawingSurfaceKey =
      GlobalKey<NoteDrawingSurfaceState>();
  List<Offset> _activeStroke = const <Offset>[];
  bool _iosCanUndo = false;
  bool _iosCanRedo = false;
  double _backgroundZoom = 1;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myNotesControllerProvider);
    final controller = ref.read(myNotesControllerProvider.notifier);
    return switch (state.view) {
      MyNotesView.list => _NotesListView(
        state: state,
        onCreate: _handleCreate,
        onAddCategory: _showAddCategoryDialog,
        onCategoryAction: _handleCategoryAction,
        onNoteAction: _handleNoteAction,
        onOpenNote: _openExistingNote,
      ),
      MyNotesView.template => _NoteTemplateView(
        selectedType: state.paperType,
        onBack: _backToList,
        onSelected: (type) {
          ref.read(myNotesControllerProvider.notifier).chooseTemplate(type);
        },
      ),
      MyNotesView.editor => _NoteEditorView(
        drawingSurfaceKey: _drawingSurfaceKey,
        state: state,
        activeStroke: _activeStroke,
        canUndo: noteDrawingUsesPencilKit
            ? _iosCanUndo
            : controller.canUndoFlutter,
        canRedo: noteDrawingUsesPencilKit
            ? _iosCanRedo
            : controller.canRedoFlutter,
        onBack: _backToList,
        onEditTitle: _editDraftTitle,
        onColorSelected: (color) {
          ref.read(myNotesControllerProvider.notifier).setSelectedColor(color);
        },
        onStrokeWidthChanged: (value) {
          ref.read(myNotesControllerProvider.notifier).setStrokeWidth(value);
        },
        onToolModeSelected: (mode) {
          ref.read(myNotesControllerProvider.notifier).setToolMode(mode);
        },
        onUndo: _handleUndo,
        onRedo: _handleRedo,
        onClear: _handleClear,
        onPanStart: _handlePanStart,
        onPanUpdate: _handlePanUpdate,
        onPanEnd: _handlePanEnd,
        onPanCancel: _handlePanCancel,
        onHistoryChanged: (history) {
          if (_iosCanUndo == history.canUndo &&
              _iosCanRedo == history.canRedo) {
            return;
          }
          setState(() {
            _iosCanUndo = history.canUndo;
            _iosCanRedo = history.canRedo;
          });
        },
        backgroundZoom: _backgroundZoom,
        onZoomIn: () => _drawingSurfaceKey.currentState?.zoomBackgroundIn(),
        onZoomOut: () => _drawingSurfaceKey.currentState?.zoomBackgroundOut(),
        onResetZoom: () =>
            _drawingSurfaceKey.currentState?.resetBackgroundZoom(),
        onBackgroundZoomChanged: (zoom) {
          if (_backgroundZoom != zoom) {
            setState(() => _backgroundZoom = zoom);
          }
        },
        onPendingPencilKitConsumed: () {
          ref
              .read(myNotesControllerProvider.notifier)
              .clearPendingPencilKitData();
        },
        onSave: _saveEditorImage,
      ),
    };
  }

  Future<void> _handleCreate() async {
    final controller = ref.read(myNotesControllerProvider.notifier);
    // 先做一次"是否存在可写入分类"的校验，避免让用户白填一次标题：
    // 没有可写分类时直接提示并退出，不弹出输入框。
    final validationError = controller.validateCanCreateNote();
    if (validationError != null) {
      if (mounted) {
        _showMessage(validationError);
      }
      return;
    }
    // 先弹出"新建笔记"标题输入框（按 Figma 设计稿），确认后再带着
    // 标题进入"选择笔记样式"页面。
    final title = await showTextInputDialog(
      context: context,
      title: '新建笔记',
      hintText: '请输入笔记标题',
      maxLength: 30,
    );
    if (!mounted || title == null || title.isEmpty) {
      return;
    }
    final message = controller.beginCreateNote(title: title);
    if (message != null && mounted) {
      _showMessage(message);
    }
  }

  void _backToList() {
    setState(() {
      _activeStroke = const <Offset>[];
      _iosCanUndo = false;
      _iosCanRedo = false;
      _backgroundZoom = 1;
    });
    ref.read(myNotesControllerProvider.notifier).backToList();
  }

  void _openExistingNote(NoteEntry note) {
    setState(() {
      _iosCanUndo = false;
      _iosCanRedo = false;
      _backgroundZoom = 1;
    });
    unawaited(
      ref.read(myNotesControllerProvider.notifier).openExistingNote(note),
    );
  }

  Future<void> _editDraftTitle() async {
    final current = ref.read(myNotesControllerProvider).draftTitle;
    final next = await showTextInputDialog(
      context: context,
      title: '编辑标题',
      hintText: '请输入笔记标题',
      initialValue: current,
      confirmLabel: '确定',
      maxLength: 30,
    );
    if (!mounted || next == null || next.isEmpty || next == current) {
      return;
    }
    ref.read(myNotesControllerProvider.notifier).updateDraftTitle(next);
  }

  Future<void> _showAddCategoryDialog() async {
    final result = await showTextInputDialog(
      context: context,
      title: '新建笔记分类',
      hintText: '请输入笔记分类名称',
      confirmLabel: '确认',
    );
    if (!mounted || result == null) {
      return;
    }
    final message = await ref
        .read(myNotesControllerProvider.notifier)
        .addCategory(result);
    if (message != null && mounted) {
      _showMessage(message);
    }
  }

  /// Left-nav category menu — supports 重命名 + 删除.
  /// 重命名复用 `noteCategorySave`（id > 0 即更新）；删除走 `noteCategoryDelete`。
  Future<void> _handleCategoryAction(
    NoteCategoryItem item,
    _NoteMenuAction action,
  ) async {
    final controller = ref.read(myNotesControllerProvider.notifier);
    switch (action) {
      case _NoteMenuAction.rename:
        final nextName = await showTextInputDialog(
          context: context,
          title: '重命名分类',
          hintText: '请输入新的分类名称',
          initialValue: item.name,
          confirmLabel: '保存',
        );
        if (nextName == null || nextName.isEmpty || nextName == item.name) {
          return;
        }
        final message = await controller.renameCategory(item.id, nextName);
        if (mounted) {
          _showMessage(message ?? '分类名称已更新');
        }
        break;
      case _NoteMenuAction.delete:
        final confirmed = await showConfirmDialog(
          context: context,
          title: '删除分类',
          content: '删除“${item.name}”后，该分类下的笔记也会一并移除。',
          confirmLabel: '删除',
        );
        if (!confirmed || !mounted) {
          return;
        }
        final message = await controller.deleteCategory(item.id);
        if (mounted) {
          _showMessage(message ?? '分类已删除');
        }
        break;
    }
  }

  /// Note card menu — supports 重命名 + 删除.
  Future<void> _handleNoteAction(NoteEntry item, _NoteMenuAction action) async {
    final controller = ref.read(myNotesControllerProvider.notifier);
    switch (action) {
      case _NoteMenuAction.rename:
        final nextTitle = await showTextInputDialog(
          context: context,
          title: '重命名笔记',
          hintText: '请输入新的笔记名称',
          initialValue: item.title,
          confirmLabel: '保存',
        );
        if (nextTitle == null || nextTitle.isEmpty || nextTitle == item.title) {
          return;
        }
        final message = await controller.renameNote(item, nextTitle);
        if (mounted) {
          _showMessage(message ?? '笔记名称已更新');
        }
        break;
      case _NoteMenuAction.delete:
        final confirmed = await showConfirmDialog(
          context: context,
          title: '删除笔记',
          content: '确定删除“${item.title}”吗？此操作不可恢复。',
          confirmLabel: '删除',
        );
        if (!confirmed || !mounted) {
          return;
        }
        final message = await controller.deleteNote(item.id);
        if (mounted) {
          _showMessage(message ?? '笔记已删除');
        }
        break;
    }
  }

  void _handlePanStart(DragStartDetails details) {
    if (noteDrawingUsesPencilKit) {
      return;
    }
    setState(() => _activeStroke = <Offset>[details.localPosition]);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (noteDrawingUsesPencilKit) {
      return;
    }
    setState(() {
      _activeStroke = <Offset>[..._activeStroke, details.localPosition];
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (noteDrawingUsesPencilKit) {
      return;
    }
    if (_activeStroke.length >= 2) {
      ref.read(myNotesControllerProvider.notifier).addStroke(_activeStroke);
    }
    setState(() => _activeStroke = const <Offset>[]);
  }

  /// 多指落下时（≥2 根手指）由画布层主动调用：丢弃此前
  /// 单指开启的半截笔画，把绘制权让给 [InteractiveViewer] 的缩放手势，
  /// 避免 Android 平板上"两指捏合 = 顺手画一道"。
  void _handlePanCancel() {
    if (_activeStroke.isEmpty) {
      return;
    }
    setState(() => _activeStroke = const <Offset>[]);
  }

  Future<void> _handleUndo() async {
    if (noteDrawingUsesPencilKit) {
      await _drawingSurfaceKey.currentState?.undo();
      return;
    }
    ref.read(myNotesControllerProvider.notifier).undoStroke();
  }

  Future<void> _handleRedo() async {
    if (noteDrawingUsesPencilKit) {
      await _drawingSurfaceKey.currentState?.redo();
      return;
    }
    ref.read(myNotesControllerProvider.notifier).redoStroke();
  }

  Future<void> _handleClear() async {
    if (noteDrawingUsesPencilKit) {
      await _drawingSurfaceKey.currentState?.clear();
      setState(() {
        _iosCanUndo = false;
        _iosCanRedo = false;
      });
      return;
    }
    ref.read(myNotesControllerProvider.notifier).clearCanvas();
  }

  Future<void> _saveEditorImage() async {
    try {
      final surface = _drawingSurfaceKey.currentState;
      final bytes = await surface?.capturePng(pixelRatio: 2.2);
      if (bytes == null || bytes.isEmpty) {
        _showMessage('画布还未准备好，请稍后重试');
        return;
      }

      String? drawingExport;
      NoteDrawingKind? drawingKind;
      if (noteDrawingUsesPencilKit) {
        drawingExport = await surface?.exportPencilKitData();
        drawingKind = NoteDrawingKind.pencilKit;
      } else {
        final strokes = ref.read(myNotesControllerProvider).strokes;
        if (strokes.isNotEmpty) {
          drawingExport = NoteDrawingCodec.encodeStrokesJson(strokes);
          drawingKind = NoteDrawingKind.strokes;
        }
      }

      final message = await ref
          .read(myNotesControllerProvider.notifier)
          .saveCurrentNote(
            pngBytes: bytes,
            drawingExport: drawingExport,
            drawingKind: drawingKind,
          );
      if (message != null && message.isNotEmpty && mounted) {
        _showMessage(message);
        return;
      }
      if (mounted) {
        _showMessage('笔记已保存');
        _backToList();
      }
    } catch (_) {
      if (mounted) {
        _showMessage('笔记导出失败，请稍后重试');
      }
    }
  }

  void _showMessage(String message) {
    AppToast.show(context, message);
  }
}

class _NotesListView extends ConsumerWidget {
  const _NotesListView({
    required this.state,
    required this.onCreate,
    required this.onAddCategory,
    required this.onCategoryAction,
    required this.onNoteAction,
    required this.onOpenNote,
  });

  final MyNotesState state;
  final Future<void> Function() onCreate;
  final Future<void> Function() onAddCategory;
  final Future<void> Function(NoteCategoryItem item, _NoteMenuAction action)
  onCategoryAction;
  final Future<void> Function(NoteEntry item, _NoteMenuAction action)
  onNoteAction;
  final ValueChanged<NoteEntry> onOpenNote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    final controller = ref.read(myNotesControllerProvider.notifier);

    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Left nav (matches courseware layout) ──────────────────────
            Container(
              width: ui(180),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(ui(16)),
                ),
                border: Border(
                  right: BorderSide(
                    color: const Color(0xFFF3F2F3),
                    width: ui(1),
                  ),
                ),
              ),
              child: _NotesSidebar(
                state: state,
                onSelectCategory: controller.selectCategory,
                onAddCategory: onAddCategory,
                onCategoryAction: onCategoryAction,
              ),
            ),
            // ── Right content (tabs + grid) ───────────────────────────────
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.horizontal(
                    right: Radius.circular(ui(16)),
                  ),
                ),
                child: _NotesContentArea(
                  state: state,
                  onSelectFilter: controller.selectFilter,
                  onOpenNote: onOpenNote,
                  onCreate: onCreate,
                  onNoteAction: onNoteAction,
                ),
              ),
            ),
          ],
        ),
        if (state.busy)
          const Positioned.fill(
            child: AppLoadingOverlay(),
          ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  Left nav (sidebar)
// ──────────────────────────────────────────────────────────────────────────

class _NotesSidebar extends StatelessWidget {
  const _NotesSidebar({
    required this.state,
    required this.onSelectCategory,
    required this.onAddCategory,
    required this.onCategoryAction,
  });

  final MyNotesState state;
  final ValueChanged<int> onSelectCategory;
  final Future<void> Function() onAddCategory;
  final Future<void> Function(NoteCategoryItem item, _NoteMenuAction action)
  onCategoryAction;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.fromLTRB(ui(8), ui(8), ui(8), ui(10)),
      child: Column(
        children: [
          Expanded(
            // 刚进入页面正在拉取数据时，侧栏保持空白；不展示 loading 转圈，
            // 也不闪一下"暂无分类"占位。加载完成确实无数据时才显示占位。
            child: state.categories.isEmpty
                ? (state.loading
                      ? const SizedBox.shrink()
                      : Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: ui(8)),
                            child: Text(
                              '暂无分类\n点击下方"添加分类"创建',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: ui(12),
                                color: const Color(0xFFB6B5BB),
                                fontFamily: 'PingFang SC',
                                fontWeight: AppFont.w400,
                                height: 1.6,
                              ),
                            ),
                          ),
                        ))
                : ListView.separated(
                    itemCount: state.categories.length,
                    separatorBuilder: (context, index) =>
                        SizedBox(height: ui(8)),
                    itemBuilder: (context, index) {
                      final item = state.categories[index];
                      return _NoteCategoryCard(
                        item: item,
                        selected: item.id == state.selectedCategoryId,
                        onTap: () => onSelectCategory(item.id),
                        onAction: (action) => onCategoryAction(item, action),
                      );
                    },
                  ),
          ),
          SizedBox(height: ui(12)),
          _NotesAddCategoryCard(onTap: onAddCategory),
        ],
      ),
    );
  }
}

class _NoteCategoryCard extends StatefulWidget {
  const _NoteCategoryCard({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onAction,
  });

  final NoteCategoryItem item;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<_NoteMenuAction> onAction;

  @override
  State<_NoteCategoryCard> createState() => _NoteCategoryCardState();
}

class _NoteCategoryCardState extends State<_NoteCategoryCard> {
  final GlobalKey _menuTriggerKey = GlobalKey();

  Future<void> _openActionMenu() async {
    // 默认分类（id == 0，名为"笔记"）不允许重命名 / 删除，因此不弹菜单。
    if (widget.item.id <= 0) {
      return;
    }
    final action = await _showNoteActionMenu(
      context: context,
      triggerKey: _menuTriggerKey,
      includeRename: true,
    );
    if (action != null) {
      widget.onAction(action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final selected = widget.selected;
    final item = widget.item;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Container(
        height: ui(60),
        padding: EdgeInsets.fromLTRB(ui(10), ui(12), ui(8), ui(12)),
        decoration: BoxDecoration(
          // Selected: lavender card #EEEAFF with 8 radius.
          // Non-selected: white card with 16 radius.
          color: selected ? const Color(0xFFEEEAFF) : Colors.white,
          borderRadius: BorderRadius.circular(ui(selected ? 8 : 16)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 36×36 note glyph：未选中走 note/9.png（无填色描线版本），
            // 选中走 note/4.png（彩色实心版本）。两张图都是 self-contained。
            Image.asset(
              selected
                  ? AppAssets.folderCategorySelectedIcon
                  : AppAssets.folderCategoryIdleIcon,
              width: ui(36),
              height: ui(36),
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
            SizedBox(width: ui(10)),
            // Single-line "name（count）" label per spec.
            Expanded(
              child: Text(
                '${item.name}（${item.count}）',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(13),
                  color: const Color(0xFF0B081A),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 12 / 13,
                ),
              ),
            ),
            if (item.id > 0)
              GestureDetector(
                key: _menuTriggerKey,
                behavior: HitTestBehavior.opaque,
                onTap: _openActionMenu,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: ui(2)),
                  child: Image.asset(
                    AppAssets.cloudActionMore,
                    width: ui(24),
                    height: ui(24),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotesAddCategoryCard extends StatelessWidget {
  const _NotesAddCategoryCard({required this.onTap});

  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 与录音系统侧栏「添加分类」保持一致：163×60 胶囊背景，纵向居中排版。
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: ui(60),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ui(8)),
          color: const Color(0xFFF5F6FA),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: ui(18),
              height: ui(18),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFB6B5BB),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_rounded, size: ui(12), color: Colors.white),
            ),
            SizedBox(height: ui(4)),
            Text(
              '添加分类',
              style: TextStyle(
                fontSize: ui(13),
                color: const Color(0xFF0B081A),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 12 / 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  Right content (tabs + grid + FAB)
// ──────────────────────────────────────────────────────────────────────────

class _NotesContentArea extends StatelessWidget {
  const _NotesContentArea({
    required this.state,
    required this.onSelectFilter,
    required this.onOpenNote,
    required this.onCreate,
    required this.onNoteAction,
  });

  final MyNotesState state;
  final ValueChanged<MyNotesFilter> onSelectFilter;
  final ValueChanged<NoteEntry> onOpenNote;
  final Future<void> Function() onCreate;
  final Future<void> Function(NoteEntry item, _NoteMenuAction action)
  onNoteAction;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return PageInitLoadingShell(
      loading: state.loading && state.visibleNotes.isEmpty,
      child: Padding(
        padding: EdgeInsets.fromLTRB(ui(20), ui(18), ui(20), ui(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NotesTabBar(active: state.activeFilter, onChanged: onSelectFilter),
            SizedBox(height: ui(16)),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: state.loading && state.visibleNotes.isEmpty
                        ? const SizedBox.shrink()
                        : state.visibleNotes.isEmpty
                        ? const _EmptyPanel()
                        : GridView.builder(
                          padding: EdgeInsets.only(bottom: ui(64)),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                mainAxisSpacing: ui(20),
                                crossAxisSpacing: ui(16),
                                childAspectRatio: 1.0,
                              ),
                          itemCount: state.visibleNotes.length,
                          itemBuilder: (context, index) {
                            final item = state.visibleNotes[index];
                            return _NoteCard(
                              item: item,
                              onOpen: () => onOpenNote(item),
                              onAction: (action) => onNoteAction(item, action),
                            );
                          },
                        ),
                ),
                Positioned(
                  right: 0,
                  bottom: ui(8),
                  child: _NotesFloatingCreateButton(onTap: onCreate),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Pill-shaped tab bar that replaces the previous title/search/sort/refresh
/// row. Spec: outer #F5F6FA pill (8 radius, 1px outline #F3F2F3, 4px padding,
/// 16px gap), active item white with shadow + 6 radius.
///
class _NotesTabBar extends StatelessWidget {
  const _NotesTabBar({required this.active, required this.onChanged});

  static const List<MyNotesFilter> _visibleFilters = <MyNotesFilter>[
    MyNotesFilter.all,
    MyNotesFilter.recent,
    MyNotesFilter.favorite,
  ];

  final MyNotesFilter active;
  final ValueChanged<MyNotesFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.all(ui(4)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _visibleFilters.length; i++) ...[
            _NotesTabItem(
              label: _visibleFilters[i].label,
              active: _visibleFilters[i] == active,
              onTap: () => onChanged(_visibleFilters[i]),
            ),
            if (i != _visibleFilters.length - 1) SizedBox(width: ui(16)),
          ],
        ],
      ),
    );
  }
}

class _NotesTabItem extends StatelessWidget {
  const _NotesTabItem({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // No AnimatedContainer / Material / InkWell: per spec, the tab switch
    // should not animate and the chip should not show any tap feedback.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: ui(36),
        padding: EdgeInsets.symmetric(horizontal: ui(16)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(ui(active ? 6 : 8)),
          boxShadow: active
              ? <BoxShadow>[
                  BoxShadow(
                    color: const Color(0x59B5B5B5),
                    blurRadius: ui(20),
                    offset: Offset(0, ui(8)),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: ui(14),
            height: 1,
            color: active ? const Color(0xFF0B081A) : const Color(0xFF6D6B75),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
          ),
        ),
      ),
    );
  }
}

class _NotesFloatingCreateButton extends StatelessWidget {
  const _NotesFloatingCreateButton({required this.onTap});

  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: ui(40),
        padding: EdgeInsets.symmetric(horizontal: ui(13), vertical: ui(8)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
          boxShadow: [
            BoxShadow(
              color: const Color(0x59B5B5B5),
              blurRadius: ui(20),
              offset: Offset(0, ui(16)),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 与录音系统「新建文件夹」FAB 保持一致：20×20 图标。
            Image.asset(
              'assets/images/note/3.png',
              width: ui(20),
              height: ui(20),
              fit: BoxFit.contain,
            ),
            SizedBox(width: ui(8)),
            Text(
              '新建笔记',
              style: TextStyle(
                fontSize: ui(16),
                color: const Color(0xFF0B081A),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 12 / 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteTemplateView extends StatefulWidget {
  const _NoteTemplateView({
    required this.selectedType,
    required this.onBack,
    required this.onSelected,
  });

  final NotePaperType selectedType;
  final VoidCallback onBack;
  final ValueChanged<NotePaperType> onSelected;

  @override
  State<_NoteTemplateView> createState() => _NoteTemplateViewState();
}

class _NoteTemplateViewState extends State<_NoteTemplateView> {
  late NotePaperType _pending;

  @override
  void initState() {
    super.initState();
    _pending = widget.selectedType;
  }

  @override
  void didUpdateWidget(covariant _NoteTemplateView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedType != widget.selectedType) {
      _pending = widget.selectedType;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(16)),
      child: Container(
        color: Colors.white,
        child: Stack(
          children: [
            Positioned(
              left: ui(20),
              top: ui(20),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onBack,
                child: Image.asset(
                  'assets/images/note/5.png',
                  width: ui(32),
                  height: ui(32),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: ui(25),
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  '请选择您的笔记样式',
                  style: TextStyle(
                    fontSize: ui(16),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                    color: const Color(0xFF0B081A),
                  ),
                ),
              ),
            ),
            Positioned(
              top: ui(131),
              left: 0,
              right: 0,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TemplatePreviewCard(
                      type: NotePaperType.staff,
                      selected: _pending == NotePaperType.staff,
                      onTap: () =>
                          setState(() => _pending = NotePaperType.staff),
                    ),
                    SizedBox(width: ui(16)),
                    _TemplatePreviewCard(
                      type: NotePaperType.notebook,
                      selected: _pending == NotePaperType.notebook,
                      onTap: () =>
                          setState(() => _pending = NotePaperType.notebook),
                    ),
                    SizedBox(width: ui(16)),
                    _TemplatePreviewCard(
                      type: NotePaperType.blank,
                      selected: _pending == NotePaperType.blank,
                      onTap: () =>
                          setState(() => _pending = NotePaperType.blank),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: ui(614),
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onSelected(_pending),
                  child: Container(
                    width: ui(350),
                    height: ui(52),
                    padding: EdgeInsets.all(ui(10)),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
                      ),
                      borderRadius: BorderRadius.circular(ui(12)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x59AD80FF),
                          blurRadius: ui(20),
                          offset: Offset(0, ui(16)),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '下一步',
                          style: TextStyle(
                            fontSize: ui(16),
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w500,
                            color: Colors.white,
                            height: 28 / 16,
                          ),
                        ),
                        SizedBox(width: ui(4)),
                        Image.asset(
                          'assets/images/note/8.png',
                          width: ui(20),
                          height: ui(20),
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplatePreviewCard extends StatelessWidget {
  const _TemplatePreviewCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final NotePaperType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final asset = selected
        ? 'assets/images/note/6.png'
        : 'assets/images/note/7.png';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: ui(300),
        height: ui(400),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(ui(16)),
                child: Image.asset(asset, fit: BoxFit.fill),
              ),
            ),
            Positioned(
              top: ui(14),
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  type.label,
                  style: TextStyle(
                    fontSize: ui(18),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    color: const Color(0xFF0B081A),
                    height: 24 / 18,
                  ),
                ),
              ),
            ),
            Positioned(
              left: ui(8),
              top: ui(52),
              width: ui(284),
              height: ui(340),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(12)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(ui(12)),
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: NotePaperPainter(type: type),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteEditorView extends StatelessWidget {
  const _NoteEditorView({
    required this.drawingSurfaceKey,
    required this.state,
    required this.activeStroke,
    required this.canUndo,
    required this.canRedo,
    required this.onBack,
    required this.onEditTitle,
    required this.onColorSelected,
    required this.onStrokeWidthChanged,
    required this.onToolModeSelected,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onPanCancel,
    required this.onHistoryChanged,
    required this.backgroundZoom,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
    required this.onBackgroundZoomChanged,
    required this.onPendingPencilKitConsumed,
    required this.onSave,
  });

  final GlobalKey<NoteDrawingSurfaceState> drawingSurfaceKey;
  final MyNotesState state;
  final List<Offset> activeStroke;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onBack;
  final Future<void> Function() onEditTitle;
  final ValueChanged<Color> onColorSelected;
  final ValueChanged<double> onStrokeWidthChanged;
  final ValueChanged<NoteToolMode> onToolModeSelected;
  final Future<void> Function() onUndo;
  final Future<void> Function() onRedo;
  final Future<void> Function() onClear;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;
  final VoidCallback onPanCancel;
  final ValueChanged<NoteDrawingHistory> onHistoryChanged;
  final double backgroundZoom;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;
  final ValueChanged<double> onBackgroundZoomChanged;
  final VoidCallback onPendingPencilKitConsumed;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    final state = this.state;
    final penActive = state.toolMode == NoteToolMode.pen;
    final eraserActive = state.toolMode == NoteToolMode.eraser;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      padding: EdgeInsets.fromLTRB(ui(18), ui(16), ui(18), ui(18)),
      child: Column(
        children: [
          SizedBox(
            height: ui(44),
            child: Row(
              children: [
                // 左右等宽占位，保证标题相对整行居中、保存按钮贴右。
                SizedBox(
                  width: ui(96),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: onBack,
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => onEditTitle(),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            state.draftTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: ui(20),
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF16141F),
                            ),
                          ),
                        ),
                        SizedBox(width: ui(4)),
                        Icon(
                          Icons.edit_outlined,
                          size: ui(16),
                          color: const Color(0xFF8B879A),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: ui(96),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _SecondaryActionButton(
                      label: '保存',
                      icon: Icons.save_outlined,
                      busy: state.busy,
                      onPressed: state.busy ? null : onSave,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: ui(16)),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: NoteDrawingSurface(
                    key: drawingSurfaceKey,
                    paperType: state.paperType,
                    backgroundImage: _buildOptionalRemoteImage(
                      state.editorBackgroundImageUrl,
                      fit: BoxFit.cover,
                    ),
                    strokeColor: state.selectedColor,
                    strokeWidth: state.strokeWidth,
                    toolMode: state.toolMode,
                    strokes: state.strokes,
                    activeStroke: activeStroke,
                    pendingPencilKitData: state.pendingPencilKitData,
                    onPendingPencilKitConsumed: onPendingPencilKitConsumed,
                    onPanStart: onPanStart,
                    onPanUpdate: onPanUpdate,
                    onPanEnd: onPanEnd,
                    onPanCancel: onPanCancel,
                    onHistoryChanged: onHistoryChanged,
                    onBackgroundZoomChanged: onBackgroundZoomChanged,
                    borderRadius: ui(18),
                  ),
                ),
                Positioned(
                  left: ui(0),
                  right: ui(0),
                  bottom: ui(22),
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ui(12),
                        vertical: ui(10),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(ui(16)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x14000000),
                            blurRadius: ui(18),
                            offset: Offset(0, ui(8)),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: canUndo ? () => onUndo() : null,
                              icon: const Icon(Icons.undo_rounded),
                              tooltip: '撤销',
                            ),
                            IconButton(
                              onPressed: canRedo ? () => onRedo() : null,
                              icon: const Icon(Icons.redo_rounded),
                              tooltip: '重做',
                            ),
                            Container(
                              width: 1,
                              height: ui(22),
                              color: const Color(0xFFEAEAF2),
                            ),
                            SizedBox(width: ui(4)),
                            IconButton(
                              onPressed: onZoomOut,
                              icon: const Icon(Icons.remove_rounded),
                              tooltip: '缩小画布',
                            ),
                            TextButton(
                              onPressed: onResetZoom,
                              style: TextButton.styleFrom(
                                minimumSize: Size(ui(54), ui(40)),
                                padding: EdgeInsets.symmetric(
                                  horizontal: ui(4),
                                ),
                                foregroundColor: const Color(0xFF1F1A32),
                              ),
                              child: Text('${(backgroundZoom * 100).round()}%'),
                            ),
                            IconButton(
                              onPressed: onZoomIn,
                              icon: const Icon(Icons.add_rounded),
                              tooltip: '放大画布',
                            ),
                            Container(
                              width: 1,
                              height: ui(22),
                              color: const Color(0xFFEAEAF2),
                            ),
                            SizedBox(width: ui(4)),
                            _ToolToggleButton(
                              icon: Icons.edit_rounded,
                              active: penActive,
                              onTap: () => onToolModeSelected(NoteToolMode.pen),
                            ),
                            _ToolToggleButton(
                              icon: Icons.auto_fix_off_outlined,
                              active: eraserActive,
                              onTap: () =>
                                  onToolModeSelected(NoteToolMode.eraser),
                            ),
                            SizedBox(width: ui(8)),
                            Container(
                              width: 1,
                              height: ui(22),
                              color: const Color(0xFFEAEAF2),
                            ),
                            SizedBox(width: ui(10)),
                            ..._editorColors.map((color) {
                              final active = color == state.selectedColor &&
                                  penActive;
                              return GestureDetector(
                                onTap: () => onColorSelected(color),
                                child: Container(
                                  width: ui(22),
                                  height: ui(22),
                                  margin: EdgeInsets.only(right: ui(10)),
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: active
                                          ? const Color(0xFF16141F)
                                          : Colors.white,
                                      width: active ? 2 : 1,
                                    ),
                                  ),
                                ),
                              );
                            }),
                            SizedBox(width: ui(4)),
                            Container(
                              width: ui(44),
                              height: ui(34),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF6F7FB),
                                borderRadius: BorderRadius.circular(ui(10)),
                              ),
                              child: Text(
                                '${state.strokeWidth.round()}',
                                style: TextStyle(
                                  fontSize: ui(14),
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF2A2A2A),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: ui(110),
                              child: Slider(
                                value: state.strokeWidth,
                                min: 2,
                                max: 32,
                                activeColor: const Color(0xFF8B5CFF),
                                inactiveColor: const Color(0xFFE8EAF4),
                                onChanged: onStrokeWidthChanged,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: ui(22),
                              color: const Color(0xFFEAEAF2),
                            ),
                            SizedBox(width: ui(8)),
                            TextButton.icon(
                              onPressed: () => onClear(),
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('清空画布'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF1F1A32),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolToggleButton extends StatelessWidget {
  const _ToolToggleButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ui(2)),
      child: Material(
        color: active ? const Color(0xFFF1ECFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(ui(10)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ui(10)),
          child: Container(
            width: ui(36),
            height: ui(36),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ui(10)),
              border: Border.all(
                color: active
                    ? const Color(0xFF8B5CFF)
                    : const Color(0xFFE7EAF4),
              ),
            ),
            child: Icon(
              icon,
              size: ui(18),
              color: active
                  ? const Color(0xFF8B5CFF)
                  : const Color(0xFF1F1A32),
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  Note card — purple gradient header + lined paper + folded-corner cover.
//  Layout maps the design CSS (170×170) to scaled `ui()` units. Sizes are
//  expressed as ratios of the card's actual width so the whole composition
//  re-flows at any grid extent.
// ──────────────────────────────────────────────────────────────────────────

class _NoteCard extends StatefulWidget {
  const _NoteCard({
    required this.item,
    required this.onOpen,
    required this.onAction,
  });

  final NoteEntry item;
  final VoidCallback onOpen;
  final ValueChanged<_NoteMenuAction> onAction;

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  final GlobalKey _menuTriggerKey = GlobalKey();

  Future<void> _openActionMenu() async {
    final action = await _showNoteActionMenu(
      context: context,
      triggerKey: _menuTriggerKey,
      includeRename: true,
    );
    if (action != null) {
      widget.onAction(action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    final item = widget.item;
    return GestureDetector(
      onTap: widget.onOpen,
      behavior: HitTestBehavior.opaque,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 卡片以 170×170 设计稿为基准，所有 design 值按当前宽度等比缩放。
          final w = constraints.maxWidth;
          double k(double design) => design / 170 * w;

          // 整张卡片的视觉（圆角、紫色顶部、横线、折角、阴影）都内置在
          // bg.png 里；这里不再叠真实笔记预览图、灰底、条纹、紫渐变条。
          // 不再使用 ClipRRect 以保留 bg 自身的圆角阴影。
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/sound/bg.png',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              // 标题
              Positioned(
                left: k(14),
                top: k(15),
                right: k(40),
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: const Color(0xFF0B081A),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                  ),
                ),
              ),
              // ⋯ 菜单触发器（右上角）— note/1.png
              Positioned(
                right: k(8),
                top: k(8),
                child: GestureDetector(
                  key: _menuTriggerKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: _openActionMenu,
                  child: Padding(
                    padding: EdgeInsets.all(k(3)),
                    child: Image.asset(
                      'assets/images/note/1.png',
                      width: k(20),
                      height: k(20),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              // 黄色日期图标（note/2.png）
              Positioned(
                left: k(13),
                top: k(132),
                child: Image.asset(
                  'assets/images/note/2.png',
                  width: k(20),
                  height: k(18),
                  fit: BoxFit.contain,
                ),
              ),
              // 日期文本
              Positioned(
                left: k(40),
                top: k(133),
                child: Text(
                  item.dateLabel.replaceAll('-', '.'),
                  style: TextStyle(
                    fontSize: ui(12),
                    color: const Color(0xFFA59DB4),
                    fontFamily: 'Barlow',
                    fontWeight: FontWeight.w500,
                    height: 16 / 12,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//  Action menu (rename / delete) — mirrors the courseware menu visuals.
// ──────────────────────────────────────────────────────────────────────────

enum _NoteMenuAction { rename, delete }

/// Pops up a menu anchored to [triggerKey]'s widget. When [includeRename]
/// is false, only a single "删除" row is shown (used by the left-nav category
/// list since the backend has no rename endpoint for note categories).
Future<_NoteMenuAction?> _showNoteActionMenu({
  required BuildContext context,
  required GlobalKey triggerKey,
  required bool includeRename,
}) {
  final scale = DashboardScaleScope.of(context);
  final menuWidth = scale.ui(142);
  // Approximate height: 8 + 36*(1 or 2) + (2+1+3) divider + 8.
  final approxMenuHeight = scale.ui(includeRename ? 100 : 56);

  return showAnchoredPopupMenu<_NoteMenuAction>(
    context: context,
    triggerKey: triggerKey,
    menuWidth: menuWidth,
    approxMenuHeight: approxMenuHeight,
    builder: (dialogContext, _) => _NoteActionMenuPanel(
      includeRename: includeRename,
      onSelected: (action) => Navigator.of(dialogContext).pop(action),
    ),
  );
}

class _NoteActionMenuPanel extends StatelessWidget {
  const _NoteActionMenuPanel({
    required this.includeRename,
    required this.onSelected,
  });

  final bool includeRename;
  final ValueChanged<_NoteMenuAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(142),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1.11)),
        boxShadow: [
          BoxShadow(color: const Color(0x050B081A), blurRadius: ui(1)),
          BoxShadow(
            color: const Color(0x0F0B081A),
            blurRadius: ui(40),
            offset: Offset(0, ui(12)),
          ),
          BoxShadow(
            color: const Color(0x050B081A),
            blurRadius: ui(24),
            offset: Offset(0, ui(12)),
            spreadRadius: ui(-16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: ui(8)),
          if (includeRename) ...[
            _NoteActionMenuRow(
              label: '重命名',
              icon: AppAssets.coursewareActionRename,
              onTap: () => onSelected(_NoteMenuAction.rename),
            ),
            SizedBox(height: ui(2)),
            Container(
              margin: EdgeInsets.symmetric(horizontal: ui(8)),
              height: ui(1),
              color: const Color(0xFFF3F4F6),
            ),
            SizedBox(height: ui(3)),
          ],
          _NoteActionMenuRow(
            label: '删除',
            icon: AppAssets.coursewareActionDelete,
            danger: true,
            onTap: () => onSelected(_NoteMenuAction.delete),
          ),
          SizedBox(height: ui(8)),
        ],
      ),
    );
  }
}

class _NoteActionMenuRow extends StatelessWidget {
  const _NoteActionMenuRow({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final String icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: ui(36),
        child: Row(
          children: [
            SizedBox(width: ui(14)),
            Image.asset(
              icon,
              width: ui(20),
              height: ui(20),
              fit: BoxFit.contain,
            ),
            SizedBox(width: ui(10)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(13),
                color: danger
                    ? const Color(0xFFFF323C)
                    : const Color(0xFF0B081A),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 20 / 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty-state placeholder shown when the active category has no notes.
/// Per spec: a 300×300 illustration (`assets/images/404/kj.png`) + the
/// single line "暂无笔记". No description text, no inline CTA — users
/// rely on the floating "新建笔记" FAB at the bottom-right to create one.
class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/404/kj.png',
            width: ui(200),
            height: ui(200),
            fit: BoxFit.contain,
          ),
          SizedBox(height: ui(0)),
          Text(
            '暂无笔记',
            style: TextStyle(
              fontSize: ui(16),
              color: const Color(0xFF8A91A5),
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildOptionalRemoteImage(String? rawUrl, {BoxFit fit = BoxFit.cover}) {
  final resolvedUrl = _resolveRemoteUrl(rawUrl);
  if (resolvedUrl == null) {
    return const SizedBox.shrink();
  }
  return Image.network(
    resolvedUrl,
    fit: fit,
    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    loadingBuilder: (context, child, loadingProgress) => child,
  );
}

String? _resolveRemoteUrl(String? rawUrl) {
  final value = rawUrl?.trim() ?? '';
  if (value.isEmpty || value.toLowerCase() == 'string') {
    return null;
  }
  final resolved = MediaUrl.resolve(value);
  return resolved.isEmpty ? null : resolved;
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(12)),
      child: Container(
        width: ui(40),
        height: ui(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: const Color(0xFFE7EAF4)),
        ),
        child: Icon(icon, size: ui(22), color: const Color(0xFF19152A)),
      ),
    );
  }
}

/// 次操作按钮（白底带描边，例如笔记详情右上角的"保存"）。
class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final foreground = onPressed == null
        ? const Color(0xFFB9BCCB)
        : const Color(0xFF1B1730);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(ui(12)),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(ui(12)),
        child: Container(
          height: ui(40),
          padding: EdgeInsets.symmetric(horizontal: ui(16)),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ui(12)),
            border: Border.all(color: const Color(0xFFE6EAF5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const AppLoadingIndicator()
              else
                Icon(icon, size: ui(18), color: foreground),
              SizedBox(width: ui(6)),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  fontSize: ui(14),
                  fontWeight: FontWeight.w500,
                  color: foreground,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const List<Color> _editorColors = <Color>[
  Color(0xFF2A2A2A),
  Color(0xFFFF5A36),
  Color(0xFFFFA040),
  Color(0xFF5CCB6A),
  Color(0xFF4B9EF8),
  Color(0xFF8B5CFF),
];
