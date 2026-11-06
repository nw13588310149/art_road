import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:the_road_of_music_flutter/core/widgets/app_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/class_share_drawer.dart';
import '../../shell/ui/shell_layout.dart';
import '../../smart_campus/navigation/group_chat_return.dart';
import '../state/consultation_detail_controller.dart';
import '../state/consultation_detail_state.dart';
import 'consultation_page.dart';
import 'package:the_road_of_music_flutter/core/theme/app_font.dart';

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
      if (msg.isNotEmpty && msg != previous?.errorMessage) {
        AppToast.show(context, msg);
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
    return ShellPageSurface(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ui(16)),
        child: PageInitLoadingShell(
          loading: state.loading && state.detail == null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DetailHeader(
                onBack: () =>
                    GroupChatReturnNavigator.pop(context, ref: ref),
                onShare: controller.openShareDialog,
              ),
              Expanded(
                child: state.detail == null
                    ? const Center(child: Text('暂无资讯'))
                    : _DetailBody(detail: state.detail!),
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
        label: '您将分享的资讯',
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
          AppToast.show(context, '消息已成功发送');
          Navigator.of(context).maybePop();
        }
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 顶部 56 header（左返回 + 右"分享"按钮）
// ─────────────────────────────────────────────────────────────────────

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.onBack, required this.onShare});

  final VoidCallback onBack;
  final VoidCallback onShare;

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

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return GestureDetector(
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
              'assets/images/home/dictation/10.png',
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// 详情正文：标题 + 元信息 + 阅读数 + 封面 + HTML 正文
// ─────────────────────────────────────────────────────────────────────

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});

  final ConsultationDetail detail;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    // 外层 vertical 12 padding 让滚动条不顶到 header 分割线和白卡底部；
    // 内层滚动 padding 上下各减 12，整体视觉与原间距一致。
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
                  Text(
                    detail.source,
                    style: TextStyle(
                      color: const Color(0xFF6D6B75),
                      fontSize: ui(14),
                      fontFamily: 'PingFang SC',
                      height: 20 / 14,
                    ),
                  ),
                  SizedBox(width: ui(11)),
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
                  _ViewCountText(count: detail.viewCount),
                ],
              ),
              SizedBox(height: ui(20)),
              HtmlWidget(
                detail.htmlContent.isEmpty ? '<p>暂无内容</p>' : detail.htmlContent,
                textStyle: TextStyle(
                  color: const Color(0xFF0B081A),
                  fontSize: ui(13),
                  fontFamily: 'PingFang SC',
                  height: 24 / 13,
                ),
                // 拦截 <img>：默认 _core 包对 <img> 的处理会把整张大图按
                // 原始分辨率解码到 GPU，iPad 上快速 fling 时多张高清图同时
                // 解码 → Skia/Impeller OOM 闪退。这里改成 CachedNetworkImage
                // + 受限的 memCacheWidth，把解码后位图大小卡在屏幕物理像素
                // 内，并用 RepaintBoundary 隔离 raster cache。
                customWidgetBuilder: (element) {
                  if (element.localName != 'img') return null;
                  final src = element.attributes['src']?.trim() ?? '';
                  if (src.isEmpty) return null;
                  final designW = double.tryParse(
                    element.attributes['width'] ?? '',
                  );
                  final designH = double.tryParse(
                    element.attributes['height'] ?? '',
                  );
                  return _ConsultationHtmlImage(
                    url: src,
                    designWidth: designW,
                    designHeight: designH,
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

/// 资讯正文中的 `<img>` 渲染器：把后端给的远程图片按容器最大宽度等比缩放，
/// 同时把解码后的位图尺寸（`memCacheWidth`）卡在屏幕物理像素 × 1 的范围里，
/// 避免一张几 MB 的大图被解到几十 MB 的位图，导致 iPad 在快速滚动时 OOM。
///
/// - 加 `RepaintBoundary` 隔离图层，滚动时不会让整篇正文都重新栅格化。
/// - 用 `CachedNetworkImage` 走磁盘缓存，避免重复下载/解码。
/// - 加载失败时退回灰色占位，正文不会因为单张图损坏而整页崩。
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

        // memCacheWidth 上限：屏幕物理像素 × 1，最多 1600，避免设计师
        // 上传的 4K 大图在内存里占爆。
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

class _ViewCountText extends StatelessWidget {
  const _ViewCountText({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final ui = DashboardScaleScope.of(context).ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/home/eye.png',
          width: ui(14),
          fit: BoxFit.contain,
        ),
        SizedBox(width: ui(4)),
        Text(
          count.toString(),
          style: TextStyle(
            color: const Color(0xFF6D6B75),
            fontSize: ui(14),
            fontFamily: 'PingFang SC',
            height: 1.0,
          ),
        ),
      ],
    );
  }
}
