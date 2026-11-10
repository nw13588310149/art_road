import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_navigator.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/network/media_url.dart';
import '../../../../core/widgets/app_wheel_picker_sheet.dart';
import '../../../../core/theme/app_font.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_asset_graphic.dart';
import '../../../ebooks/data/ebook_repository.dart';
import '../../../gallery/data/gallery_repository.dart';
import '../../data/shell_repository.dart';
import '../../state/shell_controller.dart';
import '../../state/shell_state.dart';
import '../shell_layout.dart';
import 'shell_notice_drawer.dart';

/// 顶栏：全局搜索 + 帮助 / 通知 / 设置 + 账户菜单，搜索框和快捷按钮各自使用白底。
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
              SizedBox(width: gap),
              AppIconButton.asset(
                asset: AppAssets.shellV2Help,
                semanticLabel: '帮助',
                onTap: () => onNavigate(RoutePaths.helpGuide),
              ),
              SizedBox(width: gap),
              _noticeButton(context),
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

  Widget _noticeButton(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final unread = state.unreadCount;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AppIconButton.asset(
          asset: AppAssets.shellV2Notice,
          semanticLabel: '通知',
          onTap: () => showShellNoticeDrawer(
            context,
            items: state.noticeItems,
            unreadCount: unread,
            onMarkAllRead: onMarkAllRead,
            onOpen: onOpenNotice,
          ),
        ),
        if (unread > 0)
          Positioned(
            right: ui(-6),
            top: ui(-4),
            child: Container(
              height: ui(14),
              constraints: BoxConstraints(minWidth: ui(22)),
              padding: EdgeInsets.symmetric(horizontal: ui(4)),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF04545),
                borderRadius: BorderRadius.circular(ui(20)),
              ),
              child: Text(
                unread > 99 ? '99+' : (unread > 9 ? '$unread+' : '$unread'),
                textAlign: TextAlign.center,
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                ),
                strutStyle: StrutStyle(
                  fontSize: ui(9),
                  height: 1,
                  forceStrutHeight: true,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
                style: TextStyle(
                  fontFamily: 'Manrope',
                  color: Colors.white,
                  fontSize: ui(9),
                  fontWeight: FontWeight.w800,
                  height: 1,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
            ),
          ),
      ],
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
    final selected = await showAppProvincePicker(
      context: context,
      provinces: result.provinces,
      selected: state.user.province.isEmpty ? null : state.user.province,
    );
    if (selected == null || !context.mounted) return;
    final error = await onUpdateProvince(selected);
    if (!context.mounted) return;
    AppToast.show(context, error ?? '修改成功！');
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

  Widget _buildAvatar(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final fallback = Container(
      width: ui(36),
      height: ui(36),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFE7ECFA), Color(0xFFD9E1F6)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: ui(20),
        color: const Color(0xFF7E879C),
      ),
    );
    final avatarWidget = widget.user.avatarUrl.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: MediaUrl.resolve(widget.user.avatarUrl),
            width: ui(36),
            height: ui(36),
            fit: BoxFit.cover,
            placeholder: (context, url) => fallback,
            errorWidget: (context, url, error) => fallback,
          )
        : fallback;

    return Container(
      width: ui(40),
      height: ui(40),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: ClipOval(
        child: SizedBox(width: ui(36), height: ui(36), child: avatarWidget),
      ),
    );
  }

  Future<void> _open() async {
    final triggerBox =
        _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (triggerBox == null) {
      return;
    }
    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayBox = overlay.context.findRenderObject() as RenderBox;
    // 提前抓取当前页面的 DashboardScaleScope，再透传到 root overlay 子树里，
    // 避免菜单 builder 的 context 找不到 scope 而触发 `scope != null` 断言。
    final scale = DashboardScaleScope.of(context);
    final ui = scale.ui;
    final menuWidth = ui(180);
    final menuHeight = ui(212);

    // 与 1.0 `placement="bottom-end"` 对齐：弹出在按钮右下方。
    final triggerSize = triggerBox.size;
    final bottomRight = triggerBox.localToGlobal(
      triggerSize.bottomRight(Offset.zero),
      ancestor: overlayBox,
    );
    final overlaySize = overlayBox.size;
    var dx = bottomRight.dx - menuWidth;
    var dy = bottomRight.dy + ui(8);
    if (dx < ui(8)) {
      dx = ui(8);
    }
    if (dx + menuWidth > overlaySize.width - ui(8)) {
      dx = overlaySize.width - menuWidth - ui(8);
    }
    if (dy + menuHeight > overlaySize.height - ui(8)) {
      dy = overlaySize.height - menuHeight - ui(8);
    }

    final action = await showMenu<_UserMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(dx, dy, dx + menuWidth, dy + menuHeight),
      color: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      menuPadding: const EdgeInsets.symmetric(vertical: 8),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      constraints: BoxConstraints.tightFor(width: menuWidth),
      items: <PopupMenuEntry<_UserMenuAction>>[
        PopupMenuItem<_UserMenuAction>(
          padding: EdgeInsets.zero,
          enabled: false,
          child: DashboardScaleScope(
            data: scale,
            child: Builder(
              builder: (panelCtx) => _UserMenuPanel(
                width: menuWidth,
                province: widget.user.province,
                onSelect: (value) => Navigator.of(panelCtx).pop(value),
              ),
            ),
          ),
        ),
      ],
    );

    if (action == null || !context.mounted) {
      return;
    }

    widget.onSelect(action);
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
            _buildAvatar(context),
            if (widget.showName) ...[
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: Text(
                  _name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1,
                    color: const Color(0xFF1A1A1A),
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w500,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 2),
            const AppAssetGraphic(
              AppAssets.leftNavBottom,
              width: 14,
              height: 14,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserMenuPanel extends StatelessWidget {
  const _UserMenuPanel({
    required this.width,
    required this.province,
    required this.onSelect,
  });

  final double width;
  final String province;
  final ValueChanged<_UserMenuAction> onSelect;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final regionText = province.trim().isEmpty ? '未设置' : province.trim();
    // Figma：white bg + 1px #F3F2F3 border + 16px radius + 0 2 8 rgba(0,0,0,.12) shadow
    // 内边距 16，三行间距 16；行高度 44，左侧 36 圆形占位 + 20 图标。
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(16)),
        border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x1F000000), // rgba(0,0,0,0.12)
            blurRadius: ui(8),
            offset: Offset(0, ui(2)),
          ),
        ],
      ),
      padding: EdgeInsets.all(ui(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _UserMenuRow(
            iconAsset: AppAssets.homeUserMenuRegion,
            label: '所在地区',
            sublabel: regionText,
            onTap: () => onSelect(_UserMenuAction.region),
          ),
          SizedBox(height: ui(24)),
          _UserMenuRow(
            iconAsset: AppAssets.homeUserMenuProfile,
            label: '资料修改',
            onTap: () => onSelect(_UserMenuAction.profile),
          ),
          SizedBox(height: ui(24)),
          _UserMenuRow(
            iconAsset: AppAssets.homeUserMenuLogout,
            label: '退出登录',
            onTap: () => onSelect(_UserMenuAction.logout),
          ),
        ],
      ),
    );
  }
}

class _UserMenuRow extends StatelessWidget {
  const _UserMenuRow({
    required this.iconAsset,
    required this.label,
    required this.onTap,
    this.sublabel,
  });

  /// 行图标（PNG 资源路径）。
  final String iconAsset;
  final String label;

  /// 副标题（仅「所在地区」用于显示当前省份）。null 时不渲染第二行。
  final String? sublabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hasSub = sublabel != null && sublabel!.isNotEmpty;
    return AppPressable(
      onTap: onTap,
      child: SizedBox(
        height: ui(44),
        child: Row(
          children: [
            Image.asset(
              iconAsset,
              width: ui(36),
              height: ui(36),
              fit: BoxFit.contain,
            ),
            SizedBox(width: ui(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: hasSub
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: ui(16),
                      color: Colors.black,
                      fontFamily: 'PingFang SC',
                      fontWeight: AppFont.w500,
                      height: 1.2,
                    ),
                  ),
                  if (hasSub) ...[
                    SizedBox(height: ui(4)),
                    Text(
                      sublabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui(12),
                        color: const Color(0xFF715EFE),
                        fontFamily: 'PingFang SC',
                        fontWeight: AppFont.w400,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
  final _searchRegion = Object();

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
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_handleTextChange);
    _controller.dispose();
    _focusNode.removeListener(_handleFocusChange);
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

  void _handleFocusChange() {
    if (_focusNode.hasFocus && _query.trim().isNotEmpty) _showOverlay();
  }

  void _handleTextChange() {
    final value = _controller.text;
    if (value == _query) return;
    _debounce?.cancel();
    final keyword = value.trim();
    setState(() {
      _query = value;
      _pendingKeyword = '';
      if (keyword.isEmpty) {
        _status = _SearchStatus.idle;
        _results = _emptyResults;
      } else {
        _status = _SearchStatus.loading;
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
        _status = responses.any((response) => response.isSuccess)
            ? _SearchStatus.done
            : _SearchStatus.failed;
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
        child: TapRegion(
          groupId: _searchRegion,
          onTapOutside: (_) {
            if (!_overlay.isShowing) return;
            _focusNode.unfocus();
            _hideOverlay();
          },
          child: _buildField(context),
        ),
      ),
    );
  }

  Widget _buildField(BuildContext context) {
    double ui(num value) => value.toDouble();
    return SizedBox(
      height: ui(40),
      child: AppTextField(
        controller: _controller,
        focusNode: _focusNode,
        textInputAction: TextInputAction.search,
        cursorColor: const Color(0xFF715EFE),
        cursorWidth: 1.5,
        cursorHeight: ui(16),
        onSubmitted: _handleSubmitted,
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(
          fontSize: ui(14),
          color: const Color(0xFF1A1A1A),
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w400,
        ),
        decoration: InputDecoration(
          isCollapsed: false,
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          hintText: '搜索',
          hintStyle: TextStyle(
            fontSize: ui(14),
            color: const Color(0xFFD1D1D1),
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w400,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.only(left: ui(14), right: ui(8)),
            child: AppAssetGraphic(
              AppAssets.shellV2Search,
              width: ui(16),
              height: ui(16),
              fit: BoxFit.contain,
            ),
          ),
          prefixIconConstraints: BoxConstraints(minWidth: ui(38)),
          suffixIcon: _query.isEmpty
              ? null
              : AppPressable(
                  semanticLabel: '清空',
                  onTap: _controller.clear,
                  child: Padding(
                    padding: EdgeInsets.only(right: ui(10)),
                    child: Icon(
                      Icons.cancel,
                      size: ui(16),
                      color: const Color(0xFFC6C6C6),
                    ),
                  ),
                ),
          suffixIconConstraints: BoxConstraints(minWidth: ui(28)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ui(12)),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ui(12)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ui(12)),
            borderSide: BorderSide(
              color: const Color(0xFFE5DFFE),
              width: ui(1),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    final box = context.findRenderObject() as RenderBox?;
    final width = (box?.size.width ?? 324).clamp(320.0, 420.0);
    return CompositedTransformFollower(
      link: _layerLink,
      showWhenUnlinked: false,
      targetAnchor: Alignment.bottomLeft,
      offset: const Offset(0, AppSpace.s8),
      child: Align(
        alignment: Alignment.topLeft,
        child: TapRegion(
          groupId: _searchRegion,
          child: SizedBox(
            width: width,
            child: Material(
              type: MaterialType.transparency,
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
        ),
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.status,
    required this.onRetry,
    required this.activeTab,
    required this.results,
    required this.onTabChanged,
    required this.onItemTap,
  });

  final _SearchStatus status;
  final VoidCallback onRetry;
  final _SearchTab activeTab;
  final Map<_SearchTab, List<_SearchItem>> results;
  final ValueChanged<_SearchTab> onTabChanged;
  final ValueChanged<_SearchItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    double ui(num value) => value.toDouble();
    final list = results[activeTab] ?? const <_SearchItem>[];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: const Color(0xFFF3F2F3), width: ui(1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x1F000000),
            blurRadius: ui(16),
            offset: Offset(0, ui(4)),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchTabBar(
            activeTab: activeTab,
            results: results,
            onTabChanged: onTabChanged,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(ui(12), ui(10), ui(12), ui(12)),
            child: SizedBox(height: ui(360), child: _buildBody(context, list)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<_SearchItem> list) {
    double ui(num value) => value.toDouble();
    if (status == _SearchStatus.idle || status == _SearchStatus.loading) {
      return Center(child: const AppLoadingIndicator());
    }
    if (status == _SearchStatus.failed) {
      return AppErrorState(
        title: '搜索失败',
        description: '请检查网络后重试',
        onRetry: onRetry,
      );
    }
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: ui(40),
              color: const Color(0xFFCECED1),
            ),
            SizedBox(height: ui(8)),
            Text(
              '暂无结果',
              style: TextStyle(
                fontSize: ui(13),
                color: const Color(0xFFB6B5BB),
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w400,
                height: 1.2,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(8)),
        border: Border.all(color: const Color(0xFFF3F3F3), width: ui(1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: ui(10), vertical: ui(4)),
        itemCount: list.length,
        separatorBuilder: (_, _) =>
            Container(height: ui(1), color: const Color(0xFFF3F3F3)),
        itemBuilder: (context, index) {
          final item = list[index];
          return _SearchResultRow(
            index: index,
            item: item,
            onTap: () => onItemTap(item),
          );
        },
      ),
    );
  }
}

class _SearchTabBar extends StatelessWidget {
  const _SearchTabBar({
    required this.activeTab,
    required this.results,
    required this.onTabChanged,
  });

  final _SearchTab activeTab;
  final Map<_SearchTab, List<_SearchItem>> results;
  final ValueChanged<_SearchTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    double ui(num value) => value.toDouble();
    return Container(
      height: ui(44),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F2F3), width: 1)),
      ),
      child: Row(
        children: _SearchTab.values.map((tab) {
          final count = results[tab]?.length ?? 0;
          final selected = tab == activeTab;
          return Expanded(
            child: AppPressable(
              onTap: () => onTabChanged(tab),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: ui(13),
                          fontFamily: 'PingFang SC',
                          fontWeight: selected ? AppFont.w500 : AppFont.w400,
                          color: selected
                              ? const Color(0xFF715EFE)
                              : const Color(0xFF6D6B75),
                          height: 1.2,
                        ),
                        children: [
                          TextSpan(text: tab.label),
                          TextSpan(text: '($count)'),
                        ],
                      ),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      bottom: ui(0),
                      child: Container(
                        width: ui(28),
                        height: ui(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF715EFE),
                          borderRadius: BorderRadius.circular(ui(3)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({
    required this.index,
    required this.item,
    required this.onTap,
  });

  final int index;
  final _SearchItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    double ui(num value) => value.toDouble();
    return AppPressable(
      onTap: onTap,
      child: SizedBox(
        height: ui(44),
        child: Row(
          children: [
            Container(
              width: ui(20),
              height: ui(20),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFF715EFE),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ui(12),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 1,
                ),
              ),
            ),
            SizedBox(width: ui(10)),
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ui(13),
                  color: const Color(0xFF0B081A),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w400,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
