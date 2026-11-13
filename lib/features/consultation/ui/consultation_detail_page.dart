import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/class_share_drawer.dart';
import '../../shell/ui/shell_layout.dart';
import '../../smart_campus/navigation/group_chat_return.dart';
import '../state/consultation_detail_controller.dart';
import '../state/consultation_detail_state.dart';
import 'consultation_page.dart';

class ConsultationDetailPage extends ConsumerStatefulWidget {
  const ConsultationDetailPage({super.key});

  @override
  ConsumerState<ConsultationDetailPage> createState() =>
      _ConsultationDetailPageState();
}

class _ConsultationDetailPageState
    extends ConsumerState<ConsultationDetailPage> {
  ConsultationDetailArgs? _args;
  bool _shareDialogShowing = false;

  ConsultationDetailArgs _resolveArgs(BuildContext context) {
    if (_args != null) return _args!;
    final raw = ModalRoute.of(context)?.settings.arguments;
    _args = ConsultationDetailArgs.fromRaw(raw);
    return _args!;
  }

  @override
  Widget build(BuildContext context) {
    final args = _resolveArgs(context);
    final provider = consultationDetailControllerProvider(args);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen<ConsultationDetailState>(provider, (previous, next) {
      final msg = next.errorMessage;
      if (msg.isNotEmpty &&
          msg != previous?.errorMessage &&
          next.detail != null) {
        AppToast.showError(context, msg);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) controller.clearError();
        });
      }

      if (next.shareDialogVisible && !_shareDialogShowing) {
        _shareDialogShowing = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showShareDialog(context, args);
        });
      }
    });

    final ui = DashboardScaleScope.of(context).ui;
    final detail = state.detail;
    return ShellPageSurface(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ui(16)),
        child: PageInitLoadingShell(
          loading: state.loading && detail == null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DetailHeader(
                onBack: () => GroupChatReturnNavigator.pop(context, ref: ref),
                onShare: detail == null ? null : controller.openShareDialog,
              ),
              Expanded(
                child: detail == null
                    ? (state.loading
                          ? const SizedBox.shrink()
                          : AppErrorState(
                              title: '资讯加载失败',
                              description: state.errorMessage.isEmpty
                                  ? '内容可能已下架，请返回列表查看其他资讯'
                                  : state.errorMessage,
                              onRetry: controller.reload,
                            ))
                    : _DetailBody(detail: detail),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showShareDialog(
    BuildContext context,
    ConsultationDetailArgs args,
  ) async {
    if (!mounted) return;
    await showClassShareDrawer<void>(
      context: context,
      scale: DashboardScaleScope.of(context),
      child: _ConsultationShareDrawer(args: args),
    );
    _shareDialogShowing = false;
    if (mounted) {
      ref
          .read(consultationDetailControllerProvider(args).notifier)
          .closeShareDialog();
    }
  }
}

class _ConsultationShareDrawer extends ConsumerWidget {
  const _ConsultationShareDrawer({required this.args});

  final ConsultationDetailArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(consultationDetailControllerProvider(args));
    final controller = ref.read(
      consultationDetailControllerProvider(args).notifier,
    );

    return ClassShareDrawer(
      title: '分享资讯',
      targetCard: ShareTargetCard(
        label: '你将分享的资讯',
        title: state.detail?.title ?? '',
        coverUrl: state.detail?.coverUrl ?? '',
        placeholderIcon: Icons.feed_rounded,
      ),
      classes: state.classList
          .map(
            (cls) => ClassShareItem(
              id: cls.id,
              name: cls.name,
              avatarUrl: cls.avatarUrl,
              checked: cls.checked,
            ),
          )
          .toList(growable: false),
      loading: state.classLoading,
      sending: state.sending,
      onToggleClass: controller.toggleClass,
      onSend: () async {
        final success = await controller.send();
        if (!context.mounted) return;
        if (success) {
          AppToast.showSuccess(context, '已分享到班级群');
          Navigator.of(context).maybePop();
        }
      },
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.onBack, required this.onShare});

  final VoidCallback onBack;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Container(
      height: ui(56),
      padding: EdgeInsets.symmetric(horizontal: ui(20)),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF3F2F3), width: 1)),
      ),
      child: Row(
        children: [
          ConsultationBackButton(onTap: onBack),
          Expanded(
            child: Center(
              child: Text(
                '资讯',
                style: TextStyle(
                  color: const Color(0xFF0B081A),
                  fontSize: ui(16),
                  fontWeight: AppFont.w600,
                  fontFamily: 'PingFang SC',
                ),
              ),
            ),
          ),
          _ShareButton(onTap: onShare),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: ui(28),
          padding: EdgeInsets.fromLTRB(ui(12), ui(4), ui(13), ui(4)),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(ui(8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                AppAssets.newsShare,
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
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});

  final ConsultationDetail detail;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: ui(12)),
      child: Scrollbar(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(ui(20), ui(12), ui(20), ui(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.title,
                style: TextStyle(
                  color: const Color(0xFF0B081A),
                  fontSize: ui(16),
                  fontFamily: 'PingFang SC',
                  fontWeight: AppFont.w500,
                  height: 24 / 16,
                ),
              ),
              SizedBox(height: ui(8)),
              Row(
                children: [
                  if (detail.source.isNotEmpty)
                    Text(
                      detail.source,
                      style: TextStyle(
                        color: const Color(0xFF6D6B75),
                        fontSize: ui(14),
                        fontFamily: 'PingFang SC',
                        height: 20 / 14,
                      ),
                    ),
                  if (detail.source.isNotEmpty) SizedBox(width: ui(11)),
                  if (detail.updateTime.isNotEmpty)
                    Text(
                      detail.updateTime,
                      style: TextStyle(
                        color: const Color(0xFF6D6B75),
                        fontSize: ui(14),
                        fontFamily: 'PingFang SC',
                        height: 20 / 14,
                      ),
                    ),
                  SizedBox(width: ui(16)),
                  ViewCountLabel(count: detail.viewCount, fontSize: 14),
                ],
              ),
              SizedBox(height: ui(20)),
              HtmlWidget(
                detail.htmlContent.isEmpty
                    ? '<p>暂无内容</p>'
                    : detail.htmlContent,
                textStyle: TextStyle(
                  color: const Color(0xFF0B081A),
                  fontSize: ui(13),
                  fontFamily: 'PingFang SC',
                  height: 24 / 13,
                ),
                customWidgetBuilder: (element) {
                  if (element.localName != 'img') return null;
                  final src = element.attributes['src']?.trim() ?? '';
                  if (src.isEmpty) return null;
                  return _ConsultationHtmlImage(
                    url: src,
                    designWidth: double.tryParse(
                      element.attributes['width'] ?? '',
                    ),
                    designHeight: double.tryParse(
                      element.attributes['height'] ?? '',
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 资讯正文中的 `<img>`：按容器宽度等比缩放，解码尺寸限制在屏幕物理像素内。
class _ConsultationHtmlImage extends StatelessWidget {
  const _ConsultationHtmlImage({
    required this.url,
    this.designWidth,
    this.designHeight,
  });

  final String url;
  final double? designWidth;
  final double? designHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.maybeOf(context);
        final dpr = media?.devicePixelRatio ?? 1.0;
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (media?.size.width ?? 1024.0);

        double width = designWidth ?? maxW;
        double? height = designHeight;
        if (width > maxW) {
          if (designWidth != null && designHeight != null && designWidth! > 0) {
            height = designHeight! * (maxW / designWidth!);
          } else {
            height = null;
          }
          width = maxW;
        }
        final memCacheW = (width * dpr).clamp(1.0, 1600.0).toInt();

        return RepaintBoundary(
          child: CachedNetworkImage(
            imageUrl: url,
            width: width,
            height: height,
            fit: BoxFit.contain,
            memCacheWidth: memCacheW,
            fadeInDuration: const Duration(milliseconds: 120),
            fadeOutDuration: const Duration(milliseconds: 80),
            errorWidget: (context, error, stackTrace) => Container(
              width: width,
              height: height ?? 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.broken_image_rounded,
                color: Color(0xFFC9C6D8),
              ),
            ),
          ),
        );
      },
    );
  }
}
