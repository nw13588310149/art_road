import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:the_road_of_art_flutter/core/widgets/app_loading_indicator.dart';
import 'package:the_road_of_art_flutter/core/widgets/app_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/app_asset_graphic.dart';
import '../../../core/widgets/app_refresh_indicator.dart';
import '../../../core/widgets/class_share_drawer.dart';
import '../../../core/widgets/cloud_folder_card_artwork.dart';
import '../../../core/widgets/image_gallery_viewer.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import '../../smart_campus/navigation/group_chat_return.dart';
import '../state/cloud_drive_controller.dart';
import '../state/cloud_drive_state.dart';
import 'courseware_file_picker.dart';
import 'courseware_inline_preview.dart';
import 'package:the_road_of_art_flutter/core/theme/app_font.dart';
import 'package:the_road_of_art_flutter/core/theme/app_theme.dart';

class MyCloudDrivePage extends ConsumerStatefulWidget {
  const MyCloudDrivePage({super.key});

  @override
  ConsumerState<MyCloudDrivePage> createState() => _MyCloudDrivePageState();
}

class _MyCloudDrivePageState extends ConsumerState<MyCloudDrivePage> {
  late final TextEditingController _searchController;
  String _keyword = '';
  bool _consumedRouteArgs = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_consumedRouteArgs) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) return;
    final raw = args['previewItem'];
    if (raw is! Map) return;
    _consumedRouteArgs = true;
    // 延迟到首帧渲染完成后再触发预览，避免在 build 期间触发 setState。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final item = CloudFileItem(
        id: int.tryParse(raw['id']?.toString() ?? '') ?? 0,
        title: raw['title']?.toString() ?? '',
        type: CloudFileType.fromValue(raw['typeValue']),
        audioUrl: raw['audioUrl']?.toString() ?? '',
        imageUrls: (raw['imageUrls'] as List?)?.cast<String>() ?? const [],
      );
      if (item.id > 0 ||
          item.audioUrl.isNotEmpty ||
          item.imageUrls.isNotEmpty) {
        ref.read(cloudDriveControllerProvider.notifier).openPreview(item);
      }
    });
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handlePreviewClose() {
    if (GroupChatReturnNavigator.isActive(context)) {
      ref.read(cloudDriveControllerProvider.notifier).closePreview();
      GroupChatReturnNavigator.pop(context, ref: ref);
      return;
    }
    ref.read(cloudDriveControllerProvider.notifier).closePreview();
  }

  void _handleSearchChanged() {
    final value = _searchController.text.trim();
    if (value == _keyword) {
      return;
    }
    setState(() {
      _keyword = value;
    });
  }

  void _clearSearch() {
    _searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cloudDriveControllerProvider);
    final controller = ref.read(cloudDriveControllerProvider.notifier);
    final previewing = state.previewingFile;
    final Widget content;
    if (previewing != null) {
      content = _CoursewarePreviewPage(
        state: state,
        controller: controller,
        onClose: _handlePreviewClose,
        onRename: () => _handleFileAction(previewing, _CloudFileAction.rename),
        onShare: () => _handleFileAction(previewing, _CloudFileAction.share),
        onDelete: () async {
          await _handleFileAction(previewing, _CloudFileAction.delete);
          if (mounted) controller.closePreview();
        },
      );
    } else {
      content = AppSplitPanel(
        sidebar: _CloudSidebar(
          state: state,
          onSelectCategory: controller.selectCategory,
          onAddCategory: _showAddCategoryDialog,
          onCategoryAction: _handleCategoryAction,
        ),
        child: _CloudContentArea(
          state: state,
          keyword: _keyword,
          searchController: _searchController,
          onClearSearch: _clearSearch,
          onRefresh: controller.refresh,
          onSortChanged: controller.setSortType,
          onBackToOverview: controller.backToOverview,
          onOpenFolder: controller.openFolder,
          onCreateFolder: _showCreateFolderDialog,
          onFolderAction: _handleFolderAction,
          onFileAction: _handleFileAction,
          onUpload: _showUploadDialog,
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: content),
        if (state.busy)
          const Positioned.fill(
            child: IgnorePointer(child: AppLoadingOverlay()),
          ),
      ],
    );
  }

  Future<void> _showAddCategoryDialog() async {
    final name = await _showNameDialog(
      context,
      title: '新建分类',
      hint: '如素描资料、联考模拟题',
      confirmLabel: '创建',
    );
    if (name == null || name.isEmpty) {
      return;
    }
    final message = await ref
        .read(cloudDriveControllerProvider.notifier)
        .addCategory(name);
    if (!mounted) {
      return;
    }
    _showMessage(message ?? '分类已创建');
  }

  Future<void> _showCreateFolderDialog() async {
    final state = ref.read(cloudDriveControllerProvider);
    if (state.selectedCategoryId <= 0) {
      _showMessage('请先选择或新建分类');
      return;
    }
    final name = await _showNameDialog(
      context,
      title: '新建文件夹',
      hint: '如石膏头像范画',
      confirmLabel: '创建',
    );
    if (name == null || name.isEmpty) {
      return;
    }
    final message = await ref
        .read(cloudDriveControllerProvider.notifier)
        .addFolder(name);
    if (!mounted) {
      return;
    }
    _showMessage(message ?? '文件夹已创建');
  }

  Future<void> _handleCategoryAction(
    CloudCategoryItem item,
    _CloudMenuAction action,
  ) async {
    final controller = ref.read(cloudDriveControllerProvider.notifier);
    switch (action) {
      case _CloudMenuAction.rename:
        final nextName = await _showNameDialog(
          context,
          title: '重命名分类',
          hint: '请输入新的分类名称',
          initial: item.name,
        );
        if (nextName == null || nextName.isEmpty || nextName == item.name) {
          return;
        }
        final message = await controller.renameCategory(item.id, nextName);
        if (!mounted) {
          return;
        }
        _showMessage(message ?? '分类名称已更新');
      case _CloudMenuAction.delete:
        final confirmed = await showAppConfirm(
          context: context,
          title: '删除分类',
          message: '「${item.name}」下的文件夹和资料会一并删除，且不可恢复。',
          danger: true,
        );
        if (!confirmed) {
          return;
        }
        final message = await controller.deleteCategory(item.id);
        if (!mounted) {
          return;
        }
        _showMessage(message ?? '分类已删除');
      case _CloudMenuAction.share:
        break;
    }
  }

  Future<void> _handleFolderAction(
    CloudFolderItem item,
    _CloudMenuAction action,
  ) async {
    final controller = ref.read(cloudDriveControllerProvider.notifier);
    switch (action) {
      case _CloudMenuAction.rename:
        final nextName = await _showNameDialog(
          context,
          title: '重命名文件夹',
          hint: '请输入新的文件夹名称',
          initial: item.title,
        );
        if (nextName == null || nextName.isEmpty || nextName == item.title) {
          return;
        }
        final message = await controller.renameFolder(item.id, nextName);
        if (!mounted) {
          return;
        }
        _showMessage(message ?? '文件夹名称已更新');
      case _CloudMenuAction.delete:
        final confirmed = await showAppConfirm(
          context: context,
          title: '删除文件夹',
          message: '「${item.title}」里的资料会一并删除，且不可恢复。',
          danger: true,
        );
        if (!confirmed) {
          return;
        }
        final message = await controller.deleteFolder(item.id);
        if (!mounted) {
          return;
        }
        _showMessage(message ?? '文件夹已删除');
      case _CloudMenuAction.share:
        break;
    }
  }

  Future<void> _handleFileAction(
    CloudFileItem item,
    _CloudFileAction action,
  ) async {
    final controller = ref.read(cloudDriveControllerProvider.notifier);
    switch (action) {
      case _CloudFileAction.preview:
        controller.openPreview(item);
      case _CloudFileAction.rename:
        final nextTitle = await _showNameDialog(
          context,
          title: '重命名资料',
          hint: '请输入新的资料标题',
          initial: item.title,
          maxLength: 40,
        );
        if (nextTitle == null || nextTitle.isEmpty || nextTitle == item.title) {
          return;
        }
        final message = await controller.renameCourseware(item.id, nextTitle);
        if (!mounted) {
          return;
        }
        _showMessage(message ?? '资料标题已更新');
      case _CloudFileAction.share:
        final classes = await controller.fetchShareClasses();
        if (!mounted) {
          return;
        }
        await _showClassShareDrawer(item, classes);
      case _CloudFileAction.delete:
        final confirmed = await showAppConfirm(
          context: context,
          title: '删除资料',
          message: '「${item.title}」删除后不可恢复。',
          danger: true,
        );
        if (!confirmed) {
          return;
        }
        final message = await controller.deleteCourseware(item.id);
        if (!mounted) {
          return;
        }
        _showMessage(message ?? '资料已删除');
      case _CloudFileAction.play:
        controller.togglePlaying(item.id);
    }
  }

  Future<void> _showUploadDialog() async {
    final state = ref.read(cloudDriveControllerProvider);
    if (state.selectedCategoryId <= 0) {
      _showMessage('请先选择或新建分类');
      return;
    }
    final controller = ref.read(cloudDriveControllerProvider.notifier);
    await showScaledDialog<void>(
      context: context,
      barrierColor: AppColors.scrim,
      builder: (dialogContext) => _UploadDialog(
        controller: controller,
        onSuccess: () => AppToast.showSuccess(context, '资料已上传'),
      ),
    );
  }

  Future<void> _showClassShareDrawer(
    CloudFileItem file,
    List<CloudShareClassItem> classes,
  ) async {
    final selected = <String>{};
    var sending = false;
    await showClassShareDrawer<void>(
      context: context,
      child: StatefulBuilder(
        builder: (drawerContext, setDrawerState) {
          return ClassShareDrawer(
            title: '分享资料',
            targetCard: ShareTargetCard(
              label: '你将分享的资料',
              title: file.title,
              coverUrl: file.imageUrls.isEmpty ? '' : file.imageUrls.first,
              placeholderIcon: Icons.insert_drive_file_rounded,
            ),
            classes: classes
                .map(
                  (item) => ClassShareItem(
                    id: item.id,
                    name: item.name,
                    avatarUrl: item.avatarUrl,
                    checked: selected.contains(item.id),
                  ),
                )
                .toList(growable: false),
            loading: false,
            sending: sending,
            onToggleClass: (id) {
              setDrawerState(() {
                if (selected.contains(id)) {
                  selected.remove(id);
                } else {
                  selected.add(id);
                }
              });
            },
            onSend: () async {
              if (selected.isEmpty) {
                _showMessage('请先选择要分享的班级');
                return;
              }
              setDrawerState(() => sending = true);
              final message = await ref
                  .read(cloudDriveControllerProvider.notifier)
                  .shareCourseware(file: file, classIds: selected.toList());
              if (!mounted) {
                return;
              }
              setDrawerState(() => sending = false);
              _showMessage(message ?? '已分享到班级群');
              if (message == null && drawerContext.mounted) {
                Navigator.of(drawerContext).maybePop();
              }
            },
          );
        },
      ),
    );
  }

  void _showMessage(String message) {
    AppToast.show(context, message);
  }
}

enum _CloudMenuAction { rename, share, delete }

Future<_CloudMenuAction?> _showCloudMenu(
  BuildContext anchor, {
  bool share = false,
}) {
  return showAppMenu<_CloudMenuAction>(
    context: anchor,
    width: 144,
    items: [
      const AppMenuItem(
        value: _CloudMenuAction.rename,
        label: '重命名',
        iconAsset: AppAssets.coursewareActionRename,
      ),
      if (share)
        const AppMenuItem(
          value: _CloudMenuAction.share,
          label: '分享到班级',
          iconAsset: AppAssets.coursewareActionShare,
        ),
      const AppMenuItem(
        value: _CloudMenuAction.delete,
        label: '删除',
        iconAsset: AppAssets.coursewareActionDelete,
        danger: true,
      ),
    ],
  );
}

/// 名称输入弹窗（新建 / 重命名分类、文件夹与资料）。
Future<String?> _showNameDialog(
  BuildContext context, {
  required String title,
  required String hint,
  String initial = '',
  String confirmLabel = '保存',
  int maxLength = 20,
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
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initial.length,
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

class _CloudSidebar extends StatelessWidget {
  const _CloudSidebar({
    required this.state,
    required this.onSelectCategory,
    required this.onAddCategory,
    required this.onCategoryAction,
  });

  final CloudDriveState state;
  final ValueChanged<int> onSelectCategory;
  final VoidCallback onAddCategory;
  final Future<void> Function(CloudCategoryItem item, _CloudMenuAction action)
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
          : Padding(
              padding: const EdgeInsets.all(AppSpace.s8),
              child: Text('还没有分类，点击下方「新建分类」', style: AppText.caption12),
            );
    } else {
      list = ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: state.categories.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpace.s4),
        itemBuilder: (context, index) {
          final item = state.categories[index];
          return _CategoryRow(
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
          Padding(
            padding: const EdgeInsets.all(AppSpace.s8),
            child: Text('资料分类', style: AppText.title16),
          ),
          Expanded(child: list),
          const SizedBox(height: AppSpace.s8),
          _StorageUsage(state: state),
          const SizedBox(height: AppSpace.s8),
          AppAddCategoryButton(onTap: onAddCategory),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.onAction,
  });

  final CloudCategoryItem item;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<_CloudMenuAction> onAction;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      selected: selected,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s8,
          AppSpace.s8,
          AppSpace.s4,
          AppSpace.s8,
        ),
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
              width: 28,
              height: 28,
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
                  Text(item.subtitle, style: AppText.caption12),
                ],
              ),
            ),
            Builder(
              builder: (anchor) => AppIconButton.asset(
                asset: AppAssets.cloudActionMore,
                assetSize: 20,
                semanticLabel: '分类操作',
                size: AppButtonSize.sm,
                filled: false,
                onTap: () async {
                  final action = await _showCloudMenu(anchor);
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

class _StorageUsage extends StatelessWidget {
  const _StorageUsage({required this.state});

  final CloudDriveState state;

  @override
  Widget build(BuildContext context) {
    final label = state.storageUsageLabel;
    return Container(
      padding: const EdgeInsets.all(AppSpace.s12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: AppRadius.br8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('云盘存储', style: AppText.caption12Strong),
          const SizedBox(height: AppSpace.s4),
          AppProgressBar(value: state.storageUsagePercent / 100, height: 6),
          const SizedBox(height: AppSpace.s4),
          Text(label.isEmpty ? '—' : label, style: AppText.caption12),
        ],
      ),
    );
  }
}

class _CloudContentArea extends StatelessWidget {
  const _CloudContentArea({
    required this.state,
    required this.keyword,
    required this.searchController,
    required this.onClearSearch,
    required this.onRefresh,
    required this.onSortChanged,
    required this.onBackToOverview,
    required this.onOpenFolder,
    required this.onCreateFolder,
    required this.onFolderAction,
    required this.onFileAction,
    required this.onUpload,
  });

  final CloudDriveState state;
  final String keyword;
  final TextEditingController searchController;
  final VoidCallback onClearSearch;
  final Future<void> Function() onRefresh;
  final ValueChanged<CloudDriveSortType> onSortChanged;
  final VoidCallback onBackToOverview;
  final ValueChanged<CloudFolderItem> onOpenFolder;
  final VoidCallback onCreateFolder;
  final Future<void> Function(CloudFolderItem item, _CloudMenuAction action)
  onFolderAction;
  final Future<void> Function(CloudFileItem item, _CloudFileAction action)
  onFileAction;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final categoryName = state.selectedCategory?.name ?? '';
    final folders = state.folders
        .where((item) => !item.isCreateShortcut)
        .where((item) => keyword.isEmpty || item.title.contains(keyword))
        .toList();
    final files = state.files
        .where((item) => keyword.isEmpty || item.title.contains(keyword))
        .toList();
    final searching = keyword.isNotEmpty;
    final count = state.isFolderView ? files.length : folders.length;

    final Widget body;
    if (state.loading && state.categories.isEmpty) {
      body = const _CloudGridSkeleton();
    } else if (state.categories.isEmpty && state.errorMessage.isNotEmpty) {
      body = AppErrorState(
        title: '云盘加载失败',
        description: state.errorMessage,
        onRetry: onRefresh,
      );
    } else if (state.categories.isEmpty) {
      body = const AppEmptyState(
        illustration: AppAssets.emptyCloudPlaceholder,
        title: '还没有资料分类',
        description: '先在左侧新建一个分类，再创建文件夹存放资料',
      );
    } else if (count == 0 && searching) {
      body = AppEmptyState(
        icon: Icons.search_off_rounded,
        title: '没有找到相关资料',
        description: '换个关键词试试',
        actionLabel: '清除搜索',
        onAction: onClearSearch,
      );
    } else if (count == 0 && state.isFolderView) {
      body = AppEmptyState(
        icon: Icons.upload_file_outlined,
        title: '这个文件夹还没有资料',
        description: '上传范画、步骤图或示范视频，课上随时调用',
        actionLabel: '上传资料',
        onAction: onUpload,
      );
    } else if (count == 0) {
      body = AppEmptyState(
        icon: Icons.create_new_folder_outlined,
        title: '这个分类还没有文件夹',
        description: '按题材或课次建文件夹，资料更好找',
        actionLabel: '新建文件夹',
        onAction: onCreateFolder,
      );
    } else if (state.isFolderView) {
      body = _CloudFilesGrid(items: files, onAction: onFileAction);
    } else {
      body = _CloudFoldersGrid(
        items: folders,
        onOpenFolder: onOpenFolder,
        onAction: onFolderAction,
      );
    }

    return Padding(
      // 与分类栏并排的内容区沿用 30 / 28 / 20 的起始位置。
      padding: const EdgeInsets.fromLTRB(14, AppSpace.s12, AppSpace.s4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: state.isFolderView ? AppSize.iconButtonSm : 20,
            child: Row(
              children: [
                if (state.isFolderView) ...[
                  AppIconButton.back(
                    semanticLabel: '返回文件夹列表',
                    onTap: onBackToOverview,
                  ),
                  const SizedBox(width: AppSpace.s8),
                ],
                Flexible(
                  child: Text(
                    state.isFolderView ? state.currentFolderName : categoryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body14Strong,
                  ),
                ),
                const SizedBox(width: AppSpace.s8),
                if (state.categories.isNotEmpty)
                  Text.rich(
                    TextSpan(
                      style: AppText.caption12,
                      children: [
                        const TextSpan(text: '共 '),
                        TextSpan(
                          text: '$count',
                          style: AppText.number(
                            size: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        TextSpan(text: state.isFolderView ? ' 份资料' : ' 个文件夹'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s16),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 324,
                    child: _CloudSearchField(
                      controller: searchController,
                      hint: state.isFolderView ? '搜索资料名称' : '搜索文件夹',
                      onCleared: onClearSearch,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.s12),
              _CloudToolbarButton(
                label: state.sortType == CloudDriveSortType.none
                    ? '排序'
                    : '按${state.sortType.label}',
                iconAsset: AppAssets.coursewareSort,
                onTap: () => onSortChanged(state.sortType),
              ),
              const SizedBox(width: AppSpace.s12),
              _CloudToolbarButton(
                label: '刷新',
                iconAsset: AppAssets.coursewareRefresh,
                onTap: onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 30),
          Expanded(
            child: AppRefreshIndicator(onRefresh: onRefresh, child: body),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: state.isFolderView ? '上传资料' : '新建文件夹',
              iconAsset: state.isFolderView
                  ? AppAssets.coursewareUploadFab
                  : AppAssets.coursewareNewFolder,
              variant: AppButtonVariant.floating,
              onTap: state.isFolderView ? onUpload : onCreateFolder,
            ),
          ),
        ],
      ),
    );
  }
}

class _CloudSearchField extends StatelessWidget {
  const _CloudSearchField({
    required this.controller,
    required this.hint,
    required this.onCleared,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    const border = OutlineInputBorder(
      borderRadius: AppRadius.br12,
      borderSide: BorderSide(color: AppColors.lineSoft),
    );
    return SizedBox(
      height: AppSize.iconButton,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => AppTextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          textAlignVertical: TextAlignVertical.center,
          style: AppText.body14.copyWith(height: 1),
          cursorColor: AppColors.brand,
          cursorWidth: 1.5,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppText.body14.copyWith(
              height: 1,
              color: AppColors.textPlaceholder,
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: AppSpace.s16, right: 10),
              child: AppAssetGraphic(
                AppAssets.shellV2Search,
                width: 18,
                height: 18,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 44),
            suffixIcon: value.text.isEmpty
                ? null
                : AppIconButton(
                    icon: Icons.cancel_rounded,
                    semanticLabel: '清空',
                    filled: false,
                    size: AppButtonSize.sm,
                    onTap: onCleared,
                  ),
            suffixIconConstraints: const BoxConstraints(minWidth: 40),
            contentPadding: const EdgeInsets.only(right: AppSpace.s12),
            filled: true,
            fillColor: AppColors.surface,
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: const BorderSide(color: AppColors.brand),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloudToolbarButton extends StatelessWidget {
  const _CloudToolbarButton({
    required this.label,
    required this.iconAsset,
    required this.onTap,
  });

  final String label;
  final String iconAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      child: Container(
        height: AppSize.iconButton,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.br12,
          border: Border.all(color: AppColors.lineSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAssetGraphic(iconAsset, width: 16, height: 16),
            const SizedBox(width: AppSpace.s4),
            Text(
              label,
              style: AppText.caption12Strong.copyWith(color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

int _cloudColumnsFor(double width) => width >= 840 ? 4 : (width >= 620 ? 3 : 2);

class _CloudFoldersGrid extends StatelessWidget {
  const _CloudFoldersGrid({
    required this.items,
    required this.onOpenFolder,
    required this.onAction,
  });

  final List<CloudFolderItem> items;
  final ValueChanged<CloudFolderItem> onOpenFolder;
  final Future<void> Function(CloudFolderItem item, _CloudMenuAction action)
  onAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpace.s8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: constraints.maxWidth >= 700
              ? 4
              : (constraints.maxWidth >= 500 ? 3 : 2),
          mainAxisSpacing: AppSpace.s16,
          crossAxisSpacing: AppSpace.s16,
          childAspectRatio: CloudFolderCardArtwork.gridChildAspectRatio,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _FolderCard(
            item: item,
            onTap: () => onOpenFolder(item),
            onAction: (action) => onAction(item, action),
          );
        },
      ),
    );
  }
}

class _FolderCard extends StatefulWidget {
  const _FolderCard({
    required this.item,
    required this.onTap,
    required this.onAction,
  });

  final CloudFolderItem item;
  final VoidCallback onTap;
  final ValueChanged<_CloudMenuAction> onAction;

  @override
  State<_FolderCard> createState() => _FolderCardState();
}

class _FolderCardState extends State<_FolderCard> {
  final _menuKey = GlobalKey();

  Future<void> _openMenu() async {
    final anchor = _menuKey.currentContext;
    if (anchor == null) return;
    final action = await _showCloudMenu(anchor);
    if (mounted && action != null) widget.onAction(action);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final meta = [
      '${item.fileCount} 个文件',
      if (item.sizeLabel.isNotEmpty) item.sizeLabel,
    ].join(' · ');
    return AppPressable(
      onTap: widget.onTap,
      child: Column(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: CloudFolderCardArtwork.artworkAspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CloudFolderCardArtwork(
                    hasContent: item.hasContent,
                    menuTriggerKey: _menuKey,
                    onMenuTap: _openMenu,
                  ),
                  Positioned(
                    left: CloudFolderCardArtwork.metaLeftInset,
                    right: AppSpace.s12,
                    bottom: CloudFolderCardArtwork.metaSizeBottomInset,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.dateLabel.isNotEmpty)
                          Text(
                            item.dateLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption12,
                          ),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption12.copyWith(
                            color: AppColors.brandDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: CloudFolderCardArtwork.titleGap),
          SizedBox(
            height: CloudFolderCardArtwork.titleAreaHeight,
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppText.body13,
            ),
          ),
        ],
      ),
    );
  }
}

class _CloudFilesGrid extends StatelessWidget {
  const _CloudFilesGrid({required this.items, required this.onAction});

  final List<CloudFileItem> items;
  final Future<void> Function(CloudFileItem item, _CloudFileAction action)
  onAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpace.s8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _cloudColumnsFor(constraints.maxWidth),
          mainAxisSpacing: AppSpace.s16,
          crossAxisSpacing: AppSpace.s16,
          childAspectRatio: 0.88,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return RepaintBoundary(
            child: _FileCard(
              item: item,
              onAction: (action) => onAction(item, action),
            ),
          );
        },
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({required this.item, required this.onAction});

  final CloudFileItem item;
  final ValueChanged<_CloudFileAction> onAction;

  @override
  Widget build(BuildContext context) {
    final visual = _resolveFileVisual(item);
    final fallback = Center(
      child: Image.asset(
        visual.iconAsset,
        width: 72,
        height: 72,
        fit: BoxFit.contain,
      ),
    );
    final meta = <String>[
      if (item.sizeLabel.isNotEmpty) item.sizeLabel,
      if (item.dateLabel.isNotEmpty) item.dateLabel,
    ].join(' · ');
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => onAction(_CloudFileAction.preview),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.card),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: AppColors.surfaceSubtle,
                    child: visual.thumbnailUrl.isNotEmpty
                        ? LayoutBuilder(
                            builder: (context, box) => CachedNetworkImage(
                              imageUrl: visual.thumbnailUrl,
                              fit: BoxFit.cover,
                              fadeInDuration: Duration.zero,
                              memCacheWidth: _coursewareDecodeExtent(
                                context,
                                box.maxWidth,
                                480,
                              ),
                              placeholder: (_, _) => const SizedBox.shrink(),
                              errorWidget: (_, _, _) => fallback,
                            ),
                          )
                        : fallback,
                  ),
                  Positioned(
                    top: AppSpace.s8,
                    right: AppSpace.s8,
                    child: AppTag(label: visual.badgeLabel),
                  ),
                  if (item.type == CloudFileType.audio)
                    Positioned(
                      right: AppSpace.s8,
                      bottom: AppSpace.s8,
                      child: AppIconButton(
                        icon: item.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        semanticLabel: item.isPlaying ? '暂停' : '播放',
                        size: AppButtonSize.sm,
                        onTap: () => onAction(_CloudFileAction.play),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s12,
              AppSpace.s8,
              AppSpace.s4,
              AppSpace.s8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body14Strong,
                      ),
                      if (meta.isNotEmpty)
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption12,
                        ),
                    ],
                  ),
                ),
                Builder(
                  builder: (anchor) => AppIconButton.asset(
                    asset: AppAssets.cloudActionMore,
                    assetSize: 20,
                    semanticLabel: '资料操作',
                    size: AppButtonSize.sm,
                    filled: false,
                    onTap: () async {
                      final action = await _showCloudMenu(anchor, share: true);
                      switch (action) {
                        case _CloudMenuAction.rename:
                          onAction(_CloudFileAction.rename);
                        case _CloudMenuAction.share:
                          onAction(_CloudFileAction.share);
                        case _CloudMenuAction.delete:
                          onAction(_CloudFileAction.delete);
                        case null:
                          break;
                      }
                    },
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

class _CloudGridSkeleton extends StatelessWidget {
  const _CloudGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppSpace.s16,
        crossAxisSpacing: AppSpace.s16,
        mainAxisExtent: 124,
      ),
      itemCount: 8,
      itemBuilder: (_, _) => const AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSkeleton(width: 36, height: 36, radius: AppRadius.control),
            Spacer(),
            AppSkeletonText(lines: 2),
          ],
        ),
      ),
    );
  }
}

class _UploadKindOption extends StatelessWidget {
  const _UploadKindOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ui(18),
            height: ui(18),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? const Color(0xFF8E7FFF)
                    : const Color(0xFFCECED1),
                width: ui(1),
              ),
            ),
            child: selected
                ? Center(
                    child: Container(
                      width: ui(9),
                      height: ui(9),
                      decoration: const BoxDecoration(
                        color: Color(0xFF8E7FFF),
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
          SizedBox(width: ui(5)),
          Text(
            label,
            style: TextStyle(
              fontSize: ui(14),
              color: const Color(0xFF0B081A),
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w400,
              height: 12 / 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Preview ────────────────────────────────────────────────────────────────

/// 文件预览页：占据 courseware 页面整个内容区（左侧外壳侧栏依然由
/// `ShellPageSurface` 负责显示）。根据 [CloudFileItem.type] 派发到三种正文：
///  - 图片：头部条 + 主体（PageView 缩放）+ 右侧 160 缩略图栏
///  - 图文讲解：左侧封面 + 标题 + 简介，右侧步骤图（PageView），底部讲解音频
///    播放条；保留分享按钮。
///  - 课件：头部条 + 全宽主体（按文件后缀解析；图片直显，PDF 内嵌阅读，
///    视频内嵌播放，其它类型显示占位）。
class _CoursewarePreviewPage extends StatelessWidget {
  const _CoursewarePreviewPage({
    required this.state,
    required this.controller,
    required this.onClose,
    required this.onRename,
    required this.onShare,
    required this.onDelete,
  });

  final CloudDriveState state;
  final CloudDriveController controller;
  final VoidCallback onClose;
  final Future<void> Function() onRename;
  final Future<void> Function() onShare;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final item = state.previewingFile!;

    // 业务上「图片」与「图文讲解」共用 `CloudFileType.score`：仅有 imageUrls
    // 且没有 audioUrl 视为「图片」，应该走图片预览（带右侧缩略图列）；
    // 否则才是带讲解音频的图文讲解预览。
    final isImageOnlyScore =
        item.type == CloudFileType.score &&
        item.audioUrl.trim().isEmpty &&
        item.imageUrls.isNotEmpty;

    final Widget body;
    if (item.type == CloudFileType.courseware) {
      body = _PreviewCoursewareBody(
        state: state,
        onClose: onClose,
        onRename: onRename,
        onShare: onShare,
        onDelete: onDelete,
      );
    } else if (item.type == CloudFileType.score && !isImageOnlyScore) {
      body = _PreviewScoreBody(
        state: state,
        controller: controller,
        onClose: onClose,
        onShare: onShare,
      );
    } else {
      // 图片（score 但无 audio）以及兜底的 audio 类型 → 图片预览。
      body = _PreviewImageBody(
        state: state,
        controller: controller,
        onClose: onClose,
        onRename: onRename,
        onShare: onShare,
        onDelete: onDelete,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: body,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Common header / button widgets used by image + courseware previews.
// ──────────────────────────────────────────────────────────────────────────

/// 统一的预览页顶部条：左侧返回 + 标题（可点编辑），右侧 分享 / 删除。
class _PreviewHeaderBar extends StatelessWidget {
  const _PreviewHeaderBar({
    required this.title,
    required this.onClose,
    required this.onRename,
    required this.onShare,
    required this.onDelete,
  });

  final String title;
  final VoidCallback onClose;
  final Future<void> Function() onRename;
  final Future<void> Function() onShare;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(56),
      padding: EdgeInsets.symmetric(horizontal: ui(12)),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F2F3), width: 1)),
      ),
      child: Row(
        children: [
          _PreviewBackButton(onTap: onClose),
          SizedBox(width: ui(12)),
          Expanded(
            child: Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onRename(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body14Strong,
                      ),
                    ),
                    SizedBox(width: ui(6)),
                    Image.asset(
                      AppAssets.homeRename,
                      width: ui(20),
                      height: ui(20),
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
            ),
          ),
          _PreviewActionPill(
            iconAsset: AppAssets.coursewareActionShare,
            label: '分享',
            onTap: onShare,
          ),
          SizedBox(width: ui(8)),
          _PreviewActionPill(
            iconAsset: AppAssets.coursewareActionDelete,
            label: '删除',
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

class _PreviewBackButton extends StatelessWidget {
  const _PreviewBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: ui(32),
        height: ui(32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
        ),
        child: Icon(
          Icons.chevron_left_rounded,
          size: ui(18),
          color: const Color(0xFF1C274C),
        ),
      ),
    );
  }
}

class _PreviewActionPill extends StatelessWidget {
  const _PreviewActionPill({
    required this.iconAsset,
    required this.label,
    required this.onTap,
  });

  final String iconAsset;
  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: () => onTap(),
      child: Container(
        height: ui(32),
        padding: EdgeInsets.symmetric(horizontal: ui(12)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(8)),
          border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              iconAsset,
              width: ui(20),
              height: ui(20),
              fit: BoxFit.contain,
            ),
            SizedBox(width: ui(4)),
            Text(
              label,
              style: TextStyle(
                fontSize: ui(12),
                color: Colors.black,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Image preview: header + main pager + right thumbnail rail
// ──────────────────────────────────────────────────────────────────────────

class _PreviewImageBody extends StatefulWidget {
  const _PreviewImageBody({
    required this.state,
    required this.controller,
    required this.onClose,
    required this.onRename,
    required this.onShare,
    required this.onDelete,
  });

  final CloudDriveState state;
  final CloudDriveController controller;
  final VoidCallback onClose;
  final Future<void> Function() onRename;
  final Future<void> Function() onShare;
  final Future<void> Function() onDelete;

  @override
  State<_PreviewImageBody> createState() => _PreviewImageBodyState();
}

class _PreviewImageBodyState extends State<_PreviewImageBody> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.state.previewActiveImageIndex,
    );
  }

  @override
  void didUpdateWidget(covariant _PreviewImageBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.state.previewActiveImageIndex;
    if (_pageController.hasClients && _pageController.page?.round() != target) {
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.state.previewingFile!;
    final showRail = item.imageUrls.length > 1;
    return Column(
      children: [
        _PreviewHeaderBar(
          title: item.title,
          onClose: widget.onClose,
          onRename: widget.onRename,
          onShare: widget.onShare,
          onDelete: widget.onDelete,
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _PreviewImagePager(
                  urls: item.imageUrls,
                  pageController: _pageController,
                  heroPrefix: 'cloud_preview_${item.id}',
                  onPageChanged: widget.controller.previewSetImageIndex,
                ),
              ),
              if (showRail)
                _PreviewThumbnailRail(
                  urls: item.imageUrls,
                  currentIndex: widget.state.previewActiveImageIndex,
                  onSelect: widget.controller.previewSetImageIndex,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewImagePager extends StatelessWidget {
  const _PreviewImagePager({
    required this.urls,
    required this.pageController,
    required this.heroPrefix,
    required this.onPageChanged,
  });

  final List<String> urls;
  final PageController pageController;
  final String heroPrefix;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    if (urls.isEmpty) {
      return Container(
        color: const Color(0xFFFAFAFD),
        alignment: Alignment.center,
        child: Text(
          '该资料暂无可预览图片',
          style: TextStyle(
            color: const Color(0xFF8F86A8),
            fontSize: ui(12),
            fontFamily: 'PingFang SC',
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.all(ui(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ui(7)),
        child: Container(
          color: const Color(0xFFFAFAFD),
          child: PageView.builder(
            controller: pageController,
            itemCount: urls.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final resolved = CloudDriveController.resolveMediaUrl(
                urls[index],
              );
              return LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onDoubleTap: () => showImageGallery(
                      context,
                      images: urls
                          .map(CloudDriveController.resolveMediaUrl)
                          .toList(),
                      initialIndex: index,
                      heroTagPrefix: heroPrefix,
                    ),
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: CachedNetworkImage(
                        imageUrl: resolved,
                        fit: BoxFit.contain,
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        // 只限制较长边解码，避免同时设 width+height 把位图
                        // 压成视口比例导致拉伸（与 image_gallery_viewer 一致）。
                        memCacheWidth: _coursewarePreviewMemCacheWidth(
                          context,
                          constraints.maxWidth,
                          constraints.maxHeight,
                          4096,
                        ),
                        placeholder: (_, _) => Center(
                          child: SizedBox(
                            width: ui(28),
                            height: ui(28),
                            child: AppLoadingIndicator(),
                          ),
                        ),
                        errorWidget: (_, _, _) => Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: ui(48),
                            color: const Color(0xFFB6B5BB),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 图片预览页右侧的缩略图栏。设计要点（参 Figma）：
/// - 容器宽 160，左边 1px `#F3F2F3` 分隔线，白底；
/// - 每张缩略图 128×170，圆角 9，1px `#F3F2F3` 描边；
/// - 页码标签做成「右下角徽章」嵌在缩略图内（只有顶左 + 底左圆角 8，
///   底右那一头让缩略图本身的 9px 圆角带圆，避免双圆视觉不一致）；
/// - 激活态：图上叠一层 11% 透明的暗紫蒙版（约 `#0B081A` @ 0x1C），
///   徽章底色由 `#F5F6FA` 切成 `#E3DFFF`，徽章文字由 `#0B081A` 切成
///   `#715EFE`。**不要**改成"整图换底色"的旧写法 —— 旧写法在 BoxFit.cover
///   下被图片完全遮住，肉眼根本看不到激活效果。
class _PreviewThumbnailRail extends StatelessWidget {
  const _PreviewThumbnailRail({
    required this.urls,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<String> urls;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      width: ui(160),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Color(0xFFF3F2F3), width: 1)),
      ),
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: ui(16), vertical: ui(16)),
        itemCount: urls.length,
        // Figma: 缩略图之间 8px 间距（页码标签已经吃在卡片内部，不再额外抬高）。
        separatorBuilder: (_, _) => SizedBox(height: ui(8)),
        itemBuilder: (context, index) {
          final isCurrent = index == currentIndex;
          return GestureDetector(
            onTap: () => onSelect(index),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: ui(128),
              height: ui(170),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(ui(9)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 缩略图本体：兜底浅灰底 + 1px 浅边框 + 远端图片。
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFD),
                        border: Border.all(
                          color: const Color(0xFFF3F2F3),
                          width: ui(1),
                        ),
                        borderRadius: BorderRadius.circular(ui(9)),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: CloudDriveController.resolveMediaUrl(
                          urls[index],
                        ),
                        fit: BoxFit.cover,
                        width: ui(128),
                        height: ui(170),
                        memCacheWidth: _coursewareDecodeExtent(
                          context,
                          ui(128),
                          360,
                        ),
                        memCacheHeight: _coursewareDecodeExtent(
                          context,
                          ui(170),
                          480,
                        ),
                        placeholder: (_, _) => const SizedBox.shrink(),
                        errorWidget: (_, _, _) => Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: ui(28),
                            color: const Color(0xFFB6B5BB),
                          ),
                        ),
                      ),
                    ),
                    // 激活态：11% 暗紫蒙版（#0B081A @ ~11%）盖在图上面，
                    // 让正在预览的页明显比其它页"暗"一档。颜色 0x1C 对应
                    // 28/255 ≈ 11%，与 Figma 的 rgba(11,8,26,0.11) 对齐。
                    if (isCurrent)
                      const Positioned.fill(
                        child: ColoredBox(color: Color(0x1C0B081A)),
                      ),
                    // 右下角徽章：50×18，左上角 + 右下角圆角 8（设计是
                    // 顶左/底左 + 自然贴在右下被父级 9px clip 带圆），
                    // active=#E3DFFF + #715EFE / inactive=#F5F6FA + #0B081A。
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ui(6),
                          vertical: ui(2),
                        ),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? const Color(0xFFE3DFFF)
                              : const Color(0xFFF5F6FA),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(ui(8)),
                          ),
                        ),
                        child: Text(
                          '第${index + 1}页',
                          style: TextStyle(
                            fontSize: ui(12),
                            color: isCurrent
                                ? const Color(0xFF715EFE)
                                : const Color(0xFF0B081A),
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w400,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Courseware preview: header + full-width body (no thumbnail rail).
// 按后缀分发到图片显示 / 「在新窗口打开」按钮。
// ──────────────────────────────────────────────────────────────────────────

class _PreviewCoursewareBody extends ConsumerWidget {
  const _PreviewCoursewareBody({
    required this.state,
    required this.onClose,
    required this.onRename,
    required this.onShare,
    required this.onDelete,
  });

  final CloudDriveState state;
  final VoidCallback onClose;
  final Future<void> Function() onRename;
  final Future<void> Function() onShare;
  final Future<void> Function() onDelete;

  String _primaryUrl() {
    final item = state.previewingFile!;
    if (item.audioUrl.trim().isNotEmpty) return item.audioUrl;
    if (item.imageUrls.isNotEmpty) return item.imageUrls.first;
    return '';
  }

  bool _isImageUrl(String url) {
    return _hasExt(url, ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'svg']);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = DashboardScaleScope.of(context).ui;
    final item = state.previewingFile!;
    final raw = _primaryUrl();
    final resolved = CloudDriveController.resolveMediaUrl(raw);
    // 与 theory 页面 PDF 阅读器一致，把当前登录态的 app-token 透传给
    // pdfrx，万一后端未来要给课件文件加鉴权头也能直接生效。
    final token = ref.watch(appStorageProvider).token;

    return Column(
      children: [
        _PreviewHeaderBar(
          title: item.title,
          onClose: onClose,
          onRename: onRename,
          onShare: onShare,
          onDelete: onDelete,
        ),
        Expanded(
          child: _isImageUrl(raw)
              ? _PreviewImagePager(
                  urls: <String>[raw],
                  pageController: PageController(),
                  heroPrefix: 'cloud_preview_${item.id}',
                  onPageChanged: (_) {},
                )
              : resolved.isEmpty
              ? _CoursewareEmptyPreview(ui: ui)
              : Padding(
                  padding: EdgeInsets.all(ui(16)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(ui(7)),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFD),
                        border: Border.all(
                          color: const Color(0xFFF3F2F3),
                          width: ui(1),
                        ),
                      ),
                      // 直接把文件嵌入到本页面里：Web 端使用 iframe /
                      // <img> / <audio> / <video> / Office Online；
                      // 原生端按文件类型分流：PDF 走 pdfrx（与 theory
                      // 页面同款），图片走 CachedNetworkImage，其它类型
                      // 展示占位。不再跳新标签页。
                      child: CoursewareInlinePreview(
                        url: resolved,
                        authToken: token,
                        placeholder: _CoursewareEmptyPreview(ui: ui),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// 课件预览空状态（无可解析的文件链接时）。
class _CoursewareEmptyPreview extends StatelessWidget {
  const _CoursewareEmptyPreview({required this.ui});

  final double Function(num) ui;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(ui(16)),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFD),
          borderRadius: BorderRadius.circular(ui(7)),
          border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              AppAssets.coursewareUploadFile,
              width: ui(96),
              height: ui(96),
              fit: BoxFit.contain,
            ),
            SizedBox(height: ui(14)),
            Text(
              '该资料暂无可预览内容',
              style: TextStyle(
                fontSize: ui(12),
                color: const Color(0xFF8F86A8),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// 图文讲解预览：左侧返回 + 分享 + 封面画框 + 标题 + 简介；右侧步骤图
// （PageView）；底部讲解音频播放条。
// ──────────────────────────────────────────────────────────────────────────

class _PreviewScoreBody extends StatelessWidget {
  const _PreviewScoreBody({
    required this.state,
    required this.controller,
    required this.onClose,
    required this.onShare,
  });

  final CloudDriveState state;
  final CloudDriveController controller;
  final VoidCallback onClose;
  final Future<void> Function() onShare;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final item = state.previewingFile!;

    return Padding(
      padding: EdgeInsets.fromLTRB(ui(12), ui(12), ui(12), ui(12)),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: ui(320),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PreviewScoreTurntable(
                        title: item.title,
                        coverUrl: item.imageUrls.isEmpty
                            ? ''
                            : CloudDriveController.resolveMediaUrl(
                                item.imageUrls.first,
                              ),
                        isPlaying: state.previewIsPlaying,
                        onBack: onClose,
                        onShare: onShare,
                      ),
                      SizedBox(height: ui(12)),
                      Expanded(
                        child: _PreviewDescriptionCard(text: item.title),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: ui(1),
                  margin: EdgeInsets.only(left: ui(12), right: ui(14)),
                  color: const Color(0xFFF3F2F3),
                ),
                Expanded(
                  child: _PreviewScoreSheet(
                    images: item.imageUrls,
                    activeIndex: state.previewActiveImageIndex,
                    onPageChanged: controller.previewSetImageIndex,
                    heroPrefix: 'cloud_preview_score_${item.id}',
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: ui(18)),
          _PreviewPlaybackBar(state: state, controller: controller),
        ],
      ),
    );
  }
}

/// 图文讲解预览左上角面板：返回 / 分享 + 封面画框 + 标题胶囊 + 讲解音频频谱。
class _PreviewScoreTurntable extends StatelessWidget {
  const _PreviewScoreTurntable({
    required this.title,
    required this.coverUrl,
    required this.isPlaying,
    required this.onBack,
    required this.onShare,
  });

  final String title;
  final String coverUrl;
  final bool isPlaying;
  final VoidCallback onBack;
  final Future<void> Function() onShare;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _PreviewBackButton(onTap: onBack),
            const Spacer(),
            GestureDetector(
              onTap: () => onShare(),
              child: Container(
                height: ui(28),
                padding: EdgeInsets.symmetric(horizontal: ui(10)),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4FF),
                  borderRadius: BorderRadius.circular(ui(8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/home/open_external.png',
                      width: ui(20),
                      height: ui(20),
                      fit: BoxFit.contain,
                    ),
                    SizedBox(width: ui(4)),
                    Text(
                      '分享',
                      style: TextStyle(
                        color: const Color(0xFF0B081A),
                        fontSize: ui(12),
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: ui(22)),
        Center(
          child: _PreviewCoverFrame(coverUrl: coverUrl, playing: isPlaying),
        ),
        SizedBox(height: ui(14)),
        Center(
          child: Container(
            width: ui(129),
            height: ui(18),
            decoration: BoxDecoration(
              color: const Color(0xFFEDEDED),
              borderRadius: BorderRadius.circular(ui(12)),
            ),
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: ui(12)),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontSize: ui(12),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 18 / 11,
              ),
            ),
          ),
        ),
        SizedBox(height: ui(16)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: ui(22)),
          child: SizedBox(
            height: ui(38),
            child: _PreviewWaveformVisualizer(playing: isPlaying),
          ),
        ),
      ],
    );
  }
}

/// 封面画框：白色卡纸 + 首张步骤图；讲解播放时右下角亮起「讲解中」。
class _PreviewCoverFrame extends StatelessWidget {
  const _PreviewCoverFrame({required this.coverUrl, required this.playing});

  final String coverUrl;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final placeholder = Container(
      color: const Color(0xFFF4F4FF),
      alignment: Alignment.center,
      child: Icon(
        Icons.palette_outlined,
        size: ui(40),
        color: const Color(0xFFB6B5BB),
      ),
    );
    return AnimatedScale(
      scale: playing ? 1.0 : 0.96,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
      child: Container(
        width: ui(180),
        height: ui(180),
        padding: EdgeInsets.all(ui(10)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
          boxShadow: [
            BoxShadow(
              color: const Color(0x1A715EFE),
              blurRadius: ui(20),
              offset: Offset(0, ui(8)),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ui(6)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (coverUrl.isEmpty)
                placeholder
              else
                CachedNetworkImage(
                  imageUrl: coverUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: _coursewareDecodeExtent(context, ui(160), 480),
                  placeholder: (_, _) => placeholder,
                  errorWidget: (_, _, _) => placeholder,
                ),
              Positioned(
                right: ui(6),
                bottom: ui(6),
                child: AnimatedOpacity(
                  opacity: playing ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    height: ui(20),
                    padding: EdgeInsets.symmetric(horizontal: ui(8)),
                    decoration: BoxDecoration(
                      color: const Color(0xFF715EFE),
                      borderRadius: BorderRadius.circular(ui(10)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '讲解中',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: ui(12),
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w500,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 简化频谱：播放时柱状高度做随机弹跳，不依赖真实采样。
class _PreviewWaveformVisualizer extends StatefulWidget {
  const _PreviewWaveformVisualizer({required this.playing});

  final bool playing;

  @override
  State<_PreviewWaveformVisualizer> createState() =>
      _PreviewWaveformVisualizerState();
}

class _PreviewWaveformVisualizerState extends State<_PreviewWaveformVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<double> _phases;
  static const int _bars = 30;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    final rng = math.Random();
    _phases = List<double>.generate(
      _bars,
      (_) => rng.nextDouble() * 2 * math.pi,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final barWidth = width / (_bars * 1.6);
            final gap = (width - barWidth * _bars) / (_bars - 1);
            return Stack(
              children: [
                for (int i = 0; i < _bars; i++)
                  Positioned(
                    left: i * (barWidth + gap),
                    bottom: 0,
                    child: _bar(barWidth, height, i),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _bar(double w, double maxHeight, int index) {
    final phase = _phases[index];
    final t = _ctrl.value * 2 * math.pi + phase;
    final amp = widget.playing ? 0.6 + 0.4 * math.sin(t) : 0.18;
    final h = maxHeight * amp.clamp(0.1, 1.0);
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: <Color>[Color(0xFF715EFE), Color(0xFFD2C6FF)],
        ),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _PreviewDescriptionCard extends StatelessWidget {
  const _PreviewDescriptionCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(20), vertical: ui(16)),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: SingleChildScrollView(
        child: Text(
          text.isEmpty ? '暂无简介' : text,
          style: TextStyle(
            color: const Color(0xFF0B081A),
            fontSize: ui(13),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
            height: 26 / 13,
          ),
        ),
      ),
    );
  }
}

/// 图文讲解右侧步骤图区：PageView + 当前页/总页计数，双击放大查看。
class _PreviewScoreSheet extends StatefulWidget {
  const _PreviewScoreSheet({
    required this.images,
    required this.activeIndex,
    required this.onPageChanged,
    required this.heroPrefix,
  });

  final List<String> images;
  final int activeIndex;
  final ValueChanged<int> onPageChanged;
  final String heroPrefix;

  @override
  State<_PreviewScoreSheet> createState() => _PreviewScoreSheetState();
}

class _PreviewScoreSheetState extends State<_PreviewScoreSheet> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.activeIndex);
  }

  @override
  void didUpdateWidget(covariant _PreviewScoreSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pageController.hasClients &&
        _pageController.page?.round() != widget.activeIndex) {
      _pageController.animateToPage(
        widget.activeIndex,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final images = widget.images;
    if (images.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/404/wx.png',
              width: ui(200),
              height: ui(200),
              fit: BoxFit.contain,
            ),
            Text(
              '暂无步骤图',
              style: TextStyle(
                color: const Color.fromARGB(255, 22, 22, 22),
                fontSize: ui(16),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
              ),
            ),
          ],
        ),
      );
    }
    final activeIndex = widget.activeIndex.clamp(0, images.length - 1);
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: images.length,
          onPageChanged: widget.onPageChanged,
          itemBuilder: (context, index) {
            final url = CloudDriveController.resolveMediaUrl(images[index]);
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: ui(16)),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: () => showImageGallery(
                  context,
                  images: images
                      .map(CloudDriveController.resolveMediaUrl)
                      .toList(),
                  initialIndex: index,
                  heroTagPrefix: widget.heroPrefix,
                ),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.only(bottom: ui(36)),
                  child: CachedNetworkImage(
                    imageUrl: url,
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                    memCacheWidth: _coursewareDecodeExtent(
                      context,
                      MediaQuery.sizeOf(context).width,
                      2200,
                    ),
                    placeholder: (_, _) => SizedBox(
                      height: ui(120),
                      child: Center(
                        child: SizedBox(
                          width: ui(28),
                          height: ui(28),
                          child: AppLoadingIndicator(),
                        ),
                      ),
                    ),
                    errorWidget: (_, _, _) => Icon(
                      Icons.broken_image_outlined,
                      size: ui(48),
                      color: const Color(0xFFB6B5BB),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Positioned(
          right: ui(10),
          bottom: ui(6),
          child: Container(
            height: ui(24),
            padding: EdgeInsets.symmetric(horizontal: ui(8)),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F2F3),
              borderRadius: BorderRadius.circular(ui(6)),
            ),
            alignment: Alignment.center,
            child: Text(
              '${activeIndex + 1}/${images.length}',
              style: TextStyle(
                color: const Color(0xFF0B081A),
                fontSize: ui(12),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 底部讲解音频播放条：封面 + 标题 + 跳转/播放 + 倍速 + 进度 + 收藏。
class _PreviewPlaybackBar extends StatelessWidget {
  const _PreviewPlaybackBar({required this.state, required this.controller});

  final CloudDriveState state;
  final CloudDriveController controller;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final item = state.previewingFile!;
    final durationMs = math.max(state.previewDuration.inMilliseconds, 1);
    final ratio = (state.previewPosition.inMilliseconds / durationMs).clamp(
      0.0,
      1.0,
    );
    final favorite = state.previewFavorite;
    final cover = item.imageUrls.isNotEmpty ? item.imageUrls.first : '';
    final coverUrl = CloudDriveController.resolveMediaUrl(cover);
    final coverFallback = Center(
      child: Icon(
        Icons.palette_outlined,
        size: ui(22),
        color: const Color(0xFFB6B5BB),
      ),
    );

    return Container(
      height: ui(72),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4FF),
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: ui(12)),
          Container(
            width: ui(48),
            height: ui(48),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(ui(4)),
            ),
            clipBehavior: Clip.antiAlias,
            child: coverUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: coverUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: _coursewareDecodeExtent(
                      context,
                      ui(48),
                      160,
                    ),
                    memCacheHeight: _coursewareDecodeExtent(
                      context,
                      ui(48),
                      160,
                    ),
                    errorWidget: (_, _, _) => coverFallback,
                  )
                : coverFallback,
          ),
          SizedBox(width: ui(12)),
          SizedBox(
            width: ui(70),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF0B081A),
                    fontSize: ui(15),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                  ),
                ),
                SizedBox(height: ui(6)),
                Text(
                  '图文讲解',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFFB6B5BB),
                    fontSize: ui(12),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w400,
                    height: 12 / 12,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(67)),
          _PreviewSkipIcon(
            asset: 'assets/images/home/left.png',
            onTap: () => controller.previewSkipSeconds(-5),
          ),
          SizedBox(width: ui(8)),
          GestureDetector(
            onTap: controller.previewTogglePlay,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: ui(44),
              height: ui(44),
              child: Center(
                child: Container(
                  width: ui(36.67),
                  height: ui(36.67),
                  decoration: const BoxDecoration(
                    color: Color(0xFF715EFE),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    state.previewIsPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: ui(22),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: ui(8)),
          _PreviewSkipIcon(
            asset: 'assets/images/home/right.png',
            onTap: () => controller.previewSkipSeconds(5),
          ),
          SizedBox(width: ui(12)),
          _PreviewSpeedChip(
            speed: state.previewSpeed,
            onChanged: controller.previewSetSpeed,
          ),
          SizedBox(width: ui(14)),
          Expanded(
            child: _PreviewProgressTrack(
              ratio: ratio,
              durationLabel:
                  '${_formatDuration(state.previewPosition)}/${_formatDuration(state.previewDuration)}',
              onSeekRatio: (r) => controller.previewSeekRatio(r),
            ),
          ),
          SizedBox(width: ui(19)),
          GestureDetector(
            onTap: controller.previewToggleFavorite,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  favorite ? Icons.star_rounded : Icons.star_border_rounded,
                  size: ui(24),
                  color: favorite
                      ? const Color(0xFF715EFE)
                      : const Color(0xFFB6B5BB),
                ),
                SizedBox(width: ui(4)),
                Text(
                  favorite ? '已收藏' : '收藏',
                  style: TextStyle(
                    color: const Color(0xFFB6B5BB),
                    fontSize: ui(13),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                    height: 12 / 13,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: ui(12)),
        ],
      ),
    );
  }

  String _formatDuration(Duration value) {
    if (value == Duration.zero) return '00:00';
    final m = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _PreviewSkipIcon extends StatelessWidget {
  const _PreviewSkipIcon({required this.asset, required this.onTap});

  final String asset;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: () => onTap(),
      behavior: HitTestBehavior.opaque,
      child: Image.asset(
        asset,
        width: ui(24),
        height: ui(24),
        fit: BoxFit.contain,
      ),
    );
  }
}

class _PreviewProgressTrack extends StatelessWidget {
  const _PreviewProgressTrack({
    required this.ratio,
    required this.durationLabel,
    required this.onSeekRatio,
  });

  final double ratio;
  final String durationLabel;
  final ValueChanged<double> onSeekRatio;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final trackHeight = ui(4);
    final thumbSize = ui(12);
    final hitHeight = ui(20);

    // 自身高度 = hit zone（20），保证在外层 Row（72 高，crossAxis 居中）里
    // 滑块视觉中线对齐播放条中线。时间标签通过 Stack 浮在滑块上方，
    // clipBehavior: Clip.none 让其向上溢出但不撑高布局。
    return SizedBox(
      height: hitHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final clamped = ratio.clamp(0.0, 1.0);
                final fillWidth = width * clamped;
                final thumbLeft = (width - thumbSize) * clamped;
                void emit(Offset p) {
                  if (width <= 0) return;
                  onSeekRatio((p.dx / width).clamp(0.0, 1.0));
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => emit(d.localPosition),
                  onHorizontalDragStart: (d) => emit(d.localPosition),
                  onHorizontalDragUpdate: (d) => emit(d.localPosition),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: trackHeight,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE1E2E5),
                          borderRadius: BorderRadius.circular(ui(23)),
                        ),
                      ),
                      Container(
                        height: trackHeight,
                        width: fillWidth,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: <Color>[
                              Color(0xFFE2D0FF),
                              Color(0xFF715EFE),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(ui(23)),
                        ),
                      ),
                      Positioned(
                        left: thumbLeft,
                        child: Container(
                          width: thumbSize,
                          height: thumbSize,
                          decoration: BoxDecoration(
                            color: const Color(0xFF715EFE),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                offset: const Offset(0, 4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // 时间标签：贴近可见进度条上方（轨道顶在 y=(20-4)/2=8，
          // bottom: 14 → 标签底边 y=6，距离轨道顶视觉约 ~4px）。
          Positioned(
            right: 0,
            bottom: ui(14),
            child: Text(
              durationLabel,
              style: TextStyle(
                color: const Color(0xFF0B081A),
                fontSize: ui(12),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewSpeedChip extends StatefulWidget {
  const _PreviewSpeedChip({required this.speed, required this.onChanged});

  final double speed;
  final ValueChanged<double> onChanged;

  static const List<double> options = <double>[2.0, 1.5, 1.25, 1.0, 0.75, 0.5];

  static String formatSpeed(double v) {
    var t = v.toStringAsFixed(2);
    if (t.contains('.')) {
      t = t.replaceFirst(RegExp(r'0+$'), '');
      if (t.endsWith('.')) t = '${t}0';
    }
    return '${t}x';
  }

  @override
  State<_PreviewSpeedChip> createState() => _PreviewSpeedChipState();
}

class _PreviewSpeedChipState extends State<_PreviewSpeedChip> {
  bool _open = false;

  Future<void> _showMenu() async {
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    final box = context.findRenderObject() as RenderBox;
    final tl = box.localToGlobal(Offset.zero);
    final size = box.size;
    final menuWidth = ui(96);
    final itemHeight = ui(34);
    final padding = ui(6);
    final menuHeight =
        _PreviewSpeedChip.options.length * itemHeight + padding * 2;
    final gap = ui(8);

    final overlay =
        Overlay.of(context, rootOverlay: true).context.findRenderObject()
            as RenderBox;
    final overlaySize = overlay.size;

    var left = tl.dx + (size.width - menuWidth) / 2;
    left = left.clamp(ui(8), overlaySize.width - menuWidth - ui(8));
    final topAbove = tl.dy - menuHeight - gap;
    final topBelow = tl.dy + size.height + gap;
    final above = topAbove >= ui(8);
    final top = above ? topAbove : topBelow;

    setState(() => _open = true);
    final selected = await showGeneralDialog<double>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'preview_speed_menu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondary) {
        return DashboardScaleScope(
          data: scale,
          child: Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                width: menuWidth,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: padding),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(ui(12)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF715EFE,
                          ).withValues(alpha: 0.10),
                          blurRadius: ui(20),
                          offset: Offset(0, ui(8)),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final v in _PreviewSpeedChip.options)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => Navigator.of(dialogContext).pop(v),
                            child: Container(
                              height: itemHeight,
                              alignment: Alignment.center,
                              child: Text(
                                _PreviewSpeedChip.formatSpeed(v),
                                style: TextStyle(
                                  color: v == widget.speed
                                      ? const Color(0xFF715EFE)
                                      : const Color(0xFF7F7F7F),
                                  fontSize: ui(13),
                                  fontFamily: 'PingFang SC',
                                  fontWeight: v == widget.speed
                                      ? AppFont.w600
                                      : AppFont.w400,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    setState(() => _open = false);
    if (selected != null && selected != widget.speed) {
      widget.onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showMenu,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: ui(28),
        padding: EdgeInsets.symmetric(horizontal: ui(8)),
        decoration: BoxDecoration(
          color: _open ? const Color(0xFFF5F2FF) : Colors.white,
          borderRadius: BorderRadius.circular(ui(6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _PreviewSpeedChip.formatSpeed(widget.speed),
              style: TextStyle(
                color: _open
                    ? const Color(0xFF715EFE)
                    : const Color(0xFF7F7F7F),
                fontSize: ui(12),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 12 / 12,
              ),
            ),
            SizedBox(width: ui(2)),
            Image.asset(
              'assets/images/home/chevron-down.png',
              width: ui(12),
              height: ui(12),
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Upload Dialog ──────────────────────────────────────────────────────────

/// 上传体积上限。超过则在「选择文件」阶段直接拒绝，避免一路 await 到
/// 真正读字节 / 拼 multipart 时 OOM 导致 iPad / iPhone 上 APP 闪退。
///
/// - 图片：15MB（与 UI 提示「图片支持 15M 以内」一致）
/// - 音频 / 课件文件：1GB（覆盖较长的示范视频 / 大型 PDF）
const int _kMaxImageBytes = 15 * 1024 * 1024;
const int _kMaxFileBytes = 1024 * 1024 * 1024;

/// 缩略图渲染时的最大解码边长（逻辑像素）。`Image.memory` 默认会按
/// 原图分辨率全量解码到光栅缓存：一张 4000×3000 的 JPEG 会占
/// ~50MB raster，连选 10 张就会把 iPad WebView / iOS 的 GPU 内存撑爆，
/// OS 直接 SIGKILL 进程。我们拼图只显示 76×76，留出 2 倍 DPR 余量
/// 解码到 200×200 已经足够清晰、内存足够低。
const int _kThumbDecodeMaxPx = 200;

/// 图片 / 图文讲解 / 课件在「未选文件」时上传区域的统一高度（设计稿逻辑 px）。
const double _kUploadEmptyZoneHeight = 140;

/// 已选文件列表（图片网格 / 图文讲解区等）的最大可视高度；超出后区域内滚动，
/// 避免弹窗被撑高把底部「取消 / 确认」顶出屏幕。
const double _kUploadListMaxHeight = 220;

/// 上传图片网格每行个数与间距（设计稿逻辑 px）。
const int _kUploadImageGridColumns = 4;
const double _kUploadImageGridSpacing = 8;
const double _kUploadImageGridPadding = 10;

/// 把字节数转成「12.5MB」/「1.2GB」形式，给提示用。
String _formatUploadSize(int bytes) {
  if (bytes <= 0) return '0B';
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  if (bytes >= gb) {
    final v = bytes / gb;
    return '${v.toStringAsFixed(v < 10 ? 1 : 0)}GB';
  }
  if (bytes >= mb) {
    final v = bytes / mb;
    return '${v.toStringAsFixed(v < 10 ? 1 : 0)}MB';
  }
  if (bytes >= kb) {
    final v = bytes / kb;
    return '${v.toStringAsFixed(v < 10 ? 1 : 0)}KB';
  }
  return '${bytes}B';
}

/// 描述上传对话框内单个待上传/已上传文件的全部状态。
class _UploadSlot {
  _UploadSlot({required this.name, this.bytes, this.path, this.size});

  final String name;
  final Uint8List? bytes;
  final String? path;
  final int? size;

  /// 上传进度 0.0–1.0（进行中时 < 1.0；完成后被设为 1.0）
  double progress = 0.0;

  /// 成功后由服务器返回的完整 URL
  String? uploadedUrl;

  /// 失败时的错误文案；null 表示无错误
  String? error;

  bool get isDone => uploadedUrl != null;
  bool get hasError => error != null;
  bool get isUploading => !isDone && !hasError;
  bool get canUpload =>
      (bytes != null && bytes!.isNotEmpty) ||
      (path != null && path!.trim().isNotEmpty);
  bool get hasMemoryPreview =>
      looksLikeImage && bytes != null && bytes!.isNotEmpty;

  /// 根据文件名后缀判断是否为图片，用于显示内存缩略图
  bool get looksLikeImage {
    final ext = name.toLowerCase().split('.').last;
    return const ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }
}

/// 上传资料对话框。保持原有视觉风格，增加：
/// - 每个文件独立的实时上传进度（LinearProgressIndicator / CircularProgressIndicator）
/// - 图片文件用内存字节显示缩略图
/// - 每个文件独立的删除/重试按钮
/// - 图片类型可连续追加多张
/// - 确认按钮在上传未完成时禁用
class _UploadDialog extends StatefulWidget {
  const _UploadDialog({required this.controller, required this.onSuccess});

  final CloudDriveController controller;
  final VoidCallback onSuccess;

  @override
  State<_UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<_UploadDialog> {
  final _titleCtrl = TextEditingController();
  CloudUploadKind _kind = CloudUploadKind.image;

  /// `_slots` 在 image / score 时承载图片列表（多选追加），在 courseware
  /// 时承载唯一的课件文件。
  final List<_UploadSlot> _slots = [];

  /// 仅在 score 类型下使用：与图片并列的「讲解音频」上传槽。
  /// `_slots` + `_scoreAudio` 一起完成图文讲解「讲解音频 + 步骤图」的上传。
  _UploadSlot? _scoreAudio;

  bool _confirming = false;

  /// 系统选择器已确认、但尚未把所选文件转成上传槽位前的过渡态。
  /// 多选图片时读取/校验可能耗时，避免对话框仍停在「空选区」像卡住一样。
  bool _picking = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  bool get _isScore => _kind == CloudUploadKind.score;

  bool get _anyUploading {
    if (_slots.any((s) => s.isUploading)) return true;
    if (_isScore && (_scoreAudio?.isUploading ?? false)) return true;
    return false;
  }

  List<_UploadSlot> get _doneSlots => _slots.where((s) => s.isDone).toList();

  bool get _canConfirm {
    if (_confirming || _anyUploading) return false;
    switch (_kind) {
      case CloudUploadKind.image:
        return _doneSlots.isNotEmpty;
      case CloudUploadKind.score:
        // 图文讲解必须同时具备讲解音频与至少一张图片
        return _doneSlots.isNotEmpty && (_scoreAudio?.isDone ?? false);
      case CloudUploadKind.courseware:
        return _doneSlots.isNotEmpty;
    }
  }

  bool get _pickDisabled => _picking || _anyUploading;

  // ── file picking ──────────────────────────────────────────────────────────

  /// 体积超限 / 选取异常时统一弹一条 toast。提取出来是因为
  /// `_pick` / `_pickScoreAudio` 都需要相同的反馈。
  void _notifyOversize(String fileName, int sizeBytes, int limitBytes) {
    if (!mounted) return;
    AppToast.show(
      context,
      '"$fileName" 体积过大（${_formatUploadSize(sizeBytes)}，上限 '
      '${_formatUploadSize(limitBytes)}），已跳过',
      duration: const Duration(seconds: 3),
    );
  }

  /// 体积校验。size 未知（picker 没返回字节数）时，
  /// 通过已有的 `bytes` 长度兜底。返回 null 表示通过。
  int? _slotSizeBytes(CoursewarePickedFile f) {
    if (f.size != null && f.size! > 0) return f.size;
    if (f.bytes != null) return f.bytes!.lengthInBytes;
    return null;
  }

  /// 主选取（image / score 多选追加图片；courseware 单文件覆盖）。
  Future<void> _pick() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final allowMultiple =
          _kind == CloudUploadKind.image || _kind == CloudUploadKind.score;
      // 图片 / 图文讲解选图直接走 image 类型 — 移动端会拉起相册而不是文件管理。
      final pickType =
          (_kind == CloudUploadKind.image || _kind == CloudUploadKind.score)
          ? CoursewarePickType.image
          : CoursewarePickType.any;
      // 选取本身可能在 iOS 上抛 native exception（DRM 音频、被 dismiss
      // 的 picker、照片库授权异常等），try/catch 兜底防止一路冒到根
      // zone handler 引发闪退。
      final List<CoursewarePickedFile> files;
      try {
        files = await pickCoursewareFiles(
          allowMultiple: allowMultiple,
          type: pickType,
        );
      } catch (e) {
        if (!mounted) return;
        AppToast.show(context, '文件选择失败：${_describeError(e)}');
        return;
      }
      if (files.isEmpty || !mounted) return;

      final imageMode =
          _kind == CloudUploadKind.image || _kind == CloudUploadKind.score;
      final limit = imageMode ? _kMaxImageBytes : _kMaxFileBytes;

      final newSlots = <_UploadSlot>[];
      for (final f in files) {
        final size = _slotSizeBytes(f);
        if (size != null && size > limit) {
          _notifyOversize(f.name, size, limit);
          continue;
        }
        final slot = _UploadSlot(
          name: f.name,
          bytes: f.bytes,
          path: f.path,
          size: f.size,
        );
        if (!slot.canUpload) continue;
        newSlots.add(slot);
      }
      if (newSlots.isEmpty || !mounted) return;

      setState(() {
        if (_kind == CloudUploadKind.courseware) {
          _slots
            ..clear()
            ..addAll(newSlots.take(1));
        } else {
          _slots.addAll(newSlots);
        }
      });

      for (final slot in newSlots) {
        unawaited(_startUpload(slot));
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  /// 图文讲解专用：选取单个讲解音频文件。
  Future<void> _pickScoreAudio() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final List<CoursewarePickedFile> files;
      try {
        files = await pickCoursewareFiles(
          allowMultiple: false,
          type: CoursewarePickType.audio,
        );
      } catch (e) {
        if (!mounted) return;
        AppToast.show(context, '音频选择失败：${_describeError(e)}');
        return;
      }
      if (files.isEmpty || !mounted) return;
      final f = files.first;
      final size = _slotSizeBytes(f);
      if (size != null && size > _kMaxFileBytes) {
        _notifyOversize(f.name, size, _kMaxFileBytes);
        return;
      }
      final slot = _UploadSlot(
        name: f.name,
        bytes: f.bytes,
        path: f.path,
        size: f.size,
      );
      if (!slot.canUpload || !mounted) return;
      setState(() => _scoreAudio = slot);
      unawaited(_startUpload(slot));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _startUpload(_UploadSlot slot) async {
    void progress(double p) {
      if (!mounted) return;
      setState(() => slot.progress = p.clamp(0.0, 0.99));
    }

    String? url;
    Object? failure;
    try {
      final path = slot.path?.trim();
      url = path != null && path.isNotEmpty
          // path 路径走 MultipartFile.fromFile —— Dio 会以流的方式从磁盘
          // 读取，不会在内存中复制整个文件。这是 iOS 上传大文件的核心
          // 优化点。
          ? await widget.controller.uploadFilePathRaw(
              filePath: path,
              filename: slot.name,
              onProgress: progress,
            )
          // bytes 路径只在 Web / 历史 IO 兜底中出现；进入这里之前已经
          // 在 _pick 阶段做了体积校验，理论上不会触发 OOM。
          : await widget.controller.uploadFileRaw(
              bytes: slot.bytes ?? Uint8List(0),
              filename: slot.name,
              onProgress: progress,
            );
    } catch (e) {
      // Dio 抛 DioException、底层抛 OutOfMemoryError 等都在这里被吞掉，
      // 只把 slot 标成失败让用户重试，不会再向上冒到 unawaited 让整
      // 个 zone 报错从而触发 iOS 端的 fatal error。
      failure = e;
    }
    if (!mounted) return;
    setState(() {
      if (url != null && url.isNotEmpty) {
        slot.uploadedUrl = url;
        slot.progress = 1.0;
        slot.error = null;
      } else {
        slot.error = failure != null
            ? '上传失败：${_describeError(failure)}'
            : '上传失败，点击重试';
        slot.progress = 0.0;
      }
    });
  }

  /// 把任意 Object 转成简短的提示文案，避免把巨长的 stack trace
  /// 直接打到 toast / slot 上。
  String _describeError(Object e) {
    final raw = e.toString();
    if (raw.length <= 60) return raw;
    return '${raw.substring(0, 60)}…';
  }

  void _removeSlot(_UploadSlot slot) => setState(() {
    if (identical(slot, _scoreAudio)) {
      _scoreAudio = null;
    } else {
      _slots.remove(slot);
    }
  });

  void _retrySlot(_UploadSlot slot) {
    setState(() {
      slot.error = null;
      slot.progress = 0.0;
      slot.uploadedUrl = null;
    });
    unawaited(_startUpload(slot));
  }

  // ── confirm ───────────────────────────────────────────────────────────────

  Future<void> _confirm() async {
    final done = _doneSlots;
    if (done.isEmpty) return;

    final rawTitle = _titleCtrl.text.trim();
    final fallbackBaseName = done.first.name;
    final fallbackTitle = fallbackBaseName.contains('.')
        ? fallbackBaseName.substring(0, fallbackBaseName.lastIndexOf('.'))
        : fallbackBaseName;
    final title = rawTitle.isNotEmpty ? rawTitle : fallbackTitle;
    if (title.isEmpty) return;

    setState(() => _confirming = true);

    final String audioUrl;
    final String imageInput;
    final CloudFileType fileType;
    switch (_kind) {
      case CloudUploadKind.image:
        // 图片类：保存为 score 类型，仅有图片，没有音频。
        fileType = CloudFileType.score;
        imageInput = done.map((s) => s.uploadedUrl!).join('\n');
        audioUrl = '';
        break;
      case CloudUploadKind.score:
        // 图文讲解：必须同时携带讲解音频 + 图片。
        fileType = CloudFileType.score;
        imageInput = done.map((s) => s.uploadedUrl!).join('\n');
        audioUrl = _scoreAudio?.uploadedUrl ?? '';
        break;
      case CloudUploadKind.courseware:
        fileType = CloudFileType.courseware;
        audioUrl = done.first.uploadedUrl ?? '';
        imageInput = '';
        break;
    }

    final message = await widget.controller.addCourseware(
      title: title,
      type: fileType,
      audioUrl: audioUrl,
      imageInput: imageInput,
    );

    if (!mounted) return;
    setState(() => _confirming = false);

    if (message != null) {
      AppToast.show(context, message, duration: const Duration(seconds: 2));
      return;
    }
    Navigator.of(context).pop();
    widget.onSuccess();
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final mediaSize = MediaQuery.sizeOf(context);
    final maxDialogHeight = mediaSize.height - ui(48);

    final canConfirm = _canConfirm;
    final dialogPadding = EdgeInsets.fromLTRB(ui(20), ui(25), ui(20), ui(20));
    final uploadZone = switch (_kind) {
      CloudUploadKind.image => _buildImageZone(ui),
      CloudUploadKind.score => _buildScoreZone(ui),
      CloudUploadKind.courseware => _buildFileZone(ui),
    };

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: ui(32), vertical: ui(24)),
      child: Container(
        width: ui(420),
        constraints: BoxConstraints(maxHeight: maxDialogHeight),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFD2C6FF), Colors.white, Colors.white],
            stops: <double>[0, 0.21, 1],
          ),
          borderRadius: BorderRadius.circular(ui(24)),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Image.asset(
                AppAssets.coursewareUploadHeader,
                fit: BoxFit.fitWidth,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: dialogPadding.copyWith(bottom: 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── title ──
                        Center(
                          child: Text(
                            '上传资料',
                            style: appDialogTitleTextStyle(ui),
                          ),
                        ),
                        SizedBox(
                          height: ui(
                            appDialogGapBeforeFirstInput(topInset: 25),
                          ),
                        ),

                        // ── courseware title input ──
                        SizedBox(
                          height: ui(45),
                          child: AppTextField(
                            controller: _titleCtrl,
                            cursorColor: const Color(0xFF715EFE),
                            cursorWidth: 1.5,
                            cursorHeight: ui(16),
                            style: TextStyle(
                              fontSize: ui(14),
                              color: const Color(0xFF0B081A),
                              fontFamily: 'PingFang SC',
                              fontWeight: AppFont.w400,
                            ),
                            decoration: InputDecoration(
                              hintText: '请输入资料标题',
                              hintStyle: TextStyle(
                                fontSize: ui(14),
                                color: const Color(0xFFB6B5BB),
                                fontFamily: 'PingFang SC',
                                fontWeight: AppFont.w400,
                                height: 12 / 14,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: ui(13),
                                vertical: ui(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(ui(12)),
                                borderSide: BorderSide(
                                  color: const Color(0xFFF3F2F3),
                                  width: ui(1),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(ui(12)),
                                borderSide: BorderSide(
                                  color: const Color(0xFFD9C7FF),
                                  width: ui(1),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: ui(18)),

                        // ── kind selector ──
                        Text(
                          '选择分类',
                          style: TextStyle(
                            fontSize: ui(14),
                            color: const Color(0xFF0B081A),
                            fontFamily: 'PingFang SC',
                            fontWeight: AppFont.w500,
                            height: 12 / 14,
                          ),
                        ),
                        SizedBox(height: ui(12)),
                        Row(
                          children: CloudUploadKind.values.map((item) {
                            final label = item.label;
                            return Padding(
                              padding: EdgeInsets.only(
                                right: item == CloudUploadKind.courseware
                                    ? 0
                                    : ui(13),
                              ),
                              child: _UploadKindOption(
                                label: label,
                                selected: item == _kind,
                                onTap: _picking
                                    ? null
                                    : () => setState(() {
                                        _kind = item;
                                        _slots.clear();
                                        _scoreAudio = null;
                                      }),
                              ),
                            );
                          }).toList(),
                        ),
                        SizedBox(height: ui(18)),

                        // ── upload zone header ──
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '上传文件',
                              style: TextStyle(
                                fontSize: ui(14),
                                color: const Color(0xFF0B081A),
                                fontFamily: 'PingFang SC',
                                fontWeight: AppFont.w500,
                                height: 1.0,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _kind.uploadTip,
                              style: TextStyle(
                                fontSize: ui(12),
                                color: const Color(0xFFCECED1),
                                fontFamily: 'PingFang SC',
                                fontWeight: AppFont.w400,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: ui(10)),

                        // ── upload zone（高度受限，列表过长时区域内滚动）──
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: ui(_kUploadListMaxHeight),
                          ),
                          child: SingleChildScrollView(child: uploadZone),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    dialogPadding.left,
                    ui(20),
                    dialogPadding.right,
                    dialogPadding.bottom,
                  ),
                  child: AppDialogActionBar(
                    onCancel: () => Navigator.of(context).pop(),
                    onConfirm: _confirm,
                    confirmEnabled: canConfirm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── image grid zone ───────────────────────────────────────────────────────

  Widget _buildPickingIndicator(double Function(double) ui) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppLoadingIndicator(
          size: ui(28),
          strokeWidth: ui(2.5),
          color: const Color(0xFF715EFE),
        ),
        SizedBox(height: ui(8)),
        Text(
          '正在处理所选文件…',
          style: TextStyle(
            fontSize: ui(13),
            color: const Color(0xFF715EFE),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
          ),
        ),
      ],
    );
  }

  Widget _wrapUploadZoneWithPicking(
    Widget child,
    double Function(double) ui, {
    double? minHeight,
  }) {
    if (!_picking) return child;
    return Stack(
      alignment: Alignment.center,
      children: [
        child,
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ui(12)),
            child: Container(
              color: Colors.white.withValues(alpha: 0.78),
              alignment: Alignment.center,
              child: minHeight != null
                  ? SizedBox(
                      height: ui(minHeight),
                      child: Center(child: _buildPickingIndicator(ui)),
                    )
                  : _buildPickingIndicator(ui),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageZone(double Function(double) ui) {
    // If nothing uploaded yet, show original empty-state look inside the zone
    if (_slots.isEmpty) {
      return _wrapUploadZoneWithPicking(
        GestureDetector(
          onTap: _pickDisabled ? null : _pick,
          child: Container(
            width: double.infinity,
            height: ui(_kUploadEmptyZoneHeight),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4FF),
              borderRadius: BorderRadius.circular(ui(12)),
              border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  AppAssets.coursewareUploadFile,
                  width: ui(56),
                  height: ui(56),
                  fit: BoxFit.contain,
                ),
                SizedBox(height: ui(8)),
                _uploadHintText('图片', ui),
              ],
            ),
          ),
        ),
        ui,
        minHeight: _kUploadEmptyZoneHeight,
      );
    }

    return _wrapUploadZoneWithPicking(_buildUploadImageGridShell(ui), ui);
  }

  double _uploadImageGridTileSize(double maxWidth, double Function(double) ui) {
    final spacing = ui(_kUploadImageGridSpacing);
    final gaps = _kUploadImageGridColumns - 1;
    return (maxWidth - spacing * gaps) / _kUploadImageGridColumns;
  }

  Widget _buildUploadAddTile(
    double tileSize,
    BorderRadius radius,
    double Function(double) ui,
  ) {
    return GestureDetector(
      onTap: _pickDisabled ? null : _pick,
      child: SizedBox(
        width: tileSize,
        height: tileSize,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: radius,
            border: Border.all(color: const Color(0xFFD9C7FF), width: ui(1)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_rounded,
                color: const Color(0xFF715EFE),
                size: ui(22),
              ),
              SizedBox(height: ui(2)),
              Text(
                '添加',
                style: TextStyle(
                  fontSize: ui(13),
                  color: const Color(0xFF715EFE),
                  fontFamily: 'PingFang SC',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadImageGridShell(double Function(double) ui) {
    final radius = BorderRadius.circular(ui(8));
    final spacing = ui(_kUploadImageGridSpacing);
    final padding = ui(_kUploadImageGridPadding);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4FF),
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tileSize = _uploadImageGridTileSize(constraints.maxWidth, ui);
          final tiles = <Widget>[
            ..._slots.map(
              (slot) => _buildImageTile(slot, tileSize, radius, ui),
            ),
            _buildUploadAddTile(tileSize, radius, ui),
          ];
          return Wrap(spacing: spacing, runSpacing: spacing, children: tiles);
        },
      ),
    );
  }

  Widget _buildImageTile(
    _UploadSlot slot,
    double size,
    BorderRadius radius,
    double Function(double) ui,
  ) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          // background: real thumbnail or placeholder
          ClipRRect(
            borderRadius: radius,
            // cacheWidth/cacheHeight：把 raw bitmap 解码尺寸卡到预览尺寸
            // 上限内。Image.memory 默认按原图分辨率全量解码 raster，
            // 一张高分辨率手机原图就足以撑爆 iPad WebView 的 GPU 内存
            // 触发 SIGKILL（用户层观察就是「闪退」）。
            // errorBuilder：解码失败（PNG/JPEG 损坏、超大 GIF 等）也不
            // 让控件抛异常一路冒到 build phase。
            child: slot.hasMemoryPreview
                ? Image.memory(
                    slot.bytes!,
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                    cacheWidth: _kThumbDecodeMaxPx,
                    cacheHeight: _kThumbDecodeMaxPx,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.low,
                    errorBuilder: (context, _, _) => Container(
                      width: size,
                      height: size,
                      color: const Color(0xFFF0EBFF),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: ui(20),
                        color: const Color(0xFFB6B5BB),
                      ),
                    ),
                  )
                : Container(
                    width: size,
                    height: size,
                    color: const Color(0xFFF0EBFF),
                    child: Center(
                      child: Image.asset(
                        AppAssets.coursewareUploadImage,
                        width: ui(36),
                        height: ui(36),
                      ),
                    ),
                  ),
          ),

          // uploading overlay
          if (slot.isUploading)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: radius,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: Center(
                    child: AppLoadingIndicator(
                      value: slot.progress > 0 ? slot.progress : null,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

          // error overlay – tap to retry
          if (slot.hasError)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => _retrySlot(slot),
                child: ClipRRect(
                  borderRadius: radius,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.55),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: ui(20),
                        ),
                        SizedBox(height: ui(2)),
                        Text(
                          '重试',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: ui(12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // done badge (bottom-left) — 主色实心圆 + 白色勾
          if (slot.isDone)
            Positioned(
              left: ui(3),
              bottom: ui(3),
              child: Container(
                width: ui(16),
                height: ui(16),
                decoration: const BoxDecoration(
                  color: AppTheme.brandColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: ui(10),
                ),
              ),
            ),

          // delete button (top-right, always)
          Positioned(
            right: ui(3),
            top: ui(3),
            child: GestureDetector(
              onTap: () => _removeSlot(slot),
              child: Container(
                width: ui(18),
                height: ui(18),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: ui(11),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── score (audio + images) zone ───────────────────────────────────────────

  /// 图文讲解：左侧「点击将讲解音频在此处上传」+ 右侧「点击将图片在此处上传」。
  /// 对应接口 `param2`（讲解音频）+ `param3`（图片数组）：上传后音频走
  /// `_scoreAudio`，图片走 `_slots`，提交时一并组装为 score 类型。
  Widget _buildScoreZone(double Function(double) ui) {
    return _wrapUploadZoneWithPicking(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 双区上传卡片：等宽两列。
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ScoreUploadCell(
                  ui: ui,
                  label: '讲解音频',
                  iconAsset: AppAssets.coursewareUploadFile,
                  onTap: _pickDisabled ? null : _pickScoreAudio,
                ),
              ),
              SizedBox(width: ui(16)),
              Expanded(
                child: _ScoreUploadCell(
                  ui: ui,
                  label: '图片',
                  iconAsset: AppAssets.coursewareUploadImage,
                  onTap: _pickDisabled ? null : _pick,
                ),
              ),
            ],
          ),
          // 已选音频文件：在卡片下方以单行槽样式展示进度/完成/重试。
          if (_scoreAudio != null) ...[
            SizedBox(height: ui(10)),
            _buildFileSlot(_scoreAudio!, ui),
          ],
          // 已选图片：与 image 类型保持同一 4 列自适应网格 + “+” 加号瓦片。
          if (_slots.isNotEmpty) ...[
            SizedBox(height: ui(10)),
            _buildUploadImageGridShell(ui),
          ],
        ],
      ),
      ui,
    );
  }

  // ── single-file zone ──────────────────────────────────────────────────────

  Widget _buildFileZone(double Function(double) ui) {
    final uploadLabel = switch (_kind) {
      CloudUploadKind.image => '图片',
      CloudUploadKind.score => '讲解图片',
      CloudUploadKind.courseware => '文件',
    };

    if (_slots.isEmpty) {
      return _wrapUploadZoneWithPicking(
        GestureDetector(
          onTap: _pickDisabled ? null : _pick,
          child: Container(
            width: double.infinity,
            height: ui(_kUploadEmptyZoneHeight),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4FF),
              borderRadius: BorderRadius.circular(ui(12)),
              border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  AppAssets.coursewareUploadImage,
                  width: ui(56),
                  height: ui(56),
                  fit: BoxFit.contain,
                ),
                SizedBox(height: ui(8)),
                _uploadHintText(uploadLabel, ui),
              ],
            ),
          ),
        ),
        ui,
        minHeight: _kUploadEmptyZoneHeight,
      );
    }

    return _buildFileSlot(_slots.first, ui);
  }

  Widget _buildFileSlot(_UploadSlot slot, double Function(double) ui) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(12)),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4FF),
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(
          color: slot.hasError
              ? const Color(0xFFFF386B)
              : const Color(0xFFD9C7FF),
          width: ui(1),
        ),
      ),
      child: Row(
        children: [
          // file icon
          Image.asset(
            AppAssets.coursewareUploadImage,
            width: ui(40),
            height: ui(40),
            fit: BoxFit.contain,
          ),
          SizedBox(width: ui(10)),

          // name + progress/status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: ui(13),
                    color: const Color(0xFF0B081A),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                  ),
                ),
                SizedBox(height: ui(6)),
                if (slot.isUploading) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(ui(3)),
                    child: LinearProgressIndicator(
                      value: slot.progress > 0 ? slot.progress : null,
                      backgroundColor: const Color(0xFFE1E2E5),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF715EFE),
                      ),
                      minHeight: ui(4),
                    ),
                  ),
                  SizedBox(height: ui(3)),
                  Text(
                    slot.progress > 0
                        ? '${(slot.progress * 100).toStringAsFixed(0)}%'
                        : '准备上传...',
                    style: TextStyle(
                      fontSize: ui(12),
                      color: const Color(0xFF715EFE),
                      fontFamily: 'PingFang SC',
                    ),
                  ),
                ] else if (slot.isDone)
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: ui(14),
                        color: const Color(0xFF715EFE),
                      ),
                      SizedBox(width: ui(4)),
                      Text(
                        '已上传${_humanFileSize(slot.size).isEmpty ? '' : ' · '}${_humanFileSize(slot.size)}',
                        style: TextStyle(
                          fontSize: ui(12),
                          color: const Color(0xFFB6B5BB),
                          fontFamily: 'PingFang SC',
                          fontWeight: AppFont.w400,
                          height: 1.2,
                        ),
                      ),
                    ],
                  )
                else if (slot.hasError)
                  Text(
                    slot.error ?? '上传失败',
                    style: TextStyle(
                      fontSize: ui(12),
                      color: const Color(0xFFFF386B),
                      fontFamily: 'PingFang SC',
                    ),
                  ),
              ],
            ),
          ),

          SizedBox(width: ui(8)),

          // retry (only on error)
          if (slot.hasError) ...[
            GestureDetector(
              onTap: () => _retrySlot(slot),
              child: Container(
                width: ui(28),
                height: ui(28),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0EBFF),
                  borderRadius: BorderRadius.circular(ui(6)),
                ),
                child: Icon(
                  Icons.refresh_rounded,
                  size: ui(16),
                  color: const Color(0xFF715EFE),
                ),
              ),
            ),
            SizedBox(width: ui(6)),
          ],

          // delete
          GestureDetector(
            onTap: () => _removeSlot(slot),
            child: Container(
              width: ui(28),
              height: ui(28),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(ui(6)),
              ),
              child: Icon(
                Icons.close_rounded,
                size: ui(16),
                color: const Color(0xFFB6B5BB),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  static String _humanFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
  }

  static Widget _uploadHintText(String label, double Function(double) ui) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: ui(14),
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
          height: 1.0,
        ),
        children: <InlineSpan>[
          const TextSpan(
            text: '点击将',
            style: TextStyle(color: Color(0xFFB6B5BB)),
          ),
          TextSpan(
            text: label,
            style: const TextStyle(color: Color(0xFF0B081A)),
          ),
          const TextSpan(
            text: '在此处上传',
            style: TextStyle(color: Color(0xFFB6B5BB)),
          ),
        ],
      ),
    );
  }
}

/// 图文讲解上传区中的「点击将 X 在此处上传」单元格，高度与图片/课件空态上传区一致。
class _ScoreUploadCell extends StatelessWidget {
  const _ScoreUploadCell({
    required this.ui,
    required this.label,
    required this.iconAsset,
    required this.onTap,
  });

  final double Function(double) ui;
  final String label;
  final String iconAsset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: ui(_kUploadEmptyZoneHeight),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4FF),
          borderRadius: BorderRadius.circular(ui(12)),
          border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: 0.66,
              child: Image.asset(
                iconAsset,
                width: ui(42),
                height: ui(42),
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: ui(12)),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: ui(14),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 12 / 14,
                ),
                children: <InlineSpan>[
                  const TextSpan(
                    text: '点击将',
                    style: TextStyle(color: Color(0xFFB6B5BB)),
                  ),
                  TextSpan(
                    text: label,
                    style: const TextStyle(color: Color(0xFF0B081A)),
                  ),
                  const TextSpan(
                    text: '在此处上传',
                    style: TextStyle(color: Color(0xFFB6B5BB)),
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

/// 文件卡片可触发的动作。`preview` / `play` 由卡片本体的点击与底部音频
/// 控件触发；`rename` / `share` / `delete` 由共享操作菜单
/// (`showItemActionMenu`) 派发。菜单项的文案由共享组件本身负责，无需在此
/// 重复定义。
int? _coursewareDecodeExtent(
  BuildContext context,
  double logicalExtent,
  int maxPixels,
) {
  if (!logicalExtent.isFinite || logicalExtent <= 0) {
    return maxPixels;
  }
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return (logicalExtent * dpr).ceil().clamp(1, maxPixels).toInt();
}

/// 大图预览解码宽度：仅按视口较长边限制，高度随原图比例缩放。
int? _coursewarePreviewMemCacheWidth(
  BuildContext context,
  double maxWidth,
  double maxHeight,
  int maxPixels,
) {
  final longest = math.max(
    maxWidth.isFinite ? maxWidth : 0.0,
    maxHeight.isFinite ? maxHeight : 0.0,
  );
  if (longest <= 0) return null;
  return _coursewareDecodeExtent(context, longest, maxPixels);
}

enum _CloudFileAction { preview, play, rename, share, delete }

/// 文件卡片的视觉数据：图标资源 + 类型徽标背景/文字色 + 徽标文案，
/// 图片类资料额外带缩略图地址。由文件后缀名 + [CloudFileType] 共同决定。
class _FileVisual {
  const _FileVisual({
    required this.iconAsset,
    required this.badgeLabel,
    required this.badgeBg,
    required this.badgeColor,
    this.thumbnailUrl = '',
  });

  final String iconAsset;
  final String badgeLabel;
  final Color badgeBg;
  final Color badgeColor;

  /// 非空时卡片主体显示该图片缩略图，加载失败再回退到 [iconAsset]。
  final String thumbnailUrl;
}

// 文件徽标按业务分类：图片 / 讲解 / 课件（视频文件标为「视频」）。
// 文件主体图标仍然按后缀自动选择（PDF / DOC / 图片 / 课件占位图）。
const Color _kBadgeBgImage = Color(0x1A715EFE);
const Color _kBadgeFgImage = Color(0xFF715EFE);
const Color _kBadgeBgScore = Color(0xFFE6F2FF);
const Color _kBadgeFgScore = Color(0xFF1E73FF);
const Color _kBadgeBgCourseware = Color(0xFFDFFCF0);
const Color _kBadgeFgCourseware = Color(0xFF0CAC40);

bool _hasExt(String url, List<String> exts) {
  final lower = url.toLowerCase();
  for (final ext in exts) {
    if (lower.endsWith('.$ext')) return true;
  }
  return false;
}

/// 根据 url 后缀挑选缩略图素材；找不到匹配时回退到课件占位图。
String _resolveFileIcon(String url) {
  if (_hasExt(url, ['pdf'])) return AppAssets.coursewareFileTypePdf;
  if (_hasExt(url, ['doc', 'docx', 'txt', 'rtf'])) {
    return AppAssets.coursewareFileTypeDoc;
  }
  if (_hasExt(url, ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'svg'])) {
    return AppAssets.coursewareFileTypeImage;
  }
  return AppAssets.coursewareFileTypeKj;
}

_FileVisual _resolveFileVisual(CloudFileItem item) {
  // 选取最具代表性的 url 用于嗅探后缀。
  String url = item.audioUrl;
  if (url.isEmpty && item.imageUrls.isNotEmpty) {
    url = item.imageUrls.first;
  }

  // ── 主体图标：保留各种文件类型缩略图（PDF/DOC/图片/课件）。
  final iconAsset = _resolveFileIcon(url);
  const imageExts = ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'];
  final firstImage = item.imageUrls.isNotEmpty
      ? item.imageUrls.first
      : (_hasExt(item.audioUrl, imageExts) ? item.audioUrl : '');
  final thumbnailUrl = CloudDriveController.resolveMediaUrl(firstImage);

  // ── 类型徽标：
  //  · 仅有图片资源（imageUrls 非空且 audioUrl 为空）→ 图片
  //  · CloudFileType.score（图片 + 讲解音频）       → 讲解
  //  · 视频后缀的课件                               → 视频
  //  · 其它（courseware / audio）                   → 课件
  final hasOnlyImages =
      item.imageUrls.isNotEmpty && item.audioUrl.trim().isEmpty;
  if (hasOnlyImages) {
    return _FileVisual(
      iconAsset: iconAsset,
      badgeLabel: '图片',
      badgeBg: _kBadgeBgImage,
      badgeColor: _kBadgeFgImage,
      thumbnailUrl: thumbnailUrl,
    );
  }
  final isVideo = _hasExt(item.audioUrl, ['mp4', 'mov', 'm4v', 'webm']);
  return switch (item.type) {
    CloudFileType.score => _FileVisual(
      iconAsset: iconAsset,
      badgeLabel: '讲解',
      badgeBg: _kBadgeBgScore,
      badgeColor: _kBadgeFgScore,
      thumbnailUrl: thumbnailUrl,
    ),
    CloudFileType.courseware || CloudFileType.audio => _FileVisual(
      iconAsset: iconAsset,
      badgeLabel: isVideo ? '视频' : '课件',
      badgeBg: _kBadgeBgCourseware,
      badgeColor: _kBadgeFgCourseware,
      thumbnailUrl: thumbnailUrl,
    ),
  };
}
