// 校长端「校长信箱」收件箱：查看来信并按状态筛选、回复。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';

import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/scaled_dialog.dart';
import '../../shell/ui/shell_layout.dart';
import '../../../core/constants/app_assets.dart';
import '../data/principal_inbox_data.dart';
import '../data/principal_mailbox_repository.dart';
import 'mailbox_attachment_widgets.dart';

const Color _kPageBg = Color(0xFFEFF3FC);
const Color _kBorderSoft = Color(0xFFF3F2F3);
const Color _kInnerGray = Color(0xFFF5F6FA);
const Color _kTextDark = Color(0xFF0B081A);
const Color _kTextHint = Color(0xFFB6B5BB);
const Color _kPurple = Color(0xFF8741FF);
const Color _kGreen = Color(0xFF35BD7C);

class PrincipalInboxView extends ConsumerStatefulWidget {
  const PrincipalInboxView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<PrincipalInboxView> createState() => _PrincipalInboxViewState();
}

class _PrincipalInboxViewState extends ConsumerState<PrincipalInboxView> {
  static const int _pageSize = 10;

  PrincipalInboxStatus _status = PrincipalInboxStatus.sent;
  bool _loading = false;
  bool _replying = false;
  int _currentPage = 1;
  int _total = 0;
  List<PrincipalInboxItem> _items = const [];

  int get _totalPages {
    if (_total <= 0) return 1;
    return (_total + _pageSize - 1) ~/ _pageSize;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadList(page: 1));
    });
  }

  Future<void> _loadList({required int page}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final resp = await ref
          .read(principalMailboxRepositoryProvider)
          .headmasterPrincipalMailboxList(
            current: page,
            size: _pageSize,
            status: _status.apiCode,
          );
      if (!mounted) return;
      if (!resp.isSuccess) {
        AppToast.show(context, resp.displayMsg);
        setState(() => _loading = false);
        return;
      }
      final pageData = parsePrincipalInboxPage(resp.data);
      setState(() {
        _items = pageData.items;
        _total = pageData.total;
        _currentPage = page;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.show(context, '网络异常，请稍后再试');
    }
  }

  Future<void> _reloadCurrentPage() async {
    await _loadList(page: _currentPage);
    if (!mounted) return;
    if (_items.isEmpty && _currentPage > 1) {
      await _loadList(page: _currentPage - 1);
    }
  }

  Future<void> _goToPage(int page) async {
    if (page < 1 || page > _totalPages || page == _currentPage) return;
    await _loadList(page: page);
  }

  Future<void> _switchStatus(PrincipalInboxStatus status) async {
    if (_status == status && !_loading) return;
    setState(() {
      _status = status;
      _items = const [];
      _currentPage = 1;
      _total = 0;
    });
    await _loadList(page: 1);
  }

  Future<void> _reply(PrincipalInboxItem item) async {
    if (_replying || item.id.isEmpty) return;
    final content = await showTextInputDialog(
      context: context,
      title: '回复 · ${item.submitterLabel}',
      hintText: '填写回复内容',
      confirmLabel: '发送回复',
      multiline: true,
    );
    if (!mounted || content == null || content.isEmpty) return;
    setState(() => _replying = true);
    try {
      final resp = await ref
          .read(principalMailboxRepositoryProvider)
          .headmasterPrincipalMailboxReply(id: item.id, replyContent: content);
      if (!mounted) return;
      if (!resp.isSuccess) {
        AppToast.show(context, resp.displayMsg);
        return;
      }
      AppToast.show(context, '回复已发送');
      await _reloadCurrentPage();
    } catch (_) {
      if (!mounted) return;
      AppToast.show(context, '网络异常，请稍后再试');
    } finally {
      if (mounted) setState(() => _replying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      color: _kPageBg,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ui(16)),
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              _Banner(onBack: widget.onBack),
              Padding(
                padding: EdgeInsets.fromLTRB(ui(16), ui(14), ui(16), ui(12)),
                child: _StatusFilterRow(
                  current: _status,
                  onChanged: (status) => unawaited(_switchStatus(status)),
                ),
              ),
              Expanded(
                child: MainContentLoadingShell(
                  loading: _loading && _items.isEmpty,
                  child: Column(
                    children: [
                      Expanded(
                        child: _loading && _items.isEmpty
                            ? const SizedBox.shrink()
                            : _items.isEmpty
                            ? const _EmptyHint()
                            : ListView.separated(
                                padding: EdgeInsets.fromLTRB(
                                  ui(16),
                                  0,
                                  ui(16),
                                  ui(12),
                                ),
                                itemCount: _items.length,
                                separatorBuilder: (_, _) =>
                                    SizedBox(height: ui(12)),
                                itemBuilder: (_, index) => _InboxCard(
                                  item: _items[index],
                                  replying: _replying,
                                  onReply: () =>
                                      unawaited(_reply(_items[index])),
                                ),
                              ),
                      ),
                      if (_total > 0)
                        _InboxPaginationBar(
                          currentPage: _currentPage,
                          totalPages: _totalPages,
                          total: _total,
                          loading: _loading,
                          onPrev: () => unawaited(_goToPage(_currentPage - 1)),
                          onNext: () => unawaited(_goToPage(_currentPage + 1)),
                        ),
                    ],
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

class _Banner extends StatelessWidget {
  const _Banner({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(82),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(AppAssets.xiaoquanHeaderBg),
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: ui(20),
            top: ui(20),
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(ui(8)),
              child: Container(
                width: ui(32),
                height: ui(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui(8)),
                  border: Border.all(color: _kBorderSoft),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: ui(20),
                  color: const Color(0xFF1C274C),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '校长信箱',
                  style: TextStyle(
                    fontSize: ui(16),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                  ),
                ),
                SizedBox(height: ui(4)),
                Text(
                  '查看师生来信，按状态筛选并回复',
                  style: TextStyle(
                    fontSize: ui(12),
                    color: _kTextHint,
                    fontFamily: 'PingFang SC',
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

class _StatusFilterRow extends StatelessWidget {
  const _StatusFilterRow({required this.current, required this.onChanged});

  final PrincipalInboxStatus current;
  final ValueChanged<PrincipalInboxStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      children: [
        for (final status in PrincipalInboxStatus.values) ...[
          _StatusChip(
            label: status.label,
            selected: current == status,
            onTap: () => onChanged(status),
          ),
          SizedBox(width: ui(8)),
        ],
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ui(16)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: ui(14), vertical: ui(6)),
        decoration: BoxDecoration(
          color: selected ? _kPurple : _kInnerGray,
          borderRadius: BorderRadius.circular(ui(16)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: ui(13),
            color: selected ? Colors.white : _kTextDark,
            fontFamily: 'PingFang SC',
            fontWeight: AppFont.w500,
          ),
        ),
      ),
    );
  }
}

class _InboxCard extends StatelessWidget {
  const _InboxCard({
    required this.item,
    required this.replying,
    required this.onReply,
  });

  final PrincipalInboxItem item;
  final bool replying;
  final VoidCallback onReply;

  Color get _statusColor {
    return switch (item.status) {
      PrincipalInboxStatus.sent => _kPurple,
      PrincipalInboxStatus.replied => _kGreen,
      PrincipalInboxStatus.closed => _kTextHint,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final hasReply = item.replyContent.trim().isNotEmpty;
    return Container(
      padding: EdgeInsets.all(ui(14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui(12)),
        border: Border.all(color: _kBorderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Badge(text: item.status.label, color: _statusColor),
              if (item.msgType.isNotEmpty) ...[
                SizedBox(width: ui(8)),
                _Badge(text: item.msgType, color: const Color(0xFF325BFF)),
              ],
              const Spacer(),
              if (item.createTime.isNotEmpty)
                Text(
                  item.createTime,
                  style: TextStyle(fontSize: ui(12), color: _kTextHint),
                ),
            ],
          ),
          SizedBox(height: ui(10)),
          Row(
            children: [
              if (!item.isAnonymous) ...[
                _SubmitterAvatar(
                  name: item.submitterLabel,
                  avatarUrl: item.submitterHeadUrl,
                ),
                SizedBox(width: ui(10)),
              ],
              Expanded(
                child: Text(
                  item.submitterLabel,
                  style: TextStyle(
                    fontSize: ui(14),
                    color: _kTextDark,
                    fontFamily: 'PingFang SC',
                    fontWeight: AppFont.w600,
                  ),
                ),
              ),
            ],
          ),
          if (item.studentNo.isNotEmpty) ...[
            SizedBox(height: ui(4)),
            Text(
              '学号 ${item.studentNo}',
              style: TextStyle(fontSize: ui(12), color: _kTextHint),
            ),
          ],
          SizedBox(height: ui(10)),
          Text(
            item.content,
            style: TextStyle(
              fontSize: ui(14),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              height: 1.5,
            ),
          ),
          if (item.attachments.isNotEmpty) ...[
            SizedBox(height: ui(10)),
            Wrap(
              spacing: ui(8),
              runSpacing: ui(8),
              children: [
                for (var i = 0; i < item.attachments.length; i++)
                  MailboxAttachmentChip(
                    url: item.attachments[i],
                    onTap: () => previewMailboxAttachment(
                      context,
                      attachments: item.attachments,
                      index: i,
                      heroTagPrefix: 'inbox_${item.id}',
                    ),
                  ),
              ],
            ),
          ],
          if (hasReply) ...[
            SizedBox(height: ui(12)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(ui(12)),
              decoration: BoxDecoration(
                color: _kInnerGray,
                borderRadius: BorderRadius.circular(ui(8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '我的回复',
                    style: TextStyle(
                      fontSize: ui(12),
                      color: _kPurple,
                      fontWeight: AppFont.w500,
                    ),
                  ),
                  if (item.replyTime.isNotEmpty) ...[
                    SizedBox(height: ui(4)),
                    Text(
                      item.replyTime,
                      style: TextStyle(fontSize: ui(11), color: _kTextHint),
                    ),
                  ],
                  SizedBox(height: ui(6)),
                  Text(
                    item.replyContent,
                    style: TextStyle(
                      fontSize: ui(13),
                      color: _kTextDark,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (item.canReply) ...[
            SizedBox(height: ui(12)),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ReplyButton(
                  label: replying ? '提交中…' : '回复',
                  enabled: !replying,
                  onTap: onReply,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InboxPaginationBar extends StatelessWidget {
  const _InboxPaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.total,
    required this.loading,
    required this.onPrev,
    required this.onNext,
  });

  final int currentPage;
  final int totalPages;
  final int total;
  final bool loading;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final canPrev = !loading && currentPage > 1;
    final canNext = !loading && currentPage < totalPages;
    return Container(
      padding: EdgeInsets.fromLTRB(ui(16), ui(10), ui(16), ui(14)),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _kBorderSoft)),
      ),
      child: Row(
        children: [
          Text(
            '共 $total 条',
            style: TextStyle(
              fontSize: ui(12),
              color: _kTextHint,
              fontFamily: 'PingFang SC',
            ),
          ),
          const Spacer(),
          _PaginationArrow(
            icon: Icons.chevron_left_rounded,
            enabled: canPrev,
            onTap: onPrev,
          ),
          SizedBox(width: ui(8)),
          Text(
            '第 $currentPage / $totalPages 页',
            style: TextStyle(
              fontSize: ui(13),
              color: _kTextDark,
              fontFamily: 'PingFang SC',
              fontWeight: AppFont.w500,
            ),
          ),
          SizedBox(width: ui(8)),
          _PaginationArrow(
            icon: Icons.chevron_right_rounded,
            enabled: canNext,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class _PaginationArrow extends StatelessWidget {
  const _PaginationArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Container(
          width: ui(32),
          height: ui(32),
          decoration: BoxDecoration(
            color: _kInnerGray,
            borderRadius: BorderRadius.circular(ui(8)),
            border: Border.all(color: _kBorderSoft),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: ui(18), color: const Color(0xFF1C274C)),
        ),
      ),
    );
  }
}

class _ReplyButton extends StatelessWidget {
  const _ReplyButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [Color(0xFFB68EFF), Color(0xFF8640FF)],
            ),
            borderRadius: BorderRadius.circular(ui(6)),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: ui(12), vertical: ui(5)),
            child: Text(
              label,
              style: TextStyle(
                fontSize: ui(12),
                color: Colors.white,
                fontFamily: 'PingFang SC',
                fontWeight: AppFont.w500,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmitterAvatar extends StatelessWidget {
  const _SubmitterAvatar({required this.name, required this.avatarUrl});

  final String name;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    final initial = name.isNotEmpty ? name.characters.first : '·';
    final placeholder = Container(
      width: ui(36),
      height: ui(36),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFDAD2FF),
        borderRadius: BorderRadius.circular(ui(8)),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: ui(14),
          height: 1.0,
          fontWeight: AppFont.w600,
          color: _kPurple,
          fontFamily: 'PingFang SC',
        ),
      ),
    );
    final url = avatarUrl.trim();
    if (url.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ui(8)),
      child: Image.network(
        url,
        width: ui(36),
        height: ui(36),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ui(8), vertical: ui(2)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ui(4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: ui(11),
          color: color,
          fontFamily: 'PingFang SC',
          fontWeight: AppFont.w500,
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: ui(40), color: _kTextHint),
          SizedBox(height: ui(8)),
          Text(
            '当前状态下暂无来信',
            style: TextStyle(fontSize: ui(13), color: _kTextHint),
          ),
        ],
      ),
    );
  }
}
