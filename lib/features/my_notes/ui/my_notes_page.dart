import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/network/media_url.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/app_asset_graphic.dart';
import '../../../core/widgets/app_loading_indicator.dart'
    show AppLoadingOverlay;
import '../state/my_notes_controller.dart';
import '../state/my_notes_state.dart';
import '../state/note_drawing_codec.dart';
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
    // 没有可写入的分类时直接提示，不让用户白填一次标题。
    final validationError = controller.validateCanCreateNote();
    if (validationError != null) {
      if (mounted) {
        _showMessage(validationError);
      }
      return;
    }
    final title = await _showNameDialog(
      context,
      title: '新建笔记',
      hint: '请输入笔记标题',
      confirmLabel: '下一步',
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
    final next = await _showNameDialog(
      context,
      title: '修改标题',
      hint: '请输入笔记标题',
      initial: current,
      maxLength: 30,
    );
    if (!mounted || next == null || next.isEmpty || next == current) {
      return;
    }
    ref.read(myNotesControllerProvider.notifier).updateDraftTitle(next);
  }

  Future<void> _showAddCategoryDialog() async {
    final result = await _showNameDialog(
      context,
      title: '新建分类',
      hint: '如素描讲评、色彩笔记',
      maxLength: 20,
    );
    if (!mounted || result == null || result.isEmpty) {
      return;
    }
    final message = await ref
        .read(myNotesControllerProvider.notifier)
        .addCategory(result);
    if (message != null && mounted) {
      _showMessage(message);
    }
  }

  /// 左侧分类菜单：重命名复用 `noteCategorySave`（id > 0 即更新），删除走 `noteCategoryDelete`。
  Future<void> _handleCategoryAction(
    NoteCategoryItem item,
    _NoteMenuAction action,
  ) async {
    final controller = ref.read(myNotesControllerProvider.notifier);
    switch (action) {
      case _NoteMenuAction.rename:
        final nextName = await _showNameDialog(
          context,
          title: '重命名分类',
          hint: '请输入新的分类名称',
          initial: item.name,
          maxLength: 20,
        );
        if (nextName == null || nextName.isEmpty || nextName == item.name) {
          return;
        }
        final message = await controller.renameCategory(item.id, nextName);
        if (mounted) {
          _showMessage(message ?? '分类名称已更新');
        }
      case _NoteMenuAction.delete:
        final confirmed = await showAppConfirm(
          context: context,
          title: '删除分类',
          message: '删除「${item.name}」后，该分类下的笔记也会一并删除，且不可恢复。',
          danger: true,
        );
        if (!confirmed || !mounted) {
          return;
        }
        final message = await controller.deleteCategory(item.id);
        if (mounted) {
          _showMessage(message ?? '分类已删除');
        }
    }
  }

  Future<void> _handleNoteAction(NoteEntry item, _NoteMenuAction action) async {
    final controller = ref.read(myNotesControllerProvider.notifier);
    switch (action) {
      case _NoteMenuAction.rename:
        final nextTitle = await _showNameDialog(
          context,
          title: '重命名笔记',
          hint: '请输入新的笔记名称',
          initial: item.title,
          maxLength: 30,
        );
        if (nextTitle == null || nextTitle.isEmpty || nextTitle == item.title) {
          return;
        }
        final message = await controller.renameNote(item, nextTitle);
        if (mounted) {
          _showMessage(message ?? '笔记名称已更新');
        }
      case _NoteMenuAction.delete:
        final confirmed = await showAppConfirm(
          context: context,
          title: '删除笔记',
          message: '「${item.title}」删除后不可恢复。',
          danger: true,
        );
        if (!confirmed || !mounted) {
          return;
        }
        final message = await controller.deleteNote(item.id);
        if (mounted) {
          _showMessage(message ?? '笔记已删除');
        }
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

  /// 多指落下时由画布层调用：丢弃单指开启的半截笔画，把手势让给缩放。
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
    final confirmed = await showAppConfirm(
      context: context,
      title: '清空画布',
      message: '画布上的笔迹会全部清除，清空后可以撤销。',
      danger: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
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
        AppToast.showSuccess(context, '笔记已保存');
        _backToList();
      }
    } catch (_) {
      if (mounted) {
        AppToast.showError(context, '笔记保存失败，请稍后重试');
      }
    }
  }

  void _showMessage(String message) {
    AppToast.show(context, message);
  }
}

/// 名称输入弹窗（新建 / 重命名笔记与分类、修改标题）。
Future<String?> _showNameDialog(
  BuildContext context, {
  required String title,
  required String hint,
  String initial = '',
  String confirmLabel = '保存',
  int maxLength = 30,
}) {
  return showAppDialog<String>(
    context: context,
    builder: (_) => _NameDialog(
      title: title,
      hint: hint,
      initial: initial,
      confirmLabel: confirmLabel,
      maxLength: maxLength,
    ),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.hint,
    required this.initial,
    required this.confirmLabel,
    required this.maxLength,
  });

  final String title;
  final String hint;
  final String initial;
  final String confirmLabel;
  final int maxLength;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initial,
  );
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _ctrl.text.trim();
    if (value.isEmpty) {
      setState(() => _error = '名称不能为空');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.title,
      actions: [
        AppButton(
          label: '取消',
          variant: AppButtonVariant.secondary,
          onTap: () => Navigator.of(context).pop(),
        ),
        AppButton(label: widget.confirmLabel, onTap: _submit),
      ],
      child: AppInputField(
        controller: _ctrl,
        hint: widget.hint,
        maxLength: widget.maxLength,
        errorText: _error,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onChanged: (_) {
          if (_error != null) {
            setState(() => _error = null);
          }
        },
        onSubmitted: (_) => _submit(),
      ),
    );
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
    final controller = ref.read(myNotesControllerProvider.notifier);
    return Stack(
      children: [
        AppSplitPanel(
          sidebar: _NotesSidebar(
            state: state,
            onSelectCategory: controller.selectCategory,
            onAddCategory: onAddCategory,
            onCategoryAction: onCategoryAction,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.s4, 2, AppSpace.s4, 0),
            child: _NotesContentArea(
              state: state,
              onSelectFilter: controller.selectFilter,
              onOpenNote: onOpenNote,
              onCreate: onCreate,
              onNoteAction: onNoteAction,
              onRetry: controller.refresh,
            ),
          ),
        ),
        if (state.busy) const Positioned.fill(child: AppLoadingOverlay()),
      ],
    );
  }
}

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
    final Widget list;
    if (state.categories.isEmpty) {
      list = state.loading
          ? const Padding(
              padding: EdgeInsets.all(AppSpace.s8),
              child: AppSkeletonText(lines: 4, lineHeight: 36),
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s8),
                child: Text(
                  '还没有分类\n点击下方「新建分类」',
                  style: AppText.caption12,
                  textAlign: TextAlign.center,
                ),
              ),
            );
    } else {
      list = ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: state.categories.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s4),
        itemBuilder: (context, index) {
          final item = state.categories[index];
          return _NoteCategoryRow(
            item: item,
            selected: item.id == state.selectedCategoryId,
            onTap: () => onSelectCategory(item.id),
            onAction: (action) => onCategoryAction(item, action),
          );
        },
      );
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: list),
          const SizedBox(height: AppSpace.s8),
          AppAddCategoryButton(onTap: onAddCategory),
        ],
      ),
    );
  }
}

class _NoteCategoryRow extends StatelessWidget {
  const _NoteCategoryRow({
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
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      selected: selected,
      child: Container(
        height: 60,
        padding: const EdgeInsets.only(left: AppSpace.s8, right: AppSpace.s4),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandWash : null,
          borderRadius: AppRadius.br8,
        ),
        child: Row(
          children: [
            AppAssetGraphic(
              selected
                  ? AppAssets.cloudCategorySelected
                  : AppAssets.cloudCategoryIdle,
              width: 36,
              height: 36,
            ),
            const SizedBox(width: AppSpace.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body14Strong.copyWith(
                      color: selected ? AppColors.brandDeep : AppColors.ink,
                    ),
                  ),
                  Text('${item.count} 篇', style: AppText.caption12),
                ],
              ),
            ),
            // 默认分类（id <= 0）不允许重命名 / 删除。
            if (item.id > 0)
              Builder(
                builder: (anchor) => AppIconButton.asset(
                  asset: AppAssets.cloudActionMore,
                  assetSize: 20,
                  semanticLabel: '分类操作',
                  size: AppButtonSize.sm,
                  filled: false,
                  onTap: () async {
                    final action = await _showNoteMenu(anchor);
                    if (action != null) {
                      onAction(action);
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotesContentArea extends StatelessWidget {
  const _NotesContentArea({
    required this.state,
    required this.onSelectFilter,
    required this.onOpenNote,
    required this.onCreate,
    required this.onNoteAction,
    required this.onRetry,
  });

  static const List<MyNotesFilter> _visibleFilters = <MyNotesFilter>[
    MyNotesFilter.all,
    MyNotesFilter.recent,
    MyNotesFilter.favorite,
  ];

  final MyNotesState state;
  final ValueChanged<MyNotesFilter> onSelectFilter;
  final ValueChanged<NoteEntry> onOpenNote;
  final Future<void> Function() onCreate;
  final Future<void> Function(NoteEntry item, _NoteMenuAction action)
  onNoteAction;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final notes = state.visibleNotes;
    final Widget body;
    if (state.loading && notes.isEmpty) {
      body = const _NotesGridSkeleton();
    } else if (notes.isEmpty && state.errorMessage != null) {
      body = AppErrorState(
        title: '笔记加载失败',
        description: state.errorMessage!.isEmpty
            ? '请检查网络连接后重试'
            : state.errorMessage!,
        onRetry: onRetry,
      );
    } else if (notes.isEmpty && state.activeFilter == MyNotesFilter.favorite) {
      body = const AppEmptyState(
        illustration: AppAssets.emptyNotesPlaceholder,
        title: '还没有收藏的笔记',
        description: '收藏的笔记会集中显示在这里，方便考前复习',
      );
    } else if (notes.isEmpty) {
      body = AppEmptyState(
        illustration: AppAssets.emptyNotesPlaceholder,
        title: '这个分类还没有笔记',
        description: '用手写笔记记录老师讲评的要点、构图小稿和改进方法',
        actionLabel: '新建笔记',
        onAction: onCreate,
      );
    } else {
      body = LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 700
              ? 4
              : (constraints.maxWidth >= 520 ? 3 : 2);
          return GridView.builder(
            padding: const EdgeInsets.only(bottom: AppSpace.s8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: AppSpace.s16,
              crossAxisSpacing: AppSpace.s16,
              childAspectRatio: 1,
            ),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final item = notes[index];
              return _NoteCard(
                item: item,
                onOpen: () => onOpenNote(item),
                onAction: (action) => onNoteAction(item, action),
              );
            },
          );
        },
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: AppSegmented<MyNotesFilter>(
            neutral: true,
            segments: [
              for (final filter in _visibleFilters)
                AppSegment(value: filter, label: filter.label),
            ],
            value: state.activeFilter,
            onChanged: onSelectFilter,
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        Expanded(child: body),
        Align(
          alignment: Alignment.centerRight,
          child: AppButton(
            label: '新建笔记',
            iconAsset: AppAssets.noteCreate,
            variant: AppButtonVariant.floating,
            onTap: onCreate,
          ),
        ),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.item,
    required this.onOpen,
    required this.onAction,
  });

  final NoteEntry item;
  final VoidCallback onOpen;
  final ValueChanged<_NoteMenuAction> onAction;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AppPressable(
          onTap: onOpen,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const AppAssetGraphic(AppAssets.noteCard, fit: BoxFit.fill),
              Positioned(
                top: AppSpace.s16,
                left: AppSpace.s16,
                right: 48,
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body14Strong,
                ),
              ),
              Positioned(
                left: AppSpace.s16,
                right: AppSpace.s16,
                bottom: AppSpace.s24,
                child: Row(
                  children: [
                    if (item.isFavorite) ...[
                      Semantics(
                        label: '已收藏',
                        child: const AppAssetGraphic(
                          AppAssets.noteStar,
                          width: 18,
                          height: 18,
                        ),
                      ),
                      const SizedBox(width: AppSpace.s8),
                    ],
                    Flexible(
                      child: Text(
                        item.dateLabel.replaceAll('-', '.'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: AppSpace.s4,
          right: AppSpace.s4,
          child: Builder(
            builder: (anchor) => AppIconButton.asset(
              asset: AppAssets.noteMore,
              assetSize: 20,
              semanticLabel: '笔记操作',
              size: AppButtonSize.sm,
              filled: false,
              onTap: () async {
                final action = await _showNoteMenu(anchor);
                if (action != null) {
                  onAction(action);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _NotesGridSkeleton extends StatelessWidget {
  const _NotesGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppSpace.s16,
        crossAxisSpacing: AppSpace.s16,
        childAspectRatio: 1,
      ),
      itemCount: 4,
      itemBuilder: (_, _) => const AppCard(
        padding: EdgeInsets.all(AppSpace.s12),
        child: Column(
          children: [
            Expanded(child: AppSkeleton(radius: AppRadius.control)),
            SizedBox(height: AppSpace.s8),
            AppSkeletonText(lines: 2),
          ],
        ),
      ),
    );
  }
}

enum _NoteMenuAction { rename, delete }

Future<_NoteMenuAction?> _showNoteMenu(BuildContext anchor) {
  return showAppMenu<_NoteMenuAction>(
    context: anchor,
    width: 144,
    items: const [
      AppMenuItem(
        value: _NoteMenuAction.rename,
        label: '重命名',
        iconAsset: AppAssets.coursewareActionRename,
      ),
      AppMenuItem(
        value: _NoteMenuAction.delete,
        label: '删除',
        iconAsset: AppAssets.coursewareActionDelete,
        danger: true,
      ),
    ],
  );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(
          title: '选择笔记样式',
          subtitle: '网格纸适合推敲比例与构图，笔记本适合文字要点',
          onBack: widget.onBack,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              AppSpace.s16,
              AppSpace.page,
              AppSpace.s24,
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpace.s24,
              runSpacing: AppSpace.s24,
              children: [
                for (final type in const [
                  NotePaperType.grid,
                  NotePaperType.notebook,
                  NotePaperType.blank,
                ])
                  _TemplatePreviewCard(
                    type: type,
                    selected: _pending == type,
                    onTap: () => setState(() => _pending = type),
                  ),
              ],
            ),
          ),
        ),
        Align(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              AppSpace.s12,
              AppSpace.page,
              AppSpace.s24,
            ),
            child: SizedBox(
              width: 350,
              child: AppButton(
                label: '下一步',
                expand: true,
                onTap: () => widget.onSelected(_pending),
              ),
            ),
          ),
        ),
      ],
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
    return AppPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: type.label,
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(AppSpace.s12),
        decoration: BoxDecoration(
          borderRadius: AppRadius.br12,
          image: DecorationImage(
            image: AssetImage(
              selected
                  ? AppAssets.noteTemplateSelected
                  : AppAssets.noteTemplateIdle,
            ),
            fit: BoxFit.fill,
          ),
        ),
        child: Column(
          children: [
            Text(type.label, style: AppText.title16),
            const SizedBox(height: AppSpace.s12),
            SizedBox(
              height: 300,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.br8,
                  border: Border.all(color: AppColors.lineSoft),
                ),
                child: ClipRRect(
                  borderRadius: AppRadius.br8,
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
    final state = this.state;
    final penActive = state.toolMode == NoteToolMode.pen;
    final eraserActive = state.toolMode == NoteToolMode.eraser;
    Widget divider() => Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
      color: AppColors.line,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            AppSpace.s16,
            AppSpace.page,
            AppSpace.s12,
          ),
          child: Row(
            children: [
              AppIconButton.back(onTap: onBack),
              const SizedBox(width: AppSpace.s12),
              Flexible(
                child: AppPressable(
                  onTap: () => onEditTitle(),
                  semanticLabel: '修改标题',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          state.draftTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.title20,
                        ),
                      ),
                      const SizedBox(width: AppSpace.s4),
                      const AppAssetGraphic(
                        AppAssets.homeRename,
                        width: 16,
                        height: 16,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              AppButton(
                label: '保存',
                icon: Icons.save_outlined,
                size: AppButtonSize.sm,
                loading: state.busy,
                onTap: onSave,
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              0,
              AppSpace.page,
              AppSpace.s24,
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: NoteDrawingSurface(
                    key: drawingSurfaceKey,
                    paperType: state.paperType,
                    backgroundImage: _buildOptionalRemoteImage(
                      state.editorBackgroundImageUrl,
                      fit: state.editorBackgroundIsBase
                          ? BoxFit.contain
                          : BoxFit.cover,
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
                    borderRadius: AppRadius.panel,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: AppSpace.s20,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s8,
                        vertical: AppSpace.s4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.br12,
                        border: Border.all(color: AppColors.lineSoft),
                        boxShadow: AppShadow.popover,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppIconButton(
                              icon: Icons.undo_rounded,
                              semanticLabel: '撤销',
                              filled: false,
                              onTap: canUndo ? () => onUndo() : null,
                            ),
                            AppIconButton(
                              icon: Icons.redo_rounded,
                              semanticLabel: '重做',
                              filled: false,
                              onTap: canRedo ? () => onRedo() : null,
                            ),
                            divider(),
                            AppIconButton(
                              icon: Icons.remove_rounded,
                              semanticLabel: '缩小画布',
                              filled: false,
                              onTap: onZoomOut,
                            ),
                            AppPressable(
                              onTap: onResetZoom,
                              semanticLabel: '恢复原始大小',
                              child: SizedBox(
                                width: 52,
                                child: Text(
                                  '${(backgroundZoom * 100).round()}%',
                                  textAlign: TextAlign.center,
                                  style: AppText.number(size: 14),
                                ),
                              ),
                            ),
                            AppIconButton(
                              icon: Icons.add_rounded,
                              semanticLabel: '放大画布',
                              filled: false,
                              onTap: onZoomIn,
                            ),
                            divider(),
                            _ToolToggleButton(
                              icon: Icons.edit_rounded,
                              label: '画笔',
                              active: penActive,
                              onTap: () => onToolModeSelected(NoteToolMode.pen),
                            ),
                            _ToolToggleButton(
                              icon: Icons.auto_fix_off_outlined,
                              label: '橡皮',
                              active: eraserActive,
                              onTap: () =>
                                  onToolModeSelected(NoteToolMode.eraser),
                            ),
                            divider(),
                            for (final color in _editorColors)
                              AppPressable(
                                onTap: () => onColorSelected(color),
                                selected:
                                    color == state.selectedColor && penActive,
                                semanticLabel: '笔迹颜色',
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          color == state.selectedColor &&
                                              penActive
                                          ? AppColors.ink
                                          : AppColors.surface,
                                      width:
                                          color == state.selectedColor &&
                                              penActive
                                          ? 2
                                          : 1,
                                    ),
                                  ),
                                ),
                              ),
                            divider(),
                            Container(
                              width: 40,
                              height: AppSize.controlSm,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                borderRadius: AppRadius.br8,
                              ),
                              child: Text(
                                '${state.strokeWidth.round()}',
                                style: AppText.number(size: 14),
                              ),
                            ),
                            SizedBox(
                              width: 110,
                              child: Slider(
                                value: state.strokeWidth,
                                min: 2,
                                max: 32,
                                activeColor: AppColors.brand,
                                inactiveColor: AppColors.line,
                                onChanged: onStrokeWidthChanged,
                              ),
                            ),
                            divider(),
                            AppButton(
                              label: '清空画布',
                              icon: Icons.delete_outline_rounded,
                              variant: AppButtonVariant.text,
                              size: AppButtonSize.sm,
                              onTap: () => onClear(),
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
        ),
      ],
    );
  }
}

class _ToolToggleButton extends StatelessWidget {
  const _ToolToggleButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: AppPressable(
        onTap: onTap,
        selected: active,
        semanticLabel: label,
        child: Container(
          width: AppSize.iconButtonSm,
          height: AppSize.iconButtonSm,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.brandWash : null,
            borderRadius: AppRadius.br8,
            border: Border.all(
              color: active ? AppColors.brand : AppColors.line,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: active ? AppColors.brand : AppColors.ink,
          ),
        ),
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

/// 笔迹颜色（画面内容色，不是界面色）。
const List<Color> _editorColors = <Color>[
  Color(0xFF2A2A2A),
  Color(0xFFFF5A36),
  Color(0xFFFFA040),
  Color(0xFF5CCB6A),
  Color(0xFF4B9EF8),
  Color(0xFF8B5CFF),
];
