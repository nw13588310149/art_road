import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_navigator.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/demo/demo_config.dart';
import '../../../../core/ui/ui.dart';
import '../../../ebooks/data/ebook_repository.dart';
import '../../../gallery/data/gallery_repository.dart';
import '../../data/shell_repository.dart';
import '../../state/shell_controller.dart';
import '../../state/shell_state.dart';
import 'shell_notice_drawer.dart';

/// 顶栏：全局搜索 +（演示版标识）+ 帮助 / 通知 / 设置 + 账户菜单，搜索框和快捷按钮各自使用白底。
///
/// 只有图标的按钮都有读屏名称（帮助、通知、设置、账户菜单），走查脚本也按名称点击；
/// 图标按钮与账户菜单的点击区域都是 40 高，铺满整条顶栏。
class ShellTopBar extends StatelessWidget {
  const ShellTopBar({
    required this.state,
    required this.onNavigate,
    required this.onLogout,
    required this.onMarkAllRead,
    required this.onLoadProvinces,
    required this.onUpdateProvince,
    this.onOpenNotice,
    this.demoMode = kDemoMode,
    super.key,
  });

  final ShellState state;
  final ValueChanged<String> onNavigate;
  final Future<void> Function() onLogout;
  final Future<void> Function() onMarkAllRead;
  final Future<({List<String> provinces, String? error})> Function()
  onLoadProvinces;
  final Future<String?> Function(String province) onUpdateProvince;

  /// 点开通知抽屉里的一条消息：标为已读并打开对应页面。
  final ValueChanged<ShellNoticeItem>? onOpenNotice;

  /// 演示版在搜索框右侧常驻「演示版」标识。
  final bool demoMode;

  static const double height = 40;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = constraints.maxWidth < 720 ? AppSpace.s8 : AppSpace.s16;
        return SizedBox(
          height: height,
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 324),
                    child: const _TopSearchBox(),
                  ),
                ),
              ),
              if (demoMode) ...[const ShellDemoModeTag(), SizedBox(width: gap)],
              AppIconButton.asset(
                asset: AppAssets.shellV2Help,
                semanticLabel: '帮助',
                onTap: () => onNavigate(RoutePaths.helpGuide),
              ),
              SizedBox(width: gap),
              AppIconButton.asset(
                asset: AppAssets.shellV2Notice,
                semanticLabel: '通知',
                badgeCount: state.unreadCount,
                onTap: () => showShellNoticeDrawer(
                  context,
                  items: state.noticeItems,
                  unreadCount: state.unreadCount,
                  onMarkAllRead: onMarkAllRead,
                  onOpen: onOpenNotice,
                ),
              ),
              SizedBox(width: gap),
              AppIconButton.asset(
                asset: AppAssets.shellV2Setting,
                semanticLabel: '设置',
                onTap: () => onNavigate(RoutePaths.info),
              ),
              SizedBox(width: gap),
              _UserMenuButton(
                user: state.user,
                schoolName: state.schoolName,
                showName: constraints.maxWidth >= 560,
                onSelect: (action) => _onUserMenu(context, action),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onUserMenu(BuildContext context, _UserMenuAction action) async {
    switch (action) {
      case _UserMenuAction.region:
        await _changeRegion(context);
      case _UserMenuAction.profile:
        onNavigate(RoutePaths.info);
      case _UserMenuAction.logout:
        await _logout();
    }
  }

  Future<void> _changeRegion(BuildContext context) async {
    final result = await onLoadProvinces();
    if (!context.mounted) return;
    if (result.provinces.isEmpty) {
      AppToast.showError(context, result.error ?? '地区列表加载失败，请稍后再试');
      return;
    }
    final current = state.user.province.trim();
    final selected = await showAppDrawer<String>(
      context: context,
      builder: (drawerContext) => AppDrawer(
        title: '所在地区',
        subtitle: '用于展示本省的联考政策与资讯',
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final province in result.provinces)
              AppListRow(
                title: province,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s24,
                  vertical: AppSpace.s12,
                ),
                trailing: province == current
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: AppColors.brand,
                      )
                    : null,
                onTap: () => Navigator.of(drawerContext).pop(province),
              ),
          ],
        ),
      ),
    );
    if (selected == null || selected == current || !context.mounted) return;
    final error = await onUpdateProvince(selected);
    if (!context.mounted) return;
    if (error == null) {
      AppToast.showSuccess(context, '所在地区已改为$selected');
    } else {
      AppToast.showError(context, error.isEmpty ? '修改失败，请稍后再试' : error);
    }
  }

  Future<void> _logout() async {
    try {
      await onLogout();
    } finally {
      // 智慧校园等子页可能叠在首页之上；用根 Navigator 清栈。
      rootNavigatorKey.currentState?.pushNamedAndRemoveUntil(
        RoutePaths.login,
        (route) => false,
      );
    }
  }
}

// ─────────────────────── 演示版标识 ───────────────────────

/// 演示版常驻标识：点开说明演示数据保存在哪里、怎么重置。
class ShellDemoModeTag extends StatelessWidget {
  const ShellDemoModeTag({super.key});

  static const explanation = '演示数据仅保存在本机浏览器或设备，可在登录页重置';

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: () => showAppDialog<void>(
        context: context,
        builder: (dialogContext) => AppDialog(
          title: '演示版',
          message: '当前账号、成绩、作品与消息都是演示数据，用于体验各项功能。$explanation。',
          actions: [
            AppButton(
              label: '知道了',
              onTap: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        ),
      ),
      child: const SizedBox(
        height: ShellTopBar.height,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpace.s4),
          child: Center(
            child: AppTag(
              label: '演示版',
              tone: AppTone.info,
              icon: Icons.info_outline_rounded,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────── 账户菜单 ───────────────────────

enum _UserMenuAction { region, profile, logout }

class _UserMenuButton extends StatefulWidget {
  const _UserMenuButton({
    required this.user,
    required this.schoolName,
    required this.showName,
    required this.onSelect,
  });

  final ShellUser user;
  final String schoolName;
  final bool showName;
  final ValueChanged<_UserMenuAction> onSelect;

  @override
  State<_UserMenuButton> createState() => _UserMenuButtonState();
}

class _UserMenuButtonState extends State<_UserMenuButton> {
  final _anchorKey = GlobalKey();

  String get _name {
    final name = widget.user.displayName.trim();
    return name.isEmpty ? '用户' : name;
  }

  Future<void> _open() async {
    final anchor = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context, rootOverlay: true).context.findRenderObject()
            as RenderBox?;
    if (anchor == null || overlay == null) return;
    const menuWidth = 240.0;
    final bottomRight = anchor.localToGlobal(
      anchor.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final left = (bottomRight.dx - menuWidth)
        .clamp(
          AppSpace.s8,
          math.max(AppSpace.s8, overlay.size.width - menuWidth - AppSpace.s8),
        )
        .toDouble();
    final top = bottomRight.dy + AppSpace.s8;

    final action = await showGeneralDialog<_UserMenuAction>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭账户菜单',
      barrierColor: const Color(0x00000000),
      transitionDuration: AppMotion.overlay,
      pageBuilder: (dialogContext, _, _) => Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: menuWidth,
            child: _UserMenuPanel(
              name: _name,
              user: widget.user,
              schoolName: widget.schoolName,
              onSelect: (value) => Navigator.of(dialogContext).pop(value),
            ),
          ),
        ],
      ),
      transitionBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: AppMotion.overlayCurve,
        ),
        child: child,
      ),
    );
    if (action != null && mounted) {
      widget.onSelect(action);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      key: _anchorKey,
      onTap: _open,
      semanticLabel: '账户菜单',
      child: SizedBox(
        height: ShellTopBar.height,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAvatar(name: _name, url: widget.user.avatarUrl, size: 30),
            if (widget.showName) ...[
              const SizedBox(width: AppSpace.s8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: Text(
                  _name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body14Strong,
                ),
              ),
            ],
            const SizedBox(width: 2),
            const Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserMenuPanel extends StatelessWidget {
  const _UserMenuPanel({
    required this.name,
    required this.user,
    required this.schoolName,
    required this.onSelect,
  });

  final String name;
  final ShellUser user;
  final String schoolName;
  final ValueChanged<_UserMenuAction> onSelect;

  @override
  Widget build(BuildContext context) {
    final identity = user.identity.trim();
    final province = user.province.trim();
    final note = [
      if (identity.isNotEmpty) identity,
      if (schoolName.trim().isNotEmpty) schoolName.trim(),
    ].join(' · ');
    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.br12,
          border: Border.all(color: AppColors.lineSoft),
          boxShadow: AppShadow.popover,
        ),
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppListRow(
              title: name,
              subtitle: note.isEmpty ? null : note,
              leading: AppAvatar(name: name, url: user.avatarUrl, size: 36),
              divider: true,
            ),
            const SizedBox(height: AppSpace.s4),
            AppListRow(
              title: '所在地区',
              leading: const _MenuIcon(Icons.place_outlined),
              trailing: Text(
                province.isEmpty ? '未设置' : province,
                style: AppText.caption12,
              ),
              chevron: true,
              onTap: () => onSelect(_UserMenuAction.region),
            ),
            AppListRow(
              title: '个人信息',
              leading: const _MenuIcon(Icons.person_outline_rounded),
              chevron: true,
              onTap: () => onSelect(_UserMenuAction.profile),
            ),
            AppListRow(
              title: '退出登录',
              leading: const _MenuIcon(Icons.logout_rounded),
              onTap: () => onSelect(_UserMenuAction.logout),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuIcon extends StatelessWidget {
  const _MenuIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: 20, color: AppColors.textSecondary);
  }
}

// ─────────────────────── 全局搜索 ───────────────────────
//
// 输入 300ms 后并行搜索范画、资讯、视频、笔记，结果浮层挂在搜索框下方；
// 回车立即搜索。浮层只在点外部、选中结果或清空时收起，回车导致输入框失焦时不收起。
// 点击结果：视频 → /video-tutorial {openVideoId}，资讯 → /consultationDetail {id}，
// 范画 → /gallery {workId}，笔记 → /my-notes。

enum _SearchTab {
  gallery('范画', Icons.image_outlined),
  ebook('书刊', Icons.menu_book_outlined),
  text('资讯', Icons.article_outlined),
  video('视频', Icons.play_circle_outline_rounded),
  note('笔记', Icons.sticky_note_2_outlined);

  const _SearchTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _SearchItem {
  const _SearchItem({
    required this.id,
    required this.title,
    required this.type,
  });

  /// 后端原始 id（雪花长整型，以字符串承载，避免 53bit 精度丢失）。
  final String id;
  final String title;

  /// 分发字段：数字（6 视频 / 9 资讯）或字符串（'gallery' / 'note'）。
  final Object? type;
}

enum _SearchStatus { idle, loading, done, failed }

const _emptyResults = <_SearchTab, List<_SearchItem>>{
  _SearchTab.gallery: <_SearchItem>[],
  _SearchTab.ebook: <_SearchItem>[],
  _SearchTab.text: <_SearchItem>[],
  _SearchTab.video: <_SearchItem>[],
  _SearchTab.note: <_SearchItem>[],
};

class _TopSearchBox extends ConsumerStatefulWidget {
  const _TopSearchBox();

  @override
  ConsumerState<_TopSearchBox> createState() => _TopSearchBoxState();
}

class _TopSearchBoxState extends ConsumerState<_TopSearchBox> {
  static const _debounceDuration = Duration(milliseconds: 300);

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  final _overlay = OverlayPortalController();

  Timer? _debounce;

  /// 正在等待结果的关键字，用于丢弃过期结果。
  String _pendingKeyword = '';
  String _query = '';
  _SearchTab _activeTab = _SearchTab.gallery;
  _SearchStatus _status = _SearchStatus.idle;
  Map<_SearchTab, List<_SearchItem>> _results = _emptyResults;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_handleTextChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _showOverlay() {
    if (!_overlay.isShowing) {
      _overlay.show();
    }
  }

  void _hideOverlay() {
    if (_overlay.isShowing) {
      _overlay.hide();
    }
  }

  void _handleTextChange() {
    final value = _controller.text;
    if (value == _query) return;
    _debounce?.cancel();
    final keyword = value.trim();
    setState(() {
      _query = value;
      if (keyword.isEmpty) {
        _pendingKeyword = '';
        _status = _SearchStatus.idle;
        _results = _emptyResults;
      }
    });
    if (keyword.isEmpty) {
      _hideOverlay();
      return;
    }
    _showOverlay();
    _debounce = Timer(_debounceDuration, () => _performSearch(keyword));
  }

  void _handleSubmitted(String value) {
    final keyword = value.trim();
    if (keyword.isEmpty) return;
    _debounce?.cancel();
    _showOverlay();
    _performSearch(keyword);
  }

  Future<void> _performSearch(String keyword) async {
    _pendingKeyword = keyword;
    setState(() => _status = _SearchStatus.loading);

    final repo = ref.read(shellRepositoryProvider);
    final province = ref.read(shellControllerProvider).user.province;
    try {
      final responses = await Future.wait([
        ref
            .read(galleryRepositoryProvider)
            .getWorks(keyword: keyword, size: 30),
        repo.searchTextbookList(keyword: keyword, province: province),
        repo.searchVideoList(keyword: keyword, province: province),
        repo.searchNoteList(keyword: keyword, province: province),
        ref.read(ebookRepositoryProvider).searchBooks(keyword),
      ]);
      if (!mounted || _pendingKeyword != keyword) return;
      final results = <_SearchTab, List<_SearchItem>>{
        _SearchTab.gallery: _parseList(responses[0].data, type: 'gallery'),
        _SearchTab.ebook: _parseList(responses[4].data, type: 'ebook'),
        // 资讯接口自带 type 字段，按原值分发。
        _SearchTab.text: _parseList(responses[1].data),
        _SearchTab.video: _parseList(responses[2].data, type: 6),
        _SearchTab.note: _parseList(responses[3].data, type: 'note'),
      };
      setState(() {
        _status = _SearchStatus.done;
        _results = results;
        if (results[_activeTab]!.isEmpty) {
          _activeTab = _SearchTab.values.firstWhere(
            (tab) => results[tab]!.isNotEmpty,
            orElse: () => _activeTab,
          );
        }
      });
    } catch (_) {
      if (!mounted || _pendingKeyword != keyword) return;
      setState(() {
        _status = _SearchStatus.failed;
        _results = _emptyResults;
      });
    }
  }

  List<_SearchItem> _parseList(dynamic raw, {Object? type}) {
    if (raw is Map && raw['records'] is List) {
      raw = raw['records'];
    }
    if (raw is! List) return const <_SearchItem>[];
    final items = <_SearchItem>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final id = entry['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final title = entry['title']?.toString().trim() ?? '';
      items.add(
        _SearchItem(
          id: id,
          title: title.isNotEmpty ? title : (entry['name']?.toString() ?? ''),
          type: type ?? entry['type'],
        ),
      );
    }
    return items;
  }

  void _openItem(_SearchItem item) {
    final navigator = Navigator.of(context);
    _focusNode.unfocus();
    _hideOverlay();
    switch (item.type) {
      case 6:
        navigator.pushNamed(
          RoutePaths.videoTutorial,
          arguments: <String, dynamic>{'openVideoId': item.id},
        );
      case 9:
        navigator.pushNamed(
          RoutePaths.consultationDetail,
          arguments: <String, dynamic>{'id': item.id},
        );
      case 'gallery':
        navigator.pushNamed(
          RoutePaths.gallery,
          arguments: <String, dynamic>{'workId': item.id},
        );
      case 'ebook':
        navigator.pushNamed(
          RoutePaths.ebooks,
          arguments: <String, dynamic>{'bookId': item.id},
        );
      case 'note':
        navigator.pushNamed(RoutePaths.myNotes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _overlay,
        overlayLocation: OverlayChildLocation.rootOverlay,
        overlayChildBuilder: _buildOverlay,
        child: AppSearchField(
          toolbar: true,
          controller: _controller,
          focusNode: _focusNode,
          hint: '搜索范画、书刊、资讯、视频、笔记',
          onSubmitted: _handleSubmitted,
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    final box = context.findRenderObject() as RenderBox?;
    final width = (box?.size.width ?? 360).clamp(340.0, 420.0);
    return Stack(
      children: [
        // 点浮层外任意位置收起浮层。
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              _focusNode.unfocus();
              _hideOverlay();
            },
          ),
        ),
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          offset: const Offset(-2, AppSpace.s8),
          child: SizedBox(
            width: width,
            child: _SearchPanel(
              status: _status,
              activeTab: _activeTab,
              results: _results,
              onTabChanged: (tab) => setState(() => _activeTab = tab),
              onItemTap: _openItem,
              onRetry: () {
                final keyword = _query.trim();
                if (keyword.isNotEmpty) _performSearch(keyword);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.status,
    required this.activeTab,
    required this.results,
    required this.onTabChanged,
    required this.onItemTap,
    required this.onRetry,
  });

  final _SearchStatus status;
  final _SearchTab activeTab;
  final Map<_SearchTab, List<_SearchItem>> results;
  final ValueChanged<_SearchTab> onTabChanged;
  final ValueChanged<_SearchItem> onItemTap;
  final VoidCallback onRetry;

  static const double _bodyHeight = 320;

  @override
  Widget build(BuildContext context) {
    final done = status == _SearchStatus.done;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.br12,
          border: Border.all(color: AppColors.lineSoft),
          boxShadow: AppShadow.popover,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.lineSoft)),
              ),
              alignment: Alignment.centerLeft,
              child: AppTabs<_SearchTab>(
                tabs: [
                  for (final tab in _SearchTab.values)
                    AppTab(
                      value: tab,
                      label: tab.label,
                      count: done ? results[tab]!.length : null,
                    ),
                ],
                value: activeTab,
                onChanged: onTabChanged,
              ),
            ),
            SizedBox(height: _bodyHeight, child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (status) {
      case _SearchStatus.idle:
      case _SearchStatus.loading:
        return const _SearchSkeleton();
      case _SearchStatus.failed:
        return AppErrorState(
          title: '搜索失败',
          description: '请检查网络后重试',
          onRetry: onRetry,
        );
      case _SearchStatus.done:
        final list = results[activeTab]!;
        if (list.isEmpty) {
          return const AppEmptyState(
            icon: Icons.search_off_rounded,
            title: '没有找到相关内容',
            description: '换个关键词试试，可搜索范画、资讯、视频和笔记',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
          itemCount: list.length,
          itemBuilder: (context, index) => AppListRow(
            title: list[index].title,
            leading: Icon(
              activeTab.icon,
              size: 18,
              color: AppColors.textTertiary,
            ),
            chevron: true,
            divider: index < list.length - 1,
            onTap: () => onItemTap(list[index]),
          ),
        );
    }
  }
}

class _SearchSkeleton extends StatelessWidget {
  const _SearchSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(
        children: [
          for (var i = 0; i < 5; i++) ...[
            if (i > 0) const SizedBox(height: AppSpace.s20),
            Row(
              children: [
                const AppSkeleton(width: 18, height: 18),
                const SizedBox(width: AppSpace.s12),
                AppSkeleton(width: i.isEven ? 240 : 160),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
